-- Physics system module for web swinging

local PhysicsSystem = {}

-- Define the standard mass for all ragdoll physics objects
PhysicsSystem.STANDARD_RAGDOLL_MASS = 1

-- No rhythm system implemented

-- Advanced momentum system tracking (perfect swing functionality removed)
PhysicsSystem.MomentumSystem = {
    ConsecutivePerfectSwings = 0, -- Kept for compatibility but not used
    MaxConsecutiveSwings = 1, -- Set to 1 to disable consecutive swing bonuses
    SpeedMultiplierPerSwing = 0, -- Set to 0 to disable speed boost
    MomentumDecayRate = 0.5, -- How quickly momentum decays when not swinging
    LastSwingTime = 0,
    MomentumMultiplier = 1.0, -- Fixed at 1.0 to disable momentum multiplier
    PeakSpeed = 0, -- Track the peak speed achieved
    IsDiving = false,
    DiveBoostFactor = 1.5, -- Multiplier for dive boost
    DiveStartTime = 0,
    DiveDuration = 0.75, -- Seconds for dive boost to last
    VelocityHistory = {}, -- Store recent velocities for smooth transitions
    HistorySize = 5 -- Number of velocity entries to store
}

-- Initialize the momentum system with values from ConVars
function PhysicsSystem.InitializeMomentumSystem()
    local system = PhysicsSystem.MomentumSystem
    system.MaxConsecutiveSwings = GetConVar("webswing_momentum_max_swings"):GetInt()
    system.SpeedMultiplierPerSwing = GetConVar("webswing_momentum_boost_per_swing"):GetFloat()
    system.MomentumDecayRate = GetConVar("webswing_momentum_decay_rate"):GetFloat()
    system.DiveBoostFactor = GetConVar("webswing_dive_boost_factor"):GetFloat()
    system.DiveDuration = GetConVar("webswing_dive_duration"):GetFloat()
    return system
end

-- Calculate elastic constants for constraints
function PhysicsSystem.CalcElasticConstant(Phys1, Phys2, Ent1, Ent2, iFixed)
    local minMass = 0

    if Ent1:IsWorld() then
        minMass = Phys2:GetMass()
    elseif Ent2:IsWorld() then
        minMass = Phys1:GetMass()
    else
        minMass = math.min(Phys1:GetMass(), Phys2:GetMass())
    end

    -- Default values
    local const = minMass * 100
    local damp = const * 0.2

    if not iFixed then
        const = minMass * 50
        damp = const * 1
    end

    -- Model-specific adjustments for problematic models
    if Ent1:IsValid() and not Ent1:IsWorld() and Ent1:GetClass() == "prop_ragdoll" then
        local modelName = Ent1:GetModel():lower()
        -- Increase constraint stiffness and damping for problematic models like combine
        if string.find(modelName, "combine") or
           string.find(modelName, "police") or
           string.find(modelName, "soldier") then
            -- Increase stiffness and damping for problematic models
            const = const * 1.25
            damp = damp * 1.5
        end
    end

    return const, damp
end

-- Apply physics forces to the ragdoll during web swinging
function PhysicsSystem.ApplySwingForces(ragdoll, owner, constraintController, frameTime, rhythmSystem)
    if not IsValid(ragdoll) then return end

    -- Initialize momentum system with ConVar values if necessary
    if PhysicsSystem.MomentumSystem.SpeedMultiplierPerSwing ~= GetConVar("webswing_momentum_boost_per_swing"):GetFloat() then
        PhysicsSystem.InitializeMomentumSystem()
    end

    local ownerVel = owner:GetVelocity()
    local horizontalSpeed = ownerVel:Length2D()
    local massCompFactor = GetConVar("webswing_gravity_reduction"):GetFloat() or 0.5
    local momentumFactor = GetConVar("webswing_momentum_preservation"):GetFloat() or 1

    -- Detect falling speed and enhance swinging response (Web of Shadows style)
    local verticalSpeed = math.abs(ownerVel.z)
    local fallingFast = ownerVel.z < -300 -- Detect falling
    if fallingFast then
        -- Increase momentum and gravity compensation during fast falls
        local fallSpeedFactor = math.Clamp(math.abs(ownerVel.z) / 800, 1, 2.5)
        massCompFactor = massCompFactor * fallSpeedFactor
        momentumFactor = momentumFactor * fallSpeedFactor
    end

    -- Update momentum system
    PhysicsSystem:UpdateMomentumSystem(owner, horizontalSpeed, frameTime)

    -- Determine how vertical the rope is
    local ropeVerticalFactor = 1
    if constraintController and IsValid(constraintController.rope) then
        local ropePos = constraintController.rope:GetPos()
        local ragdollPos = ragdoll:GetPos()
        local toRope = (ropePos - ragdollPos):GetNormalized()
        ropeVerticalFactor = math.abs(toRope:Dot(Vector(0, 0, 1)))
    end

    local angleMultiplier = Lerp(1 - ropeVerticalFactor, 1.4, 1.0)
    local gravity = 600

    -- No rhythm system adjustments needed

    -- We don't have a rhythm system, so we'll use default values
    -- No need to try to access the rhythm system

    -- Apply dive boost if active
    if PhysicsSystem.MomentumSystem.IsDiving then
        local timeSinceDive = CurTime() - PhysicsSystem.MomentumSystem.DiveStartTime
        local diveProgress = math.Clamp(timeSinceDive / PhysicsSystem.MomentumSystem.DiveDuration, 0, 1)

        -- Dive boost fades out over time
        local currentDiveBoost = Lerp(diveProgress, PhysicsSystem.MomentumSystem.DiveBoostFactor, 1.0)
        momentumFactor = momentumFactor * currentDiveBoost

        -- End dive state when duration expires
        if diveProgress >= 1 then
            PhysicsSystem.MomentumSystem.IsDiving = false
        end
    end

    -- Track velocity history for smooth transitions
    table.insert(PhysicsSystem.MomentumSystem.VelocityHistory, 1, ownerVel)
    if #PhysicsSystem.MomentumSystem.VelocityHistory > PhysicsSystem.MomentumSystem.HistorySize then
        table.remove(PhysicsSystem.MomentumSystem.VelocityHistory)
    end

    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local physObj = ragdoll:GetPhysicsObjectNum(i)
        if IsValid(physObj) then
            local mass = physObj:GetMass()
            local upwardCompensation = mass * gravity * massCompFactor * momentumFactor * angleMultiplier * frameTime

            local ropeLength = constraintController and constraintController.current_length or 100
            local centripetalAccel = (horizontalSpeed^2) / math.max(ropeLength, 1)
            local centripetalForce = mass * centripetalAccel

            local ropeLengthRatio = 1
            if constraintController and constraintController.initial_length then
                ropeLengthRatio = constraintController.current_length / constraintController.initial_length
            end
            local dynamicTuning = Lerp(ropeLengthRatio, 0.55, 0.15)
            local inertiaAdjustment = centripetalForce * dynamicTuning

            local verticalForce = upwardCompensation - inertiaAdjustment
            local horizontalForce = Vector(0, 0, 0)

            if horizontalSpeed > 0 then
                local acceleration = (ownerVel - (PhysicsSystem.PrevOwnerVel or ownerVel)) / frameTime
                local predictedOwnerVel = ownerVel + acceleration * 0.1
                PhysicsSystem.PrevOwnerVel = ownerVel

                local predictedHorizontal = Vector(predictedOwnerVel.x, predictedOwnerVel.y, 0)
                local predictedHorizontalSpeed = predictedHorizontal:Length()

                if predictedHorizontalSpeed > 0 then
                    local inputVec = Vector(0, 0, 0)
                    if owner:KeyDown(IN_FORWARD) then inputVec = inputVec + owner:EyeAngles():Forward() end
                    if owner:KeyDown(IN_BACK) then inputVec = inputVec - owner:EyeAngles():Forward() end
                    if owner:KeyDown(IN_MOVELEFT) then inputVec = inputVec - owner:EyeAngles():Right() end
                    if owner:KeyDown(IN_MOVERIGHT) then inputVec = inputVec + owner:EyeAngles():Right() end

                    if inputVec:Length() > 0 then
                        inputVec:Normalize()
                    end

                    local predictedDir = predictedHorizontal:GetNormalized()
                    local finalDir = LerpVector(0.35, predictedDir, inputVec)
                    finalDir:Normalize()

                    -- Apply standard horizontal force (perfect swing functionality removed)
                    local preservationHorizontalFactor = math.Clamp(horizontalSpeed / 500, 0.4, 0.9)

                    -- No momentum multiplier applied

                    -- Apply enhanced momentum preservation for higher speeds
                    if horizontalSpeed > 600 then
                        -- Make it harder to lose speed at high velocities (WoS-like feel)
                        local highSpeedPreservation = math.Clamp((horizontalSpeed - 600) / 400, 0, 0.3)
                        preservationHorizontalFactor = preservationHorizontalFactor + highSpeedPreservation

                        -- Additional boost from vertical speed (Web of Shadows style fall-to-swing transition)
                        if fallingFast then
                            local verticalBoost = math.Clamp(verticalSpeed / 1000, 0, 0.5)
                            preservationHorizontalFactor = preservationHorizontalFactor + verticalBoost
                        end
                    end

                    horizontalForce = finalDir * predictedHorizontalSpeed * mass * preservationHorizontalFactor * frameTime

                    local naturalArcAccel = (horizontalSpeed^2) / math.max(ropeLength, 1)
                    local velNorm = ownerVel:GetNormalized()
                    local desiredArcDir = (Vector(0, 0, 1):Cross(velNorm)):Cross(velNorm)
                    desiredArcDir:Normalize()

                    local currentAccel = (ownerVel - (PhysicsSystem.PrevOwnerVel or ownerVel)) / frameTime
                    local actualHorizontalAccel = Vector(currentAccel.x, currentAccel.y, 0)
                    local idealAccel = desiredArcDir * naturalArcAccel
                    local accelerationDiff = idealAccel - actualHorizontalAccel

                    -- Apply rhythm-based arc preservation
                    local swingArcFactor = Lerp(math.min(horizontalSpeed / 600, 1), 0.4, 0.25)

                    -- No rhythm-based arc enhancement since rhythm system is not available
                    -- Perfect swing arc enhancement has been removed

                    local arcPreservationForce = accelerationDiff * mass * swingArcFactor
                    horizontalForce = horizontalForce + arcPreservationForce

                    -- No rhythm-based boost since rhythm system is not available
                end
            end

            local totalForce = horizontalForce + Vector(0, 0, verticalForce)
            physObj:ApplyForceCenter(totalForce)
        end
    end
end

-- Update the momentum system state
function PhysicsSystem:UpdateMomentumSystem(owner, currentSpeed, frameTime)
    -- Skip if momentum building is disabled
    if not GetConVar("webswing_momentum_building"):GetBool() then return end

    local momentumSystem = self.MomentumSystem

    -- Update peak speed if current speed is higher
    if currentSpeed > momentumSystem.PeakSpeed then
        momentumSystem.PeakSpeed = currentSpeed
    end

    -- Decay momentum over time when not swinging
    local currentTime = CurTime()
    local timeSinceLastSwing = currentTime - momentumSystem.LastSwingTime

    if timeSinceLastSwing > 1.0 then -- After 1 second of not swinging, begin decay
        -- Perfect swing functionality has been removed
        -- Ensure momentum multiplier is always 1.0
        momentumSystem.MomentumMultiplier = 1.0
        momentumSystem.ConsecutivePerfectSwings = 0
    end

    -- Check for dive boost activation (when looking down + jump while falling)
    if not momentumSystem.IsDiving and
       owner:KeyDown(IN_JUMP) and
       owner:GetVelocity().z < -100 and
       owner:EyeAngles().pitch > 30 then

        momentumSystem.IsDiving = true
        momentumSystem.DiveStartTime = currentTime

        -- Trigger any dive effects here (sound, particles, etc.)
        if SERVER then
            owner:EmitSound("physics/body/body_medium_impact_soft7.wav", 75, 120)
        end
    end
end

-- Record a perfect swing for momentum building (disabled)
function PhysicsSystem.RecordPerfectSwing()
    -- Perfect swing functionality has been removed
    -- Just update the last swing time for compatibility
    PhysicsSystem.MomentumSystem.LastSwingTime = CurTime()

    -- Ensure momentum multiplier is always 1.0
    PhysicsSystem.MomentumSystem.MomentumMultiplier = 1.0

    -- Reset consecutive swings to 0
    PhysicsSystem.MomentumSystem.ConsecutivePerfectSwings = 0
end

-- Reset momentum system (e.g., when landing or taking damage)
function PhysicsSystem.ResetMomentumSystem()
    PhysicsSystem.MomentumSystem.ConsecutivePerfectSwings = 0
    PhysicsSystem.MomentumSystem.MomentumMultiplier = 1.0
    PhysicsSystem.MomentumSystem.IsDiving = false
    -- We don't reset peak speed here as it's useful for statistics
end

-- Record the start of a new swing
function PhysicsSystem.RecordSwingStart()
    -- Update momentum system's last swing time
    PhysicsSystem.MomentumSystem.LastSwingTime = CurTime()
end

-- Get the current momentum system state
function PhysicsSystem.GetMomentumState()
    return PhysicsSystem.MomentumSystem
end

return PhysicsSystem