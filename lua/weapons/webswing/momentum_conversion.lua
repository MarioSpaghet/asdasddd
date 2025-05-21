-- Momentum Conversion System
-- Converts downward momentum into forward momentum (Web of Shadows style)

local MomentumConversion = {}

-- Configuration
MomentumConversion.Config = {
    -- Core parameters
    ConversionEfficiency = 0.7,        -- How efficiently vertical momentum converts to horizontal (0.0-1.0)
    MinVerticalSpeed = 300,            -- Minimum downward speed to trigger conversion (units/sec)
    MaxVerticalSpeed = 1200,           -- Speed at which max conversion is reached (units/sec)
    
    -- Activation parameters
    RequireJumpKey = true,             -- Require jump key to be pressed for conversion
    RequireForwardKey = true,          -- Require forward key to be pressed for conversion
    ActivationDelay = 0.1,             -- Delay before conversion activates (seconds)
    
    -- Effect parameters
    ConversionDuration = 0.4,          -- How long the conversion effect lasts (seconds)
    ConversionEasing = 0.2,            -- Easing factor for smooth conversion (0.0-1.0)
    
    -- Visual feedback
    EnableEffects = true,              -- Enable visual/audio effects during conversion
    EffectIntensity = 1.0,             -- Intensity of visual effects (0.0-2.0)
    
    -- Advanced parameters
    DirectionalInfluence = 0.6,        -- How much player look direction influences conversion direction (0.0-1.0)
    VerticalRetention = 0.3,           -- How much vertical momentum to retain (0.0-1.0)
    CooldownTime = 0.5,                -- Cooldown between conversions (seconds)
    
    -- Boost parameters
    EnableBoostEffect = true,          -- Enable additional boost when conversion is perfect
    PerfectTimingWindow = 0.15,        -- Timing window for perfect conversion (seconds)
    PerfectBoostMultiplier = 1.3       -- Speed multiplier for perfect timing (1.0-2.0)
}

-- State tracking
MomentumConversion.State = {
    IsConverting = false,              -- Currently performing conversion
    ConversionStartTime = 0,           -- When conversion started
    LastConversionTime = 0,            -- When last conversion completed
    ConversionProgress = 0,            -- Progress of current conversion (0.0-1.0)
    InitialVerticalSpeed = 0,          -- Initial downward speed at conversion start
    ConvertedMomentum = Vector(0,0,0), -- Momentum that has been converted
    PerfectConversion = false,         -- Whether this conversion had perfect timing
    CooldownActive = false,            -- Whether cooldown is active
    FallStartTime = 0,                 -- When the current fall began
    PeakHeight = 0,                    -- Peak height during fall
    CurrentHeight = 0,                 -- Current height
    FallDistance = 0,                  -- Distance fallen so far
    PreviousVelocity = Vector(0,0,0),  -- Velocity from previous frame
    EffectsActive = false              -- Whether effects are currently active
}

-- Initialize the momentum conversion system
function MomentumConversion:Initialize()
    -- Reset state variables
    self:ResetState()
    
    -- Load ConVar settings
    self:LoadConVarSettings()
    
    -- Register needed hooks
    hook.Add("Think", "MomentumConversion_Think", function()
        if CLIENT then return end -- Server-side only
        
        -- Process all players
        for _, player in ipairs(player.GetAll()) do
            if IsValid(player) and player:Alive() then
                self:ProcessPlayer(player)
            end
        end
    end)
    
    return self
end

-- Reset state variables
function MomentumConversion:ResetState()
    self.State = {
        IsConverting = false,
        ConversionStartTime = 0,
        LastConversionTime = 0,
        ConversionProgress = 0,
        InitialVerticalSpeed = 0,
        ConvertedMomentum = Vector(0,0,0),
        PerfectConversion = false,
        CooldownActive = false,
        FallStartTime = 0,
        PeakHeight = 0,
        CurrentHeight = 0,
        FallDistance = 0,
        PreviousVelocity = Vector(0,0,0),
        EffectsActive = false
    }
end

-- Load settings from ConVars
function MomentumConversion:LoadConVarSettings()
    -- Create ConVars if they don't exist
    if not ConVarExists("webswing_momentum_conversion") then
        CreateConVar("webswing_momentum_conversion", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable momentum conversion system", 0, 1)
    end
    
    if not ConVarExists("webswing_conversion_efficiency") then
        CreateConVar("webswing_conversion_efficiency", tostring(self.Config.ConversionEfficiency), FCVAR_ARCHIVE + FCVAR_REPLICATED, "Efficiency of momentum conversion (0.0-1.0)", 0, 1)
    end
    
    if not ConVarExists("webswing_min_conversion_speed") then
        CreateConVar("webswing_min_conversion_speed", tostring(self.Config.MinVerticalSpeed), FCVAR_ARCHIVE + FCVAR_REPLICATED, "Minimum speed for momentum conversion", 100, 500)
    end
    
    if not ConVarExists("webswing_conversion_boost") then
        CreateConVar("webswing_conversion_boost", tostring(self.Config.PerfectBoostMultiplier), FCVAR_ARCHIVE + FCVAR_REPLICATED, "Boost multiplier for perfect conversion timing", 1.0, 2.0)
    end
    
    if not ConVarExists("webswing_conversion_direction") then
        CreateConVar("webswing_conversion_direction", tostring(self.Config.DirectionalInfluence), FCVAR_ARCHIVE + FCVAR_REPLICATED, "Directional influence on momentum conversion", 0.0, 1.0)
    end
    
    -- Load values from ConVars
    self.Config.ConversionEfficiency = GetConVar("webswing_conversion_efficiency"):GetFloat()
    self.Config.MinVerticalSpeed = GetConVar("webswing_min_conversion_speed"):GetFloat()
    self.Config.PerfectBoostMultiplier = GetConVar("webswing_conversion_boost"):GetFloat()
    self.Config.DirectionalInfluence = GetConVar("webswing_conversion_direction"):GetFloat()
    self.Config.EnableConversion = GetConVar("webswing_momentum_conversion"):GetBool()
end

-- Process a player for momentum conversion
function MomentumConversion:ProcessPlayer(player)
    if not IsValid(player) or not player:Alive() then return end
    if not self.Config.EnableConversion then return end
    
    -- Get current state
    local velocity = player:GetVelocity()
    local position = player:GetPos()
    local currentTime = CurTime()
    local frameTime = FrameTime()
    
    -- Update height tracking
    self.State.CurrentHeight = position.z
    
    -- Detect if we're falling
    local isFalling = velocity.z < -50 and not player:OnGround()
    local wasGoingDown = self.State.PreviousVelocity.z < -50
    
    -- Start tracking a new fall
    if isFalling and not wasGoingDown then
        self.State.FallStartTime = currentTime
        self.State.PeakHeight = position.z
    end
    
    -- Update peak height if we're still going up
    if velocity.z > 0 then
        self.State.PeakHeight = math.max(self.State.PeakHeight, position.z)
    end
    
    -- Calculate fall distance
    if isFalling then
        self.State.FallDistance = self.State.PeakHeight - position.z
    else
        self.State.FallDistance = 0
    end
    
    -- Check if we're eligible for momentum conversion
    if self:CanConvertMomentum(player, velocity, currentTime) then
        -- Start conversion if not already converting
        if not self.State.IsConverting then
            self:StartConversion(player, velocity, currentTime)
        end
    end
    
    -- Process active conversion
    if self.State.IsConverting then
        self:ProcessConversion(player, velocity, currentTime, frameTime)
    end
    
    -- Update previous velocity
    self.State.PreviousVelocity = velocity
end

-- Check if player can convert momentum
function MomentumConversion:CanConvertMomentum(player, velocity, currentTime)
    -- Skip if conversion is disabled
    if not self.Config.EnableConversion then return false end
    
    -- Skip if already converting
    if self.State.IsConverting then return false end
    
    -- Skip if on cooldown
    if self.State.CooldownActive and 
       (currentTime - self.State.LastConversionTime) < self.Config.CooldownTime then
        return false
    end
    
    -- Check vertical speed requirement
    local verticalSpeed = math.abs(velocity.z)
    if velocity.z > -self.Config.MinVerticalSpeed then return false end
    
    -- Check key requirements
    if self.Config.RequireJumpKey and not player:KeyDown(IN_JUMP) then return false end
    if self.Config.RequireForwardKey and not player:KeyDown(IN_FORWARD) then return false end
    
    -- Check if we're falling (not just moving downward while on ground)
    if player:OnGround() then return false end
    
    -- All checks passed
    return true
end

-- Start momentum conversion
function MomentumConversion:StartConversion(player, velocity, currentTime)
    -- Set conversion state
    self.State.IsConverting = true
    self.State.ConversionStartTime = currentTime
    self.State.ConversionProgress = 0
    self.State.InitialVerticalSpeed = math.abs(velocity.z)
    self.State.ConvertedMomentum = Vector(0,0,0)
    
    -- Check for perfect timing
    local fallDuration = currentTime - self.State.FallStartTime
    local isPerfectTiming = fallDuration > 0.2 and fallDuration < 0.2 + self.Config.PerfectTimingWindow
    self.State.PerfectConversion = isPerfectTiming
    
    -- Apply initial effects
    if SERVER and self.Config.EnableEffects then
        self:ApplyConversionEffects(player, 0, isPerfectTiming)
    end
end

-- Process active conversion
function MomentumConversion:ProcessConversion(player, velocity, currentTime, frameTime)
    -- Calculate conversion progress
    local elapsedTime = currentTime - self.State.ConversionStartTime
    local progress = math.Clamp(elapsedTime / self.Config.ConversionDuration, 0, 1)
    self.State.ConversionProgress = progress
    
    -- Check if conversion is complete
    if progress >= 1.0 then
        self:EndConversion(player, currentTime)
        return
    end
    
    -- Calculate conversion amount for this frame
    local conversionAmount = self:CalculateConversionAmount(player, velocity, progress, frameTime)
    
    -- Apply the conversion
    if conversionAmount:LengthSqr() > 0 then
        -- Add to total converted momentum
        self.State.ConvertedMomentum = self.State.ConvertedMomentum + conversionAmount
        
        -- Apply to player velocity
        player:SetVelocity(conversionAmount)
    end
    
    -- Apply ongoing effects
    if SERVER and self.Config.EnableEffects and not self.State.EffectsActive then
        self:ApplyConversionEffects(player, progress, self.State.PerfectConversion)
    end
end

-- Calculate conversion amount for current frame
function MomentumConversion:CalculateConversionAmount(player, velocity, progress, frameTime)
    -- Get normalized progress with easing
    local easedProgress = math.pow(progress, self.Config.ConversionEasing)
    
    -- Calculate conversion strength based on vertical speed
    local verticalSpeed = math.abs(velocity.z)
    local conversionStrength = math.Clamp(
        (verticalSpeed - self.Config.MinVerticalSpeed) / 
        (self.Config.MaxVerticalSpeed - self.Config.MinVerticalSpeed),
        0, 1
    )
    
    -- Apply perfect timing bonus if applicable
    if self.State.PerfectConversion then
        conversionStrength = conversionStrength * self.Config.PerfectBoostMultiplier
    end
    
    -- Calculate conversion direction
    local conversionDir = self:CalculateConversionDirection(player)
    
    -- Calculate vertical component to remove
    local verticalRemoval = Vector(0, 0, velocity.z * (1 - self.Config.VerticalRetention) * frameTime * 10)
    
    -- Calculate horizontal component to add
    local horizontalAddition = conversionDir * verticalSpeed * self.Config.ConversionEfficiency * conversionStrength * frameTime * 10
    
    -- Combine for final conversion
    return horizontalAddition - verticalRemoval
end

-- Calculate direction for momentum conversion
function MomentumConversion:CalculateConversionDirection(player)
    -- Start with player's forward direction
    local eyeAngles = player:EyeAngles()
    local lookDir = eyeAngles:Forward()
    
    -- Remove vertical component for pure horizontal direction
    lookDir.z = 0
    if lookDir:LengthSqr() < 0.1 then
        lookDir = Vector(1, 0, 0) -- Default to forward if looking straight up/down
    else
        lookDir:Normalize()
    end
    
    -- Get current velocity direction (horizontal only)
    local velocity = player:GetVelocity()
    local horizontalVel = Vector(velocity.x, velocity.y, 0)
    local velDir = Vector(0, 0, 0)
    
    if horizontalVel:LengthSqr() > 100 then
        velDir = horizontalVel:GetNormalized()
    else
        velDir = lookDir -- Use look direction if not moving significantly
    end
    
    -- Blend between velocity direction and look direction based on directional influence
    local finalDir = LerpVector(self.Config.DirectionalInfluence, velDir, lookDir)
    finalDir:Normalize()
    
    return finalDir
end

-- End the conversion process
function MomentumConversion:EndConversion(player, currentTime)
    -- Update state
    self.State.IsConverting = false
    self.State.LastConversionTime = currentTime
    self.State.CooldownActive = true
    self.State.EffectsActive = false
    
    -- Apply final effects if perfect conversion
    if SERVER and self.Config.EnableEffects and self.State.PerfectConversion then
        self:ApplyPerfectConversionEffect(player)
    end
end

-- Apply visual and audio effects during conversion
function MomentumConversion:ApplyConversionEffects(player, progress, isPerfect)
    if not IsValid(player) then return end
    
    -- Mark effects as active
    self.State.EffectsActive = true
    
    -- Basic sound effect
    local pitch = 100 + (progress * 20)
    if isPerfect then pitch = pitch + 15 end
    
    -- Play appropriate sound based on progress
    if progress < 0.1 then
        -- Initial sound
        player:EmitSound("physics/body/body_medium_impact_soft" .. math.random(1, 7) .. ".wav", 75, pitch)
    elseif progress > 0.4 and progress < 0.6 then
        -- Mid-conversion sound
        player:EmitSound("physics/rubber/rubber_tire_impact_soft" .. math.random(1, 3) .. ".wav", 75, pitch + 10)
    end
    
    -- Visual effect (simple for now, could be enhanced)
    local effectPos = player:GetPos() + Vector(0, 0, 30)
    local effectData = EffectData()
    effectData:SetOrigin(effectPos)
    effectData:SetScale(1.0)
    util.Effect("cball_bounce", effectData)
end

-- Apply special effect for perfect conversion
function MomentumConversion:ApplyPerfectConversionEffect(player)
    if not IsValid(player) then return end
    
    -- Play a more dramatic sound
    player:EmitSound("physics/glass/glass_impact_bullet" .. math.random(1, 4) .. ".wav", 80, 110)
    
    -- More dramatic visual effect
    local effectPos = player:GetPos() + Vector(0, 0, 30)
    local effectData = EffectData()
    effectData:SetOrigin(effectPos)
    effectData:SetScale(2.0)
    util.Effect("cball_explode", effectData)
end

-- Register the module
return MomentumConversion
