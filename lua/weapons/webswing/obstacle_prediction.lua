-- Advanced Obstacle Prediction System for Web Swinging
-- Predicts player trajectory during swings to avoid obstacles

local ObstaclePrediction = {}

-- Configuration
ObstaclePrediction.Config = {
    -- Core simulation parameters
    SimulationSteps = 10,           -- Number of steps to simulate (higher = more accurate but more expensive)
    SimulationTime = 0.75,          -- Total time to simulate in seconds
    StiffnessFactor = 0.5,          -- Rope stiffness for simulation (0.0-1.0)
    
    -- Collision detection
    PlayerHullMins = Vector(-16, -16, 0),    -- Player collision hull minimum
    PlayerHullMaxs = Vector(16, 16, 72),     -- Player collision hull maximum
    
    -- Scoring parameters
    ObstructionPenalty = -9999,     -- Score penalty for obstructed paths
    NarrowPassageBonus = 0.3,       -- Bonus for "threading the needle" points
    
    -- Performance optimization
    EnableFullSimulation = true,    -- Enable full physics simulation (disable for performance)
    EnableGeometricArc = true,      -- Enable simplified geometric arc checking
    EnableThreadNeedle = true,      -- Enable detection of narrow passages
    EnableDynamicNudging = true,    -- Enable point adjustment for otherwise good points
    
    -- Debug visualization
    ShowDebugTraces = false,        -- Show debug visualization of traces
    ShowObstructedPaths = false,    -- Show obstructed paths in red
    ShowClearPaths = false          -- Show clear paths in green
}

-- Initialize ConVars
local function CreateConVars()
    CreateClientConVar("webswing_obstacle_prediction", "1", true, false, "Enable obstacle prediction for swing points", 0, 1)
    CreateClientConVar("webswing_obstacle_sim_steps", "10", true, false, "Number of simulation steps for obstacle prediction", 3, 20)
    CreateClientConVar("webswing_obstacle_sim_time", "0.75", true, false, "Simulation time in seconds", 0.2, 2.0)
    CreateClientConVar("webswing_obstacle_debug", "0", true, false, "Show debug visualization for obstacle prediction", 0, 1)
    CreateClientConVar("webswing_obstacle_thread_needle", "1", true, false, "Enable 'thread the needle' detection", 0, 1)
    CreateClientConVar("webswing_obstacle_dynamic_nudging", "1", true, false, "Enable dynamic point nudging", 0, 1)
end
CreateConVars()

-- Update config from ConVars
function ObstaclePrediction:UpdateConfigFromConVars()
    self.Config.EnableFullSimulation = GetConVar("webswing_obstacle_prediction"):GetBool()
    self.Config.SimulationSteps = GetConVar("webswing_obstacle_sim_steps"):GetInt()
    self.Config.SimulationTime = GetConVar("webswing_obstacle_sim_time"):GetFloat()
    self.Config.ShowDebugTraces = GetConVar("webswing_obstacle_debug"):GetBool()
    self.Config.EnableThreadNeedle = GetConVar("webswing_obstacle_thread_needle"):GetBool()
    self.Config.EnableDynamicNudging = GetConVar("webswing_obstacle_dynamic_nudging"):GetBool()
end

-- Core function: Check if a swing trajectory is obstructed
function ObstaclePrediction:IsTrajectoryObstructed(candidatePos, playerPos, playerVel, ropeLength, playerEntity)
    -- Update config from ConVars
    self:UpdateConfigFromConVars()
    
    -- If prediction is disabled, always return false (no obstruction)
    if not self.Config.EnableFullSimulation then
        return false
    end
    
    -- Initialize simulation variables
    local simPlayerPos = Vector(playerPos.x, playerPos.y, playerPos.z)  -- Clone position
    local simPlayerVel = Vector(playerVel.x, playerVel.y, playerVel.z)  -- Clone velocity
    local GRAVITY = GetConVar("sv_gravity"):GetFloat()
    local SIM_FRAMETIME = self.Config.SimulationTime / self.Config.SimulationSteps
    local NUM_STEPS = self.Config.SimulationSteps
    
    -- Get player hull size for collision detection
    local playerMins = self.Config.PlayerHullMins
    local playerMaxs = self.Config.PlayerHullMaxs
    
    -- Perform simulation steps
    for i = 1, NUM_STEPS do
        local prevSimPos = Vector(simPlayerPos.x, simPlayerPos.y, simPlayerPos.z)  -- Clone position
        
        -- Apply gravity
        simPlayerVel.z = simPlayerVel.z - GRAVITY * SIM_FRAMETIME
        
        -- Apply simplified rope constraint (basic pendulum physics)
        local toAttach = candidatePos - simPlayerPos
        local dist = toAttach:Length()
        if dist > ropeLength then
            -- Pull back towards rope length (rope constraint)
            local pullDir = toAttach:GetNormalized()
            local correctionForce = pullDir * (dist - ropeLength) * self.Config.StiffnessFactor
            simPlayerVel = simPlayerVel + correctionForce * SIM_FRAMETIME
        end
        
        -- Update position
        simPlayerPos = simPlayerPos + simPlayerVel * SIM_FRAMETIME
        
        -- Check for collisions using hull trace
        local tr = util.TraceHull({
            start = prevSimPos,
            endpos = simPlayerPos,
            mins = playerMins,
            maxs = playerMaxs,
            filter = playerEntity,
            mask = MASK_SOLID_BRUSHONLY  -- Only check against world brushes
        })
        
        -- If we hit something, the path is obstructed
        if tr.Hit and tr.Entity ~= game.GetWorld() then
            -- Optional: check if the hit entity is the one we are attached to
            -- if IsValid(candidate.entity) and tr.Entity == candidate.entity then continue end
            
            -- Debug visualization
            if self.Config.ShowDebugTraces and self.Config.ShowObstructedPaths then
                debugoverlay.Line(prevSimPos, simPlayerPos, 2, Color(255, 0, 0), true)
                debugoverlay.Sphere(tr.HitPos, 5, 2, Color(255, 0, 0), true)
            end
            
            return true  -- Obstructed
        end
        
        -- Debug visualization for clear paths
        if self.Config.ShowDebugTraces and self.Config.ShowClearPaths then
            debugoverlay.Line(prevSimPos, simPlayerPos, 0.1, Color(0, 255, 0), true)
        end
    end
    
    return false  -- Not obstructed
end

-- Simplified geometric arc approximation (less CPU intensive)
function ObstaclePrediction:CheckGeometricArc(candidatePos, playerPos, playerVel, ropeLength, playerEntity)
    -- If geometric arc checking is disabled, return false (no obstruction)
    if not self.Config.EnableGeometricArc then
        return false
    end
    
    -- Calculate the lowest point of the swing (bottom of the arc)
    local lowestPoint = Vector(
        candidatePos.x,
        candidatePos.y,
        candidatePos.z - ropeLength
    )
    
    -- Create a simple 3-segment arc
    local segments = {
        { start = playerPos, endpos = Vector(
            (playerPos.x + lowestPoint.x) / 2,
            (playerPos.y + lowestPoint.y) / 2,
            (playerPos.z + lowestPoint.z) / 2
        )},
        { start = Vector(
            (playerPos.x + lowestPoint.x) / 2,
            (playerPos.y + lowestPoint.y) / 2,
            (playerPos.z + lowestPoint.z) / 2
        ), endpos = lowestPoint },
        { start = lowestPoint, endpos = Vector(
            lowestPoint.x + playerVel.x * 0.5,
            lowestPoint.y + playerVel.y * 0.5,
            lowestPoint.z + math.abs(playerVel.z) * 0.3
        )}
    }
    
    -- Check each segment for collisions
    for _, segment in ipairs(segments) do
        local tr = util.TraceHull({
            start = segment.start,
            endpos = segment.endpos,
            mins = self.Config.PlayerHullMins,
            maxs = self.Config.PlayerHullMaxs,
            filter = playerEntity,
            mask = MASK_SOLID_BRUSHONLY
        })
        
        if tr.Hit then
            -- Debug visualization
            if self.Config.ShowDebugTraces then
                debugoverlay.Line(segment.start, segment.endpos, 2, Color(255, 0, 0), true)
                debugoverlay.Sphere(tr.HitPos, 5, 2, Color(255, 0, 0), true)
            end
            
            return true  -- Obstructed
        elseif self.Config.ShowDebugTraces then
            debugoverlay.Line(segment.start, segment.endpos, 0.1, Color(0, 255, 0), true)
        end
    end
    
    return false  -- Not obstructed
end

-- Detect "thread the needle" opportunities (narrow passages)
function ObstaclePrediction:DetectThreadNeedle(candidatePos, playerPos, playerVel, ropeLength, playerEntity)
    -- If thread needle detection is disabled, return 0 (no bonus)
    if not self.Config.EnableThreadNeedle then
        return 0
    end
    
    -- Use the geometric arc to check for narrow passages
    local segments = {
        { start = playerPos, endpos = Vector(
            (playerPos.x + candidatePos.x) / 2,
            (playerPos.y + candidatePos.y) / 2,
            (playerPos.z + candidatePos.z) / 2
        )}
    }
    
    -- Check for obstacles near the path but not directly in it
    local isNarrowPassage = false
    local narrowPassageCount = 0
    
    for _, segment in ipairs(segments) do
        -- First check if the path itself is clear
        local pathTrace = util.TraceHull({
            start = segment.start,
            endpos = segment.endpos,
            mins = self.Config.PlayerHullMins,
            maxs = self.Config.PlayerHullMaxs,
            filter = playerEntity,
            mask = MASK_SOLID_BRUSHONLY
        })
        
        -- If the path is obstructed, it's not a thread-the-needle opportunity
        if pathTrace.Hit then
            return 0
        end
        
        -- Check perpendicular to the path for nearby obstacles
        local pathDir = (segment.endpos - segment.start):GetNormalized()
        local rightDir = pathDir:Cross(Vector(0, 0, 1)):GetNormalized()
        
        -- Check both sides
        local sideTraces = {
            util.TraceLine({
                start = (segment.start + segment.endpos) / 2,
                endpos = (segment.start + segment.endpos) / 2 + rightDir * 100,
                filter = playerEntity,
                mask = MASK_SOLID_BRUSHONLY
            }),
            util.TraceLine({
                start = (segment.start + segment.endpos) / 2,
                endpos = (segment.start + segment.endpos) / 2 - rightDir * 100,
                filter = playerEntity,
                mask = MASK_SOLID_BRUSHONLY
            })
        }
        
        -- Count how many sides have nearby obstacles
        local nearbyObstacles = 0
        for _, tr in ipairs(sideTraces) do
            if tr.Hit and tr.Fraction < 0.8 then
                nearbyObstacles = nearbyObstacles + 1
                
                -- Debug visualization
                if self.Config.ShowDebugTraces then
                    debugoverlay.Line(tr.StartPos, tr.HitPos, 2, Color(255, 0, 255), true)
                    debugoverlay.Sphere(tr.HitPos, 3, 2, Color(255, 0, 255), true)
                end
            end
        end
        
        -- If obstacles on both sides, it's a narrow passage
        if nearbyObstacles >= 2 then
            narrowPassageCount = narrowPassageCount + 1
            isNarrowPassage = true
        end
    end
    
    -- Return bonus score for thread-the-needle opportunities
    return isNarrowPassage and self.Config.NarrowPassageBonus or 0
end

-- Try to nudge a point slightly to avoid immediate obstacles
function ObstaclePrediction:TryDynamicPointNudging(candidate, playerPos, playerVel, ropeLength, playerEntity)
    -- If dynamic nudging is disabled, return the original point
    if not self.Config.EnableDynamicNudging then
        return candidate
    end
    
    -- Only try nudging if the original point is obstructed
    if not self:IsTrajectoryObstructed(candidate.pos, playerPos, playerVel, ropeLength, playerEntity) then
        return candidate
    end
    
    -- Try nudging in several directions
    local nudgeDirections = {
        Vector(0, 0, 30),    -- Up
        Vector(30, 0, 0),    -- Right
        Vector(-30, 0, 0),   -- Left
        Vector(0, 30, 0),    -- Forward
        Vector(0, -30, 0)    -- Back
    }
    
    for _, nudgeDir in ipairs(nudgeDirections) do
        -- Create nudged point
        local nudgedPos = candidate.pos + nudgeDir
        
        -- Check if the nudged point is valid (not in the void)
        local validityCheck = util.TraceLine({
            start = nudgedPos,
            endpos = nudgedPos + Vector(0, 0, -50),
            filter = playerEntity,
            mask = MASK_SOLID_BRUSHONLY
        })
        
        -- Skip if the nudged point is floating in the void
        if not validityCheck.Hit then
            continue
        end
        
        -- Check if the nudged trajectory is clear
        if not self:IsTrajectoryObstructed(nudgedPos, playerPos, playerVel, ropeLength, playerEntity) then
            -- Create a new candidate with the nudged position
            local nudgedCandidate = table.Copy(candidate)
            nudgedCandidate.pos = nudgedPos
            nudgedCandidate.isNudged = true
            
            -- Debug visualization
            if self.Config.ShowDebugTraces then
                debugoverlay.Line(candidate.pos, nudgedPos, 2, Color(0, 255, 255), true)
                debugoverlay.Sphere(nudgedPos, 5, 2, Color(0, 255, 255), true)
            end
            
            return nudgedCandidate
        end
    end
    
    -- If no nudged position works, return the original
    return candidate
end

-- Main function to evaluate obstacle avoidance for a swing candidate
function ObstaclePrediction:EvaluateObstacleAvoidance(candidate, playerPos, playerVel, playerEntity)
    -- Update config from ConVars
    self:UpdateConfigFromConVars()
    
    -- Calculate rope length (distance from player to candidate)
    local ropeLength = candidate.pos:Distance(playerPos)
    
    -- Try dynamic point nudging if enabled
    if self.Config.EnableDynamicNudging then
        candidate = self:TryDynamicPointNudging(candidate, playerPos, playerVel, ropeLength, playerEntity)
    end
    
    -- Check if trajectory is obstructed using full simulation
    local isObstructed = self:IsTrajectoryObstructed(candidate.pos, playerPos, playerVel, ropeLength, playerEntity)
    
    -- If not obstructed by full simulation, also check geometric arc as a backup
    if not isObstructed and self.Config.EnableGeometricArc then
        isObstructed = self:CheckGeometricArc(candidate.pos, playerPos, playerVel, ropeLength, playerEntity)
    end
    
    -- If obstructed, apply penalty
    if isObstructed then
        return self.Config.ObstructionPenalty
    end
    
    -- Check for thread-the-needle opportunities
    local threadNeedleBonus = self:DetectThreadNeedle(candidate.pos, playerPos, playerVel, ropeLength, playerEntity)
    
    -- Return the final score (0 if no obstruction, plus any thread-needle bonus)
    return threadNeedleBonus
end

return ObstaclePrediction
