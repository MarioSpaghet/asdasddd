-- Include all the modular components

-- Ensure clients receive all required modules (CLEANED UP - removed broken systems)
if SERVER then
    AddCSLuaFile()
    AddCSLuaFile("weapons/webswing/convars.lua")
    AddCSLuaFile("weapons/webswing/model_cache.lua")
    	AddCSLuaFile("weapons/webswing/simple_map_analysis.lua")
    AddCSLuaFile("weapons/webswing/saved_weapons.lua")
    AddCSLuaFile("weapons/webswing/camera_system.lua")
    AddCSLuaFile("weapons/webswing/rope_dynamics.lua")
    AddCSLuaFile("weapons/webswing/swing_targeting.lua") -- RESTORED: AI targeting system
    AddCSLuaFile("weapons/webswing/momentum_system.lua") -- REPLACED: The working momentum system
end

include("convars.lua")

-- Import the essential systems (CLEANED UP - removed broken momentum systems)
local ModelInfoCache = include("model_cache.lua")
local SimpleMapAnalysis = include("simple_map_analysis.lua")
local SavedWeapons = include("saved_weapons.lua")
local CameraSystem = include("camera_system.lua")
local RopeDynamics = include("rope_dynamics.lua")
local SwingTargeting = include("swing_targeting.lua") -- RESTORED: AI targeting (but fixed to work with proper momentum)

-- REPLACED: Import the new proper momentum system instead of broken ones
local ProperMomentum = include("momentum_system.lua")

-- Keep only essential physics for basic rope constraint calculations
local BasicPhysics = {
    STANDARD_RAGDOLL_MASS = 1,
    CalcElasticConstant = function(Phys1, Phys2, Ent1, Ent2, iFixed)
        local minMass = 0
        if Ent1:IsWorld() then
            minMass = Phys2:GetMass()
        elseif Ent2:IsWorld() then
            minMass = Phys1:GetMass()
        else
            minMass = math.min(Phys1:GetMass(), Phys2:GetMass())
        end
        
        local const = minMass * 100
        local damp = const * 0.2
        if not iFixed then
            const = minMass * 50
            damp = const * 1
        end
        return const, damp
    end
}

if SERVER then
	-- Add network strings
	util.AddNetworkString("WebSwing_SetRopeMaterial")
	util.AddNetworkString("WebSwing_ToggleManualMode")
	util.AddNetworkString("WebSwing_SetSoundSet")

	-- Server init
	util.AddNetworkString("WebSwing_NoclipSpeed")
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

SWEP.STANDARD_RAGDOLL_MASS = BasicPhysics.STANDARD_RAGDOLL_MASS  -- Standard mass for ragdoll physics objects

-- ModelInfoCache is now imported from model_cache.lua

-- SavedWeapons is now imported from saved_weapons.lua

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

-- MapAnalysisData is now imported from map_analysis.lua

-- AnalyzeMap and AnalyzeEnvironment functions are now imported from map_analysis.lua

-- First, ensure SWEP is initialized
SWEP = SWEP or {}

-- Move the WebSoundCount variables to be properties of SWEP
SWEP.WebSoundCooldown = 0.1  -- Minimum time between sounds
SWEP.WebSoundResetTime = 1.0  -- Time before sound count resets
SWEP.MaxWebSoundCount = 3     -- Number of rapid sounds before fatigue kicks in

-- Initialize function should be defined after SWEP is declared
function SWEP:Initialize()
	-- Initialize simple analysis defaults
	self.Range = 2000
	self.TargetingMultiplier = 1.0
	self.SpeedMultiplier = 1.0

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

	-- No need to register camera hooks anymore - using global hook

	-- The simplified targeting system initializes itself automatically
	
	-- The proper momentum system initializes itself in Think() when needed

	-- Run simple analysis on server
	if SERVER then
		local analysis = SimpleMapAnalysis:GetAnalysis()
		if analysis then
			SimpleMapAnalysis:UpdateWeaponParameters(self)
		end
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
end

function SWEP:Reload()

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


--   Think function
function SWEP:Think()
    if !self.Owner:IsOnGround() then
        self.Owner:SetAllowFullRotation(true)
    elseif self.Owner:IsOnGround() then
        self.Owner:SetAllowFullRotation(false)
    end
    
    -- Initialize the proper momentum system if not already done
    if not self.ProperMomentum then
        self.ProperMomentum = ProperMomentum
        if SERVER then
            -- Run balance analysis on first setup
            self.ProperMomentum:AnalyzeBalance()
        end
    end
    
    -- Update the proper momentum system
    if IsValid(self.Owner) then
        self.ProperMomentum:UpdateMomentum(self.Owner, FrameTime(), self.RagdollActive)
    end
    
    -- Update AI targeting system (restored by user request)
    if SwingTargeting and SwingTargeting.TrackPlayerInput then
        SwingTargeting:TrackPlayerInput(self.Owner, FrameTime())
    end

-- Camera system is now imported from camera_system.lua

	if CLIENT then
		if self.LastTargetNameUpdate ~= self.TargetPhysObj then
			local BoneNum = self.Owner:TranslatePhysBoneToBone(self.TargetPhysObj or 0)
			self.BoneName = self.Owner:GetBoneName(BoneNum or 0) or ""
			self.BoneName = self.BoneName:gsub("ValveBiped.", "")
			self.LastTargetNameUpdate = self.TargetPhysObj
		end
	end

	-- Add this new check
	if self.RagdollActive and not self.Owner:KeyDown(IN_ATTACK2) then
		self:StopWebSwing()
	end
	if self.ConstraintController then
		self.ConstraintController.speed = self:GetShortenSpeed()

		if self.Owner:KeyDown(IN_FORWARD) then
			self.ConstraintController:Shorten()
		end
	end

    -- Dynamic rope length adjustment using the RopeDynamics module
    if self.RagdollActive and self.ConstraintController and GetConVar("webswing_dynamic_length"):GetBool() then
        RopeDynamics.AdjustRopeLength(self.ConstraintController, self.Ragdoll, function() return self:GetTargetBone() end, FrameTime())
    end

    -- REPLACED: Apply simple pendulum physics instead of broken competing systems
    if self.RagdollActive and IsValid(self.Ragdoll) and self.ConstraintController then
        self:ApplySimplePendulumPhysics(FrameTime())
    end

    -- REMOVED: All the broken momentum systems that fought each other
    -- - WebOfShadowsPhysics (over-engineered)
    -- - PhysicsSystem.ApplySwingForces (disabled momentum building)
    -- - PendulumPhysics (redundant)
    -- - WebReleaseDynamics (unnecessary)
    -- - MomentumConversion (over-complicated)

    -- Process rope shortening/slackening
    if IsValid(self.Owner) and self.Owner:KeyDown(IN_ATTACK2) and self.ConstraintController then
        if not IsValid(self.ConstraintController.constraint) or not IsValid(self.ConstraintController.rope) then
            -- Recreate constraint if something went wrong
            self:CleanupWebSwing()
            return
        end        self.ConstraintController.speed = self:GetShortenSpeed()

        if self.Owner:KeyDown(IN_FORWARD) then
            self.ConstraintController:Shorten()
        end
    end
end

-- Use the basic physics CalcElasticConstant function
local function CalcElasticConstant(Phys1, Phys2, Ent1, Ent2, iFixed)
    return BasicPhysics.CalcElasticConstant(Phys1, Phys2, Ent1, Ent2, iFixed)
end

-- Use the basic physics standard ragdoll mass
SWEP.STANDARD_RAGDOLL_MASS = BasicPhysics.STANDARD_RAGDOLL_MASS

-- Simple pendulum physics to replace broken systems
function SWEP:ApplySimplePendulumPhysics(frameTime)
    if not IsValid(self.Ragdoll) or not self.ConstraintController then return end
    
    local owner = self.Owner
    local ownerVel = owner:GetVelocity()
    local ropeLength = self.ConstraintController.current_length or 100
    
    -- Get momentum speed from proper momentum system
    local targetSpeed = self.ProperMomentum:GetCurrentSpeed(owner)
    
    -- Simple gravity compensation
    local gravity = Vector(0, 0, -600)
    local massCompensation = 0.6 -- How much to compensate for gravity
    
    -- Apply forces to ragdoll physics objects
    for i = 0, self.Ragdoll:GetPhysicsObjectCount() - 1 do
        local physObj = self.Ragdoll:GetPhysicsObjectNum(i)
        if IsValid(physObj) then
            local mass = physObj:GetMass()
            
            -- Apply upward force to counteract gravity during swing
            local upwardForce = mass * 600 * massCompensation * frameTime
            
            -- Apply momentum-based velocity
            local currentVel = owner:GetVelocity()
            if currentVel:Length() > 50 then
                local direction = currentVel:GetNormalized()
                local newVel = self.ProperMomentum:ApplyMomentumToPlayer(owner, currentVel)
                owner:SetVelocity(newVel)
            end
            
            physObj:ApplyForceCenter(Vector(0, 0, upwardForce))
        end
    end
end

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
            -- RESTORED: AI targeting system (by user request)
            local bestPoint = self:FindPotentialSwingPoints()
            if not bestPoint or not bestPoint.pos or not bestPoint.normal then 
                -- Fallback to manual targeting if AI fails
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
                tr = {
                    Hit = true,
                    HitPos = bestPoint.pos,
                    HitNormal = bestPoint.normal,
                    Entity = bestPoint.entity or game.GetWorld(),
                    StartPos = self.Owner:EyePos(),
                    PhysicsBone = 0
                }
            end
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
    
    -- Store attach point for momentum system
    self.AttachPoint = attachPos

    -- New: Check if the attachment is a glass surface and adjust if needed.
    if IsValid(attachEntity) then
        local mat = attachEntity:GetMaterial() or ""
        if string.find(mat:lower(), "glass") then
            if SERVER then
                self.Owner:SetVelocity(self.Owner:GetVelocity() * 0.7)
                self:PlayGlassAttachSound()
            end
        end
    end

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

    -- Standardize mass for each physics object
    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local physObj = ragdoll:GetPhysicsObjectNum(i)
        if IsValid(physObj) then
            physObj:SetMass(self.STANDARD_RAGDOLL_MASS)
            physObj:EnableMotion(true)
            physObj:Wake()
        end
    end
    -- NEW: Adjust ragdoll damping based on its physical spread
    self:AdjustRagdollForSwing(ragdoll)

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

        -- Use the RopeDynamics module to create the constraint controller
        self.ConstraintController = RopeDynamics.CreateConstraintController(
            ragdoll, attachEntity, targetPhysObj, attachBone, tr.HitPos,
            dist, useRope, ropeMat, ropeWidth, ropeColor
        )
        if self.ConstraintController then
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
                type = "elastic",               -- added field to mark elastic constraints
                initial_length = dist * 0.95,     -- added: store the initial (rest) rope length
                baseConst = const,              -- added: store the base spring constant
                baseDamp = damp,                -- added: store the base damping value
                Set = function(ctrl)
                    if IsValid(ctrl.constraint) then
                        ctrl.constraint:Fire("SetSpringLength", ctrl.current_length, 0)
                        -- Compute the stretch ratio (current / rest length)
                        local ratio = ctrl.current_length / ctrl.initial_length
                        ratio = math.Clamp(ratio, 0.5, 1.2)

                        -- Dynamic recalculation of stiffness and damping based on the ratio.
                        -- You can also incorporate swing angle here if desired.
                        local stiffnessFactor = Lerp((ratio - 0.5) / (1.2 - 0.5), 1.5, 0.8)
                        local dampingFactor   = Lerp((ratio - 0.5) / (1.2 - 0.5), 0.8, 1.5)
                        local newConst = ctrl.baseConst * stiffnessFactor
                        local newDamp  = ctrl.baseDamp * dampingFactor
                        ctrl.constraint:SetKeyValue("constant", tostring(newConst))
                        ctrl.constraint:SetKeyValue("damping", tostring(newDamp))
                        ctrl.constraint:Fire("Update", "", 0)
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

    if IsValid(attachEntity) then
        local mat = attachEntity:GetMaterial() or ""
        if string.find(mat:lower(), "glass") then
            if SERVER then
                -- Apply a momentum penalty
                self.Owner:SetVelocity(self.Owner:GetVelocity() * 0.7)
                self:PlayGlassAttachSound()  -- Play a special sound for glass attachment
            end
        end
    end

    -- REMOVED: Broken pendulum physics notification
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

    -- Get final velocity before stopping the swing
    local releaseVelocity = Vector(0, 0, 0)
    if IsValid(rag) then
        local physObj = rag:GetPhysicsObjectNum(11) -- Main body bone
        if IsValid(physObj) then
            releaseVelocity = physObj:GetVelocity()
        end
    end

    -- REPLACED: Use proper momentum system for release mechanics
    if self.ProperMomentum and self.AttachPoint then
        local releaseInfo = self.ProperMomentum:OnSwingReleaseWithFeedback(ply, self.AttachPoint)
        
        if releaseInfo then
            -- Apply the momentum speed to player velocity
            local newVel = self.ProperMomentum:ApplyMomentumToPlayer(ply, releaseVelocity)
            releaseVelocity = newVel
            
            -- Debug feedback if developer mode is on
            if GetConVar("developer") and GetConVar("developer"):GetBool() then
                print("Release Quality:", releaseInfo.quality, "New Speed:", releaseInfo.newSpeed)
                print("Tier:", releaseInfo.tier, "Combo:", releaseInfo.comboMultiplier)
            end
        end
    end
    
    -- REMOVED: All the broken release systems
    -- - PendulumPhysics (redundant swing phase tracking)
    -- - WebOfShadowsPhysics:EnhanceWebRelease (over-engineered)
    -- - WebReleaseDynamics:HandleWebRelease (unnecessary complexity)

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

    -- No rhythm system implemented
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

        -- No need to remove camera hooks - using global hook
    end

    return true
end

-- Add Deploy function to ensure camera hook is added when weapon is equipped
function SWEP:Deploy()
    -- No need to add camera hooks - using global hook
    return true
end

function SWEP:OnRemove()
    -- Remove any camera hook and reset camera state
    hook.Remove("CalcView", "SpiderManView")
    self.CameraVars = nil
    self.TransitioningFromSwing = false
    self.CameraTransitionStart = 0

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

    -- Clean up animation and physics hooks
    hook.Remove("CalcMainActivity", "BaseAnimations")
    -- REMOVED: PendulumPhysics hook cleanup (system no longer exists)

    -- Clean up web swing if active
    if self.CleanupWebSwing then
        self:CleanupWebSwing()
    end

    if self.ConstraintController then
        -- Make sure constraint and rope are valid before removing
        if IsValid(self.ConstraintController.constraint) then
            self.ConstraintController.constraint:Remove()
        end
        if IsValid(self.ConstraintController.rope) then
            self.ConstraintController.rope:Remove()
        end
        -- Clear the controller after removing the constraint
        self.ConstraintController = nil
    end

    -- Clear any remaining rope dynamics state
    if RopeDynamics then
        RopeDynamics.PrevVelocity = nil
        RopeDynamics.LastLengthChange = nil
        RopeDynamics.LastCornerTime = nil
    end

    -- Clear the ragdoll
    if IsValid(self.Ragdoll) then
        self.Ragdoll:Remove()
        self.Ragdoll = nil
    end

    self.RagdollActive = false
    self:ResetAllSettings()
end

function SWEP:OnDrop()
    if self.CleanupWebSwing then
        self:CleanupWebSwing()
    end
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

-- Add this function right before GatherSwingPointCandidates
function SWEP:IsValidSwingPoint(pos, playerPos)
    return SwingTargeting:IsValidSwingPoint(self, pos, playerPos)
end

-- Add this function to calculate optimal sky height
function SWEP:CalculateOptimalSkyHeight(eyePos, velocity, distToGround)
    return SwingTargeting:CalculateOptimalSkyHeight(self, eyePos, velocity, distToGround)
end

-- Now modify GatherSwingPointCandidates to use this function
function SWEP:GatherSwingPointCandidates()
    return SwingTargeting:GatherSwingPointCandidates(self)
end

function SWEP:CheckOverheadClearance(pos)
    return SwingTargeting:CheckOverheadClearance(self, pos)
end

-- Modify the function signature to accept candidates array
function SWEP:EvaluateSwingCandidate(candidate, playerState, allCandidates)
    return SwingTargeting:EvaluateSwingCandidate(self, candidate, playerState, allCandidates)
end

-- Modify FindPotentialSwingPoints to pass candidates array
-- RESTORED: AI targeting function (but cleaned up to work with proper momentum)
function SWEP:FindPotentialSwingPoints()
    return SwingTargeting:FindPotentialSwingPoints(self)
end

-- Function to check if a point is a building corner
function SWEP:IsCornerPoint(hitPos, hitNormal)
    return SwingTargeting:IsCornerPoint(self, hitPos, hitNormal)
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
    self.BaseRange = self.Range or 2000
    if not GetConVar("webswing_manual_mode"):GetBool() then
        -- Range is already set by SimpleMapAnalysis:UpdateWeaponParameters()
        -- Just use manual override if needed
    else
        self.Range = self.BaseRange
    end

    -- Simple height calculation based on vertical range
    local analysis = SimpleMapAnalysis.Cache[game.GetMap()]
    if analysis and analysis.verticalRange > 0 then
        local heightRatio = math.Clamp(analysis.verticalRange / 1000, 0.5, 2)
        self.OptimalSwingHeight = 150 * heightRatio
    else
        self.OptimalSwingHeight = 150
    end
    
    -- Fewer search points for better performance
    self.SearchPoints = 12

    -- Adjust range based on wind speed if available
    if self.Environment and self.Environment.windSpeed then
         local windFactor = math.Clamp(self.Environment.windSpeed / 200, 0, 0.5)
         self.Range = self.Range * (1 + windFactor)
    end

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

-- Add just before or after the SWEP:IsInCorner function (around line 827)

-- Function to adjust ragdoll physics for optimal swing dynamics
function SWEP:AdjustRagdollForSwing(ragdoll)
    if not IsValid(ragdoll) then return end

    -- Set appropriate damping and drag for web-swinging
    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local physObj = ragdoll:GetPhysicsObjectNum(i)
        if IsValid(physObj) then
            -- Set linear and angular damping for more controlled swinging
            physObj:SetDamping(0.2, 0.8)

            -- Adjust drag based on model size and mass
            local modelScale = 1
            if IsValid(self.Owner) then
                modelScale = self.Owner:GetModelScale()
            end

            -- Scale mass by model scale to maintain appropriate physics
            local mass = self.STANDARD_RAGDOLL_MASS * math.max(0.8, modelScale)
            physObj:SetMass(mass)

            -- Enable motion and wake the physics object
            physObj:EnableMotion(true)
            physObj:Wake()
        end
    end

    -- Apply initial rotation to align ragdoll with player's view
    if IsValid(self.Owner) then
        local viewAngles = self.Owner:EyeAngles()
        local physObj = ragdoll:GetPhysicsObjectNum(0) -- Main body physics object
        if IsValid(physObj) then
            physObj:SetAngles(Angle(0, viewAngles.y, 0))
        end
    end
end

-- Function to find a safe position for the player
function SWEP:FindSafePosition(pos)
    if not pos then return pos end

    local ply = self.Owner
    if not IsValid(ply) then return pos end

    -- Define player hull dimensions
    local mins = Vector(-16, -16, 0)
    local maxs = Vector(16, 16, 72)

    -- Check if the original position is safe
    local tr = util.TraceHull({
        start = pos,
        endpos = pos,
        mins = mins,
        maxs = maxs,
        filter = ply,
        mask = MASK_SOLID
    })

    -- If position is already safe, return it
    if not tr.Hit then
        return pos
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

        local tr = util.TraceHull({
            start = testPos,
            endpos = testPos,
            mins = mins,
            maxs = maxs,
            filter = ply,
            mask = MASK_SOLID
        })

        if not tr.Hit then
            return testPos
        end
    end

    -- If no safe position found, move up and away from walls
    local upTrace = util.TraceLine({
        start = pos,
        endpos = pos + Vector(0, 0, 128),
        filter = ply,
        mask = MASK_SOLID
    })

    if upTrace.Hit then
        return pos + Vector(0, 0, upTrace.HitPos.z - pos.z - 10)
    else
        return pos + Vector(0, 0, 100)
    end
end

-- And replace it with this hook that modifies the web swings
hook.Add("InitPostEntity", "WebSwing_SetupMomentumTracking", function()
    -- Find all weapons with the web swing mechanic
    if SWEP and SWEP.StartWebSwing then
        -- Store the original function
        local originalStartWebSwing = SWEP.StartWebSwing

        -- Override with our new function that records momentum
        SWEP.StartWebSwing = function(self, tr)
            -- Call the original function first
            originalStartWebSwing(self, tr)

            -- If tr is valid, record swing information
            if tr and tr.Hit and IsValid(self.Owner) then
                local ply = self.Owner
                local vel = ply:GetVelocity()
                local speed = vel:Length()
                local hitPos = tr.HitPos

                -- Calculate swing quality (0-1)
                local swingQuality = 0.5 -- Default moderate quality

                if speed > 200 then
                    local toTarget = (hitPos - ply:EyePos()):GetNormalized()
                    local alignment = vel:GetNormalized():Dot(toTarget)
                    local heightDiff = hitPos.z - ply:EyePos().z

                    -- Calculate a combined quality score
                    swingQuality = math.Clamp(
                        0.5 +  -- Base value
                        math.Clamp(alignment, -0.5, 0.5) +  -- Alignment bonus
                        (heightDiff > 50 and 0.2 or 0) +  -- Height bonus
                        math.Clamp((speed - 200) / 1000, 0, 0.3),  -- Speed bonus
                        0, 1
                    )
                end

                -- Record the swing event
                -- RESTORED: SwingTargeting swing event recording (with error checking)
                if SwingTargeting and SwingTargeting.RecordSwingEvent then
                    SwingTargeting:RecordSwingEvent(swingQuality, hitPos, vel)
                end

                if GetConVar("developer"):GetBool() then
                    print(string.format("[WebSwing] Recorded swing, quality: %.2f, speed: %.1f",
                          swingQuality, speed))
                end
            end
        end
    end
end)

-- Create a hook for post-swing physics that lets our pendulum system do post-processing
hook.Add("PostSimulatePhysics", "WebSwing_PostPhysics", function()
    local ply = LocalPlayer and LocalPlayer() or nil
    if not IsValid(ply) then return end

    local weapon = ply:GetActiveWeapon()
    if IsValid(weapon) and weapon:GetClass() == "webswing" and weapon.RagdollActive then
        -- Call the post-process hook
        hook.Run("PostSwingPhysics", weapon.Ragdoll, ply, weapon.ConstraintController)
    end
end)

-- Add OnRemove function to clean up hooks and global references
function SWEP:OnRemove()
    -- Clean up hooks
    if CLIENT then
        hook.Remove("RenderScreenspaceEffects", "FlowState_ScreenEffects")
    end

    -- Call original OnRemove if it exists
    if self.BaseClass.OnRemove then
        self.BaseClass.OnRemove(self)
    end

    if self.ConstraintController then
        -- Make sure constraint and rope are valid before removing
        if IsValid(self.ConstraintController.constraint) then
            self.ConstraintController.constraint:Remove()
        end
        if IsValid(self.ConstraintController.rope) then
            self.ConstraintController.rope:Remove()
        end
        -- Clear the controller after removing the constraint
        self.ConstraintController = nil
    end

    -- Clear any remaining rope dynamics state
    if RopeDynamics then
        RopeDynamics.PrevVelocity = nil
        RopeDynamics.LastLengthChange = nil
        RopeDynamics.LastCornerTime = nil
    end

    -- Clear the ragdoll
    if IsValid(self.Ragdoll) then
        self.Ragdoll:Remove()
        self.Ragdoll = nil
    end

    self.RagdollActive = false
    self:ResetAllSettings()

    -- Make sure we're properly cleaning up hooks
    -- REMOVED: PendulumPhysics hook cleanup (system no longer exists)
end

-- Adding the missing ResetAllSettings function
function SWEP:ResetAllSettings()
	-- Reset all web swinging states
	self.Roping = false
	self.RagdollActive = false
	self.WebSoundCount = 0
	self.TransitioningFromSwing = false
	self.CameraTransitionStart = 0
	self.TargetPhysObj = 0
	self.CameraVars = nil
	self.ConstraintController = nil
	self.OriginalStates = nil

	-- Reset any active effects
	if hook.GetTable()["PostSwingPhysics"] and hook.GetTable()["PostSwingPhysics"]["PendulumPhysics_PostProcess"] then
		hook.Remove("PostSwingPhysics", "PendulumPhysics_PostProcess")
	end

	-- REMOVED: Momentum conversion system reset (system no longer exists)
end