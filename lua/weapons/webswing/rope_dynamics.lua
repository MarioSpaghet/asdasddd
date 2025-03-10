-- Rope dynamics module for web swinging

local RopeDynamics = {}

-- Dynamic rope length adjustment
function RopeDynamics.AdjustRopeLength(constraintController, ragdoll, targetBoneFunc, frameTime, rhythmSystem)
    if not constraintController or not IsValid(ragdoll) then return end
    
    local physObj = ragdoll:GetPhysicsObjectNum(targetBoneFunc())
    if not IsValid(physObj) then return end
    
    local vel = physObj:GetVelocity()
    local speed = vel:Length()
    local pos = physObj:GetPos()
    
    -- Calculate swing angle relative to vertical
    local attachPos = constraintController.rope:GetPos()
    local toAttach = (attachPos - pos):GetNormalized()
    local verticalAngle = math.deg(math.acos(math.abs(toAttach:Dot(Vector(0, 0, 1)))))
    
    -- Get adjustment factors from ConVars
    local angleFactor = GetConVar("webswing_length_angle_factor"):GetFloat()
    local minLengthRatio = GetConVar("webswing_min_length_ratio"):GetFloat()
    local smoothingFactor = GetConVar("webswing_length_smoothing"):GetFloat()
    local maxLengthChange = GetConVar("webswing_max_length_change"):GetFloat()
    local swingSpeed = GetConVar("webswing_swing_speed"):GetFloat()
    
    local baseLength = constraintController.initial_length or constraintController.current_length
    
    -- Store previous velocity for acceleration calculation
    RopeDynamics.PrevVelocity = RopeDynamics.PrevVelocity or vel

    local acceleration = (vel - RopeDynamics.PrevVelocity) / frameTime
    local predictedVel = vel + acceleration * 0.1 -- Look ahead 0.1 seconds
    RopeDynamics.PrevVelocity = vel

    -- Predict future position
    local lookaheadTime = 0.15
    local predictedPos = pos + predictedVel * lookaheadTime
    local predictedRopeLength = (attachPos - predictedPos):Length()
    
    -- Angle-based adjustment with momentum prediction
    local predictedAngle = verticalAngle
    if predictedVel:Length() > 50 then
        local predictedDir = (predictedVel:GetNormalized() * 100 + pos - attachPos):GetNormalized()
        predictedAngle = math.deg(math.acos(math.abs(predictedDir:Dot(Vector(0, 0, 1)))))
    end

    local angleAdjust = 1 - (predictedAngle / 90) * 0.5 * angleFactor
    local speedRatio = math.min(speed / swingSpeed, 1)
    local speedAdjust = 1 - speedRatio * 0.3
    
    -- Add corner detection adjustment
    local cornerFactor = 1
    if RopeDynamics.LastCornerTime and CurTime() - RopeDynamics.LastCornerTime < 0.5 then
        local timeSinceCorner = CurTime() - RopeDynamics.LastCornerTime
        cornerFactor = Lerp(timeSinceCorner / 0.5, 1.2, 1) -- Slightly longer rope in corners
    end

    -- Add rhythm-based adjustments if available
    local rhythmFactor = 1
    if rhythmSystem then
        -- Calculate current swing phase (0-1)
        local currentTime = CurTime()
        local swingPhase = rhythmSystem:UpdateSwingPhase(rhythmSystem.LastSwingTime, currentTime)
        
        -- Get rhythm adjustments
        local isInRhythm, rhythmScore = rhythmSystem:CheckRhythm(currentTime)
        
        if isInRhythm then
            -- Create a natural, rhythmic oscillation of the rope length
            -- This creates a more dynamic, breathing feel to the swings
            local rhythmPulse = math.sin(swingPhase * math.pi * 2) * 0.1 * rhythmScore
            rhythmFactor = 1 + rhythmPulse
            
            -- When approaching the optimal release point, gradually extend the rope
            -- This creates a more pronounced pendulum effect at release
            local releaseProximity = 1 - math.abs(swingPhase - rhythmSystem.OptimalReleasePoint) * 3
            if releaseProximity > 0.7 then
                local releaseExtension = releaseProximity * 0.08 * rhythmScore
                rhythmFactor = rhythmFactor + releaseExtension
            end
            
            -- Short ropes when starting a new swing, gradually extending
            if swingPhase < 0.15 then
                local startPhaseShorten = (0.15 - swingPhase) / 0.15 * 0.1
                rhythmFactor = rhythmFactor - startPhaseShorten
            end
        end
    end

    -- Compute the target length based on the current factors
    local computedTargetLength = baseLength * math.max(angleAdjust * speedAdjust * cornerFactor * rhythmFactor, minLengthRatio)
    
    -- Blend the computed target length with the predicted rope length
    local targetLength = Lerp(0.5, computedTargetLength, predictedRopeLength)
    
    -- Apply rate limiting to length changes
    local currentLength = constraintController.current_length
    local lengthDiff = targetLength - currentLength
    local maxChangePerFrame = math.min(
        GetConVar("webswing_max_length_change"):GetFloat() * frameTime,
        50 -- Absolute maximum per frame
    )
    lengthDiff = math.Clamp(lengthDiff, -maxChangePerFrame, maxChangePerFrame)
    
    -- Apply smoothing with momentum preservation
    local smoothedLength
    if not RopeDynamics.LastLengthChange then
        smoothedLength = currentLength + lengthDiff
        RopeDynamics.LastLengthChange = lengthDiff
    else
        local momentum = RopeDynamics.LastLengthChange * 0.3
        local newChange = Lerp(smoothingFactor, lengthDiff + momentum, RopeDynamics.LastLengthChange)
        smoothedLength = currentLength + newChange
        RopeDynamics.LastLengthChange = newChange
    end
    
    -- Ensure length stays within bounds
    smoothedLength = math.Clamp(smoothedLength, baseLength * minLengthRatio, baseLength * 1.2)
    
    -- Update rope length
    constraintController.current_length = smoothedLength
    constraintController:Set()
    
    -- Store corner detection time when sharp turns are detected
    local turnRate = vel:Cross(RopeDynamics.PrevVelocity):Length() / (speed * frameTime)
    if turnRate > 200 then
        RopeDynamics.LastCornerTime = CurTime()
    end
    
    -- Return the length for use in other systems
    return smoothedLength
end

-- Method to record a corner or sharp turn
function RopeDynamics.RecordCornerTurn()
    RopeDynamics.LastCornerTime = CurTime()
end

-- Create a constraint controller for rope or elastic
function RopeDynamics.CreateConstraintController(ragdoll, attachEntity, targetPhysObj, attachBone, attachPos, dist, useRope, ropeMat, ropeWidth, ropeColor)
    local controller = nil
    
    if useRope then
        -- Calculate local offset based on entity type
        local localPos
        if attachEntity:IsWorld() then
            localPos = attachPos  -- For world, use world coordinates
        else
            -- For props and other entities, properly convert to local space
            local physObj = attachEntity:GetPhysicsObject()
            if IsValid(physObj) then
                localPos = WorldToLocal(attachPos, Angle(0,0,0), attachEntity:GetPos(), attachEntity:GetAngles())
            else
                localPos = attachPos - attachEntity:GetPos()
            end
        end

        local lengthConstraint, ropeEntity = constraint.Rope(
            ragdoll, attachEntity,
            targetPhysObj, attachBone,
            Vector(0, 0, 0), localPos,
            0, dist * 0.95, 0, ropeWidth,
            ropeMat, false
        )
        
        if ropeEntity then
            ropeEntity:SetKeyValue("spawnflags", "1")
            ropeEntity:SetRenderMode(RENDERMODE_TRANSALPHA)
            ropeEntity:SetColor(ropeColor)
            ropeEntity:SetMaterial(ropeMat)
        end
        
        if lengthConstraint and ropeEntity then
            controller = {
                current_length = dist * 0.95,
                initial_length = dist * 0.95, -- Store initial length for reference
                constraint = lengthConstraint,
                rope = ropeEntity,
                speed = 5,
                Set = function(ctrl)
                    if IsValid(ctrl.constraint) then
                        ctrl.constraint:Fire("SetLength", ctrl.current_length, 0)
                    end
                    if IsValid(ctrl.rope) then
                        ctrl.rope:Fire("SetLength", ctrl.current_length, 0)
                    end
                end,
                Shorten = function(ctrl)
                    ctrl.current_length = math.max(ctrl.current_length - ctrl.speed, 10)
                    ctrl:Set()
                end,
                Slacken = function(ctrl)
                    ctrl.current_length = math.min(ctrl.current_length + ctrl.speed, 2000) -- Use a reasonable max range
                    ctrl:Set()
                end
            }
        end
    else
        -- Elastic constraint implementation would go here
        -- This is a placeholder for future implementation
    end
    
    return controller
end

return RopeDynamics