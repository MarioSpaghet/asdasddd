AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

-- Add networking for sound sets
util.AddNetworkString("WebSwing_SetSoundSet")

SWEP = SWEP or {}

function SWEP:Initialize()
    self.BaseClass.Initialize(self)

    if SERVER then
        -- Setup network message handler
        if not self.NetworkSetup then
            self.NetworkSetup = true
            net.Receive("WebSwing_SetSoundSet", function(len, ply)
                if not IsValid(ply) then return end
                local soundSet = net.ReadString()
                -- Validate the sound set exists
                if self.SoundSets[soundSet] then
                    ply:ConCommand("webswing_sound_set " .. soundSet)
                end
            end)
        end
    end
end

local MAX_WEB_LENGTH = 1000 -- Define maximum web length

function SWEP:Holster()
    // Existing holster logic
    -- Prevent holster from interfering with noclip
    -- Remove or comment out any lines that disable noclip
    // return true
    return true
end

function SWEP:PrimaryAttack()
    if not IsValid(self.Owner) then return end
    
    local trace = self.Owner:GetEyeTrace()
    -- Check if we hit something solid and it's not the skybox
    if not trace.Hit or trace.HitSky then return end
    
    local targetPos = trace.HitPos
    local distance = (targetPos - self.Owner:GetPos()):Length()
    if distance > MAX_WEB_LENGTH then
        targetPos = self.Owner:GetPos() + (targetPos - self.Owner:GetPos()):GetNormalized() * MAX_WEB_LENGTH
    end
    
    // ... existing code ...
end