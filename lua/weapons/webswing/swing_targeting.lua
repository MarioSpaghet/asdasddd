-- AI Swing Point Intelligence System
-- Module for advanced swing point targeting intelligence

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
        momentumDirection = Vector(0, 0, 0), -- Current momentum direction
        flowState = false, -- Whether player is in "flow state"
        flowStateStartTime = 0, -- When flow state began
        flowStateScore = 0 -- Current flow score (0-1)
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
    local baseDistance = speed > 300 and 800 or 500
    local upwardBias = distToGround < 200 and 0.7 or 0.3 -- More upward bias when close to ground
    local numPointsToGenerate = 4 - #candidates -- Generate up to 4 total points
    
    -- Generate dynamic points
    local newPoints = {}
    
    for i = 1, numPointsToGenerate do
        -- Calculate angle offset for diverse point distribution
        local angleOffset = (i - 1) * (math.pi * 2 / numPointsToGenerate)
        
        -- Base direction from player's intended direction
        local baseDir = self.History.playerDirection:Angle()
        
        -- Add some variation to the angle based on index
        local variedAngle = Angle(
            baseDir.p + math.sin(angleOffset) * 15,
            baseDir.y + math.cos(angleOffset) * 20,
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
            
            -- Create the dynamic point
            table.insert(newPoints, {
                pos = dynamicPos,
                normal = traceToPoint.HitNormal,
                entity = traceToPoint.Entity or game.GetWorld(),
                time = currentTime,
                type = "dynamic",
                isDynamic = true
            })
        elseif not traceToPoint.Hit and not isSkybox then
            -- If we didn't hit anything, make sure this is a valid position with something nearby
            local proximityCheck = util.TraceLine({
                start = dynamicPos,
                endpos = dynamicPos - Vector(0, 0, 200), -- Check below
                mask = MASK_SOLID
            })
            
            if proximityCheck.Hit and not proximityCheck.HitSky and proximityCheck.HitPos:Distance(dynamicPos) < 200 then
                -- Only create a suspended point if there's something below it
                table.insert(newPoints, {
                    pos = dynamicPos,
                    normal = Vector(0, 0, -1), -- Default normal pointing down
                    entity = game.GetWorld(),
                    time = currentTime,
                    type = "dynamic",
                    isDynamic = true
                })
            end
        end
    end
    
    -- Add new points to our dynamic points collection
    for _, point in ipairs(newPoints) do
        table.insert(self.History.dynamicPoints, point)
    end
    
    -- Update the last generation time
    self.History.lastDynamicPointTime = currentTime
    
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
    
    -- Flow state detection
    local currentTime = CurTime()
    local flowThreshold = 0.6 -- Threshold for entering flow state
    local flowDecay = 0.1 -- How quickly flow state decays
    
    -- When in flow state, heavily favor points that maintain momentum
    if momentumData.flowState then
        -- Check if we should exit flow state
        if currentTime - momentumData.flowStateStartTime > 5 or speed < 300 then
            momentumData.flowState = false
            momentumData.flowStateScore = math.max(momentumData.flowStateScore - flowDecay, 0)
        else
            -- In flow state, boost momentum alignment importance
            momentumData.flowStateScore = math.min(momentumData.flowStateScore + 0.05, 1.0)
        end
    else
        -- Check if we should enter flow state
        if speed > 500 and momentumData.consecutiveGoodSwings >= 2 then
            momentumData.flowState = true
            momentumData.flowStateStartTime = currentTime
            momentumData.flowStateScore = 0.5 -- Initial flow score
        end
    end
    
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
    local baseWeight = (1 + momentumData.flowStateScore * 0.5) -- Flow state increases momentum importance
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
        
        -- Show ideal swing point if in flow state
        if momentumData.flowState then
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
        print(string.format("[Momentum] Quality: %.2f, Consecutive: %d, Multiplier: %.2f, Flow: %s", 
                          quality, 
                          momentumData.consecutiveGoodSwings,
                          momentumData.momentumMultiplier,
                          momentumData.flowState and "YES" or "NO"))
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
    
    -- Calculate path around the building
    local rightVector = buildingNormal:Cross(Vector(0, 0, 1)):GetNormalized()
    local startSide = rightVector:Dot((playerPos - buildingCenter):GetNormalized()) > 0 and 1 or -1
    local pathRadius = building.width * 0.6 -- Path slightly away from the building
    local pathHeight = math.max(playerPos.z, buildingCenter.z + 300) -- Path at reasonable height
    
    -- Create a semicircular path around the building
    local numPoints = 10
    for i = 0, numPoints do
        local angle = startSide * (i / numPoints) * math.pi
        local offset = rightVector * math.cos(angle) + buildingNormal * math.sin(angle)
        local pathPoint = {
            pos = buildingCenter + offset * pathRadius + Vector(0, 0, pathHeight - buildingCenter.z),
            normal = -offset,
            index = i + 1
        }
        table.insert(pathPoints, pathPoint)
    end
    
    -- Set path data
    curveData.pathPoints = pathPoints
    curveData.pathActive = true
    curveData.pathStartTime = currentTime
    curveData.currentPathIndex = 1
    curveData.lastPathUpdateTime = currentTime
    
    -- Debug visualization
    if CLIENT and GetConVar("webswing_show_ai_indicator"):GetBool() then
        for i, point in ipairs(pathPoints) do
            debugoverlay.Sphere(point.pos, 8, 5, Color(255, 255, 0, 180))
            debugoverlay.Text(point.pos, "Path " .. i, 5, true)
            
            if i < #pathPoints then
                debugoverlay.Line(point.pos, pathPoints[i+1].pos, 5, Color(255, 255, 0, 180))
            end
        end
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
    
    -- Add the path target to the candidates list
    table.insert(candidates, pathTarget)
    
    -- Debug visualization for path target
    if CLIENT and GetConVar("webswing_show_ai_indicator"):GetBool() then
        debugoverlay.Sphere(pathTarget.pos, 10, 0.1, Color(255, 255, 0, 180))
        debugoverlay.Text(pathTarget.pos, "Path Target", 0.1, true)
        debugoverlay.Line(playerPos, pathTarget.pos, 0.1, Color(255, 255, 0, 180))
    end
    
    return candidates
end

-- Score curved path targets
function SwingTargeting:EvaluatePathTarget(candidate)
    -- This function is used by EvaluateSwingCandidate to give appropriate score to path targets
    if not candidate.isPathPoint then
        return 0
    end
    
    -- Path points get a substantial score to make them desirable
    -- but not so high that they override critical gameplay needs like avoiding hitting the ground
    return 0.6
end

return SwingTargeting
