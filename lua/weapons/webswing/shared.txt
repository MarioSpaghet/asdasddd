local ModelInfoCache
ModelInfoCache = {
	Info = {},
	Exists = function(mdl)
		return ModelInfoCache.Info[mdl]~=nil
	end,
	Prepare = function(mdl,ply)
		local Data = duplicator.CopyEntTable( ply )
		local ragdoll = ents.Create( "prop_ragdoll" )
			duplicator.DoGeneric( ragdoll, Data )
			ragdoll:Spawn()
			local physObjs = ragdoll:GetPhysicsObjectCount() --get number of phys-bones in ragdoll
		ragdoll:Remove()
		ModelInfoCache.Info[mdl] = physObjs
		--print("Cache: Made a ragdoll but didnt spawn it")
		--print("Cache: It has",physObjs,"physics objects")
	end,
	Get = function(mdl)
		return ModelInfoCache.Info[mdl]
	end,
	GimmeDatNumber = function(mdl,ply)
		if not ModelInfoCache.Exists(mdl) then
			ModelInfoCache.Prepare(mdl,ply)
		end
		return ModelInfoCache.Get(mdl)
	end
} --this is hopefully shared between all instances of the weapons so that we dont spam too many ragdolls when trying to find bone counts
	
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

-- *** Move the following block to the top of the file, outside of any functions ***
if SERVER then
	-- Add network strings for setting rope material
	util.AddNetworkString("WebSwing_SetRopeMaterial")
	
	-- Add network string for toggling manual mode
	util.AddNetworkString("WebSwing_ToggleManualMode")
	
	-- Function to handle setting rope material
	net.Receive("WebSwing_SetRopeMaterial", function(len, ply)
		-- Permission check: Only allow admins to set the rope material
		if ply:IsAdmin() then
			local material = net.ReadString()
			RunConsoleCommand("webswing_rope_material", material)
			print(ply:Nick() .. " set webswing_rope_material to " .. material)
		else
			ply:ChatPrint("You do not have permission to change the rope material.")
		end
	end)
	
	-- Function to handle toggling manual mode
	net.Receive("WebSwing_ToggleManualMode", function(len, ply)
		-- No admin restriction; allow all players to toggle manual mode
		local currentMode = GetConVar("webswing_manual_mode"):GetBool()
		local newMode = not currentMode
		RunConsoleCommand("webswing_manual_mode", newMode and "1" or "0")
		ply:ChatPrint("Manual mode set to " .. tostring(newMode))
		print(ply:Nick() .. " set webswing_manual_mode to " .. tostring(newMode))
	end)
	
	-- Define a new ConVar for rope material
	CreateConVar("webswing_rope_material", "cable/xbeam", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Material used for the web rope")

	CreateConVar("webswing_swing_speed", "800", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Base swing force when using web swing", 1, 90000)

	CreateConVar("webswing_manual_mode", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Use manual web-swing mode (old style)", 0, 1)

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

	-- Add this near the top of the file with other ConVars
	CreateConVar("webswing_rope_alpha", "255", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Alpha transparency of the web rope (0-255)", 0, 255)
	CreateConVar("webswing_rope_color_r", "255", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Red component of web rope color (0-255)", 0, 255)
	CreateConVar("webswing_rope_color_g", "255", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Green component of web rope color (0-255)", 0, 255)
	CreateConVar("webswing_rope_color_b", "255", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Blue component of web rope color (0-255)", 0, 255)
end
-- *** End of moved block ***

-- Add this near the top of the file with other global variables
local MapAnalysisData = {}

-- Function to analyze the map
function SWEP:AnalyzeMap()
    if SERVER then
        local mapName = game.GetMap()
        
        -- Check if we already analyzed this map
        if MapAnalysisData[mapName] then
            self.MapAnalysis = table.Copy(MapAnalysisData[mapName])
            self:UpdateMapParameters()
            return
        end
        
        print("[Web Shooters] Analyzing map: " .. mapName)
        
        -- Parameters for analysis
        local scanHeight = 5000
        local scanSteps = 20
        local scanRadius = 10000
        local totalPoints = 0
        local hitPoints = 0
        local heightSum = 0
        local maxHeight = 0
        
        -- Grid scan the map
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
        
        -- Calculate map metrics
        self.MapAnalysis.averageHeight = heightSum / hitPoints
        self.MapAnalysis.buildingDensity = hitPoints / totalPoints
        
        -- Scan for open spaces
        local openSpaces = 0
        local scanPoints = 100
        for i = 1, scanPoints do
            local randPos = Vector(
                math.random(-scanRadius, scanRadius),
                math.random(-scanRadius, scanRadius),
                100
            )
            
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
        self.MapAnalysis.openSpaceRatio = openSpaces / scanPoints
        
        -- Store the analysis for future use
        MapAnalysisData[mapName] = table.Copy(self.MapAnalysis)
        
        -- Adjust web-shooting parameters based on map analysis
        self:UpdateMapParameters()
        
        self.MapAnalysis.analyzed = true
        print("[Web Shooters] Map Analysis Complete:")
        print("  Average Height: " .. math.floor(self.MapAnalysis.averageHeight))
        print("  Building Density: " .. string.format("%.2f", self.MapAnalysis.buildingDensity))
        print("  Open Space Ratio: " .. string.format("%.2f", self.MapAnalysis.openSpaceRatio))
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
    
    -- Initialize sound fatigue system variables
    self.LastWebSoundTime = CurTime()
    self.WebSoundCount = 0
    
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
local STANDARD_RAGDOLL_MASS = 1

-- Add this near the top with other SWEP variables
SWEP.BaseRange = 1000  -- Reduced from 2000 to 1000 for better control
SWEP.MaxWebLength = 1500  -- Maximum length the web can be stretched

function SWEP:PrimaryAttack()
    -- Do nothing
end

function SWEP:SecondaryAttack()
    if not IsFirstTimePredicted() then return end

    if self.Owner:KeyPressed(IN_ATTACK2) then
        -- Check for valid hit point before restricting movement
        local tr
        if GetConVar("webswing_manual_mode"):GetBool() then
            tr = util.TraceLine({
                start = self.Owner:EyePos(),
                endpos = self.Owner:EyePos() + self.Owner:GetAimVector() * self.BaseRange,
                filter = self.Owner,
                mask = MASK_SOLID
            })
            -- If no hit point is found, allow player to continue falling
            if not tr.Hit then return end
        else
            local bestPoint = self:FindPotentialSwingPoints()
            if not bestPoint or not bestPoint.pos or not bestPoint.normal then return end
            tr = {
                Hit = true,
                HitPos = bestPoint.pos,
                HitNormal = bestPoint.normal,
                Entity = game.GetWorld(),
                StartPos = self.Owner:EyePos(),
                PhysicsBone = 0
            }
        end

        -- Only restrict movement if we have a valid swing point
        if SERVER then
            self.Owner.OriginalNoclipSpeed = self.Owner:GetNWFloat("sv_noclipspeed", 5)
            self.Owner:SetNWFloat("sv_noclipspeed", 0)
            net.Start("WebShooterNoclipSpeed")
            net.WriteBool(true)
            net.Send(self.Owner)
        end
        
        -- Add movement restriction only if we have a valid point
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
    if not self.Owner then return end
    local ply = self.Owner
    
    self:SetNextPrimaryFire(CurTime() + 0.1)
    
    if not tr or not tr.Hit then return end
    
    -- Ensure tr.Entity exists
    tr.Entity = tr.Entity or game.GetWorld()
    
    local maxRange = GetConVar("webswing_manual_mode"):GetBool() and self.BaseRange or self.Range
    if tr.HitPos:Distance(tr.StartPos or self.Owner:EyePos()) >= maxRange then return end
    
    if hook.Run("CanTool", ply, tr, "webswing") == false then
        return
    end
    
    if SERVER then
        -- Initialize sound variables if they don't exist
        self.LastWebSoundTime = self.LastWebSoundTime or CurTime()
        self.WebSoundCount = self.WebSoundCount or 0
        
        -- Sound fatigue system
        local currentTime = CurTime()
        local timeSinceLastSound = currentTime - self.LastWebSoundTime
        
        -- Reset sound count if enough time has passed
        if timeSinceLastSound > self.WebSoundResetTime then
            self.WebSoundCount = 0
        end
        
        -- Only play sound if cooldown has passed
        if timeSinceLastSound > self.WebSoundCooldown then
            -- Increment sound count
            self.WebSoundCount = self.WebSoundCount + 1
            self.LastWebSoundTime = currentTime
            
            -- Calculate volume and pitch based on fatigue
            local volume = math.Clamp(1 - (self.WebSoundCount / self.MaxWebSoundCount) * 0.3, 0.7, 1)
            -- Adjusted pitch range to 95-110
            local pitch = math.Clamp(100 + math.random(-5, 10) - (self.WebSoundCount * 2), 95, 110)
            
            -- Play the sound with varied parameters
            local soundNumber = math.random(1, 3)
            ply:EmitSound("webshooters/web_shoot" .. soundNumber .. ".wav", 75, pitch, volume)
        end
    end
    
    self.RagdollActive = true
    self:ShootEffects(self)
    
    if (!SERVER) then return end
    
    -- Web decal feature
    if SERVER then
        local webDecal = "decals/spiderman_web"
        util.Decal(webDecal, tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal)
    end
    
    self:SetNetworkedBool("wt_ragdollactive", true)
    
    local OldBoneScale = ply:GetModelScale()
    ply:SetModelScale(1, 0)
    
    local Data = duplicator.CopyEntTable(ply)
    local ragdoll = ents.Create("prop_ragdoll")
    if not IsValid(ragdoll) then return end
    duplicator.DoGeneric(ragdoll, Data)
    ragdoll:Spawn()
    ragdoll:Activate()
    
    -- Standardize the mass of all physics objects in the ragdoll
    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local phys = ragdoll:GetPhysicsObjectNum(i)
        if phys:IsValid() then
            phys:SetMass(STANDARD_RAGDOLL_MASS)
        end
    end
    
    ply:SetModelScale(OldBoneScale, 0)
    
    if isfunction(ragdoll.CPPISetOwner) then
        ragdoll:CPPISetOwner(ply)
    else
        ragdoll.Owner = ply
        ragdoll.OwnerID = ply:SteamID()
    end

    local vel = ply:GetVelocity()

    local targetPhysObj = self:GetTargetBone()
    local targetBone = 0
    local targetFound = false
    local bonePos, boneAng, bonePosL
    
    bonePos = ragdoll:GetPos()
    
    local iNumPhysObjects = ragdoll:GetPhysicsObjectCount()
    for Bone = 0, iNumPhysObjects - 1 do
        local PhysObj = ragdoll:GetPhysicsObjectNum(Bone)
        if (PhysObj:IsValid()) then
            local boneid = ragdoll:TranslatePhysBoneToBone(Bone)
            local Pos, Ang = ply:GetBonePosition(boneid)
            PhysObj:SetPos(Pos)
            PhysObj:SetAngles(Ang)
            PhysObj:AddVelocity(vel)
            if Bone == targetPhysObj then
                bonePos, boneAng = Pos, Ang
                bonePosL = PhysObj:LocalToWorld(Vector(0, 0, 0))
                targetBone = Bone
                targetFound = true
                break
            end
        end
    end

    if not targetFound then
        bonePos = ragdoll:GetPos()
        targetBone = 0
    end

    local useRope = ply:KeyDown(IN_USE)
    
    if not useRope then
        local class = IsValid(tr.Entity) and tr.Entity:GetClass() or ""
        if class == "prop_ragdoll" then
            local IsOk = false
            local Phys = tr.Entity:GetPhysicsObject()
            if IsValid(Phys) then
                if Phys:IsGravityEnabled() then
                    IsOk = true
                end
            end
            if not IsOk then
                useRope = true
            end
        end
    end
    
    ply:SetParent(ragdoll)
    ply:SetMoveType(MOVETYPE_NOCLIP)
    ply:SetVelocity(Vector(0, 0, 0))
    if SERVER then
        -- Store the player's original noclip speed
        ply.OriginalNoclipSpeed = ply:GetNWFloat("sv_noclipspeed", 5)
        
        -- Set personal noclip speed to 0 immediately (removed delay)
        ply:SetNWFloat("sv_noclipspeed", 0)
        
        -- Override the player's movement without delay
        hook.Add("Move", "WebSwing_NoclipSpeed_" .. ply:EntIndex(), function(moveply, mv)
            if moveply == ply and ply.WT_webswing_Roping then
                mv:SetVelocity(Vector(0, 0, 0))
                return true
            end
        end)
    end
    ply:SpectateEntity(ragdoll)
    
    -- Add this line to keep the HUD visible
    ply:DrawWorldModel(false)
    
    ragdoll.DontAllowRemoval = true
    ragdoll.DontAllowRape = true
    ply.WT_webswing_Roping = true
    self.Ragdoll = ragdoll
    
    local TimerID = "" .. CurTime() .. "/" .. math.random() .. "/" .. math.random(100)
    timer.Create(TimerID, 1 + math.random(), 0, function()
        if not IsValid(ply) then
            SafeRemoveEntity(ragdoll)
            timer.Destroy(TimerID)
        end
    end)
    
    local LPos1, LPos2
    LPos1 = Vector(0, 0, 0)
    LPos2 = (tr.Entity:EntIndex() ~= 0) and (tr.HitPos - tr.Entity:GetPos()) or tr.HitPos
    local WPos1, WPos2 = bonePos, tr.HitPos
    local Distance = math.floor(WPos1:Distance(WPos2))
    local EndBoneID = 0
    local EndPhysBoneObj
    if IsValid(tr.Entity) and tr.Entity:GetClass() == "prop_ragdoll" then
        local EndPhysBoneIndex = tr.PhysicsBone or 0
        EndPhysBoneObj = tr.Entity:GetPhysicsObjectNum(EndPhysBoneIndex)
        EndBoneID = EndPhysBoneIndex
        LPos2 = EndPhysBoneObj:WorldToLocal(WPos2)
    end
    
    -- Retrieve the selected rope material from the ConVar
    local ropeMaterial = GetConVar("webswing_rope_material"):GetString()

    -- Set rope width based on material
    local ropeWidth = 2  -- Default width for other materials
    if ropeMaterial == "cable/redlaser" then
        ropeWidth = 5  -- Slightly increased width for 'cable/redlaser'
    elseif ropeMaterial == "cable/rope" then
        ropeWidth = 1  -- Even thinner for 'cable/rope'
     elseif ropeMaterial == "cable/cable2" then
        ropeWidth = 1.25  -- Even thinner for 'cable/cable2'
    end

    -- Get color and alpha values from ConVars
    local ropeColor = Color(
        GetConVar("webswing_rope_color_r"):GetInt(),
        GetConVar("webswing_rope_color_g"):GetInt(),
        GetConVar("webswing_rope_color_b"):GetInt(),
        GetConVar("webswing_rope_alpha"):GetInt()
    )

    if useRope then
        local length_constraint, rope = constraint.Rope(
            ragdoll, tr.Entity, targetBone, EndBoneID,
            LPos1, LPos2, 0, Distance * 0.95, 0, ropeWidth,
            ropeMaterial, false
        )

        if rope then
            rope:SetKeyValue('spawnflags', '1')
            rope:SetKeyValue('minCPULevel', '0')
            rope:SetKeyValue('maxCPULevel', '0')
            rope:SetKeyValue('updaterate', '1')
            -- Enhanced alpha and rendering settings
            rope:SetRenderMode(RENDERMODE_TRANSALPHA)
            rope:SetColor(ropeColor)
            rope:SetKeyValue('renderamt', tostring(ropeColor.a))
            rope:SetKeyValue('rendercolor', string.format("%d %d %d", ropeColor.r, ropeColor.g, ropeColor.b))
            rope:SetKeyValue('rendermode', '5') -- 5 is RENDERMODE_TRANSCOLOR for better alpha handling
            rope:SetKeyValue('renderorder', '1') -- Higher render order to ensure proper layering
            rope:SetMaterial(ropeMaterial)
            rope:DrawShadow(false)
        else
            print("Error: Failed to create rope.")
            self.RagdollActive = false
            return
        end

        if length_constraint then
            self.ConstraintController = {
                current_length = Distance * 0.95,
                constraint = length_constraint,
                rope = rope,
                speed = 5,
                Set = function(self)
                    if IsValid(self.constraint) then self.constraint:Fire("SetLength", self.current_length, 0) end
                    if IsValid(self.rope) then self.rope:Fire("SetLength", self.current_length, 0) end
                end,
                Shorten = function(self)
                    self.current_length = math.Clamp(self.current_length - self.speed, self.min_length, self.max_length)
                    self:Set()
                end,
                Slacken = function(self)
                    self.current_length = math.Clamp(self.current_length + self.speed, self.min_length, self.max_length)
                    self:Set()
                end
            }
            self.ConstraintController:Set()
        else
            print("Error: Failed to create length constraint.")
            self.RagdollActive = false
            return
        end
    else
        local const, damp = CalcElasticConstant(
            ragdoll:GetPhysicsObjectNum(targetBone),
            tr.Entity:GetPhysicsObjectNum(EndBoneID),
            ragdoll, tr.Entity
        )

        local spring_constraint, rope = constraint.Elastic(
            ragdoll, tr.Entity, targetBone, EndBoneID,
            LPos1, LPos2, const * 5, damp * 5, 0,
            ropeMaterial, ropeWidth, true
        )

        if rope then
            rope:SetKeyValue('spawnflags', '1')
            rope:SetKeyValue('minCPULevel', '0')
            rope:SetKeyValue('maxCPULevel', '0')
            rope:SetKeyValue('updaterate', '1')
            rope:SetKeyValue('collide', '0')
            -- Enhanced alpha and rendering settings
            rope:SetRenderMode(RENDERMODE_TRANSALPHA)
            rope:SetColor(ropeColor)
            rope:SetKeyValue('renderamt', tostring(ropeColor.a))
            rope:SetKeyValue('rendercolor', string.format("%d %d %d", ropeColor.r, ropeColor.g, ropeColor.b))
            rope:SetKeyValue('rendermode', '5') -- 5 is RENDERMODE_TRANSCOLOR for better alpha handling
            rope:SetKeyValue('renderorder', '1') -- Higher render order to ensure proper layering
            rope:SetMaterial(ropeMaterial)
            rope:DrawShadow(false)
        else
            print("Error: Failed to create elastic rope.")
        end

        if spring_constraint then
            spring_constraint:SetKeyValue('spawnflags', '1')
            spring_constraint:SetKeyValue('minCPULevel', '0')
            spring_constraint:SetKeyValue('maxCPULevel', '0')
        else
            print("Error: Failed to create spring constraint.")
        end

        if spring_constraint and rope then
            self.ConstraintController = {
                current_length = Distance * 0.95,
                min_length = 10,
                max_length = self.Range,
                constraint = spring_constraint,
                rope = rope,
                speed = 5,
                Set = function(self)
                    if IsValid(self.constraint) then self.constraint:Fire("SetSpringLength", self.current_length, 0) end
                    if IsValid(self.rope) then self.rope:Fire("SetLength", self.current_length, 0) end
                end,
                Shorten = function(self)
                    self.current_length = math.Clamp(self.current_length - self.speed, self.min_length, self.max_length)
                    self:Set()
                end,
                Slacken = function(self)
                    self.current_length = math.Clamp(self.current_length + self.speed, self.min_length, self.max_length)
                    self:Set()
                end
            }
            self.ConstraintController:Set()
        else
            print("Error: Failed to create spring constraint or elastic rope.")
            self.RagdollActive = false
            return
        end
    end

    -- Make player invisible
    if SERVER then
        ply:SetNoDraw(true)  -- Makes the player model invisible
        ply:DrawWorldModel(false)
        ply:SetRenderMode(RENDERMODE_TRANSALPHA)
        ply:SetColor(Color(255, 255, 255, 0))  -- Make fully transparent
        
        -- Also handle any potential accessories or other attached entities
        for _, ent in pairs(ents.FindByClass("prop_physics")) do
            if ent:GetParent() == ply then
                ent:SetNoDraw(true)
            end
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
    
    self.Owner:EmitSound("webshooters/web_jump" .. math.random(1, 2) .. ".wav")
    
    self.RagdollActive = false

    if SERVER then
        ply:SetNoDraw(false)
        ply:DrawWorldModel(true)
        ply:SetRenderMode(RENDERMODE_NORMAL)
        ply:SetColor(Color(255, 255, 255, 255))
        
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
    ply:SetMoveType(MOVETYPE_WALK)
    
    if SERVER then
        hook.Remove("Move", "WebSwing_NoclipSpeed_" .. ply:EntIndex())
        if ply.OriginalNoclipSpeed then
            ply:SetNWFloat("sv_noclipspeed", ply.OriginalNoclipSpeed)
            ply.OriginalNoclipSpeed = nil
        end
    end

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
        
        -- Remove the ragdoll after 30 seconds
        timer.Create("WebRemoval_" .. rag:EntIndex(), 30, 1, function()
            if IsValid(rag) then
                SafeRemoveEntity(rag)
            end
        end)
    else
        SafeRemoveEntity(rag)
    end
    
    local respawnPos = ragValid and rag:GetPos() or ply:GetPos()

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
    
    respawnPos = FindSafePosition(respawnPos)

    ply:UnSpectate()
    SavedWeapons.Retrieve(ply)

    ply:SetPos(respawnPos)
    ply:SetVelocity(vel)
    ply:SetRenderMode(RENDERMODE_NORMAL)
    
    -- Enhanced unstuck system with corner detection
    if SERVER then
        local unstuckAttempts = 0
        local function AttemptUnstuck()
            if not IsValid(ply) or unstuckAttempts >= 5 then 
                timer.Remove("WebShooterUnstuck_" .. ply:EntIndex())
                return
            end
            
            local tr = util.TraceHull({
                start = ply:GetPos(),
                endpos = ply:GetPos(),
                mins = ply:OBBMins(),
                maxs = ply:OBBMaxs(),
                filter = ply,
                mask = MASK_SOLID
            })
            
            if tr.Hit then
                local newPos = FindSafePosition(ply:GetPos())
                ply:SetPos(newPos)
                unstuckAttempts = unstuckAttempts + 1
            else
                timer.Remove("WebShooterUnstuck_" .. ply:EntIndex())
            end
        end
        
        timer.Create("WebShooterUnstuck_" .. ply:EntIndex(), 0.1, 50, AttemptUnstuck)
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
    
    return true
end

function SWEP:OnRemove()
    -- Make sure to clean up the hook if the weapon is removed
    if SERVER and IsValid(self.Owner) then
        hook.Remove("Move", "WebSwing_NoclipSpeed_" .. self.Owner:EntIndex())
        if self.Owner.OriginalNoclipSpeed then
            self.Owner:SetNWFloat("sv_noclipspeed", self.Owner.OriginalNoclipSpeed)
            self.Owner.OriginalNoclipSpeed = nil
        end
    end
    self:Holster()
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
    return GetConVar("webswing_swing_speed"):GetFloat()
end

function SWEP:GetShortenSpeed()
    return GetConVar("webswing_swing_speed"):GetFloat() / 100 
end

-- Function to find potential swing points in the environment
function SWEP:FindPotentialSwingPoints()
    local ply = self.Owner
    if not IsValid(ply) then return nil end
    
    -- Initialize MapAnalysis if it doesn't exist
    if not self.MapAnalysis then
        self.MapAnalysis = {
            analyzed = false,
            averageHeight = 500,  -- Default values
            buildingDensity = 0.5,
            openSpaceRatio = 0.5
        }
    end
    
    -- Analyze map if not already done
    if not self.MapAnalysis.analyzed then
        self:AnalyzeMap()
    end
    
    local eyePos = ply:EyePos()
    local forward = ply:GetAimVector()
    local right = forward:Cross(Vector(0, 0, 1))
    local up = right:Cross(forward)
    
    -- Get player's current velocity for momentum calculations
    local playerVel = ply:GetVelocity()
    local speedSqr = playerVel:LengthSqr()
    
    -- Check for ceiling above player
    local ceilingTrace = util.TraceLine({
        start = eyePos,
        endpos = eyePos + Vector(0, 0, 500),
        filter = ply,
        mask = MASK_SOLID
    })
    
    local hasCeiling = ceilingTrace.Hit
    local ceilingPoint = nil
    if hasCeiling then
        -- Find best point on ceiling
        local ceilingRadius = 300  -- Search radius for ceiling points
        local bestCeilingScore = -1
        
        for i = 1, 8 do
            local angle = math.rad(((i - 1) / 8) * 360)
            local offset = Vector(
                math.cos(angle) * ceilingRadius,
                math.sin(angle) * ceilingRadius,
                0
            )
            
            local ceilingCheck = util.TraceLine({
                start = eyePos + Vector(0, 0, 200),  -- Start above player
                endpos = ceilingTrace.HitPos + offset,
                filter = ply,
                mask = MASK_SOLID
            })
            
            if ceilingCheck.Hit then
                local score = self:EvaluateSwingPoint(ceilingCheck.HitPos, eyePos, playerVel, false, speedSqr, true)
                if score > bestCeilingScore then
                    bestCeilingScore = score
                    ceilingPoint = {
                        pos = ceilingCheck.HitPos,
                        normal = ceilingCheck.HitNormal,
                        entity = ceilingCheck.Entity,
                        score = score,
                        isCorner = false,
                        isCeiling = true
                    }
                end
            end
        end
    end
    
    -- Use map-adjusted parameters for regular points
    local searchRadius = self.Range * GetConVarNumber("webswing_map_range_mult", 1)
    local numPoints = self.SearchPoints or 16
    local bestPoint = nil
    local bestScore = -1
    
    -- Search in a cone in front of the player
    for i = 1, numPoints do
        local angle = math.rad(((i - 1) / numPoints) * 360)
        local searchDir = forward + 
                         right * (math.cos(angle) * 0.5) + 
                         up * (math.sin(angle) * 0.5)
        searchDir:Normalize()
        
        -- Main trace
        local tr = util.TraceLine({
            start = eyePos,
            endpos = eyePos + searchDir * searchRadius,
            filter = ply,
            mask = MASK_SOLID
        })
        
        if tr.Hit then
            -- Check for building corners by doing additional traces
            local isCorner = self:IsCornerPoint(tr.HitPos, tr.HitNormal)
            local score = self:EvaluateSwingPoint(tr.HitPos, eyePos, playerVel, isCorner, speedSqr, false)
            
            if score > bestScore then
                bestScore = score
                bestPoint = {
                    pos = tr.HitPos,
                    normal = tr.HitNormal,
                    entity = tr.Entity,
                    score = score,
                    isCorner = isCorner,
                    isCeiling = false
                }
            end
        end
    end
    
    -- Choose between ceiling point and regular point
    if ceilingPoint and (not bestPoint or ceilingPoint.score > bestPoint.score) then
        return ceilingPoint
    end
    
    return bestPoint
end

-- Function to check if a point is a building corner
function SWEP:IsCornerPoint(hitPos, hitNormal)
    local checkDist = 30  -- Distance to check for corners
    local directions = {
        Vector(1, 0, 0),
        Vector(-1, 0, 0),
        Vector(0, 1, 0),
        Vector(0, -1, 0)
    }
    
    local gaps = 0
    for _, dir in ipairs(directions) do
        -- Skip direction if it's parallel to hit normal
        if math.abs(dir:Dot(hitNormal)) > 0.9 then continue end
        
        local tr = util.TraceLine({
            start = hitPos + hitNormal * 5, -- Offset slightly from wall
            endpos = hitPos + hitNormal * 5 + dir * checkDist,
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
        if dist > 200 or (playerVel and playerVel:Length() < 300) then
            return -1
        end
        score = score - 0.5
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
            optimalHeight = optimalHeight * GetConVarNumber("webswing_map_height_mult", 1)
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
        score = score + 0.3  -- Significant bonus for ceiling points
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
        if not ConVarExists("webswing_map_height_mult") then
            CreateConVar("webswing_map_height_mult", "1", FCVAR_ARCHIVE, "Multiplier for optimal swing height")
        end
        if not ConVarExists("webswing_map_range_mult") then
            CreateConVar("webswing_map_range_mult", "1", FCVAR_ARCHIVE, "Multiplier for web range")
        end
    end
end

if SERVER then
    util.AddNetworkString("WebShooterNoclipSpeed")
end

if CLIENT then
    net.Receive("WebShooterNoclipSpeed", function()
        local shouldRestrict = net.ReadBool()
        if shouldRestrict then
            LocalPlayer():SetNWFloat("sv_noclipspeed", 0)
        end
    end)
end