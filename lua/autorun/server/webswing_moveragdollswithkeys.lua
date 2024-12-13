hook.Add("Think","webswing_MoveRagdollsWithKeys",function()
	local curTime = CurTime()
	
	for _, v in ipairs(player.GetAll()) do
		if not v.WT_webswing_Roping then continue end
		
		local roper = v:GetWeapon("webswing")
		if not IsValid(roper) then continue end
		
		local rag = roper.Ragdoll
		if not IsValid(rag) then continue end
		
		-- Кэшируем состояния клавиш
		local moveKeys = {
			forward = v:KeyDown(IN_FORWARD),
			back = v:KeyDown(IN_BACK),
			right = v:KeyDown(IN_MOVERIGHT),
			left = v:KeyDown(IN_MOVELEFT)
		}
		
		if moveKeys.forward or moveKeys.back or moveKeys.left or moveKeys.right then
			roper:Shorten()
			
			local angle = v:EyeAngles():Forward()
			angle.z = 0
			local angle2 = v:EyeAngles():Right()
			angle2.z = 0
			
			-- Оптимизированная обработка направления
			if not (moveKeys.forward or moveKeys.back) then
				angle = Vector(0,0,0)
			elseif moveKeys.back then
				angle = angle * -1
			end
			
			if moveKeys.left then
				angle2 = angle2 * -1
			end
			
			if moveKeys.right or moveKeys.left then
				angle = angle + angle2
				angle:Normalize() -- Используем более быстрый метод нормализации
			end
			
			local phys = rag:GetPhysicsObject()
			if IsValid(phys) then
				-- Применяем силу более эффективно
				phys:ApplyForceCenter(angle * roper:GetSwingForce())
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