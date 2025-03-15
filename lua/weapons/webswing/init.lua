AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("camera_system.lua")
AddCSLuaFile("convars.lua")
AddCSLuaFile("model_cache.lua")
AddCSLuaFile("map_analysis.lua")
AddCSLuaFile("saved_weapons.lua")
AddCSLuaFile("rope_dynamics.lua")
AddCSLuaFile("physics_system.lua")
AddCSLuaFile("rhythm_system.lua")
AddCSLuaFile("rhythm_hud.lua")
AddCSLuaFile("swing_targeting.lua")
AddCSLuaFile("adaptive_tension.lua")
AddCSLuaFile("pendulum_physics.lua")
AddCSLuaFile("web_release_dynamics.lua")
AddCSLuaFile("flow_state_system.lua")
AddCSLuaFile("flow_state_hud.lua")

include("shared.lua")

-- Add networking for sound sets
util.AddNetworkString("WebSwing_SetSoundSet")

SWEP = SWEP or {}

if SERVER then
    -- Create a ConVar for maximum web length
    CreateConVar("webswing_max_length", "1000", FCVAR_ARCHIVE, "Maximum length of web swing")

    util.AddNetworkString("WebSwing_SetSoundSet")
end

function SWEP:Initialize()
    self.BaseClass.Initialize(self)

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
end

function SWEP:Holster()
    -- Clean up any server-side resources if needed
    return true
end

-- Add Deploy function for server-side handling
function SWEP:Deploy()
    -- Server-side deploy logic if needed
    return true
end

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    
    local trace = owner:GetEyeTrace()
    if not trace.Hit or trace.HitSky then return end
    
    local maxWebLength = GetConVar("webswing_max_length"):GetFloat()
    local targetPos = trace.HitPos
    local distance = (targetPos - owner:GetPos()):Length()
    
    if distance > maxWebLength then
        targetPos = owner:GetPos() + (targetPos - owner:GetPos()):GetNormalized() * maxWebLength
    end
    
    -- Additional swing logic here...
end