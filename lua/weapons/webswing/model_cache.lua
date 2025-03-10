-- Model Cache System for Web Shooters

local ModelInfoCache = {
	Version = 1, -- Version tracking for cache format
	Info = {},
	DiskCache = {},
	
	-- Initialize the cache system
	Initialize = function(self)
		if not file.Exists("webswing", "DATA") then
			file.CreateDir("webswing")
		end
		if not file.Exists("webswing/modelcache", "DATA") then
			file.CreateDir("webswing/modelcache")
		end
		self:LoadFromDisk()
	end,
	
	-- Save cache to disk
	SaveToDisk = function(self)
		if not self.Info then return end
		
		local data = {
			version = self.Version,
			cache = self.Info,
			timestamp = os.time()
		}
		
		local success, err = pcall(function()
			file.Write("webswing/modelcache/models.txt", util.TableToJSON(data))
		end)
		
		if not success then
			print("[Web Shooters] Failed to save model cache: " .. tostring(err))
		end
	end,
	
	-- Load cache from disk
	LoadFromDisk = function(self)
		local path = "webswing/modelcache/models.txt"
		if not file.Exists(path, "DATA") then return false end
		
		local success, data = pcall(function()
			return util.JSONToTable(file.Read(path, "DATA"))
		end)
		
		if success and data and data.version == self.Version then
			self.Info = data.cache or {}
			return true
		end
		return false
	end,
	
	-- Check if model exists in cache
	Exists = function(self, mdl)
		return self.Info[mdl] ~= nil
	end,
	
	-- Validate cached data
	ValidateCache = function(self, mdl, physObjs)
		if not isnumber(physObjs) or physObjs <= 0 then
			return false
		end
		return true
	end,
	
	-- Prepare model info with error handling
	Prepare = function(mdl, ply)
		if not IsValid(ply) then return 15 end -- Return default if player is invalid
		
		-- Try to create test ragdoll
		local success, physObjs = pcall(function()
			local Data = duplicator.CopyEntTable(ply)
			local ragdoll = ents.Create("prop_ragdoll")
			if not IsValid(ragdoll) then error("Failed to create ragdoll") end
			
			duplicator.DoGeneric(ragdoll, Data)
			ragdoll:Spawn()
			
			local count = ragdoll:GetPhysicsObjectCount()
			ragdoll:Remove()
			
			return count
		end)
		
		if success and ModelInfoCache:ValidateCache(mdl, physObjs) then
			ModelInfoCache.Info[mdl] = physObjs
			ModelInfoCache:SaveToDisk()
			return physObjs
		else
			print("[Web Shooters] Warning: Failed to prepare model info for " .. tostring(mdl))
			return 15 -- Fallback to a reasonable default
		end
	end,
	
	-- Get cached info
	Get = function(self, mdl)
		return self.Info[mdl]
	end,
	
	-- Main interface function with error handling
	GimmeDatNumber = function(mdl, ply)
		if not mdl or not IsValid(ply) then
			return 15 -- Fallback default if invalid input
		end
		
		-- Check memory cache first
		if ModelInfoCache:Exists(mdl) then
			local cached = ModelInfoCache:Get(mdl)
			if ModelInfoCache:ValidateCache(mdl, cached) then
				return cached
			end
		end
		
		-- If not in cache or invalid, prepare new data
		return ModelInfoCache.Prepare(mdl, ply)
	end,
	
	-- Clear invalid entries
	CleanupCache = function(self)
		local now = os.time()
		for mdl, data in pairs(self.Info) do
			-- Remove entries older than 30 days
			if now - (data.timestamp or 0) > 2592000 then
				self.Info[mdl] = nil
			end
		end
		self:SaveToDisk()
	end
}

-- Initialize the cache system
timer.Simple(0, function()
	ModelInfoCache:Initialize()
end)

-- Periodically clean up the cache
timer.Create("WebSwing_ModelCache_Cleanup", 300, 0, function()
	ModelInfoCache:CleanupCache()
end)

-- Make the ModelInfoCache available to other files
return ModelInfoCache