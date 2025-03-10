-- Saved Weapons System for Web Shooters

local SavedWeapons = {
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

return SavedWeapons