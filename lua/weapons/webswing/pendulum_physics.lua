-- Pendulum Physics Enhancement System
-- Creates more authentic pendulum-like swinging motion

local PendulumPhysics = {}

-- Configuration
PendulumPhysics.Config = {
    -- Core pendulum parameters
    ArcEmphasisFactor = 1.2,         -- How much to emphasize the pendulum arc (1.0 = default, higher = more pronounced arcs)
    NaturalFrequency = 1.0,          -- Natural oscillation frequency multiplier (1.0 = default physics, higher = faster pendulum)
    ApexSlowdownFactor = 0.8,        -- Slowdown at apex of swing (1.0 = no slowdown, lower = more slowdown)
    
    -- Momentum and inertia settings
    MomentumPreservation = 1.2,      -- How well momentum is preserved during swings (1.0 = default, higher = better preservation)
    InertiaFactor = 1.1,             -- How much inertia affects the swing (1.0 = default, higher = more inertia)
    
    -- Gravity adjustment for more realistic arcs
    GravityModulation = true,        -- Enable gravity modulation during swing
    VerticalGravityFactor = 0.85,    -- Gravity factor when moving upward (lower = more "float" at top of arc)
    ApexGravityFactor = 0.7,         -- Gravity factor at the apex of the swing
    DownwardGravityFactor = 1.2,     -- Gravity factor when dropping downward
    
    -- Rotation and swing control 
    RotationalDamping = 0.8,         -- Damping of rotational motion (0-1, lower = less wobble)
    SwingAmplification = 1.15,       -- Amplification of swing force (1.0 = default, higher = stronger swings)
    ReflexCorrection = true,         -- Apply reflexive correction to make swings feel more controlled
    
    -- Advanced physics tweaks
    CentripetalForceEmphasis = 1.15, -- Emphasis on centripetal force during circular motion
    TangentialBoostFactor = 1.2,     -- Boost to tangential force for better arc transitions
    BobbleReduction = 0.7,           -- Reduction of side-to-side bobble (1.0 = default, lower = less bobble)
    
    -- Web behavior
    ElasticityFactor = 0.15,         -- How elastic the web feels (0.0 = rigid, higher = more elastic)
    TensionResponse = 0.8,           -- How quickly the web responds to tension changes
    
    -- Animation and feel
    BodyRotationFactor = 1.2,        -- How much the body rotates during swings
    SwingEntrySmoothing = 1.5,       -- Smoothing factor for entering a swing
    SwingExitBoost = 1.15,            -- Speed boost factor when exiting at optimal angle
    
    -- Web of Shadows style fall-to-swing enhancements
    FallingSwingBoost = 1.5,        -- Additional boost applied when entering a swing from a fast fall
    FallingArcEmphasis = 1.4,       -- Enhanced arc emphasis during fast falls
    FallingInertiaReduction = 0.7,  -- Reduce inertia during fast falls for more responsive arcs
}

-- State variables
PendulumPhysics.State = {
    CurrentPhase = 0,                -- Current phase of the pendulum swing (0-1, where 0.5 is apex)
    SwingDirection = Vector(0,0,0),  -- Current swing direction vector
    CentripetalForce = 0,            -- Current centripetal force magnitude
    LastSwingApex = 0,               -- Time of last swing apex
    InSwingTransition = false,       -- Whether we're in a transition between swings
    TransitionStartTime = 0,         -- When the current transition started
    LastAngularVelocity = 0,         -- Previous angular velocity
    PreviousPosition = Vector(0,0,0),-- Previous position for velocity calculation
    RotationAxis = Vector(0,0,0),    -- Current rotation axis
    SwingPlane = {                   -- Plane of the swing
        normal = Vector(0,1,0),
        distance = 0
    },
    ElasticExtension = 0,            -- Current elastic extension of the web
    PendulumLength = 100,            -- Current effective pendulum length
    PeakHeight = 0,                  -- Peak height reached in current swing
    ApexReached = false,             -- Whether we've reached the apex in the current swing
    GravityFactor = 1.0,             -- Current gravity adjustment factor
    LastOnGroundTime = 0,            -- Last time the player was on ground
    PostSwingBoostActive = false,    -- Is the post-swing momentum boost active?
    PostSwingBoostTime = 0           -- When the post-swing boost started
}

-- Initialize the pendulum physics system
function PendulumPhysics:Initialize()
    -- Reset state variables
    self.State.CurrentPhase = 0
    self.State.SwingDirection = Vector(0,0,0)
    self.State.CentripetalForce = 0
    self.State.LastSwingApex = 0
    self.State.InSwingTransition = false
    self.State.TransitionStartTime = 0
    self.State.RotationAxis = Vector(0,0,0)
    self.State.LastAngularVelocity = 0
    self.State.PreviousPosition = Vector(0,0,0)
    self.State.ElasticExtension = 0
    self.State.PendulumLength = 100
    self.State.PeakHeight = 0
    self.State.ApexReached = false
    self.State.GravityFactor = 1.0
    
    -- Load ConVars
    self:LoadConVarSettings()
    
    -- Register any needed hooks
    hook.Add("PostSwingPhysics", "PendulumPhysics_PostProcess", function(ragdoll, ply, constraintController)
        if IsValid(ragdoll) and IsValid(ply) then
            self:PostProcessPhysics(ragdoll, ply, constraintController)
        end
    end)
    
    return self
end

-- Load settings from ConVars
function PendulumPhysics:LoadConVarSettings()
    -- Load values from global ConVars if they exist
    if ConVarExists("webswing_pendulum_arc_emphasis") then
        self.Config.ArcEmphasisFactor = GetConVar("webswing_pendulum_arc_emphasis"):GetFloat()
    end
    
    if ConVarExists("webswing_pendulum_frequency") then
        self.Config.NaturalFrequency = GetConVar("webswing_pendulum_frequency"):GetFloat()
    end
    
    if ConVarExists("webswing_momentum_preservation") then
        self.Config.MomentumPreservation = GetConVar("webswing_momentum_preservation"):GetFloat()
    end
    
    if ConVarExists("webswing_swing_curve") then
        self.Config.SwingAmplification = GetConVar("webswing_swing_curve"):GetFloat()
    end
end

-- Calculate the current phase of the pendulum swing
function PendulumPhysics:CalculateSwingPhase(constraintController, position, velocity)
    if not constraintController or not constraintController.rope then return 0.5 end
    
    -- Get the attachment point (pivot of the pendulum)
    local attachPoint = constraintController.rope:GetPos()
    
    -- Vector from attachment to player
    local swingVector = position - attachPoint
    local horizontalDir = Vector(swingVector.x, swingVector.y, 0):GetNormalized()
    
    -- Calculate the angle from vertical
    local angleFromVertical = math.acos(math.abs(swingVector:GetNormalized():Dot(Vector(0,0,-1))))
    local normalizedAngle = angleFromVertical / math.pi  -- 0 = hanging straight down, 1 = horizontal
    
    -- Use velocity to determine which part of the swing we're in
    local horizontalVel = Vector(velocity.x, velocity.y, 0)
    local velDir = horizontalVel:GetNormalized()
    local velAlignment = horizontalDir:Dot(velDir)
    
    -- Determine direction of swing based on velocity alignment
    local swingDirection = (velAlignment > 0) and 1 or -1
    
    -- Calculate phase (0 = start of forward swing, 0.5 = apex, 1.0 = end of swing)
    local phase
    if swingDirection > 0 then
        -- Forward swing (0 to 0.5)
        phase = normalizedAngle * 0.5
    else
        -- Return swing (0.5 to 1.0)
        phase = 1.0 - normalizedAngle * 0.5
    end
    
    -- Store for other calculations
    self.State.CurrentPhase = phase
    
    -- Check if we've reached the apex
    if not self.State.ApexReached and phase > 0.45 and phase < 0.55 then
        self.State.ApexReached = true
        self.State.LastSwingApex = CurTime()
    elseif phase < 0.4 or phase > 0.6 then
        self.State.ApexReached = false
    end
    
    return phase
end

-- Calculate the swing plane for more consistent swinging
function PendulumPhysics:CalculateSwingPlane(constraintController, position, velocity)
    if not constraintController or not constraintController.rope then return end
    
    -- Get the attachment point (pivot of the pendulum)
    local attachPoint = constraintController.rope:GetPos()
    
    -- Calculate the swing axis (perpendicular to the plane of the swing)
    local swingVector = position - attachPoint
    local swingDirection = velocity:GetNormalized()
    
    -- The swing plane normal is perpendicular to both the swing vector and velocity
    local planeNormal = swingVector:Cross(swingDirection):GetNormalized()
    
    -- Sometimes the cross product can be zero, handle that case
    if planeNormal:LengthSqr() < 0.1 then
        planeNormal = Vector(0, 1, 0)
    else
        planeNormal:Normalize()
    end
    
    -- Calculate the plane distance
    local planeDistance = planeNormal:Dot(position)
    
    -- Store the swing plane
    self.State.SwingPlane.normal = planeNormal
    self.State.SwingPlane.distance = planeDistance
    
    -- Store for rotation calculations
    self.State.RotationAxis = planeNormal
    
    -- Calculate and store pendulum length (distance from attachment to player)
    self.State.PendulumLength = swingVector:Length()
    
    return self.State.SwingPlane
end

-- Core function to enhance pendulum physics
function PendulumPhysics:EnhancePhysics(ragdoll, owner, constraintController, frameTime)
    if not IsValid(ragdoll) or not IsValid(owner) or not constraintController then return end
    
    -- Get the main physics object (body)
    local physObj = ragdoll:GetPhysicsObjectNum(11) -- Main body bone
    if not IsValid(physObj) then return end
    
    -- Get current state
    local position = physObj:GetPos()
    local velocity = physObj:GetVelocity()
    local speed = velocity:Length()
    local horizontalSpeed = Vector(velocity.x, velocity.y, 0):Length()
    
    -- Detect falling for Web of Shadows style responsiveness
    local fallingFast = velocity.z < -300
    local verticalSpeed = math.abs(velocity.z)
    local fallFactor = math.Clamp(verticalSpeed / 1000, 0, 1)
    
    -- Apply Web of Shadows style adjustments during fast falls
    local arcEmphasis = self.Config.ArcEmphasisFactor
    local inertiaFactor = self.Config.InertiaFactor
    local swingAmplification = self.Config.SwingAmplification
    
    if fallingFast then
        -- Enhance arc emphasis during fast falls
        arcEmphasis = arcEmphasis * Lerp(fallFactor, 1, self.Config.FallingArcEmphasis)
        
        -- Reduce inertia during fast falls for more responsive control
        inertiaFactor = inertiaFactor * Lerp(fallFactor, 1, self.Config.FallingInertiaReduction)
        
        -- Amplify swing force based on fall speed
        swingAmplification = swingAmplification * Lerp(fallFactor, 1, self.Config.FallingSwingBoost)
    end
    
    -- Calculate swing phase and plane
    local phase = self:CalculateSwingPhase(constraintController, position, velocity)
    local swingPlane = self:CalculateSwingPlane(constraintController, position, velocity)
    
    -- Get attachment point (pendulum pivot)
    local attachPoint = constraintController.rope:GetPos()
    
    -- Calculate pendulum vectors
    local toAttach = (attachPoint - position):GetNormalized()
    local pendulumVector = (position - attachPoint)
    local pendulumDir = pendulumVector:GetNormalized()
    
    -- Calculate natural pendulum forces
    local gravityForce = Vector(0, 0, -600) -- Base gravity
    local pendulumMass = physObj:GetMass()
    
    -- Modulate gravity based on swing phase for more natural arcs
    if self.Config.GravityModulation then
        local verticalMotion = velocity.z
        
        if phase < 0.5 and verticalMotion > 0 then
            -- Upward swing - reduce gravity
            self.State.GravityFactor = self.Config.VerticalGravityFactor
        elseif phase >= 0.45 and phase <= 0.55 then
            -- At apex - further reduce gravity
            self.State.GravityFactor = self.Config.ApexGravityFactor
        elseif phase > 0.5 and verticalMotion < 0 then
            -- Downward swing - increase gravity
            self.State.GravityFactor = self.Config.DownwardGravityFactor
        else
            -- Default
            self.State.GravityFactor = 1.0
        end
        
        gravityForce = gravityForce * self.State.GravityFactor
    end
    
    -- Calculate centripetal force for circular motion
    local centripetal = Vector(0,0,0)
    if horizontalSpeed > 50 then
        -- Force toward the center of rotation (perpendicular to velocity)
        local centripetalDir = (attachPoint - position):GetNormalized()
        local centripetalMag = (horizontalSpeed * horizontalSpeed) / self.State.PendulumLength
        centripetal = centripetalDir * centripetalMag * pendulumMass * self.Config.CentripetalForceEmphasis
        
        -- Store for other calculations
        self.State.CentripetalForce = centripetalMag
    end
    
    -- Calculate tangential force for better arcs
    local tangential = Vector(0,0,0)
    if speed > 50 then
        -- Force perpendicular to the pendulum (tangent to the circular motion)
        local pendulumPerp = self.State.RotationAxis:Cross(pendulumDir):GetNormalized()
        
        -- Scale tangential force based on phase (stronger in middle of swing, weaker at endpoints)
        local phaseMultiplier = math.sin(phase * math.pi) -- Peaks at phase 0.5
        
        -- Add tangential boost
        tangential = pendulumPerp * horizontalSpeed * pendulumMass * 
                    phaseMultiplier * self.Config.TangentialBoostFactor * frameTime * 60
    end
    
    -- Calculate arc emphasis force
    local arcEmphasisForce = Vector(0,0,0)
    if speed > 50 then
        -- Calculate the ideal arc direction based on pendulum position
        local idealDir = Vector(-pendulumDir.x, -pendulumDir.y, 0)
        idealDir:Normalize()
        
        -- Calculate how much the current velocity deviates from the ideal arc
        local currentDir = Vector(velocity.x, velocity.y, 0):GetNormalized()
        local alignment = idealDir:Dot(currentDir)
        
        -- Only apply correction if moving in a somewhat different direction
        if alignment < 0.9 then
            -- Calculate correction force (stronger when more deviation)
            local correctionStrength = (1 - alignment) * arcEmphasis
            arcEmphasisForce = idealDir * horizontalSpeed * pendulumMass * correctionStrength * frameTime * 30
        end
    end
    
    -- Apply elastic rebound when tension changes rapidly
    local elasticRebound = Vector(0,0,0)
    if self.Config.ElasticityFactor > 0 and constraintController then
        local currentLength = constraintController.current_length
        local targetLength = constraintController.initial_length or currentLength
        
        -- Calculate extension or compression
        local extension = currentLength - targetLength
        local extensionDelta = extension - self.State.ElasticExtension
        
        -- Only apply elastic force if the extension is changing rapidly
        if math.abs(extensionDelta) > 2 then
            local elasticForce = -extensionDelta * pendulumMass * self.Config.ElasticityFactor
            elasticRebound = toAttach * elasticForce
        end
        
        -- Store current extension
        self.State.ElasticExtension = extension
    end
    
    -- Apply slowdown at apex of swing for more "float" time
    local apexSlowdown = Vector(0,0,0)
    if phase >= 0.45 and phase <= 0.55 and self.Config.ApexSlowdownFactor < 1.0 then
        -- Calculate slowdown factor
        local slowFactor = math.min(1 - self.Config.ApexSlowdownFactor, 0.5)
        
        -- Apply slight drag at apex to create "float" feeling
        apexSlowdown = -velocity * slowFactor * pendulumMass * frameTime * 10
    end
    
    -- Apply bob reduction to minimize side-to-side motion
    local bobReduction = Vector(0,0,0)
    if self.Config.BobbleReduction < 1.0 and self.State.SwingPlane.normal:LengthSqr() > 0.1 then
        -- Calculate lateral motion (perpendicular to swing plane)
        local planeNormal = self.State.SwingPlane.normal
        local lateralComponent = velocity:Dot(planeNormal) * planeNormal
        
        -- Only dampen if lateral motion is significant
        if lateralComponent:LengthSqr() > 100 then
            local reductionStrength = (1 - self.Config.BobbleReduction) * 0.8
            bobReduction = -lateralComponent * pendulumMass * reductionStrength * frameTime * 20
        end
    end
    
    -- Apply reflex correction for more controlled swings
    local reflexCorrection = Vector(0,0,0)
    if self.Config.ReflexCorrection and owner:KeyDown(IN_FORWARD) then
        -- Get player's look direction as the intended direction
        local intendedDir = owner:EyeAngles():Forward()
        intendedDir.z = 0
        intendedDir:Normalize()
        
        -- Calculate current horizontal movement direction
        local currentDir = Vector(velocity.x, velocity.y, 0)
        local currentSpeed = currentDir:Length()
        
        if currentSpeed > 50 then
            currentDir:Normalize()
            
            -- Calculate angle between current and intended direction
            local dirDot = currentDir:Dot(intendedDir)
            
            -- Only apply correction if there's significant deviation
            if dirDot < 0.8 then
                -- Calculate correction force (stronger when more deviation)
                local correctionStrength = (1 - dirDot) * 0.4 -- 0.4 means subtle correction
                reflexCorrection = intendedDir * currentSpeed * pendulumMass * correctionStrength * frameTime * 30
            end
        end
    end
    
    -- Calculate body rotation for more dynamic swinging
    if self.Config.BodyRotationFactor > 1.0 and horizontalSpeed > 200 then
        local bodyPhys = ragdoll:GetPhysicsObjectNum(0) -- Pelvis/main body
        if IsValid(bodyPhys) then
            -- Calculate rotation based on swing motion
            local swingRight = self.State.RotationAxis:Cross(velocity:GetNormalized())
            local rotationAngle = Angle(
                swingRight.x * 20 * (self.Config.BodyRotationFactor - 1.0),
                swingRight.y * 20 * (self.Config.BodyRotationFactor - 1.0),
                swingRight.z * 20 * (self.Config.BodyRotationFactor - 1.0)
            )
            
            -- Apply gentle rotation force
            bodyPhys:AddAngleVelocity(rotationAngle * frameTime * 5)
        end
    end
    
    -- Combine all forces
    local pendulumForce = centripetal + tangential + arcEmphasisForce + 
                          elasticRebound + apexSlowdown + bobReduction + 
                          reflexCorrection
                          
    -- Scale the force by the swing amplification
    pendulumForce = pendulumForce * swingAmplification
    
    -- Add modulated gravity
    pendulumForce = pendulumForce + gravityForce * pendulumMass
    
    -- Apply the combined force
    physObj:ApplyForceCenter(pendulumForce)
    
    -- Store current velocity and position for next frame
    self.State.PreviousPosition = position
    
    return pendulumForce
end

-- Post-process physics after the main physics simulation
function PendulumPhysics:PostProcessPhysics(ragdoll, owner, constraintController)
    if not IsValid(ragdoll) or not IsValid(owner) then return end
    
    -- Get the main physics object
    local physObj = ragdoll:GetPhysicsObjectNum(11) -- Main body bone
    if not IsValid(physObj) then return end
    
    -- Apply post-swing momentum boost if conditions are right
    if self.State.PostSwingBoostActive then
        local boostDuration = 0.3 -- How long the boost lasts
        local timeSinceBoost = CurTime() - self.State.PostSwingBoostTime
        
        if timeSinceBoost <= boostDuration then
            -- Calculate boost factor that fades out over time
            local boostFactor = Lerp(timeSinceBoost / boostDuration, self.Config.SwingExitBoost - 1.0, 0)
            
            -- Apply boost in current travel direction
            local velocity = physObj:GetVelocity()
            local speed = velocity:Length()
            
            if speed > 100 then
                local boostForce = velocity:GetNormalized() * speed * physObj:GetMass() * boostFactor
                physObj:ApplyForceCenter(boostForce)
            end
        else
            -- End boost
            self.State.PostSwingBoostActive = false
        end
    end
end

-- Called when a web swing starts
function PendulumPhysics:OnSwingStart(ragdoll, owner, constraintController)
    if not IsValid(ragdoll) or not IsValid(owner) then return end
    
    -- Reset swing state
    self.State.CurrentPhase = 0
    self.State.ApexReached = false
    self.State.PeakHeight = owner:GetPos().z
    self.State.ElasticExtension = 0
    self.State.PostSwingBoostActive = false
    
    -- Apply entry smoothing if configured
    if self.Config.SwingEntrySmoothing > 1.0 then
        local physObj = ragdoll:GetPhysicsObjectNum(11) -- Main body bone
        if IsValid(physObj) then
            -- Calculate a gentler entry into the swing by reducing sudden velocity changes
            local currentVel = physObj:GetVelocity()
            local speed = currentVel:Length()
            
            if speed > 200 then
                -- Apply slight damping to create a smoother entry
                local entryDamping = (self.Config.SwingEntrySmoothing - 1.0) * 0.5
                local dampingForce = -currentVel * entryDamping
                
                physObj:ApplyForceCenter(dampingForce)
            end
        end
    end
end

-- Called when a web swing ends
function PendulumPhysics:OnSwingEnd(ragdoll, owner, releaseVelocity)
    if not IsValid(ragdoll) or not IsValid(owner) then return end
    
    -- Check if we should apply a swing exit boost
    if self.Config.SwingExitBoost > 1.0 then
        -- Calculate the swing phase at release
        local phase = self.State.CurrentPhase
        
        -- Best boost at optimal release point (around phase 0.35 or 0.65)
        local optimalEarly = math.abs(phase - 0.35)
        local optimalLate = math.abs(phase - 0.65)
        local releaseQuality = 1.0 - math.min(optimalEarly, optimalLate) * 5 -- 1.0 = perfect, 0.0 = worst
        
        -- Only boost if release was reasonably timed
        if releaseQuality > 0.5 then
            -- Apply post-swing momentum boost
            self.State.PostSwingBoostActive = true
            self.State.PostSwingBoostTime = CurTime()
            
            -- Apply immediate velocity boost to the player
            local boostMultiplier = Lerp(releaseQuality, 1.0, self.Config.SwingExitBoost)
            owner:SetVelocity(releaseVelocity * (boostMultiplier - 1.0))
        end
    end
end

return PendulumPhysics 