-- Map Analysis System for Web Shooters

local MapAnalysisData = {
	Version = 2, -- Increment this when map analysis logic changes
	Cache = {},
	Persist = function(self, mapName)
		if not file.Exists("webswing", "DATA") then
			file.CreateDir("webswing")
		end
		if not file.Exists("webswing/mapdata", "DATA") then
			file.CreateDir("webswing/mapdata")
		end
		
		local data = {
			version = self.Version,
			analysis = self.Cache[mapName],
			timestamp = os.time()
		}
		
		local success, err = pcall(function()
			file.Write("webswing/mapdata/" .. mapName .. ".txt", util.TableToJSON(data))
		end)
		
		if not success then
			print("[Web Shooters] Failed to save map analysis: " .. tostring(err))
		end
	end,
	Load = function(self, mapName)
		local path = "webswing/mapdata/" .. mapName .. ".txt"
		if not file.Exists(path, "DATA") then return false end
		
		local success, data = pcall(function()
			return util.JSONToTable(file.Read(path, "DATA"))
		end)
		
		if success and data and data.version == self.Version then
			self.Cache[mapName] = data.analysis
			return true
		end
		return false
	end
}

-- Function to analyze the map
function SWEP:AnalyzeMap()
	if SERVER then
		local mapName = game.GetMap()
		
		-- Try to load from memory cache first
		if MapAnalysisData.Cache[mapName] then
			self.MapAnalysis = table.Copy(MapAnalysisData.Cache[mapName])
			self:UpdateMapParameters()
			return
		end
		
		-- Try to load from disk cache
		if MapAnalysisData:Load(mapName) then
			self.MapAnalysis = table.Copy(MapAnalysisData.Cache[mapName])
			self:UpdateMapParameters()
			return
		end
		
		print("[Web Shooters] Analyzing map: " .. mapName)
		
		-- Initialize analysis data with enhanced properties
		self.MapAnalysis = {
			averageHeight = 0,
			buildingDensity = 0,
			openSpaceRatio = 0,
			maxHeight = 0,
			terrainTypes = {
				flat = 0,
				sloped = 0,
				irregular = 0
			},
			verticalCorridors = {
				count = 0,
				averageWidth = 0,
				positions = {}
			},
			landmarks = {
				count = 0,
				positions = {}
			},
			ceilingSpaces = {
				ratio = 0,
				averageHeight = 0
			},
			verticalityScore = 0,
			wallDensity = 0,
			analyzed = false
		}
		
		-- Parameters for analysis
		local scanHeight = 5000
		local scanSteps = 20
		local scanRadius = 10000
		local totalPoints = 0
		local hitPoints = 0
		local heightSum = 0
		local maxHeight = 0
		
		-- Grid scan the map with error handling
		local function performGridScan()
			local terrainData = {}
			local scanResults = {}
			
			for x = -scanRadius, scanRadius, scanRadius/scanSteps do
				for y = -scanRadius, scanRadius, scanRadius/scanSteps do
					local startPos = Vector(x, y, scanHeight)
					local tr = util.TraceLine({
						start = startPos,
						endpos = startPos - Vector(0, 0, scanHeight),
						mask = MASK_SOLID_BRUSHONLY
					})
					
					if tr.Hit then
						hitPoints = hitPoints + 1
						local height = scanHeight - tr.HitPos.z
						heightSum = heightSum + height
						maxHeight = math.max(maxHeight, height)
						
						table.insert(terrainData, {
							pos = tr.HitPos,
							norm = tr.HitNormal,
							height = height
						})
						
						table.insert(scanResults, {
							pos = tr.HitPos,
							hit = true
						})
					else
						table.insert(scanResults, {
							pos = startPos - Vector(0, 0, scanHeight),
							hit = false
						})
					end
					totalPoints = totalPoints + 1
				end
			end
			return hitPoints > 0, terrainData, scanResults
		end
		
		-- Perform grid scan with validation
		local scanSuccess, terrainData, scanResults = performGridScan()
		if not scanSuccess then
			-- Use fallback values if scan fails
			self.MapAnalysis.averageHeight = 500
			self.MapAnalysis.buildingDensity = 0.5
			self.MapAnalysis.openSpaceRatio = 0.5
			self.MapAnalysis.maxHeight = 1000
			self.MapAnalysis.terrainTypes.flat = 0.6
			self.MapAnalysis.terrainTypes.sloped = 0.3
			self.MapAnalysis.terrainTypes.irregular = 0.1
			self.MapAnalysis.verticalityScore = 0.4
			self.MapAnalysis.wallDensity = 0.5
			self.MapAnalysis.analyzed = true
			print("[Web Shooters] Map analysis failed, using fallback values")
			return
		end
		
		-- Calculate map metrics
		self.MapAnalysis.averageHeight = heightSum / hitPoints
		self.MapAnalysis.buildingDensity = hitPoints / totalPoints
		self.MapAnalysis.maxHeight = maxHeight
		
		-- Analyze terrain types
		local flatCount, slopedCount, irregularCount = 0, 0, 0
		for _, data in ipairs(terrainData) do
			if data.norm.z > 0.95 then -- Nearly flat surface
				flatCount = flatCount + 1
			elseif data.norm.z > 0.7 then -- Slightly sloped
				slopedCount = slopedCount + 1
			else -- Irregular or vertical
				irregularCount = irregularCount + 1
			end
		end
		
		local totalSurfaces = flatCount + slopedCount + irregularCount
		if totalSurfaces > 0 then
			self.MapAnalysis.terrainTypes.flat = flatCount / totalSurfaces
			self.MapAnalysis.terrainTypes.sloped = slopedCount / totalSurfaces
			self.MapAnalysis.terrainTypes.irregular = irregularCount / totalSurfaces
		else
			self.MapAnalysis.terrainTypes.flat = 0.6
			self.MapAnalysis.terrainTypes.sloped = 0.3
			self.MapAnalysis.terrainTypes.irregular = 0.1
		end
		
		-- Calculate wall density (vertical surfaces)
		self.MapAnalysis.wallDensity = irregularCount / (totalSurfaces > 0 and totalSurfaces or 1)
		
		-- Calculate verticality score
		self.MapAnalysis.verticalityScore = (self.MapAnalysis.terrainTypes.irregular * 2 + 
											self.MapAnalysis.terrainTypes.sloped) / 3
		
		-- Detect vertical corridors
		local function detectVerticalCorridors()
			local corridors = {}
			local minCorridorHeight = 300
			local corridorCheckRadius = 200
			
			for _, data in ipairs(terrainData) do
				if data.height > minCorridorHeight then
					local isOpenVertical = true
					
					-- Check if there's open space above this point
					for radius = 50, corridorCheckRadius, 50 do
						for angle = 0, 315, 45 do
							local rad = math.rad(angle)
							local checkPos = data.pos + Vector(math.cos(rad) * radius, math.sin(rad) * radius, data.height / 2)
							local tr = util.TraceLine({
								start = data.pos + Vector(0, 0, data.height / 2),
								endpos = checkPos,
								mask = MASK_SOLID_BRUSHONLY
							})
							
							if tr.Hit then
								isOpenVertical = false
								break
							end
						end
						
						if not isOpenVertical then
							break
						end
					end
					
					if isOpenVertical then
						local corridor = {
							position = data.pos,
							height = data.height,
							width = corridorCheckRadius
						}
						
						-- Check if this corridor is unique
						local isUnique = true
						for _, existingCorridor in ipairs(corridors) do
							local dist = data.pos:Distance(existingCorridor.position)
							if dist < corridorCheckRadius * 2 then
								isUnique = false
								break
							end
						end
						
						if isUnique then
							table.insert(corridors, corridor)
						end
					end
				end
			end
			
			return corridors
		end
		
		local corridors = detectVerticalCorridors()
		self.MapAnalysis.verticalCorridors.count = #corridors
		
		if #corridors > 0 then
			local totalWidth = 0
			for _, corridor in ipairs(corridors) do
				totalWidth = totalWidth + corridor.width
				table.insert(self.MapAnalysis.verticalCorridors.positions, {
					x = corridor.position.x,
					y = corridor.position.y,
					z = corridor.position.z,
					width = corridor.width,
					height = corridor.height
				})
			end
			self.MapAnalysis.verticalCorridors.averageWidth = totalWidth / #corridors
		end
		
		-- Detect ceiling spaces (areas where player can crawl upside down)
		local function detectCeilingSpaces()
			local ceilingPoints = 0
			local ceilingHeightSum = 0
			
			for _, data in ipairs(terrainData) do
				-- Check if there's a ceiling above
				local tr = util.TraceLine({
					start = data.pos + Vector(0, 0, 100),
					endpos = data.pos + Vector(0, 0, 500),
					mask = MASK_SOLID_BRUSHONLY
				})
				
				if tr.Hit then
					ceilingPoints = ceilingPoints + 1
					ceilingHeightSum = ceilingHeightSum + (tr.HitPos.z - data.pos.z)
				end
			end
			
			return ceilingPoints, ceilingHeightSum
		end
		
		local ceilingPoints, ceilingHeightSum = detectCeilingSpaces()
		if hitPoints > 0 then
			self.MapAnalysis.ceilingSpaces.ratio = ceilingPoints / hitPoints
		end
		
		if ceilingPoints > 0 then
			self.MapAnalysis.ceilingSpaces.averageHeight = ceilingHeightSum / ceilingPoints
		end
		
		-- Scan for open spaces with improved reliability
		local openSpaces = 0
		local scanPoints = 100
		local validScans = 0
		
		for i = 1, scanPoints do
			local randPos = Vector(
				math.random(-scanRadius, scanRadius),
				math.random(-scanRadius, scanRadius),
				100
			)
			
			-- Ensure random position is valid
			local heightCheck = util.TraceLine({
				start = randPos + Vector(0, 0, 1000),
				endpos = randPos - Vector(0, 0, 1000),
				mask = MASK_SOLID_BRUSHONLY
			})
			
			if heightCheck.Hit then
				validScans = validScans + 1
				local openSpace = true
				for angle = 0, 360, 45 do
					local rad = math.rad(angle)
					local checkPos = randPos + Vector(math.cos(rad) * 500, math.sin(rad) * 500, 0)
					local tr = util.TraceLine({
						start = randPos,
						endpos = checkPos,
						mask = MASK_SOLID_BRUSHONLY
					})
					if tr.Hit then
						openSpace = false
						break
					end
				end
				if openSpace then
					openSpaces = openSpaces + 1
				end
			end
		end
		
		-- Calculate open space ratio only if we have valid scans
		if validScans > 0 then
			self.MapAnalysis.openSpaceRatio = openSpaces / validScans
		else
			self.MapAnalysis.openSpaceRatio = 0.5 -- fallback value
		end
		
		-- Find map landmarks - large distinctive structures
		local function detectLandmarks()
			local landmarks = {}
			local minLandmarkSize = 500
			local landmarkCheckPoints = 50
			
			for i = 1, landmarkCheckPoints do
				local randPos = Vector(
					math.random(-scanRadius, scanRadius),
					math.random(-scanRadius, scanRadius),
					math.random(100, 1000)
				)
				
				local tr = util.TraceLine({
					start = randPos,
					endpos = randPos - Vector(0, 0, 2000),
					mask = MASK_SOLID_BRUSHONLY
				})
				
				if tr.Hit then
					local basePos = tr.HitPos
					local size = 0
					local hitCount = 0
					
					-- Check surrounding area size
					for radius = 100, 1000, 100 do
						local sideHits = 0
						for angle = 0, 315, 45 do
							local rad = math.rad(angle)
							local checkPos = basePos + Vector(math.cos(rad) * radius, math.sin(rad) * radius, 0)
							local sideTr = util.TraceLine({
								start = checkPos + Vector(0, 0, 50),
								endpos = checkPos - Vector(0, 0, 200),
								mask = MASK_SOLID_BRUSHONLY
							})
							
							if sideTr.Hit and math.abs(sideTr.HitPos.z - basePos.z) < 50 then
								sideHits = sideHits + 1
							end
						end
						
						if sideHits >= 6 then -- Most directions hit something at same level
							size = radius
							hitCount = sideHits
						else
							break
						end
					end
					
					if size >= minLandmarkSize then
						local isUnique = true
						for _, landmark in ipairs(landmarks) do
							if basePos:Distance(landmark.position) < size + landmark.size then
								isUnique = false
								break
							end
						end
						
						if isUnique then
							table.insert(landmarks, {
								position = basePos,
								size = size,
								hitRatio = hitCount / 8
							})
						end
					end
				end
			end
			
			return landmarks
		end
		
		local landmarks = detectLandmarks()
		self.MapAnalysis.landmarks.count = #landmarks
		
		for _, landmark in ipairs(landmarks) do
			table.insert(self.MapAnalysis.landmarks.positions, {
				x = landmark.position.x,
				y = landmark.position.y,
				z = landmark.position.z,
				size = landmark.size
			})
		end
		
		-- Store the analysis in both memory and disk cache
		MapAnalysisData.Cache[mapName] = table.Copy(self.MapAnalysis)
		MapAnalysisData:Persist(mapName)
		
		-- Adjust web-shooting parameters based on map analysis
		self:UpdateMapParameters()
		
		self.MapAnalysis.analyzed = true
		print("[Web Shooters] Enhanced Map Analysis Complete:")
		print("  Average Height: " .. math.floor(self.MapAnalysis.averageHeight))
		print("  Building Density: " .. string.format("%.2f", self.MapAnalysis.buildingDensity))
		print("  Open Space Ratio: " .. string.format("%.2f", self.MapAnalysis.openSpaceRatio))
		print("  Max Height: " .. math.floor(self.MapAnalysis.maxHeight))
		print("  Terrain Types: Flat=" .. string.format("%.2f", self.MapAnalysis.terrainTypes.flat) .. 
			  ", Sloped=" .. string.format("%.2f", self.MapAnalysis.terrainTypes.sloped) .. 
			  ", Irregular=" .. string.format("%.2f", self.MapAnalysis.terrainTypes.irregular))
		print("  Verticality Score: " .. string.format("%.2f", self.MapAnalysis.verticalityScore))
		print("  Wall Density: " .. string.format("%.2f", self.MapAnalysis.wallDensity))
		print("  Vertical Corridors: " .. self.MapAnalysis.verticalCorridors.count)
		print("  Landmarks: " .. self.MapAnalysis.landmarks.count)
		print("  Ceiling Space Ratio: " .. string.format("%.2f", self.MapAnalysis.ceilingSpaces.ratio))
	end
end

-- Environment Analysis: scans for 'env_wind' entities to determine wind speed on the map.
function SWEP:AnalyzeEnvironment()
    if SERVER then
        local windEntities = ents.FindByClass("env_wind")
        local totalSpeed = 0
        local count = 0
        for _, ent in ipairs(windEntities) do
            if IsValid(ent) then
                local speed = tonumber(ent:GetKeyValues().m_flWindSpeed) or 0
                totalSpeed = totalSpeed + speed
                count = count + 1
            end
        end
        self.Environment = self.Environment or {}
        if count > 0 then
            self.Environment.windSpeed = totalSpeed / count
            print("[Web Shooters] Environment Analysis: Average Wind Speed =", self.Environment.windSpeed)
        else
            self.Environment.windSpeed = 0
            print("[Web Shooters] Environment Analysis: No wind found, defaulting to 0")
        end
        
        -- Detect light sources for atmospheric analysis
        local lightEntities = ents.FindByClass("light*")
        local skyLightCount = 0
        local indoorLightCount = 0
        
        for _, ent in ipairs(lightEntities) do
            if IsValid(ent) then
                -- Simple heuristic: lights above certain height are likely "sky" lights
                if ent:GetPos().z > self.MapAnalysis.averageHeight * 1.5 then
                    skyLightCount = skyLightCount + 1
                else
                    indoorLightCount = indoorLightCount + 1
                end
            end
        end
        
        self.Environment.lighting = {
            skyLightCount = skyLightCount,
            indoorLightCount = indoorLightCount,
            indoorRatio = indoorLightCount / (skyLightCount + indoorLightCount + 0.001)
        }
        
        print("[Web Shooters] Environment Lighting Analysis:")
        print("  Sky Lights: " .. skyLightCount)
        print("  Indoor Lights: " .. indoorLightCount)
        print("  Indoor Ratio: " .. string.format("%.2f", self.Environment.lighting.indoorRatio))
    end
end

-- Function to update web-shooting parameters based on map analysis
function SWEP:UpdateMapParameters()
    if not self.MapAnalysis then return end
    
    -- Scale web range based on map height and density
    local heightMultiplier = math.Clamp(self.MapAnalysis.averageHeight / 500, 0.8, 1.5)
    local densityMultiplier = math.Clamp(1 - self.MapAnalysis.buildingDensity, 0.7, 1.3)
    
    -- Apply multipliers from ConVars
    local mapHeightMult = GetConVar("webswing_map_height_mult"):GetFloat()
    local mapRangeMult = GetConVar("webswing_map_range_mult"):GetFloat()
    
    -- Calculate final range
    self.Range = self.BaseRange * heightMultiplier * densityMultiplier * mapRangeMult
    
    -- Adjust other parameters as needed
    -- For example, adjust swing speed based on open space
    local openSpaceMultiplier = math.Clamp(self.MapAnalysis.openSpaceRatio * 1.5, 0.8, 1.2)
    self.SwingSpeedMultiplier = openSpaceMultiplier
    
    -- Adjust for vertical traversal in maps with high verticality
    if self.MapAnalysis.verticalityScore > 0.5 then
        self.VerticalBoostMultiplier = 1 + (self.MapAnalysis.verticalityScore - 0.5) * 0.5
    else
        self.VerticalBoostMultiplier = 1
    end
    
    print("[Web Shooters] Map Parameters Updated:")
    print("  Web Range: " .. math.floor(self.Range))
    print("  Swing Speed Multiplier: " .. string.format("%.2f", self.SwingSpeedMultiplier))
    print("  Vertical Boost Multiplier: " .. string.format("%.2f", self.VerticalBoostMultiplier or 1))
end

-- Function to get nearest landmark position for contextual awareness
function MapAnalysisData:GetNearestLandmark(pos, mapAnalysis)
    if not mapAnalysis or not mapAnalysis.landmarks or mapAnalysis.landmarks.count == 0 then
        return nil
    end
    
    local nearestLandmark = nil
    local nearestDist = math.huge
    
    for _, landmark in ipairs(mapAnalysis.landmarks.positions) do
        local landmarkPos = Vector(landmark.x, landmark.y, landmark.z)
        local dist = pos:Distance(landmarkPos)
        
        if dist < nearestDist then
            nearestDist = dist
            nearestLandmark = {
                position = landmarkPos,
                size = landmark.size,
                distance = dist
            }
        end
    end
    
    return nearestLandmark
end

-- Function to check if player is in a vertical corridor
function MapAnalysisData:IsInVerticalCorridor(pos, mapAnalysis)
    if not mapAnalysis or not mapAnalysis.verticalCorridors or mapAnalysis.verticalCorridors.count == 0 then
        return false, nil
    end
    
    for _, corridor in ipairs(mapAnalysis.verticalCorridors.positions) do
        local corridorPos = Vector(corridor.x, corridor.y, corridor.z)
        local horizontalDist = math.sqrt((pos.x - corridorPos.x)^2 + (pos.y - corridorPos.y)^2)
        
        if horizontalDist < corridor.width and 
           pos.z > corridorPos.z and 
           pos.z < corridorPos.z + corridor.height then
            return true, {
                position = corridorPos,
                width = corridor.width,
                height = corridor.height
            }
        end
    end
    
    return false, nil
end

-- Function to determine if player is on a wall
function MapAnalysisData:IsOnWall(player)
    if not IsValid(player) then return false end
    
    local normal = player:GetGroundNormal()
    if normal and normal.z < 0.5 then
        return true, normal
    end
    
    return false, nil
end

-- Function to determine terrain type at a position
function MapAnalysisData:GetTerrainTypeAtPosition(pos)
    local tr = util.TraceLine({
        start = pos + Vector(0, 0, 50),
        endpos = pos - Vector(0, 0, 100),
        mask = MASK_SOLID_BRUSHONLY
    })
    
    if not tr.Hit then
        return "air"
    end
    
    if tr.HitNormal.z > 0.95 then
        return "flat"
    elseif tr.HitNormal.z > 0.7 then
        return "sloped"
    elseif tr.HitNormal.z > 0.3 then
        return "steep"
    else
        return "wall"
    end
end

return MapAnalysisData