-- Simplified Swing Targeting System
-- Focus: Physics + Player Preference, No Artificial Complexity

local SwingTargeting = {}

-- Simple configuration - no over-engineering
SwingTargeting.Config = {
    -- Physics parameters
    OptimalSwingDistance = 400,  -- Ideal distance for pendulum physics
    MaxSwingDistance = 800,      -- Maximum useful distance
    MinSwingDistance = 150,      -- Minimum useful distance
    
    -- Movement tracking
    HistorySize = 5,             -- Track last 5 swing points
    TrendInfluence = 0.3,        -- How much movement trend affects scoring (0-1)
    
    -- Emergency thresholds
    GroundDangerHeight = 200,    -- Height below which we prioritize upward points
    LowSpeedThreshold = 100,     -- Speed below which we use different logic
}

-- Player swing history tracking
SwingTargeting.PlayerHistory = {}

-- Get or create player history
function SwingTargeting:GetPlayerHistory(player)
    if not IsValid(player) then return nil end
    
    local steamID = player:SteamID()
    if not self.PlayerHistory[steamID] then
        self.PlayerHistory[steamID] = {
            recentPoints = {},           -- Last few swing points chosen
            movementTrend = Vector(0,0,0), -- Current movement direction trend
            lastUpdateTime = 0,
        }
    end
    
    return self.PlayerHistory[steamID]
end

-- Record when player chooses a swing point
function SwingTargeting:RecordSwingChoice(player, chosenPoint)
    local history = self:GetPlayerHistory(player)
    if not history then return end
    
    -- Add to recent points
    table.insert(history.recentPoints, 1, {
        pos = chosenPoint,
        time = CurTime()
    })
    
    -- Limit history size
    if #history.recentPoints > self.Config.HistorySize then
        table.remove(history.recentPoints)
    end
    
    -- Update movement trend if we have enough data
    if #history.recentPoints >= 2 then
        local recent = history.recentPoints[1].pos
        local previous = history.recentPoints[2].pos
        local newTrend = (recent - previous):GetNormalized()
        
        -- Blend with existing trend for smoothness
        if history.movementTrend:LengthSqr() > 0 then
            history.movementTrend = LerpVector(0.3, history.movementTrend, newTrend)
        else
            history.movementTrend = newTrend
        end
        
        history.movementTrend:Normalize()
    end
    
    history.lastUpdateTime = CurTime()
end

-- Calculate physics optimality score for a swing point
function SwingTargeting:CalculatePhysicsScore(candidate, playerPos, velocity)
    local score = 0
    local distance = candidate.pos:Distance(playerPos)
    local speed = velocity:Length()
    
    -- Distance scoring - prefer optimal swing distances
    local distanceScore = 0
    if distance >= self.Config.MinSwingDistance and distance <= self.Config.MaxSwingDistance then
        -- Calculate how close to optimal distance
        local optimalDist = self.Config.OptimalSwingDistance
        local deviation = math.abs(distance - optimalDist) / optimalDist
        distanceScore = math.max(0, 1 - deviation)
    end
    score = score + distanceScore * 0.4
    
    -- Momentum preservation - does this point work with current velocity?
    if speed > self.Config.LowSpeedThreshold then
        local velocityDir = velocity:GetNormalized()
        local toCandidate = (candidate.pos - playerPos):GetNormalized()
        
        -- Points roughly in direction of movement are better
        local alignmentScore = math.max(0, velocityDir:Dot(toCandidate))
        score = score + alignmentScore * 0.3
        
        -- Height considerations for momentum
        local heightDiff = candidate.pos.z - playerPos.z
        if speed > 300 then
            -- At high speed, slight downward bias maintains momentum
            if heightDiff < 0 and heightDiff > -100 then
                score = score + 0.1
            end
        end
    end
    
    -- Arc quality - avoid points that create sharp angles
    local heightDiff = candidate.pos.z - playerPos.z
    local horizontalDist = math.sqrt(distance * distance - heightDiff * heightDiff)
    
    if horizontalDist > 0 then
        local arcAngle = math.atan2(math.abs(heightDiff), horizontalDist)
        -- Prefer moderate arc angles (not too steep, not too shallow)
        local idealAngle = math.rad(30) -- 30 degrees
        local angleDiff = math.abs(arcAngle - idealAngle)
        local arcScore = math.max(0, 1 - (angleDiff / math.rad(45)))
        score = score + arcScore * 0.2
    end
    
    -- Safety - avoid points that lead into geometry
    local toPoint = candidate.pos - playerPos
    local midPoint = playerPos + toPoint * 0.5
    local checkTrace = util.TraceLine({
        start = playerPos,
        endpos = midPoint,
        mask = MASK_SOLID
    })
    
    if checkTrace.Hit then
        score = score - 0.2 -- Penalty for obstructed path
    end
    
    return math.Clamp(score, 0, 1)
end

-- Calculate player preference score based on movement patterns
function SwingTargeting:CalculatePreferenceScore(candidate, player, playerPos)
    local history = self:GetPlayerHistory(player)
    if not history then return 0.5 end -- Default neutral score
    
    local score = 0
    
    -- Movement trend influence
    if history.movementTrend:LengthSqr() > 0 then
        local toCandidate = (candidate.pos - playerPos):GetNormalized()
        local trendAlignment = math.max(0, history.movementTrend:Dot(toCandidate))
        score = score + trendAlignment * self.Config.TrendInfluence
    end
    
    -- Recent point patterns - avoid recently used areas unless they're clearly good
    local recentAvoidance = 0
    for i, recentPoint in ipairs(history.recentPoints) do
        local distToRecent = candidate.pos:Distance(recentPoint.pos)
        if distToRecent < 200 then
            -- Slight penalty for being too close to recent points
            local ageFactor = math.min(1, (CurTime() - recentPoint.time) / 5) -- 5 second decay
            recentAvoidance = recentAvoidance + (1 - ageFactor) * 0.1
        end
    end
    score = score - recentAvoidance
    
    -- Consistency bonus - if this point fits established patterns
    if #history.recentPoints >= 3 then
        local avgHeight = 0
        for _, point in ipairs(history.recentPoints) do
            avgHeight = avgHeight + point.pos.z
        end
        avgHeight = avgHeight / #history.recentPoints
        
        local heightDiff = math.abs(candidate.pos.z - avgHeight)
        if heightDiff < 100 then
            score = score + 0.1 -- Small bonus for consistent height choices
        end
    end
    
    return math.Clamp(score, 0, 1)
end

-- Emergency system - handle dangerous situations
function SwingTargeting:CalculateEmergencyScore(candidate, playerPos, velocity)
    local score = 0
    
    -- Check if player is close to ground
    local groundTrace = util.TraceLine({
        start = playerPos,
        endpos = playerPos - Vector(0, 0, 1000),
        mask = MASK_SOLID
    })
    
    local distToGround = groundTrace.Hit and groundTrace.HitPos:Distance(playerPos) or 1000
    
    -- Emergency upward bias when close to ground
    if distToGround < self.Config.GroundDangerHeight then
        local heightDiff = candidate.pos.z - playerPos.z
        if heightDiff > 50 then -- Point is above player
            local urgency = 1 - (distToGround / self.Config.GroundDangerHeight)
            score = score + urgency * 0.4 -- Strong bonus when in danger
        end
    end
    
    -- Emergency forward momentum when falling
    local speed = velocity:Length()
    if velocity.z < -200 and speed > 200 then -- Falling fast
        local velocityDir = velocity:GetNormalized()
        local toCandidate = (candidate.pos - playerPos):GetNormalized()
        local alignment = velocityDir:Dot(toCandidate)
        
        if alignment > 0.5 then -- Point is roughly forward
            score = score + 0.3 -- Help maintain forward momentum while falling
        end
    end
    
    return math.Clamp(score, 0, 1)
end

-- Main candidate evaluation function
function SwingTargeting:EvaluateCandidate(candidate, player, playerPos, velocity)
    if not IsValid(player) then return 0 end
    
    -- Calculate component scores
    local physicsScore = self:CalculatePhysicsScore(candidate, playerPos, velocity)
    local preferenceScore = self:CalculatePreferenceScore(candidate, player, playerPos)
    local emergencyScore = self:CalculateEmergencyScore(candidate, playerPos, velocity)
    
    -- Weight the scores
    local finalScore = physicsScore * 0.7 + preferenceScore * 0.2 + emergencyScore * 0.1
    
    -- Debug visualization if enabled
    if CLIENT and GetConVar("webswing_show_ai_indicator") and GetConVar("webswing_show_ai_indicator"):GetBool() then
        local debugColor = Color(255 * finalScore, 255 * (1 - finalScore), 0, 180)
        debugoverlay.Sphere(candidate.pos, 5, 0.1, debugColor)
        
        if finalScore > 0.6 then
            debugoverlay.Text(candidate.pos + Vector(0, 0, 20), 
                string.format("Score: %.2f\nP:%.2f Pr:%.2f E:%.2f", 
                    finalScore, physicsScore, preferenceScore, emergencyScore), 
                0.1, true)
        end
    end
    
    return finalScore
end

-- Clean up old player data periodically
function SwingTargeting:CleanupOldData()
    local currentTime = CurTime()
    local maxAge = 300 -- 5 minutes
    
    for steamID, history in pairs(self.PlayerHistory) do
        if currentTime - history.lastUpdateTime > maxAge then
            self.PlayerHistory[steamID] = nil
        end
    end
end

-- Hook for periodic cleanup
if SERVER then
    timer.Create("SwingTargeting_Cleanup", 60, 0, function()
        SwingTargeting:CleanupOldData()
    end)
end

-- Extracted Targeting System (delegated from shared.lua)
-- These functions accept the weapon instance as the first parameter

local SimpleMapAnalysis = include("simple_map_analysis.lua")

function SwingTargeting:IsValidSwingPoint(weapon, pos, playerPos)
    local allowSkyAttach = GetConVar("webswing_allow_sky_attach"):GetBool()
    if allowSkyAttach then
        return true
    end

    local upTrace = util.TraceLine({
        start = pos,
        endpos = pos + Vector(0, 0, 100),
        mask = MASK_SOLID
    })

    if not upTrace.Hit then
        local surroundTraces = {}
        local directions = { Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0) }
        for _, dir in ipairs(directions) do
            local surroundTrace = util.TraceLine({ start = pos, endpos = pos + dir * 100, mask = MASK_SOLID })
            if surroundTrace.Hit and not surroundTrace.HitSky then
                table.insert(surroundTraces, surroundTrace)
            end
        end
        if #surroundTraces < 1 then
            return false
        end
    elseif upTrace.HitSky then
        return false
    end

    local traceToPoint = util.TraceLine({ start = playerPos, endpos = pos, mask = MASK_SOLID })
    if traceToPoint.HitSky then
        return false
    end

    return true
end

function SwingTargeting:CalculateOptimalSkyHeight(weapon, eyePos, velocity, distToGround)
    local baseHeight = math.max(distToGround * 1.5, 300)
    local speedFactor = math.min(velocity:Length() / 1000, 1)
    local speedBonus = speedFactor * 400
    local finalHeight = baseHeight + speedBonus
    return math.Clamp(finalHeight, 300, 1500)
end

function SwingTargeting:CheckOverheadClearance(weapon, pos)
    local heightCheck = util.TraceLine({ start = pos, endpos = pos - Vector(0, 0, 1000), mask = MASK_SOLID })
    if not heightCheck.Hit or heightCheck.HitPos:Distance(pos) > 500 then
        return { clear = true, height = 100 }
    end

    local tr = util.TraceLine({ start = pos, endpos = pos + Vector(0, 0, 80), mask = MASK_SOLID })
    if not tr.Hit then
        local hasObstruction = false
        local angles = {30, 150, 270}
        for _, angle in ipairs(angles) do
            local rad = math.rad(angle)
            local checkDir = Vector(math.cos(rad) * 0.5, math.sin(rad) * 0.5, 0.8):GetNormalized()
            local coneTrace = util.TraceLine({ start = pos, endpos = pos + checkDir * 60, mask = MASK_SOLID })
            if coneTrace.Hit then
                hasObstruction = true
                break
            end
        end
        return { clear = not hasObstruction, height = hasObstruction and 60 or 80 }
    end

    return { clear = false, height = tr.HitPos:Distance(pos) }
end

function SwingTargeting:IsCornerPoint(weapon, hitPos, hitNormal)
    local checkDist = 20
    local right = hitNormal:Cross(Vector(0, 0, 1)):GetNormalized()
    local up = right:Cross(hitNormal):GetNormalized()
    local directions = { right, right * -1, up, up * -1 }

    local gaps = 0
    local traces = 0
    for _, dir in ipairs(directions) do
        if gaps >= 2 or traces >= 3 then break end
        if math.abs(dir:Dot(hitNormal)) > 0.1 then continue end

        traces = traces + 1
        local tr = util.TraceLine({
            start = hitPos + hitNormal * 2,
            endpos = hitPos + hitNormal * 2 + dir * checkDist,
            mask = MASK_SOLID
        })
        if not tr.Hit then
            gaps = gaps + 1
        end
    end
    return gaps >= 2
end

function SwingTargeting:GatherSwingPointCandidates(weapon)
    local ply = weapon.Owner
    if not IsValid(ply) then return {} end

    local eyePos = ply:EyePos()
    local eyeAngles = ply:EyeAngles()
    local vel = ply:GetVelocity()
    local speed = vel:Length()
    local scanRadius = weapon.Range * GetConVar("webswing_map_range_mult"):GetFloat()
    local candidates = {}

    local momentumFactor = GetConVar("webswing_momentum_preservation"):GetFloat()
    local groundSafety = GetConVar("webswing_ground_safety"):GetFloat()
    local allowSkyAttach = GetConVar("webswing_allow_sky_attach"):GetBool()

    local groundTrace = util.TraceLine({ start = eyePos, endpos = eyePos - Vector(0, 0, 1000), filter = ply, mask = MASK_SOLID })
    local distToGround = groundTrace.Hit and groundTrace.HitPos:Distance(eyePos) or 1000

    local baseSteps = 16
    local steps = baseSteps
    local halfAngle = 30
    if speed > 500 then
        halfAngle = Lerp(momentumFactor, 30, 15)
        steps = math.floor(Lerp(momentumFactor, baseSteps, 12))
    elseif distToGround < 200 and groundSafety > 0.5 then
        halfAngle = Lerp(groundSafety, 30, 45)
        steps = math.floor(Lerp(groundSafety, baseSteps, 20))
    end

    local idealDir = vel:GetNormalized()
    if speed < 100 then
        idealDir = ply:GetAimVector()
    end

    local scannedDirections = {}
    for i = 1, steps do
        local angleProgress = (i - 1) / steps
        local yawOffset = 360 * angleProgress

        local basePitch = -30
        if distToGround < 200 then
            basePitch = Lerp(groundSafety, -30, -15)
        elseif speed > 500 then
            basePitch = Lerp(momentumFactor, -30, -45)
        end

        local pitchOffset = basePitch + math.random(-halfAngle, halfAngle)
        local scanAngles = Angle(eyeAngles.p + pitchOffset, eyeAngles.y + yawOffset, 0)
        local direction = scanAngles:Forward()

        local dirKey = string.format("%.1f_%.1f_%.1f", direction.x, direction.y, direction.z)
        if scannedDirections[dirKey] then continue end
        scannedDirections[dirKey] = true

        if speed > 100 then
            direction = LerpVector(momentumFactor * 0.5, direction, idealDir)
            direction:Normalize()
        end

        local tr = util.TraceLine({ start = eyePos, endpos = eyePos + direction * scanRadius, filter = ply, mask = MASK_SOLID })
        if tr.Hit then
            local heightDiff = tr.HitPos.z - eyePos.z
            local isCorner = false
            local overhead = nil
            if (heightDiff > -100 and heightDiff < 300) or (speed > 300 and tr.HitPos:Distance(eyePos + vel:GetNormalized() * 300) < 200) then
                isCorner = self:IsCornerPoint(weapon, tr.HitPos, tr.HitNormal)
                overhead = self:CheckOverheadClearance(weapon, tr.HitPos)
            end

            local pointType = "forward"
            if heightDiff > 100 then
                pointType = "overhead"
            elseif speed > 300 and tr.HitPos:Distance(eyePos + vel:GetNormalized() * 300) < 200 then
                pointType = "momentum"
            end

            table.insert(candidates, { pos = tr.HitPos, normal = tr.HitNormal, entity = tr.Entity, isCorner = isCorner, overhead = overhead, type = pointType })
        end
    end

    if distToGround < 200 and groundSafety > 0.5 and #candidates < 3 then
        local upSteps = math.floor(4 * groundSafety)
        local upRadius = scanRadius * 0.4
        for i = 1, upSteps do
            local angle = math.rad((i / upSteps) * 360)
            local offset = Vector(math.cos(angle) * upRadius * 0.3, math.sin(angle) * upRadius * 0.3, upRadius)
            local tr = util.TraceLine({ start = eyePos, endpos = eyePos + offset, filter = ply, mask = MASK_SOLID })
            if tr.Hit then
                table.insert(candidates, { pos = tr.HitPos, normal = tr.HitNormal, entity = tr.Entity, isCorner = false, overhead = self:CheckOverheadClearance(weapon, tr.HitPos), type = "emergency" })
            end
        end
    end

    if speed > 500 and momentumFactor > 0.5 and #candidates < 5 then
        local momSteps = math.floor(3 * momentumFactor)
        local momRadius = scanRadius * 0.6
        for i = 1, momSteps do
            local progress = (i - 1) / momSteps
            local offset = vel:GetNormalized() * (momRadius * progress) + Vector(0, 0, momRadius * 0.3 * (1 - progress))
            local tr = util.TraceLine({ start = eyePos, endpos = eyePos + offset, filter = ply, mask = MASK_SOLID })
            if tr.Hit then
                table.insert(candidates, { pos = tr.HitPos, normal = tr.HitNormal, entity = tr.Entity, isCorner = false, overhead = self:CheckOverheadClearance(weapon, tr.HitPos), type = "momentum" })
            end
        end
    end

    if allowSkyAttach then
        local skyHeight = self:CalculateOptimalSkyHeight(weapon, eyePos, vel, distToGround)
        local skySteps = 8
        local skyRadius = scanRadius * 0.7
        local pattern = {}
        if speed > 300 then
            local forward = vel:GetNormalized()
            local right = forward:Cross(Vector(0, 0, 1))
            for i = 1, skySteps do
                local angle = math.rad((i / skySteps) * 270 - 135)
                local dirWeight = math.cos(angle) * 0.5 + 0.5
                local dir = forward * dirWeight + right * math.sin(angle)
                dir:Normalize()
                table.insert(pattern, dir)
            end
        else
            for i = 1, skySteps do
                local angle = math.rad((i / skySteps) * 360)
                table.insert(pattern, Vector(math.cos(angle), math.sin(angle), 0))
            end
        end
        for _, dir in ipairs(pattern) do
            local offset = dir * skyRadius * 0.5
            local skyPoint = eyePos + offset + Vector(0, 0, skyHeight - eyePos.z)
            local skyTrace = util.TraceLine({ start = eyePos, endpos = skyPoint, filter = ply, mask = MASK_SOLID })
            if not skyTrace.Hit then
                table.insert(candidates, { pos = skyPoint, normal = Vector(0, 0, -1), entity = game.GetWorld(), isCorner = false, overhead = { clear = true, height = skyHeight - eyePos.z }, type = "sky" })
            end
        end

        if speed > 300 then
            local forwardDist = math.min(speed * 0.5, skyRadius * 0.7)
            local forwardPoint = eyePos + vel:GetNormalized() * forwardDist + Vector(0, 0, skyHeight * 0.7)
            local forwardTrace = util.TraceLine({ start = eyePos, endpos = forwardPoint, filter = ply, mask = MASK_SOLID })
            if not forwardTrace.Hit then
                table.insert(candidates, { pos = forwardPoint, normal = Vector(0, 0, -1), entity = game.GetWorld(), isCorner = false, overhead = { clear = true, height = skyHeight - eyePos.z }, type = "sky_momentum" })
            end
        end
    end

    if #candidates == 0 then
        local up_tr = util.TraceLine({ start = eyePos, endpos = eyePos + Vector(0, 0, 500), filter = ply, mask = MASK_SOLID })
        if up_tr.Hit then
            table.insert(candidates, { pos = up_tr.HitPos, normal = up_tr.HitNormal, entity = up_tr.Entity, type = "emergency_vertical" })
        end
    end

    if speed > 200 and not GetConVar("webswing_manual_mode"):GetBool() then
        local candidatesWithPaths = candidates
        if SwingTargeting and SwingTargeting.ApplyCurvedPathPlanning then
            candidatesWithPaths = SwingTargeting:ApplyCurvedPathPlanning(candidates, eyePos, vel, ply:GetAimVector())
        end
        candidates = {}
        for _, candidate in ipairs(candidatesWithPaths) do
            if not candidate.isPathPoint or self:IsValidSwingPoint(weapon, candidate.pos, eyePos) then
                table.insert(candidates, candidate)
            end
        end
        if GetConVar("developer"):GetBool() then
            print("[Web Shooter] Applied curved path planning")
        end
    end

    local validCandidates = {}
    for _, candidate in ipairs(candidates) do
        if self:IsValidSwingPoint(weapon, candidate.pos, eyePos) or (candidate.type == "sky" and allowSkyAttach) then
            table.insert(validCandidates, candidate)
        end
    end
    return validCandidates
end

function SwingTargeting:EvaluateSwingCandidate(weapon, candidate, playerState, allCandidates)
    local score = 0
    local ply = weapon.Owner
    local eyePos = playerState.eyePos
    local vel = playerState.velocity
    local speedSqr = vel:LengthSqr()
    local speed = vel:Length()

    local momentumFactor = GetConVar("webswing_momentum_preservation"):GetFloat()
    local groundSafety = GetConVar("webswing_ground_safety"):GetFloat()
    local assistStrength = GetConVar("webswing_assist_strength"):GetFloat()
    local maxWebLength = GetConVar("webswing_web_length"):GetFloat()
    local swingCurve = GetConVar("webswing_swing_curve"):GetFloat()

    local groundTrace = util.TraceLine({ start = eyePos, endpos = eyePos - Vector(0, 0, 1000), filter = ply, mask = MASK_SOLID })
    local distToGround = groundTrace.Hit and groundTrace.HitPos:Distance(eyePos) or 1000

    local isConfined = false
    local confinedDirections = 0
    local confinedCheckDist = 150
    if speed < 300 then
        local checkDirections = {
            Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0),
            Vector(0.7, 0.7, 0), Vector(-0.7, 0.7, 0), Vector(0.7, -0.7, 0), Vector(-0.7, -0.7, 0)
        }
        for _, dir in ipairs(checkDirections) do
            local confineTrace = util.TraceLine({ start = eyePos, endpos = eyePos + dir * confinedCheckDist, filter = ply, mask = MASK_SOLID_BRUSHONLY })
            if confineTrace.Hit then
                confinedDirections = confinedDirections + 1
            end
        end
        isConfined = confinedDirections >= 3
        if CLIENT and GetConVar("webswing_show_ai_indicator"):GetBool() and isConfined then
            debugoverlay.Text(eyePos + Vector(0, 0, 20), "CONFINED SPACE", 0.5, true)
        end
    end

    if candidate.isPathPoint then
        local pathScore = 0.5
        if SwingTargeting and SwingTargeting.EvaluatePathTarget then
            pathScore = SwingTargeting:EvaluatePathTarget(candidate)
        end
        if speedSqr > 90000 then
            pathScore = pathScore * (1 + swingCurve * 0.5)
        end
        local dist = candidate.pos:Distance(eyePos)
        if dist > maxWebLength then
            return -1000
        end
        if distToGround < 100 and candidate.pos.z < eyePos.z then
            pathScore = pathScore * 0.5
        end
        return pathScore
    end

    local dist = candidate.pos:Distance(eyePos)
    if dist > maxWebLength then
        return -1000
    end

    local baseOptimalDist = 500
    local speedBonus = math.sqrt(speedSqr) * 0.5 * momentumFactor
    local optimalDist = math.Clamp(baseOptimalDist + speedBonus, 300, maxWebLength * 0.8)
    local distScore = 1 - math.abs(dist - optimalDist) / optimalDist
    score = score + distScore * (0.3 * assistStrength)

    local heightDiff = candidate.pos.z - eyePos.z
    local optimalHeight = weapon.OptimalSwingHeight or 150
    optimalHeight = optimalHeight * (1 + swingCurve * 0.5)

    if distToGround < 200 and groundSafety > 0 then
        local groundDanger = (200 - distToGround) / 200
        if heightDiff > 0 then
            score = score + (groundDanger * groundSafety * 0.5)
        else
            score = score - (groundDanger * groundSafety * 0.5)
        end
    end

    local arcScore = 0
    if candidate.type == "overhead" then
        arcScore = math.Clamp(heightDiff / (optimalHeight * swingCurve), 0, 1) * (0.4 * assistStrength)
    else
        local idealHeight = optimalHeight * (1 + (speed / 1000) * swingCurve)
        local heightScore = 1 - math.abs(heightDiff - idealHeight) / idealHeight
        arcScore = math.Clamp(heightScore, 0, 1) * (0.3 * assistStrength)
        local velDir = vel:GetNormalized()
        local rightVec = velDir:Cross(Vector(0, 0, 1))
        local lateralOffset = math.abs(rightVec:Dot((candidate.pos - eyePos):GetNormalized()))
        local lateralScore = lateralOffset * swingCurve * 0.2
        arcScore = arcScore + lateralScore
    end
    score = score + arcScore

    local opennessScore = 0
    if false then
        local ropeLength = dist
        local isObstructed = weapon.ObstaclePrediction:IsTrajectoryObstructed(candidate.pos, eyePos, vel, ropeLength, ply)
        if not isObstructed then
            local openSpaceChecks = 0
            local openSpaceHits = 0
            local checkWidth = 80
            local toPoint = (candidate.pos - eyePos):GetNormalized()
            local arcRight = toPoint:Cross(Vector(0, 0, 1)):GetNormalized()
            local arcUp = arcRight:Cross(toPoint):GetNormalized()
            local checkDirections = { arcRight * checkWidth, arcRight * -checkWidth, arcUp * checkWidth }
            for _, offset in ipairs(checkDirections) do
                openSpaceChecks = openSpaceChecks + 1
                for t = 0.3, 0.7, 0.2 do
                    local arcPoint = eyePos + toPoint * (dist * t)
                    local wideTrace = util.TraceHull({ start = arcPoint, endpos = arcPoint + offset, mins = Vector(-10, -10, -10), maxs = Vector(10, 10, 10), filter = ply, mask = MASK_SOLID_BRUSHONLY })
                    if wideTrace.Hit then
                        openSpaceHits = openSpaceHits + 1
                    end
                end
            end
            local opennessFactor = 1 - (openSpaceHits / (openSpaceChecks * 3))
            opennessScore = opennessFactor * 0.2 * assistStrength
            if CLIENT and GetConVar("webswing_show_ai_indicator"):GetBool() and opennessScore > 0.1 then
                debugoverlay.Text(candidate.pos + Vector(0, 0, 15), string.format("Open: %.1f", opennessScore * 5), 0.2, true)
            end
        end
    end
    score = score + opennessScore

    if SwingTargeting and SwingTargeting.EvaluateCandidate then
        local targetingScore = SwingTargeting:EvaluateCandidate(candidate, ply, eyePos, vel)
        score = score + targetingScore * 0.8
    end

    if candidate.isCorner then
        local cornerBonus = 0.2 * assistStrength
        if candidate.overhead and candidate.overhead.clear then
            cornerBonus = cornerBonus + (0.1 * assistStrength)
        end
        cornerBonus = cornerBonus * (1 - swingCurve * 0.3)
        score = score + cornerBonus
    end

    if candidate.overhead then
        local clearanceScore = candidate.overhead.clear and 0.2 or (candidate.overhead.height / 100) * 0.1
        score = score + clearanceScore * assistStrength
    end

    local analysis = SimpleMapAnalysis.Cache[game.GetMap()]
    if analysis then
        if analysis.wallDensity > 0.7 then
            if heightDiff > 0 then
                score = score + (0.1 * assistStrength * (1 + swingCurve * 0.5))
            end
        end
        if analysis.openness > 0.7 then
            if dist > optimalDist * 0.8 then
                score = score + (0.1 * momentumFactor * (1 - swingCurve * 0.3))
            end
        end
    end

    if distToGround < 100 and speedSqr < 40000 then
        if heightDiff > 0 and dist < 300 then
            score = score + (1.0 * groundSafety)
        end
    end

    if candidate.type == "sky" or candidate.type == "sky_momentum" then
        score = score + 0.3
        if candidate.type == "sky_momentum" and speedSqr > 90000 then
            local velDir = vel:GetNormalized()
            local toPoint = (candidate.pos - eyePos):GetNormalized()
            local momentumAlign = velDir:Dot(toPoint)
            score = score + momentumAlign * 0.4 * momentumFactor
        end
        if allCandidates and #allCandidates < 3 and distToGround < 200 then
            score = score + 0.3 * groundSafety
        end
    end

    do
        local assistStrengthLocal = assistStrength
        if IsValid(candidate.entity) then
            if candidate.entity:IsWorld() then
                score = score + 0.1 * assistStrengthLocal
            else
                local phys = candidate.entity:GetPhysicsObject()
                if IsValid(phys) then
                    local entVel = phys:GetVelocity():Length()
                    if entVel > 20 then
                        score = score - 0.15 * assistStrengthLocal
                    else
                        score = score + 0.05 * assistStrengthLocal
                    end
                end
            end
        end
        local upwardAlignment = candidate.normal:Dot(Vector(0, 0, 1))
        if upwardAlignment < 0.3 then
            score = score + 0.1 * assistStrengthLocal
        elseif upwardAlignment > 0.7 then
            score = score - 0.1 * assistStrengthLocal
        end
    end

    if speed > 300 then
        local predictedVel
        if weapon.PrevEvalVelocity then
            local acceleration = (vel - weapon.PrevEvalVelocity) / FrameTime()
            predictedVel = vel + acceleration * 0.1
        else
            predictedVel = vel
        end
        weapon.PrevEvalVelocity = vel
        local predictedAlignment = predictedVel:GetNormalized():Dot((candidate.pos - eyePos):GetNormalized())
        predictedAlignment = math.Clamp(predictedAlignment, 0, 1)
        score = score + predictedAlignment * 0.2
    end

    if false then
        local obstacleScore = weapon.ObstaclePrediction:EvaluateObstacleAvoidance(candidate, eyePos, vel, ply)
        score = score + obstacleScore
        if CLIENT and GetConVar("webswing_obstacle_debug"):GetBool() and obstacleScore > 0 then
            debugoverlay.Sphere(candidate.pos, 5, 0.2, Color(0, 255, 255, 180))
            debugoverlay.Text(candidate.pos, "Thread Needle", 0.2, true)
        end
    end

    return score
end

function SwingTargeting:FindPotentialSwingPoints(weapon)
    local ply = weapon.Owner
    if not IsValid(ply) then return nil end

    local assistStrength = GetConVar("webswing_assist_strength"):GetFloat()
    local momentumFactor = GetConVar("webswing_momentum_preservation"):GetFloat()
    local groundSafety = GetConVar("webswing_ground_safety"):GetFloat()

    local vel = ply:GetVelocity()
    local speed = vel:Length()
    local eyePos = ply:EyePos()
    local groundTrace = util.TraceLine({ start = eyePos, endpos = eyePos - Vector(0, 0, 1000), filter = ply, mask = MASK_SOLID })
    local distToGround = groundTrace.Hit and groundTrace.HitPos:Distance(eyePos) or 1000

    if GetConVar("developer"):GetBool() then
        print("\n[Web Shooter] Starting point search:")
        print(string.format("  Speed: %.1f, Height: %.1f", speed, distToGround))
        print(string.format("  Preferences - Assist: %.1f, Momentum: %.1f, Safety: %.1f", assistStrength, momentumFactor, groundSafety))
    end

    local candidates = self:GatherSwingPointCandidates(weapon)
    if #candidates == 0 then
        if GetConVar("developer"):GetBool() then
            print("[Web Shooter] No candidates found from initial search")
        end
        return nil
    else
        if GetConVar("developer"):GetBool() then
            print(string.format("[Web Shooter] Found %d initial candidates", #candidates))
        end
    end

    local playerState = { velocity = vel, onGround = ply:IsOnGround(), eyePos = eyePos, aimVector = ply:GetAimVector() }
    local bestCandidate = nil
    local bestScore = -1
    local debugScores = {}

    for _, candidate in ipairs(candidates) do
        local finalScore = self:EvaluateSwingCandidate(weapon, candidate, playerState, candidates)
        candidate.score = finalScore
        if GetConVar("developer"):GetBool() then
            table.insert(debugScores, { pos = candidate.pos, type = candidate.type, score = finalScore, height = candidate.pos.z - eyePos.z, dist = candidate.pos:Distance(eyePos) })
        end
        if CLIENT and GetConVar("webswing_show_ai_indicator"):GetBool() then
            local duration = 0.1
            local color = Color(255, 255 * (1 - finalScore), 0, 180)
            debugoverlay.Sphere(candidate.pos, 3, duration, color)
        end
        if finalScore > bestScore then
            bestScore = finalScore
            bestCandidate = candidate
        end
    end

    if GetConVar("developer"):GetBool() then
        table.sort(debugScores, function(a, b) return a.score > b.score end)
        print("[Web Shooter] Top candidates:")
        for i = 1, math.min(5, #debugScores) do
            local c = debugScores[i]
            print(string.format("  %d) Score: %.2f, Dist: %.0f, Height: %.0f, Type: %s", i, c.score, c.dist, c.height, c.type or "?"))
        end
    end

    if not bestCandidate then
        if GetConVar("developer"):GetBool() then
            print("[Web Shooter] No suitable swing point found after evaluation")
        end
        return nil
    end

    if GetConVar("developer"):GetBool() then
        print(string.format("[Web Shooter] Best candidate: Score %.2f, Dist %.0f, Height %.0f, Type %s", bestCandidate.score or -1, bestCandidate.pos:Distance(eyePos), bestCandidate.pos.z - eyePos.z, bestCandidate.type or "?"))
    end

    return { pos = bestCandidate.pos, normal = bestCandidate.normal, entity = bestCandidate.entity, type = bestCandidate.type }
end

return SwingTargeting
