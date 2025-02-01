-- Initialize shared ConVars
if SERVER then
	-- Server-side ConVars
	CreateConVar("webswing_swing_speed", "800", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Base swing force when using web swing", 1, 90000)
	CreateConVar("webswing_manual_mode", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Use manual web-swing mode (old style)", 0, 1)
	CreateConVar("webswing_enable_fall_damage", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable fall damage when using WebSwing", 0, 1)
	CreateConVar("webswing_rope_material", "cable/xbeam", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Material used for the web rope")
	CreateConVar("webswing_map_height_mult", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Multiplier for optimal swing height")
	CreateConVar("webswing_map_range_mult", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Multiplier for web range")
	CreateConVar("webswing_rope_alpha", "255", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Alpha transparency of the web rope (0-255)", 0, 255)
	CreateConVar("webswing_rope_color_r", "255", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Red component of web rope color (0-255)", 0, 255)
	CreateConVar("webswing_rope_color_g", "255", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Green component of web rope color (0-255)", 0, 255)
	CreateConVar("webswing_rope_color_b", "255", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Blue component of web rope color (0-255)", 0, 255)
	CreateConVar("webswing_momentum_preservation", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How much momentum to preserve during swings (0-2)", 0, 2)
	CreateConVar("webswing_ground_safety", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How much to prioritize avoiding ground collision (0-2)", 0, 2)
	CreateConVar("webswing_assist_strength", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How strong the swing point selection assist should be (0-2)", 0, 2)
	CreateConVar("webswing_web_length", "1500", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Maximum allowed web length", 300, 3000)
	CreateConVar("webswing_swing_curve", "1.0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How pronounced the swing arc should be (0-2)", 0, 2)
	CreateConVar("webswing_keep_webs", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Keep webs for 30 seconds after detaching", 0, 1)
	CreateConVar("webswing_gravity_reduction", "0.5", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How much to reduce gravity during swings (0-1)", 0, 1)
	CreateConVar("webswing_gravity_speed_factor", "1.0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How much speed affects gravity reduction (0-2)", 0, 2)
	CreateConVar("webswing_gravity_angle_factor", "1.0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How much rope angle affects gravity reduction (0-2)", 0, 2)
	-- Add new ConVars for dynamic rope length
	CreateConVar("webswing_dynamic_length", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable dynamic rope length adjustment", 0, 1)
	CreateConVar("webswing_length_angle_factor", "1.0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How much swing angle affects rope length (0-2)", 0, 2)
	CreateConVar("webswing_min_length_ratio", "0.5", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Minimum rope length as ratio of initial length (0.1-1)", 0.1, 1)
	CreateConVar("webswing_length_smoothing", "0.8", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Smoothing factor for rope length changes (0-1)", 0, 1)
	CreateConVar("webswing_max_length_change", "100", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Maximum length change per second", 10, 500)
	-- Add new ConVar for sky web attachment
	CreateConVar("webswing_allow_sky_attach", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Allow attaching webs to the sky", 0, 1)
	CreateConVar("webswing_sky_height", "1000", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Height for sky web attachment points", 300, 3000)

	-- Add network strings
	util.AddNetworkString("WebSwing_SetRopeMaterial")
	util.AddNetworkString("WebSwing_ToggleManualMode")
	util.AddNetworkString("WebSwing_SetSoundSet")

	-- Server init
	util.AddNetworkString("WebSwing_NoclipSpeed")
end

if CLIENT then
	-- Client-side ConVars
	CreateClientConVar("webswing_manual_mode", "0", true, true, "Use manual web-swing mode (old style)")
	CreateClientConVar("webswing_show_ai_indicator", "0", true, false, "Show AI swing point indicator")
	CreateClientConVar("webswing_momentum_preservation", "1", true, true, "How much momentum to preserve during swings (0-2)")
	CreateClientConVar("webswing_ground_safety", "1", true, true, "How much to prioritize avoiding ground collision (0-2)")
	CreateClientConVar("webswing_assist_strength", "1", true, true, "How strong the swing point selection assist should be (0-2)")
	CreateClientConVar("webswing_web_length", "1500", true, true, "Maximum allowed web length")
	CreateClientConVar("webswing_swing_curve", "1.0", true, true, "How pronounced the swing arc should be (0-2)")
	CreateClientConVar("webswing_keep_webs", "1", true, true, "Keep webs for 30 seconds after detaching")
	CreateClientConVar("webswing_gravity_reduction", "0.5", true, true, "How much to reduce gravity during swings (0-1)")
	CreateClientConVar("webswing_gravity_speed_factor", "1.0", true, true, "How much speed affects gravity reduction (0-2)")
	CreateClientConVar("webswing_gravity_angle_factor", "1.0", true, true, "How much rope angle affects gravity reduction (0-2)")
	CreateClientConVar("webswing_dynamic_length", "1", true, true, "Enable dynamic rope length adjustment")
	CreateClientConVar("webswing_length_angle_factor", "1.0", true, true, "How much swing angle affects rope length (0-2)")
	CreateClientConVar("webswing_length_speed_factor", "1.0", true, true, "How much speed affects rope length (0-2)")
	CreateClientConVar("webswing_min_length_ratio", "0.5", true, true, "Minimum rope length as ratio of initial length (0.1-1)")
	CreateClientConVar("webswing_allow_sky_attach", "0", true, true, "Allow attaching webs to the sky")
	CreateClientConVar("webswing_sky_height", "1000", true, true, "Height for sky web attachment points")
end

-- Ensure ConVars are accessible
local function GetSwingSpeed()
	return GetConVar("webswing_swing_speed"):GetFloat()
end

local function IsManualMode()
	return GetConVar("webswing_manual_mode"):GetBool()
end

local function GetMomentumPreservation()
	return GetConVar("webswing_momentum_preservation"):GetFloat()
end

local function GetGroundSafety()
	return GetConVar("webswing_ground_safety"):GetFloat()
end

local function GetAssistStrength()
	return GetConVar("webswing_assist_strength"):GetFloat()
end

local function GetWebLength()
	return GetConVar("webswing_web_length"):GetFloat()
end

local function GetSwingCurve()
	return GetConVar("webswing_swing_curve"):GetFloat()
end

SWEP.STANDARD_RAGDOLL_MASS = 1  -- Standard mass for ragdoll physics objects

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
	Exists = function(mdl)
		return ModelInfoCache.Info[mdl] ~= nil
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
	Get = function(mdl)
		return ModelInfoCache.Info[mdl]
	end,
	
	-- Main interface function with error handling
	GimmeDatNumber = function(mdl, ply)
		if not mdl or not IsValid(ply) then
			return 15 -- Fallback default if invalid input
		end
		
		-- Check memory cache first
		if ModelInfoCache.Exists(mdl) then
			local cached = ModelInfoCache.Get(mdl)
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

local SavedWeapons
SavedWeapons = {
	Stored = {},
	Store = function(ply)
		local tbl = {}
		local active = ply:GetActiveWeapon()
		local weps = ply:GetWeapons()
		for _,wep in pairs(weps) do
			local w = {}
			w.PrimaryAmmoType = wep:GetPrimaryAmmoType()
			w.SecondaryAmmoType = wep:GetSecondaryAmmoType()
			w.PrimaryAmmo = ply:GetAmmoCount(w.PrimaryAmmoType)
			w.SecondaryAmmo = ply:GetAmmoCount(w.SecondaryAmmoType)
			w.Clip1 = wep:Clip1()
			w.Clip2 = wep:Clip2()
			local class = wep:GetClass()
			tbl[class] = w
			if class=="webswing" then
				tbl.roper_bone = wep.TargetPhysObj
			end
		end
		tbl.equipped = active:GetClass()
		tbl.ply_data = {
			hp = ply:Health(),
			maxhp = ply:GetMaxHealth(),
			armor = ply:Armor(),
			gravity = ply:GetGravity(),
			jump = ply:GetJumpPower(),
			walk = ply:GetWalkSpeed(),
			run = ply:GetRunSpeed(),
		}
		--print("Saved weapons as")
		--PrintTable(tbl)
		--print("-----")
		SavedWeapons.Stored[ply] = tbl
	end,
	Retrieve = function(ply)
		local old = SavedWeapons.Stored[ply]
		if not old then return end
		ply:StripWeapons()
		local toequip
		local roper_bone,roper_wep
		ply:SetSuppressPickupNotices(true)
		for wepclass,wepdata in pairs(old) do
			--print("Restoring",wepclass)
			if wepclass=="equipped" then
				toequip = wepdata
				continue
			end
			if wepclass=="roper_bone" then
				roper_bone = wepdata
				continue
			end
			if wepclass=="ply_data" then
				ply:SetHealth( wepdata.hp )
				ply:SetMaxHealth( wepdata.maxhp )
				ply:SetArmor( wepdata.armor )
				ply:SetGravity( wepdata.gravity )
				ply:SetJumpPower( wepdata.jump )
				ply:SetWalkSpeed( wepdata.walk )
				ply:SetRunSpeed( wepdata.run )
				continue
			end
			--PrintTable(wepdata)
			local new = ply:Give(wepclass,false)
			if wepdata.Clip1 ~= -1 then new:SetClip1(wepdata.Clip1) end
			if wepdata.Clip2 ~= -1 then new:SetClip2(wepdata.Clip2) end
			ply:SetAmmo( wepdata.PrimaryAmmo, wepdata.PrimaryAmmoType )
			ply:SetAmmo( wepdata.SecondaryAmmo, wepdata.SecondaryAmmoType )
			if wepclass=="webswing" then
				roper_wep = new
			end
		end
		ply:SetSuppressPickupNotices(false)
		ply:SelectWeapon(toequip)
		if roper_wep then
			--print("Make sure the client knows we had this selected ->", roper_bone)
			roper_wep.TargetPhysObj = roper_bone or 0
			roper_wep:ReceiveCurObj()
		end
		SavedWeapons.Stored[ply] = nil
	end
}

SWEP.Author			= "MarioSpaghet"
SWEP.Purpose		= "Rope yourself to stuff.\nLeft click = rope.\nRight click = unrope.\nReload = change target bone."
SWEP.Category = "Spider-Man"

SWEP.Spawnable			= true
SWEP.UseHands			= true

SWEP.HoldType = "normal"
SWEP.ViewModelFOV = 85.433070866142
SWEP.ViewModelFlip = false
SWEP.ViewModel = "models/weapons/c_arms.mdl"
SWEP.WorldModel = ""
SWEP.ShowViewModel = true
SWEP.ShowWorldModel = false
SWEP.ViewModelBoneMods = {
	["ValveBiped.Crossbow_base"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(-30, -30, -30), angle = Angle(0, 0, 0) }
}

SWEP.Primary.ClipSize		= -1
SWEP.Primary.DefaultClip	= -1
SWEP.Primary.Automatic		= false
SWEP.Primary.Ammo			= "none"

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= false
SWEP.Secondary.Ammo			= "none"

SWEP.Weight				= 5
SWEP.AutoSwitchTo		= false
SWEP.AutoSwitchFrom		= false

SWEP.PrintName			= "Spider-Man Web-Shooters"
SWEP.Slot				= 4
SWEP.SlotPos			= 6
SWEP.DrawAmmo			= false
SWEP.DrawCrosshair		= true

SWEP.Roping = false
SWEP.RagdollActive = false
SWEP.Ragdoll = nil
SWEP.Range = 2000
SWEP.RunForceMultiplier = 1.5
SWEP.DampingFactor = 50

local ShootSound = Sound( "webshoot/webshoot" )

local quadBorderColor = Color(255,255,255,255)
local quadInnerColor = Color(0,0,0,255)
local quadDraw = function(weapon)
	surface.SetDrawColor(quadInnerColor)
	surface.DrawRect(-50, -50, 100, 100)
	surface.SetDrawColor(quadBorderColor)
	surface.DrawOutlinedRect(-50, -50, 100, 100)
	draw.SimpleText("Bone: "..weapon.TargetPhysObj.."/"..weapon.PhysObjLoopLimit, "default", 0, -10, Color(255,0,0,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(weapon.BoneName or "", "default", 0, 10, Color(255,0,0,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- Add this near the top of the file with other global variables
local MapAnalysisData = {
	Version = 1, -- Increment this when map analysis logic changes
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
		
		-- Initialize analysis data
		self.MapAnalysis = {
			averageHeight = 0,
			buildingDensity = 0,
			openSpaceRatio = 0,
			maxHeight = 0,
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
						heightSum = heightSum + (scanHeight - tr.HitPos.z)
						maxHeight = math.max(maxHeight, scanHeight - tr.HitPos.z)
					end
					totalPoints = totalPoints + 1
				end
			end
			return hitPoints > 0
		end
		
		-- Perform grid scan with validation
		local scanSuccess = performGridScan()
		if not scanSuccess then
			-- Use fallback values if scan fails
			self.MapAnalysis.averageHeight = 500
			self.MapAnalysis.buildingDensity = 0.5
			self.MapAnalysis.openSpaceRatio = 0.5
			self.MapAnalysis.maxHeight = 1000
			self.MapAnalysis.analyzed = true
			print("[Web Shooters] Map analysis failed, using fallback values")
			return
		end
		
		-- Calculate map metrics
		self.MapAnalysis.averageHeight = heightSum / hitPoints
		self.MapAnalysis.buildingDensity = hitPoints / totalPoints
		self.MapAnalysis.maxHeight = maxHeight
		
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
		
		-- Store the analysis in both memory and disk cache
		MapAnalysisData.Cache[mapName] = table.Copy(self.MapAnalysis)
		MapAnalysisData:Persist(mapName)
		
		-- Adjust web-shooting parameters based on map analysis
		self:UpdateMapParameters()
		
		self.MapAnalysis.analyzed = true
		print("[Web Shooters] Map Analysis Complete:")
		print("  Average Height: " .. math.floor(self.MapAnalysis.averageHeight))
		print("  Building Density: " .. string.format("%.2f", self.MapAnalysis.buildingDensity))
		print("  Open Space Ratio: " .. string.format("%.2f", self.MapAnalysis.openSpaceRatio))
		print("  Max Height: " .. math.floor(self.MapAnalysis.maxHeight))
	end
end

-- First, ensure SWEP is initialized
SWEP = SWEP or {}

-- Move the WebSoundCount variables to be properties of SWEP
SWEP.WebSoundCooldown = 0.1  -- Minimum time between sounds
SWEP.WebSoundResetTime = 1.0  -- Time before sound count resets
SWEP.MaxWebSoundCount = 3     -- Number of rapid sounds before fatigue kicks in

-- Initialize function should be defined after SWEP is declared
function SWEP:Initialize()
	-- Initialize MapAnalysis table
	self.MapAnalysis = {
		averageHeight = 500,  -- Default height
		buildingDensity = 0.5,  -- Default density
		openSpaceRatio = 0.5,  -- Default open space ratio
		analyzed = false
	}
	
	-- Initialize sound variables
	self.LastWebSoundTime = 0
	self.WebSoundCount = 0
	
	if SERVER and not self.NetworkSetup then
		self.NetworkSetup = true
		net.Receive("WebSwing_SetSoundSet", function(len, ply)
			if not IsValid(ply) then return end
			local soundSet = net.ReadString()
			if self.SoundSets and self.SoundSets[soundSet] then
				ply:ConCommand("webswing_sound_set " .. soundSet)
			end
		end)
	end
	
	-- Run map analysis if on server
	if SERVER then
		self:AnalyzeMap()
	end
	
	-- Rest of your initialize code...
	if self.SetWeaponHoldType then 
		self:SetWeaponHoldType(self.HoldType) 
	end

	self.Roping = false
	self.RagdollActive = false
	self.Ragdoll = nil
	
	self.BoneName = ""
	self.LastTargetNameUpdate = -1

	-- Construction Kit code
	if CLIENT then
		-- Create a new table for every weapon instance
		self.VElements = table.FullCopy(self.VElements)
		self.WElements = table.FullCopy(self.WElements)
		self.ViewModelBoneMods = table.FullCopy(self.ViewModelBoneMods)

		self:CreateModels(self.VElements) -- create viewmodels
		self:CreateModels(self.WElements) -- create worldmodels
		
		-- init view model bone build function
		if IsValid(self.Owner) then
			local vm = self.Owner.GetViewModel and self.Owner:GetViewModel() or NULL
			if IsValid(vm) then
				self:ResetBonePositions(vm)
				
				-- Init viewmodel visibility
				if (self.ShowViewModel == nil or self.ShowViewModel) then
					vm:SetColor(Color(255,255,255,255))
				else
					vm:SetColor(Color(255,255,255,1))
					vm:SetMaterial("Debug/hsv")            
				end
			end
		end
	end

	-- Initialize camera variables
	self.CameraVars = {
		targetDistance = 75,
		currentDistance = 75,
		minDistance = 50,
		maxDistance = 200,
		lastAngles = Angle(0, 0, 0),
		currentAngles = Angle(0, 0, 0),
		tiltAngle = 0,
		maxTilt = 15,
		smoothSpeed = 10
	}
	
	-- Initialize camera transition state
	self.TransitioningFromSwing = false
	self.CameraTransitionStart = 0
	
	-- Register camera hook once
	if CLIENT then
		hook.Add("CalcView", "SpiderManView", function(ply, pos, angles, fov)
			// ... move camera code here ...
		end)
	end
end

--	Reload changes our bone number
SWEP.DelayChangeBone = 0
SWEP.ChangeBone_Delay = 0.2
SWEP.PhysObjLoopLimit = 15
SWEP.TargetPhysObj = 11
function SWEP:Reload()
	if SERVER then
		if self.DelayChangeBone<CurTime() then
			self.DelayChangeBone = CurTime()+self.ChangeBone_Delay
			self:ConfigureMaxObjs()
			self.TargetPhysObj = self.TargetPhysObj+0
			if self.TargetPhysObj>=self.PhysObjLoopLimit then
				--print(self.TargetPhysObj.." is >= "..self.PhysObjLoopLimit)
				self.TargetPhysObj = 0
			end
			self:CallOnClient('ReceiveCurObj', tostring(self.TargetPhysObj))
			--print("Current target bone = ", self.TargetPhysObj, "[Todo: Show this on the HUD]")
		end
	end
end

function SWEP:ConfigureMaxObjs(answer)
	if SERVER then
		local physObjs = ModelInfoCache.GimmeDatNumber( self.Owner:GetModel(), self.Owner )
		--print("Cached answer:",physObjs)
		self.PhysObjLoopLimit = physObjs
		self:CallOnClient('ConfigureMaxObjs', tostring(physObjs))
		return
	end
	--client
	--print("SHIT LOOK AT THIS >>> ",tonumber(answer))
	self.PhysObjLoopLimit = tonumber(answer)
	--print("The server says our ragdoll has this many physbones >>> ",self.PhysObjLoopLimit)
end

function SWEP:ReceiveCurObj(answer) --used to keep our state after unragdolling
	if SERVER then
		--print("Synch the value to our client")
		timer.Simple(0.1, function()
			if IsValid(self) then
				self:CallOnClient('ReceiveCurObj', tostring(self.TargetPhysObj))
			end
		end)
		return
	end
	--client
	--print("RESTORING PHYSOBJ OPTION >>> ",tonumber(answer))
	self.TargetPhysObj = tonumber(answer)
end

function SWEP:OnRemove(webswing)
	hook.Remove( "CalcView", "name" )
    return true
end

--   Think does nothing
function SWEP:Think()
    if !self.Owner:IsOnGround() then
        self.Owner:SetAllowFullRotation(true)
    elseif self.Owner:IsOnGround() then
        self.Owner:SetAllowFullRotation(false)
    end

-- Remove the existing CalcView hook
hook.Remove("CalcView", "SpiderManView")

-- Initialize camera variables
local function InitializeCamera(weapon)
    weapon.CameraVars = {
        targetDistance = 150,
        currentDistance = 150,
        minDistance = 150,
        maxDistance = 200,
        lastPos = Vector(0, 0, 0),
        currentAngles = Angle(0, 0, 0),
        tiltAngle = 0,
        maxTilt = 15,
        smoothSpeed = 5
    }
    return weapon.CameraVars
end

-- Add smooth camera transition
hook.Add("CalcView", "SpiderManView", function(ply, pos, angles, fov)
    local weapon = ply:GetActiveWeapon()
    if !IsValid(weapon) or weapon:GetClass() != "webswing" then return end
    
    -- Initialize or get camera variables
    local cv = weapon.CameraVars or InitializeCamera(weapon)
    
    -- Initialize vectors if they don't exist
    cv.lastPos = cv.lastPos or pos
    cv.currentAngles = cv.currentAngles or angles
    cv.tiltAngle = cv.tiltAngle or 0
    
    -- Enhance smooth camera transition upon detachment
    if weapon.TransitioningFromSwing then
        if not cv.transitionStartTime then
            cv.transitionStartTime = CurTime()
            cv.transitionStartAngles = angles
            -- Define desired end angles (reset pitch and roll)
            cv.transitionTargetAngles = Angle(0, angles.y, 0)
        end
        
        local transitionDuration = 1.0 -- Increased from 0.5 for a smoother transition
        local elapsed = CurTime() - cv.transitionStartTime
        local progress = math.Clamp(elapsed / transitionDuration, 0, 1)
        
        -- Interpolate angles only for smooth transition
        local newAngles = LerpAngle(progress, cv.transitionStartAngles, cv.transitionTargetAngles)
        
        angles = newAngles
        
        -- End transition
        if progress >= 1 then
            weapon.TransitioningFromSwing = false
            cv.transitionStartTime = nil
            cv.transitionStartAngles = nil
            cv.transitionTargetAngles = nil
        end
    end
    
    -- Smooth position transition with safety check
    if pos and cv.lastPos then
        cv.lastPos = LerpVector(FrameTime() * 10, cv.lastPos, pos)
    else
        cv.lastPos = pos
    end
    
    -- Calculate smooth angles only during active swinging
    if weapon.RagdollActive then
        cv.currentAngles = LerpAngle(FrameTime() * 15, cv.currentAngles, angles)
        
        -- Calculate tilt during swing
        local velocity = ply:GetVelocity()
        local rightDot = velocity:Dot(angles:Right())
        local targetTilt = -rightDot * 0.01
        targetTilt = math.Clamp(targetTilt, -cv.maxTilt, cv.maxTilt)
        cv.tiltAngle = Lerp(FrameTime() * 5, cv.tiltAngle, targetTilt)
    else
        -- When not swinging, quickly reset tilt
        cv.tiltAngle = Lerp(FrameTime() * 30, cv.tiltAngle, 0)
        if not weapon.TransitioningFromSwing then
            cv.currentAngles = angles
        end
    end
    
    -- Apply final angles with safety check
    local finalAngles = weapon.TransitioningFromSwing and angles or Angle(cv.currentAngles.p, cv.currentAngles.y, cv.tiltAngle)
    
    -- Calculate camera position
    local view = {}
    view.origin = cv.lastPos - (finalAngles:Forward() * cv.targetDistance) + (finalAngles:Up() * 5)
    view.angles = finalAngles
    view.fov = fov
    view.drawviewer = true
    
    -- Collision check
    local traceData = {
        start = cv.lastPos,
        endpos = view.origin,
        filter = ply,
        mask = MASK_SOLID
    }
    
    local trace = util.TraceLine(traceData)
    if trace.Hit then
        local hitDist = cv.lastPos:Distance(trace.HitPos)
        hitDist = math.max(hitDist, cv.minDistance)
        view.origin = cv.lastPos - (finalAngles:Forward() * hitDist) + (finalAngles:Up() * 5)
    end
    
    return view
end)

	if CLIENT then
		if self.LastTargetNameUpdate ~= self.TargetPhysObj then
			local BoneNum = self.Owner:TranslatePhysBoneToBone(self.TargetPhysObj or 0)
			self.BoneName = self.Owner:GetBoneName(BoneNum or 0) or ""
			self.BoneName = self.BoneName:gsub("ValveBiped.", "")
			self.LastTargetNameUpdate = self.TargetPhysObj
		end
	end

	-- Remove this block
	--[[
	if self.SecondaryAttackActive and not self.Owner:KeyDown(IN_ATTACK2) then
		self:SecondaryAttack()
		self.SecondaryAttackActive = false
	end
	]]

	-- Add this new check
	if self.RagdollActive and not self.Owner:KeyDown(IN_ATTACK2) then
		self:StopWebSwing()
	end

	if self.ConstraintController then
		self.ConstraintController.speed = self:GetShortenSpeed()
	end

    -- Dynamic rope length adjustment
    if self.RagdollActive and self.ConstraintController and GetConVar("webswing_dynamic_length"):GetBool() then
        local ragdoll = self.Ragdoll
        if IsValid(ragdoll) then
            -- Get the ragdoll's velocity and position
            local physObj = ragdoll:GetPhysicsObjectNum(self:GetTargetBone())
            if IsValid(physObj) then
                local vel = physObj:GetVelocity()
                local speed = vel:Length()
                local pos = physObj:GetPos()
                
                -- Calculate swing angle relative to vertical
                local attachPos = self.ConstraintController.rope:GetPos()
                local toAttach = (attachPos - pos):GetNormalized()
                local verticalAngle = math.deg(math.acos(math.abs(toAttach:Dot(Vector(0, 0, 1)))))
                
                -- Get adjustment factors from ConVars
                local angleFactor = GetConVar("webswing_length_angle_factor"):GetFloat()
                local minLengthRatio = GetConVar("webswing_min_length_ratio"):GetFloat()
                local smoothingFactor = GetConVar("webswing_length_smoothing"):GetFloat()
                local maxLengthChange = GetConVar("webswing_max_length_change"):GetFloat()
                
                -- Calculate ideal rope length based on angle and speed
                local baseLength = self.ConstraintController.initial_length or self.ConstraintController.current_length
                local minLength = baseLength * minLengthRatio
                
                -- Store previous velocity if not exists
                self.PrevVelocity = self.PrevVelocity or vel
                
                -- Calculate acceleration and use it to predict motion
                local acceleration = (vel - self.PrevVelocity) / FrameTime()
                local predictedVel = vel + acceleration * 0.1 -- Look ahead 0.1 seconds
                self.PrevVelocity = vel
                
                -- Angle-based adjustment with momentum prediction
                local predictedAngle = verticalAngle
                if predictedVel:Length() > 50 then
                    local predictedDir = (predictedVel:GetNormalized() * 100 + pos - attachPos):GetNormalized()
                    predictedAngle = math.deg(math.acos(math.abs(predictedDir:Dot(Vector(0, 0, 1)))))
                end
                
                -- Smooth angle transition
                local angleAdjust = 1 - (predictedAngle / 90) * 0.5 * angleFactor
                
                -- Speed-based adjustment using swing speed with better ramping
                local swingSpeed = GetSwingSpeed()
                local speedRatio = math.min(speed / swingSpeed, 1)
                local speedAdjust = 1 - speedRatio * 0.3
                
                -- Add corner detection adjustment
                local cornerFactor = 1
                if self.LastCornerTime and CurTime() - self.LastCornerTime < 0.5 then
                    local timeSinceCorner = CurTime() - self.LastCornerTime
                    cornerFactor = Lerp(timeSinceCorner / 0.5, 1.2, 1) -- Slightly longer rope in corners
                end
                
                -- Combine adjustments with corner factor
                local targetLength = baseLength * math.max(angleAdjust * speedAdjust * cornerFactor, minLengthRatio)
                
                -- Apply rate limiting to length changes
                local currentLength = self.ConstraintController.current_length
                local lengthDiff = targetLength - currentLength
                local maxChange = math.min(
                    GetConVar("webswing_max_length_change"):GetFloat() * FrameTime(),
                    50 -- Absolute maximum per frame
                )
                lengthDiff = math.Clamp(lengthDiff, -maxChange, maxChange)
                
                -- Apply smoothing with momentum preservation
                local smoothedLength
                if not self.LastLengthChange then
                    smoothedLength = currentLength + lengthDiff
                else
                    -- Preserve some momentum in length changes
                    local momentum = self.LastLengthChange * 0.3
                    local newChange = Lerp(smoothingFactor, lengthDiff + momentum, self.LastLengthChange)
                    smoothedLength = currentLength + newChange
                    self.LastLengthChange = newChange
                end
                
                -- Ensure length stays within bounds
                smoothedLength = math.Clamp(smoothedLength, minLength, baseLength * 1.2)
                
                -- Update rope length
                self.ConstraintController.current_length = smoothedLength
                self.ConstraintController:Set()
                
                -- Store corner detection time when sharp turns are detected
                local turnRate = vel:Cross(self.PrevVelocity):Length() / (speed * FrameTime())
                if turnRate > 1000 then -- Threshold for sharp turns
                    self.LastCornerTime = CurTime()
                end
            end
        end
    end
end

local function CalcElasticConstant( Phys1, Phys2, Ent1, Ent2, iFixed )
	local minMass = 0

	if Ent1:IsWorld() then
		minMass = Phys2:GetMass()
	elseif Ent2:IsWorld() then
		minMass = Phys1:GetMass()
	else
		minMass = math.min( Phys1:GetMass(), Phys2:GetMass() )
	end

	-- const, damp
	local const = minMass * 100
	local damp = const * 0.2

	if not iFixed then

		const = minMass * 50
		damp = const * 1

	end

	return const, damp

end

-- Define the standard mass for all ragdoll physics objects
SWEP.STANDARD_RAGDOLL_MASS = 1

-- Add this near the top with other SWEP variables
SWEP.BaseRange = 1000  -- Reduced from 2000 to 1000 for better control
SWEP.MaxWebLength = 1500  -- Maximum length the web can be stretched

function SWEP:PrimaryAttack()
    -- Do nothing
end

function SWEP:SecondaryAttack()
    if not IsFirstTimePredicted() then return end
    
    -- Prevent spamming
    if (self.NextSwingTime or 0) > CurTime() then
        return
    end
    
    if self.Owner:KeyPressed(IN_ATTACK2) then
        self.NextSwingTime = CurTime() + 0.5  -- Adjust cooldown as needed
        
        local tr
        if GetConVar("webswing_manual_mode"):GetBool() then
            -- Use exact trace for manual mode
            tr = util.TraceLine({
                start = self.Owner:EyePos(),
                endpos = self.Owner:EyePos() + self.Owner:GetAimVector() * self.BaseRange,
                filter = self.Owner,
                mask = MASK_SOLID,
                collisiongroup = COLLISION_GROUP_NONE,
                ignoreworld = false
            })
            
            if not tr.Hit then return end
        else
            local bestPoint = self:FindPotentialSwingPoints()
            if not bestPoint or not bestPoint.pos or not bestPoint.normal then return end
            tr = {
                Hit = true,
                HitPos = bestPoint.pos,
                HitNormal = bestPoint.normal,
                Entity = bestPoint.entity or game.GetWorld(),
                StartPos = self.Owner:EyePos(),
                PhysicsBone = 0
            }
        end
        
        if SERVER then
            self.Owner.OriginalNoclipSpeed = self.Owner:GetNWFloat("sv_noclipspeed", 5)
            self.Owner:SetNWFloat("sv_noclipspeed", 0)
            net.Start("WebSwing_NoclipSpeed")
            net.WriteBool(true)
            net.Send(self.Owner)
        end
        
        hook.Add("Move", "WebSwing_NoclipSpeed_" .. self.Owner:EntIndex(), function(moveply, mv)
            if moveply == self.Owner then
                mv:SetVelocity(Vector(0, 0, 0))
                return true
            end
        end)
        
        self:StartWebSwing(tr)
        
    elseif self.Owner:KeyReleased(IN_ATTACK2) then
        self:StopWebSwing()
    end
end

function SWEP:StartWebSwing(tr)
    if self.RagdollActive then return end
    if not IsValid(self.Owner) then return end
    
    local ply = self.Owner
    if not tr or not tr.Hit then return end
    tr.Entity = tr.Entity or game.GetWorld()

    -- Make sure we respect the swing range
    local maxRange = GetConVar("webswing_manual_mode"):GetBool() and self.BaseRange or self.Range
    if tr.HitPos:Distance(tr.StartPos or ply:EyePos()) >= maxRange then return end

    -- Store the exact world position for attachment
    local attachPos = tr.HitPos
    local attachEntity = tr.Entity
    local attachBone = tr.PhysicsBone or 0

    -- Sound system
    if SERVER then
        self.LastWebSoundTime = self.LastWebSoundTime or 0
        self.WebSoundCount = self.WebSoundCount or 0
        
        -- Always play sound on first shot after initialization
        if self.LastWebSoundTime == 0 then
            self:PlayWebShootSound()
            self.LastWebSoundTime = CurTime()
            self.WebSoundCount = 1
        else
            local currentTime = CurTime()
            local timeSinceLastSound = currentTime - self.LastWebSoundTime
            
            if timeSinceLastSound > self.WebSoundResetTime then
                self.WebSoundCount = 0
            end
            
            if timeSinceLastSound > self.WebSoundCooldown then
                self.WebSoundCount = self.WebSoundCount + 1
                self.LastWebSoundTime = currentTime
                self:PlayWebShootSound()
            end
        end
    end

    -- Store original player states
    if SERVER then
        self.OriginalStates = {
            moveType = ply:GetMoveType(),
            walkSpeed = ply:GetWalkSpeed(),
            runSpeed = ply:GetRunSpeed(),
            jumpPower = ply:GetJumpPower(),
            color = ply:GetColor(),
            renderMode = ply:GetRenderMode(),
            noDraw = ply:GetNoDraw(),
            noclipSpeed = ply:GetNWFloat("sv_noclipspeed", 5)
        }
        
        -- Apply swing state more gracefully
        ply:SetMoveType(MOVETYPE_NOCLIP)
        ply:SetNWFloat("sv_noclipspeed", 0)
        
        -- Don't completely zero velocity, just dampen it
        local currentVel = ply:GetVelocity()
        ply:SetVelocity(currentVel * 0.5)
    end

    self.RagdollActive = true
    self:ShootEffects(self)
    if CLIENT then return end

    -- Optional web decal
    if SERVER then
        util.Decal("decals/spiderman_web", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal)
    end

    self:SetNetworkedBool("wt_ragdollactive", true)

    -- Cache the player's current velocity so we can preserve inertia
    local currentVelocity = ply:GetVelocity()

    local originalScale = ply:GetModelScale()
    ply:SetModelScale(1, 0)

    -- Get player data safely
    local data = self:SafelyCopyPlayerData(ply)
    if not data then 
        ErrorNoHalt("WebSwing: Failed to copy player data for ragdoll creation\n")
        return
    end

    local ragdoll = ents.Create("prop_ragdoll")
    if not IsValid(ragdoll) then 
        ErrorNoHalt("WebSwing: Failed to create ragdoll entity\n")
        return 
    end
    
    -- Apply data safely
    if not self:SafelyApplyEntityData(ragdoll, data) then
        ErrorNoHalt("WebSwing: Failed to apply entity data to ragdoll\n")
        ragdoll:Remove()
        return
    end
    
    ragdoll:Spawn()
    ragdoll:Activate()
    
    
    -- Standardize mass and add initial dampening
    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local physObj = ragdoll:GetPhysicsObjectNum(i)
        if IsValid(physObj) then
            physObj:SetMass(self.STANDARD_RAGDOLL_MASS)
            physObj:SetDamping(0, 0)  -- Remove damping completely
            physObj:EnableMotion(true)
            physObj:Wake()
        end
    end


    -- Standardize mass and add initial dampening
    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local physObj = ragdoll:GetPhysicsObjectNum(i)
        if IsValid(physObj) then
            physObj:SetMass(self.STANDARD_RAGDOLL_MASS)
            physObj:SetDamping(0, 0)  -- Remove damping completely
            physObj:EnableMotion(true)
            physObj:Wake()
        end
    end

    ply:SetModelScale(originalScale, 0)

    if isfunction(ragdoll.CPPISetOwner) then
        ragdoll:CPPISetOwner(ply)
    else
        ragdoll.Owner = ply
        ragdoll.OwnerID = ply:SteamID()
    end

    -- Set mass for all physics objects to STANDARD_RAGDOLL_MASS
    local physCount = ragdoll:GetPhysicsObjectCount()
    for i = 0, physCount - 1 do
        local physObj = ragdoll:GetPhysicsObjectNum(i)
        if IsValid(physObj) then
            physObj:SetMass(self.STANDARD_RAGDOLL_MASS)
        end
    end

    -- Transfer the player's velocity to all ragdoll bodies
    local physCount = ragdoll:GetPhysicsObjectCount()
    for i = 0, physCount - 1 do
        local boneIndex = ragdoll:TranslatePhysBoneToBone(i)
        if boneIndex then
            local physObj = ragdoll:GetPhysicsObjectNum(i)
            if IsValid(physObj) then
                local bonePos, boneAng = ply:GetBonePosition(boneIndex)
                physObj:SetPos(bonePos)
                physObj:SetAngles(boneAng)
                physObj:AddVelocity(currentVelocity)
            end
        end
    end

    -- Figure out which bone to attach the rope/spring to
    local targetPhysObj = self:GetTargetBone()
    local bonePos = ragdoll:GetPos()
    local foundBonePos = false
    local vel = ply:GetVelocity()

    for i = 0, physCount - 1 do
        if i == targetPhysObj then
            local boneIndex = ragdoll:TranslatePhysBoneToBone(i)
            local Pos, Ang = ply:GetBonePosition(boneIndex)
            bonePos = Pos
            foundBonePos = true
            break
        end
    end
    if not foundBonePos then
        bonePos = ragdoll:GetPos()
    end

    -- Decide if we use rope or elastic
    local useRope = ply:KeyDown(IN_USE)
    local dist = math.floor(bonePos:Distance(tr.HitPos))
    local attachEntity = tr.Entity
    local attachBone = 0
    local attachPos = (attachEntity:EntIndex() ~= 0)
        and (tr.HitPos - attachEntity:GetPos()) or tr.HitPos

    if IsValid(attachEntity) and attachEntity:GetClass() == "prop_ragdoll" then
        attachBone = tr.PhysicsBone or 0
        local entPhys = attachEntity:GetPhysicsObjectNum(attachBone)
        if IsValid(entPhys) then
            attachPos = entPhys:WorldToLocal(tr.HitPos)
        end
    end

    ply:SetParent(ragdoll)
    -- Removing any forced zero velocity here
    ply:SetMoveType(MOVETYPE_NOCLIP)

    -- Hide player model
    ply:SetNoDraw(true)
    ply:DrawWorldModel(false)
    ply:SetRenderMode(RENDERMODE_TRANSALPHA)
    ply:SetColor(Color(255, 255, 255, 0))

    ragdoll.DontAllowRemoval = true
    ragdoll.DontAllowRape = true
    ply.WT_webswing_Roping = true
    self.Ragdoll = ragdoll

    ply:SpectateEntity(ragdoll)

    -- Decide rope material
    local ropeMat = GetConVar("webswing_rope_material"):GetString() or "cable/xbeam"
    local ropeWidth = 2
    if ropeMat == "cable/redlaser" then
        ropeWidth = 5
    elseif ropeMat == "cable/rope" then
        ropeWidth = 1
    elseif ropeMat == "cable/cable2" then
        ropeWidth = 1.25
    end

    local ropeColor = Color(
        GetConVar("webswing_rope_color_r"):GetInt(),
        GetConVar("webswing_rope_color_g"):GetInt(),
        GetConVar("webswing_rope_color_b"):GetInt(),
        GetConVar("webswing_rope_alpha"):GetInt()
    )

    if useRope then
        -- Calculate local offset based on entity type
        local localPos
        if attachEntity:IsWorld() then
            localPos = tr.HitPos  -- For world, use world coordinates
        else
            -- For props and other entities, properly convert to local space
            local physObj = attachEntity:GetPhysicsObject()
            if IsValid(physObj) then
                localPos = WorldToLocal(tr.HitPos, Angle(0,0,0), attachEntity:GetPos(), attachEntity:GetAngles())
            else
                localPos = tr.HitPos - attachEntity:GetPos()
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
            self.ConstraintController = {
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
                    ctrl.current_length = math.min(ctrl.current_length + ctrl.speed, self.Range)
                    ctrl:Set()
                end
            }
            self.ConstraintController:Set()
        else
            self.RagdollActive = false
            return
        end
    else
        -- Calculate local offset for elastic constraint
        local localPos
        if attachEntity:IsWorld() then
            localPos = tr.HitPos
        else
            local physObj = attachEntity:GetPhysicsObject()
            if IsValid(physObj) then
                localPos = WorldToLocal(tr.HitPos, Angle(0,0,0), attachEntity:GetPos(), attachEntity:GetAngles())
            else
                localPos = tr.HitPos - attachEntity:GetPos()
            end
        end

        local const, damp = CalcElasticConstant(
            ragdoll:GetPhysicsObjectNum(targetPhysObj),
            attachEntity:GetPhysicsObjectNum(attachBone),
            ragdoll, attachEntity
        )
        local springConstraint, ropeEntity = constraint.Elastic(
            ragdoll, attachEntity,
            targetPhysObj, attachBone,
            Vector(0, 0, 0), attachPos,
            const * 5, damp * 5, 0,
            ropeMat, ropeWidth, true
        )
        if ropeEntity then
            ropeEntity:SetKeyValue("spawnflags", "1")
            ropeEntity:SetRenderMode(RENDERMODE_TRANSALPHA)
            ropeEntity:SetColor(ropeColor)
            ropeEntity:SetMaterial(ropeMat)
        end
        if springConstraint and ropeEntity then
            self.ConstraintController = {
                current_length = dist * 0.95,
                min_length = 10,
                max_length = self.Range,
                constraint = springConstraint,
                rope = ropeEntity,
                speed = 5,
                Set = function(ctrl)
                    if IsValid(ctrl.constraint) then
                        ctrl.constraint:Fire("SetSpringLength", ctrl.current_length, 0)
                    end
                    if IsValid(ctrl.rope) then
                        ctrl.rope:Fire("SetLength", ctrl.current_length, 0)
                    end
                end,
                Shorten = function(ctrl)
                    ctrl.current_length = math.max(ctrl.current_length - ctrl.speed, ctrl.min_length)
                    ctrl:Set()
                end,
                Slacken = function(ctrl)
                    ctrl.current_length = math.min(ctrl.current_length + ctrl.speed, ctrl.max_length)
                    ctrl:Set()
                end
            }
            self.ConstraintController:Set()
        else
            self.RagdollActive = false
            return
        end
    end
end

-- Add this function before StopWebSwing
function SWEP:IsInCorner(pos, ignoreEnts)
    local angles = {0, 45, 90, 135, 180, 225, 270, 315}
    local hitCount = 0
    local hitNormals = {}
    
    for _, angle in ipairs(angles) do
        local rad = math.rad(angle)
        local dir = Vector(math.cos(rad), math.sin(rad), 0)
        
        local tr = util.TraceLine({
            start = pos,
            endpos = pos + dir * 40,
            filter = ignoreEnts or {self.Owner},
            mask = MASK_SOLID
        })
        
        if tr.Hit then
            hitCount = hitCount + 1
            table.insert(hitNormals, tr.HitNormal)
        end
    end
    
    -- If we hit multiple walls, check if they form a corner
    if hitCount >= 2 then
        -- Calculate the average escape direction from all hit normals
        local escapeDir = Vector(0, 0, 0)
        for _, normal in ipairs(hitNormals) do
            escapeDir = escapeDir + normal
        end
        escapeDir:Normalize()
        
        return true, escapeDir
    end
    
    return false, Vector(0, 0, 0)
end

function SWEP:StopWebSwing()
    if not self.RagdollActive then return end
    
    if not self.Owner then return end
    local ply = self.Owner
    local rag = self.Ragdoll
    
    self:PlayWebJumpSound()
    
    self.RagdollActive = false

    if SERVER then
        -- Restore all original states if they exist
        if self.OriginalStates then
            ply:SetMoveType(self.OriginalStates.moveType)
            ply:SetWalkSpeed(self.OriginalStates.walkSpeed)
            ply:SetRunSpeed(self.OriginalStates.runSpeed)
            ply:SetJumpPower(self.OriginalStates.jumpPower)
            ply:SetColor(self.OriginalStates.color)
            ply:SetRenderMode(self.OriginalStates.renderMode)
            ply:SetNoDraw(self.OriginalStates.noDraw)
            ply:SetNWFloat("sv_noclipspeed", self.OriginalStates.noclipSpeed)
            
            -- Clear stored states
            self.OriginalStates = nil
        else
            -- Fallback to default states if original states weren't stored
            ply:SetMoveType(MOVETYPE_WALK)
            ply:SetColor(Color(255, 255, 255, 255))
            ply:SetRenderMode(RENDERMODE_NORMAL)
            ply:SetNoDraw(false)
        end
        
        -- Restore visibility of attached entities
        for _, ent in pairs(ents.FindByClass("prop_physics")) do
            if ent:GetParent() == ply then
                ent:SetNoDraw(false)
            end
        end
    end

    if CLIENT then return end

    self:SetNetworkedBool("wt_ragdollactive", false)
    
    ply.WT_webswing_Roping = false
    ply:SetParent(nil)
    
    -- Remove move hook without affecting other hooks
    hook.Remove("Move", "WebSwing_NoclipSpeed_" .. ply:EntIndex())

    local ragValid = IsValid(rag)
    local vel = Vector(0, 0, 0)
    
    if ragValid then
        vel = rag:GetVelocity()
        
        -- Make the ragdoll invisible and non-colliding
        rag:SetRenderMode(RENDERMODE_TRANSALPHA)
        rag:SetColor(Color(255, 255, 255, 0))
        rag:SetCollisionGroup(COLLISION_GROUP_WORLD)
        
        -- Get all physics objects and disable collisions
        for i = 0, rag:GetPhysicsObjectCount() - 1 do
            local phys = rag:GetPhysicsObjectNum(i)
            if IsValid(phys) then
                phys:EnableCollisions(false)
            end
        end
        
        -- Handle web removal based on ConVar
        if GetConVar("webswing_keep_webs"):GetBool() then
            -- Remove the ragdoll after a delay
            timer.Create("WebRemoval_" .. rag:EntIndex(), 30, 1, function()
                if IsValid(rag) then
                    SafeRemoveEntity(rag)
                end
            end)
        else
            -- Remove immediately if keep_webs is disabled
            SafeRemoveEntity(rag)
        end
    else
        SafeRemoveEntity(rag)
    end
    
    local respawnPos = ragValid and rag:GetPos() or ply:GetPos()
    local safePos = self:FindSafePosition(respawnPos)


    -- Enhanced safe position finding with corner avoidance
    local function FindSafePosition(pos)
        local function TestPosition(testPos)
            -- Check for corners at the test position
            local inCorner = self:IsInCorner(testPos, {ply})
            if inCorner then return false end
            
            -- Check if position is safe for player
            local tr = util.TraceHull({
                start = testPos,
                endpos = testPos,
                mins = Vector(-16, -16, 0),
                maxs = Vector(16, 16, 72),
                filter = ply,
                mask = MASK_SOLID
            })
            
            return not tr.Hit
        end
        
        -- Try positions in a spiral pattern, moving outward and upward
        local attempts = {}
        for i = 0, 360, 45 do
            for dist = 0, 64, 32 do
                for height = 0, 64, 32 do
                    local rad = math.rad(i)
                    local offset = Vector(
                        math.cos(rad) * dist,
                        math.sin(rad) * dist,
                        height
                    )
                    table.insert(attempts, offset)
                end
            end
        end
        
        -- Try each position
        for _, offset in ipairs(attempts) do
            local testPos = pos + offset
            if TestPosition(testPos) then
                return testPos
            end
        end
        
        -- If no safe position found, move up and away from walls
        local tr = util.TraceHull({
            start = pos,
            endpos = pos,
            mins = Vector(-16, -16, 0),
            maxs = Vector(16, 16, 72),
            filter = ply,
            mask = MASK_SOLID
        })
        
        if tr.Hit then
            return pos + tr.HitNormal * 64 + Vector(0, 0, 64)
        end
        
        return pos
    end
    
    -- Find a safe position and set the player's position
    local safePos = FindSafePosition(respawnPos)
    
    -- Enhanced safe position finding with corner avoidance
    local function FindSafePosition(pos)
        local function TestPosition(testPos)
            -- Check for corners at the test position
            local inCorner = self:IsInCorner(testPos, {ply})
            if inCorner then return false end
            
            -- Check if position is safe for player
            local tr = util.TraceHull({
                start = testPos,
                endpos = testPos,
                mins = Vector(-16, -16, 0),
                maxs = Vector(16, 16, 72),
                filter = ply,
                mask = MASK_SOLID
            })
            
            return not tr.Hit
        end
        
        -- Try positions in a spiral pattern, moving outward and upward
        local attempts = {}
        for i = 0, 360, 45 do
            for dist = 0, 64, 32 do
                for height = 0, 64, 32 do
                    local rad = math.rad(i)
                    local offset = Vector(
                        math.cos(rad) * dist,
                        math.sin(rad) * dist,
                        height
                    )
                    table.insert(attempts, offset)
                end
            end
        end
        
        -- Try each position
        for _, offset in ipairs(attempts) do
            local testPos = pos + offset
            if TestPosition(testPos) then
                return testPos
            end
        end
        
        -- If no safe position found, move up and away from walls
        local tr = util.TraceHull({
            start = pos,
            endpos = pos,
            mins = Vector(-16, -16, 0),
            maxs = Vector(16, 16, 72),
            filter = ply,
            mask = MASK_SOLID
        })
        
        if tr.Hit then
            return pos + tr.HitNormal * 64 + Vector(0, 0, 64)
        end
        
        return pos
    end
    
    -- Find a safe position and set the player's position
    local safePos = FindSafePosition(respawnPos)
    if safePos then
        ply:SetPos(safePos)
        
        -- Transfer momentum more naturally
        if vel:Length() > 0 then
            -- Preserve horizontal velocity with better control
            local horizontalVel = Vector(vel.x, vel.y, 0)
            local verticalVel = Vector(0, 0, math.max(vel.z * 0.8, 0)) -- Prevent strong downward momentum
            
            -- Apply velocity with a slight damping for better control
            ply:SetVelocity(horizontalVel * 0.9 + verticalVel)
        end
    end
end

function SWEP:Shorten()
    if self.ConstraintController then
        self.ConstraintController:Shorten()
    end
end

function SWEP:Slacken()
    if self.ConstraintController then
        self.ConstraintController:Slacken()
    end
end

/*---------------------------------------------------------
   Name: ShouldDropOnDie
   Desc: Should this weapon be dropped when its owner dies?
---------------------------------------------------------*/
function SWEP:ShouldDropOnDie()
    return false
end

function SWEP:Holster()
    if IsValid(self.Owner) and self.Owner:Alive() and self.RagdollActive then
        return false
    end
    
    -- Ensure player is visible when holstering
    if SERVER and IsValid(self.Owner) then
        self.Owner:SetNoDraw(false)
        self.Owner:DrawWorldModel(true)
        self.Owner:SetRenderMode(RENDERMODE_NORMAL)
        self.Owner:SetColor(Color(255, 255, 255, 255))
        
        -- Restore visibility of attached entities
        for _, ent in pairs(ents.FindByClass("prop_physics")) do
            if ent:GetParent() == self.Owner then
                ent:SetNoDraw(false)
            end
        end
    end
    
    if CLIENT and IsValid(self.Owner) then
        self.Owner:DrawViewModel(true)
        local vm = self.Owner:GetViewModel()
        if IsValid(vm) then
            self:ResetBonePositions(vm)
        end
    end
    
    if SERVER then
        self.Owner:SetViewEntity(self.Owner)
        self.Owner:UnSpectate()
        self.Owner:SetMoveType(MOVETYPE_WALK)
    end
    
    hook.Remove("CalcView", "SpiderManView")
    hook.Remove("CalcMainActivity", "BaseAnimations")
    
    return true
end

function SWEP:OnRemove()
    -- Clean up view hooks
    hook.Remove("CalcView", "name")
    hook.Remove("CalcView", "SpiderManView")
    
    -- Server-side cleanup
    if SERVER and IsValid(self.Owner) then
        -- Clean up movement hooks and restore noclip speed
        hook.Remove("Move", "WebSwing_NoclipSpeed_" .. self.Owner:EntIndex())
        if self.Owner.OriginalNoclipSpeed then
            self.Owner:SetNWFloat("sv_noclipspeed", self.Owner.OriginalNoclipSpeed)
            self.Owner.OriginalNoclipSpeed = nil
        end
        
        -- Make sure player is visible and properly configured
        self.Owner:SetNoDraw(false)
        self.Owner:DrawWorldModel(true)
        self.Owner:SetRenderMode(RENDERMODE_NORMAL)
        self.Owner:SetColor(Color(255, 255, 255, 255))
        self.Owner:SetMoveType(MOVETYPE_WALK)
        
        -- Clean up any active ragdoll
        if IsValid(self.Ragdoll) then
            SafeRemoveEntity(self.Ragdoll)
        end
    end
    
    -- Client-side cleanup
    if CLIENT and IsValid(self.Owner) then
        self.Owner:DrawViewModel(true)
        local vm = self.Owner:GetViewModel()
        if IsValid(vm) then
            self:ResetBonePositions(vm)
        end
    end
    
    -- Call holster to ensure all holster cleanup is performed
    self:Holster()
    hook.Remove("CalcMainActivity", "BaseAnimations")
end

function SWEP:GetTargetBone()
    local ply = self.Owner
    local model = ply:GetModel():lower()

    -- Define bone names for right and left hands
    local boneNames = {
        right = {"ValveBiped.Bip01_R_Hand", "bip01_r_hand"},
        left = {"ValveBiped.Bip01_L_Hand", "bip01_l_hand"}
    }

    -- Determine which hand to use based on some condition (e.g., alternating, player choice, etc.)
    local useRightHand = (CurTime() % 2 < 1)  -- This will alternate between right and left
    local targetBones = useRightHand and boneNames.right or boneNames.left

    -- Find the first matching bone
    for _, boneName in ipairs(targetBones) do
        local boneId = ply:LookupBone(boneName)
        if boneId then
            return ply:TranslateBoneToPhysBone(boneId)
        end
    end

    -- Fallback to a default bone if none of the target bones are found
    return 0
end

if SERVER then
    -- Create a ConVar on the server side as well (default is 0, which means fall damage is off)
    CreateConVar("webswing_enable_fall_damage", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable fall damage when using WebSwing", 0, 1)

    -- Add this section to define a new ConVar for rope material
    CreateConVar("webswing_rope_material", "cable/xbeam", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Material used for the web rope")

    hook.Add("EntityTakeDamage", "FallDamageWhileHoldingSWEP", function(target, dmginfo)
        if target:IsPlayer() and dmginfo:IsFallDamage() then
            local weapon = target:GetActiveWeapon()
            if IsValid(weapon) and weapon:GetClass() == "webswing" then
                -- Check if fall damage should be enabled
                if not GetConVar("webswing_enable_fall_damage"):GetBool() then
                    dmginfo:SetDamage(0)
                    dmginfo:ScaleDamage(0)
                    -- Prevent fall impact sound
                    target:EmitSound("", 0, 0) -- This overrides the default fall sound with silence
                end
            end
        end
    end)

    -- Add hook to prevent fall impact sounds
    hook.Add("OnPlayerHitGround", "PreventFallSoundWhileHoldingSWEP", function(player, inWater, onFloater, speed)
        local weapon = player:GetActiveWeapon()
        if IsValid(weapon) and weapon:GetClass() == "webswing" then
            if not GetConVar("webswing_enable_fall_damage"):GetBool() then
                return true -- Prevents the default fall sound from playing
            end
        end
    end)
end

print("webswing Shared.lua Reloaded OK")

hook.Add( "CalcMainActivity", "BaseAnimations", function( Player, Velocity )
    // Check if the player is holding this SWEP
    if not Player:GetActiveWeapon() or Player:GetActiveWeapon():GetClass() ~= "webswing" then
        return
    end

    // ... existing code ...
    if not Player.LastOnGround and not Player:OnGround() then
        Player.LastOnGround = true
    end
    if Player:IsOnGround() and Player.LastOnGround then
        Player:AddVCDSequenceToGestureSlot( GESTURE_SLOT_FLINCH, Player:LookupSequence("jump_land"), 0, true )
        Player.LastOnGround = false
    end
    Player.m_FistAttackIndex = Player.m_FistAttackIndex or Player:GetNW2Int("$fist_attack_index")
    if Player.m_FistAttackIndex ~= Player:GetNW2Int("$fist_attack_index") then
        Player.m_FistAttackIndex = Player:GetNW2Int("$fist_attack_index")
        Player:AddVCDSequenceToGestureSlot( 5, Player:LookupSequence("zombie_attack_0" .. ( ( Player.m_FistAttackIndex )% 7 + 1 )), 0.5, true )
    end
    if Player:IsOnGround() and Velocity:Length() > Player:GetRunSpeed() - 10 then
        return ACT_HL2MP_RUN_FAST, -1
    end
end)

-- Add this function after SWEP initialization
function SWEP:GetSwingForce()
    return GetSwingSpeed()
end

function SWEP:GetShortenSpeed()
    return GetSwingSpeed() / 100 
end

-- Improved AI-based swing targeting system
function SWEP:GatherSwingPointCandidates()
    local ply = self.Owner
    if not IsValid(ply) then return {} end
    
    local eyePos = ply:EyePos()
    local eyeAngles = ply:EyeAngles()
    local vel = ply:GetVelocity()
    local speed = vel:Length()
    local scanRadius = self.Range * GetConVar("webswing_map_range_mult"):GetFloat()
    local candidates = {}
    
    -- Get user preferences
    local momentumFactor = GetMomentumPreservation()
    local groundSafety = GetGroundSafety()
    local allowSkyAttach = GetConVar("webswing_allow_sky_attach"):GetBool()
    
    -- Check ground distance for emergency points
    local groundTrace = util.TraceLine({
        start = eyePos,
        endpos = eyePos - Vector(0, 0, 1000),
        filter = ply,
        mask = MASK_SOLID
    })
    local distToGround = groundTrace.Hit and groundTrace.HitPos:Distance(eyePos) or 1000
    
    -- Dynamic scan parameters based on state
    local baseSteps = 16 -- Reduced from 24 for better performance
    local steps = baseSteps
    local halfAngle = 30
    
    -- Adjust scan pattern based on speed and height
    if speed > 500 then
        -- At high speeds, focus more on forward arc
        halfAngle = Lerp(momentumFactor, 30, 15)
        steps = math.floor(Lerp(momentumFactor, baseSteps, 12))
    elseif distToGround < 200 and groundSafety > 0.5 then
        -- When close to ground, scan more upward but with fewer points
        halfAngle = Lerp(groundSafety, 30, 45)
        steps = math.floor(Lerp(groundSafety, baseSteps, 20))
    end
    
    -- Calculate ideal swing direction based on momentum
    local idealDir = vel:GetNormalized()
    if speed < 100 then
        idealDir = ply:GetAimVector()
    end
    
    -- Efficient forward cone scan
    local scannedDirections = {}
    for i = 1, steps do
        local angleProgress = (i - 1) / steps
        local yawOffset = 360 * angleProgress
        
        -- Bias pitch based on ground proximity and speed
        local basePitch = -30
        if distToGround < 200 then
            basePitch = Lerp(groundSafety, -30, -15)
        elseif speed > 500 then
            basePitch = Lerp(momentumFactor, -30, -45)
        end
        
        local pitchOffset = basePitch + math.random(-halfAngle, halfAngle)
        local scanAngles = Angle(eyeAngles.p + pitchOffset, eyeAngles.y + yawOffset, 0)
        local direction = scanAngles:Forward()
        
        -- Cache direction to avoid duplicate traces
        local dirKey = string.format("%.1f_%.1f_%.1f", direction.x, direction.y, direction.z)
        if scannedDirections[dirKey] then continue end
        scannedDirections[dirKey] = true
        
        -- Bias direction towards ideal path
        if speed > 100 then
            direction = LerpVector(momentumFactor * 0.5, direction, idealDir)
            direction:Normalize()
        end
        
        local tr = util.TraceLine({
            start = eyePos,
            endpos = eyePos + direction * scanRadius,
            filter = ply,
            mask = MASK_SOLID
        })
        
        if tr.Hit then
            -- Only check for corners if point is potentially useful
            local heightDiff = tr.HitPos.z - eyePos.z
            local isCorner = false
            local overhead = nil
            
            -- Selective corner and overhead checks
            if (heightDiff > -100 and heightDiff < 300) or 
               (speed > 300 and tr.HitPos:Distance(eyePos + vel:GetNormalized() * 300) < 200) then
                isCorner = self:IsCornerPoint(tr.HitPos, tr.HitNormal)
                overhead = self:CheckOverheadClearance(tr.HitPos)
            end
            
            -- Determine point type
            local pointType = "forward"
            if heightDiff > 100 then
                pointType = "overhead"
            elseif speed > 300 and tr.HitPos:Distance(eyePos + vel:GetNormalized() * 300) < 200 then
                pointType = "momentum"
            end
            
            table.insert(candidates, {
                pos = tr.HitPos,
                normal = tr.HitNormal,
                entity = tr.Entity,
                isCorner = isCorner,
                overhead = overhead,
                type = pointType
            })
        end
    end
    
    -- Add emergency upward points only when necessary
    if distToGround < 200 and groundSafety > 0.5 and #candidates < 3 then
        local upSteps = math.floor(4 * groundSafety) -- Reduced from 8
        local upRadius = scanRadius * 0.4
        
        for i = 1, upSteps do
            local angle = math.rad((i / upSteps) * 360)
            local offset = Vector(
                math.cos(angle) * upRadius * 0.3,
                math.sin(angle) * upRadius * 0.3,
                upRadius
            )
            
            local tr = util.TraceLine({
                start = eyePos,
                endpos = eyePos + offset,
                filter = ply,
                mask = MASK_SOLID
            })
            
            if tr.Hit then
                table.insert(candidates, {
                    pos = tr.HitPos,
                    normal = tr.HitNormal,
                    entity = tr.Entity,
                    isCorner = false,
                    overhead = self:CheckOverheadClearance(tr.HitPos),
                    type = "emergency"
                })
            end
        end
    end
    
    -- Add momentum-preserving points only at high speeds
    if speed > 500 and momentumFactor > 0.5 and #candidates < 5 then
        local momSteps = math.floor(3 * momentumFactor) -- Reduced from 6
        local momRadius = scanRadius * 0.6
        
        for i = 1, momSteps do
            local progress = (i - 1) / momSteps
            local offset = vel:GetNormalized() * (momRadius * progress) +
                          Vector(0, 0, momRadius * 0.3 * (1 - progress))
            
            local tr = util.TraceLine({
                start = eyePos,
                endpos = eyePos + offset,
                filter = ply,
                mask = MASK_SOLID
            })
            
            if tr.Hit then
                table.insert(candidates, {
                    pos = tr.HitPos,
                    normal = tr.HitNormal,
                    entity = tr.Entity,
                    isCorner = false,
                    overhead = self:CheckOverheadClearance(tr.HitPos),
                    type = "momentum"
                })
            end
        end
    end
    
    -- Add sky attachment points if enabled
    if allowSkyAttach then
        -- Calculate optimal sky height dynamically
        local skyHeight = self:CalculateOptimalSkyHeight(eyePos, vel, distToGround)
        local skySteps = 8 -- Number of sky points to add
        local skyRadius = scanRadius * 0.7 -- Slightly reduced radius for sky points
        
        -- Calculate distribution pattern based on speed
        local pattern = {}
        if speed > 300 then
            -- At high speeds, bias points in movement direction
            local forward = vel:GetNormalized()
            local right = forward:Cross(Vector(0, 0, 1))
            for i = 1, skySteps do
                local angle = math.rad((i / skySteps) * 270 - 135) -- -135 to +135 degrees
                local dirWeight = math.cos(angle) * 0.5 + 0.5 -- Weight forward direction more
                local dir = forward * dirWeight + right * math.sin(angle)
                dir:Normalize()
                table.insert(pattern, dir)
            end
        else
            -- At low speeds, distribute points in a circle
            for i = 1, skySteps do
                local angle = math.rad((i / skySteps) * 360)
                table.insert(pattern, Vector(math.cos(angle), math.sin(angle), 0))
            end
        end
        
        -- Generate sky points using the pattern
        for _, dir in ipairs(pattern) do
            local offset = dir * skyRadius * 0.5
            local skyPoint = eyePos + offset + Vector(0, 0, skyHeight - eyePos.z)
            
            -- Check if there's a clear path to the sky point
            local skyTrace = util.TraceLine({
                start = eyePos,
                endpos = skyPoint,
                filter = ply,
                mask = MASK_SOLID
            })
            
            if not skyTrace.Hit then
                table.insert(candidates, {
                    pos = skyPoint,
                    normal = Vector(0, 0, -1),
                    entity = game.GetWorld(),
                    isCorner = false,
                    overhead = { clear = true, height = skyHeight - eyePos.z },
                    type = "sky"
                })
            end
        end
        
        -- Add forward-biased sky points for momentum preservation
        if speed > 300 then
            local forwardDist = math.min(speed * 0.5, skyRadius * 0.7)
            local forwardPoint = eyePos + vel:GetNormalized() * forwardDist + Vector(0, 0, skyHeight * 0.7)
            
            local forwardTrace = util.TraceLine({
                start = eyePos,
                endpos = forwardPoint,
                filter = ply,
                mask = MASK_SOLID
            })
            
            if not forwardTrace.Hit then
                table.insert(candidates, {
                    pos = forwardPoint,
                    normal = Vector(0, 0, -1),
                    entity = game.GetWorld(),
                    isCorner = false,
                    overhead = { clear = true, height = skyHeight - eyePos.z },
                    type = "sky_momentum"
                })
            end
        end
    end
    
    -- Add emergency vertical check
    if #candidates == 0 then
        local up_tr = util.TraceLine({
            start = eyePos,
            endpos = eyePos + Vector(0, 0, 500),
            filter = ply,
            mask = MASK_SOLID
        })
        
        if up_tr.Hit then
            table.insert(candidates, {
                pos = up_tr.HitPos,
                normal = up_tr.HitNormal,
                entity = up_tr.Entity,
                type = "emergency_vertical"
            })
        end
    end
    
    return candidates
end

function SWEP:CheckOverheadClearance(pos)
    -- Only check if we're not too high up
    local heightCheck = util.TraceLine({
        start = pos,
        endpos = pos - Vector(0, 0, 1000),
        mask = MASK_SOLID
    })
    
    -- If point is very high up, assume good clearance
    if not heightCheck.Hit or heightCheck.HitPos:Distance(pos) > 500 then
        return {
            clear = true,
            height = 100
        }
    end
    
    -- Quick upward check
    local tr = util.TraceLine({
        start = pos,
        endpos = pos + Vector(0, 0, 80), -- Reduced from 100 for better performance
        mask = MASK_SOLID
    })
    
    -- If nothing directly above, do a cone check for better accuracy
    if not tr.Hit then
        local hasObstruction = false
        local angles = {30, 150, 270} -- Reduced number of checks from 8 to 3
        
        for _, angle in ipairs(angles) do
            local rad = math.rad(angle)
            local checkDir = Vector(
                math.cos(rad) * 0.5,
                math.sin(rad) * 0.5,
                0.8
            ):GetNormalized()
            
            local coneTrace = util.TraceLine({
                start = pos,
                endpos = pos + checkDir * 60,
                mask = MASK_SOLID
            })
            
            if coneTrace.Hit then
                hasObstruction = true
                break
            end
        end
        
        return {
            clear = not hasObstruction,
            height = hasObstruction and 60 or 80
        }
    end
    
    return {
        clear = false,
        height = tr.HitPos:Distance(pos)
    }
end

-- Modify the function signature to accept candidates array
function SWEP:EvaluateSwingCandidate(candidate, playerState, allCandidates)
    local score = 0
    local ply = self.Owner
    local eyePos = playerState.eyePos
    local vel = playerState.velocity
    local speedSqr = vel:LengthSqr()
    local speed = vel:Length()
    
    -- Get user preferences
    local momentumFactor = GetMomentumPreservation()
    local groundSafety = GetGroundSafety()
    local assistStrength = GetAssistStrength()
    local maxWebLength = GetWebLength()
    local swingCurve = GetSwingCurve()
    
    -- Check ground distance
    local groundTrace = util.TraceLine({
        start = eyePos,
        endpos = eyePos - Vector(0, 0, 1000),
        filter = ply,
        mask = MASK_SOLID
    })
    local distToGround = groundTrace.Hit and groundTrace.HitPos:Distance(eyePos) or 1000
    
    -- Base distance scoring with web length limit
    local dist = candidate.pos:Distance(eyePos)
    if dist > maxWebLength then
        return -1000 -- Immediately reject points beyond max web length
    end
    
    -- Distance scoring with momentum consideration
    local baseOptimalDist = 500
    local speedBonus = math.sqrt(speedSqr) * 0.5 * momentumFactor
    local optimalDist = math.Clamp(baseOptimalDist + speedBonus, 300, maxWebLength * 0.8)
    local distScore = 1 - math.abs(dist - optimalDist) / optimalDist
    score = score + distScore * (0.3 * assistStrength)
    
    -- Height evaluation with ground safety and swing curve
    local heightDiff = candidate.pos.z - eyePos.z
    local optimalHeight = self.OptimalSwingHeight or 150
    
    -- Adjust optimal height based on swing curve preference
    optimalHeight = optimalHeight * (1 + swingCurve * 0.5)
    
    -- Adjust height scoring based on ground proximity
    if distToGround < 200 and groundSafety > 0 then
        -- Strong preference for upward points when close to ground
        local groundDanger = (200 - distToGround) / 200
        if heightDiff > 0 then
            score = score + (groundDanger * groundSafety * 0.5)
        else
            score = score - (groundDanger * groundSafety * 0.5)
        end
    end
    
    -- Enhanced arc scoring based on swing curve preference
    local arcScore = 0
    if candidate.type == "overhead" then
        -- For overhead points, higher curve means prefer more height
        arcScore = math.Clamp(heightDiff / (optimalHeight * swingCurve), 0, 1) * (0.4 * assistStrength)
    else
        -- For other points, calculate ideal arc based on speed and curve
        local idealHeight = optimalHeight * (1 + (speed / 1000) * swingCurve)
        local heightScore = 1 - math.abs(heightDiff - idealHeight) / idealHeight
        arcScore = math.Clamp(heightScore, 0, 1) * (0.3 * assistStrength)
        
        -- Add lateral arc consideration
        local velDir = vel:GetNormalized()
        local rightVec = velDir:Cross(Vector(0, 0, 1))
        local lateralOffset = math.abs(rightVec:Dot((candidate.pos - eyePos):GetNormalized()))
        local lateralScore = lateralOffset * swingCurve * 0.2
        arcScore = arcScore + lateralScore
    end
    score = score + arcScore
    
    -- Momentum preservation scoring with curve influence
    if speedSqr > 40000 then -- Only consider momentum above certain speed
        local velDir = vel:GetNormalized()
        local toPoint = (candidate.pos - eyePos):GetNormalized()
        local momentumAlign = velDir:Dot(toPoint)
        
        -- Calculate ideal swing arc with curve influence
        local rightVec = velDir:Cross(Vector(0, 0, 1))
        local curveOffset = Vector(0, 0, optimalHeight * swingCurve)
        local idealSwingPoint = eyePos + velDir * optimalDist + curveOffset
        local toIdealPoint = (idealSwingPoint - eyePos):GetNormalized()
        local idealAlign = toPoint:Dot(toIdealPoint)
        
        -- Combine momentum and ideal path scores
        local momentumScore = math.Clamp(momentumAlign + 0.5, 0, 1) * momentumFactor
        local pathScore = math.Clamp(idealAlign + 0.5, 0, 1) * assistStrength
        
        -- Adjust based on curve preference
        local curveWeight = Lerp(swingCurve, 0.7, 0.3) -- More curve means less emphasis on pure momentum
        score = score + (momentumScore * curveWeight + pathScore * (1 - curveWeight))
    end
    
    -- Corner point bonus with curve consideration
    if candidate.isCorner then
        local cornerBonus = 0.2 * assistStrength
        if candidate.overhead.clear then
            cornerBonus = cornerBonus + (0.1 * assistStrength)
        end
        -- Reduce corner preference with high curve values
        cornerBonus = cornerBonus * (1 - swingCurve * 0.3)
        score = score + cornerBonus
    end
    
    -- Overhead clearance scoring
    if candidate.overhead then
        local clearanceScore = candidate.overhead.clear and 0.2 or 
                             (candidate.overhead.height / 100) * 0.1
        score = score + clearanceScore * assistStrength
    end
    
    -- Map-specific adjustments with curve influence
    if self.MapAnalysis and self.MapAnalysis.analyzed then
        -- Adjust for building density
        if self.MapAnalysis.buildingDensity > 0.7 then
            -- In dense areas, prefer higher points more with higher curve values
            if heightDiff > 0 then
                score = score + (0.1 * assistStrength * (1 + swingCurve * 0.5))
            end
        end
        
        -- Adjust for open spaces
        if self.MapAnalysis.openSpaceRatio > 0.7 then
            -- In open areas, prefer longer swings for momentum, but consider curve
            if dist > optimalDist * 0.8 then
                score = score + (0.1 * momentumFactor * (1 - swingCurve * 0.3))
            end
        end
    end
    
    -- Emergency recovery scoring
    if distToGround < 100 and speedSqr < 40000 then
        -- Desperate times call for desperate measures
        if heightDiff > 0 and dist < 300 then
            score = score + (1.0 * groundSafety) -- Strong preference for any upward point
        end
    end
    
    -- Special scoring for sky points
    if candidate.type == "sky" or candidate.type == "sky_momentum" then
        -- Base score for sky points
        score = score + 0.3
        
        -- Bonus for momentum-preserving sky points
        if candidate.type == "sky_momentum" and speedSqr > 90000 then -- Speed > 300
            local velDir = vel:GetNormalized()
            local toPoint = (candidate.pos - eyePos):GetNormalized()
            local momentumAlign = velDir:Dot(toPoint)
            score = score + momentumAlign * 0.4 * momentumFactor
        end
        
        -- Emergency sky point bonus when no other good points are available
        if allCandidates and #allCandidates < 3 and distToGround < 200 then
            score = score + 0.3 * groundSafety
        end
    end
    
    return score
end

-- Modify FindPotentialSwingPoints to pass candidates array
function SWEP:FindPotentialSwingPoints()
    local ply = self.Owner
    if not IsValid(ply) then return nil end
    
    -- Get user preferences for logging
    local assistStrength = GetAssistStrength()
    local momentumFactor = GetMomentumPreservation()
    local groundSafety = GetGroundSafety()
    
    -- Gather initial state for logging
    local vel = ply:GetVelocity()
    local speed = vel:Length()
    local eyePos = ply:EyePos()
    local groundTrace = util.TraceLine({
        start = eyePos,
        endpos = eyePos - Vector(0, 0, 1000),
        filter = ply,
        mask = MASK_SOLID
    })
    local distToGround = groundTrace.Hit and groundTrace.HitPos:Distance(eyePos) or 1000
    
    -- Debug info about current state
    if GetConVar("developer"):GetBool() then
        print("\n[Web Shooter] Starting point search:")
        print(string.format("  Speed: %.1f, Height: %.1f", speed, distToGround))
        print(string.format("  Preferences - Assist: %.1f, Momentum: %.1f, Safety: %.1f", 
            assistStrength, momentumFactor, groundSafety))
    end
    
    local candidates = self:GatherSwingPointCandidates()
    if #candidates == 0 then
        if GetConVar("developer"):GetBool() then
            print("[Web Shooter] No candidates found from initial search")
        end
    else
        if GetConVar("developer"):GetBool() then
            print(string.format("[Web Shooter] Found %d initial candidates", #candidates))
        end
    end
    
    local playerState = {
        velocity = vel,
        onGround = ply:IsOnGround(),
        eyePos = eyePos,
        aimVector = ply:GetAimVector()
    }
    
    local bestCandidate = nil
    local bestScore = -1
    local debugScores = {}
    
    for i, candidate in ipairs(candidates) do
        local score = self:EvaluateSwingCandidate(candidate, playerState, candidates)
        
        -- Store debug info about scoring
        if GetConVar("developer"):GetBool() then
            table.insert(debugScores, {
                pos = candidate.pos,
                type = candidate.type,
                score = score,
                height = candidate.pos.z - eyePos.z,
                dist = candidate.pos:Distance(eyePos)
            })
        end
        
        if score > bestScore then
            bestScore = score
            bestCandidate = candidate
        end
    end
    
    -- Log detailed scoring info if in developer mode
    if GetConVar("developer"):GetBool() and #debugScores > 0 then
        print("\n[Web Shooter] Candidate Scores:")
        table.sort(debugScores, function(a, b) return a.score > b.score end)
        for i, info in ipairs(debugScores) do
            if i <= 3 then -- Only show top 3 scores
                print(string.format("  %d. Type: %s, Score: %.2f, Height: %.1f, Dist: %.1f",
                    i, info.type, info.score, info.height, info.dist))
            end
        end
    end
    
    -- If no good candidate found or score is too low, use fallback
    if not bestCandidate or bestScore < 0.2 then
        if GetConVar("developer"):GetBool() then
            print("[Web Shooter] Using fallback trace due to " .. 
                (not bestCandidate and "no candidate" or "low score"))
        end
        
        -- Calculate fallback range based on speed
        local fallbackRange = math.Clamp(300 + speed * 0.5, 300, 1000)
        
        -- Try direct aim trace first
        local aimTrace = util.TraceLine({
            start = eyePos,
            endpos = eyePos + ply:GetAimVector() * fallbackRange,
            filter = ply,
            mask = MASK_SOLID
        })
        
        if aimTrace.Hit then
            if GetConVar("developer"):GetBool() then
                print(string.format("[Web Shooter] Fallback found point at distance %.1f",
                    aimTrace.HitPos:Distance(eyePos)))
            end
            
            return {
                pos = aimTrace.HitPos,
                normal = aimTrace.HitNormal,
                entity = aimTrace.Entity
            }
        end
        
        -- If direct trace fails and we're close to ground, try upward trace
        if distToGround < 200 then
            local upTrace = util.TraceLine({
                start = eyePos,
                endpos = eyePos + Vector(0, 0, fallbackRange * 0.7),
                filter = ply,
                mask = MASK_SOLID
            })
            
            if upTrace.Hit then
                if GetConVar("developer"):GetBool() then
                    print("[Web Shooter] Using emergency upward point")
                end
                
                return {
                    pos = upTrace.HitPos,
                    normal = upTrace.HitNormal,
                    entity = upTrace.Entity
                }
            end
        end
        
        if GetConVar("developer"):GetBool() then
            print("[Web Shooter] No valid point found, even with fallback")
        end
        return nil
    end
    
    if GetConVar("developer"):GetBool() then
        print(string.format("[Web Shooter] Selected point: Type=%s, Score=%.2f",
            bestCandidate.type, bestScore))
    end
    
    return {
        pos = bestCandidate.pos,
        normal = bestCandidate.normal,
        entity = bestCandidate.entity,
        score = bestScore,
        type = bestCandidate.type
    }
end

-- Function to check if a point is a building corner
function SWEP:IsCornerPoint(hitPos, hitNormal)
    -- Reduced check distance for better accuracy and performance
    local checkDist = 20  -- Reduced from 30
    
    -- Only check perpendicular directions relative to hit normal
    local right = hitNormal:Cross(Vector(0, 0, 1)):GetNormalized()
    local up = right:Cross(hitNormal):GetNormalized()
    
    local directions = {
        right,
        right * -1,
        up,
        up * -1
    }
    
    local gaps = 0
    local traces = 0 -- Track number of traces performed
    
    for _, dir in ipairs(directions) do
        -- Skip if we've already found enough gaps or too many traces
        if gaps >= 2 or traces >= 3 then break end
        
        -- Skip direction if it's too close to hit normal
        if math.abs(dir:Dot(hitNormal)) > 0.1 then continue end
        
        traces = traces + 1
        local tr = util.TraceLine({
            start = hitPos + hitNormal * 2, -- Reduced offset for more accurate corner detection
            endpos = hitPos + hitNormal * 2 + dir * checkDist,
            mask = MASK_SOLID
        })
        
        if not tr.Hit then
            gaps = gaps + 1
        end
    end
    
    return gaps >= 2  -- If there are 2 or more gaps, it's likely a corner
end

-- Function to evaluate how good a swing point is
function SWEP:EvaluateSwingPoint(point, playerPos, playerVel, isCorner, speedSqr, isCeiling)
    local score = 0
    speedSqr = speedSqr or 0
    
    -- Distance factor (prefer points at medium distance)
    local dist = point:Distance(playerPos)
    local optimalDist = math.Clamp(500 + speedSqr * 0.01, 300, 800)
    local distScore = 1 - math.abs(dist - optimalDist) / optimalDist
    score = score + distScore * 0.3
    
    -- Height factor using map-specific optimal height
    local heightDiff = point.z - playerPos.z
    if heightDiff < 0 and not isCeiling then
        -- Allow downward points but with adjusted scoring
        local downwardPenalty = math.abs(heightDiff) / 1000 -- Less severe penalty
        score = score - downwardPenalty * 0.3 -- Reduced penalty multiplier
        
        -- If moving fast enough, allow downward points more freely
        if playerVel and playerVel:Length() > 200 then
            score = score + 0.2 -- Bonus for maintaining momentum while swinging down
        end
    else
        -- For ceiling points, prefer points directly above or slightly ahead
        if isCeiling then
            -- Calculate horizontal distance to point
            local horizontalDist = Vector(point.x - playerPos.x, point.y - playerPos.y, 0):Length()
            -- Prefer points slightly ahead of the player when moving
            local optimalHorizDist = playerVel:Length() > 100 and 100 or 0
            local horizScore = 1 - math.abs(horizontalDist - optimalHorizDist) / 200
            score = score + horizScore * 0.4
            
            -- Bonus for being high enough but not too high
            local optimalHeight = math.Clamp(heightDiff, 100, 300)
            score = score + (optimalHeight / 300) * 0.3
        else
            local optimalHeight = self.OptimalSwingHeight or 150
            optimalHeight = optimalHeight * GetConVar("webswing_map_height_mult"):GetFloat()
            local heightScore = 1 - math.abs(heightDiff - optimalHeight) / optimalHeight
            heightScore = math.Clamp(heightScore, 0, 1)
            score = score + heightScore * 0.3
        end
    end
    
    -- Momentum factor (prefer points that maintain momentum)
    if playerVel and playerVel:Length() > 50 then
        local velDir = playerVel:GetNormalized()
        local toPoint = (point - playerPos):GetNormalized()
        local dotProduct = velDir:Dot(toPoint)
        
        -- For ceiling points, we want to maintain forward momentum
        if isCeiling then
            local horizontalVel = Vector(velDir.x, velDir.y, 0):GetNormalized()
            local horizontalToPoint = Vector(toPoint.x, toPoint.y, 0):GetNormalized()
            dotProduct = horizontalVel:Dot(horizontalToPoint)
        end
        
        local momentumScore = math.Clamp(dotProduct + 1, 0, 1)
        score = score + momentumScore * 0.3
    end
    
    -- Corner bonus
    if isCorner then
        score = score + 0.2
    end
    
    -- Ceiling bonus
    if isCeiling then
        score = score + 0.3
    end
    
    -- Ensure downward points are still possible by setting a minimum score
    if heightDiff < 0 and score > -0.5 then
        score = math.max(score, 0.1) -- Ensure a minimum positive score for valid downward points
    end
    
    return score
end

-- Function to update parameters based on map analysis
function SWEP:UpdateMapParameters()
    -- Store the original range before adjusting
    self.BaseRange = self.Range or 2000
    
    -- Only adjust range for AI mode
    if not GetConVar("webswing_manual_mode"):GetBool() then
        -- Adjust search radius based on building density
        local baseRadius = self.BaseRange
        self.Range = baseRadius * (1 + (1 - self.MapAnalysis.buildingDensity) * 0.5)
    else
        -- In manual mode, use the base range
        self.Range = self.BaseRange
    end
    
    -- Adjust optimal swing height based on average building height
    local optimalHeightRatio = math.Clamp(self.MapAnalysis.averageHeight / 1000, 0.5, 2)
    self.OptimalSwingHeight = 150 * optimalHeightRatio
    
    -- Adjust number of search points based on building density
    self.SearchPoints = math.floor(16 * (1 + self.MapAnalysis.buildingDensity))
    
    -- Create ConVars if they don't exist
    if SERVER then
        if not GetConVar("webswing_map_height_mult") then
            CreateConVar("webswing_map_height_mult", "1", FCVAR_ARCHIVE, "Multiplier for optimal swing height")
        end
        if not GetConVar("webswing_map_range_mult") then
            CreateConVar("webswing_map_range_mult", "1", FCVAR_ARCHIVE, "Multiplier for web range")
        end
    end
end

if SERVER then
    util.AddNetworkString("WebSwing_NoclipSpeed")
end

if CLIENT then
    net.Receive("WebSwing_NoclipSpeed", function()
        local shouldRestrict = net.ReadBool()
        if shouldRestrict then
            LocalPlayer():SetNWFloat("sv_noclipspeed", 0)
        end
    end)
end

-- Add sound sets table before any other SWEP functionality
SWEP.SoundSets = {
    ["Tom Holland"] = {
        web_shoot = {
            "webshooters/web_shoot1.wav",
            "webshooters/web_shoot2.wav",
            "webshooters/web_shoot3.wav"
        },
        web_jump = {
            "webshooters/web_jump1.wav",
            "webshooters/web_jump2.wav"
        }
    },
    ["Tobey Maguire"] = {
        web_shoot = {
            "webshooters/web_shoot1.wav",
            "webshooters/web_shoot2.wav",
            "webshooters/web_shoot3.wav"
        },
        web_jump = {
            "webshooters/web_jump1.wav",
            "webshooters/web_jump2.wav"
        }
    },
    ["Andrew Garfield"] = {
        web_shoot = {
            "webshooters/web_shoot_andrew1.wav",
            "webshooters/web_shoot2.wav",
            "webshooters/web_shoot3.wav"
        },
        web_jump = {
            "webshooters/web_jump1.wav",
            "webshooters/web_jump2.wav"
        }
    },
    ["PS1 Spider-Man"] = {
        web_shoot = {
            "webshooters/ps1_web_shoot.wav",
            "webshooters/ps1_web_shoot.wav",
            "webshooters/ps1_web_shoot.wav"
        },
        web_jump = {
            "webshooters/ps1_web_detach.wav",
            "webshooters/ps1_web_detach.wav"
        }
    },
    ["Insomniac Spider-Man"] = {
        web_shoot = {
            "webshooters/insomniac_web_shoot1.wav",
            "webshooters/insomniac_web_shoot2.wav",
            "webshooters/insomniac_web_shoot3.wav",
            "webshooters/insomniac_web_shoot4.wav"
        },
        web_jump = {
            "webshooters/insomniac_web_detach1.wav",
            "webshooters/insomniac_web_detach2.wav",
            "webshooters/insomniac_web_detach3.wav"
        }
    }
}

-- Function to get current sound set
function SWEP:GetCurrentSoundSet()
    local soundSet = "Tom Holland" -- Default sound set
    if CLIENT then
        soundSet = GetConVar("webswing_sound_set"):GetString()
    elseif SERVER then
        local ply = self.Owner
        if IsValid(ply) then
            soundSet = ply:GetInfo("webswing_sound_set")
        end
    end
    return self.SoundSets[soundSet] or self.SoundSets["Tom Holland"]
end

-- Function to play web shoot sound
function SWEP:PlayWebShootSound()
    if SERVER then
        local soundSet = self:GetCurrentSoundSet()
        local sounds = soundSet.web_shoot
        local soundNumber = math.random(1, #sounds)
        local volume = math.Clamp(1 - (self.WebSoundCount / self.MaxWebSoundCount) * 0.3, 0.7, 1)
        local pitch = math.Clamp(100 + math.random(-5, 10) - (self.WebSoundCount * 2), 95, 110)
        self.Owner:EmitSound(sounds[soundNumber], 75, pitch, volume)
    end
end

-- Function to play web jump sound
function SWEP:PlayWebJumpSound()
    if SERVER then
        local soundSet = self:GetCurrentSoundSet()
        local sounds = soundSet.web_jump
        local soundNumber = math.random(1, #sounds)
        self.Owner:EmitSound(sounds[soundNumber], 75, math.random(98, 102), 1)
    end
end

-- Add this helper function near the top of the file
function SWEP:SafelyCopyPlayerData(ply)
    if not IsValid(ply) then return nil end
    
    -- Check if duplicator library exists and is not restricted
    if duplicator and duplicator.CopyEntTable then
        local success, result = pcall(function()
            return duplicator.CopyEntTable(ply)
        end)
        if success and result then
            return result
        end
    end
    
    -- Fallback: Create minimal entity data manually
    return {
        Pos = ply:GetPos(),
        Angle = ply:GetAngles(),
        Model = ply:GetModel(),
        Skin = ply:GetSkin(),
        Bodygroups = ply:GetBodyGroups(),
        ModelScale = ply:GetModelScale(),
        Material = ply:GetMaterial(),
        Color = ply:GetColor(),
        RenderMode = ply:GetRenderMode(),
        RenderFX = ply:GetRenderFX()
    }
end

-- Add this helper function to safely apply entity data
function SWEP:SafelyApplyEntityData(ent, data)
    if not IsValid(ent) or not data then return false end
    
    local success = pcall(function()
        -- Apply basic properties
        ent:SetPos(data.Pos or Vector(0,0,0))
        ent:SetAngles(data.Angle or Angle(0,0,0))
        ent:SetModel(data.Model or "models/player/kleiner.mdl")
        ent:SetSkin(data.Skin or 0)
        ent:SetModelScale(data.ModelScale or 1, 0)
        
        -- Apply visual properties
        if data.Material then ent:SetMaterial(data.Material) end
        if data.Color then ent:SetColor(data.Color) end
        if data.RenderMode then ent:SetRenderMode(data.RenderMode) end
        if data.RenderFX then ent:SetRenderFX(data.RenderFX) end
        
        -- Apply bodygroups if available
        if data.Bodygroups then
            for _, bg in ipairs(data.Bodygroups) do
                ent:SetBodygroup(bg.id or 0, bg.num or 0)
            end
        end
        
        -- If duplicator is available, try to use it for additional properties
        if duplicator and duplicator.DoGeneric then
            duplicator.DoGeneric(ent, data)
        end
    end)
    
    return success
end

-- Add cleanup function
function SWEP:CleanupWebSwing()
    if not IsValid(self.Owner) then return end
    
    -- Stop web swing if active
    if self.RagdollActive then
        self:StopWebSwing()
    end
    
    -- Ensure hooks are removed
    hook.Remove("CalcView", "SpiderManView")
    hook.Remove("Move", "WebSwing_NoclipSpeed_" .. self.Owner:EntIndex())
    
    if SERVER then
        -- Restore original states if they exist
        if self.OriginalStates then
            self.Owner:SetMoveType(self.OriginalStates.moveType)
            self.Owner:SetWalkSpeed(self.OriginalStates.walkSpeed)
            self.Owner:SetRunSpeed(self.OriginalStates.runSpeed)
            self.Owner:SetJumpPower(self.OriginalStates.jumpPower)
            self.Owner:SetColor(self.OriginalStates.color)
            self.Owner:SetRenderMode(self.OriginalStates.renderMode)
            self.Owner:SetNoDraw(self.OriginalStates.noDraw)
            self.Owner:SetNWFloat("sv_noclipspeed", self.OriginalStates.noclipSpeed)
            
            -- Clear stored states
            self.OriginalStates = nil
        else
            -- Fallback to default states if original states weren't stored
            self.Owner:SetMoveType(MOVETYPE_WALK)
            self.Owner:SetColor(Color(255, 255, 255, 255))
            self.Owner:SetRenderMode(RENDERMODE_NORMAL)
            self.Owner:SetNoDraw(false)
        end
        
        -- Clean up any active ragdoll
        if IsValid(self.Ragdoll) then
            SafeRemoveEntity(self.Ragdoll)
        end
    end
    
    if CLIENT then
        -- Restore viewmodel visibility
        self.Owner:DrawViewModel(true)
        local vm = self.Owner:GetViewModel()
        if IsValid(vm) then
            self:ResetBonePositions(vm)
        end
    end
end

function SWEP:OnRemove()
    self:CleanupWebSwing()
end

function SWEP:OnDrop()
    self:CleanupWebSwing()
end

-- Add this function to handle safe position finding that was moved from StopWebSwing
function SWEP:FindSafePosition(pos)
    if not IsValid(self.Owner) then return pos end
    local ply = self.Owner
    
    local function TestPosition(testPos)
        -- Check for corners at the test position
        local inCorner = self:IsInCorner(testPos, {ply})
        if inCorner then return false end
        
        -- Check if position is safe for player
        local tr = util.TraceHull({
            start = testPos,
            endpos = testPos,
            mins = Vector(-16, -16, 0),
            maxs = Vector(16, 16, 72),
            filter = ply,
            mask = MASK_SOLID
        })
        
        return not tr.Hit
    end
    
    -- Try positions in a spiral pattern, moving outward and upward
    local attempts = {}
    for i = 0, 360, 45 do
        for dist = 0, 64, 32 do
            for height = 0, 64, 32 do
                local rad = math.rad(i)
                local offset = Vector(
                    math.cos(rad) * dist,
                    math.sin(rad) * dist,
                    height
                )
                table.insert(attempts, offset)
            end
        end
    end
    
    -- Try each position
    for _, offset in ipairs(attempts) do
        local testPos = pos + offset
        if TestPosition(testPos) then
            return testPos
        end
    end
    
    -- If no safe position found, move up and away from walls
    local tr = util.TraceHull({
        start = pos,
        endpos = pos,
        mins = Vector(-16, -16, 0),
        maxs = Vector(16, 16, 72),
        filter = ply,
        mask = MASK_SOLID
    })
    
    if tr.Hit then
        return pos + tr.HitNormal * 64 + Vector(0, 0, 64)
    end
    
    return pos
end

-- Add this new function to calculate optimal sky height
function SWEP:CalculateOptimalSkyHeight(eyePos, velocity, distToGround)
    local baseHeight = 800 -- Base minimum height
    local speed = velocity:Length()
    
    -- Factor in current height from ground
    local heightFromGround = math.max(distToGround, 100)
    
    -- Factor in player's speed (faster = higher ceiling needed)
    local speedFactor = math.Clamp(speed / 1000, 0, 1) -- Normalize speed
    local speedHeight = speedFactor * 1000 -- Up to 1000 units extra height based on speed
    
    -- Factor in map analysis if available
    local mapFactor = 1
    if self.MapAnalysis and self.MapAnalysis.analyzed then
        -- Use average building height as a reference
        mapFactor = math.Clamp(self.MapAnalysis.averageHeight / 1000, 0.5, 2)
    end
    
    -- Calculate final height
    local optimalHeight = (baseHeight + speedHeight) * mapFactor
    
    -- Ensure minimum height relative to player
    optimalHeight = math.max(optimalHeight, heightFromGround + 400)
    
    -- Cap maximum height
    return math.min(optimalHeight, 3000)
end