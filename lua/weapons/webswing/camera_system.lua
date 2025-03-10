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
        maxTilt = 15,
        smoothSpeed = 5,
        verticalOffset = 5,
        contextualFOV = 72,
        lastContextState = "", -- Tracks the last contextual state for transitions
        contextTransitionTime = 0, -- Track when context last changed
        isInVerticalCorridor = false,
        nearLandmark = false,
        onWall = false,
        terrainType = "flat",
        ceilingCrawling = false
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
    elseif ply:GetVelocity():Length() > 500 then
        context = "fast_moving"
    end
    
    -- Handle context transitions
    if cv.lastContextState ~= context then
        cv.contextTransitionTime = CurTime()
        cv.lastContextState = context
    end
    
    return context
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
    
    -- Analyze player context for context-aware camera
    local context = CameraSystem.AnalyzePlayerContext(weapon, ply, pos)
    
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
        local targetFOV = fov
        
        -- Context-specific camera adjustments
        if context == "vertical_corridor" then
            -- Tighter camera in vertical corridors with upward angle
            local corridorTightness = 0.7 -- 70% of normal distance
            dynamicTargetDistance = cv.targetDistance * corridorTightness
            targetVerticalOffset = 20 -- Look up more in vertical corridors
            targetFOV = fov * 1.05 -- Slightly wider FOV for better vertical visibility
        elseif context == "wall" then
            -- Wall-running camera with tilt based on wall normal
            local wallRunTightness = 0.85 -- 85% of normal distance
            dynamicTargetDistance = cv.targetDistance * wallRunTightness
            targetVerticalOffset = 0 -- Neutral height on walls
        elseif context == "ceiling" then
            -- Ceiling crawling - inverted camera
            targetVerticalOffset = -15 -- Look down when on ceiling
            dynamicTargetDistance = cv.targetDistance * 0.8 -- Closer camera when on ceiling
        elseif context == "landmark" then
            -- Landmark framing - pull back to see more context
            dynamicTargetDistance = cv.targetDistance * 1.15 -- Pull back 15% more
            targetFOV = fov * 1.05 -- Slightly wider FOV to see landmark
        elseif context == "fast_moving" then
            -- Fast movement - dynamic FOV and pulled back camera
            local speed = ply:GetVelocity():Length()
            local speedFactor = math.Clamp(speed / 1000, 0, 1) -- 0-1 based on speed up to 1000 units/s
            dynamicTargetDistance = Lerp(speedFactor, cv.targetDistance, cv.targetDistance * 1.2)
            targetFOV = Lerp(speedFactor, fov, fov * 1.1) -- Up to 10% wider FOV at high speeds
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
        end
        
        local transitionDuration = 1.0
        local elapsed = CurTime() - cv.transitionStartTime
        local progress = math.Clamp(elapsed / transitionDuration, 0, 1)
        local newAngles = LerpAngle(progress, cv.transitionStartAngles, cv.transitionTargetAngles)
        angles = newAngles
        
        if progress >= 1 then
            weapon.TransitioningFromSwing = false
            cv.transitionStartTime = nil
            cv.transitionStartAngles = nil
            cv.transitionTargetAngles = nil
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
        -- Apply contextual tilting based on terrain and movement
        local targetTilt = 0
        
        if cv.onWall then
            -- Add tilt when on walls based on wall normal
            local norm = ply:GetGroundNormal()
            if norm then
                local rightDot = norm:Dot(angles:Right())
                targetTilt = rightDot * 10
            end
        elseif cv.terrainType == "sloped" or cv.terrainType == "steep" then
            -- Add subtle tilt on slopes
            local vel = ply:GetVelocity()
            if vel:Length() > 100 then
                local rightDot = vel:Dot(angles:Right())
                targetTilt = -rightDot * 0.005
            end
        end
        
        -- Apply ceiling inversion when crawling on ceiling
        if cv.ceilingCrawling then
            targetTilt = 180 -- Fully inverted
        end
        
        targetTilt = math.Clamp(targetTilt, -cv.maxTilt, cv.maxTilt)
        cv.tiltAngle = Lerp(FrameTime() * 30, cv.tiltAngle, targetTilt)
        
        if not weapon.TransitioningFromSwing then
            cv.currentAngles = angles
        end
    end

    local finalAngles = weapon.TransitioningFromSwing and angles or Angle(cv.currentAngles.p, cv.currentAngles.y, cv.tiltAngle)
    
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
    
    -- Reset any existing transition data
    if weapon.CameraVars then
        weapon.CameraVars.transitionStartTime = nil
        weapon.CameraVars.transitionStartAngles = nil
        weapon.CameraVars.transitionTargetAngles = nil
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