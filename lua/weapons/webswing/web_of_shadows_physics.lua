-- Web of Shadows Physics Enhancement System
-- This module enhances the physics to match the feel of Spider-Man: Web of Shadows

local WebOfShadowsPhysics = {}

-- Configuration based on Web of Shadows feel
WebOfShadowsPhysics.Config = {
    -- Core swing physics
    BaseGravity = 650,                -- Base gravity value (vanilla = 600)
    SwingGravityReduction = 0.65,     -- Gravity reduction during swings (lower = more floaty)
    MomentumPreservation = 1.4,       -- How well momentum is preserved (higher = better preservation)

    -- Arc and pendulum enhancements
    ArcEmphasisFactor = 1.5,          -- How pronounced the swing arcs are (higher = more dramatic)
    SwingAcceleration = 1.35,         -- How quickly speed builds during swings
    ApexFloatTime = 0.25,             -- How long to "float" at the apex of swings

    -- Web of Shadows specific mechanics
    FallToSwingBoost = 1.8,           -- Speed boost when transitioning from fall to swing
    SwingKickoffBoost = 1.5,          -- Boost when pushing off at the bottom of a swing
    VerticalBoostFactor = 1.4,        -- Enhanced vertical movement for higher arcs

    -- Dive mechanics
    DiveAcceleration = 1.6,           -- How quickly speed builds during dives
    DiveRecoveryBoost = 1.5,          -- Boost when recovering from a dive into a swing
    MaxDiveSpeed = 1200,              -- Maximum speed during a dive

    -- Advanced physics tuning
    CentripetalForceEmphasis = 1.4,   -- Emphasis on circular motion (higher = tighter turns)
    TangentialForceEmphasis = 1.3,    -- Emphasis on forward motion in swings
    InertiaCompensation = 0.7,        -- Compensation for inertia (lower = more responsive)

    -- Transition smoothing
    SwingToSwingSmoothing = 0.8,      -- Smoothing when transitioning between swings
    FallToSwingSmoothing = 0.6,       -- Smoothing when transitioning from fall to swing
    SwingToFallSmoothing = 0.9,       -- Smoothing when transitioning from swing to fall

    -- Contextual physics adjustments
    CornerSwingBoost = 1.3,           -- Speed boost when swinging around corners
    NarrowSpaceSmoothing = 0.7,       -- Extra smoothing in narrow spaces
    OpenAreaSpeedBoost = 1.2,         -- Speed boost in open areas

    -- Skill-based mechanics (perfect swing functionality removed)
    PerfectTimingBoost = 1.0,         -- Disabled (set to 1.0 - no boost)
    RhythmicSwingBonus = 1.0,         -- Disabled (set to 1.0 - no bonus)
    ConsecutiveSwingMultiplier = 0.0  -- Disabled (set to 0.0 - no multiplier)
}

-- State tracking
WebOfShadowsPhysics.State = {
    CurrentGravityFactor = 1.0,
    LastSwingPhase = 0.5,
    InFastFall = false,
    FastFallStartTime = 0,
    LastGroundTime = 0,
    ConsecutiveSwings = 0,
    LastSwingQuality = 0,
    SwingStartTime = 0,
    LastCornerTime = 0,
    InNarrowSpace = false,
    CurrentSpeedMultiplier = 1.0,
    PeakSwingHeight = 0,
    ApexReachedTime = 0,
    IsFloatingAtApex = false,
    LastReleaseTime = 0,
    LastReleaseQuality = 0,
    VelocityHistory = {},
    HistorySize = 5
}

-- Initialize the system
function WebOfShadowsPhysics:Initialize()
    -- Reset state
    self.State.CurrentGravityFactor = 1.0
    self.State.LastSwingPhase = 0.5
    self.State.InFastFall = false
    self.State.FastFallStartTime = 0
    self.State.LastGroundTime = 0
    self.State.ConsecutiveSwings = 0
    self.State.LastSwingQuality = 0
    self.State.SwingStartTime = 0
    self.State.LastCornerTime = 0
    self.State.InNarrowSpace = false
    self.State.CurrentSpeedMultiplier = 1.0
    self.State.PeakSwingHeight = 0
    self.State.ApexReachedTime = 0
    self.State.IsFloatingAtApex = false
    self.State.LastReleaseTime = 0
    self.State.LastReleaseQuality = 0
    self.State.VelocityHistory = {}

    -- Load ConVar settings
    self:LoadConVarSettings()

    return self
end

-- Load settings from ConVars
function WebOfShadowsPhysics:LoadConVarSettings()
    -- Create ConVars if they don't exist
    if not ConVarExists("webswing_wos_gravity") then
        CreateConVar("webswing_wos_gravity", tostring(self.Config.BaseGravity), FCVAR_ARCHIVE + FCVAR_REPLICATED, "Base gravity value for Web of Shadows physics", 500, 800)
    end

    if not ConVarExists("webswing_wos_momentum") then
        CreateConVar("webswing_wos_momentum", tostring(self.Config.MomentumPreservation), FCVAR_ARCHIVE + FCVAR_REPLICATED, "Momentum preservation factor for Web of Shadows physics", 1.0, 2.0)
    end

    if not ConVarExists("webswing_wos_arc_emphasis") then
        CreateConVar("webswing_wos_arc_emphasis", tostring(self.Config.ArcEmphasisFactor), FCVAR_ARCHIVE + FCVAR_REPLICATED, "Arc emphasis factor for Web of Shadows physics", 1.0, 2.0)
    end

    if not ConVarExists("webswing_wos_fall_boost") then
        CreateConVar("webswing_wos_fall_boost", tostring(self.Config.FallToSwingBoost), FCVAR_ARCHIVE + FCVAR_REPLICATED, "Fall-to-swing boost factor for Web of Shadows physics", 1.0, 2.5)
    end

    -- Load values from ConVars
    self.Config.BaseGravity = GetConVar("webswing_wos_gravity"):GetFloat()
    self.Config.MomentumPreservation = GetConVar("webswing_wos_momentum"):GetFloat()
    self.Config.ArcEmphasisFactor = GetConVar("webswing_wos_arc_emphasis"):GetFloat()
    self.Config.FallToSwingBoost = GetConVar("webswing_wos_fall_boost"):GetFloat()
end

-- Calculate the current phase of the pendulum swing (0-1)
function WebOfShadowsPhysics:CalculateSwingPhase(constraintController, position, velocity)
    if not constraintController or not constraintController.rope then return 0.5 end

    -- Get the attachment point (pivot of the pendulum)
    local attachPoint = constraintController.rope:GetPos()

    -- Vector from attachment to player
    local swingVector = position - attachPoint
    local horizontalDir = Vector(swingVector.x, swingVector.y, 0):GetNormalized()

    -- Calculate the angle from vertical
    local angleFromVertical = math.acos(math.abs(swingVector:GetNormalized():Dot(Vector(0,0,-1))))
    local normalizedAngle = angleFromVertical / math.pi  -- 0 = hanging straight down, 1 = horizontal

    -- Determine swing direction (forward/backward half of the swing)
    local swingDirection = 0
    if velocity:Length() > 50 then
        local velocityDir = velocity:GetNormalized()
        local dotProduct = horizontalDir:Dot(Vector(velocityDir.x, velocityDir.y, 0):GetNormalized())
        swingDirection = dotProduct > 0 and 1 or -1
    end

    -- Calculate phase based on angle and direction
    -- Phase 0.0 = start of swing, 0.5 = apex, 1.0 = end of swing
    local phase
    if swingDirection >= 0 then
        phase = normalizedAngle * 0.5  -- 0.0 to 0.5 (first half)
    else
        phase = 1.0 - normalizedAngle * 0.5  -- 0.5 to 1.0 (second half)
    end

    -- Store for next frame
    self.State.LastSwingPhase = phase

    return phase
end

-- Detect and handle fast falls (Web of Shadows style dive mechanics)
function WebOfShadowsPhysics:HandleFastFall(owner, velocity, frameTime)
    local verticalVelocity = velocity.z
    local horizontalSpeed = Vector(velocity.x, velocity.y, 0):Length()

    -- Detect if we're in a fast fall
    if verticalVelocity < -300 then
        if not self.State.InFastFall then
            -- Just started falling fast
            self.State.InFastFall = true
            self.State.FastFallStartTime = CurTime()
        end

        -- Calculate fall duration
        local fallDuration = CurTime() - self.State.FastFallStartTime

        -- Apply increasing acceleration during the dive (Web of Shadows style)
        local diveAcceleration = Vector(0, 0, -self.Config.DiveAcceleration * 100 * frameTime)

        -- Cap the maximum dive speed
        if verticalVelocity > -self.Config.MaxDiveSpeed then
            return diveAcceleration
        end
    else
        -- No longer in fast fall
        self.State.InFastFall = false
    end

    return Vector(0, 0, 0)
end

-- Calculate enhanced gravity for more dramatic arcs
function WebOfShadowsPhysics:CalculateEnhancedGravity(phase, velocity, pendulumMass)
    local verticalMotion = velocity.z
    local gravityFactor = 1.0

    -- Web of Shadows style gravity modulation for dramatic arcs
    if phase < 0.3 and verticalMotion > 0 then
        -- Early upward swing - reduce gravity significantly for higher arcs
        gravityFactor = self.Config.SwingGravityReduction * 0.8
    elseif phase >= 0.45 and phase <= 0.55 then
        -- At apex - further reduce gravity for "float" effect
        gravityFactor = self.Config.SwingGravityReduction * 0.6

        -- Track apex time for "float" effect
        if not self.State.IsFloatingAtApex then
            self.State.IsFloatingAtApex = true
            self.State.ApexReachedTime = CurTime()
        end

        -- Apply extended float if within float time window
        local apexTime = CurTime() - self.State.ApexReachedTime
        if apexTime < self.Config.ApexFloatTime then
            -- Progressive reduction during float time
            local floatFactor = 1 - (apexTime / self.Config.ApexFloatTime)
            gravityFactor = gravityFactor * (0.5 + 0.5 * floatFactor)
        end
    elseif phase > 0.7 and verticalMotion < 0 then
        -- Late downward swing - increase gravity for faster drops
        gravityFactor = 1.2
        self.State.IsFloatingAtApex = false
    else
        -- Default - slightly reduced gravity during swings
        gravityFactor = self.Config.SwingGravityReduction
        self.State.IsFloatingAtApex = false
    end

    -- Store current gravity factor
    self.State.CurrentGravityFactor = gravityFactor

    -- Calculate the actual gravity force
    return Vector(0, 0, -self.Config.BaseGravity) * gravityFactor * pendulumMass
end

-- Calculate enhanced centripetal force for tighter turns
function WebOfShadowsPhysics:CalculateCentripetalForce(position, attachPoint, velocity, pendulumLength, pendulumMass)
    local horizontalSpeed = Vector(velocity.x, velocity.y, 0):Length()

    if horizontalSpeed < 50 then return Vector(0, 0, 0) end

    -- Calculate direction to center of rotation
    local centripetalDir = (attachPoint - position):GetNormalized()

    -- Web of Shadows style centripetal force calculation
    local centripetalMag = (horizontalSpeed * horizontalSpeed) / pendulumLength

    -- Apply emphasis factor for tighter turns
    centripetalMag = centripetalMag * self.Config.CentripetalForceEmphasis

    -- Calculate final force
    return centripetalDir * centripetalMag * pendulumMass
end

-- Calculate enhanced tangential force for better forward momentum
function WebOfShadowsPhysics:CalculateTangentialForce(position, attachPoint, velocity, phase, pendulumMass, frameTime)
    local speed = velocity:Length()

    if speed < 50 then return Vector(0, 0, 0) end

    -- Calculate pendulum direction
    local pendulumDir = (position - attachPoint):GetNormalized()

    -- Calculate rotation axis (perpendicular to pendulum plane)
    local velocityDir = velocity:GetNormalized()
    local rotationAxis = pendulumDir:Cross(velocityDir):GetNormalized()

    -- Calculate tangential direction (perpendicular to pendulum)
    local tangentialDir = rotationAxis:Cross(pendulumDir):GetNormalized()

    -- Scale tangential force based on phase (stronger in middle of swing, weaker at endpoints)
    local phaseMultiplier = math.sin(phase * math.pi) -- Peaks at phase 0.5

    -- Web of Shadows style tangential force calculation
    local tangentialMag = speed * phaseMultiplier * self.Config.TangentialForceEmphasis

    -- Apply swing acceleration for better momentum building
    tangentialMag = tangentialMag * self.Config.SwingAcceleration

    -- Calculate final force
    return tangentialDir * tangentialMag * pendulumMass * frameTime * 60
end

-- Calculate kickoff boost at bottom of swing
function WebOfShadowsPhysics:CalculateKickoffBoost(phase, velocity, pendulumMass, frameTime)
    -- Only apply near bottom of swing
    if phase > 0.1 and phase < 0.9 then return Vector(0, 0, 0) end

    local speed = velocity:Length()
    if speed < 100 then return Vector(0, 0, 0) end

    -- Calculate boost direction (forward and slightly upward)
    local boostDir = velocity:GetNormalized()
    boostDir.z = boostDir.z + 0.2 -- Add slight upward component
    boostDir:Normalize()

    -- Calculate boost magnitude
    local boostMag = speed * 0.2 * self.Config.SwingKickoffBoost

    -- Calculate final force
    return boostDir * boostMag * pendulumMass * frameTime * 30
end

-- Apply fall-to-swing transition boost
function WebOfShadowsPhysics:ApplyFallToSwingBoost(velocity, wasInFastFall, pendulumMass, frameTime)
    if not wasInFastFall then return Vector(0, 0, 0) end

    -- Calculate boost direction (forward and upward)
    local horizontalDir = Vector(velocity.x, velocity.y, 0):GetNormalized()
    local boostDir = horizontalDir + Vector(0, 0, 0.5) -- Add upward component
    boostDir:Normalize()

    -- Calculate boost magnitude based on vertical speed
    local verticalSpeed = math.abs(velocity.z)
    local boostMag = math.min(verticalSpeed, 500) * self.Config.FallToSwingBoost

    -- Calculate final force
    return boostDir * boostMag * pendulumMass * frameTime * 20
end

-- Core function to enhance physics with Web of Shadows feel
function WebOfShadowsPhysics:EnhancePhysics(ragdoll, owner, constraintController, frameTime)
    if not IsValid(ragdoll) or not IsValid(owner) or not constraintController then return end

    -- Reload ConVar settings occasionally
    if CurTime() % 5 < frameTime then
        self:LoadConVarSettings()
    end

    -- Get the main physics object (body)
    local physObj = ragdoll:GetPhysicsObjectNum(11) -- Main body bone
    if not IsValid(physObj) then return end

    -- Get current state
    local position = physObj:GetPos()
    local velocity = physObj:GetVelocity()
    local speed = velocity:Length()
    local pendulumMass = physObj:GetMass()

    -- Store velocity history for smooth transitions
    table.insert(self.State.VelocityHistory, 1, velocity)
    if #self.State.VelocityHistory > self.State.HistorySize then
        table.remove(self.State.VelocityHistory)
    end

    -- Get attachment point (pendulum pivot)
    local attachPoint = constraintController.rope:GetPos()

    -- Calculate pendulum length
    local pendulumVector = (position - attachPoint)
    local pendulumLength = pendulumVector:Length()

    -- Calculate swing phase
    local phase = self:CalculateSwingPhase(constraintController, position, velocity)

    -- Check if we were in a fast fall
    local wasInFastFall = self.State.InFastFall

    -- Handle fast falls (Web of Shadows dive mechanics)
    local diveForce = self:HandleFastFall(owner, velocity, frameTime)

    -- Calculate enhanced gravity
    local gravityForce = self:CalculateEnhancedGravity(phase, velocity, pendulumMass)

    -- Calculate enhanced centripetal force
    local centripetalForce = self:CalculateCentripetalForce(position, attachPoint, velocity, pendulumLength, pendulumMass)

    -- Calculate enhanced tangential force
    local tangentialForce = self:CalculateTangentialForce(position, attachPoint, velocity, phase, pendulumMass, frameTime)

    -- Calculate kickoff boost
    local kickoffForce = self:CalculateKickoffBoost(phase, velocity, pendulumMass, frameTime)

    -- Apply fall-to-swing transition boost
    local fallToSwingForce = self:ApplyFallToSwingBoost(velocity, wasInFastFall, pendulumMass, frameTime)

    -- Combine all forces
    local totalForce = gravityForce + centripetalForce + tangentialForce +
                       kickoffForce + fallToSwingForce + diveForce

    -- Apply the combined force
    physObj:ApplyForceCenter(totalForce)

    return totalForce
end

-- Handle web release with Web of Shadows style
function WebOfShadowsPhysics:EnhanceWebRelease(player, releaseVelocity, swingPhase)
    if not IsValid(player) then return releaseVelocity end

    -- Store original velocity
    local originalVel = releaseVelocity:Clone()
    local speed = originalVel:Length()

    -- Calculate release quality based on phase
    local releaseQuality = 0

    -- Web of Shadows optimal release points are at ~0.3 and ~0.7 phase
    local earlyOptimal = math.abs(swingPhase - 0.3)
    local lateOptimal = math.abs(swingPhase - 0.7)
    local optimalDist = math.min(earlyOptimal, lateOptimal)

    -- Score is inverse to distance from optimal (closer = higher)
    releaseQuality = math.Clamp(1 - (optimalDist / 0.3), 0, 1)

    -- Store release quality
    self.State.LastReleaseQuality = releaseQuality
    self.State.LastReleaseTime = CurTime()

    -- Calculate direction adjustments based on player input
    local eyeAngles = player:EyeAngles()
    local lookDir = eyeAngles:Forward()

    -- Determine release type based on player input and look direction
    local releaseType = "standard"
    local speedMultiplier = 1.0

    -- Check for boost release (Jump + Forward)
    if player:KeyDown(IN_JUMP) and player:KeyDown(IN_FORWARD) and eyeAngles.pitch < 30 then
        releaseType = "boost"
        speedMultiplier = 1.3

        -- Enhanced forward component
        local forwardBoost = lookDir * (speed * 0.2)
        forwardBoost.z = math.max(forwardBoost.z, 0) -- Ensure we don't push downward
        originalVel = originalVel + forwardBoost

    -- Check for dive release (Jump + Down look angle)
    elseif player:KeyDown(IN_JUMP) and eyeAngles.pitch > 30 then
        releaseType = "dive"
        speedMultiplier = 1.2

        -- Enhanced downward component with forward momentum
        local diveDir = lookDir
        diveDir.z = math.min(diveDir.z, -0.3) -- Ensure downward component
        originalVel = originalVel + diveDir * (speed * 0.25)

    -- Check for upward release (Jump + Up look angle)
    elseif player:KeyDown(IN_JUMP) and eyeAngles.pitch < -20 then
        releaseType = "upward"
        speedMultiplier = 1.15

        -- Enhanced upward component
        local upwardBoost = Vector(0, 0, speed * 0.35)
        originalVel = originalVel + upwardBoost
    end

    -- Perfect timing and consecutive swing bonuses removed

    -- Reset consecutive swings counter
    self.State.ConsecutiveSwings = 0

    -- Apply final speed multiplier
    local finalVel = originalVel * speedMultiplier

    -- Perfect release effects removed

    return finalVel
end

-- Register the module
return WebOfShadowsPhysics
