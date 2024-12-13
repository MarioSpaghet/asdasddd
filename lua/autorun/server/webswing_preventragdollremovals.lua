hook.Add("CanTool", "webswing_ProtectRagdolls", function(ply, tr, tool)
	--Sanity
	if not IsValid(tr.Entity) then return end
	--Just to save on typing
	local Ent = tr.Entity
	--Don't allow removal
	if tool=="remover" and Ent.DontAllowRemoval then
		return false
	end
	--Also don't allow elastic on ragdolls that have no gravity (it causes crashes)
	if tool=="elastic" and Ent:GetClass()=="prop_ragdoll" then
		--Get its physobj and check gravity
		local Phys = Ent:GetPhysicsObject()
		if IsValid(Phys) then
			if not Phys:IsGravityEnabled() then
				return false --Can't use elastic on this ragdoll because it has no gravity
			end
		end
	end
	--And the inverse, don't allow no gravity if the ragdoll has an elastic attached to it
	if tool=="physprop" and Ent:GetClass()=="prop_ragdoll" then
		--Check the gravity option of physprop tool
		local GravOk = tobool(ply:GetActiveWeapon():GetToolObject():GetClientInfo("gravity_toggle"))
		if not GravOk then
			--See if it has any elastic constraints
			local Constraints = constraint.FindConstraints(Ent,"Elastic")
			if #Constraints>0 then
				return false --Can't use nograv physprop on this ragdoll because it has an elastic
			end
		end
	end
end)

hook.Add("CanProperty", "webswing_ProtectRagdolls", function(ply,mode,Ent,d,e)
	--Sanity
	if not IsValid(Ent) then return end
	--Don't allow removal
	if mode=="remover" and Ent.DontAllowRemoval then
		return false
	end
	--Don't allow gravity toggle when we have an elastic attached
	if mode=="gravity" and Ent:GetClass()=="prop_ragdoll" then
		--See if it has any elastic constraints
		local Constraints = constraint.FindConstraints(Ent,"Elastic")
		if #Constraints>0 then
			return false --Can't use nogravity on this ragdoll because it has an elastic
		end
	end
end)