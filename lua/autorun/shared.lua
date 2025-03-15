-- Web Shooters Shared Initialization
-- This file loads all necessary components for the web shooters addon

if SERVER then
    -- Add client-side Lua files
    AddCSLuaFile()
    
    -- Load effects
    AddCSLuaFile("effects/web_beam/init.lua")
    AddCSLuaFile("effects/web_impact/init.lua")
    AddCSLuaFile("effects/web_impact_small/init.lua")
    AddCSLuaFile("effects/web_line/init.lua")
    AddCSLuaFile("effects/webswing_boost_ready/init.lua")
    AddCSLuaFile("effects/webswing_optimal_release/init.lua")
    AddCSLuaFile("effects/webswing_perfect_release/init.lua")
    
    -- Precache effects and sounds
    resource.AddFile("materials/effects/webswing_trail.vmt")
    resource.AddFile("materials/effects/webswing_impact.vmt")
    resource.AddFile("sound/webshoot/webshoot.wav")
end

-- Register the weapon
weapons.Register({
    Base = "weapon_base",
    ClassName = "webswing",
    Spawnable = true,
    AdminOnly = false,
    Category = "Spider-Man"
}, "webswing")

print("[Web Shooters] Shared initialization complete")
