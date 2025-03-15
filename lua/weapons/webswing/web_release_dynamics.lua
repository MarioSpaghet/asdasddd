-- Web Release Dynamics System
-- Creates more satisfying and controllable web releases

local WebReleaseDynamics = {}

-- Configuration
WebReleaseDynamics.Config = {
    -- Core Release Parameters
    MomentumConservation = 1.25,       -- How well momentum is preserved when releasing (1.0 = default, higher = better preservation)
    DirectionalInfluence = 0.35,        -- How much player input affects release direction (0.0-1.0)
    OptimalReleaseBonus = 1.3,          -- Speed multiplier for perfect timing (1.0 = no bonus)
    
    -- Release Types
    EnableReleaseTypes = true,          -- Enable different release behaviors based on input
    StandardReleaseMult = 1.0,          -- Base multiplier for standard releases
    BoostReleaseMult = 1.35,            -- Speed multiplier for boost releases (Jump + Forward)
    DiveReleaseMult = 1.25,             -- Speed multiplier for dive releases (Jump + Down)
    UpwardReleaseMult = 1.2,            -- Speed multiplier for upward releases (Jump + Up)
    
    -- Release Point Scoring
    MaxReleaseScore = 100,              -- Maximum points for a perfect release
    OptimalReleasePhaseEarly = 0.35,    -- First optimal phase for release (0-1)
    OptimalReleasePhaseMiddle = 0.5,    -- Middle optimal phase for release (0-1)
    OptimalReleasePhaseLate = 0.65,     -- Second optimal phase for release (0-1)
    ReleaseScoreThreshold = 75,         -- Score needed for optimal release effects
    
    -- Visual and Audio Effects
    EnableVisualFeedback = true,        -- Enable visual effects for releases
    EnableBoostLines = true,            -- Enable speed lines effect on powerful releases
    EnableAudioFeedback = true,         -- Enable sound effects for different release qualities
    EnableSlowMotion = true,            -- Enable brief slow motion on perfect releases
    SlowMotionDuration = 0.15,          -- Duration of slow motion effect (seconds)
    SlowMotionTimescale = 0.4,          -- How slow time moves during effect (0.0-1.0)
    
    -- Release Recovery
    RecoveryDuration = 0.3,             -- Time window after release for further adjustments (seconds)
    AirControlBoost = 1.4,              -- Increased air control after release
    GravityDelayTime = 0.2,             -- Time to delay normal gravity after release (seconds)
    PostReleaseGravity = 0.7,           -- Gravity multiplier immediately after release
    
    -- Advanced Release Dynamics
    MidairCorrectionStrength = 0.3,     -- Ability to adjust trajectory after release (0.0-1.0)
    ChainReleaseBonus = 1.15,           -- Speed bonus for chaining multiple well-timed releases
    ChainTimeWindow = 1.5,              -- Time window to maintain chain bonus (seconds)
    MaxChainBonus = 1.5,                -- Maximum cumulative chain bonus
    SkillExpression = true              -- Enable skill expression through release mechanics
}

-- State variables
WebReleaseDynamics.State = {
    LastReleaseTime = 0,                -- When the last web was released
    LastReleaseScore = 0,               -- Quality score of the last release (0-100)
    LastReleasePhase = 0,               -- Swing phase at last release (0-1)
    LastReleaseVelocity = Vector(0,0,0),-- Velocity at last release
    ReleaseType = "standard",           -- Type of the last release
    ChainCount = 0,                     -- Current chain of well-timed releases
    ChainBonus = 1.0,                   -- Current chain bonus multiplier
    LastChainTime = 0,                  -- When the last chain release occurred
    InRecoveryPhase = false,            -- Whether player is in post-release recovery
    RecoveryStartTime = 0,              -- When recovery phase started
    RecoveryVelocity = Vector(0,0,0),   -- Initial velocity at start of recovery
    IsSlowMotionActive = false,         -- Whether slow motion effect is active
    SlowMotionStartTime = 0,            -- When slow motion started
    ReleaseEffectsActive = {            -- Currently active release effects
        boost = false,
        dive = false,
        upward = false,
        perfect = false
    },
    PerfectReleaseActive = false,       -- Whether a perfect release is active
    PerfectReleaseStartTime = 0,        -- When perfect release started
    CumulativeScore = 0,                -- Running score for releases (for achievements/rewards)
    HighScore = 0                       -- Best release score in this session
}

-- Initialize the web release system
function WebReleaseDynamics:Initialize()
    -- Reset state variables
    self:ResetState()
    
    -- Load ConVar settings
    self:LoadConVarSettings()
    
    -- Register needed hooks
    hook.Add("Move", "WebReleaseDynamics_ModifyMovement", function(ply, mv)
        -- Only affect local player, only during recovery phase
        if CLIENT and IsValid(ply) and ply == LocalPlayer() and self.State.InRecoveryPhase then
            self:ModifyPostReleaseMovement(ply, mv)
        end
    end)
    
    return self
end

-- Reset state variables to defaults
function WebReleaseDynamics:ResetState()
    self.State.LastReleaseTime = 0
    self.State.LastReleaseScore = 0
    self.State.LastReleasePhase = 0
    self.State.LastReleaseVelocity = Vector(0,0,0)
    self.State.ReleaseType = "standard"
    self.State.ChainCount = 0
    self.State.ChainBonus = 1.0
    self.State.LastChainTime = 0
    self.State.InRecoveryPhase = false
    self.State.RecoveryStartTime = 0
    self.State.RecoveryVelocity = Vector(0,0,0)
    self.State.IsSlowMotionActive = false
    self.State.SlowMotionStartTime = 0
    self.State.ReleaseEffectsActive = {
        boost = false,
        dive = false,
        upward = false,
        perfect = false
    }
    self.State.PerfectReleaseActive = false
    self.State.PerfectReleaseStartTime = 0
    self.State.CumulativeScore = 0
end

-- Load settings from ConVars
function WebReleaseDynamics:LoadConVarSettings()
    -- Load values from global ConVars if they exist
    if ConVarExists("webswing_release_momentum") then
        self.Config.MomentumConservation = GetConVar("webswing_release_momentum"):GetFloat()
    end
    
    if ConVarExists("webswing_release_direction") then
        self.Config.DirectionalInfluence = GetConVar("webswing_release_direction"):GetFloat()
    end
    
    if ConVarExists("webswing_optimal_release") then
        self.Config.OptimalReleaseBonus = GetConVar("webswing_optimal_release"):GetFloat()
    end
    
    if ConVarExists("webswing_chain_bonus") then
        self.Config.ChainReleaseBonus = GetConVar("webswing_chain_bonus"):GetFloat()
    end
    
    if ConVarExists("webswing_slowmo_enabled") then
        self.Config.EnableSlowMotion = GetConVar("webswing_slowmo_enabled"):GetBool()
    end
    
    if ConVarExists("webswing_midair_correction") then
        self.Config.MidairCorrectionStrength = GetConVar("webswing_midair_correction"):GetFloat()
    end
end

-- Core function - handle web release
function WebReleaseDynamics:HandleWebRelease(player, releaseVelocity, swingPhase)
    if not IsValid(player) then return releaseVelocity end
    
    -- Store original velocity for later
    local originalVelocity = releaseVelocity:Clone()
    
    -- Calculate release score based on timing/phase
    local releaseScore = self:CalculateReleaseScore(swingPhase)
    
    -- Determine release type based on player input
    local releaseType = self:DetermineReleaseType(player)
    
    -- Calculate momentum and direction
    local finalVelocity = self:CalculateReleaseVelocity(player, releaseVelocity, releaseType, releaseScore)
    
    -- Apply chain bonuses if applicable
    finalVelocity = self:ApplyChainBonuses(finalVelocity, releaseScore)
    
    -- Begin recovery phase
    self:StartRecoveryPhase(player, finalVelocity)
    
    -- Apply visual and audio effects
    if SERVER then
        self:ApplyReleaseEffects(player, releaseType, releaseScore, finalVelocity)
    end
    
    -- Update state
    self.State.LastReleaseTime = CurTime()
    self.State.LastReleaseScore = releaseScore
    self.State.LastReleasePhase = swingPhase
    self.State.LastReleaseVelocity = finalVelocity
    self.State.ReleaseType = releaseType
    
    -- Update cumulative score and high score
    self.State.CumulativeScore = self.State.CumulativeScore + releaseScore
    if releaseScore > self.State.HighScore then
        self.State.HighScore = releaseScore
    end
    
    -- Apply final velocity to player
    return finalVelocity
end

-- Calculate release score based on swing phase
function WebReleaseDynamics:CalculateReleaseScore(phase)
    -- Calculate distances to optimal release points (early, middle, late)
    local earlyDist = math.abs(phase - self.Config.OptimalReleasePhaseEarly)
    local middleDist = math.abs(phase - self.Config.OptimalReleasePhaseMiddle)
    local lateDist = math.abs(phase - self.Config.OptimalReleasePhaseLate)
    
    -- Find the closest optimal point
    local closestDist = math.min(earlyDist, middleDist, lateDist)
    
    -- Score is inverse to distance from optimal (closer = higher score)
    local maxDistance = 0.3 -- Maximum distance for any score
    local normalizedDist = math.Clamp(closestDist / maxDistance, 0, 1)
    local score = (1 - normalizedDist) * self.Config.MaxReleaseScore
    
    -- Add bonus for early/late that encourages rhythmic swinging
    if closestDist == earlyDist or closestDist == lateDist then
        score = score * 1.1 -- 10% bonus for hitting early/late spots perfectly
    end
    
    return math.Round(score)
end

-- Determine release type based on player input
function WebReleaseDynamics:DetermineReleaseType(player)
    if not self.Config.EnableReleaseTypes then return "standard" end
    
    local eyeAngles = player:EyeAngles()
    local lookingUp = eyeAngles.pitch < -30
    local lookingDown = eyeAngles.pitch > 30
    
    -- Check for boost release (Jump + Forward)
    if player:KeyDown(IN_JUMP) and player:KeyDown(IN_FORWARD) and not lookingDown then
        return "boost"
    end
    
    -- Check for dive release (Jump + Down look angle)
    if player:KeyDown(IN_JUMP) and lookingDown then
        return "dive"
    end
    
    -- Check for upward release (Jump + Up look angle)
    if player:KeyDown(IN_JUMP) and lookingUp then
        return "upward"
    end
    
    -- Default to standard release
    return "standard"
end

-- Calculate final release velocity based on type and score
function WebReleaseDynamics:CalculateReleaseVelocity(player, baseVelocity, releaseType, releaseScore)
    -- Start with base velocity
    local finalVel = baseVelocity * self.Config.MomentumConservation
    
    -- Get base speed
    local baseSpeed = finalVel:Length()
    
    -- Apply directional influence based on player input
    if self.Config.DirectionalInfluence > 0 then
        local influenceDir = Vector(0,0,0)
        
        -- Calculate influence direction from player input
        if player:KeyDown(IN_FORWARD) then
            influenceDir = influenceDir + player:EyeAngles():Forward()
        end
        if player:KeyDown(IN_BACK) then
            influenceDir = influenceDir - player:EyeAngles():Forward()
        end
        if player:KeyDown(IN_MOVELEFT) then
            influenceDir = influenceDir - player:EyeAngles():Right()
        end
        if player:KeyDown(IN_MOVERIGHT) then
            influenceDir = influenceDir + player:EyeAngles():Right()
        end
        
        -- Normalize if we have input
        if influenceDir:LengthSqr() > 0 then
            influenceDir:Normalize()
            
            -- Blend current direction with influence direction
            local currentDir = finalVel:GetNormalized()
            local blendedDir = LerpVector(self.Config.DirectionalInfluence, currentDir, influenceDir)
            blendedDir:Normalize()
            
            -- Apply the new direction while preserving speed
            finalVel = blendedDir * baseSpeed
        end
    end
    
    -- Apply multiplier based on release type
    local speedMultiplier = 1.0
    
    if releaseType == "boost" then
        speedMultiplier = self.Config.BoostReleaseMult
        
        -- Enhanced forward component
        local forwardBoost = player:EyeAngles():Forward() * (baseSpeed * 0.15)
        forwardBoost.z = math.max(forwardBoost.z, 0) -- Ensure we don't push downward
        finalVel = finalVel + forwardBoost
    elseif releaseType == "dive" then
        speedMultiplier = self.Config.DiveReleaseMult
        
        -- Enhanced downward component
        local diveBoost = Vector(0, 0, -baseSpeed * 0.25)
        finalVel = finalVel + diveBoost
    elseif releaseType == "upward" then
        speedMultiplier = self.Config.UpwardReleaseMult
        
        -- Enhanced upward component
        local upwardBoost = Vector(0, 0, baseSpeed * 0.3)
        finalVel = finalVel + upwardBoost
    else -- standard
        speedMultiplier = self.Config.StandardReleaseMult
    end
    
    -- Apply optimal release bonus if score is high enough
    if releaseScore >= self.Config.ReleaseScoreThreshold then
        local optimalBonus = Lerp(
            (releaseScore - self.Config.ReleaseScoreThreshold) / 
            (self.Config.MaxReleaseScore - self.Config.ReleaseScoreThreshold),
            1.0, 
            self.Config.OptimalReleaseBonus
        )
        
        speedMultiplier = speedMultiplier * optimalBonus
        
        -- Mark perfect release for effects
        self.State.PerfectReleaseActive = true
        self.State.PerfectReleaseStartTime = CurTime()
        self.State.ReleaseEffectsActive.perfect = true
    end
    
    -- Apply final speed multiplier
    finalVel = finalVel * speedMultiplier
    
    return finalVel
end

-- Apply chain bonuses for consecutive well-timed releases
function WebReleaseDynamics:ApplyChainBonuses(velocity, releaseScore)
    local currentTime = CurTime()
    
    -- Check if this release is within the chain time window
    if currentTime - self.State.LastChainTime <= self.Config.ChainTimeWindow then
        -- Only count good releases for chains
        if releaseScore >= self.Config.ReleaseScoreThreshold then
            -- Increment chain count
            self.State.ChainCount = self.State.ChainCount + 1
            
            -- Calculate chain bonus (increases with each consecutive good release)
            local chainFactor = 1.0 + math.min(
                self.State.ChainCount * (self.Config.ChainReleaseBonus - 1.0),
                self.Config.MaxChainBonus - 1.0
            )
            
            -- Store for future releases
            self.State.ChainBonus = chainFactor
            
            -- Apply chain bonus
            velocity = velocity * chainFactor
        end
    else
        -- Chain broken - reset
        self.State.ChainCount = releaseScore >= self.Config.ReleaseScoreThreshold and 1 or 0
        self.State.ChainBonus = 1.0
    end
    
    -- Update chain time
    if releaseScore >= self.Config.ReleaseScoreThreshold then
        self.State.LastChainTime = currentTime
    end
    
    return velocity
end

-- Start recovery phase after release
function WebReleaseDynamics:StartRecoveryPhase(player, velocity)
    -- Set state
    self.State.InRecoveryPhase = true
    self.State.RecoveryStartTime = CurTime()
    self.State.RecoveryVelocity = velocity
    
    -- Apply slow motion effect if enabled and perfect release
    if self.Config.EnableSlowMotion and self.State.PerfectReleaseActive then
        self:ApplySlowMotionEffect(player)
    end
    
    -- Flag effects as active based on release type
    self.State.ReleaseEffectsActive[self.State.ReleaseType] = true
end

-- Handle the recovery phase
function WebReleaseDynamics:ModifyPostReleaseMovement(player, moveData)
    if not self.State.InRecoveryPhase then return end
    
    local currentTime = CurTime()
    local elapsedTime = currentTime - self.State.RecoveryStartTime
    
    -- Check if recovery phase is over
    if elapsedTime > self.Config.RecoveryDuration then
        self.State.InRecoveryPhase = false
        
        -- Reset effects
        for effect, _ in pairs(self.State.ReleaseEffectsActive) do
            self.State.ReleaseEffectsActive[effect] = false
        end
        
        return
    end
    
    -- Calculate recovery progress (0-1)
    local recoveryProgress = elapsedTime / self.Config.RecoveryDuration
    
    -- Modified gravity during recovery
    if elapsedTime < self.Config.GravityDelayTime then
        local gravityMult = self.Config.PostReleaseGravity
        moveData:SetVelocity(Vector(
            moveData:GetVelocity().x,
            moveData:GetVelocity().y,
            moveData:GetVelocity().z + (600 * (1 - gravityMult) * FrameTime())
        ))
    end
    
    -- Apply increased air control
    if self.Config.MidairCorrectionStrength > 0 then
        local controlStrength = self.Config.MidairCorrectionStrength * (1 - recoveryProgress)
        local wishDir = Vector(0,0,0)
        
        -- Determine wish direction from input
        if player:KeyDown(IN_FORWARD) then
            wishDir = wishDir + player:EyeAngles():Forward()
        end
        if player:KeyDown(IN_BACK) then
            wishDir = wishDir - player:EyeAngles():Forward()
        end
        if player:KeyDown(IN_MOVELEFT) then
            wishDir = wishDir - player:EyeAngles():Right()
        end
        if player:KeyDown(IN_MOVERIGHT) then
            wishDir = wishDir + player:EyeAngles():Right()
        end
        
        -- Apply correction if we have input
        if wishDir:LengthSqr() > 0 then
            wishDir:Normalize()
            wishDir.z = 0 -- No vertical control
            
            local currentVel = moveData:GetVelocity()
            local currentSpeed = currentVel:Length2D()
            
            -- Calculate the corrective force
            local correctionForce = wishDir * currentSpeed * controlStrength * FrameTime() * 200
            
            -- Apply to velocity
            moveData:SetVelocity(currentVel + correctionForce)
        end
    end
end

-- Apply slow motion effect
function WebReleaseDynamics:ApplySlowMotionEffect(player)
    if not self.Config.EnableSlowMotion then return end
    
    self.State.IsSlowMotionActive = true
    self.State.SlowMotionStartTime = CurTime()
    
    -- Apply time scale change
    if SERVER and engine and engine.ServerFrameTime then
        -- This is just a placeholder as true slow motion would need more advanced implementation
        -- Game.SetTimeScale(self.Config.SlowMotionTimescale)
        
        -- Schedule returning to normal time
        timer.Simple(self.Config.SlowMotionDuration, function()
            -- Game.SetTimeScale(1.0)
            self.State.IsSlowMotionActive = false
        end)
    end
    
    -- Apply FOV change to emphasize the effect
    if CLIENT and player == LocalPlayer() then
        local originalFOV = player:GetFOV()
        local targetFOV = originalFOV * 1.1 -- 10% increase
        
        -- Schedule FOV changes
        local steps = 10
        for i = 1, steps do
            local progress = i / steps
            local newFOV = Lerp(progress, originalFOV, targetFOV)
            
            timer.Simple(self.Config.SlowMotionDuration * (progress / 2), function()
                if IsValid(player) then
                    player:SetFOV(newFOV, 0.01)
                end
            end)
        end
        
        -- Return to normal FOV
        timer.Simple(self.Config.SlowMotionDuration, function()
            if IsValid(player) then
                player:SetFOV(originalFOV, 0.1)
            end
        end)
    end
end

-- Apply visual and audio effects for release
function WebReleaseDynamics:ApplyReleaseEffects(player, releaseType, releaseScore, releaseVelocity)
    if not IsValid(player) then return end
    
    -- Play appropriate sound based on release type and quality
    if self.Config.EnableAudioFeedback then
        local soundName = "physics/body/body_medium_impact_soft"
        local pitch = 100
        local volume = 0.7
        
        if releaseScore >= self.Config.ReleaseScoreThreshold then
            -- Perfect release sound
            soundName = "physics/glass/glass_strain" .. math.random(1, 3)
            pitch = 100 + math.min(releaseScore, 20)
            volume = 1.0
        else
            -- Different sounds based on release type
            if releaseType == "boost" then
                soundName = "physics/rubber/rubber_tire_impact_hard" .. math.random(1, 3)
                pitch = 110
            elseif releaseType == "dive" then
                soundName = "physics/body/body_medium_impact_hard" .. math.random(1, 6)
                pitch = 90
            elseif releaseType == "upward" then
                soundName = "physics/rubber/rubber_tire_impact_soft" .. math.random(1, 3)
                pitch = 120
            end
        end
        
        -- Play the sound
        player:EmitSound(soundName .. ".wav", 75, pitch, volume)
    end
    
    -- Create visual effects
    if self.Config.EnableVisualFeedback then
        -- Effects would be implemented with particles, which are beyond this code's scope
        -- Placeholder notification for demonstration
        if releaseScore >= self.Config.ReleaseScoreThreshold then
            if SERVER then
                -- Using a net message to signal a perfect release visual effect
                -- You would need to implement the actual visual effects
                -- net.Start("WebSwing_PerfectRelease")
                -- net.WriteVector(releaseVelocity)
                -- net.WriteFloat(releaseScore)
                -- net.Send(player)
            end
        end
    end
    
    -- Apply chain combo effects for consecutive good releases
    if self.State.ChainCount > 1 and self.Config.EnableVisualFeedback then
        -- Chain effect would be implemented here
        -- This is a placeholder
    end
end

-- Update function called every frame during web swinging
function WebReleaseDynamics:Update(player, frameTime)
    -- Update slow motion effect
    if self.State.IsSlowMotionActive then
        local elapsed = CurTime() - self.State.SlowMotionStartTime
        if elapsed > self.Config.SlowMotionDuration then
            self.State.IsSlowMotionActive = false
        end
    end
    
    -- Update recovery phase
    if self.State.InRecoveryPhase then
        local elapsed = CurTime() - self.State.RecoveryStartTime
        if elapsed > self.Config.RecoveryDuration then
            self.State.InRecoveryPhase = false
            
            -- Reset effects
            for effect, _ in pairs(self.State.ReleaseEffectsActive) do
                self.State.ReleaseEffectsActive[effect] = false
            end
        end
    end
    
    -- Update chain counter
    if self.State.ChainCount > 0 then
        local chainElapsed = CurTime() - self.State.LastChainTime
        if chainElapsed > self.Config.ChainTimeWindow then
            self.State.ChainCount = 0
            self.State.ChainBonus = 1.0
        end
    end
end

-- Get current release stats (for HUD)
function WebReleaseDynamics:GetReleaseStats()
    return {
        lastScore = self.State.LastReleaseScore,
        chainCount = self.State.ChainCount,
        chainBonus = self.State.ChainBonus,
        perfectRelease = self.State.PerfectReleaseActive,
        releaseType = self.State.ReleaseType,
        highScore = self.State.HighScore,
        cumulativeScore = self.State.CumulativeScore,
        inRecovery = self.State.InRecoveryPhase
    }
end

return WebReleaseDynamics 