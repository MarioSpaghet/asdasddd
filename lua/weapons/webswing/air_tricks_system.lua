-- lua/weapons/webswing/air_tricks_system.lua
local AirTricksSystem = {}
AirTricksSystem.Config = {
    TrickKey = IN_WALK, -- Using IN_WALK (commonly Left Alt) as the trick button
    TrickDuration = 0.6, -- Slightly shorter duration
    TrickCooldown = 0.3,
    MaxTricksPerAir = 2,
    SpinForce = 1200, -- Increased for more noticeable spin
    FlipForce = 900   -- Increased for more noticeable flip
}
AirTricksSystem.State = {
    IsTricking = false,
    TrickEndTime = 0,
    NextTrickTime = 0,
    TricksThisAir = 0,
    OriginalVelocity = nil,
    OriginalAngularVelocity = nil
}

function AirTricksSystem:Initialize(weaponSWEP)
    self.SWEP = weaponSWEP
    self.State.IsTricking = false
    self.State.TrickEndTime = 0
    self.State.NextTrickTime = 0
    self.State.TricksThisAir = 0
    self.State.OriginalVelocity = vector_origin
    self.State.OriginalAngularVelocity = vector_origin
end

function AirTricksSystem:IsActive()
    return self.State.IsTricking
end

function AirTricksSystem:CanPerformTrick()
    local ply = self.SWEP.Owner
    if not IsValid(ply) then return false end

    -- Check if player is in the air, not doing other actions, and cooldowns/limits permit
    return not ply:IsOnGround() and
           not self.SWEP.RagdollActive and
           not self.SWEP.IsPointLaunching and -- Ensure not point launching
           not self:IsActive() and -- Ensure not already tricking
           CurTime() >= self.State.NextTrickTime and
           self.State.TricksThisAir < self.Config.MaxTricksPerAir
end

function AirTricksSystem:StartTrick(trickType)
    if not self:CanPerformTrick() then return end -- Double check

    local ply = self.SWEP.Owner
    if not IsValid(ply) then return end
    
    local physObj = ply:GetPhysicsObject()
    if not IsValid(physObj) then return end

    self.State.IsTricking = true
    self.State.TrickEndTime = CurTime() + self.Config.TrickDuration
    self.State.TricksThisAir = self.State.TricksThisAir + 1
    
    -- Store original velocities to potentially blend back or for more controlled exit
    self.State.OriginalVelocity = ply:GetVelocity()
    self.State.OriginalAngularVelocity = physObj:GetAngleVelocity()

    -- Make player non-collidable for a brief moment to avoid snagging
    ply:SetCollisionGroup(COLLISION_GROUP_DEBRIS) -- Or another non-colliding group

    local angVel = Vector(0,0,0)
    local soundToPlay = ""

    if trickType == "spin_left" then
        angVel = Vector(0, 0, self.Config.SpinForce)
        soundToPlay = "ambient/atmosphere/wind_debris_loop.wav" -- Placeholder
    elseif trickType == "spin_right" then
        angVel = Vector(0, 0, -self.Config.SpinForce)
        soundToPlay = "ambient/atmosphere/wind_debris_loop.wav" -- Placeholder
    elseif trickType == "forward_flip" then
        angVel = Vector(self.Config.FlipForce, 0, 0) -- Pitch forward
        soundToPlay = "ambient/atmosphere/wind_debris_loop.wav" -- Placeholder
    elseif trickType == "backward_flip" then
        angVel = Vector(-self.Config.FlipForce, 0, 0) -- Pitch backward
        soundToPlay = "ambient/atmosphere/wind_debris_loop.wav" -- Placeholder
    end
    
    physObj:AddAngleVelocity(angVel)
    if soundToPlay ~= "" then ply:EmitSound(soundToPlay, 70, 120) end

    -- Give a slight upward nudge to counteract gravity a bit during the trick
    -- ply:SetVelocity(self.State.OriginalVelocity + Vector(0,0,50))
end

function AirTricksSystem:StopTrick()
    local ply = self.SWEP.Owner
    if not IsValid(ply) then return end
    local physObj = ply:GetPhysicsObject()
    if not IsValid(physObj) then return end

    self.State.IsTricking = false
    self.State.NextTrickTime = CurTime() + self.Config.TrickCooldown
    
    -- Dampen angular velocity significantly but not necessarily to zero immediately
    physObj:SetAngleVelocity(self.State.OriginalAngularVelocity * 0.1 + physObj:GetAngleVelocity() * 0.3) 
    ply:SetCollisionGroup(COLLISION_GROUP_PLAYER) -- Restore collision
end

function AirTricksSystem:Think()
    local ply = self.SWEP.Owner
    if not IsValid(ply) then return end

    if ply:IsOnGround() then
        if self.State.TricksThisAir > 0 then
            self.State.TricksThisAir = 0 -- Reset on landing
        end
        if self:IsActive() then -- If somehow still active and landed, stop it.
            self:StopTrick()
        end
    end

    if self:IsActive() then
        if CurTime() >= self.State.TrickEndTime then
            self:StopTrick()
        else
            -- During trick, could apply slight air control or gravity modification if desired
            -- For now, just let the initial impulse and angular velocity play out.
            -- Ensure player remains non-collidable until trick ends.
             if ply:GetCollisionGroup() ~= COLLISION_GROUP_DEBRIS then
                ply:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
             end
        end
        return -- Don't check for new trick input while already tricking
    end

    -- Check for trick input
    if ply:KeyDown(self.Config.TrickKey) and self:CanPerformTrick() then
        local trickToPerform = nil
        -- Prioritize distinct inputs: Forward/Backward for flips, Left/Right for spins.
        if ply:KeyDown(IN_FORWARD) and not ply:KeyDown(IN_BACK) then
            trickToPerform = "forward_flip"
        elseif ply:KeyDown(IN_BACK) and not ply:KeyDown(IN_FORWARD) then
            trickToPerform = "backward_flip"
        elseif ply:KeyDown(IN_MOVELEFT) and not ply:KeyDown(IN_MOVERIGHT) then
            trickToPerform = "spin_left"
        elseif ply:KeyDown(IN_MOVERIGHT) and not ply:KeyDown(IN_MOVELEFT) then
            trickToPerform = "spin_right"
        end
        
        if trickToPerform then
            self:StartTrick(trickToPerform)
        end
    end
end
return AirTricksSystem
