-- Include all the modular components
include("convars.lua")

-- Import the modular systems
local ModelInfoCache = include("model_cache.lua")
local MapAnalysisData = include("map_analysis.lua")
local SavedWeapons = include("saved_weapons.lua")
local CameraSystem = include("camera_system.lua")
local RopeDynamics = include("rope_dynamics.lua")
local PhysicsSystem = include("physics_system.lua")
local RhythmSystem = include("rhythm_system.lua") -- Add the Rhythm System
local RhythmHUD = include("rhythm_hud.lua") -- Add the Rhythm HUD
local SwingTargeting = include("swing_targeting.lua") -- Add the AI Swing Targeting System
local AdaptiveTension = include("adaptive_tension.lua") -- Add the Adaptive Tension System
local PendulumPhysics = include("pendulum_physics.lua") -- Add the Pendulum Physics Enhancement System
local WebReleaseDynamics = include("web_release_dynamics.lua") -- Add the Web Release Dynamics System
local FlowStateSystem = include("flow_state_system.lua") -- Add the Flow State System
local FlowStateHUD = include("flow_state_hud.lua") -- Add the Flow State HUD

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

SWEP.STANDARD_RAGDOLL_MASS = 1  -- Standard mass for ragdoll physics objects

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
	
	-- Initialize the Rhythm System if not already initialized
	if not self.RhythmSystem then
		self.RhythmSystem = table.Copy(RhythmSystem)
		self.RhythmSystem:Initialize()
	end
	
	-- Initialize the Flow State System
	if not self.FlowStateSystem then
		self.FlowStateSystem = table.Copy(FlowStateSystem) or {}
		
		-- Make sure the FlowStateSystem has all required tables
		if not self.FlowStateSystem.State then
		    self.FlowStateSystem.State = {}
		end
		
		if not self.FlowStateSystem.Config then
		    self.FlowStateSystem.Config = {}
		end
		
		-- Ensure core methods exist to prevent errors
		self.FlowStateSystem.Initialize = self.FlowStateSystem.Initialize or function() end
		self.FlowStateSystem.Update = self.FlowStateSystem.Update or function() return {} end
		self.FlowStateSystem.ResetState = self.FlowStateSystem.ResetState or function() end
		
		-- Initialize with safeguards
		local success, err = pcall(function()
		    self.FlowStateSystem:Initialize()
		end)
		
		if not success then
		    ErrorNoHalt("Failed to initialize FlowStateSystem: " .. tostring(err) .. "\n")
		    
		    -- Set up minimal functionality to prevent errors
		    self.FlowStateSystem.GetFlowAdjustments = self.FlowStateSystem.GetFlowAdjustments or function()
		        return {
		            speedMultiplier = 1.0,
		            gravityFactor = 1.0,
		            airControlFactor = 1.0,
		            momentumConservation = 1.0,
		            visualIntensity = 0,
		            flowLevel = 0,
		            chainMultiplier = 1.0,
		            inFlowState = false,
		            timeDilated = false
		        }
		    end
		end
	end
	
	-- Initialize HUD systems on client
	if CLIENT then
		-- Initialize Rhythm HUD if not already initialized
		if not self.RhythmHUD then
			self.RhythmHUD = table.Copy(RhythmHUD)
			self.RhythmHUD:Initialize()
		end
		
		-- Initialize Flow State HUD
		if not self.FlowStateHUD then
			self.FlowStateHUD = table.Copy(FlowStateHUD)
			self.FlowStateHUD:Initialize()
		end
	end
	
	-- Run analysis on server: map analysis and environmental analysis (wind)
	if SERVER then
		self:AnalyzeMap()
		self:AnalyzeEnvironment()  -- New: check for wind zones
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
	
	-- No need to register camera hooks anymore - using global hook

	-- Initialize the rhythm system
	self.RhythmSystem = RhythmSystem
	self.RhythmSystem:Initialize()
	
	-- Initialize the adaptive tension system
	self.AdaptiveTension = AdaptiveTension
	self.AdaptiveTension:Initialize()
	
	-- Initialize the pendulum physics enhancement system
	self.PendulumPhysics = PendulumPhysics
	self.PendulumPhysics:Initialize()
	
	-- Initialize the web release dynamics system
	self.WebReleaseDynamics = WebReleaseDynamics
	self.WebReleaseDynamics:Initialize()
	
	-- Initialize the rhythm HUD system
	if CLIENT then
		self.RhythmHUD = RhythmHUD
		self.RhythmHUD:Initialize()
		
		-- Add a HUD paint hook for the rhythm system
		hook.Add("HUDPaint", "WebSwingRhythmHUD", function()
			if IsValid(LocalPlayer()) and IsValid(LocalPlayer():GetActiveWeapon()) and 
			   LocalPlayer():GetActiveWeapon():GetClass() == "webswing" then
				-- Only draw if we're actually web swinging
				if LocalPlayer():GetActiveWeapon().RagdollActive then
					self.RhythmHUD:Draw(self.RhythmSystem)
					
					-- Draw Flow State HUD if initialized
					if self.FlowStateHUD then
						self.FlowStateHUD:Draw(self.FlowStateSystem)
					end
				else
					-- Also draw the Flow State HUD when not swinging, but only if it's active
					if self.FlowStateHUD and self.FlowStateSystem and 
					   self.FlowStateSystem.State and self.FlowStateSystem.State.FlowScore > 0 then
						self.FlowStateHUD:Draw(self.FlowStateSystem)
					end
				end
			end
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
	-- Properly remove the camera hook using the correct hook name
	hook.Remove("CalcView", "SpiderManView")
	-- Remove rhythm HUD hook
	hook.Remove("HUDPaint", "WebSwingRhythmHUD")
	-- Clean up camera variables
	self.CameraVars = nil
	self.TransitioningFromSwing = false
	self.CameraTransitionStart = 0
    return true
end

--   Think does nothing
function SWEP:Think()
    if !self.Owner:IsOnGround() then
        self.Owner:SetAllowFullRotation(true)
    elseif self.Owner:IsOnGround() then
        self.Owner:SetAllowFullRotation(false)
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
		elseif self.Owner:KeyDown(IN_BACK) then
			self.ConstraintController:Slacken()
		end
	end
	
	-- Update the Flow State system if active
	if self.FlowStateSystem and self.RhythmSystem then
		-- Only update during active swinging
		if self.RagdollActive and IsValid(self.Ragdoll) then
			local ownerVel = self.Owner:GetVelocity()
			local frameTime = FrameTime()
			
			-- Update flow state and get adjustments
			if self.FlowStateSystem and self.FlowStateSystem.Update and self.RhythmSystem then
				local flowAdjustments = self.FlowStateSystem:Update(self.RhythmSystem, ownerVel, frameTime)
				
				-- Store flow adjustments for use in physics calculations
				self.FlowAdjustments = flowAdjustments
			end
		elseif not self.RagdollActive then
			-- Update flow state with zero velocity to allow it to decay when not swinging
			if self.FlowStateSystem and self.FlowStateSystem.Update and self.RhythmSystem then
				self.FlowStateSystem:Update(self.RhythmSystem, Vector(0, 0, 0), FrameTime())
			end
		end
	end

    -- Dynamic rope length adjustment using the RopeDynamics module
    if self.RagdollActive and self.ConstraintController and GetConVar("webswing_dynamic_length"):GetBool() then
        RopeDynamics.AdjustRopeLength(self.ConstraintController, self.Ragdoll, function() return self:GetTargetBone() end, FrameTime(), self.RhythmSystem)
        
        -- Apply adaptive tension system
        if self.AdaptiveTension then
            self.AdaptiveTension:Update(self.Owner, self.ConstraintController, self.Owner:GetVelocity(), FrameTime(), self.Ragdoll)
        end
    end

    -- Apply physics forces using the PhysicsSystem module
    if self.RagdollActive and IsValid(self.Ragdoll) then
		-- Apply swing physics via the PhysicsSystem module
		PhysicsSystem.ApplySwingForces(self.Ragdoll, self.Owner, self.ConstraintController, FrameTime(), self.RhythmSystem)
		
		-- Apply pendulum physics enhancements
		if self.PendulumPhysics then
			self.PendulumPhysics:Update(self.Ragdoll, self.Owner, FrameTime())
		end
		
		-- Apply flow state physics adjustments if available
		if self.FlowAdjustments and self.FlowStateSystem and self.FlowStateSystem.State.InFlowState then
			-- Apply to ragdoll physics
			for i = 0, self.Ragdoll:GetPhysicsObjectCount() - 1 do
				local physObj = self.Ragdoll:GetPhysicsObjectNum(i)
				if IsValid(physObj) then
					-- Apply flow-based speed boost
					if self.FlowAdjustments.speedMultiplier > 1.0 then
						local vel = physObj:GetVelocity()
						if vel:Length() > 50 then -- Only boost if already moving
							local speedBoost = (self.FlowAdjustments.speedMultiplier - 1.0) * physObj:GetMass() * vel:GetNormalized() * vel:Length() * 0.5
							physObj:ApplyForceCenter(speedBoost)
						end
					end
					
					-- Apply reduced gravity when in high flow levels
					if self.FlowAdjustments.gravityFactor < 1.0 then
						local gravityReduction = physObj:GetMass() * 600 * (1.0 - self.FlowAdjustments.gravityFactor) * Vector(0, 0, 1) * FrameTime()
						physObj:ApplyForceCenter(gravityReduction)
					end
				end
			end
			
			-- Apply time dilation if active
			if self.FlowAdjustments.timeDilated and CLIENT then
				-- Camera effects and time dilation are handled by the FlowStateSystem itself
			end
		end
    end
    
    -- Update web release dynamics system
    if self.WebReleaseDynamics then
        self.WebReleaseDynamics:Update(self.Owner, FrameTime())
    end
    
    -- Process rope shortening/slackening
    if IsValid(self.Owner) and self.Owner:KeyDown(IN_ATTACK2) and self.ConstraintController then
        if not IsValid(self.ConstraintController.constraint) or not IsValid(self.ConstraintController.rope) then
            -- Recreate constraint if something went wrong
            self:CleanupWebSwing()
            return
        end
        
        self.ConstraintController.speed = self:GetShortenSpeed()
        
        if self.Owner:KeyDown(IN_FORWARD) then
            self.ConstraintController:Shorten()
        elseif self.Owner:KeyDown(IN_BACK) then
            self.ConstraintController:Slacken()
        end
    end
end

-- Use the physics system's CalcElasticConstant function
local function CalcElasticConstant(Phys1, Phys2, Ent1, Ent2, iFixed)
    return PhysicsSystem.CalcElasticConstant(Phys1, Phys2, Ent1, Ent2, iFixed)
end

-- Use the physics system's standard ragdoll mass
SWEP.STANDARD_RAGDOLL_MASS = PhysicsSystem.STANDARD_RAGDOLL_MASS

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
        local RopeDynamics = include("rope_dynamics.lua")
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

    -- Record the start of a new swing for rhythm tracking
    if self.RhythmSystem then
        local swingType = "standard"
        -- Determine swing type based on conditions
        if self.Owner:GetVelocity():Length() > 800 then
            swingType = "momentum"
        elseif self.Owner:GetVelocity().z < -300 then
            swingType = "falling"
        end
        
        -- Record the new swing event
        self.RhythmSystem:RecordSwing(swingType)
        
        -- Also record it in the physics system for force calculations
        PhysicsSystem.RecordSwingStart()
    end
    
    -- Notify the pendulum physics system of the new swing
    if self.PendulumPhysics then
        self.PendulumPhysics:OnSwingStart(self.Ragdoll, self.Owner, self.ConstraintController)
    end
    
    -- Record the swing in the Flow State system
    if self.FlowStateSystem and self.RhythmSystem then
        -- Get the current rhythm score to pass to the flow system
        local rhythmScore = self.RhythmSystem.RhythmScore or 0
        self.FlowStateSystem:RecordSwing(rhythmScore)
        
        -- Reset the swing start time in the rhythm state for phase calculation
        PhysicsSystem.RhythmState.SwingStartTime = CurTime()
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
    
    -- Get final velocity before stopping the swing
    local releaseVelocity = Vector(0, 0, 0)
    if IsValid(rag) then
        local physObj = rag:GetPhysicsObjectNum(11) -- Main body bone
        if IsValid(physObj) then
            releaseVelocity = physObj:GetVelocity()
        end
    end
    
    -- Get current swing phase from pendulum physics system
    local swingPhase = 0.5 -- Default middle phase
    if self.PendulumPhysics and self.PendulumPhysics.State then
        swingPhase = self.PendulumPhysics.State.CurrentPhase
    end
    
    -- Apply enhanced release dynamics
    if self.WebReleaseDynamics then
        releaseVelocity = self.WebReleaseDynamics:HandleWebRelease(ply, releaseVelocity, swingPhase)
    end
    
    -- Notify the pendulum physics system that the swing is ending
    if self.PendulumPhysics then
        self.PendulumPhysics:OnSwingEnd(rag, ply, releaseVelocity)
    end
    
    -- Record the web release in the Flow State system
    if self.FlowStateSystem and self.RhythmSystem then
        -- Calculate release accuracy based on rhythm system's optimal release point
        local releaseAccuracy = 0.5 -- Default moderate accuracy
        
        if self.RhythmSystem.OptimalReleasePoint > 0 then
            -- Calculate how close we are to the optimal release point
            releaseAccuracy = 1 - math.min(math.abs(swingPhase - self.RhythmSystem.OptimalReleasePoint), 0.5) * 2
        end
        
        -- Record the release in the flow system
        self.FlowStateSystem:RecordWebRelease(releaseAccuracy)
    end
    
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

    if self.RagdollActive and self.RhythmSystem then
        -- Record the swing release and get release accuracy
        local swingDuration = CurTime() - self.RhythmSystem.LastSwingTime
        local releaseAccuracy = self.RhythmSystem:RecordRelease(swingDuration)
        
        -- Apply a momentum boost based on release timing accuracy
        if releaseAccuracy > 0.7 and GetConVar("webswing_rhythm_boost"):GetBool() then
            local boostStrength = releaseAccuracy * 0.3
            local currentVel = self.Owner:GetVelocity()
            local boostVel = currentVel:GetNormalized() * currentVel:Length() * boostStrength
            self.Owner:SetVelocity(boostVel)
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
    -- No need to clean up camera hooks - using global hook
    
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
    
    -- Make sure we're properly cleaning up hooks
    hook.Remove("PostSwingPhysics", "PendulumPhysics_PostProcess")
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
    -- Check if the ConVar allows sky attachments
    local allowSkyAttach = GetConVar("webswing_allow_sky_attach"):GetBool()
    
    -- If sky attachments are allowed, skip the checks
    if allowSkyAttach then
        return true
    end
    
    -- Check if the point is too high (potential sky attachment)
    local upTrace = util.TraceLine({
        start = pos,
        endpos = pos + Vector(0, 0, 100),
        mask = MASK_SOLID
    })
    
    -- If nothing above us, this might be a sky point
    if not upTrace.Hit then
        -- Do an additional check for nearby surfaces
        local surroundTraces = {}
        local directions = {
            Vector(1, 0, 0),
            Vector(-1, 0, 0),
            Vector(0, 1, 0),
            Vector(0, -1, 0)
        }
        
        -- Check for nearby surfaces in several directions
        for _, dir in ipairs(directions) do
            local surroundTrace = util.TraceLine({
                start = pos,
                endpos = pos + dir * 100,
                mask = MASK_SOLID
            })
            
            if surroundTrace.Hit and not surroundTrace.HitSky then
                table.insert(surroundTraces, surroundTrace)
            end
        end
        
        -- If we don't have at least 1 nearby surface, assume it's a sky point
        if #surroundTraces < 1 then
            return false
        end
    elseif upTrace.HitSky then
        -- If we directly hit sky, definitely reject
        return false
    end
    
    -- Trace from player to swing point to ensure it's not blocked by sky
    local traceToPoint = util.TraceLine({
        start = playerPos,
        endpos = pos,
        mask = MASK_SOLID
    })
    
    if traceToPoint.HitSky then
        return false
    end
    
    -- If it passed all checks, it's valid
    return true
end

-- Add this function to calculate optimal sky height
function SWEP:CalculateOptimalSkyHeight(eyePos, velocity, distToGround)
    -- Base height is proportional to distance to ground
    local baseHeight = math.max(distToGround * 1.5, 300)
    
    -- Add height based on current speed (faster = higher potential)
    local speedFactor = math.min(velocity:Length() / 1000, 1)
    local speedBonus = speedFactor * 400
    
    -- Calculate final height
    local finalHeight = baseHeight + speedBonus
    
    -- Cap the height at reasonable limits
    return math.Clamp(finalHeight, 300, 1500)
end

-- Now modify GatherSwingPointCandidates to use this function
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
    
    -- Add dynamic swing points if available
    if #candidates < 4 and not GetConVar("webswing_manual_mode"):GetBool() then
        -- Generate dynamic points to help maintain flow
        local dynamicPoints = SwingTargeting:GenerateDynamicPoints(candidates, eyePos, vel, ply:GetAimVector())
        
        -- Add dynamic points to candidates with sky check
        for _, dynamicPoint in ipairs(dynamicPoints) do
            -- Skip if too close to existing points
            local tooClose = false
            for _, existingPoint in ipairs(candidates) do
                if existingPoint.pos:Distance(dynamicPoint.pos) < 100 then
                    tooClose = true
                    break
                end
            end
            
            -- Check that it's not a sky point before adding
            if not tooClose and self:IsValidSwingPoint(dynamicPoint.pos, eyePos) then
                table.insert(candidates, dynamicPoint)
                
                -- Debug visualization for dynamic points
                if CLIENT and GetConVar("webswing_show_ai_indicator"):GetBool() then
                    debugoverlay.Sphere(dynamicPoint.pos, 8, 0.2, Color(0, 255, 255, 180))
                    debugoverlay.Text(dynamicPoint.pos, "Dynamic", 0.2, true)
                end
            end
        end
        
        if GetConVar("developer"):GetBool() then
            print(string.format("[Web Shooter] Added %d dynamic swing points", #dynamicPoints))
        end
    end
    
    -- Apply curved path planning if the player is moving at a decent speed
    if speed > 200 and not GetConVar("webswing_manual_mode"):GetBool() then
        -- Apply curved path planning to add path target points
        local candidatesWithPaths = SwingTargeting:ApplyCurvedPathPlanning(candidates, eyePos, vel, ply:GetAimVector())
        
        -- New: Verify each path point before accepting
        candidates = {}
        for _, candidate in ipairs(candidatesWithPaths) do
            if not candidate.isPathPoint or self:IsValidSwingPoint(candidate.pos, eyePos) then
                table.insert(candidates, candidate)
            end
        end
        
        if GetConVar("developer"):GetBool() then
            print("[Web Shooter] Applied curved path planning")
        end
    end
    
    -- Final safety check - verify each candidate
    local validCandidates = {}
    for _, candidate in ipairs(candidates) do
        if self:IsValidSwingPoint(candidate.pos, eyePos) or 
           (candidate.type == "sky" and allowSkyAttach) then
            table.insert(validCandidates, candidate)
        end
    end
    
    return validCandidates
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
    
    -- Check ground distance - needed for all candidate types
    local groundTrace = util.TraceLine({
        start = eyePos,
        endpos = eyePos - Vector(0, 0, 1000),
        filter = ply,
        mask = MASK_SOLID
    })
    local distToGround = groundTrace.Hit and groundTrace.HitPos:Distance(eyePos) or 1000
    
    -- Check if this is a curved path point
    if candidate.isPathPoint then
        -- For curved path points, use a specialized scoring function
        local pathScore = SwingTargeting:EvaluatePathTarget(candidate)
        
        -- Adjust the path score based on player settings and state
        if speedSqr > 90000 then -- Over 300 units/sec
            pathScore = pathScore * (1 + swingCurve * 0.5) -- Higher curve preference gives higher path scores
        end
        
        -- Ensure path points are still subject to some basic constraints
        local dist = candidate.pos:Distance(eyePos)
        if dist > maxWebLength then
            return -1000 -- Still reject points beyond max web length
        end
        
        -- Emergency conditions can override path following
        if distToGround < 100 and candidate.pos.z < eyePos.z then
            pathScore = pathScore * 0.5 -- Reduce priority when close to ground
        end
        
        return pathScore
    end
    
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
    
    -- Apply momentum-aware targeting from the SwingTargeting module
    if speedSqr > 40000 then -- Only apply momentum targeting at speeds over 200
        local momentumScore = SwingTargeting:EvaluateMomentumPreservation(candidate, eyePos, vel, playerState.aimVector)
        score = score + momentumScore * momentumFactor
    end
    
    -- Special handling for dynamic points
    if candidate.isDynamic then
        -- Dynamic points get a base bonus to make them viable
        score = score + 0.2
        
        -- But ensure they're even more strongly affected by momentum direction
        if speedSqr > 40000 then -- Only at higher speeds
            local velDir = vel:GetNormalized()
            local toPoint = (candidate.pos - eyePos):GetNormalized()
            local momentumAlign = velDir:Dot(toPoint)
            
            -- Only boost score if it aligns well with momentum
            if momentumAlign > 0.7 then
                score = score + momentumAlign * 0.3 * momentumFactor
            end
        end
    end
    
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
        local baseMomentumScore = math.Clamp(momentumAlign + 0.5, 0, 1) * momentumFactor
        local pathScore = math.Clamp(idealAlign + 0.5, 0, 1) * assistStrength
        
        -- Adjust based on curve preference
        local curveWeight = Lerp(swingCurve, 0.7, 0.3) -- More curve means less emphasis on pure momentum
        score = score + (baseMomentumScore * curveWeight + pathScore * (1 - curveWeight))
    end
    
    -- Corner point bonus with curve consideration
    if candidate.isCorner then
        local cornerBonus = 0.2 * assistStrength
        if candidate.overhead and candidate.overhead.clear then
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
    
    --------------------------------------------------------------------
    -- Begin Enhanced Swing Point Evaluation (New factors added here) --
    --------------------------------------------------------------------
    local assistStrength = GetAssistStrength()  -- Ensure we have this for scaling

    -- Entity Stability Bonus:
    if IsValid(candidate.entity) then
        if candidate.entity:IsWorld() then
            -- Static world surfaces get a bonus
            score = score + 0.1 * assistStrength
        else
            local phys = candidate.entity:GetPhysicsObject()
            if IsValid(phys) then
                local entVel = phys:GetVelocity():Length()
                if entVel > 20 then
                    -- Penalize web points on moving entities
                    score = score - 0.15 * assistStrength
                else
                    -- Stable non-world objects get a slight bonus
                    score = score + 0.05 * assistStrength
                end
            end
        end
    end

    -- Surface Normal Alignment Bonus:
    local upwardAlignment = candidate.normal:Dot(Vector(0, 0, 1))
    if upwardAlignment < 0.3 then
         -- Almost vertical surface: good for anchoring => bonus
         score = score + 0.1 * assistStrength
    elseif upwardAlignment > 0.7 then
         -- Nearly horizontal surface: less ideal for a stable swing => penalty
         score = score - 0.1 * assistStrength
    end
    --------------------------------------------------------------------
    -- End Enhanced Swing Point Evaluation ---------------------------
    
    -- In SWEP:EvaluateSwingCandidate, after your existing emergency recovery scoring block,
    -- add the following code:

    -- Context-Aware Adjustments based on environment analysis
    if self.MapAnalysis and self.MapAnalysis.analyzed then
        local buildingDensity = self.MapAnalysis.buildingDensity or 0
        local openSpaceRatio = self.MapAnalysis.openSpaceRatio or 0
        
        -- Calculate distance from the player for context-based decisions
        local dist = candidate.pos:Distance(eyePos)
        
        if buildingDensity > 0.7 then
            -- Dense urban environment: favor nearby, accessible points and corner attachments.
            if dist < 400 then
                score = score + 0.2 * assistStrength  -- bonus for being close in dense areas
            else
                score = score - 0.1 * assistStrength  -- penalty for being too far in dense areas
            end
            
            -- Penalize overly high overhead points in a dense urban setting.
            if candidate.type == "overhead" and (candidate.pos.z - eyePos.z) > 300 then
                score = score - 0.15 * assistStrength
            end
        elseif openSpaceRatio > 0.7 then
            -- Open areas: longer-range swing points are more feasible.
            if dist > 600 then
                score = score + 0.15 * momentumFactor
            end
            
            -- Provide additional bonus for sky or momentum-based swing points.
            if candidate.type == "sky" or candidate.type == "sky_momentum" then
                score = score + 0.1 * assistStrength
            end
        end
    end
    
    -- Additional Inertia-Based (Neural-like) Scoring Factor:
    -- When the player is moving fast, we predict the near-future velocity and add a bonus
    -- if the candidate point aligns with the predicted direction.
    if speed > 300 then
        local predictedVel
        if self.PrevEvalVelocity then
            -- Calculate acceleration based on change in velocity over the frame time
            local acceleration = (vel - self.PrevEvalVelocity) / FrameTime()
            predictedVel = vel + acceleration * 0.1  -- Look ahead 0.1 seconds
        else
            predictedVel = vel
        end
        self.PrevEvalVelocity = vel  -- Store current velocity for the next evaluation

        -- Compute predicted alignment with candidate direction
        local predictedAlignment = predictedVel:GetNormalized():Dot((candidate.pos - eyePos):GetNormalized())
        predictedAlignment = math.Clamp(predictedAlignment, 0, 1)
        score = score + predictedAlignment * 0.2  -- Tune this bonus weight as necessary
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
    
    -- Get AI prediction for swing targeting
    local prediction = SwingTargeting:PredictNextTargetPoint(ply, eyePos, vel, ply:GetAimVector())
    
    local bestCandidate = nil
    local bestScore = -1
    local debugScores = {}
    
    for i, candidate in ipairs(candidates) do
        local baseScore = self:EvaluateSwingCandidate(candidate, playerState, candidates)
        
        -- Apply prediction score modifier from AI Swing Targeting system
        local predictionScore = SwingTargeting:ApplyPredictionToCandidate(candidate, prediction, eyePos)
        local finalScore = baseScore + predictionScore
        
        -- Store debug info about scoring
        if GetConVar("developer"):GetBool() then
            table.insert(debugScores, {
                pos = candidate.pos,
                type = candidate.type,
                score = finalScore,
                baseScore = baseScore,
                predScore = predictionScore,
                height = candidate.pos.z - eyePos.z,
                dist = candidate.pos:Distance(eyePos)
            })
        end
        
        -- Debug visualization
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
    
    -- Log detailed scoring info if in developer mode
    if GetConVar("developer"):GetBool() and #debugScores > 0 then
        print("\n[Web Shooter] Candidate Scores:")
        table.sort(debugScores, function(a, b) return a.score > b.score end)
        for i, info in ipairs(debugScores) do
            if i <= 3 then -- Only show top 3 scores
                print(string.format("  %d. Type: %s, Score: %.2f (Base: %.2f, Pred: %.2f), Height: %.1f, Dist: %.1f",
                    i, info.type, info.score, info.baseScore, info.predScore, info.height, info.dist))
            end
        end
    end
    
    -- Debug visualization for prediction
    if CLIENT and GetConVar("webswing_show_ai_indicator"):GetBool() and prediction and prediction.targetPos then
        local duration = 0.1
        debugoverlay.Sphere(prediction.targetPos, 5, duration, Color(0, 150, 255, 180))
        debugoverlay.Line(eyePos, prediction.targetPos, duration, Color(0, 150, 255, 180))
        
        if bestCandidate then
            debugoverlay.Line(eyePos, bestCandidate.pos, duration, Color(0, 255, 0, 180))
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
    self.BaseRange = self.Range or 2000
    if not GetConVar("webswing_manual_mode"):GetBool() then
        local baseRadius = self.BaseRange
        -- Adjust range based on building density
        self.Range = baseRadius * (1 + (1 - self.MapAnalysis.buildingDensity) * 0.5)
        -- Additional range adjustment based on open space: increase range if area is open, decrease if densely built
        if self.MapAnalysis.openSpaceRatio and self.MapAnalysis.openSpaceRatio > 0.7 then
            self.Range = self.Range * 1.1
        elseif self.MapAnalysis.buildingDensity and self.MapAnalysis.buildingDensity > 0.7 then
            self.Range = self.Range * 0.9
        end
    else
        self.Range = self.BaseRange
    end
     
    -- Adjust optimal swing height based on average building height
    local optimalHeightRatio = math.Clamp(self.MapAnalysis.averageHeight / 1000, 0.5, 2)
    self.OptimalSwingHeight = 150 * optimalHeightRatio
    -- Adjust search points: for open spaces use fewer search points to speed up candidate evaluation
    if self.MapAnalysis.openSpaceRatio and self.MapAnalysis.openSpaceRatio > 0.7 then
        self.SearchPoints = math.floor(16 * (1 + self.MapAnalysis.buildingDensity) * 0.8)
    else
        self.SearchPoints = math.floor(16 * (1 + self.MapAnalysis.buildingDensity))
    end
     
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
                SwingTargeting:RecordSwingEvent(swingQuality, hitPos, vel)
                
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
    -- Clean up flow state hook and global reference
    if CLIENT then
        hook.Remove("RenderScreenspaceEffects", "FlowState_ScreenEffects")
        
        -- Only clear the global if it belongs to this weapon
        if _G.ActiveFlowSystem == self.FlowStateSystem then
            _G.ActiveFlowSystem = nil
        end
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
    hook.Remove("PostSwingPhysics", "PendulumPhysics_PostProcess")
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
	
	-- Reset rhythm system if it exists
	if self.RhythmScore then
		self.RhythmScore = 0
		self.IsInRhythm = false
		self.SwingPhase = 0
		self.OptimalReleasePoint = 0
		self.NextPredictedSwingTime = 0
		self.ConsistencyScore = 0
		self.LastSwingWasPerfect = false
		self.LastSwingTime = 0
	end
	
	-- Reset any active effects
	if hook.GetTable()["PostSwingPhysics"] and hook.GetTable()["PostSwingPhysics"]["PendulumPhysics_PostProcess"] then
		hook.Remove("PostSwingPhysics", "PendulumPhysics_PostProcess")
	end
end