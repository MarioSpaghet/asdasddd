-- Swing Rhythm Detection and Enhancement System

local RhythmSystem = {}

-- Configuration
RhythmSystem.Config = {
    MinSwingTime = 0.4,        -- Minimum time between swings to count as intentional (seconds)
    MaxSwingTime = 3.0,        -- Maximum time between swings to track for rhythm (seconds)
    OptimalSwingTime = 0.8,    -- Initial optimal time between swings (seconds), will adapt
    RhythmMemorySize = 5,      -- Number of recent swings to consider for rhythm detection
    AdaptationRate = 0.2,      -- How quickly to adapt to player's natural rhythm (0-1)
    RhythmBoostFactor = 0.15,  -- Maximum speed boost when maintaining rhythm (0-1)
    VisualFeedback = true,     -- Enable visual feedback for rhythm timing
    HapticFeedback = true,     -- Enable haptic feedback for rhythm timing
    AudioFeedback = true,      -- Enable audio feedback for rhythm timing
    PerfectSwingThreshold = 0.8, -- Minimum rhythm score to consider a swing "perfect" for momentum building
}

-- State variables
RhythmSystem.SwingHistory = {}  -- History of swing timings
RhythmSystem.LastSwingTime = 0  -- Time of last swing
RhythmSystem.CurrentRhythm = RhythmSystem.Config.OptimalSwingTime  -- Current detected rhythm time
RhythmSystem.RhythmScore = 0    -- How well player is maintaining rhythm (0-1)
RhythmSystem.IsInRhythm = false -- Whether player is currently in rhythm
RhythmSystem.SwingPhase = 0     -- Current phase in the swing (0-1, where 0 is start, 0.5 is middle, 1 is end)
RhythmSystem.OptimalReleasePoint = 0 -- Calculated optimal point to release (0-1)
RhythmSystem.NextPredictedSwingTime = 0 -- When we predict the next swing should occur
RhythmSystem.ConsistencyScore = 0 -- How consistent the player's rhythm is
RhythmSystem.LastSwingWasPerfect = false -- Tracks if the last swing was perfect

-- Initialize the rhythm system
function RhythmSystem:Initialize()
    self.SwingHistory = {}
    self.LastSwingTime = 0
    self.CurrentRhythm = self.Config.OptimalSwingTime
    self.RhythmScore = 0
    self.IsInRhythm = false
    self.SwingPhase = 0
    self.OptimalReleasePoint = 0
    self.NextPredictedSwingTime = 0
    self.ConsistencyScore = 0
    self.LastSwingWasPerfect = false
    
    -- Create ConVars for customization
    if SERVER then
        CreateConVar("webswing_rhythm_detection", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable swing rhythm detection and enhancement", 0, 1)
        CreateConVar("webswing_rhythm_boost", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable rhythm-based speed boosts", 0, 1)
        CreateConVar("webswing_rhythm_feedback", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable visual/audio feedback for rhythm", 0, 1)
        CreateConVar("webswing_momentum_building", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable momentum building from consecutive perfect swings", 0, 1)
    end
end

-- Record a new swing event
function RhythmSystem:RecordSwing(swingType)
    local currentTime = CurTime()
    local timeSinceLastSwing = currentTime - self.LastSwingTime
    
    -- Only record if it's been long enough (not just a rapid refire)
    if timeSinceLastSwing >= self.Config.MinSwingTime then
        -- Add to history
        table.insert(self.SwingHistory, {
            time = currentTime,
            interval = timeSinceLastSwing,
            type = swingType or "standard"
        })
        
        -- Keep history within size limit
        if #self.SwingHistory > self.Config.RhythmMemorySize then
            table.remove(self.SwingHistory, 1)
        end
        
        -- Update rhythm detection
        self:UpdateRhythmDetection()
        
        -- Calculate next optimal swing time
        self.NextPredictedSwingTime = currentTime + self.CurrentRhythm
        
        -- Check if this was a perfect swing
        local inRhythm, rhythmScore = self:CheckRhythm(currentTime)
        self.LastSwingWasPerfect = rhythmScore >= self.Config.PerfectSwingThreshold
        
        -- Trigger momentum building if enabled and swing was perfect
        if GetConVar("webswing_momentum_building"):GetBool() and self.LastSwingWasPerfect then
            -- Get the physics system to record this perfect swing
            local PhysicsSystem = include("physics_system.lua")
            if PhysicsSystem and PhysicsSystem.RecordPerfectSwing then
                PhysicsSystem.RecordPerfectSwing()
            end
        end
    end
    
    self.LastSwingTime = currentTime
    return timeSinceLastSwing
end

-- Record a swing release event
function RhythmSystem:RecordRelease(swingDuration)
    -- Record the release and its timing relative to the swing duration
    -- This helps determine if the player is releasing at the optimal point
    
    -- Calculate if this was close to the optimal release point
    local optimalDuration = self.CurrentRhythm * 0.75 -- Typically release at about 3/4 through swing
    local releaseAccuracy = 1 - math.min(math.abs(swingDuration - optimalDuration) / optimalDuration, 1)
    
    -- Update the optimal release point based on successful swings
    if releaseAccuracy > 0.7 and swingDuration > 0.3 then
        self.OptimalReleasePoint = Lerp(0.2, self.OptimalReleasePoint, swingDuration / self.CurrentRhythm)
    end
    
    -- Check for perfect release and update momentum system if needed
    if releaseAccuracy > 0.8 and self.LastSwingWasPerfect and GetConVar("webswing_momentum_building"):GetBool() then
        -- This was an excellent release after a perfect swing - add a bonus to momentum
        local PhysicsSystem = include("physics_system.lua")
        if PhysicsSystem and PhysicsSystem.MomentumSystem then
            -- We don't call RecordPerfectSwing again, but we could add a small bonus here if desired
        end
    end
    
    return releaseAccuracy
end

-- Update rhythm detection based on swing history
function RhythmSystem:UpdateRhythmDetection()
    if #self.SwingHistory < 2 then
        return -- Not enough data yet
    end
    
    -- Calculate average rhythm
    local totalInterval = 0
    local validIntervals = 0
    
    for i = 1, #self.SwingHistory do
        local interval = self.SwingHistory[i].interval
        if interval <= self.Config.MaxSwingTime then
            totalInterval = totalInterval + interval
            validIntervals = validIntervals + 1
        end
    end
    
    if validIntervals > 0 then
        local avgInterval = totalInterval / validIntervals
        
        -- Adapt current rhythm toward the detected average
        self.CurrentRhythm = Lerp(self.Config.AdaptationRate, self.CurrentRhythm, avgInterval)
        
        -- Calculate consistency score (how consistent the intervals are)
        local variance = 0
        for i = 1, #self.SwingHistory do
            local interval = self.SwingHistory[i].interval
            if interval <= self.Config.MaxSwingTime then
                variance = variance + (interval - avgInterval)^2
            end
        end
        
        variance = variance / validIntervals
        self.ConsistencyScore = math.max(0, 1 - math.sqrt(variance) / (avgInterval * 0.5))
    end
end

-- Check if current swing is in rhythm
function RhythmSystem:CheckRhythm(currentTime)
    if #self.SwingHistory < 2 then
        self.IsInRhythm = false
        self.RhythmScore = 0
        return false, 0
    end
    
    local timeSinceLastSwing = currentTime - self.LastSwingTime
    local predictedTimeLeft = self.NextPredictedSwingTime - currentTime
    
    -- Calculate how close we are to the expected rhythm
    local timeError = math.abs(timeSinceLastSwing - self.CurrentRhythm)
    local accuracy = math.max(0, 1 - (timeError / (self.CurrentRhythm * 0.5)))
    
    -- Calculate rhythm score based on accuracy and consistency
    self.RhythmScore = accuracy * self.ConsistencyScore
    self.IsInRhythm = self.RhythmScore > 0.7
    
    return self.IsInRhythm, self.RhythmScore, predictedTimeLeft
end

-- Calculate swing phase (0-1) based on current time and swing start time
function RhythmSystem:UpdateSwingPhase(swingStartTime, currentTime)
    local expectedDuration = self.CurrentRhythm
    local elapsedTime = currentTime - swingStartTime
    self.SwingPhase = math.Clamp(elapsedTime / expectedDuration, 0, 1)
    return self.SwingPhase
end

-- Get recommended swing adjustments based on rhythm
function RhythmSystem:GetSwingAdjustments(currentVelocity, swingPhase)
    local adjustments = {
        speedBoost = 0,
        gravityFactor = 1,
        ropeLengthFactor = 1
    }
    
    -- Only apply adjustments if rhythm detection is enabled
    if not GetConVar("webswing_rhythm_detection"):GetBool() then
        return adjustments
    end
    
    -- Speed boost based on rhythm score and swing phase
    if GetConVar("webswing_rhythm_boost"):GetBool() then
        -- Provide maximum boost near the optimal release point
        local releaseProximity = 1 - math.abs(swingPhase - self.OptimalReleasePoint) * 2
        if releaseProximity > 0 then
            adjustments.speedBoost = self.RhythmScore * releaseProximity * self.Config.RhythmBoostFactor
        end
        
        -- Adjust gravity based on swing phase (lighter at beginning, heavier near end)
        local gravCurve = math.sin(swingPhase * math.pi)
        adjustments.gravityFactor = Lerp(self.RhythmScore * 0.5, 1, 1 - 0.3 * gravCurve)
        
        -- Adjust rope length slightly based on rhythm
        adjustments.ropeLengthFactor = Lerp(self.RhythmScore * 0.3, 1, 0.95 + 0.1 * math.sin(swingPhase * math.pi * 2))
        
        -- Get the momentum system status if available
        local PhysicsSystem = include("physics_system.lua")
        if PhysicsSystem and PhysicsSystem.GetMomentumState then
            local momentumState = PhysicsSystem.GetMomentumState()
            
            -- Apply additional adjustments based on momentum system
            if momentumState and momentumState.MomentumMultiplier > 1 then
                -- Enhance the rope dynamics as momentum builds
                if momentumState.ConsecutivePerfectSwings >= 3 then
                    -- More dramatic rope length changes for high momentum
                    adjustments.ropeLengthFactor = adjustments.ropeLengthFactor * Lerp(
                        swingPhase, 
                        0.9, -- Shorter at beginning of swing
                        1.1  -- Longer at end of swing
                    )
                end
            end
        end
    end
    
    return adjustments
end

-- Provide visual feedback for rhythm
function RhythmSystem:ProvideFeedback(rhythmScore, inRhythm, swingPhase)
    if not GetConVar("webswing_rhythm_feedback"):GetBool() then
        return
    end
    
    -- Get the momentum system if available
    local momentumInfo = {}
    local PhysicsSystem = include("physics_system.lua")
    if PhysicsSystem and PhysicsSystem.GetMomentumState then
        momentumInfo = PhysicsSystem.GetMomentumState()
    end
    
    if CLIENT then
        -- Visual feedback
        if self.Config.VisualFeedback then
            -- This would be implemented in a HUD system
            -- For now, we'll set up the data that would be used
            local feedbackData = {
                rhythmScore = rhythmScore,
                inRhythm = inRhythm,
                swingPhase = swingPhase,
                optimalReleasePoint = self.OptimalReleasePoint,
                nextSwingTime = self.NextPredictedSwingTime,
                currentTime = CurTime(),
                -- Add momentum system information
                momentumMultiplier = momentumInfo.MomentumMultiplier or 1.0,
                consecutivePerfectSwings = momentumInfo.ConsecutivePerfectSwings or 0,
                peakSpeed = momentumInfo.PeakSpeed or 0,
                isDiving = momentumInfo.IsDiving or false
            }
            -- Store this data for the HUD to use
            self.FeedbackData = feedbackData
        end
        
        -- Audio feedback on perfect rhythm
        if self.Config.AudioFeedback and inRhythm and rhythmScore > 0.9 then
            -- Play a subtle "whoosh" sound that gets louder with better rhythm
            local volume = math.min(0.5, rhythmScore * 0.5)
            surface.PlaySound("physics/body/body_medium_impact_soft" .. math.random(1, 7) .. ".wav")
            
            -- Additional feedback sounds for momentum building
            if momentumInfo.ConsecutivePerfectSwings and momentumInfo.ConsecutivePerfectSwings > 1 then
                -- Play an additional sound that gets more energetic with more consecutive swings
                local pitch = 100 + (momentumInfo.ConsecutivePerfectSwings * 5)
                surface.PlaySound("physics/glass/glass_sheet_step" .. math.random(1, 4) .. ".wav")
            end
        end
        
        -- Haptic feedback
        if self.Config.HapticFeedback and inRhythm then
            local intensity = rhythmScore * 0.5
            -- This would typically use the rumble feature of controllers
            -- We can approximate with screen shake for now
            util.ScreenShake(Vector(0,0,0), intensity, 5, 0.2, 0)
        end
    end
end

-- Check if swings are in perfect rhythm for momentum building
function RhythmSystem:IsPerfectRhythm()
    return self.RhythmScore >= self.Config.PerfectSwingThreshold
end

return RhythmSystem 