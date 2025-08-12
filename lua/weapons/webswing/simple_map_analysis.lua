-- SIMPLIFIED Map Analysis - Actually Works
local SimpleMapAnalysis = {}

-- Cache with proper cleanup
SimpleMapAnalysis.Cache = {}
SimpleMapAnalysis.AnalysisInProgress = {}

-- Only 3 metrics that actually matter for web swinging
local function AnalyzeMapQuick(mapName)
    if SimpleMapAnalysis.Cache[mapName] then
        return SimpleMapAnalysis.Cache[mapName]
    end
    
    if SimpleMapAnalysis.AnalysisInProgress[mapName] then
        return nil -- Let caller handle waiting
    end
    
    SimpleMapAnalysis.AnalysisInProgress[mapName] = true
    
    local startTime = CurTime()
    local results = {
        verticalRange = 0,     -- How much vertical space exists
        wallDensity = 0,       -- How many walls for swinging
        openness = 0,          -- How open/cramped the map feels
        analyzedAt = os.time(),
        analysisTime = 0
    }
    
    -- FAST sampling: Use spawn points + nav areas if available
    local samplePoints = {}
    
    -- Try nav areas first (fastest)
    if navmesh and navmesh.GetAllNavAreas then
        local ok, areas = pcall(navmesh.GetAllNavAreas)
        if ok and areas and #areas > 5 then
            -- Sample every 10th area to keep it fast
            for i = 1, math.min(#areas, 50), math.max(1, math.floor(#areas / 50)) do
                local area = areas[i]
                if area and area.IsValid and area:IsValid() then
                    table.insert(samplePoints, area:GetCenter())
                end
            end
        end
    end
    
    -- Fallback to spawn points
    if #samplePoints < 10 then
        samplePoints = {}
        local spawns = ents.FindByClass("info_player_start")
        for _, spawn in ipairs(spawns) do
            if IsValid(spawn) then
                local pos = spawn:GetPos()
                table.insert(samplePoints, pos)
                -- Add some radial points around spawn
                for angle = 0, 270, 90 do
                    local rad = math.rad(angle)
                    local offset = Vector(math.cos(rad) * 1000, math.sin(rad) * 1000, 0)
                    table.insert(samplePoints, pos + offset)
                end
            end
        end
    end
    
    -- If still no points, use simple grid
    if #samplePoints < 5 then
        for x = -2000, 2000, 1000 do
            for y = -2000, 2000, 1000 do
                table.insert(samplePoints, Vector(x, y, 0))
            end
        end
    end
    
    local heights = {}
    local wallHits = 0
    local totalTraces = 0
    local openSpaces = 0
    
    -- EFFICIENT scanning: One vertical trace per point + 4 horizontal traces
    for i = 1, math.min(#samplePoints, 30) do -- Hard limit for performance
        local point = samplePoints[i]
        
        -- Vertical scan for height range
        local trDown = util.TraceLine({
            start = point + Vector(0, 0, 2000),
            endpos = point + Vector(0, 0, -2000),
            mask = MASK_SOLID_BRUSHONLY
        })
        
        if trDown.Hit then
            table.insert(heights, trDown.HitPos.z)
            local groundPos = trDown.HitPos + Vector(0, 0, 50)
            
            -- Quick wall density check (4 directions only)
            local blocked = 0
            for _, angle in ipairs({0, 90, 180, 270}) do
                local rad = math.rad(angle)
                local dir = Vector(math.cos(rad), math.sin(rad), 0)
                local trWall = util.TraceLine({
                    start = groundPos,
                    endpos = groundPos + dir * 400,
                    mask = MASK_SOLID
                })
                totalTraces = totalTraces + 1
                if trWall.Hit then
                    wallHits = wallHits + 1
                    if trWall.HitNormal.z < 0.3 then -- Vertical wall
                        blocked = blocked + 1
                    end
                end
            end
            
            -- Openness: fewer than 2 blocked directions = open
            if blocked < 2 then
                openSpaces = openSpaces + 1
            end
        end
    end
    
    -- Calculate final metrics
    if #heights > 0 then
        table.sort(heights)
        local minHeight = heights[1]
        local maxHeight = heights[#heights]
        results.verticalRange = math.max(0, maxHeight - minHeight)
    end
    
    results.wallDensity = totalTraces > 0 and (wallHits / totalTraces) or 0.5
    results.openness = #heights > 0 and (openSpaces / #heights) or 0.5
    results.analysisTime = CurTime() - startTime
    
    -- Cache and cleanup
    SimpleMapAnalysis.Cache[mapName] = results
    SimpleMapAnalysis.AnalysisInProgress[mapName] = nil
    
    print(string.format("[WebSwing] Map analysis complete in %.2fs - Vertical: %d, Walls: %.2f, Open: %.2f", 
        results.analysisTime, results.verticalRange, results.wallDensity, results.openness))
    
    return results
end

-- Simple parameter adjustment based on metrics
function SimpleMapAnalysis:UpdateWeaponParameters(weapon)
    local analysis = self.Cache[game.GetMap()]
    if not analysis then return end
    
    -- Adjust web range based on vertical space
    local baseRange = 2000
    local verticalMult = math.Clamp(analysis.verticalRange / 1000, 0.7, 1.5)
    weapon.Range = baseRange * verticalMult
    
    -- Adjust targeting based on wall density
    weapon.TargetingMultiplier = math.Clamp(1 + analysis.wallDensity, 0.8, 1.3)
    
    -- Adjust swing speed based on openness
    weapon.SpeedMultiplier = math.Clamp(0.5 + analysis.openness, 0.7, 1.2)
end

-- Public interface
function SimpleMapAnalysis:GetAnalysis(mapName)
    mapName = mapName or game.GetMap()
    return AnalyzeMapQuick(mapName)
end

function SimpleMapAnalysis:ClearCache()
    self.Cache = {}
    self.AnalysisInProgress = {}
end

return SimpleMapAnalysis
