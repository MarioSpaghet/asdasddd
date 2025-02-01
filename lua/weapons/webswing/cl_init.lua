-- Create client-side ConVars at file scope
CreateClientConVar("webswing_web_color_r", "255", true, false, "Red component of web color")
CreateClientConVar("webswing_web_color_g", "255", true, false, "Green component of web color")
CreateClientConVar("webswing_web_color_b", "255", true, false, "Blue component of web color")
CreateClientConVar("webswing_rope_material", "cable/xbeam", true, true, "Material used for the web rope")
CreateClientConVar("webswing_show_ai_indicator", "0", true, false, "Show the AI web point indicator")
CreateClientConVar("webswing_sound_set", "Tom Holland", true, true, "Sound set for web shooters")
CreateClientConVar("webswing_web_material", "cable/xbeam", true, true, "Material used for the web")

-- Initialize client-side ConVars
CreateClientConVar("webswing_manual_mode", "0", true, false, "Use manual web-swing mode (old style)")
CreateClientConVar("webswing_show_ai_indicator", "0", true, false, "Show AI swing point indicator")

--My (crappy?) way of hiding the view model without stripping weapons
function SWEP:GetViewModelPosition( pos, ang )
	if self.RagdollActive then
		--print("new pos")
		return Vector(-5000,-5000,-5000), ang
	end
end

-- Add customization menu
hook.Add("PopulateToolMenu", "WebSwing_Options", function()
    spawnmenu.AddToolMenuOption("Options", "Spider-Man", "WebSwing_Config", "Web Shooters", "", "", function(panel)
        panel:ClearControls()
        
        -- Add Swing Speed Slider
        local slider = panel:NumSlider("Swing Speed", "webswing_swing_speed", 400, 1200, 0)
        slider:SetTooltip("Adjust the swing force and rope length behavior (Higher values = more power and tighter rope at speed)")
        
        -- Manual Mode Toggle
        panel:Help("Swing Mode")
        local manualCheck = panel:CheckBox("Manual Mode (Classic Style)", "webswing_manual_mode")
        manualCheck:SetTooltip("When enabled, web will attach exactly where you aim. When disabled, it will automatically find the best swing point.")
        
        -- Sky Attachment Options
        panel:Help("Sky Attachment Options")
        local skyCheck = panel:CheckBox("Attach to an Uncle Ben", "webswing_allow_sky_attach")
        skyCheck:SetTooltip("When enabled, you can attach webs to an Uncle Ben when no other points are available. Height is automatically adjusted based on speed and environment.")
        
        -- Fall Damage Toggle
        local fallDamageCheck = panel:CheckBox("Enable Fall Damage", "webswing_enable_fall_damage")
        fallDamageCheck:SetTooltip("When enabled, you will take fall damage while using web swing.")
        
        -- Web Persistence Toggle
        local webPersistCheck = panel:CheckBox("Keep Webs After Detaching", "webswing_keep_webs")
        webPersistCheck:SetTooltip("When enabled, webs will stay visible for 30 seconds after detaching.")
        
        -- AI Indicator Toggle
        local aiIndicatorCheck = panel:CheckBox("DEBUG:Show AI Swing Point Indicator", "webswing_show_ai_indicator")
        aiIndicatorCheck:SetTooltip("When enabled, shows where the AI will attach the web in automatic mode.")
        
        -- Dynamic Rope Length Settings
        panel:Help("Dynamic Rope Length Settings")
        
        local dynamicLengthCheck = panel:CheckBox("Enable Dynamic Rope Length", "webswing_dynamic_length")
        dynamicLengthCheck:SetTooltip("When enabled, rope length will automatically adjust based on swing angle and speed")
        
        local angleFactorSlider = panel:NumSlider("Angle Factor", "webswing_length_angle_factor", 0, 2, 2)
        angleFactorSlider:SetTooltip("How much swing angle affects rope length (0 = no effect, 2 = maximum effect)")
        
        local minLengthSlider = panel:NumSlider("Minimum Length Ratio", "webswing_min_length_ratio", 0.1, 1, 2)
        minLengthSlider:SetTooltip("Minimum rope length as a ratio of initial length (0.1 = very short, 1 = original length)")
        
        -- Sound set selection
        panel:Help("Web Shooter Sound Set")
        local soundCombo = panel:ComboBox("Sound Set", "webswing_sound_set")
        soundCombo:SetSortItems(false)
        soundCombo:AddChoice("Tom Holland", "Tom Holland")
        soundCombo:AddChoice("Tobey Maguire", "Tobey Maguire")
        soundCombo:AddChoice("Andrew Garfield", "Andrew Garfield")
        soundCombo:AddChoice("PS1 Spider-Man", "PS1 Spider-Man")
        soundCombo:AddChoice("Insomniac Spider-Man", "Insomniac Spider-Man")
        
        -- Set current value for sound combo without triggering OnSelect
        local currentSet = GetConVar("webswing_sound_set"):GetString()
        for id, data in pairs(soundCombo.Choices) do
            if data == currentSet then
                soundCombo:ChooseOptionID(id)
                break
            end
        end
        
        -- Handle sound selection change
        soundCombo.OnSelect = function(self, index, value)
            net.Start("WebSwing_SetSoundSet")
                net.WriteString(value)
            net.SendToServer()
        end
        
        -- Web rope appearance settings
        panel:Help("Web Rope Appearance")
        
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
        local materialCombo = panel:ComboBox("Rope Material", "webswing_rope_material")
        for displayName, materialPath in pairs(ropeMaterials) do
            materialCombo:AddChoice(displayName, materialPath)
        end

        -- Set initial value based on ConVar
        local currentMaterial = GetConVar("webswing_rope_material"):GetString()
        for displayName, materialPath in pairs(ropeMaterials) do
            if materialPath == currentMaterial then
                materialCombo:SetValue(displayName)
                break
            end
        end

        -- Handle material selection change
        materialCombo.OnSelect = function(self, index, value)
            local selectedMaterial = ropeMaterials[value]
            if selectedMaterial then
                RunConsoleCommand("webswing_rope_material", selectedMaterial)
                net.Start("WebSwing_SetRopeMaterial")
                    net.WriteString(selectedMaterial)
                net.SendToServer()
                
                -- Update any existing ropes
                local weapon = LocalPlayer():GetWeapon("webswing")
                if IsValid(weapon) and weapon.ConstraintController and IsValid(weapon.ConstraintController.rope) then
                    weapon.ConstraintController.rope:SetMaterial(selectedMaterial)
                end
            end
        end
    end)
end)

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

-- Add visual indicator for auto-selected swing point
function SWEP:DrawSwingPointIndicator()
    -- Ensure ConVars exist
    if not GetConVar("webswing_manual_mode") or not GetConVar("webswing_show_ai_indicator") then return end
    
    if not GetConVar("webswing_manual_mode"):GetBool() and GetConVar("webswing_show_ai_indicator"):GetBool() then
        local bestPoint = self:FindPotentialSwingPoints()
        if bestPoint and bestPoint.pos then
            local pos = bestPoint.pos:ToScreen()
            
            -- Draw outer circle
            surface.SetDrawColor(255, 255, 255, 100)
            surface.DrawCircle(pos.x, pos.y, 12)
            
            -- Draw inner circle with score-based color
            local score = math.Clamp(bestPoint.score or 0.5, 0, 1)
            local r = Lerp(score, 255, 50)
            local g = Lerp(score, 50, 255)
            surface.SetDrawColor(r, g, 50, 200)
            surface.DrawCircle(pos.x, pos.y, 8)
            
            -- Draw direction indicator if point is a corner
            if bestPoint.isCorner and bestPoint.normal then
                surface.SetDrawColor(255, 255, 100, 150)
                local normal = bestPoint.normal:ToScreen()
                surface.DrawLine(pos.x, pos.y, 
                    pos.x + (normal.x - pos.x) * 20,
                    pos.y + (normal.y - pos.y) * 20)
            end
        end
    end
end

-- Hook into the HUD drawing
hook.Add("HUDPaint", "WebSwing_DrawIndicator", function()
    local weapon = LocalPlayer():GetActiveWeapon()
    if IsValid(weapon) and weapon:GetClass() == "webswing" then
        weapon:DrawSwingPointIndicator()
    end
end)