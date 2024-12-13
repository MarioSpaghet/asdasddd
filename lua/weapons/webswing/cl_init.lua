--My (crappy?) way of hiding the view model without stripping weapons
function SWEP:GetViewModelPosition( pos, ang )
	if self.RagdollActive then
		--print("new pos")
		return Vector(-5000,-5000,-5000), ang
	end
end


--Construction Kit code

SWEP.IronSightsPos = Vector(4.489, 0, -5.04)
SWEP.IronSightsAng = Vector(8.296, 8.869, 3.239)

SWEP.VElements = { 
}
SWEP.WElements = { 
}
--easy fix, too lazy to add these manually
for _,t in pairs(SWEP.WElements) do
	t.angle2 = t.angle
	t.pos2 = t.pos
end

include("shared.lua")

SWEP.vRenderOrder = nil
function SWEP:ViewModelDrawn()
	
	local vm = self.Owner:GetViewModel()
	if !IsValid(vm) then return end
	
	if (!self.VElements) then return end
	
	self:UpdateBonePositions(vm)
	
	--custom addition here, dont show if we are roped
	if self:GetNetworkedBool("wt_ragdollactive", false) then
		--print("Hiding view elements")
		self.UseHands = false
		return
	else
		self.UseHands = true
	end
	--

	if (!self.vRenderOrder) then
		
		// we build a render order because sprites need to be drawn after models
		self.vRenderOrder = {}

		for k, v in pairs( self.VElements ) do
			if (v.type == "Model") then
				table.insert(self.vRenderOrder, 1, k)
			elseif (v.type == "Sprite" or v.type == "Quad") then
				table.insert(self.vRenderOrder, k)
			end
		end
		
	end

	for k, name in ipairs( self.vRenderOrder ) do
	
		local v = self.VElements[name]
		if (!v) then self.vRenderOrder = nil break end
		if (v.hide) then continue end
		
		local model = v.modelEnt
		local sprite = v.spriteMaterial
		
		if (!v.bone) then continue end
		
		local pos, ang = self:GetBoneOrientation( self.VElements, v, vm )
		
		if (!pos) then continue end
		
		if (v.type == "Model" and IsValid(model)) then

			model:SetPos(pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z )
			ang:RotateAroundAxis(ang:Up(), v.angle.y)
			ang:RotateAroundAxis(ang:Right(), v.angle.p)
			ang:RotateAroundAxis(ang:Forward(), v.angle.r)

			model:SetAngles(ang)
			//model:SetModelScale(v.size)
			local matrix = Matrix()
			matrix:Scale(v.size)
			model:EnableMatrix( "RenderMultiply", matrix )
			
			if (v.material == "") then
				model:SetMaterial("")
			elseif (model:GetMaterial() != v.material) then
				model:SetMaterial( v.material )
			end
			
			if (v.skin and v.skin != model:GetSkin()) then
				model:SetSkin(v.skin)
			end
			
			if (v.bodygroup) then
				for k, v in pairs( v.bodygroup ) do
					if (model:GetBodygroup(k) != v) then
						model:SetBodygroup(k, v)
					end
				end
			end
			
			if (v.surpresslightning) then
				render.SuppressEngineLighting(true)
			end
			
			render.SetColorModulation(v.color.r/255, v.color.g/255, v.color.b/255)
			render.SetBlend(v.color.a/255)
			model:DrawModel()
			render.SetBlend(1)
			render.SetColorModulation(1, 1, 1)
			
			if (v.surpresslightning) then
				render.SuppressEngineLighting(false)
			end
			
		elseif (v.type == "Sprite" and sprite) then
			
			local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
			render.SetMaterial(sprite)
			render.DrawSprite(drawpos, v.size.x, v.size.y, v.color)
			
		elseif (v.type == "Quad" and v.draw_func) then
			
			local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
			ang:RotateAroundAxis(ang:Up(), v.angle.y)
			ang:RotateAroundAxis(ang:Right(), v.angle.p)
			ang:RotateAroundAxis(ang:Forward(), v.angle.r)
			
			cam.Start3D2D(drawpos, ang, v.size)
				v.draw_func( self )
			cam.End3D2D()

		end
		
	end
	
end

SWEP.wRenderOrder = nil
function SWEP:DrawWorldModel()

	--Don't draw it on players that are ragdolling
	if self:GetNetworkedBool("wt_ragdollactive", false) then
		return
	end

	local onSelf = false

	local bone_ent
	if (IsValid(self.Owner)) then
		bone_ent = self.Owner
	else
		// when the weapon is dropped
		bone_ent = self
		onSelf = true
		--print("draw on self")
	end
	
	if bone_ent == self then
		--self:DrawModel()
	else
		if (self.ShowWorldModel == nil or self.ShowWorldModel) then
			self:DrawModel()
		end
	end
	
	if (!self.WElements) then
		--print("no welements!")
		return
	end
	
	if (!self.wRenderOrder) then
	
		--print("Create render order")

		self.wRenderOrder = {}

		for k, v in pairs( self.WElements ) do
			if (v.type == "Model") then
				table.insert(self.wRenderOrder, 1, k)
			elseif (v.type == "Sprite" or v.type == "Quad") then
				table.insert(self.wRenderOrder, k)
			end
		end

	end
	
	
	for k, name in pairs( self.wRenderOrder ) do
	
		--print("Render",k,name)
	
		local v = self.WElements[name]
		if (!v) then self.wRenderOrder = nil break end
		if (v.hide) then continue end
		
		local pos, ang
		

		if (v.bone) then
			--print("Get position of bone")
			pos, ang = self:GetBoneOrientation( self.WElements, v, bone_ent, nil, onSelf )
		else
			--print("Get position of hand")
			pos, ang = self:GetBoneOrientation( self.WElements, v, bone_ent, "ValveBiped.Bip01_R_Hand", onSelf )
		end
		
		if (!pos) then continue end
		
		local model = v.modelEnt
		local sprite = v.spriteMaterial
		
		if (v.type == "Model" and IsValid(model)) then
			
			local vpos = onSelf and v.pos2 or v.pos
			model:SetPos(pos + ang:Forward() * vpos.x + ang:Right() * vpos.y + ang:Up() * vpos.z )
			
			if not onSelf then
				ang:RotateAroundAxis(ang:Up(), v.angle.y)
				ang:RotateAroundAxis(ang:Right(), v.angle.p)
				ang:RotateAroundAxis(ang:Forward(), v.angle.r)
			else
				ang:RotateAroundAxis(ang:Up(), v.angle2.y)
				ang:RotateAroundAxis(ang:Right(), v.angle2.p)
				ang:RotateAroundAxis(ang:Forward(), v.angle2.r)
			end

			model:SetAngles(ang)
			//model:SetModelScale(v.size)
			local matrix = Matrix()
			matrix:Scale(v.size)
			model:EnableMatrix( "RenderMultiply", matrix )
			
			if (v.material == "") then
				model:SetMaterial("")
			elseif (model:GetMaterial() != v.material) then
				model:SetMaterial( v.material )
			end
			
			if (v.skin and v.skin != model:GetSkin()) then
				model:SetSkin(v.skin)
			end
			
			if (v.bodygroup) then
				for k, v in pairs( v.bodygroup ) do
					if (model:GetBodygroup(k) != v) then
						model:SetBodygroup(k, v)
					end
				end
			end
			
			if (v.surpresslightning) then
				render.SuppressEngineLighting(true)
			end
			
			render.SetColorModulation(v.color.r/255, v.color.g/255, v.color.b/255)
			render.SetBlend(v.color.a/255)
			model:DrawModel()
			render.SetBlend(1)
			render.SetColorModulation(1, 1, 1)
			
			if (v.surpresslightning) then
				render.SuppressEngineLighting(false)
			end
			
		elseif (v.type == "Sprite" and sprite) then
			
			local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
			render.SetMaterial(sprite)
			render.DrawSprite(drawpos, v.size.x, v.size.y, v.color)
			
		elseif (v.type == "Quad" and v.draw_func) then
			
			local vpos = onSelf and v.pos2 or v.pos
			local drawpos = pos + ang:Forward() * vpos.x + ang:Right() * vpos.y + ang:Up() * vpos.z
			
			if not onSelf then
				ang:RotateAroundAxis(ang:Up(), v.angle.y)
				ang:RotateAroundAxis(ang:Right(), v.angle.p)
				ang:RotateAroundAxis(ang:Forward(), v.angle.r)
			else
				ang:RotateAroundAxis(ang:Up(), v.angle2.y)
				ang:RotateAroundAxis(ang:Right(), v.angle2.p)
				ang:RotateAroundAxis(ang:Forward(), v.angle2.r)
			end
			
			cam.Start3D2D(drawpos, ang, v.size)
				v.draw_func( self )
			cam.End3D2D()

		end
		
	end
	
end

function SWEP:GetBoneOrientation( basetab, tab, ent, bone_override, onWorldModel )
	
	local bone, pos, ang
	if (tab.rel and tab.rel != "") then
		
		local v = basetab[tab.rel]
		
		if (!v) then return end
		
		-- Technically, if there exists an element with the same name as a bone
		-- you can get in an infinite loop. Let's just hope nobody's that stupid.
		pos, ang = self:GetBoneOrientation( basetab, v, ent, nil, onWorldModel )
		
		if (!pos) then return end
		
		local vpos = onWorldModel and v.pos2 or v.pos
		pos = pos + ang:Forward() * vpos.x + ang:Right() * vpos.y + ang:Up() * vpos.z
		
		if not onWorldModel then
			ang:RotateAroundAxis(ang:Up(), v.angle.y)
			ang:RotateAroundAxis(ang:Right(), v.angle.p)
			ang:RotateAroundAxis(ang:Forward(), v.angle.r)
		else
			ang:RotateAroundAxis(ang:Up(), v.angle2.y)
			ang:RotateAroundAxis(ang:Right(), v.angle2.p)
			ang:RotateAroundAxis(ang:Forward(), v.angle2.r)
		end
			
	else
		
		if onWorldModel then
			bone = 0
		else
			bone = ent:LookupBone(bone_override or tab.bone)
		end

		if (!bone) then return end
		
		pos, ang = Vector(0,0,0), Angle(0,0,0)
		local m = ent:GetBoneMatrix(bone)
		if (m) then
			pos, ang = m:GetTranslation(), m:GetAngles()
		end
		
		if (IsValid(self.Owner) and self.Owner:IsPlayer() and 
			ent == self.Owner:GetViewModel() and self.ViewModelFlip) then
			ang.r = -ang.r // Fixes mirrored models
		end
	
	end
	
	return pos, ang
end

function SWEP:CreateModels( tab )

	if (!tab) then return end

	// Create the clientside models here because Garry says we can't do it in the render hook
	for k, v in pairs( tab ) do
		if (v.type == "Model" and v.model and v.model != "" and (!IsValid(v.modelEnt) or v.createdModel != v.model) and 
				string.find(v.model, ".mdl") and file.Exists (v.model, "GAME") ) then
			
			v.modelEnt = ClientsideModel(v.model, RENDER_GROUP_VIEW_MODEL_OPAQUE)
			if (IsValid(v.modelEnt)) then
				v.modelEnt:SetPos(self:GetPos())
				v.modelEnt:SetAngles(self:GetAngles())
				v.modelEnt:SetParent(self)
				v.modelEnt:SetNoDraw(true)
				v.createdModel = v.model
			else
				v.modelEnt = nil
			end
			
		elseif (v.type == "Sprite" and v.sprite and v.sprite != "" and (!v.spriteMaterial or v.createdSprite != v.sprite) 
			and file.Exists ("materials/"..v.sprite..".vmt", "GAME")) then
			
			local name = v.sprite.."-"
			local params = { ["$basetexture"] = v.sprite }
			// make sure we create a unique name based on the selected options
			local tocheck = { "nocull", "additive", "vertexalpha", "vertexcolor", "ignorez" }
			for i, j in pairs( tocheck ) do
				if (v[j]) then
					params["$"..j] = 1
					name = name.."1"
				else
					name = name.."0"
				end
			end

			v.createdSprite = v.sprite
			v.spriteMaterial = CreateMaterial(name,"UnlitGeneric",params)
			
		end
	end
	
end

local allbones
local hasGarryFixedBoneScalingYet = false

function SWEP:UpdateBonePositions(vm)
	
	if self.ViewModelBoneMods then
		
		if (!vm:GetBoneCount()) then return end
		
		-- !! WORKAROUND !!
		-- We need to check all model names :/
		local loopthrough = self.ViewModelBoneMods
		if (!hasGarryFixedBoneScalingYet) then
			allbones = {}
			for i=0, vm:GetBoneCount() do
				local bonename = vm:GetBoneName(i)
				if (self.ViewModelBoneMods[bonename]) then 
					allbones[bonename] = self.ViewModelBoneMods[bonename]
				else
					allbones[bonename] = { 
						scale = Vector(1,1,1),
						pos = Vector(0,0,0),
						angle = Angle(0,0,0)
					}
				end
			end
			
			loopthrough = allbones
		end
		-- !! ----------- !!
		
		for k, v in pairs( loopthrough ) do
			local bone = vm:LookupBone(k)
			if (!bone) then continue end
			
			-- !! WORKAROUND !!
			local s = Vector(v.scale.x,v.scale.y,v.scale.z)
			local p = Vector(v.pos.x,v.pos.y,v.pos.z)
			local ms = Vector(1,1,1)
			if (!hasGarryFixedBoneScalingYet) then
				local cur = vm:GetBoneParent(bone)
				while(cur >= 0) do
					local pscale = loopthrough[vm:GetBoneName(cur)].scale
					ms = ms * pscale
					cur = vm:GetBoneParent(cur)
				end
			end
			
			s = s * ms
			-- !! ----------- !!
			
			if vm:GetManipulateBoneScale(bone) != s then
				vm:ManipulateBoneScale( bone, s )
			end
			if vm:GetManipulateBoneAngles(bone) != v.angle then
				vm:ManipulateBoneAngles( bone, v.angle )
			end
			if vm:GetManipulateBonePosition(bone) != p then
				vm:ManipulateBonePosition( bone, p )
			end
		end
	else
		self:ResetBonePositions(vm)
	end
	   
end
 
function SWEP:ResetBonePositions(vm)
	
	if (!vm:GetBoneCount()) then return end
	for i=0, vm:GetBoneCount() do
		vm:ManipulateBoneScale( i, Vector(1, 1, 1) )
		vm:ManipulateBoneAngles( i, Angle(0, 0, 0) )
		vm:ManipulateBonePosition( i, Vector(0, 0, 0) )
	end
	
end

--[[**************************
	Global utility code
**************************]]

-- Fully copies the table, meaning all tables inside this table are copied too and so on (normal table.Copy copies only their reference).
-- Does not copy entities of course, only copies their reference.
-- WARNING: do not use on tables that contain themselves somewhere down the line or you'll get an infinite loop
if not table.FullCopy then
	function table.FullCopy( tab )
		if (!tab) then return nil end
		
		local res = {}
		for k, v in pairs( tab ) do
			if (type(v) == "table") then
				res[k] = table.FullCopy(v) // recursion ho!
			elseif (type(v) == "Vector") then
				res[k] = Vector(v.x, v.y, v.z)
			elseif (type(v) == "Angle") then
				res[k] = Angle(v.p, v.y, v.r)
			else
				res[k] = v
			end
		end
		
		return res
	end
end

--End construction kit

--[[ --- Add WebSwing Settings Panel to Utilities Menu --- ]]
-- Create ConVar to store the fall damage setting
CreateClientConVar("webswing_enable_fall_damage", "0", true, true, "Enable fall damage when using WebSwing", 0, 1)

-- Modify the settings panel to use net messages instead of creating a client ConVar
hook.Add("PopulateToolMenu", "WebSwing_AddSettings", function()
    spawnmenu.AddToolMenuOption("Utilities", "WebSwing", "WebSwingSettings", "WebSwing Settings", "", "", function(panel)
        panel:ClearControls()
        
        panel:Help("WebSwing Settings")
        
        -- Manual Mode Checkbox (Old Style Web-Swing)
        local manualCheckbox = panel:CheckBox("Manual Web-Swing (Old Style)", "webswing_manual_mode")
        manualCheckbox:SetTooltip("When enabled, webs will shoot exactly where you're aiming (like the old style). When disabled, the AI will choose optimal swing points.")
        
        -- Existing Fall Damage Checkbox
        local checkbox = panel:CheckBox("Fall Damage", "webswing_enable_fall_damage")
        checkbox:SetTooltip("When checked, fall damage is enabled while using WebSwing")

        -- Add Swing Speed Slider
        local slider = panel:NumSlider("Swing Speed", "webswing_swing_speed", 400, 1200, 0)
        slider:SetTooltip("Adjust the swing force when using web swing (Default: 800)")
        
        -- Define a table mapping display names to material paths
        local ropeMaterials = {
            ["Default"]         = "cable/xbeam",
            ["Rope"]           = "cable/rope",
            ["Hydra"]          = "cable/hydra",
            ["Blue Electric"]  = "cable/blue_elec",
            ["Red Laser"]      = "cable/redlaser",
            ["Cable"]          = "cable/cable2",
            ["Phys Beam"]      = "cable/physbeam",
        }

        -- Create the ComboBox for selecting rope material
        local combo = panel:ComboBox("Rope Material", "webswing_rope_material")
        for displayName, materialPath in pairs(ropeMaterials) do
            combo:AddChoice(displayName, materialPath)
        end

        -- Function to set the ComboBox value based on the current ConVar
        local function SetComboBoxValue()
            local currentMaterial = GetConVar("webswing_rope_material"):GetString()
            for displayName, materialPath in pairs(ropeMaterials) do
                if materialPath == currentMaterial then
                    combo:SetValue(displayName)
                    break
                end
            end
        end

        -- Initialize the ComboBox with the current material selection
        SetComboBoxValue()

        -- Handle the selection and send the corresponding material path to the server
        combo.OnSelect = function(self, index, value)
            local selectedMaterial = ropeMaterials[value]
            if selectedMaterial then
                net.Start("WebSwing_SetRopeMaterial")
                    net.WriteString(selectedMaterial)
                net.SendToServer()
            end
        end
    end)
end)