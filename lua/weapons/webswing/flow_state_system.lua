-- Flow State System for Web Swinging
-- Builds upon the rhythm system to create a dynamic "in the zone" flow state experience

local FlowStateSystem = {}

-- Configuration
FlowStateSystem.Config = {
    -- Flow State Core Parameters
    MinimumSpeedForFlow = 400,          -- Minimum speed to enter flow state (units/sec)
    FlowBuildupRate = 0.08,             -- How quickly flow builds up (0-1 per second)
    FlowDecayRate = 0.15,               -- How quickly flow decays when not in optimal rhythm
    PerfectReleaseFlowBonus = 0.2,      -- Flow bonus for perfect web releases
    MinRhythmScoreForFlow = 0.6,        -- Minimum rhythm score to start building flow
    ConsecutiveSwingsRequired = 2,      -- Consecutive good swings required to initiate flow
    
    -- Flow Levels and Effects
    FlowLevels = 5,                     -- Number of flow levels (1-5)
    MaxFlowScore = 1.0,                 -- Maximum flow state score
    FlowThreshold = 0.15,               -- Flow score needed to activate level 1
    
    -- Flow State Bonuses (increases with flow level)
    SpeedBonusPerLevel = 0.12,          -- Speed bonus per flow level (multiplier)
    AirControlBonusPerLevel = 0.15,     -- Air control bonus per flow level
    GravityReductionPerLevel = 0.08,    -- Gravity reduction per flow level
    MomentumConservationPerLevel = 0.1, -- Improved momentum conservation per level
    
    -- Visual and Audio Effects
    EnableFlowEffects = true,           -- Enable visual/audio effects during flow state
    ScreenEffectIntensity = 0.7,        -- Intensity of screen effects (0-1)
    CameraFOVDelta = 5,                 -- How much to increase FOV during flow (degrees)
    ColorSaturationBoost = 0.2,         -- Boost color saturation during flow
    
    -- Flow State Abilities (unlocked at specific flow levels)
    EnableFlowAbilities = true,         -- Enable special abilities during flow
    Level3Ability = "QuickRelease",     -- Special ability unlocked at level 3
    Level5Ability = "TimeDilation",     -- Special ability unlocked at level 5
    TimeDilationFactor = 0.7,           -- Time slowdown factor for time dilation
    TimeDilationDuration = 0.3,         -- Duration of time dilation effect (seconds)
    
    -- Flow State Chain System
    EnableChainSystem = true,           -- Enable chain swinging system
    ChainTimeWindow = 1.2,              -- Time window to maintain chain (seconds)
    MaxChainMultiplier = 2.0,           -- Maximum chain multiplier
    ChainBonusPerSwing = 0.1,           -- Multiplier bonus per chained swing
    PerfectChainRequirement = 0.85,      -- Rhythm score needed for perfect chain bonus
    
    FlowRequiredTime = 15,      -- Time of continuous good swinging to enter flow state (seconds)
    FlowBuildRate = 0.8,        -- How quickly flow state builds when swinging well
    MaxFlowLevel = 5,           -- Maximum flow level achievable
    SpeedMultiplierMax = 1.25,  -- Maximum speed multiplier at full flow
    GravityReductionMax = 0.2,  -- Maximum gravity reduction at full flow
    AirControlBoostMax = 1.5,   -- Maximum air control boost at full flow
    MomentumBoostMax = 1.2,     -- Maximum momentum preservation boost at full flow
    TimeDilationIntensity = 0.2, -- How much time slows down during special moments
    VisualEffectIntensity = 1.0, -- Intensity of visual effects (0-1)
    ChainMultiplierMax = 1.5,   -- Maximum chain multiplier for consecutive tricks
    FlowStateTimeout = 30,      -- How long flow state can last before requiring reset (seconds)
    ChainResetTime = 3.0,       -- Time before chain multiplier resets (seconds)
}

-- Create the necessary ConVars at the file level to ensure they exist
if SERVER then
    CreateConVar("webswing_flow_enabled", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable flow state system", 0, 1)
    CreateConVar("webswing_flow_effects", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable visual effects for flow state", 0, 1)
    CreateConVar("webswing_flow_abilities", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable special abilities during flow state", 0, 1)
    CreateConVar("webswing_flow_state_enabled", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable flow state system", 0, 1)
    CreateConVar("webswing_flow_visual_effects", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable flow state visual effects", 0, 1)
    CreateConVar("webswing_flow_time_dilation", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable time dilation during special moments", 0, 1)
end

-- State variables
FlowStateSystem.State = {
    FlowScore = 0,                      -- Current flow state score (0-1)
    FlowLevel = 0,                      -- Current flow level (0-5)
    InFlowState = false,                -- Whether player is currently in flow state
    FlowStateStartTime = 0,             -- When the current flow state began
    FlowStateActiveDuration = 0,        -- How long the current flow state has been active
    ConsecutiveGoodSwings = 0,          -- Current streak of good swings
    ChainCount = 0,                     -- Current chain count
    ChainMultiplier = 1.0,              -- Current chain multiplier
    LastChainTime = 0,                  -- When the last chain occurred
    LastRhythmScore = 0,                -- Last recorded rhythm score
    PeakSpeed = 0,                      -- Peak speed achieved during flow
    AbilitiesAvailable = {              -- Which abilities are currently available
        QuickRelease = false,
        TimeDilation = false
    },
    IsTimeDilated = false,              -- Whether time dilation is active
    TimeDilationStartTime = 0,          -- When time dilation started
    VisualEffectIntensity = 0,          -- Current intensity of visual effects
    SwingHistory = {},                  -- History of recent swings for analysis
    ExpertTiming = false,               -- Whether player is consistently hitting perfect timing
    FlowStateColor = Color(255, 255, 255), -- Current color for flow state effects (changes with level)
    FlowAccumulator = 0,                -- Accumulated flow points
    FlowStateActive = false,            -- Whether currently in flow state
    LastSwingQuality = 0,               -- Quality of last swing (0-1)
    LastGoodSwingTime = 0,             -- Time of last good swing for chain tracking
    CurrentVisualIntensity = 0,          -- Current visual effect intensity
    SpecialMoveActive = false,          -- Whether a special move is active
    SpecialMoveType = nil,              -- Type of special move if active
}

-- Initialize the flow state system
function FlowStateSystem:Initialize()
    -- Reset state variables
    self:ResetState()
    
    -- Ensure the State table and its subtables are properly initialized
    if not self.State then
        self.State = {}
    end
    
    if not self.State.AbilitiesAvailable then
        self.State.AbilitiesAvailable = {
            QuickRelease = false,
            TimeDilation = false
        }
    end
    
    -- Create or verify ConVars exist - SERVER is a global variable in GMod
    if SERVER then
        -- The proper way to check if a convar exists is to attempt to get it and see if it returns nil
        if GetConVar("webswing_flow_enabled") == nil then
            CreateConVar("webswing_flow_enabled", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable flow state system", 0, 1)
        end
        
        if GetConVar("webswing_flow_effects") == nil then
            CreateConVar("webswing_flow_effects", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable visual effects for flow state", 0, 1)
        end
        
        if GetConVar("webswing_flow_abilities") == nil then
            CreateConVar("webswing_flow_abilities", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable special abilities during flow state", 0, 1)
        end
        
        if GetConVar("webswing_flow_state_enabled") == nil then
            CreateConVar("webswing_flow_state_enabled", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable flow state system", 0, 1)
        end
        
        if GetConVar("webswing_flow_visual_effects") == nil then
            CreateConVar("webswing_flow_visual_effects", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable flow state visual effects", 0, 1)
        end
        
        if GetConVar("webswing_flow_time_dilation") == nil then
            CreateConVar("webswing_flow_time_dilation", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable time dilation during special moments", 0, 1)
        end
    end
    
    -- Hook into game functions if needed
    if CLIENT then
        -- Store 'self' reference in a safe way for hooks to use
        self.hookRef = self
        
        -- Remove any existing hooks first to prevent duplicates
        hook.Remove("RenderScreenspaceEffects", "FlowState_ScreenEffects")
        
        -- Add the screen effects hook with safe self reference
        hook.Add("RenderScreenspaceEffects", "FlowState_ScreenEffects", function()
            -- Ensure we have everything we need before rendering with safety check
            local effectsEnabled = true -- Default to enabled if ConVar doesn't exist
            local effectsConVar = GetConVar("webswing_flow_effects")
            if effectsConVar and effectsConVar.GetBool then
                effectsEnabled = effectsConVar:GetBool()
            end
            
            if not effectsEnabled then return end
            
            -- Get safe reference to the flow system
            local flowSystem = _G.ActiveFlowSystem
            if not flowSystem then return end
            if not flowSystem.RenderFlowEffects then return end
            
            -- Render the flow effects
            flowSystem:RenderFlowEffects()
        end)
        
        -- Store a global reference for the hook to use
        _G.ActiveFlowSystem = self
    end
    
    return self
end

-- Reset state to defaults
function FlowStateSystem:ResetState()
    -- Ensure the State table exists
    if not self then
        return
    end
    
    if not self.State then
        self.State = {}
    end

    -- Initialize all state variables with default values
    self.State.FlowScore = 0
    self.State.FlowLevel = 0
    self.State.InFlowState = false
    self.State.FlowStateStartTime = 0
    self.State.FlowStateActiveDuration = 0
    self.State.ConsecutiveGoodSwings = 0
    self.State.ChainCount = 0
    self.State.ChainMultiplier = 1.0
    self.State.LastChainTime = 0
    self.State.LastRhythmScore = 0
    self.State.PeakSpeed = 0
    
    -- Ensure AbilitiesAvailable exists
    if not self.State.AbilitiesAvailable then
        self.State.AbilitiesAvailable = {
            QuickRelease = false,
            TimeDilation = false
        }
    end
    
    self.State.AbilitiesAvailable.QuickRelease = false
    self.State.AbilitiesAvailable.TimeDilation = false
    
    self.State.IsTimeDilated = false
    self.State.TimeDilationStartTime = 0
    self.State.VisualEffectIntensity = 0
    self.State.SwingHistory = {}
    self.State.ExpertTiming = false
    self.State.FlowStateColor = Color(255, 255, 255)
    self.State.FlowAccumulator = 0
    self.State.FlowStateActive = false
    self.State.LastSwingQuality = 0
    self.State.LastGoodSwingTime = 0
    self.State.CurrentVisualIntensity = 0
    self.State.SpecialMoveActive = false
    self.State.SpecialMoveType = nil
end

-- Update the flow state system
function FlowStateSystem:Update(rhythmSystem, playerVelocity, frameTime)
    -- Ensure we have required parameters with safe defaults
    rhythmSystem = rhythmSystem or {}
    playerVelocity = playerVelocity or Vector(0,0,0)
    frameTime = frameTime or 0.016 -- Default to ~60fps if not provided
    
    -- Check if flow state is enabled - with safety check
    local flowEnabled = true -- Default to enabled if ConVar doesn't exist
    local flowConVar = GetConVar("webswing_flow_enabled")
    if flowConVar and flowConVar.GetBool then
        flowEnabled = flowConVar:GetBool()
    end
    
    if not flowEnabled then
        self:ResetState()
        return {}
    end
    
    local currentTime = CurTime()
    local speed = 0
    
    -- Safely get velocity length
    if playerVelocity and type(playerVelocity) == "Vector" and playerVelocity.Length then
        speed = playerVelocity:Length()
    end
    
    -- Safely get rhythm score and state
    local rhythmScore = 0
    local inRhythm = false
    
    if rhythmSystem then
        rhythmScore = rhythmSystem.RhythmScore or 0
        inRhythm = rhythmSystem.IsInRhythm or false
    end
    
    -- Store the rhythm score
    self.State.LastRhythmScore = rhythmScore
    
    -- Track peak speed
    if speed > self.State.PeakSpeed then
        self.State.PeakSpeed = speed
    end
    
    -- Update flow score based on rhythm and speed
    if speed >= self.Config.MinimumSpeedForFlow and rhythmScore >= self.Config.MinRhythmScoreForFlow then
        -- Build up flow
        local flowBuildAmount = self.Config.FlowBuildupRate * rhythmScore * frameTime
        self.State.FlowScore = math.min(self.State.FlowScore + flowBuildAmount, self.Config.MaxFlowScore)
        
        -- Check if we should enter flow state
        if not self.State.InFlowState and self.State.FlowScore >= self.Config.FlowThreshold then
            self:EnterFlowState()
        end
    else
        -- Decay flow
        local flowDecayAmount = self.Config.FlowDecayRate * frameTime
        self.State.FlowScore = math.max(self.State.FlowScore - flowDecayAmount, 0)
        
        -- Check if we should exit flow state
        if self.State.InFlowState and self.State.FlowScore < self.Config.FlowThreshold then
            self:ExitFlowState()
        end
    end
    
    -- Update flow level based on flow score
    self:UpdateFlowLevel()
    
    -- Update ability availability based on flow level
    self:UpdateAbilities()
    
    -- Update chain system
    self:UpdateChainSystem(currentTime)
    
    -- Update time dilation if active
    if self.State.IsTimeDilated then
        local dilationElapsed = currentTime - self.State.TimeDilationStartTime
        if dilationElapsed >= self.Config.TimeDilationDuration then
            self.State.IsTimeDilated = false
            game.SetTimeScale(1.0)
        end
    end
    
    -- Update visual effect intensity
    local targetIntensity = self.State.InFlowState and (self.State.FlowLevel / self.Config.FlowLevels) or 0
    self.State.VisualEffectIntensity = Lerp(frameTime * 5, self.State.VisualEffectIntensity, targetIntensity)
    
    -- Update flow state duration if active
    if self.State.InFlowState then
        self.State.FlowStateActiveDuration = currentTime - self.State.FlowStateStartTime
    end
    
    return self:GetFlowAdjustments()
end

-- Enter the flow state
function FlowStateSystem:EnterFlowState()
    self.State.InFlowState = true
    self.State.FlowStateStartTime = CurTime()
    self.State.FlowStateActiveDuration = 0
    
    -- Play entry sound if enabled
    if CLIENT and self.Config.EnableFlowEffects then
        surface.PlaySound("physics/glass/glass_impact_soft2.wav")
    end
    
    -- Notify other systems if needed
    hook.Run("WebSwing_FlowStateEntered", self.State.FlowScore)
end

-- Exit the flow state
function FlowStateSystem:ExitFlowState()
    self.State.InFlowState = false
    
    -- Reset abilities
    self.State.AbilitiesAvailable.QuickRelease = false
    self.State.AbilitiesAvailable.TimeDilation = false
    
    -- Play exit sound if enabled
    if CLIENT and self.Config.EnableFlowEffects then
        surface.PlaySound("physics/glass/glass_stress3.wav")
    end
    
    -- End time dilation if active
    if self.State.IsTimeDilated then
        self.State.IsTimeDilated = false
        game.SetTimeScale(1.0)
    end
    
    -- Notify other systems if needed
    hook.Run("WebSwing_FlowStateExited", self.State.FlowStateActiveDuration)
end

-- Update the flow level based on flow score
function FlowStateSystem:UpdateFlowLevel()
    -- Calculate level based on flow score
    local previousLevel = self.State.FlowLevel
    local scorePerLevel = self.Config.MaxFlowScore / self.Config.FlowLevels
    self.State.FlowLevel = math.floor(self.State.FlowScore / scorePerLevel)
    
    -- Cap at max level
    self.State.FlowLevel = math.min(self.State.FlowLevel, self.Config.FlowLevels)
    
    -- If level changed, update effects
    if self.State.FlowLevel ~= previousLevel then
        self:OnFlowLevelChanged(previousLevel, self.State.FlowLevel)
    end
end

-- Handle flow level changes
function FlowStateSystem:OnFlowLevelChanged(oldLevel, newLevel)
    -- Update color based on level
    local colors = {
        Color(100, 200, 255), -- Level 1: Light Blue
        Color(100, 255, 100), -- Level 2: Green
        Color(255, 255, 100), -- Level 3: Yellow
        Color(255, 100, 0),   -- Level 4: Orange
        Color(255, 50, 255)   -- Level 5: Purple
    }
    
    if newLevel > 0 and newLevel <= #colors then
        self.State.FlowStateColor = colors[newLevel]
    else
        self.State.FlowStateColor = Color(255, 255, 255)
    end
    
    -- Play level up sound
    if CLIENT and newLevel > oldLevel and self.Config.EnableFlowEffects then
        surface.PlaySound("physics/metal/metal_sheet_impact_hard" .. math.random(2, 8) .. ".wav")
    end
    
    -- Notify other systems if needed
    hook.Run("WebSwing_FlowLevelChanged", oldLevel, newLevel)
end

-- Update availability of special abilities
function FlowStateSystem:UpdateAbilities()
    -- Safety check for GetConVar
    local abilitiesEnabled = true -- Default to enabled if ConVar doesn't exist
    local abilitiesConVar = GetConVar("webswing_flow_abilities")
    if abilitiesConVar and abilitiesConVar.GetBool then
        abilitiesEnabled = abilitiesConVar:GetBool()
    end
    
    if not self.Config.EnableFlowAbilities or not abilitiesEnabled then
        self.State.AbilitiesAvailable.QuickRelease = false
        self.State.AbilitiesAvailable.TimeDilation = false
        return
    end
    
    -- Quick Release ability (Level 3+)
    self.State.AbilitiesAvailable.QuickRelease = self.State.FlowLevel >= 3
    
    -- Time Dilation ability (Level 5)
    self.State.AbilitiesAvailable.TimeDilation = self.State.FlowLevel >= 5
end

-- Update the chain system
function FlowStateSystem:UpdateChainSystem(currentTime)
    if not self.Config.EnableChainSystem then return end
    
    -- Check if chain has expired
    if currentTime - self.State.LastChainTime > self.Config.ChainTimeWindow and self.State.ChainCount > 0 then
        -- Reset chain
        self.State.ChainCount = 0
        self.State.ChainMultiplier = 1.0
    end
end

-- Record a swing for the flow system
function FlowStateSystem:RecordSwing(rhythmScore, releaseAccuracy)
    local currentTime = CurTime()
    
    -- Store swing data
    table.insert(self.State.SwingHistory, {
        time = currentTime,
        rhythmScore = rhythmScore,
        releaseAccuracy = releaseAccuracy or 0
    })
    
    -- Keep history at reasonable size
    if #self.State.SwingHistory > 10 then
        table.remove(self.State.SwingHistory, 1)
    end
    
    -- Check if this is a good swing
    if rhythmScore >= self.Config.MinRhythmScoreForFlow then
        self.State.ConsecutiveGoodSwings = self.State.ConsecutiveGoodSwings + 1
        
        -- Award flow bonus for good swings
        local flowBonus = rhythmScore * 0.1
        self.State.FlowScore = math.min(self.State.FlowScore + flowBonus, self.Config.MaxFlowScore)
    else
        self.State.ConsecutiveGoodSwings = 0
    end
    
    -- Update chain system
    if rhythmScore >= self.Config.PerfectChainRequirement then
        -- Increment chain count
        self.State.ChainCount = self.State.ChainCount + 1
        
        -- Update chain multiplier (capped at maximum)
        local chainBonus = self.Config.ChainBonusPerSwing
        self.State.ChainMultiplier = math.min(
            1.0 + (self.State.ChainCount * chainBonus),
            self.Config.MaxChainMultiplier
        )
        
        -- Update last chain time
        self.State.LastChainTime = currentTime
    end
    
    -- Analyze swing history to detect expert timing
    self:AnalyzeSwingHistory()
    
    return self.State.ChainMultiplier
end

-- Record a web release for the flow system
function FlowStateSystem:RecordWebRelease(releaseScore)
    -- Award flow bonus for good release timing
    if releaseScore > 0.7 then
        local flowBonus = releaseScore * self.Config.PerfectReleaseFlowBonus
        self.State.FlowScore = math.min(self.State.FlowScore + flowBonus, self.Config.MaxFlowScore)
    end
    
    -- Check if time dilation should be triggered
    if self.State.AbilitiesAvailable.TimeDilation and releaseScore > 0.9 then
        self:TriggerTimeDilation()
    end
end

-- Trigger time dilation effect
function FlowStateSystem:TriggerTimeDilation()
    -- Safety check for GetConVar
    local abilitiesEnabled = true -- Default to enabled if ConVar doesn't exist
    local abilitiesConVar = GetConVar("webswing_flow_abilities")
    if abilitiesConVar and abilitiesConVar.GetBool then
        abilitiesEnabled = abilitiesConVar:GetBool()
    end
    
    if not abilitiesEnabled or self.State.IsTimeDilated then
        return false
    end
    
    self.State.IsTimeDilated = true
    self.State.TimeDilationStartTime = CurTime()
    
    -- Apply time dilation
    game.SetTimeScale(self.Config.TimeDilationFactor)
    
    -- Play effect sound
    if CLIENT and self.Config.EnableFlowEffects then
        surface.PlaySound("ambient/machines/time_travel_short1.wav")
    end
    
    return true
end

-- Analyze swing history to detect expert timing
function FlowStateSystem:AnalyzeSwingHistory()
    if #self.State.SwingHistory < 3 then
        self.State.ExpertTiming = false
        return
    end
    
    -- Check the last 3 swings for consistent high scores
    local totalScore = 0
    for i = #self.State.SwingHistory, math.max(1, #self.State.SwingHistory - 2), -1 do
        totalScore = totalScore + self.State.SwingHistory[i].rhythmScore
    end
    
    local averageScore = totalScore / 3
    self.State.ExpertTiming = averageScore >= 0.85
end

-- Get flow state adjustments for physics and other systems
function FlowStateSystem:GetFlowAdjustments()
    -- Handle case where State might be nil
    if not self.State then
        return {
            speedMultiplier = 1.0,
            gravityFactor = 1.0,
            airControlFactor = 1.0,
            momentumConservation = 1.0,
            visualIntensity = 0,
            flowLevel = 0,
            chainMultiplier = 1.0,
            inFlowState = false,
            timeDilated = false
        }
    end

    local adjustments = {
        speedMultiplier = 1.0,
        gravityFactor = 1.0,
        airControlFactor = 1.0,
        momentumConservation = 1.0,
        visualIntensity = self.State.VisualEffectIntensity or 0,
        flowLevel = self.State.FlowLevel or 0,
        chainMultiplier = self.State.ChainMultiplier or 1.0,
        inFlowState = self.State.InFlowState or false,
        timeDilated = self.State.IsTimeDilated or false
    }
    
    -- Apply flow state bonuses if active
    if self.State.InFlowState then
        -- Make sure we have valid Config values
        local speedBonus = (self.Config and self.Config.SpeedBonusPerLevel) or 0.12
        local gravityReduction = (self.Config and self.Config.GravityReductionPerLevel) or 0.08
        local airControlBonus = (self.Config and self.Config.AirControlBonusPerLevel) or 0.15
        local momentumBonus = (self.Config and self.Config.MomentumConservationPerLevel) or 0.1
        local flowLevels = (self.Config and self.Config.FlowLevels) or 5
        local flowLevel = self.State.FlowLevel or 0
        
        -- Scale adjustments based on flow level
        adjustments.speedMultiplier = 1.0 + (speedBonus * flowLevel)
        adjustments.gravityFactor = 1.0 - (gravityReduction * flowLevel)
        adjustments.airControlFactor = 1.0 + (airControlBonus * flowLevel)
        adjustments.momentumConservation = 1.0 + (momentumBonus * flowLevel)
        
        -- Apply chain multiplier to speed (safely)
        adjustments.speedMultiplier = adjustments.speedMultiplier * (self.State.ChainMultiplier or 1.0)
    end
    
    return adjustments
end

-- Render flow state visual effects
function FlowStateSystem:RenderFlowEffects()
    if not CLIENT then return end
    
    -- Safety check - ensure we can render effects
    if not self or not self.Config or not self.State then return end
    if not self.Config.EnableFlowEffects or self.State.VisualEffectIntensity <= 0 then return end
    
    -- Apply screen effects based on flow intensity
    local intensity = self.State.VisualEffectIntensity * self.Config.ScreenEffectIntensity
    
    -- Color modification
    local colorModify = {
        ["$pp_colour_addr"] = 0,
        ["$pp_colour_addg"] = 0,
        ["$pp_colour_addb"] = 0,
        ["$pp_colour_brightness"] = 0,
        ["$pp_colour_contrast"] = 1 + (0.1 * intensity),
        ["$pp_colour_colour"] = 1 + (self.Config.ColorSaturationBoost * intensity),
        ["$pp_colour_mulr"] = 0,
        ["$pp_colour_mulg"] = 0,
        ["$pp_colour_mulb"] = 0
    }
    
    -- Add slight color tint based on flow level
    local color = self.State.FlowStateColor or Color(255, 255, 255)
    colorModify["$pp_colour_addr"] = (color.r / 255 - 0.5) * 0.01 * intensity
    colorModify["$pp_colour_addg"] = (color.g / 255 - 0.5) * 0.01 * intensity
    colorModify["$pp_colour_addb"] = (color.b / 255 - 0.5) * 0.01 * intensity
    
    -- Apply color modification
    DrawColorModify(colorModify)
    
    -- Apply blur at edges if in high flow levels
    if self.State.FlowLevel >= 3 then
        local blurIntensity = (self.State.FlowLevel - 2) * 0.1 * intensity
        DrawMotionBlur(0.1, blurIntensity, 0.01)
    end
    
    -- Apply FOV adjustment through hook if needed
    if self.State.FlowLevel > 0 and self.Config.CameraFOVDelta > 0 then
        hook.Add("CalcView", "FlowState_FOVAdjust", function(ply, pos, angles, fov)
            local fovAdd = self.Config.CameraFOVDelta * intensity
            return {
                fov = fov + fovAdd
            }
        end)
    else
        hook.Remove("CalcView", "FlowState_FOVAdjust")
    end
end

-- Get status info for HUD
function FlowStateSystem:GetStatusInfo()
    return {
        flowScore = self.State.FlowScore,
        flowLevel = self.State.FlowLevel,
        inFlowState = self.State.InFlowState,
        chainCount = self.State.ChainCount,
        chainMultiplier = self.State.ChainMultiplier,
        flowColor = self.State.FlowStateColor,
        consecutiveGoodSwings = self.State.ConsecutiveGoodSwings,
        peakSpeed = self.State.PeakSpeed,
        abilitiesAvailable = self.State.AbilitiesAvailable,
        expertTiming = self.State.ExpertTiming,
        visualIntensity = self.State.VisualEffectIntensity
    }
end

return FlowStateSystem 