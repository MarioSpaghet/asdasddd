hook.Add("Think","webswing_MoveRagdollsWithKeys",function()
	for _,ply in ipairs(player.GetAll()) do
		if not ply.WT_webswing_Roping then continue end
		
		local roper = ply:GetWeapon("webswing")
		if not IsValid(roper) then continue end
		
		local rag = roper.Ragdoll
		if not IsValid(rag) then continue end

		-- Track movement inputs
		local moveForward = ply:KeyDown(IN_FORWARD)
		local moveBack    = ply:KeyDown(IN_BACK)
		local moveLeft    = ply:KeyDown(IN_MOVELEFT)
		local moveRight   = ply:KeyDown(IN_MOVERIGHT)

		if moveForward or moveBack or moveLeft or moveRight then
			-- Shorten the rope before applying any forces
			roper:Shorten()

			-- Forward/back movement
			local forwardVec = ply:EyeAngles():Forward()

			-- Left/right movement
			local rightVec = ply:EyeAngles():Right()
			rightVec.z = 0
			rightVec:Normalize()

			local moveVec = Vector(0,0,0)

			if moveForward then
				moveVec = moveVec + forwardVec
			elseif moveBack then
				moveVec = moveVec - forwardVec
			end

			if moveRight then
				moveVec = moveVec + rightVec
			elseif moveLeft then
				moveVec = moveVec - rightVec
			end

			moveVec:Normalize()

			local phys = rag:GetPhysicsObject()
			if IsValid(phys) then
				phys:ApplyForceCenter(moveVec * roper:GetSwingForce())
			end
		end
	end
end)

hook.Add("PlayerSpawn", "webswing_SetSomeVariablesOnSpawn", function(ply)
	ply.WT_webswing_Roping = false
end)

hook.Add("PlayerFootstep", "webswing_MuteFootsteps", function(ply)
	if ply.WT_webswing_Roping then
		return false
	end
end)