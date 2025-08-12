-- PROPER MOMENTUM SYSTEM: Step-by-Step Implementation
-- This replaces the broken momentum system with a simple, effective one

local ProperMomentum = {}

--[[
    STEP 1: CREATE BASIC MOMENTUM DATA STRUCTURE
    
    This is the foundation - keep it SIMPLE and focused on what matters:
    - Current speed
    - Maximum possible speed  
    - How fast we build/lose speed
    - When we last swung (for decay)
]]

-- Basic momentum configuration
ProperMomentum.Config = {
    -- Core speed values (units per second)
    BaseSpeed = 400,        -- Starting speed when you begin swinging
    MaxSpeed = 1200,        -- Maximum speed achievable
    MinSpeed = 200,         -- Minimum speed before you "stall"
    
    -- Speed building rates
    SpeedBuildRate = 80,    -- Speed gained per good swing
    SpeedDecayRate = 150,   -- Speed lost per second when not swinging
    
    -- Timing windows (in seconds)
    PerfectReleaseWindow = 0.25,  -- How long the "perfect" window lasts
    SwingDecayDelay = 1.0,        -- How long before speed starts decaying
    
    -- Bonus values
    PerfectReleaseBonus = 120,    -- Extra speed for perfect timing
    ChainBonusMax = 200,          -- Maximum bonus for chaining swings
    
    -- Failure penalties
    EarlyReleasePenalty = 50,     -- Speed lost for releasing too early
    LateReleasePenalty = 30,      -- Speed lost for releasing too late
}

-- Player momentum state - this tracks the current momentum for each player
ProperMomentum.PlayerStates = {}

function ProperMomentum:GetPlayerState(player)
    if not IsValid(player) then return nil end
    
    local steamID = player:SteamID()
    if not self.PlayerStates[steamID] then
        -- Initialize new player state
        self.PlayerStates[steamID] = {
            currentSpeed = self.Config.BaseSpeed,
            lastSwingTime = 0,
            consecutiveSwings = 0,
            swingStartTime = 0,
            isSwinging = false,
            lastReleaseQuality = "good", -- "perfect", "good", "early", "late"
        }
    end
    
    return self.PlayerStates[steamID]
end

--[[
    STEP 2: IMPLEMENT SPEED TRACKING AND DECAY
    
    This handles the core momentum mechanics:
    - Speed naturally decays when not swinging
    - Speed is maintained while actively swinging
    - Provides the foundation for building/losing momentum
]]

function ProperMomentum:UpdateMomentum(player, frameTime, isCurrentlySwinging)
    local state = self:GetPlayerState(player)
    if not state then return end
    
    local currentTime = CurTime()
    
    -- Update swinging state
    if isCurrentlySwinging and not state.isSwinging then
        -- Just started swinging
        state.swingStartTime = currentTime
        state.isSwinging = true
        state.lastSwingTime = currentTime
    elseif not isCurrentlySwinging and state.isSwinging then
        -- Just stopped swinging
        state.isSwinging = false
    end
    
    -- Apply speed decay when not swinging
    if not state.isSwinging then
        local timeSinceLastSwing = currentTime - state.lastSwingTime
        
        if timeSinceLastSwing > self.Config.SwingDecayDelay then
            -- Start decaying speed
            local decayAmount = self.Config.SpeedDecayRate * frameTime
            state.currentSpeed = math.max(
                state.currentSpeed - decayAmount, 
                self.Config.MinSpeed
            )
        end
    end
    
    -- Clamp speed to valid range
    state.currentSpeed = math.Clamp(
        state.currentSpeed, 
        self.Config.MinSpeed, 
        self.Config.MaxSpeed
    )
end

function ProperMomentum:GetCurrentSpeed(player)
    local state = self:GetPlayerState(player)
    return state and state.currentSpeed or self.Config.BaseSpeed
end

function ProperMomentum:IsInFlowState(player)
    local state = self:GetPlayerState(player)
    if not state then return false end
    
    -- Flow state = high speed + recent swinging
    local timeSinceSwing = CurTime() - state.lastSwingTime
    return state.currentSpeed > (self.Config.MaxSpeed * 0.7) and timeSinceSwing < 2.0
end

--[[
    STEP 3: ADD SWING TIMING DETECTION
    
    This is the heart of skill-based swinging. We need to detect:
    - When the player is at the perfect release point in their swing arc
    - Whether they released early, late, or perfectly
    - The overall quality of their swing timing
]]

function ProperMomentum:CalculateSwingProgress(player, attachPoint)
    if not IsValid(player) or not attachPoint then return 0 end
    
    local playerPos = player:GetPos()
    local ropeVector = attachPoint - playerPos
    local ropeLength = ropeVector:Length()
    
    if ropeLength < 50 then return 0 end -- Too close to calculate
    
    -- Calculate swing angle from vertical
    local ropeDirection = ropeVector:GetNormalized()
    local verticalDot = ropeDirection:Dot(Vector(0, 0, 1))
    local swingAngle = math.acos(math.Clamp(verticalDot, -1, 1))
    
    -- Convert to progress (0 = start of swing, 1 = bottom of arc)
    local maxSwingAngle = math.rad(60) -- 60 degree maximum swing
    local progress = math.Clamp(swingAngle / maxSwingAngle, 0, 1)
    
    return progress
end

function ProperMomentum:CalculateReleaseQuality(player, attachPoint)
    local state = self:GetPlayerState(player)
    if not state or not state.isSwinging then return "none" end
    
    local swingProgress = self:CalculateSwingProgress(player, attachPoint)
    local swingDuration = CurTime() - state.swingStartTime
    
    -- Perfect release zone: between 70-90% of swing arc
    local perfectZoneStart = 0.7
    local perfectZoneEnd = 0.9
    
    -- Good release zone: between 50-95% of swing arc  
    local goodZoneStart = 0.5
    local goodZoneEnd = 0.95
    
    if swingProgress >= perfectZoneStart and swingProgress <= perfectZoneEnd then
        return "perfect"
    elseif swingProgress >= goodZoneStart and swingProgress <= goodZoneEnd then
        return "good"
    elseif swingProgress < goodZoneStart then
        return "early"
    else
        return "late"
    end
end

function ProperMomentum:GetPerfectReleaseProgress(player, attachPoint)
    local progress = self:CalculateSwingProgress(player, attachPoint)
    
    -- Perfect zone is 70-90%, so calculate how close we are to the center (80%)
    local perfectCenter = 0.8
    local perfectRadius = 0.1 -- ±10%
    
    local distanceFromPerfect = math.abs(progress - perfectCenter)
    local perfectness = math.max(0, 1 - (distanceFromPerfect / perfectRadius))
    
    return perfectness, progress
end

function ProperMomentum:IsInPerfectReleaseWindow(player, attachPoint)
    local quality = self:CalculateReleaseQuality(player, attachPoint)
    return quality == "perfect"
end

--[[
    STEP 4: IMPLEMENT PERFECT RELEASE MECHANICS
    
    This is where timing becomes speed. The release quality directly affects momentum:
    - Perfect releases give significant speed boosts
    - Good releases maintain current speed
    - Bad releases penalize speed
]]

function ProperMomentum:OnSwingRelease(player, attachPoint)
    local state = self:GetPlayerState(player)
    if not state then return end
    
    local quality = self:CalculateReleaseQuality(player, attachPoint)
    local perfectness, progress = self:GetPerfectReleaseProgress(player, attachPoint)
    
    -- Store the release quality for feedback systems
    state.lastReleaseQuality = quality
    
    -- Calculate speed change based on release quality
    local speedChange = 0
    
    if quality == "perfect" then
        -- Perfect release: big speed boost
        speedChange = self.Config.PerfectReleaseBonus
        state.consecutiveSwings = state.consecutiveSwings + 1
        
    elseif quality == "good" then
        -- Good release: small speed boost
        speedChange = self.Config.SpeedBuildRate * 0.5
        state.consecutiveSwings = state.consecutiveSwings + 1
        
    elseif quality == "early" then
        -- Early release: speed penalty
        speedChange = -self.Config.EarlyReleasePenalty
        state.consecutiveSwings = 0
        
    elseif quality == "late" then
        -- Late release: smaller speed penalty
        speedChange = -self.Config.LateReleasePenalty
        state.consecutiveSwings = 0
    end
    
    -- Apply consecutive swing bonus
    local consecutiveBonus = math.min(
        state.consecutiveSwings * 10, -- 10 units per consecutive swing
        self.Config.ChainBonusMax
    )
    
    if quality == "perfect" or quality == "good" then
        speedChange = speedChange + consecutiveBonus
    end
    
    -- Apply the speed change
    state.currentSpeed = math.Clamp(
        state.currentSpeed + speedChange,
        self.Config.MinSpeed,
        self.Config.MaxSpeed
    )
    
    -- Return info for feedback systems
    return {
        quality = quality,
        speedChange = speedChange,
        newSpeed = state.currentSpeed,
        consecutiveSwings = state.consecutiveSwings,
        perfectness = perfectness
    }
end

function ProperMomentum:ApplyMomentumToPlayer(player, velocity)
    local state = self:GetPlayerState(player)
    if not state then return velocity end
    
    local currentSpeed = velocity:Length()
    if currentSpeed < 50 then return velocity end -- Don't affect very slow movement
    
    -- Apply momentum speed while preserving direction
    local direction = velocity:GetNormalized()
    local targetSpeed = state.currentSpeed
    
    -- Smooth transition to avoid jarring speed changes
    local blendFactor = 0.8 -- How quickly to apply momentum changes
    local newSpeed = Lerp(blendFactor, currentSpeed, targetSpeed)
    
    return direction * newSpeed
end

--[[
    STEP 5: ADD PROGRESSIVE SPEED BUILDING
    
    This creates the satisfying progression curve that keeps players engaged:
    - Speed builds up gradually over multiple swings
    - Maintaining momentum becomes increasingly rewarding
    - Creates natural skill progression as players get better
]]

function ProperMomentum:CalculateProgressiveSpeedBonus(state)
    local baseBonus = 0
    
    -- Consecutive swing multiplier (increases with each good swing)
    if state.consecutiveSwings > 0 then
        -- Each consecutive swing adds 5% more speed bonus
        local consecutiveMultiplier = 1 + (state.consecutiveSwings * 0.05)
        baseBonus = self.Config.SpeedBuildRate * consecutiveMultiplier
    end
    
    -- Flow state bonus (when already at high speed)
    if state.currentSpeed > (self.Config.MaxSpeed * 0.6) then
        local flowBonus = (state.currentSpeed / self.Config.MaxSpeed) * 20
        baseBonus = baseBonus + flowBonus
    end
    
    -- Cap the total bonus
    return math.min(baseBonus, self.Config.SpeedBuildRate * 2)
end

function ProperMomentum:GetMomentumTier(player)
    local state = self:GetPlayerState(player)
    if not state then return "none" end
    
    local speedRatio = state.currentSpeed / self.Config.MaxSpeed
    
    if speedRatio >= 0.9 then
        return "legendary"    -- 90%+ of max speed
    elseif speedRatio >= 0.75 then
        return "master"       -- 75-90% of max speed
    elseif speedRatio >= 0.6 then
        return "expert"       -- 60-75% of max speed
    elseif speedRatio >= 0.4 then
        return "skilled"      -- 40-60% of max speed
    elseif speedRatio >= 0.2 then
        return "learning"     -- 20-40% of max speed
    else
        return "beginner"     -- Below 20% of max speed
    end
end

function ProperMomentum:CalculateComboMultiplier(state)
    -- Perfect swings in a row create combo multipliers
    local perfectCount = 0
    local recentReleases = state.recentReleases or {}
    
    -- Count recent perfect releases
    for _, release in ipairs(recentReleases) do
        if release.quality == "perfect" and (CurTime() - release.time) < 10 then
            perfectCount = perfectCount + 1
        else
            break -- Stop at first non-perfect
        end
    end
    
    -- Each perfect release in combo adds 10% bonus
    return math.min(1 + (perfectCount * 0.1), 2.0) -- Max 2x multiplier
end

function ProperMomentum:OnSwingReleaseAdvanced(player, attachPoint)
    local state = self:GetPlayerState(player)
    if not state then return end
    
    -- Initialize recent releases tracking
    if not state.recentReleases then
        state.recentReleases = {}
    end
    
    local quality = self:CalculateReleaseQuality(player, attachPoint)
    local perfectness, progress = self:GetPerfectReleaseProgress(player, attachPoint)
    
    -- Record this release
    table.insert(state.recentReleases, 1, {
        quality = quality,
        time = CurTime(),
        perfectness = perfectness
    })
    
    -- Keep only last 10 releases
    while #state.recentReleases > 10 do
        table.remove(state.recentReleases)
    end
    
    -- Calculate speed change with progressive bonuses
    local baseSpeedChange = 0
    
    if quality == "perfect" then
        baseSpeedChange = self.Config.PerfectReleaseBonus
        state.consecutiveSwings = state.consecutiveSwings + 1
    elseif quality == "good" then
        baseSpeedChange = self.Config.SpeedBuildRate * 0.5
        state.consecutiveSwings = state.consecutiveSwings + 1
    else
        -- Bad release resets combo
        state.consecutiveSwings = 0
        if quality == "early" then
            baseSpeedChange = -self.Config.EarlyReleasePenalty
        elseif quality == "late" then
            baseSpeedChange = -self.Config.LateReleasePenalty
        end
    end
    
    -- Apply progressive bonuses
    if quality == "perfect" or quality == "good" then
        local progressiveBonus = self:CalculateProgressiveSpeedBonus(state)
        local comboMultiplier = self:CalculateComboMultiplier(state)
        
        baseSpeedChange = (baseSpeedChange + progressiveBonus) * comboMultiplier
    end
    
    -- Apply the final speed change
    local oldSpeed = state.currentSpeed
    state.currentSpeed = math.Clamp(
        state.currentSpeed + baseSpeedChange,
        self.Config.MinSpeed,
        self.Config.MaxSpeed
    )
    
    -- Store quality for feedback
    state.lastReleaseQuality = quality
    
    return {
        quality = quality,
        speedChange = baseSpeedChange,
        oldSpeed = oldSpeed,
        newSpeed = state.currentSpeed,
        consecutiveSwings = state.consecutiveSwings,
        perfectness = perfectness,
        tier = self:GetMomentumTier(player),
        comboMultiplier = self:CalculateComboMultiplier(state)
    }
end

--[[
    STEP 6: CREATE FAILURE STATES AND RECOVERY
    
    Good games have meaningful failure states but also clear paths to recovery:
    - Missing swings or hitting obstacles should have consequences
    - Players should be able to recover from mistakes through skill
    - Stalling should be uncomfortable but not game-ending
]]

function ProperMomentum:OnSwingMiss(player, reason)
    local state = self:GetPlayerState(player)
    if not state then return end
    
    -- Different penalties for different types of failures
    local speedPenalty = 0
    
    if reason == "no_target" then
        -- Tried to swing but no valid target
        speedPenalty = self.Config.SpeedBuildRate * 0.5
    elseif reason == "obstacle_hit" then
        -- Hit an obstacle during swing
        speedPenalty = self.Config.SpeedBuildRate * 1.2
    elseif reason == "ground_hit" then
        -- Hit the ground during swing
        speedPenalty = self.Config.SpeedBuildRate * 0.8
    elseif reason == "web_break" then
        -- Web broke during swing
        speedPenalty = self.Config.SpeedBuildRate * 1.5
    end
    
    -- Reset consecutive swings on failure
    state.consecutiveSwings = 0
    
    -- Apply speed penalty
    state.currentSpeed = math.max(
        state.currentSpeed - speedPenalty,
        self.Config.MinSpeed
    )
    
    return {
        reason = reason,
        speedPenalty = speedPenalty,
        newSpeed = state.currentSpeed
    }
end

function ProperMomentum:IsInStallState(player)
    local state = self:GetPlayerState(player)
    if not state then return false end
    
    -- Stalling = low speed + not swinging recently
    local timeSinceSwing = CurTime() - state.lastSwingTime
    local lowSpeed = state.currentSpeed <= (self.Config.MinSpeed * 1.2)
    local notSwingingRecently = timeSinceSwing > 3.0
    
    return lowSpeed and notSwingingRecently
end

function ProperMomentum:GetRecoveryBonus(player)
    local state = self:GetPlayerState(player)
    if not state then return 0 end
    
    -- Give small bonus for first swing after stalling
    if self:IsInStallState(player) then
        return self.Config.SpeedBuildRate * 0.3 -- 30% bonus to help recovery
    end
    
    return 0
end

function ProperMomentum:OnObstacleHit(player, obstacleType, hitVelocity)
    local state = self:GetPlayerState(player)
    if not state then return end
    
    local hitSpeed = hitVelocity:Length()
    
    -- Harder hits = bigger penalties
    local speedPenalty = math.min(hitSpeed * 0.3, self.Config.SpeedBuildRate * 2)
    
    -- Different obstacle types have different penalties
    local obstacleMultiplier = 1.0
    if obstacleType == "wall" then
        obstacleMultiplier = 1.0
    elseif obstacleType == "ground" then
        obstacleMultiplier = 0.7  -- Ground hits are less severe
    elseif obstacleType == "ceiling" then
        obstacleMultiplier = 1.2  -- Ceiling hits are worse
    end
    
    speedPenalty = speedPenalty * obstacleMultiplier
    
    -- Reset consecutive swings
    state.consecutiveSwings = 0
    
    -- Apply penalty
    state.currentSpeed = math.max(
        state.currentSpeed - speedPenalty,
        self.Config.MinSpeed
    )
    
    return {
        hitSpeed = hitSpeed,
        obstacleType = obstacleType,
        speedPenalty = speedPenalty,
        newSpeed = state.currentSpeed
    }
end

function ProperMomentum:CanRecoverFromStall(player)
    local state = self:GetPlayerState(player)
    if not state then return false end
    
    -- Players can always attempt recovery, but success depends on execution
    return true
end

function ProperMomentum:GetFailureReason(player)
    local state = self:GetPlayerState(player)
    if not state then return "none" end
    
    local currentSpeed = state.currentSpeed
    local timeSinceSwing = CurTime() - state.lastSwingTime
    
    if currentSpeed <= self.Config.MinSpeed and timeSinceSwing > 5 then
        return "stalled" -- Player has completely stalled out
    elseif currentSpeed < (self.Config.BaseSpeed * 0.8) and timeSinceSwing > 3 then
        return "struggling" -- Player is having trouble maintaining momentum
    elseif state.consecutiveSwings == 0 and timeSinceSwing < 2 then
        return "recovering" -- Player just made a mistake but is attempting recovery
    else
        return "none" -- No failure state
    end
end

--[[
    STEP 7: ADD VISUAL AND AUDIO FEEDBACK
    
    Players need immediate, clear feedback about their momentum state:
    - Visual indicators for momentum tier and perfect release windows
    - Audio cues for successful/failed swings
    - Screen effects for flow states
    - Clear information about current momentum
]]

-- Visual feedback functions
function ProperMomentum:GetSpeedIndicatorColor(player)
    local tier = self:GetMomentumTier(player)
    
    if tier == "legendary" then
        return Color(255, 215, 0, 255)    -- Gold
    elseif tier == "master" then
        return Color(255, 20, 147, 255)   -- Deep Pink
    elseif tier == "expert" then
        return Color(138, 43, 226, 255)   -- Blue Violet
    elseif tier == "skilled" then
        return Color(0, 191, 255, 255)    -- Deep Sky Blue
    elseif tier == "learning" then
        return Color(50, 205, 50, 255)    -- Lime Green
    else -- beginner
        return Color(255, 255, 255, 255)  -- White
    end
end

function ProperMomentum:GetReleaseWindowIndicator(player, attachPoint)
    local perfectness, progress = self:GetPerfectReleaseProgress(player, attachPoint)
    local quality = self:CalculateReleaseQuality(player, attachPoint)
    
    return {
        perfectness = perfectness,
        progress = progress,
        quality = quality,
        color = (quality == "perfect") and Color(0, 255, 0, 200) or Color(255, 255, 0, 150),
        size = Lerp(perfectness, 5, 15) -- Bigger indicator when in perfect zone
    }
end

function ProperMomentum:DrawMomentumHUD(player)
    if not IsValid(player) then return end
    
    local state = self:GetPlayerState(player)
    if not state then return end
    
    -- Only show on client side
    if CLIENT then
        local scrW, scrH = ScrW(), ScrH()
        
        -- Speed bar background
        local barX, barY = scrW * 0.05, scrH * 0.8
        local barW, barH = scrW * 0.3, 20
        
        surface.SetDrawColor(0, 0, 0, 150)
        surface.DrawRect(barX, barY, barW, barH)
        
        -- Speed bar fill
        local speedRatio = state.currentSpeed / self.Config.MaxSpeed
        local fillW = barW * speedRatio
        local speedColor = self:GetSpeedIndicatorColor(player)
        
        surface.SetDrawColor(speedColor.r, speedColor.g, speedColor.b, speedColor.a)
        surface.DrawRect(barX, barY, fillW, barH)
        
        -- Speed text
        local tier = self:GetMomentumTier(player)
        local speedText = string.format("%s (%.0f)", tier:upper(), state.currentSpeed)
        
        surface.SetTextColor(255, 255, 255, 255)
        surface.SetTextPos(barX, barY - 25)
        surface.DrawText(speedText)
        
        -- Consecutive swings counter
        if state.consecutiveSwings > 0 then
            local comboText = string.format("COMBO x%d", state.consecutiveSwings)
            surface.SetTextColor(255, 215, 0, 255) -- Gold
            surface.SetTextPos(barX, barY + barH + 5)
            surface.DrawText(comboText)
        end
        
        -- Perfect release indicator (when swinging)
        if state.isSwinging then
            local centerX, centerY = scrW * 0.5, scrH * 0.5
            
            -- Draw swing progress arc
            local progress = self:CalculateSwingProgress(player, self.lastAttachPoint)
            local perfectZoneStart = 0.7
            local perfectZoneEnd = 0.9
            
            -- Arc settings
            local arcRadius = 60
            local arcThickness = 8
            
            -- Helper function to draw arc segments
            local function DrawArcSegment(startAngle, endAngle, color, thickness)
                local segments = math.max(8, math.ceil((endAngle - startAngle) / 5)) -- More segments for smoother arcs
                
                for i = 0, segments - 1 do
                    local angle1 = startAngle + (endAngle - startAngle) * (i / segments)
                    local angle2 = startAngle + (endAngle - startAngle) * ((i + 1) / segments)
                    
                    local x1 = centerX + math.cos(math.rad(angle1)) * arcRadius
                    local y1 = centerY + math.sin(math.rad(angle1)) * arcRadius
                    local x2 = centerX + math.cos(math.rad(angle2)) * arcRadius
                    local y2 = centerY + math.sin(math.rad(angle2)) * arcRadius
                    
                    surface.SetDrawColor(color.r, color.g, color.b, color.a)
                    
                    -- Draw thick line by drawing multiple offset lines
                    for offset = -thickness/2, thickness/2, 1 do
                        local offsetX = math.cos(math.rad(angle1 + 90)) * offset
                        local offsetY = math.sin(math.rad(angle1 + 90)) * offset
                        surface.DrawLine(x1 + offsetX, y1 + offsetY, x2 + offsetX, y2 + offsetY)
                    end
                end
            end
            
            -- Draw the full swing arc (background)
            DrawArcSegment(-90, 90, Color(50, 50, 50, 100), 4)
            
            -- Draw the perfect zone (green)
            local perfectStartAngle = -90 + (perfectZoneStart * 180)
            local perfectEndAngle = -90 + (perfectZoneEnd * 180)
            DrawArcSegment(perfectStartAngle, perfectEndAngle, Color(0, 255, 0, 180), arcThickness)
            
            -- Draw good zone (yellow) - areas just outside perfect
            local goodZoneStart = 0.5
            local goodZoneEnd = 0.95
            local goodStartAngle = -90 + (goodZoneStart * 180)
            local goodEndAngle = -90 + (goodZoneEnd * 180)
            
            -- Good zone before perfect zone
            if goodZoneStart < perfectZoneStart then
                DrawArcSegment(goodStartAngle, perfectStartAngle, Color(255, 255, 0, 120), 6)
            end
            -- Good zone after perfect zone  
            if perfectZoneEnd < goodZoneEnd then
                DrawArcSegment(perfectEndAngle, goodEndAngle, Color(255, 255, 0, 120), 6)
            end
            
            -- Current progress indicator with dynamic sizing and color
            local currentAngle = -90 + (progress * 180)
            local indicatorX = centerX + math.cos(math.rad(currentAngle)) * arcRadius
            local indicatorY = centerY + math.sin(math.rad(currentAngle)) * arcRadius
            
            -- Color based on timing quality
            local quality = self:CalculateReleaseQuality(player, self.lastAttachPoint or Vector(0,0,0))
            local indicatorColor = Color(255, 255, 255, 255)
            local indicatorSize = 8
            
            if quality == "perfect" then
                indicatorColor = Color(0, 255, 0, 255)
                indicatorSize = 12
                -- Add pulsing effect
                indicatorSize = indicatorSize + math.sin(CurTime() * 8) * 3
            elseif quality == "good" then
                indicatorColor = Color(255, 255, 0, 255)
                indicatorSize = 10
            elseif quality == "early" then
                indicatorColor = Color(255, 100, 100, 255)
            elseif quality == "late" then
                indicatorColor = Color(255, 150, 0, 255)
            end
            
            -- Draw indicator with glow effect
            for glow = indicatorSize + 4, indicatorSize, -1 do
                local alpha = (indicatorSize + 4 - glow) * 20
                surface.SetDrawColor(indicatorColor.r, indicatorColor.g, indicatorColor.b, alpha)
                surface.DrawCircle(indicatorX, indicatorY, glow)
            end
            
            -- Draw center indicator dot
            surface.SetDrawColor(indicatorColor.r, indicatorColor.g, indicatorColor.b, 255)
            surface.DrawCircle(indicatorX, indicatorY, indicatorSize)
            
            -- Add text labels for clarity
            surface.SetTextColor(255, 255, 255, 200)
            surface.SetTextPos(centerX - 50, centerY + arcRadius + 20)
            surface.DrawText("Perfect Release Zone")
            
            -- Show current timing quality
            surface.SetTextColor(indicatorColor.r, indicatorColor.g, indicatorColor.b, 255)
            surface.SetTextPos(centerX - 30, centerY - arcRadius - 30)
            surface.DrawText(quality:upper())
        end
    end
end

-- Audio feedback functions
function ProperMomentum:PlayReleaseSound(player, quality, tier)
    -- DISABLED: Audio feedback removed per user request
    -- No more beeps and boops after swing releases
end

function ProperMomentum:PlayTierUpSound(player, newTier)
    -- DISABLED: Audio feedback removed per user request
    -- No more beeps and boops for tier changes
end

function ProperMomentum:PlayStallSound(player)
    -- DISABLED: Audio feedback removed per user request
    -- No more beeps and boops for stalling
end

-- Enhanced release function with feedback
function ProperMomentum:OnSwingReleaseWithFeedback(player, attachPoint)
    local releaseInfo = self:OnSwingReleaseAdvanced(player, attachPoint)
    if not releaseInfo then return end
    
    local state = self:GetPlayerState(player)
    local previousTier = state.previousTier or "beginner"
    local currentTier = releaseInfo.tier
    
    -- Play release sound
    self:PlayReleaseSound(player, releaseInfo.quality, currentTier)
    
    -- Play tier up sound if improved
    if currentTier ~= previousTier then
        local tierOrder = {"beginner", "learning", "skilled", "expert", "master", "legendary"}
        local prevIndex = 1
        local currIndex = 1
        
        for i, tier in ipairs(tierOrder) do
            if tier == previousTier then prevIndex = i end
            if tier == currentTier then currIndex = i end
        end
        
        if currIndex > prevIndex then
            self:PlayTierUpSound(player, currentTier)
        end
    end
    
    -- Store for next comparison
    state.previousTier = currentTier
    
    return releaseInfo
end

--[[
    STEP 8: BALANCE AND POLISH THE SYSTEM
    
    The final step is tuning everything to feel perfect. Here's how to balance each aspect:
]]

-- Balance testing functions
function ProperMomentum:RunBalanceTest(player, testType)
    local state = self:GetPlayerState(player)
    if not state then return end
    
    if testType == "speed_build" then
        -- Test how long it takes to reach max speed with perfect swings
        state.currentSpeed = self.Config.BaseSpeed
        state.consecutiveSwings = 0
        
        local swingsToMax = 0
        while state.currentSpeed < self.Config.MaxSpeed and swingsToMax < 20 do
            local mockRelease = {
                quality = "perfect",
                speedChange = self.Config.PerfectReleaseBonus,
                consecutiveSwings = state.consecutiveSwings + 1
            }
            state.currentSpeed = math.min(
                state.currentSpeed + self.Config.PerfectReleaseBonus + (state.consecutiveSwings * 10),
                self.Config.MaxSpeed
            )
            state.consecutiveSwings = state.consecutiveSwings + 1
            swingsToMax = swingsToMax + 1
        end
        
        print("Swings to reach max speed:", swingsToMax)
        
    elseif testType == "decay_time" then
        -- Test how long it takes to lose all momentum
        state.currentSpeed = self.Config.MaxSpeed
        local timeToMin = self.Config.MaxSpeed / self.Config.SpeedDecayRate
        print("Time to decay from max to min:", timeToMin, "seconds")
        
    elseif testType == "recovery_time" then
        -- Test recovery from stall
        state.currentSpeed = self.Config.MinSpeed
        state.consecutiveSwings = 0
        local recoveryBonus = self:GetRecoveryBonus(player)
        print("Recovery bonus from stall:", recoveryBonus)
    end
end

-- Balancing guidelines and recommended values
ProperMomentum.BalanceGuides = {
    -- SPEED BUILDING BALANCE
    -- Good rule: Should take 4-6 perfect swings to reach max speed
    -- Calculation: (MaxSpeed - BaseSpeed) / (PerfectReleaseBonus + average consecutive bonus)
    speedBuildTime = {
        recommended_swings_to_max = 5,
        current_calculation = function(config)
            local speedGap = config.MaxSpeed - config.BaseSpeed
            local avgBonus = config.PerfectReleaseBonus + (3 * 10) -- Assume 3 average consecutive
            return math.ceil(speedGap / avgBonus)
        end
    },
    
    -- DECAY BALANCE  
    -- Good rule: Should take 8-12 seconds to decay from max to min when not swinging
    -- Calculation: (MaxSpeed - MinSpeed) / SpeedDecayRate
    decayTime = {
        recommended_seconds = 10,
        current_calculation = function(config)
            return (config.MaxSpeed - config.MinSpeed) / config.SpeedDecayRate
        end
    },
    
    -- TIMING WINDOW BALANCE
    -- Good rule: Perfect window should be 15-25% of total swing arc
    -- Current: 70-90% = 20% window (good!)
    timingWindow = {
        recommended_percentage = 0.2, -- 20% of swing arc
        current_window = 0.2 -- 90% - 70% = 20%
    },
    
    -- FAILURE PENALTY BALANCE
    -- Good rule: One bad swing should undo 1-2 good swings worth of progress
    failurePenalty = {
        recommended_ratio = 1.5, -- 1.5x a good swing's benefit
        early_penalty_vs_good_swing = function(config)
            return config.EarlyReleasePenalty / (config.SpeedBuildRate * 0.5)
        end
    }
}

-- Auto-balance function that suggests improvements
function ProperMomentum:AnalyzeBalance()
    local config = self.Config
    local guides = self.BalanceGuides
    
    print("=== MOMENTUM SYSTEM BALANCE ANALYSIS ===")
    
    -- Speed building analysis
    local swingsToMax = guides.speedBuildTime.current_calculation(config)
    print("Swings to reach max speed:", swingsToMax)
    if swingsToMax < 4 then
        print("WARNING: Too easy to reach max speed. Consider:")
        print("  - Increase MaxSpeed from", config.MaxSpeed, "to", config.MaxSpeed * 1.3)
        print("  - Decrease PerfectReleaseBonus from", config.PerfectReleaseBonus, "to", config.PerfectReleaseBonus * 0.8)
    elseif swingsToMax > 8 then
        print("WARNING: Too hard to reach max speed. Consider:")
        print("  - Decrease MaxSpeed from", config.MaxSpeed, "to", config.MaxSpeed * 0.9)
        print("  - Increase PerfectReleaseBonus from", config.PerfectReleaseBonus, "to", config.PerfectReleaseBonus * 1.2)
    else
        print("✓ Speed building is well balanced")
    end
    
    -- Decay analysis
    local decayTime = guides.decayTime.current_calculation(config)
    print("Decay time from max to min:", decayTime, "seconds")
    if decayTime < 6 then
        print("WARNING: Speed decays too quickly. Consider:")
        print("  - Decrease SpeedDecayRate from", config.SpeedDecayRate, "to", config.SpeedDecayRate * 0.7)
        print("  - Increase SwingDecayDelay from", config.SwingDecayDelay, "to", config.SwingDecayDelay * 1.5)
    elseif decayTime > 15 then
        print("WARNING: Speed decays too slowly. Consider:")
        print("  - Increase SpeedDecayRate from", config.SpeedDecayRate, "to", config.SpeedDecayRate * 1.3)
    else
        print("✓ Decay timing is well balanced")
    end
    
    -- Penalty analysis
    local penaltyRatio = guides.failurePenalty.early_penalty_vs_good_swing(config)
    print("Early release penalty vs good swing benefit ratio:", penaltyRatio)
    if penaltyRatio < 1 then
        print("WARNING: Penalties too weak. Consider:")
        print("  - Increase EarlyReleasePenalty from", config.EarlyReleasePenalty, "to", config.EarlyReleasePenalty * 1.5)
    elseif penaltyRatio > 3 then
        print("WARNING: Penalties too harsh. Consider:")
        print("  - Decrease EarlyReleasePenalty from", config.EarlyReleasePenalty, "to", config.EarlyReleasePenalty * 0.7)
    else
        print("✓ Failure penalties are well balanced")
    end
    
    print("=== END ANALYSIS ===")
end

-- Recommended balanced config
ProperMomentum.RecommendedConfig = {
    BaseSpeed = 400,
    MaxSpeed = 1000,        -- Reduced from 1200 for better balance
    MinSpeed = 200,
    SpeedBuildRate = 60,    -- Reduced from 80 for more gradual building
    SpeedDecayRate = 80,    -- Reduced from 150 for less harsh decay
    PerfectReleaseBonus = 100, -- Reduced from 120 for better balance
    SwingDecayDelay = 1.5,  -- Increased from 1.0 for more forgiveness
    ChainBonusMax = 150,    -- Reduced from 200 to prevent overpowering
    EarlyReleasePenalty = 45, -- Reduced from 50 for less harsh punishment
    LateReleasePenalty = 25,  -- Reduced from 30 for less harsh punishment
    PerfectReleaseWindow = 0.25 -- Keep the same - it's good!
}

-- Apply recommended balance
function ProperMomentum:ApplyRecommendedBalance()
    self.Config = table.Copy(self.RecommendedConfig)
    print("Applied recommended balance settings!")
end

--[[
    FINAL INTEGRATION GUIDE:
    
    Replace your current momentum system with this one:
    
    1. In shared.lua, include this system:
       local ProperMomentum = include("momentum_system.lua")
       self.ProperMomentum = ProperMomentum
    
    2. In your Think() function:
       self.ProperMomentum:UpdateMomentum(self.Owner, FrameTime(), self.RagdollActive)
    
    3. In your swing release function:
       local releaseInfo = self.ProperMomentum:OnSwingReleaseWithFeedback(self.Owner, self.AttachPoint)
       if releaseInfo then
           local newVel = self.ProperMomentum:ApplyMomentumToPlayer(self.Owner, self.Owner:GetVelocity())
           self.Owner:SetVelocity(newVel)
       end
    
    4. In your collision detection:
       self.ProperMomentum:OnObstacleHit(self.Owner, "wall", hitVelocity)
    
    5. In your HUD drawing (cl_init.lua):
       function SWEP:DrawHUD()
           if IsValid(self.ProperMomentum) then
               self.ProperMomentum:DrawMomentumHUD(self.Owner)
           end
       end
    
    6. Run balance analysis:
       self.ProperMomentum:AnalyzeBalance()
       -- Then apply recommended settings if needed:
       self.ProperMomentum:ApplyRecommendedBalance()
    
    CONGRATULATIONS! You now have a proper momentum system that:
    ✓ Rewards skill and timing
    ✓ Provides clear progression
    ✓ Has meaningful failure states
    ✓ Gives immediate feedback
    ✓ Is properly balanced and tunable
    
    Your players will finally feel like their skill matters!
]]

--[[
    WHY FEEDBACK MATTERS:
    
    1. IMMEDIATE CLARITY: Players instantly know how they did
    2. MOTIVATION: Positive feedback encourages continued play
    3. LEARNING AID: Clear signals help players improve timing
    4. SATISFACTION: Good feedback makes successes feel rewarding
]]

--[[
    WHY FAILURE STATES WORK:
    
    1. MEANINGFUL CONSEQUENCES: Mistakes have clear, immediate impact
    2. LEARNING OPPORTUNITIES: Failures teach players what not to do
    3. RECOVERY PATHS: Players can always work their way back up
    4. SKILL DIFFERENTIATION: Good players avoid failures, great players recover quickly
]]

--[[
    WHY PROGRESSIVE BUILDING WORKS:
    
    1. ESCALATING REWARDS: Each good swing makes the next one more valuable
    2. FLOW STATE: Once you get going, momentum becomes easier to maintain
    3. SKILL EXPRESSION: Advanced players can achieve higher tiers consistently
    4. COMEBACK MECHANICS: Even after mistakes, you can rebuild momentum
]]

--[[
    WHY PERFECT RELEASE MECHANICS WORK:
    
    1. IMMEDIATE REWARD: Good timing gives instant speed boost
    2. CLEAR CONSEQUENCE: Bad timing has immediate penalty
    3. SKILL EXPRESSION: Players can "feel" their improvement
    4. MOMENTUM BUILDING: Consecutive good swings compound the effect
]]

--[[
    WHY SWING TIMING MATTERS:
    
    1. SKILL PROGRESSION: Players get better by learning when to release
    2. CLEAR FEEDBACK: Visual/audio cues tell players how they did
    3. RISK/REWARD: Early release is safe but slow, perfect timing is risky but fast
    4. MUSCLE MEMORY: Consistent timing builds satisfying muscle memory
]]

--[[
    WHY STEP 2 WORKS:
    
    1. PREDICTABLE DECAY: Players know exactly what will happen if they stop swinging
    2. IMMEDIATE FEEDBACK: Speed changes are visible and felt right away  
    3. FLOW STATE: Rewards maintaining momentum, but doesn't punish brief pauses
    4. SIMPLE MATH: Easy to understand and debug
]]

--[[
    STEP 1: CREATE BASIC MOMENTUM DATA STRUCTURE
    
    This is the foundation - keep it SIMPLE and focused on what matters:
    - Current speed
    - Maximum possible speed  
    - How fast we build/lose speed
    - When we last swung (for decay)
]]

return ProperMomentum
