-- AI Swing Point Intelligence System
-- Module for advanced swing point targeting intelligence with Web of Shadows-style auto-targeting

local SwingTargeting = {}

-- Store recent swing history for predictive analysis
SwingTargeting.History = {
    recentPoints = {}, -- Recent chosen swing points
    targetingPatterns = {}, -- Recognized patterns in targeting
    lastChosenPoint = nil, -- Last point that was chosen
    recentVelocities = {}, -- Store recent velocities for movement prediction
    maxHistorySize = 10, -- Maximum number of points to remember
    playerDirection = Vector(0, 0, 0), -- Current player direction of travel
    lastSwingTime = 0, -- Last time a web was shot
    dynamicPoints = {}, -- Stores generated dynamic points
    lastDynamicPointTime = 0, -- Last time a dynamic point was generated
    dynamicPointCooldown = 2, -- Seconds between dynamic point generation
    momentumData = {
        peakSpeed = 0, -- Track the peak speed achieved
        consecutiveGoodSwings = 0, -- Track consecutive good swings
        momentumMultiplier = 1.0, -- Current momentum multiplier
        lastSwingQuality = 0, -- How good was the last swing (0-1)
        momentumDirection = Vector(0, 0, 0) -- Current momentum direction
    },
    curvedPathData = {
        currentTarget = nil, -- Target position for curved path
        currentNormal = nil, -- Surface normal at target
        pathActive = false, -- Is a curved path currently active
        pathStartTime = 0, -- When the curved path began
        pathPoints = {}, -- Points along the curve
        currentPathIndex = 1, -- Current point along the path being targeted
        lastPathUpdateTime = 0, -- Last time the path was updated
        buildings = {}, -- Tracked buildings for path planning
        objectsOfInterest = {}, -- Key objects in the environment
        lastBuildingScanTime = 0, -- Last time buildings were scanned
        buildingScanInterval = 10 -- Seconds between building scans
    },
    webOfShadowsTargeting = {
        enabled = true, -- Whether WoS targeting is enabled
        intelligentMode = true, -- Uses player behavior patterns to improve targeting
        activeTarget = nil, -- Currently tracked potential target
        targetLockTime = 0, -- When the current target was locked on
        targetLockDuration = 0.65, -- How long to maintain a target lock
        previousTargets = {}, -- Recently used targets for pattern recognition
        idealArcPos = nil, -- Calculated ideal position for maintaining swing arc
        preferFowardTargets = true, -- Prioritize targets in direction of movement 
        anticipationFactor = 0.6, -- How much to anticipate player's next move (0-1)
        flowStateFactor = 0, -- Increases as player maintains momentum (0-1)
        lastInputTime = 0, -- Last time player provided directional input
        lastInputDirection = Vector(0,0,0), -- Last directional input from player
        targetingConfidence = 0.5, -- How confident the system is in its targeting
        preferredHeight = 0, -- Dynamically calculated preferred attachment height
        heightAdjustment = 200 -- Starting height adjustment above player
    }
}

-- Predictive Point Selection
-- This system tries to anticipate where the player wants to go based on their
-- movement patterns, camera direction, and previous swing points
function SwingTargeting:PredictNextTargetPoint(owner, currentPos, velocity, aimVector)
    -- Initialize return value
    local prediction = {
        targetPos = nil,
        confidence = 0,
        preferredDirection = Vector(0, 0, 0)
    }

    -- Ensure we have a valid owner
    if not IsValid(owner) then return prediction end

    -- Get current state
    local currentTime = CurTime()
    local currentSpeed = velocity:Length()
    local normalizedVelocity = velocity:GetNormalized()
    local timeSinceLastSwing = currentTime - self.History.lastSwingTime

    -- Extract player input state
    local moveForward = owner:KeyDown(IN_FORWARD)
    local moveBack = owner:KeyDown(IN_BACK)
    local moveLeft = owner:KeyDown(IN_MOVELEFT)
    local moveRight = owner:KeyDown(IN_MOVERIGHT)

    -- Store velocity for history (limit to 20 entries)
    table.insert(self.History.recentVelocities, 1, {
        vel = velocity,
        time = currentTime
    })

    if #self.History.recentVelocities > 20 then
        table.remove(self.History.recentVelocities)
    end

    -- Calculate intended direction based on key inputs and camera orientation
    local intendedDir = Vector(0, 0, 0)

    if moveForward then
        intendedDir = intendedDir + aimVector
    end
    if moveBack then
        intendedDir = intendedDir - aimVector
    end

    -- Get right vector for strafing
    local rightVec = aimVector:Cross(Vector(0, 0, 1)):GetNormalized()

    if moveRight then
        intendedDir = intendedDir + rightVec
    end
    if moveLeft then
        intendedDir = intendedDir - rightVec
    end

    -- Normalize if we have any direction
    if intendedDir:LengthSqr() > 0 then
        intendedDir:Normalize()
    else
        -- Default to current velocity direction or aim direction if no keys pressed
        intendedDir = currentSpeed > 100 and normalizedVelocity or aimVector
    end

    -- Store the current player direction for other systems to use
    self.History.playerDirection = intendedDir

    -- Calculate trajectory prediction based on recent velocities
    local predictedPos = currentPos
    local predictedVel = velocity

    -- Look at velocity changes to predict future position (basic physics prediction)
    if #self.History.recentVelocities >= 2 then
        local currentVel = self.History.recentVelocities[1].vel
        local prevVel = self.History.recentVelocities[2].vel
        local timeDiff = self.History.recentVelocities[1].time - self.History.recentVelocities[2].time

        if timeDiff > 0 then
            -- Calculate acceleration
            local accel = (currentVel - prevVel) / timeDiff

            -- Predict position 0.5 seconds in the future
            local predictionTime = 0.5
            predictedVel = currentVel + accel * predictionTime
            predictedPos = currentPos + currentVel * predictionTime + 0.5 * accel * predictionTime * predictionTime
        end
    end

    -- Calculate swing point preference based on predicted trajectory
    prediction.targetPos = predictedPos
    prediction.preferredDirection = intendedDir
    prediction.confidence = 0.8 -- Base confidence level

    -- Adjust confidence based on situation
    if currentSpeed < 50 then
        -- When nearly stopped, lower confidence in prediction
        prediction.confidence = 0.4
    elseif timeSinceLastSwing < 0.3 then
        -- When rapidly changing swing points, increase confidence in prediction
        prediction.confidence = 0.9
    end

    -- Update last swing time for next prediction
    self.History.lastSwingTime = currentTime

    return prediction
end

-- Apply predictive targeting to influence point scoring
function SwingTargeting:ApplyPredictionToCandidate(candidate, prediction, playerPos)
    if not prediction or not prediction.targetPos or prediction.confidence <= 0 then
        return 0 -- No prediction data or zero confidence
    end

    local scoreMod = 0

    -- Calculate how well this candidate aligns with the predicted direction
    local toCandidate = (candidate.pos - playerPos):GetNormalized()
    local alignmentScore = prediction.preferredDirection:Dot(toCandidate)

    -- Scale by confidence and normalize to positive range
    alignmentScore = (alignmentScore + 1) * 0.5 * prediction.confidence

    -- How close is this point to being on the predicted path?
    local distToPoint = candidate.pos:Distance(playerPos)
    local predictedPos = playerPos + prediction.preferredDirection * distToPoint
    local pathDeviation = candidate.pos:Distance(predictedPos) / distToPoint
    local pathScore = (1 - math.Clamp(pathDeviation, 0, 1)) * prediction.confidence

    -- Combine scores, weighting alignment more
    scoreMod = alignmentScore * 0.6 + pathScore * 0.4

    -- Store the point in history if it's chosen
    if scoreMod > 0.7 then
        table.insert(self.History.recentPoints, 1, {
            pos = candidate.pos,
            time = CurTime()
        })

        if #self.History.recentPoints > self.History.maxHistorySize then
            table.remove(self.History.recentPoints)
        end

        self.History.lastChosenPoint = candidate.pos
    end

    return scoreMod * 0.5 -- Scale the final score modifier to appropriate range
end

-- Dynamic Point Generation
-- Create temporary swing points in areas with few attachment options to maintain flow
function SwingTargeting:GenerateDynamicPoints(candidates, playerPos, velocity, aimVector)
    -- Check cooldown for dynamic point generation
    local currentTime = CurTime()
    local timeSinceLastGeneration = currentTime - self.History.lastDynamicPointTime

    -- Clean up expired dynamic points
    local dynamicPointLifetime = 8 -- Seconds a dynamic point exists
    for i = #self.History.dynamicPoints, 1, -1 do
        local pointAge = currentTime - self.History.dynamicPoints[i].time
        if pointAge > dynamicPointLifetime then
            table.remove(self.History.dynamicPoints, i)
        end
    end

    -- Don't generate points too frequently
    if timeSinceLastGeneration < self.History.dynamicPointCooldown then
        return self.History.dynamicPoints
    end

    -- Only generate points when we have few real attachment options
    if #candidates >= 4 then
        return self.History.dynamicPoints -- Enough real points available
    end

    -- Get player state
    local speed = velocity:Length()
    local dirOfTravel = speed > 50 and velocity:GetNormalized() or aimVector

    -- Determine if we need to generate points
    local needPoints = false

    -- Check if we're in a "swing desert" - large area with few attachable points
    if #candidates < 2 then
        needPoints = true
    end

    -- Check if we need to maintain flow - when moving at speed with no good points in direction
    if speed > 300 then
        -- Check if any existing points are in roughly the direction we're going
        local hasForwardPoint = false
        for _, candidate in ipairs(candidates) do
            local toPoint = (candidate.pos - playerPos):GetNormalized()
            if dirOfTravel:Dot(toPoint) > 0.7 then -- Point is roughly in our direction
                hasForwardPoint = true
                break
            end
        end
        needPoints = needPoints or not hasForwardPoint
    end

    -- Check if we're in danger of falling with no upward points
    local groundTrace = util.TraceLine({
        start = playerPos,
        endpos = playerPos - Vector(0, 0, 1000),
        mask = MASK_SOLID
    })
    local distToGround = groundTrace.Hit and groundTrace.HitPos:Distance(playerPos) or 1000

    if distToGround < 200 and speed < 200 then
        -- Check if any existing points are above us
        local hasUpwardPoint = false
        for _, candidate in ipairs(candidates) do
            if candidate.pos.z > playerPos.z + 50 then
                hasUpwardPoint = true
                break
            end
        end
        needPoints = needPoints or not hasUpwardPoint
    end

    -- Only generate points if needed
    if not needPoints then
        return self.History.dynamicPoints
    end

    -- Parameters for dynamic point generation
    -- REFINEMENT: More contextual distance based on speed
    local baseDistance = math.Clamp(300 + speed * 0.8, 400, 1200)

    -- REFINEMENT: Enhanced height adaptation
    local upwardBias = 0.3 -- Default upward bias
    if distToGround < 100 then
        -- Very close to ground - strong upward bias for immediate "up and out" swing
        upwardBias = 0.9
    elseif distToGround < 200 then
        -- Close to ground - significant upward bias
        upwardBias = 0.7
    elseif speed > 800 then
        -- At very high speeds, reduce upward bias to maintain horizontal momentum
        upwardBias = 0.1
    elseif speed > 500 then
        -- At high speeds, slightly reduce upward bias
        upwardBias = 0.2
    end

    local numPointsToGenerate = 4 - #candidates -- Generate up to 4 total points

    -- Generate dynamic points
    local newPoints = {}

    -- REFINEMENT: Track point positions to avoid clustering
    local generatedPositions = {}

    for i = 1, numPointsToGenerate do
        -- Calculate angle offset for diverse point distribution
        local angleOffset = (i - 1) * (math.pi * 2 / numPointsToGenerate)

        -- REFINEMENT: Better momentum integration
        -- Blend player direction with momentum direction for better flow
        local directionBlend = 0.7 -- How much to favor player direction vs momentum
        local blendedDirection

        if self.History.momentumData.momentumMultiplier > 1.2 and speed > 300 then
            -- When in flow state, favor momentum direction more
            directionBlend = 0.3
            blendedDirection = LerpVector(
                directionBlend,
                self.History.momentumData.momentumDirection:Angle(),
                self.History.playerDirection:Angle()
            )
        else
            blendedDirection = self.History.playerDirection:Angle()
        end

        -- Add some variation to the angle based on index
        local variedAngle = Angle(
            blendedDirection.p + math.sin(angleOffset) * 15,
            blendedDirection.y + math.cos(angleOffset) * 20,
            0
        )

        -- Add upward bias
        variedAngle.p = variedAngle.p - 20 - (upwardBias * 30)

        -- Convert to direction vector
        local dir = variedAngle:Forward()

        -- Calculate position with variable distance based on speed
        local distance = baseDistance * (0.8 + math.random() * 0.4)
        local dynamicPos = playerPos + dir * distance

        -- Ensure the point is not inside geometry and not in sky
        local traceToPoint = util.TraceLine({
            start = playerPos,
            endpos = dynamicPos,
            mask = MASK_SOLID
        })

        -- Check if we hit the sky
        local isSkybox = false
        if traceToPoint.HitSky then
            isSkybox = true
        else
            -- Extra check for skybox - trace upward from the proposed point
            local skyTrace = util.TraceLine({
                start = dynamicPos,
                endpos = dynamicPos + Vector(0, 0, 100),
                mask = MASK_SOLID
            })

            if skyTrace.HitSky or (not skyTrace.Hit and not GetConVar("webswing_allow_sky_attach"):GetBool()) then
                isSkybox = true
            end
        end

        -- Only create point if it hit something and it's not the sky
        if traceToPoint.Hit and not isSkybox then
            -- Adjust the point to be at the hit position, slightly offset from surface
            dynamicPos = traceToPoint.HitPos - traceToPoint.HitNormal * 10

            -- REFINEMENT: Edge clinging - try to find edges near the hit point
            local edgeFound = false
            local edgePos = dynamicPos

            -- Only try edge detection if we're not too close to the ground
            if distToGround > 150 then
                -- Check for edges in 4 directions perpendicular to the hit normal
                local rightVec = traceToPoint.HitNormal:Cross(Vector(0, 0, 1)):GetNormalized()
                local upVec = rightVec:Cross(traceToPoint.HitNormal):GetNormalized()
                local directions = {
                    rightVec,
                    rightVec * -1,
                    upVec,
                    upVec * -1
                }

                for _, checkDir in ipairs(directions) do
                    local edgeTrace = util.TraceLine({
                        start = dynamicPos,
                        endpos = dynamicPos + checkDir * 50,
                        mask = MASK_SOLID
                    })

                    if not edgeTrace.Hit then
                        -- Found potential edge, nudge point towards it
                        edgePos = dynamicPos + checkDir * 20
                        edgeFound = true
                        break
                    end
                end
            end

            if edgeFound then
                dynamicPos = edgePos
            end

            -- REFINEMENT: Avoid pointless dynamic points
            -- Check if this point would lead to an immediate obstacle
            local isObstructed = false
            if _G.ObstaclePrediction then
                -- Use a simplified version of obstacle prediction
                local simpleObstacleCheck = util.TraceHull({
                    start = playerPos,
                    endpos = dynamicPos,
                    mins = Vector(-16, -16, 0),
                    maxs = Vector(16, 16, 72),
                    mask = MASK_SOLID_BRUSHONLY
                })

                isObstructed = simpleObstacleCheck.Hit and simpleObstacleCheck.Entity ~= traceToPoint.Entity
            end

            -- REFINEMENT: Density check - avoid creating points too close to existing ones
            local tooClose = false
            for _, pos in ipairs(generatedPositions) do
                if pos:Distance(dynamicPos) < 150 then
                    tooClose = true
                    break
                end
            end

            -- Also check against existing candidates
            for _, candidate in ipairs(candidates) do
                if candidate.pos:Distance(dynamicPos) < 150 then
                    tooClose = true
                    break
                end
            end

            if not isObstructed and not tooClose then
                -- Create the dynamic point
                table.insert(newPoints, {
                    pos = dynamicPos,
                    normal = traceToPoint.HitNormal,
                    entity = traceToPoint.Entity or game.GetWorld(),
                    time = currentTime,
                    type = "dynamic",
                    isDynamic = true,
                    isEdge = edgeFound
                })

                -- Add to our tracking of generated positions
                table.insert(generatedPositions, dynamicPos)
            end
        elseif not traceToPoint.Hit and not isSkybox then
            -- If we didn't hit anything, make sure this is a valid position with something nearby
            local proximityCheck = util.TraceLine({
                start = dynamicPos,
                endpos = dynamicPos - Vector(0, 0, 200), -- Check below
                mask = MASK_SOLID
            })

            if proximityCheck.Hit and not proximityCheck.HitSky and proximityCheck.HitPos:Distance(dynamicPos) < 200 then
                -- REFINEMENT: Density check for suspended points too
                local tooClose = false
                for _, pos in ipairs(generatedPositions) do
                    if pos:Distance(dynamicPos) < 150 then
                        tooClose = true
                        break
                    end
                end

                -- Also check against existing candidates
                for _, candidate in ipairs(candidates) do
                    if candidate.pos:Distance(dynamicPos) < 150 then
                        tooClose = true
                        break
                    end
                end

                if not tooClose then
                    -- Only create a suspended point if there's something below it
                    table.insert(newPoints, {
                        pos = dynamicPos,
                        normal = Vector(0, 0, -1), -- Default normal pointing down
                        entity = game.GetWorld(),
                        time = currentTime,
                        type = "dynamic",
                        isDynamic = true
                    })

                    -- Add to our tracking of generated positions
                    table.insert(generatedPositions, dynamicPos)
                end
            end
        end
    end

    -- Add new points to our dynamic points collection
    for _, point in ipairs(newPoints) do
        table.insert(self.History.dynamicPoints, point)
    end

    -- Update the last generation time
    self.History.lastDynamicPointTime = currentTime

    -- Debug visualization for dynamic points
    if CLIENT and GetConVar("webswing_show_ai_indicator"):GetBool() then
        for _, point in ipairs(newPoints) do
            local color = point.isEdge and Color(0, 255, 255, 180) or Color(255, 165, 0, 180)
            debugoverlay.Sphere(point.pos, 8, 0.5, color)
            debugoverlay.Text(point.pos, "Dynamic" .. (point.isEdge and " (Edge)" or ""), 0.5, true)
        end
    end

    return self.History.dynamicPoints
end

-- Momentum-Aware Targeting
-- This system favors points that preserve momentum in the current direction
function SwingTargeting:EvaluateMomentumPreservation(candidate, playerPos, velocity, aimVector)
    local speed = velocity:Length()
    if speed < 100 then
        return 0 -- No significant momentum to preserve
    end

    local momentumData = self.History.momentumData
    local dirOfTravel = velocity:GetNormalized()
    local toCandidate = (candidate.pos - playerPos):GetNormalized()

    -- Base momentum alignment score
    local alignmentScore = dirOfTravel:Dot(toCandidate)

    -- Update peak speed tracking
    if speed > momentumData.peakSpeed then
        momentumData.peakSpeed = speed
    end

    -- Initialize momentum direction if not set
    if momentumData.momentumDirection:LengthSqr() == 0 then
        momentumData.momentumDirection = dirOfTravel
    end

    -- Gradually blend current direction into momentum direction
    local blendFactor = 0.1 -- How quickly momentum direction adapts
    momentumData.momentumDirection = LerpVector(blendFactor, momentumData.momentumDirection, dirOfTravel)
    momentumData.momentumDirection:Normalize()

    -- Enhanced alignment score that considers the momentum direction, not just current velocity
    local momentumAlignmentScore = momentumData.momentumDirection:Dot(toCandidate)

    local currentTime = CurTime()

    -- Distance-based evaluation - prefer points at optimal distance for good swing
    local distToPoint = candidate.pos:Distance(playerPos)
    local optimalDist = math.Clamp(300 + speed * 0.3, 300, 1000)
    local distanceScore = 1 - math.abs(distToPoint - optimalDist) / optimalDist

    -- Height-based evaluation for arcing swings
    local heightDiff = candidate.pos.z - playerPos.z
    local optimalHeight = speed * 0.1 -- Higher speeds want higher arcs
    local heightScore = 1 - math.Clamp(math.abs(heightDiff - optimalHeight) / 200, 0, 1)

    -- Calculate the plane perpendicular to momentum direction
    local rightVector = momentumData.momentumDirection:Cross(Vector(0, 0, 1)):GetNormalized()
    local upVector = rightVector:Cross(momentumData.momentumDirection):GetNormalized()

    -- Calculate how far the candidate is from the ideal swing plane
    local idealSwingPoint = playerPos + momentumData.momentumDirection * optimalDist + upVector * optimalHeight
    local planeDeviation = math.abs((candidate.pos - idealSwingPoint):Dot(rightVector)) / distToPoint
    local planeScore = 1 - math.Clamp(planeDeviation, 0, 1)

    -- Combine scores with appropriate weights
    local baseWeight = 1.0 -- Base weight without flow state
    local alignmentWeight = 0.5 * baseWeight
    local planeWeight = 0.3 * baseWeight
    local distanceWeight = 0.2
    local heightWeight = 0.2

    local totalScore = alignmentScore * alignmentWeight +
                       momentumAlignmentScore * 0.2 * baseWeight +
                       planeScore * planeWeight +
                       distanceScore * distanceWeight +
                       heightScore * heightWeight

    -- Normalize the total score to a reasonable range
    totalScore = math.Clamp(totalScore * 0.5, 0, 0.8)

    -- Debug visualization for momentum prediction if enabled
    if CLIENT and GetConVar("webswing_show_ai_indicator"):GetBool() then
        local duration = 0.2

        -- Show momentum direction
        debugoverlay.Line(
            playerPos,
            playerPos + momentumData.momentumDirection * 200,
            duration,
            Color(255, 0, 255, 180)
        )

        -- Show ideal swing point if moving fast enough
        if speed > 300 then
            debugoverlay.Sphere(idealSwingPoint, 10, duration, Color(255, 0, 255, 180))
        end
    end

    return totalScore
end

-- Record a swing event to update momentum data
function SwingTargeting:RecordSwingEvent(quality, pos, velocity)
    local momentumData = self.History.momentumData
    local speed = velocity:Length()

    -- Update consecutive swing tracking
    if quality > 0.6 then
        momentumData.consecutiveGoodSwings = momentumData.consecutiveGoodSwings + 1
    else
        momentumData.consecutiveGoodSwings = 0
    end

    -- Limit to prevent integer overflow in long sessions
    momentumData.consecutiveGoodSwings = math.min(momentumData.consecutiveGoodSwings, 100)

    -- Store last swing quality
    momentumData.lastSwingQuality = quality

    -- Update peak speed if needed
    if speed > momentumData.peakSpeed then
        momentumData.peakSpeed = speed
    elseif momentumData.peakSpeed > 0 then
        -- Gradually decay peak speed when not hitting new peaks
        momentumData.peakSpeed = momentumData.peakSpeed * 0.99
    end

    -- Update momentum multiplier based on consecutive good swings
    local baseMultiplier = 1.0
    local bonusPerGoodSwing = 0.1 -- 10% boost per good swing
    momentumData.momentumMultiplier = baseMultiplier +
                                     math.min(momentumData.consecutiveGoodSwings * bonusPerGoodSwing, 0.5)

    -- Debug info
    if GetConVar("developer"):GetBool() then
        print(string.format("[Momentum] Quality: %.2f, Consecutive: %d, Multiplier: %.2f",
                          quality,
                          momentumData.consecutiveGoodSwings,
                          momentumData.momentumMultiplier))
    end
end

-- Curved Path Planning
-- Like in Spider-Man 2, assist players in following curved paths around buildings
function SwingTargeting:AnalyzeEnvironmentForCurvedPaths(playerPos, playerFacing)
    local curveData = self.History.curvedPathData
    local currentTime = CurTime()

    -- Only scan for buildings periodically to save performance
    if currentTime - curveData.lastBuildingScanTime < curveData.buildingScanInterval then
        return
    end

    -- Reset buildings list
    curveData.buildings = {}
    curveData.objectsOfInterest = {}
    curveData.lastBuildingScanTime = currentTime

    -- Scan for large static objects that could be buildings
    local scanRadius = 2000 -- Scan 2000 units around the player
    local scanSteps = 16 -- Number of directions to scan

    for i = 1, scanSteps do
        local angle = (i - 1) * (math.pi * 2 / scanSteps)
        local direction = Vector(math.cos(angle), math.sin(angle), 0)

        -- First scan horizontal to find buildings
        local horizontalTrace = util.TraceLine({
            start = playerPos,
            endpos = playerPos + direction * scanRadius,
            mask = MASK_SOLID_BRUSHONLY
        })

        if horizontalTrace.Hit and horizontalTrace.HitPos:Distance(playerPos) > 500 then
            -- Found a potentially large object, scan vertically to determine height
            local buildingInfo = {
                basePos = horizontalTrace.HitPos,
                normal = horizontalTrace.HitNormal,
                width = 0,
                height = 0,
                cornerPositions = {}
            }

            -- Scan upward to find height
            local upTrace = util.TraceLine({
                start = horizontalTrace.HitPos + Vector(0, 0, 100), -- Start a bit above to avoid ground
                endpos = horizontalTrace.HitPos + Vector(0, 0, 1000),
                mask = MASK_SOLID_BRUSHONLY
            })

            if not upTrace.Hit then
                -- Object continues upward, it's tall enough to be a building
                buildingInfo.height = 1000

                -- Scan laterally to estimate width
                local rightVec = horizontalTrace.HitNormal:Cross(Vector(0, 0, 1))
                local leftTrace = util.TraceLine({
                    start = horizontalTrace.HitPos,
                    endpos = horizontalTrace.HitPos + rightVec * 500,
                    mask = MASK_SOLID_BRUSHONLY
                })

                local rightTrace = util.TraceLine({
                    start = horizontalTrace.HitPos,
                    endpos = horizontalTrace.HitPos - rightVec * 500,
                    mask = MASK_SOLID_BRUSHONLY
                })

                local leftDist = leftTrace.Fraction * 500
                local rightDist = rightTrace.Fraction * 500

                -- Only add buildings that are wide enough
                if leftDist + rightDist > 200 then
                    buildingInfo.width = leftDist + rightDist

                    -- Estimate corner positions
                    if leftTrace.Hit then
                        table.insert(buildingInfo.cornerPositions, leftTrace.HitPos)
                    else
                        table.insert(buildingInfo.cornerPositions, horizontalTrace.HitPos + rightVec * 500)
                    end

                    if rightTrace.Hit then
                        table.insert(buildingInfo.cornerPositions, rightTrace.HitPos)
                    else
                        table.insert(buildingInfo.cornerPositions, horizontalTrace.HitPos - rightVec * 500)
                    end

                    -- Add the building to our tracking list
                    table.insert(curveData.buildings, buildingInfo)

                    -- Debug visualization
                    if CLIENT and GetConVar("webswing_show_ai_indicator"):GetBool() then
                        debugoverlay.Text(buildingInfo.basePos, "Building", 5, true)
                    end
                end
            end
        end
    end

    -- Identify objects of interest (distinct architectural features like corners)
    for _, building in ipairs(curveData.buildings) do
        for _, cornerPos in ipairs(building.cornerPositions) do
            local interest = {
                pos = cornerPos,
                type = "corner",
                priority = 1
            }
            table.insert(curveData.objectsOfInterest, interest)
        end
    end

    -- Debug visualization
    if CLIENT and GetConVar("webswing_show_ai_indicator"):GetBool() then
        for _, interest in ipairs(curveData.objectsOfInterest) do
            debugoverlay.Sphere(interest.pos, 10, 5, Color(255, 0, 255, 180))
        end
    end
end

-- Generate a curved path around a building
function SwingTargeting:GenerateCurvedPath(playerPos, playerVelocity, playerFacing, targetObject)
    local curveData = self.History.curvedPathData
    local currentTime = CurTime()

    -- If no specific target object provided, see if we're near a building to curve around
    if not targetObject then
        -- Find nearest building in roughly the player's direction
        local forwardDirection = playerVelocity:Length() > 100 and playerVelocity:GetNormalized() or playerFacing
        local bestAlign = 0.6 -- Minimum alignment threshold
        local bestDist = 1500 -- Maximum distance to consider
        local bestBuilding = nil

        for _, building in ipairs(curveData.buildings) do
            local toBuilding = (building.basePos - playerPos):GetNormalized()
            local alignment = forwardDirection:Dot(toBuilding)
            local dist = building.basePos:Distance(playerPos)

            if alignment > bestAlign and dist < bestDist then
                bestAlign = alignment
                bestDist = dist
                bestBuilding = building
            end
        end

        targetObject = bestBuilding
    end

    -- If no good building found, don't create a path
    if not targetObject then
        curveData.pathActive = false
        return false
    end

    -- Clear existing path points
    curveData.pathPoints = {}

    -- Create path around the building
    local pathPoints = {}
    local building = targetObject
    local buildingCenter = building.basePos
    local buildingNormal = building.normal

    -- Get player speed for dynamic path adjustments
    local speed = playerVelocity:Length()

    -- Calculate path around the building
    local rightVector = buildingNormal:Cross(Vector(0, 0, 1)):GetNormalized()
    local startSide = rightVector:Dot((playerPos - buildingCenter):GetNormalized()) > 0 and 1 or -1

    -- REFINEMENT: Dynamic Path Properties
    -- Adjust path radius based on player speed and building size
    local basePathRadius = building.width * 0.6 -- Base path radius

    -- Adjust radius based on speed - faster speeds get wider arcs
    local speedFactor = math.Clamp(speed / 800, 0, 1) -- Normalize speed to 0-1 range
    local pathRadius = basePathRadius * (1 + speedFactor * 0.3) -- Up to 30% wider at high speeds

    -- For very large buildings, make the path tighter relative to building width
    if building.width > 1000 then
        pathRadius = pathRadius * 0.8 -- Tighter arc for very large buildings
    end

    -- Adjust path height based on player height and speed
    local basePathHeight = math.max(playerPos.z, buildingCenter.z + 300) -- Base height
    local pathHeight = basePathHeight

    -- Higher speeds should have slightly higher paths for better arcs
    if speed > 500 then
        pathHeight = pathHeight + (speed - 500) * 0.2 -- Add height based on speed
    end

    -- Create a semicircular path around the building
    -- REFINEMENT: Adjust number of points based on building size for smoother paths
    local baseNumPoints = 10
    local numPoints = math.max(baseNumPoints, math.floor(building.width / 100))
    numPoints = math.min(numPoints, 20) -- Cap at 20 points to avoid performance issues

    for i = 0, numPoints do
        local angle = startSide * (i / numPoints) * math.pi
        local offset = rightVector * math.cos(angle) + buildingNormal * math.sin(angle)

        -- REFINEMENT: Add slight vertical curve to the path for more natural arcs
        local verticalOffset = math.sin(angle * 0.8) * 50 -- Slight vertical curve

        local pathPoint = {
            pos = buildingCenter + offset * pathRadius + Vector(0, 0, pathHeight - buildingCenter.z + verticalOffset),
            normal = -offset,
            index = i + 1
        }
        table.insert(pathPoints, pathPoint)
    end

    -- REFINEMENT: Smooth the path by averaging adjacent points
    if #pathPoints > 3 then
        local smoothedPoints = {}

        -- Keep first and last points unchanged
        table.insert(smoothedPoints, pathPoints[1])

        -- Smooth middle points
        for i = 2, #pathPoints - 1 do
            local prevPos = pathPoints[i-1].pos
            local currentPos = pathPoints[i].pos
            local nextPos = pathPoints[i+1].pos

            -- Simple 3-point average
            local smoothedPos = (prevPos + currentPos + nextPos) / 3

            local smoothedPoint = {
                pos = smoothedPos,
                normal = pathPoints[i].normal, -- Keep original normal
                index = i
            }
            table.insert(smoothedPoints, smoothedPoint)
        end

        -- Add last point
        table.insert(smoothedPoints, pathPoints[#pathPoints])

        -- Replace original points with smoothed ones
        pathPoints = smoothedPoints
    end

    -- Set path data
    curveData.pathPoints = pathPoints
    curveData.pathActive = true
    curveData.pathStartTime = currentTime
    curveData.currentPathIndex = 1
    curveData.lastPathUpdateTime = currentTime

    -- Store path properties for reference
    curveData.pathRadius = pathRadius
    curveData.pathHeight = pathHeight
    curveData.buildingWidth = building.width

    -- Debug visualization
    if CLIENT and GetConVar("webswing_show_ai_indicator"):GetBool() then
        for i, point in ipairs(pathPoints) do
            debugoverlay.Sphere(point.pos, 8, 5, Color(255, 255, 0, 180))
            debugoverlay.Text(point.pos, "Path " .. i, 5, true)

            if i < #pathPoints then
                debugoverlay.Line(point.pos, pathPoints[i+1].pos, 5, Color(255, 255, 0, 180))
            end
        end

        -- Show path properties
        debugoverlay.Text(buildingCenter + Vector(0, 0, 100),
            string.format("Path: R=%.0f, H=%.0f, W=%.0f", pathRadius, pathHeight, building.width),
            5, true)
    end

    return true
end

-- Get the current curved path target point
function SwingTargeting:GetCurvedPathTarget(playerPos, playerVel)
    local curveData = self.History.curvedPathData
    local currentTime = CurTime()

    -- First make sure we have environment data
    self:AnalyzeEnvironmentForCurvedPaths(playerPos, playerVel:GetNormalized())

    -- Check if we need to create or update a path
    if not curveData.pathActive or currentTime - curveData.pathStartTime > 8 then
        -- Try to create a new path
        self:GenerateCurvedPath(playerPos, playerVel, playerVel:GetNormalized())
    end

    -- If no active path, return nil
    if not curveData.pathActive or #curveData.pathPoints == 0 then
        return nil
    end

    -- Determine which path point we should target
    local currentIndex = curveData.currentPathIndex
    local currentPoint = curveData.pathPoints[currentIndex]

    -- If we're close enough to the current target, move to the next point
    if currentPoint and currentPoint.pos:Distance(playerPos) < 200 then
        currentIndex = currentIndex + 1

        -- If we've reached the end of the path, deactivate the path
        if currentIndex > #curveData.pathPoints then
            curveData.pathActive = false
            return nil
        end

        curveData.currentPathIndex = currentIndex
        currentPoint = curveData.pathPoints[currentIndex]
    end

    -- Update the last path update time
    curveData.lastPathUpdateTime = currentTime

    -- Check if the current point is in the sky (additional safety)
    if currentPoint then
        -- Check if path point is valid and not in the skybox
        local skyTrace = util.TraceLine({
            start = playerPos,
            endpos = currentPoint.pos,
            mask = MASK_SOLID
        })

        -- Only return the point if it's a valid target (not sky, not too far, not blocked)
        if skyTrace.HitSky or currentPoint.pos:Distance(playerPos) > GetConVar("webswing_web_length"):GetFloat() then
            -- Point is in sky or too far, move to next one
            curveData.currentPathIndex = currentIndex + 1
            return nil
        end

        -- Check if something is above the point (another sky check)
        local upTrace = util.TraceLine({
            start = currentPoint.pos,
            endpos = currentPoint.pos + Vector(0, 0, 100),
            mask = MASK_SOLID
        })

        if (not upTrace.Hit or upTrace.HitSky) and not GetConVar("webswing_allow_sky_attach"):GetBool() then
            -- This appears to be a sky point
            curveData.currentPathIndex = currentIndex + 1
            return nil
        end

        -- Return the current target point if it passed all checks
        return {
            pos = currentPoint.pos,
            normal = currentPoint.normal,
            type = "curved_path",
            entity = game.GetWorld(),
            isPathPoint = true,
            pathIndex = currentIndex
        }
    end

    return nil
end

-- Apply curved path planning to target selection
function SwingTargeting:ApplyCurvedPathPlanning(candidates, playerPos, playerVel, aimVector)
    local speed = playerVel:Length()

    -- Only apply curved path planning at decent speeds
    if speed < 200 then
        return candidates
    end

    -- Get the current curved path target
    local pathTarget = self:GetCurvedPathTarget(playerPos, playerVel)

    -- If no path target, just return original candidates
    if not pathTarget then
        return candidates
    end

    -- REFINEMENT: Path Feasibility & Destination Awareness
    -- Check if the path leads to a dead-end or confined space
    local isPathViable = true
    local curveData = self.History.curvedPathData

    if curveData.pathActive and #curveData.pathPoints > 0 then
        -- Get the last point in the path to check where it leads
        local lastPathPoint = curveData.pathPoints[#curveData.pathPoints]

        -- Check if there are swing points available at the end of the path
        local destinationScan = false
        local scanRadius = 500
        local scanDirections = 6
        local viableExitPoints = 0

        for i = 1, scanDirections do
            local angle = (i - 1) * (math.pi * 2 / scanDirections)
            local scanDir = Vector(math.cos(angle), math.sin(angle), 0.3) -- Slight upward bias

            local exitTrace = util.TraceLine({
                start = lastPathPoint.pos,
                endpos = lastPathPoint.pos + scanDir * scanRadius,
                mask = MASK_SOLID
            })

            if exitTrace.Hit and not exitTrace.HitSky then
                viableExitPoints = viableExitPoints + 1
            end
        end

        -- If there are too few exit points, the path might lead to a confined space
        if viableExitPoints < 2 then
            isPathViable = false

            if GetConVar("developer"):GetBool() then
                print("[Curved Path] Path leads to confined space with only " .. viableExitPoints .. " exit points")
            end
        end

        -- REFINEMENT: Path Interruption - check if the next segment is obstructed
        if isPathViable and curveData.currentPathIndex < #curveData.pathPoints then
            local nextPathPoint = curveData.pathPoints[curveData.currentPathIndex + 1]

            -- Use obstacle prediction if available to check the path
            if _G.ObstaclePrediction then
                local ropeLength = nextPathPoint.pos:Distance(playerPos)
                local isObstructed = _G.ObstaclePrediction:IsTrajectoryObstructed(
                    nextPathPoint.pos,
                    playerPos,
                    playerVel,
                    ropeLength,
                    nil -- No player entity in this context
                )

                if isObstructed then
                    isPathViable = false

                    if GetConVar("developer"):GetBool() then
                        print("[Curved Path] Path interrupted due to obstacle detection")
                    end

                    -- Deactivate the path so we can find a new one
                    curveData.pathActive = false
                end
            end
        end
    end

    -- Only add the path target if the path is viable
    if isPathViable then
        -- REFINEMENT: Smoother Path Transitions
        -- Evaluate the entry/exit points of the path
        if pathTarget.pathIndex == 1 or pathTarget.pathIndex == #curveData.pathPoints then
            -- This is an entry or exit point, evaluate it more carefully
            local entryExitScore = 0

            -- Check height relative to player
            local heightDiff = pathTarget.pos.z - playerPos.z
            if heightDiff > 0 then
                entryExitScore = entryExitScore + 0.2 -- Bonus for upward points
            elseif heightDiff < -100 then
                entryExitScore = entryExitScore - 0.2 -- Penalty for significantly downward points
            end

            -- Check alignment with current velocity
            local toPoint = (pathTarget.pos - playerPos):GetNormalized()
            local alignScore = playerVel:GetNormalized():Dot(toPoint)
            entryExitScore = entryExitScore + alignScore * 0.3

            -- If the entry/exit point scores poorly, don't use this path
            if entryExitScore < -0.1 then
                if GetConVar("developer"):GetBool() then
                    print("[Curved Path] Rejecting path due to poor entry/exit point score: " .. entryExitScore)
                end
                return candidates
            end

            -- Store the score for use in EvaluatePathTarget
            pathTarget.entryExitScore = entryExitScore
        end

        -- REFINEMENT: Blend Path Target Scoring
        -- As we approach the end of the path, gradually reduce forced preference
        if curveData.pathActive and #curveData.pathPoints > 0 then
            local pathProgress = pathTarget.pathIndex / #curveData.pathPoints
            pathTarget.pathProgress = pathProgress

            -- Debug visualization for path progress
            if CLIENT and GetConVar("webswing_show_ai_indicator"):GetBool() then
                debugoverlay.Text(pathTarget.pos + Vector(0, 0, 20),
                    string.format("Progress: %.1f%%", pathProgress * 100),
                    0.1, true)
            end
        end

        -- Add the path target to the candidates list
        table.insert(candidates, pathTarget)

        -- Debug visualization for path target
        if CLIENT and GetConVar("webswing_show_ai_indicator"):GetBool() then
            debugoverlay.Sphere(pathTarget.pos, 10, 0.1, Color(255, 255, 0, 180))
            debugoverlay.Text(pathTarget.pos, "Path Target", 0.1, true)
            debugoverlay.Line(playerPos, pathTarget.pos, 0.1, Color(255, 255, 0, 180))
        end
    end

    return candidates
end

-- Score curved path targets
function SwingTargeting:EvaluatePathTarget(candidate)
    -- This function is used by EvaluateSwingCandidate to give appropriate score to path targets
    if not candidate.isPathPoint then
        return 0
    end

    -- REFINEMENT: Smoother Path Transitions
    -- Base score for path points
    local baseScore = 0.6

    -- If this is an entry/exit point, use the pre-calculated score
    if candidate.entryExitScore then
        -- Adjust base score by the entry/exit quality
        baseScore = baseScore + candidate.entryExitScore
    end

    -- REFINEMENT: Blend Path Target Scoring
    -- As we approach the end of the path, gradually reduce forced preference
    if candidate.pathProgress then
        -- When we're near the end of the path (>80% complete), start reducing the score
        -- to allow for smoother transition to natural swing points
        if candidate.pathProgress > 0.8 then
            local transitionFactor = (candidate.pathProgress - 0.8) * 5 -- Scale 0.8-1.0 to 0-1
            baseScore = baseScore * (1 - transitionFactor * 0.5) -- Reduce score by up to 50%
        end
    end

    -- Ensure score stays in reasonable range
    return math.Clamp(baseScore, 0.2, 0.8)
end

-- Web of Shadows Auto-Targeting System
-- This system intelligently selects swing points similar to the fluid targeting in Spider-Man: Web of Shadows

-- Initialize WoS targeting system
function SwingTargeting:InitializeWoSTargeting()
    local wosTarget = self.History.webOfShadowsTargeting
    
    -- Create ConVars for the WoS targeting system if they don't exist
    if not ConVarExists("webswing_wos_targeting") then
        CreateConVar("webswing_wos_targeting", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enables Web of Shadows style targeting")
    end
    
    if not ConVarExists("webswing_wos_targeting_intelligence") then
        CreateConVar("webswing_wos_targeting_intelligence", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enables intelligent mode for WoS targeting")
    end
    
    if not ConVarExists("webswing_wos_height_adjustment") then
        CreateConVar("webswing_wos_height_adjustment", "200", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Base height adjustment for WoS targeting", 0, 500)
    end
    
    if not ConVarExists("webswing_wos_anticipation") then
        CreateConVar("webswing_wos_anticipation", "0.7", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How much to anticipate player's next move (0-1)", 0, 1)
    end
    
    -- Load settings from ConVars
    wosTarget.enabled = GetConVar("webswing_wos_targeting"):GetBool()
    wosTarget.intelligentMode = GetConVar("webswing_wos_targeting_intelligence"):GetBool()
    wosTarget.heightAdjustment = GetConVar("webswing_wos_height_adjustment"):GetFloat()
    wosTarget.anticipationFactor = GetConVar("webswing_wos_anticipation"):GetFloat()
    
    -- Initialize other values
    wosTarget.targetingConfidence = 0.5
    wosTarget.preferredHeight = 0
    wosTarget.flowStateFactor = 0
    wosTarget.previousTargets = {}
    
    return true
end

-- Track player input for targeting prediction
function SwingTargeting:TrackPlayerInput(owner, frameTime)
    if not IsValid(owner) then return end
    
    local wosTarget = self.History.webOfShadowsTargeting
    local currentTime = CurTime()
    
    -- Extract player input state
    local moveForward = owner:KeyDown(IN_FORWARD)
    local moveBack = owner:KeyDown(IN_BACK)
    local moveLeft = owner:KeyDown(IN_MOVELEFT)
    local moveRight = owner:KeyDown(IN_MOVERIGHT)
    local jump = owner:KeyDown(IN_JUMP)
    
    -- Check if any movement keys are pressed
    local inputDetected = moveForward or moveBack or moveLeft or moveRight or jump
    
    if inputDetected then
        -- Calculate input direction based on key presses and eye angles
        local eyeAngles = owner:EyeAngles()
        local forward = eyeAngles:Forward()
        local right = eyeAngles:Right()
        
        local inputDir = Vector(0, 0, 0)
        
        if moveForward then inputDir = inputDir + forward end
        if moveBack then inputDir = inputDir - forward end
        if moveRight then inputDir = inputDir + right end
        if moveLeft then inputDir = inputDir - right end
        
        -- Add upward component if jumping
        if jump then inputDir = inputDir + Vector(0, 0, 0.5) end
        
        -- Normalize if we have a direction
        if inputDir:LengthSqr() > 0 then
            inputDir:Normalize()
            
            -- Store last input
            wosTarget.lastInputDirection = inputDir
            wosTarget.lastInputTime = currentTime
        end
    end
    
    -- Calculate flow state based on momentum and successful swings
    local momentumData = self.History.momentumData
    local targetFlowState = 0
    
    if momentumData.consecutiveGoodSwings > 2 then
        -- Increase flow state as player maintains momentum
        targetFlowState = math.min(momentumData.consecutiveGoodSwings * 0.1, 1.0)
    end
    
    -- Smoothly adjust flow state
    wosTarget.flowStateFactor = Lerp(frameTime * 2, wosTarget.flowStateFactor, targetFlowState)
    
    -- Calculate preferred height based on player's state
    local velocity = owner:GetVelocity()
    local speed = velocity:Length()
    local verticalVel = velocity.z
    
    -- Dynamic height adjustment based on player state
    local baseHeight = wosTarget.heightAdjustment
    local targetHeight = baseHeight
    
    -- When moving fast, prefer higher attachment points
    if speed > 400 then
        targetHeight = baseHeight + (speed - 400) * 0.1
    end
    
    -- When falling fast, prefer attachment points that are much higher
    if verticalVel < -200 then
        targetHeight = baseHeight + math.abs(verticalVel) * 0.3
    end
    
    -- When already swinging upward, prefer slightly higher points
    if verticalVel > 100 then
        targetHeight = baseHeight + verticalVel * 0.1
    end
    
    -- In flow state, prefer more dramatic height differences
    targetHeight = targetHeight * (1 + wosTarget.flowStateFactor * 0.5)
    
    -- Smooth transition for height preference
    wosTarget.preferredHeight = Lerp(frameTime * 3, wosTarget.preferredHeight, targetHeight)
    
    return wosTarget.lastInputDirection
end

-- Analyze potential swing points using Web of Shadows targeting logic
function SwingTargeting:AnalyzeWoSTargets(candidates, eyePos, velocity, aimVector, frameTime)
    -- Skip if WoS targeting is disabled
    local wosTarget = self.History.webOfShadowsTargeting
    if not wosTarget.enabled then return candidates end
    
    -- Occasionally reload settings from ConVars
    if CurTime() % 5 < frameTime then
        wosTarget.enabled = GetConVar("webswing_wos_targeting"):GetBool()
        wosTarget.intelligentMode = GetConVar("webswing_wos_targeting_intelligence"):GetBool()
        wosTarget.heightAdjustment = GetConVar("webswing_wos_height_adjustment"):GetFloat()
        wosTarget.anticipationFactor = GetConVar("webswing_wos_anticipation"):GetFloat()
    end
    
    -- Get player state
    local currentTime = CurTime()
    local speed = velocity:Length()
    
    -- Calculate direction of interest
    local directionOfInterest
    local timeSinceInput = currentTime - wosTarget.lastInputTime
    
    if timeSinceInput < 0.5 and wosTarget.lastInputDirection:LengthSqr() > 0 then
        -- Use recent input direction if available
        directionOfInterest = wosTarget.lastInputDirection
    elseif speed > 100 then
        -- Otherwise use current velocity direction if moving
        directionOfInterest = velocity:GetNormalized()
    else
        -- Fall back to aim direction if nearly stationary
        directionOfInterest = aimVector
    end
    
    -- Calculate an anticipation vector that predicts where player wants to go
    local anticipationVector = directionOfInterest
    
    if wosTarget.intelligentMode and self.History.playerDirection:LengthSqr() > 0 then
        -- Blend current direction with predictive direction from movement patterns
        anticipationVector = LerpVector(
            wosTarget.anticipationFactor,
            directionOfInterest,
            self.History.playerDirection
        )
        anticipationVector:Normalize()
    end
    
    -- Calculate ideal arc position for maintaining momentum
    local idealDistance = math.Clamp(300 + speed * 0.5, 300, 1000)
    local idealHeight = eyePos.z + wosTarget.preferredHeight
    
    wosTarget.idealArcPos = eyePos + anticipationVector * idealDistance
    wosTarget.idealArcPos.z = idealHeight
    
    -- Update targeting confidence based on consistency of movement
    if #self.History.recentVelocities > 2 then
        local currentVel = self.History.recentVelocities[1].vel
        local prevVel = self.History.recentVelocities[2].vel
        
        -- If velocity is consistent, increase confidence
        local velDot = currentVel:GetNormalized():Dot(prevVel:GetNormalized())
        local consistencyFactor = (velDot + 1) * 0.5 -- Convert from -1,1 to 0,1
        
        wosTarget.targetingConfidence = Lerp(frameTime * 2, wosTarget.targetingConfidence, consistencyFactor)
    end
    
    -- Maintain target lock if we have one and it's still valid
    if wosTarget.activeTarget and currentTime - wosTarget.targetLockTime < wosTarget.targetLockDuration then
        -- Check if the active target is still in our candidates list
        local targetStillValid = false
        for _, candidate in ipairs(candidates) do
            if candidate.pos:DistToSqr(wosTarget.activeTarget.pos) < 100 then
                targetStillValid = true
                break
            end
        end
        
        -- If target is no longer valid, clear it
        if not targetStillValid then
            wosTarget.activeTarget = nil
        end
    else
        -- Target lock expired or wasn't set
        wosTarget.activeTarget = nil
    end
    
    -- Debug visualization for Web of Shadows targeting
    if CLIENT and GetConVar("webswing_show_ai_indicator"):GetBool() then
        -- Show ideal arc position
        if wosTarget.idealArcPos then
            debugoverlay.Sphere(wosTarget.idealArcPos, 8, frameTime * 2, Color(255, 0, 255, 180))
            debugoverlay.Text(wosTarget.idealArcPos, "WoS Ideal", frameTime * 2, true)
        end
        
        -- Show active target if we have one
        if wosTarget.activeTarget then
            debugoverlay.Sphere(wosTarget.activeTarget.pos, 10, frameTime * 2, Color(0, 255, 0, 180))
            debugoverlay.Text(wosTarget.activeTarget.pos, "WoS Target", frameTime * 2, true)
        end
        
        -- Show targeting confidence and flow state
        local infoText = string.format("WoS: Conf=%.2f, Flow=%.2f", 
                                     wosTarget.targetingConfidence,
                                     wosTarget.flowStateFactor)
        debugoverlay.Text(eyePos + Vector(0, 0, 30), infoText, frameTime * 2, true)
    end
    
    return candidates
end

-- Apply Web of Shadows targeting logic to score candidates
function SwingTargeting:ApplyWoSTargetingScore(candidate, eyePos, velocity)
    local wosTarget = self.History.webOfShadowsTargeting
    if not wosTarget.enabled then return 0 end
    
    local scoreMod = 0
    
    -- If we have an active target and this is it, give it a huge boost
    if wosTarget.activeTarget and candidate.pos:DistToSqr(wosTarget.activeTarget.pos) < 100 then
        return 0.9 -- Very high preference for locked target
    end
    
    -- Distance to ideal arc position
    local idealDistScore = 0
    if wosTarget.idealArcPos then
        local distToIdeal = candidate.pos:Distance(wosTarget.idealArcPos)
        local maxIdealDist = 300
        idealDistScore = 1 - math.Clamp(distToIdeal / maxIdealDist, 0, 1)
        idealDistScore = idealDistScore * 0.6 -- Weight of ideal position scoring
    end
    
    -- Height preference scoring
    local heightScore = 0
    local heightDiff = candidate.pos.z - eyePos.z
    local preferredHeight = wosTarget.preferredHeight
    
    -- Score based on how close the height is to preferred height
    local heightDelta = math.abs(heightDiff - preferredHeight)
    heightScore = 1 - math.Clamp(heightDelta / (preferredHeight * 1.5), 0, 1)
    heightScore = heightScore * 0.4 -- Weight of height scoring
    
    -- Combine scores
    scoreMod = idealDistScore + heightScore
    
    -- Scale by targeting confidence
    scoreMod = scoreMod * wosTarget.targetingConfidence
    
    -- Adjust for flow state - when in flow, be more decisive
    if wosTarget.flowStateFactor > 0.3 then
        scoreMod = scoreMod * (1 + wosTarget.flowStateFactor * 0.5)
    end
    
    -- If this is one of the best candidates so far, consider locking onto it
    if scoreMod > 0.6 then
        wosTarget.activeTarget = candidate
        wosTarget.targetLockTime = CurTime()
        
        -- Store in previous targets
        table.insert(wosTarget.previousTargets, 1, {
            pos = candidate.pos,
            time = CurTime(),
            score = scoreMod
        })
        
        -- Limit history size
        if #wosTarget.previousTargets > 10 then
            table.remove(wosTarget.previousTargets)
        end
    end
    
    return math.Clamp(scoreMod, 0, 0.8)
end

-- Update WoS auto-targeting system every frame
function SwingTargeting:UpdateWoSTargeting(owner, frameTime)
    if not IsValid(owner) then return end
    
    -- Track player input for better targeting prediction
    self:TrackPlayerInput(owner, frameTime)
    
    -- Clean up expired previous targets
    local currentTime = CurTime()
    local wosTarget = self.History.webOfShadowsTargeting
    
    for i = #wosTarget.previousTargets, 1, -1 do
        if currentTime - wosTarget.previousTargets[i].time > 10 then
            table.remove(wosTarget.previousTargets, i)
        end
    end
    
    -- Update flow state decay
    if currentTime - self.History.lastSwingTime > 2 then
        -- Gradually reduce flow state when not swinging
        wosTarget.flowStateFactor = math.max(wosTarget.flowStateFactor - frameTime * 0.5, 0)
    end
end

return SwingTargeting
