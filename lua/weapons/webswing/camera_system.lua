-- Camera System for Web Shooters

local CameraSystem = {}
local MapAnalysisData = include("map_analysis.lua") -- Import the map analysis module

-- Track active camera weapons
CameraSystem.ActiveWeapons = {}

-- Initialize camera variables
function CameraSystem.InitializeCamera(weapon)
    weapon.CameraVars = {
        targetDistance = 150,
        currentDistance = 150,
        minDistance = 150,
        maxDistance = 200,
        lastPos = Vector(0, 0, 0),
        currentAngles = Angle(0, 0, 0),
        tiltAngle = 0,
        maxTilt = 20, -- Reduced from 25 for less extreme rolls
        smoothSpeed = 5,
        verticalOffset = 5,
        contextualFOV = 72,
        baseFOV = 72, -- Store the base FOV
        targetFOV = 72, -- Target FOV for transitions
        lastContextState = "", -- Tracks the last contextual state for transitions
        contextTransitionTime = 0, -- Track when context last changed
        isInVerticalCorridor = false,
        nearLandmark = false,
        onWall = false,
        terrainType = "flat",
        ceilingCrawling = false,
        -- New dynamic camera variables
        lastVelocity = Vector(0, 0, 0),
        velocityChangeTime = 0,
        lastTurnTime = 0,
        lastDiveTime = 0,
        zoomFactor = 0, -- Current zoom factor for impact zooms
        rollFactor = 0, -- Enhanced roll factor
        lastSpeedFOVBoost = 0, -- Last speed-based FOV boost
        lastAngularVelocity = Angle(0, 0, 0),
        impactZoomDuration = 0.5, -- Duration of impact zoom effects
        recentTurns = {}, -- Track recent turns for roll accumulation
        maxRecentTurns = 5, -- Maximum number of recent turns to track
        lastSharpTurnMagnitude = 0, -- Magnitude of the last sharp turn
        lastRollAngle = 0, -- Store the last roll angle to prevent resets
        preserveRoll = false -- Flag to preserve roll during transitions
    }
    return weapon.CameraVars
end

-- Initialize the camera system
function CameraSystem.Initialize()
    if CLIENT then
        -- Remove any existing hooks first
        hook.Remove("CalcView", "SpiderManView_Global")
        
        -- Add a single global hook
        hook.Add("CalcView", "SpiderManView_Global", function(ply, pos, angles, fov)
            if !IsValid(ply) or ply ~= LocalPlayer() then return end
            
            local weapon = ply:GetActiveWeapon()
            if !IsValid(weapon) or weapon:GetClass() != "webswing" then return end
            
            -- Use the CameraSystem.CalculateView function
            return CameraSystem.CalculateView(weapon, ply, pos, angles, fov)
        end)
        
        -- Add a cleanup hook for when the game shuts down
        hook.Add("ShutDown", "WebSwing_CleanupHooks", function()
            hook.Remove("CalcView", "SpiderManView_Global")
        end)
    end
end

-- Call the initialize function
CameraSystem.Initialize()

-- Single global hook for all camera views
if CLIENT then
    -- This is now handled in the Initialize function
end

-- Analyze player context to determine camera behavior
function CameraSystem.AnalyzePlayerContext(weapon, ply, pos)
    local cv = weapon.CameraVars
    if not cv then 
        -- Recreate camera vars if missing
        cv = CameraSystem.InitializeCamera(weapon)
        if not cv then return "standard" end
    end
    
    -- Get map analysis data
    local mapAnalysis = weapon.MapAnalysis
    if not mapAnalysis or not mapAnalysis.analyzed then return "standard" end
    
    -- Check if player is on a wall
    local isOnWall, wallNormal = MapAnalysisData:IsOnWall(ply)
    cv.onWall = isOnWall
    
    -- Check vertical corridors
    local inVerticalCorridor, corridorInfo = MapAnalysisData:IsInVerticalCorridor(pos, mapAnalysis)
    cv.isInVerticalCorridor = inVerticalCorridor
    
    -- Get nearest landmark
    local landmark = MapAnalysisData:GetNearestLandmark(pos, mapAnalysis)
    cv.nearLandmark = landmark and landmark.distance < landmark.size * 1.5
    
    -- Get terrain type
    cv.terrainType = MapAnalysisData:GetTerrainTypeAtPosition(pos) or "flat" -- Ensure always has a value
    
    -- Check if player is crawling on ceiling (inverted Z normal)
    local groundNormal = ply:GetGroundNormal()
    cv.ceilingCrawling = groundNormal and groundNormal.z < -0.7
    
    -- Determine the current context
    local context = "standard"
    
    -- Get player velocity for context-specific settings
    local velocity = ply:GetVelocity()
    local speed = velocity:Length()
    
    if cv.ceilingCrawling then
        context = "ceiling"
    elseif inVerticalCorridor then
        context = "vertical_corridor"
    elseif isOnWall then
        context = "wall"
    elseif cv.terrainType == "steep" or cv.terrainType == "sloped" then
        context = "slope"
    elseif cv.nearLandmark then
        context = "landmark"
    elseif speed > 800 then -- Increased threshold for high-speed context
        context = "fast_moving"
    elseif speed > 500 then
        context = "moving"
    end
    
    -- Handle context transitions
    if cv.lastContextState ~= context then
        cv.contextTransitionTime = CurTime()
        cv.lastContextState = context
    end
    
    return context
end

-- Detect dramatic moments for camera effects
function CameraSystem.DetectDramaticMoments(weapon, ply)
    local cv = weapon.CameraVars
    if not cv then return false end
    
    local currentTime = CurTime()
    local velocity = ply:GetVelocity()
    local currentSpeed = velocity:Length()
    
    -- Initialize all time-related variables to prevent nil errors
    if cv.lastTurnTime == nil then cv.lastTurnTime = 0 end
    if cv.lastDiveTime == nil then cv.lastDiveTime = 0 end
    if cv.velocityChangeTime == nil then cv.velocityChangeTime = 0 end
    if cv.lastSharpTurnMagnitude == nil then cv.lastSharpTurnMagnitude = 0 end
    
    -- Make sure lastVelocity is initialized
    if not cv.lastVelocity then
        cv.lastVelocity = Vector(0, 0, 0)
    end
    
    local speedChange = (velocity - cv.lastVelocity):Length()
    local eyeAngles = ply:EyeAngles()
    
    -- Calculate angular velocity (how quickly the player is turning)
    local angularVelocity = Angle(0, 0, 0)
    if not cv.lastAngularVelocity then
        cv.lastAngularVelocity = eyeAngles
    end
    
    angularVelocity = eyeAngles - cv.lastAngularVelocity
    -- Normalize angles
    angularVelocity.y = math.NormalizeAngle(angularVelocity.y)
    angularVelocity.p = math.NormalizeAngle(angularVelocity.p)
    angularVelocity.r = math.NormalizeAngle(angularVelocity.r)
    
    -- Store values for next frame
    cv.lastVelocity = velocity
    cv.lastAngularVelocity = eyeAngles
    
    local dramaticMoment = false
    local momentType = "none"
    local momentMagnitude = 0
    
    -- SHARP TURN DETECTION
    -- Detect sharp turns (high angular velocity on yaw)
    local turnThreshold = 3 -- Degrees per frame
    local sharpTurnThreshold = 8 -- Degrees per frame for a very sharp turn
    local yawChange = math.abs(angularVelocity.y)
    
    -- Must be moving at a reasonable speed for turns to matter
    if currentSpeed > 300 and yawChange > turnThreshold then
        -- Make sure recentTurns is initialized
        if not cv.recentTurns then
            cv.recentTurns = {}
        end
        
        -- Initialize maxRecentTurns if needed
        if cv.maxRecentTurns == nil then
            cv.maxRecentTurns = 5 -- Default to 5 recent turns
        end
        
        -- Record this turn
        local turnRecord = {
            time = currentTime,
            magnitude = yawChange,
            direction = (angularVelocity.y > 0) and 1 or -1, -- 1 for right, -1 for left
            speed = currentSpeed
        }
        
        -- Add to recent turns list
        table.insert(cv.recentTurns, 1, turnRecord)
        
        -- Trim list if needed
        while #cv.recentTurns > cv.maxRecentTurns do
            table.remove(cv.recentTurns)
        end
        
        -- Calculate cumulative turn effect from recent turns
        local cumulativeTurn = 0
        local recentTurnWindow = 0.5 -- seconds
        for i, turn in ipairs(cv.recentTurns) do
            if currentTime - turn.time < recentTurnWindow then
                -- Turns in the same direction accumulate, opposite directions partially cancel
                local directionFactor = (i == 1) and 1 or ((turnRecord.direction == turn.direction) and 0.5 or -0.2)
                cumulativeTurn = cumulativeTurn + (turn.magnitude * directionFactor) 
            end
        end
        
        -- If turn is significant, trigger a camera effect
        if yawChange > sharpTurnThreshold or cumulativeTurn > sharpTurnThreshold * 1.5 then
            cv.lastTurnTime = currentTime
            cv.lastSharpTurnMagnitude = math.max(yawChange, cumulativeTurn / 2)
            dramaticMoment = true
            momentType = "turn"
            momentMagnitude = math.min(1, cv.lastSharpTurnMagnitude / 20) -- Normalize to 0-1
        end
    end
    
    -- DIVE/FALL DETECTION
    -- Detect sudden drops or dives
    local diveThreshold = 500 -- Velocity units/second downward
    local hardLandingThreshold = 400 -- Velocity change on landing
    
    -- Check for dive/falling
    if velocity.z < -diveThreshold and 
       (cv.lastVelocity.z > -diveThreshold * 0.7 or currentTime - cv.lastDiveTime > 1.5) then
        cv.lastDiveTime = currentTime
        dramaticMoment = true
        momentType = "dive"
        momentMagnitude = math.min(1, math.abs(velocity.z) / 1000) -- Normalize to 0-1
    end
    
    -- Check for hard landings (sudden velocity change when hitting ground)
    if speedChange > hardLandingThreshold and ply:OnGround() and cv.lastVelocity.z < -300 then
        dramaticMoment = true
        momentType = "landing"
        momentMagnitude = math.min(1, speedChange / 1000) -- Normalize to 0-1
    end
    
    -- SUDDEN ACCELERATION
    -- Detect web attach or sudden acceleration
    local accelerationThreshold = 500
    if speedChange > accelerationThreshold and currentSpeed > cv.lastVelocity:Length() then
        cv.velocityChangeTime = currentTime
        dramaticMoment = true
        momentType = "acceleration"
        momentMagnitude = math.min(1, speedChange / 1000) -- Normalize to 0-1
    end
    
    return dramaticMoment, momentType, momentMagnitude
end

-- Calculate speed-based FOV changes
function CameraSystem.CalculateSpeedFOV(weapon, ply, baseFOV)
    local cv = weapon.CameraVars
    if not cv then return baseFOV end
    
    -- Initialize lastSpeedFOVBoost if needed
    if cv.lastSpeedFOVBoost == nil then
        cv.lastSpeedFOVBoost = 0
    end
    
    -- Check if dynamic FOV is enabled
    local dynamicFovConVar = GetConVar("webswing_dynamic_fov")
    if not dynamicFovConVar or not dynamicFovConVar:GetBool() then
        return baseFOV
    end
    
    local velocity = ply:GetVelocity()
    local speed = velocity:Length()
    
    -- Calculate FOV boost based on speed
    -- Start increasing FOV at 300 units/s, max boost at 1000 units/s
    local minSpeedForFOVBoost = 300
    local maxSpeedForFOVBoost = 1000
    local maxFOVBoost = 15 -- Maximum FOV increase at top speed
    
    -- Calculate normalized speed factor (0-1)
    local speedFactor = 0
    if speed > minSpeedForFOVBoost then
        speedFactor = math.Clamp((speed - minSpeedForFOVBoost) / (maxSpeedForFOVBoost - minSpeedForFOVBoost), 0, 1)
    end
    
    -- Apply easing function for more dynamic feel (exponentiation for acceleration curve)
    speedFactor = speedFactor * speedFactor -- Quadratic easing
    
    -- Calculate FOV boost
    local fovBoost = speedFactor * maxFOVBoost
    
    -- Smooth transitions for FOV changes
    cv.lastSpeedFOVBoost = Lerp(FrameTime() * 3, cv.lastSpeedFOVBoost, fovBoost)
    
    -- Add a subtle pulsing effect based on speed for visual feedback
    local pulseAmount = speedFactor * 2 -- Max 2 degree pulse
    local pulseFactor = math.sin(CurTime() * (3 + speedFactor * 2)) -- Faster pulse at higher speeds
    local pulseFOV = pulseAmount * pulseFactor
    
    return baseFOV + cv.lastSpeedFOVBoost + pulseFOV
end

-- Calculate impact zoom effects
function CameraSystem.CalculateImpactZoom(weapon, ply, dramaticMoment, momentType, momentMagnitude)
    local cv = weapon.CameraVars
    if not cv then return 0 end
    
    -- Make sure zoomFactor is initialized
    if cv.zoomFactor == nil then
        cv.zoomFactor = 0
    end
    
    -- Initialize impact zoom duration if needed
    if cv.impactZoomDuration == nil then
        cv.impactZoomDuration = 0.5 -- Default to 0.5 seconds
    end
    
    -- Check if impact zoom is enabled
    local impactZoomConVar = GetConVar("webswing_impact_zoom")
    if not impactZoomConVar or not impactZoomConVar:GetBool() then
        return 0
    end
    
    local currentTime = CurTime()
    local zoomAmount = 0
    
    -- Process new dramatic moments
    if dramaticMoment then
        -- Different zoom effects based on moment type
        if momentType == "turn" then
            -- Sharp turns get a brief zoom-in effect
            zoomAmount = -8 * momentMagnitude -- Negative for zoom-in
        elseif momentType == "dive" then
            -- Dives get a strong zoom-out effect
            zoomAmount = 12 * momentMagnitude -- Positive for zoom-out
        elseif momentType == "landing" then
            -- Hard landings get a sharp zoom-in and camera shake
            zoomAmount = -10 * momentMagnitude
        elseif momentType == "acceleration" then
            -- Acceleration gets a moderate zoom-out
            zoomAmount = 8 * momentMagnitude
        end
    end
    
    -- Fade out existing zoom effects
    local fadeSpeed = 1 / cv.impactZoomDuration
    if math.abs(cv.zoomFactor) > 0.1 then
        -- Fade current zoom factor towards target with bounce-back
        if math.abs(zoomAmount) < 0.1 then
            -- No new zoom effect, just fade out current one
            cv.zoomFactor = Lerp(FrameTime() * 5, cv.zoomFactor, 0)
        else
            -- New zoom effect, blend based on which is stronger
            if math.abs(zoomAmount) > math.abs(cv.zoomFactor) then
                cv.zoomFactor = zoomAmount -- New effect takes precedence
            else
                -- Blend effects
                cv.zoomFactor = Lerp(FrameTime() * 10, cv.zoomFactor, zoomAmount)
            end
        end
    elseif zoomAmount ~= 0 then
        -- Apply new zoom effect
        cv.zoomFactor = zoomAmount
    end
    
    return cv.zoomFactor
end

-- Enhanced camera roll calculations
function CameraSystem.CalculateEnhancedRoll(weapon, ply, context, dramaticMoment, momentType, momentMagnitude)
    local cv = weapon.CameraVars
    if not cv then return 0 end
    
    -- Initialize rollFactor if needed
    if cv.rollFactor == nil then
        cv.rollFactor = 0
    end
    
    -- If we have a stored roll value from a transition and preserveRoll is true, use it
    if cv.preserveRoll and cv.storedRollValue and weapon.TransitioningFromSwing then
        return cv.storedRollValue
    end
    
    -- Skip enhanced roll calculations if disabled
    local enhancedRollConVar = GetConVar("webswing_enhanced_roll")
    if not enhancedRollConVar or not enhancedRollConVar:GetBool() then
        -- Fall back to basic roll calculation if enhanced is disabled
        return CameraSystem.CalculateBasicRoll(weapon, ply, context)
    end
    
    local currentTime = CurTime()
    local velocity = ply:GetVelocity()
    local horizontalSpeed = velocity:Length2D()
    local targetRoll = 0
    
    -- Calculate base roll based on movement
    if horizontalSpeed > 100 then
        -- Get right and forward vectors for player
        local eyeAngles = ply:EyeAngles()
        local forwardVec = eyeAngles:Forward()
        local rightVec = eyeAngles:Right()
        
        -- Check if we're moving left/right relative to view
        local rightDot = velocity:Dot(rightVec)
        local forwardDot = velocity:Dot(forwardVec)
        
        -- More roll when moving sideways - reduced multiplier
        local sidewaysRoll = -rightDot * 0.01 -- Reduced from 0.015
        
        -- Enhance roll based on how sideways the movement is - adjusted for smoother effect
        local sidewaysFactor = math.abs(rightDot) / (math.abs(forwardDot) + math.abs(rightDot) + 0.001)
        sidewaysRoll = sidewaysRoll * (1 + sidewaysFactor * 0.75) -- Reduced effect by 25%
        
        -- Base roll increases with speed (higher roll at higher speeds) - reduced scaling
        targetRoll = sidewaysRoll * math.min(horizontalSpeed / 600, 1.2) -- Reduced from 500 and 1.5
    end
    
    -- Enhance roll during dramatic moments
    if dramaticMoment then
        if momentType == "turn" then
            -- Make sure recentTurns is initialized
            if not cv.recentTurns or #cv.recentTurns == 0 then
                cv.recentTurns = { {direction = 1} } -- Default to right turn
            end
            
            -- Sharp turns get enhanced roll based on turn direction and magnitude - reduced multiplier
            local turnDir = cv.recentTurns[1].direction or 1
            local extraRoll = -turnDir * 10 * momentMagnitude -- Reduced from 15
            targetRoll = targetRoll + extraRoll
        elseif momentType == "dive" then
            -- Dives get a slight forward roll - reduced
            targetRoll = targetRoll + 3 * momentMagnitude -- Reduced from 5
        end
    end
    
    -- Wall running and ceiling rolls
    if context == "wall" then
        -- Add more pronounced wall-running roll - reduced multiplier
        if cv.onWall then
            local norm = ply:GetGroundNormal()
            if norm then
                local rightDot = norm:Dot(ply:EyeAngles():Right())
                local wallRoll = rightDot * 12 -- Reduced from 18
                targetRoll = targetRoll + wallRoll
            end
        end
    elseif context == "ceiling" then
        targetRoll = 180 -- Full inversion when on ceiling (keep this)
    end
    
    -- Clamp roll to maximum value
    targetRoll = math.Clamp(targetRoll, -cv.maxTilt, cv.maxTilt)
    
    -- Make roll more responsive during dramatic moments - slightly smoother
    local rollBlendSpeed = dramaticMoment and 6 or 4 -- Reduced from 8/5 for smoother transitions
    cv.rollFactor = Lerp(FrameTime() * rollBlendSpeed, cv.rollFactor, targetRoll)
    
    -- Store the last roll angle to preserve it during transitions
    cv.lastRollAngle = cv.rollFactor
    
    -- If we have a stored roll value and we're preserving roll, blend towards it for smooth transition
    if cv.preserveRoll and cv.storedRollValue and not weapon.TransitioningFromSwing then
        cv.rollFactor = Lerp(FrameTime() * 3, cv.rollFactor, cv.storedRollValue)
    end
    
    return cv.rollFactor
end

-- Basic camera roll calculation (used when enhanced roll is disabled)
function CameraSystem.CalculateBasicRoll(weapon, ply, context)
    local cv = weapon.CameraVars
    if not cv then return 0 end
    
    local targetTilt = 0
    
    if cv.onWall then
        -- Add tilt when on walls based on wall normal
        local norm = ply:GetGroundNormal()
        if norm then
            local rightDot = norm:Dot(ply:EyeAngles():Right())
            targetTilt = rightDot * 10
        end
    elseif cv.terrainType == "sloped" or cv.terrainType == "steep" then
        -- Add subtle tilt on slopes
        local vel = ply:GetVelocity()
        if vel:Length() > 100 then
            local rightDot = vel:Dot(ply:EyeAngles():Right())
            targetTilt = -rightDot * 0.005
        end
    end
    
    -- Apply ceiling inversion when crawling on ceiling
    if cv.ceilingCrawling then
        targetTilt = 180 -- Fully inverted
    end
    
    targetTilt = math.Clamp(targetTilt, -cv.maxTilt, cv.maxTilt)
    cv.tiltAngle = Lerp(FrameTime() * 30, cv.tiltAngle, targetTilt)
    
    return cv.tiltAngle
end

-- Calculate view function
function CameraSystem.CalculateView(weapon, ply, pos, angles, fov)
    -- Initialize or get camera variables
    local cv = weapon.CameraVars or CameraSystem.InitializeCamera(weapon)
    if not cv then 
        -- If we still can't get camera vars, use standard view
        return {
            origin = pos - (angles:Forward() * 150) + (angles:Up() * 5),
            angles = angles,
            fov = fov,
            drawviewer = true
        }
    end
    
    -- Ensure pos is valid to prevent nil reference later
    if not pos or not IsValid(ply) then return end
    
    -- Store the base FOV if not set
    if not cv.baseFOV or cv.baseFOV == 0 then
        cv.baseFOV = fov
    end
    
    -- Analyze player context for context-aware camera
    local context = CameraSystem.AnalyzePlayerContext(weapon, ply, pos)
    
    -- Detect dramatic moments for camera effects
    local dramaticMoment, momentType, momentMagnitude = CameraSystem.DetectDramaticMoments(weapon, ply)
    
    -- Ensure all camera values have defaults
    cv.targetDistance = cv.targetDistance or 150
    cv.verticalOffset = cv.verticalOffset or 5
    cv.contextualFOV = cv.contextualFOV or fov
    cv.lastPos = cv.lastPos or pos
    cv.currentAngles = cv.currentAngles or angles
    cv.tiltAngle = cv.tiltAngle or 0
    
    -- Context-Aware Adjustments for Camera Distance, FOV, and Position
    if weapon.MapAnalysis and weapon.MapAnalysis.analyzed then
        -- Base adjustments using original map analysis data
        local buildingDensity = weapon.MapAnalysis.buildingDensity or 0.5
        local openSpaceRatio = weapon.MapAnalysis.openSpaceRatio or 0.5
        
        -- Basic environmental adjustments
        local densityMultiplier = Lerp(buildingDensity, 1.0, 0.8)  -- Nearly full distance in open areas, 20% shorter in dense areas.
        local openMultiplier = Lerp(openSpaceRatio, 1.0, 1.2)      -- Up to 20% extra distance in open areas.
        
        -- Enhanced contextual adjustments based on context type
        local dynamicTargetDistance = cv.targetDistance
        local targetVerticalOffset = cv.verticalOffset
        local targetFOV = cv.baseFOV -- Start with base FOV
        
        -- Context-specific camera adjustments
        if context == "vertical_corridor" then
            -- Tighter camera in vertical corridors with upward angle
            local corridorTightness = 0.7 -- 70% of normal distance
            dynamicTargetDistance = cv.targetDistance * corridorTightness
            targetVerticalOffset = 20 -- Look up more in vertical corridors
            targetFOV = cv.baseFOV * 1.05 -- Slightly wider FOV for better vertical visibility
        elseif context == "wall" then
            -- Wall-running camera with tilt based on wall normal
            local wallRunTightness = 0.85 -- 85% of normal distance
            dynamicTargetDistance = cv.targetDistance * wallRunTightness
            targetVerticalOffset = 0 -- Neutral height on walls
            targetFOV = cv.baseFOV * 1.02 -- Slightly wider FOV for wall running
        elseif context == "ceiling" then
            -- Ceiling crawling - inverted camera
            targetVerticalOffset = -15 -- Look down when on ceiling
            dynamicTargetDistance = cv.targetDistance * 0.8 -- Closer camera when on ceiling
        elseif context == "landmark" then
            -- Landmark framing - pull back to see more context
            dynamicTargetDistance = cv.targetDistance * 1.15 -- Pull back 15% more
            targetFOV = cv.baseFOV * 1.05 -- Slightly wider FOV to see landmark
        elseif context == "fast_moving" then
            -- Fast movement - dynamic FOV and pulled back camera
            dynamicTargetDistance = cv.targetDistance * 1.2 -- Pull back camera more
            -- Speed-based FOV handled by CalculateSpeedFOV function
        elseif context == "moving" then
            -- Regular movement - mild FOV change
            dynamicTargetDistance = cv.targetDistance * 1.05
            -- Speed-based FOV handled by CalculateSpeedFOV function
        elseif context == "slope" then
            -- On slopes - adjust camera angle to compensate for slope
            local slopeCompensation = 5
            if cv.terrainType == "steep" then
                slopeCompensation = 10
            end
            targetVerticalOffset = slopeCompensation
        end
        
        -- Apply environmental adjustments to the context-specific settings
        dynamicTargetDistance = dynamicTargetDistance * densityMultiplier * openMultiplier
        
        -- Apply vertical corridor adjustments if needed
        if weapon.MapAnalysis.verticalityScore and weapon.MapAnalysis.verticalityScore > 0.6 and not cv.isInVerticalCorridor then
            -- In highly vertical maps, increase vertical offset outside of corridors
            targetVerticalOffset = targetVerticalOffset + (weapon.MapAnalysis.verticalityScore - 0.6) * 10
        end
        
        -- Apply ceiling space adjustments
        if weapon.MapAnalysis.ceilingSpaces and weapon.MapAnalysis.ceilingSpaces.ratio and 
           weapon.MapAnalysis.ceilingSpaces.ratio > 0.3 and not cv.ceilingCrawling then
            -- In maps with lots of ceiling space, prepare for vertical play
            targetFOV = targetFOV * (1 + (weapon.MapAnalysis.ceilingSpaces.ratio - 0.3) * 0.1)
        end
        
        -- Calculate speed-based FOV adjustments
        local speedFOV = CameraSystem.CalculateSpeedFOV(weapon, ply, targetFOV)
        
        -- Calculate impact zoom effects for dramatic moments
        local zoomEffect = CameraSystem.CalculateImpactZoom(weapon, ply, dramaticMoment, momentType, momentMagnitude)
        
        -- Apply all FOV effects
        targetFOV = speedFOV + zoomEffect
        
        -- Emit sounds for dramatic moments
        if dramaticMoment then
            local cameraSoundConVar = GetConVar("webswing_camera_sound_effects")
            if cameraSoundConVar and cameraSoundConVar:GetBool() then
                if momentType == "turn" and momentMagnitude > 0.7 then
                    ply:EmitSound("physics/body/body_medium_impact_soft" .. math.random(1, 3) .. ".wav", 50, 120)
                elseif momentType == "dive" and momentMagnitude > 0.8 then
                    ply:EmitSound("physics/body/body_medium_impact_soft" .. math.random(4, 7) .. ".wav", 60, 90)
                end
            end
        end
        
        -- Smoothly adjust the target distance over time (with safety)
        cv.targetDistance = Lerp(FrameTime() * (cv.smoothSpeed or 5), cv.targetDistance, dynamicTargetDistance)
        cv.verticalOffset = Lerp(FrameTime() * (cv.smoothSpeed or 5), cv.verticalOffset, targetVerticalOffset)
        cv.contextualFOV = Lerp(FrameTime() * (cv.smoothSpeed or 5), cv.contextualFOV, targetFOV)
        
        -- Store the contextual FOV
        fov = cv.contextualFOV
    end

    -- Handle transitions and camera smoothing
    if weapon.TransitioningFromSwing then
        if not cv.transitionStartTime then
            cv.transitionStartTime = CurTime()
            cv.transitionStartAngles = angles
            cv.transitionTargetAngles = Angle(0, angles.y, 0)
            
            -- Preserve the roll during transition
            cv.preserveRoll = true
            
            -- Store current roll for consistent preservation
            cv.storedRollValue = cv.tiltAngle or angles.r
        end
        
        -- Increased transition duration from 1.8 to 2.5 seconds
        local transitionDuration = 7
        local elapsed = CurTime() - cv.transitionStartTime
        local progress = math.Clamp(elapsed / transitionDuration, 0, 1)
        
        -- Create new angles but preserve the roll component
        local newAngles = LerpAngle(progress, cv.transitionStartAngles, cv.transitionTargetAngles)
        
        -- When preserving roll, we only update pitch and yaw, not roll
        if cv.preserveRoll then
            -- Use the stored roll value instead of the current angles.r which might be changing
            angles = Angle(newAngles.p, newAngles.y, cv.storedRollValue)
        else
            angles = newAngles
        end
        
        if progress >= 1 then
            weapon.TransitioningFromSwing = false
            cv.transitionStartTime = nil
            cv.transitionStartAngles = nil
            cv.transitionTargetAngles = nil
            -- Don't reset preserveRoll here, keep it true
            -- cv.preserveRoll = false
        end
    end

    if pos and cv.lastPos then
        cv.lastPos = LerpVector(FrameTime() * 10, cv.lastPos, pos)
    else
        cv.lastPos = pos
    end

    if weapon.RagdollActive then
        cv.currentAngles = LerpAngle(FrameTime() * 15, cv.currentAngles, angles)
        local velocity = ply:GetVelocity()
        local rightDot = velocity:Dot(angles:Right())
        local targetTilt = -rightDot * 0.01
        targetTilt = math.Clamp(targetTilt, -cv.maxTilt, cv.maxTilt)
        cv.tiltAngle = Lerp(FrameTime() * 5, cv.tiltAngle, targetTilt)
    else
        -- Calculate enhanced roll effect
        local enhancedRoll = CameraSystem.CalculateEnhancedRoll(weapon, ply, context, dramaticMoment, momentType, momentMagnitude)
        cv.tiltAngle = enhancedRoll
        
        if not weapon.TransitioningFromSwing then
            -- Preserve roll value by only updating pitch and yaw
            cv.currentAngles = Angle(angles.p, angles.y, cv.tiltAngle)
        end
    end

    -- Add slight camera shake during dramatic moments
    local shakeAngles = Angle(0, 0, 0)
    if dramaticMoment then
        local shakeAmount = momentMagnitude * 0.5 -- Maximum 0.5 degrees of shake
        shakeAngles.p = math.Rand(-shakeAmount, shakeAmount)
        shakeAngles.y = math.Rand(-shakeAmount, shakeAmount)
        shakeAngles.r = math.Rand(-shakeAmount, shakeAmount) * 0.5 -- Less roll shake
    end

    -- Construct final angles, preserving roll
    local finalAngles
    if weapon.TransitioningFromSwing then
        -- When transitioning, use the stored roll value for consistency
        local rollValue = cv.storedRollValue or cv.tiltAngle
        finalAngles = Angle(angles.p + shakeAngles.p, angles.y + shakeAngles.y, rollValue + shakeAngles.r)
    else
        finalAngles = Angle(cv.currentAngles.p + shakeAngles.p, cv.currentAngles.y + shakeAngles.y, cv.tiltAngle + shakeAngles.r)
    end
    
    -- Ensure camera values are never nil to prevent multiplication errors
    cv.targetDistance = cv.targetDistance or 150 -- Default if somehow becomes nil
    cv.verticalOffset = cv.verticalOffset or 5   -- Default if somehow becomes nil
    
    local view = {}
    view.origin = cv.lastPos - (finalAngles:Forward() * cv.targetDistance) + (finalAngles:Up() * cv.verticalOffset)
    view.angles = finalAngles
    view.fov = fov
    view.drawviewer = true

    -- Collision detection for camera
    if cv.lastPos and view.origin then  -- Ensure positions are valid before tracing
        local traceData = {
            start = cv.lastPos,
            endpos = view.origin,
            filter = ply
        }
        local trace = util.TraceLine(traceData)
        
        if trace.Hit then
            -- Adjust camera position to prevent clipping through walls
            view.origin = trace.HitPos + trace.HitNormal * 5 -- Push slightly away from the surface
        end
    end

    return view
end

-- Function to start camera transition from swing
function CameraSystem.StartTransitionFromSwing(weapon)
    weapon.TransitioningFromSwing = true
    weapon.CameraTransitionStart = CurTime()
    
    -- Reset any existing transition data while preserving roll
    if weapon.CameraVars then
        weapon.CameraVars.transitionStartTime = nil
        weapon.CameraVars.transitionStartAngles = nil
        weapon.CameraVars.transitionTargetAngles = nil
        weapon.CameraVars.preserveRoll = true -- Ensure roll is preserved
        
        -- Store the current roll angle to maintain it throughout transitions
        weapon.CameraVars.storedRollValue = weapon.CameraVars.tiltAngle or weapon.CameraVars.lastRollAngle or 0
    end
end

-- Function to adjust camera for landmark framing
function CameraSystem.FrameLandmark(weapon, landmark, playerPos)
    if not weapon.CameraVars or not landmark then return nil end
    
    local cv = weapon.CameraVars
    
    -- Calculate direction from player to landmark
    local landmarkDir = (landmark.position - playerPos):GetNormalized()
    
    -- Create an angle that looks at the landmark
    local landmarkAngle = landmarkDir:Angle()
    
    -- Only influence yaw, not pitch
    local targetYaw = landmarkAngle.y
    
    -- Return the target yaw for blending
    return targetYaw
end

-- Get terrain-specific camera settings
function CameraSystem.GetTerrainCameraSettings(terrainType, mapAnalysis)
    local settings = {
        distance = 1.0, -- Multiplier for camera distance
        fov = 1.0,      -- Multiplier for FOV
        vertOffset = 0  -- Vertical offset adjustment
    }
    
    if terrainType == "flat" then
        -- Standard settings for flat ground
        settings.distance = 1.0
        settings.fov = 1.0
        settings.vertOffset = 5
    elseif terrainType == "sloped" then
        -- Slightly pulled back for slopes
        settings.distance = 1.05
        settings.fov = 1.02
        settings.vertOffset = 8
    elseif terrainType == "steep" then
        -- More pulled back for steep slopes
        settings.distance = 1.1
        settings.fov = 1.05
        settings.vertOffset = 12
    elseif terrainType == "wall" then
        -- Tighter for walls
        settings.distance = 0.9
        settings.fov = 1.0
        settings.vertOffset = 0
    elseif terrainType == "air" then
        -- Wide for air
        settings.distance = 1.2
        settings.fov = 1.1
        settings.vertOffset = 0
    end
    
    -- Adjust for map verticality
    if mapAnalysis and mapAnalysis.verticalityScore then
        settings.vertOffset = settings.vertOffset + mapAnalysis.verticalityScore * 5
    end
    
    return settings
end

return CameraSystem