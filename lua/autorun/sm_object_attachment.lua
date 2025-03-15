-- Object Attachment System for Spider-Man Mod
-- This system allows players to attach to specific objects like lamp posts and trees when close to the ground

if SERVER then
    -- Make sure clients download this file
    AddCSLuaFile()
    
    -- Register network messages
    util.AddNetworkString("ObjectAttachment_OnAttach")
    util.AddNetworkString("ObjectAttachment_OnDetach")
    util.AddNetworkString("ObjectAttachment_RequestObjects")
    
    print("Loading Spider-Man Object Attachment functionality on server")
end

if CLIENT then
    print("Loading Spider-Man Object Attachment functionality on client")
end

-- Configuration
local ObjectAttachment = {
    Config = {
        EnabledByDefault = true,        -- Whether the feature is enabled by default
        MinAttachHeight = 30,           -- Minimum height from ground to allow attachment
        MaxAttachHeight = 200,          -- Maximum height to check for objects
        AttachDistance = 120,           -- How close to an object player needs to be
        ObjectTypes = {                 -- Types of objects to attach to
            "models/props_foliage/tree",        -- Trees
            "models/props_c17/lamppost",        -- Lamp posts
            "models/props_c17/light_",          -- Light fixtures
            "models/props_wasteland/light_spotlight01_lamp", -- Spotlights
            "models/props_junk/signpole001a",   -- Sign poles
            "models/props_street/streetlight",  -- Street lights
            "models/props_canal/bridge_pillar", -- Bridge pillars
            "models/props/cs_assault/StreetLight", -- CS Street lights
        },
        AttachAnimation = "wall_idle", -- Animation to play when attached
        DetachSpeed = 200,             -- Speed applied when jumping off
        EnableSwinging = true,         -- Allow swinging from attached objects
        ParticleEffect = "webswing_impact", -- Particle effect when attaching
    },
    
    -- State tracking
    State = {
        IsAttached = false,         -- Whether player is currently attached
        AttachedObject = nil,       -- The entity player is attached to
        AttachPosition = nil,       -- Position where player is attached
        OriginalGravity = 1,        -- Original player gravity
        LastGroundCheck = 0,        -- Time of last ground check
        LastDetachTime = 0,         -- Time of last detach
        ObjectModelName = "",       -- Model name of attached object
    }
}

-- Make the object attachment system available globally
_G.ObjectAttachment = ObjectAttachment

-- Create ConVars for configuration
local cv_object_attach_enabled = CreateConVar("sm_object_attach_enabled", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enable/disable the object attachment feature")
local cv_object_attach_distance = CreateConVar("sm_object_attach_distance", "120", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "How close to an object player needs to be")

-- Check if a model is in our list of attachable objects
function ObjectAttachment:IsAttachableObject(modelName)
    if not modelName then return false end
    
    -- Check if the model name contains any of our object types
    for _, objectType in ipairs(self.Config.ObjectTypes) do
        if string.find(string.lower(modelName), string.lower(objectType)) then
            return true
        end
    end
    
    return false
end

-- Find attachable objects around the player
function ObjectAttachment:FindAttachableObjects(player)
    if not IsValid(player) then return {} end
    
    local playerPos = player:GetPos()
    local attachDistance = cv_object_attach_distance:GetFloat()
    local nearbyObjects = {}
    
    -- Find all props nearby
    for _, ent in ipairs(ents.FindInSphere(playerPos, attachDistance)) do
        if IsValid(ent) and ent:GetClass():find("prop_") and self:IsAttachableObject(ent:GetModel()) then
            -- Calculate distance and direction
            local entPos = ent:GetPos()
            local distance = playerPos:Distance(entPos)
            local direction = (entPos - playerPos):GetNormalized()
            
            -- Get entity's bounding box for height calculation
            local mins, maxs = ent:GetModelBounds()
            local height = math.abs(maxs.z - mins.z)
            
            table.insert(nearbyObjects, {
                entity = ent,
                distance = distance,
                direction = direction,
                position = entPos,
                height = height,
                model = ent:GetModel()
            })
        end
    end
    
    -- Sort by distance
    table.sort(nearbyObjects, function(a, b)
        return a.distance < b.distance
    end)
    
    return nearbyObjects
end

-- Check if player is near the ground
function ObjectAttachment:IsNearGround(player, maxHeight)
    if not IsValid(player) then return false end
    
    local playerPos = player:GetPos()
    local trace = util.TraceLine({
        start = playerPos,
        endpos = playerPos - Vector(0, 0, maxHeight),
        filter = player,
        mask = MASK_SOLID
    })
    
    -- Return true if we hit something below us within maxHeight
    return trace.Hit and trace.Fraction < 1.0, trace.HitPos.z
end

-- Attach player to object
function ObjectAttachment:AttachToObject(player, objectInfo)
    if not IsValid(player) or not IsValid(objectInfo.entity) then return false end
    
    -- Store state information
    self.State.IsAttached = true
    self.State.AttachedObject = objectInfo.entity
    self.State.AttachPosition = objectInfo.position
    self.State.ObjectModelName = objectInfo.model
    
    -- Store original gravity and disable it
    self.State.OriginalGravity = player:GetGravity()
    player:SetGravity(0)
    
    -- Stop player's movement
    player:SetLocalVelocity(Vector(0, 0, 0))
    
    -- Set player's position to be on the object
    local attachDirection = (objectInfo.position - player:GetPos()):GetNormalized()
    local attachPosition = objectInfo.position - attachDirection * 30
    attachPosition.z = player:GetPos().z  -- Keep same height
    
    -- Trigger effects
    if SERVER then
        -- Create web impact effect
        local effectData = EffectData()
        effectData:SetOrigin(objectInfo.position)
        effectData:SetNormal(attachDirection * -1)
        effectData:SetScale(1)
        util.Effect(self.Config.ParticleEffect, effectData)
        
        -- Play sound
        player:EmitSound("webshoot/webshoot.wav", 75, 100, 0.7)
        
        -- Notify client
        net.Start("ObjectAttachment_OnAttach")
        net.WriteVector(objectInfo.position)
        net.WriteEntity(objectInfo.entity)
        net.Send(player)
    end
    
    -- Align player to face the object
    local attachAngle = attachDirection:Angle()
    attachAngle.p = 0
    player:SetEyeAngles(attachAngle)
    
    return true
end

-- Detach player from object
function ObjectAttachment:DetachFromObject(player, jumpOff)
    if not IsValid(player) then return end
    
    -- Reset player's gravity
    player:SetGravity(self.State.OriginalGravity or 1)
    
    -- If jumping off, apply speed in direction player is facing
    if jumpOff then
        local jumpDir = player:GetAimVector()
        jumpDir.z = 0.5  -- Add some upward direction
        jumpDir:Normalize()
        
        player:SetVelocity(jumpDir * self.Config.DetachSpeed)
        
        -- Play jump sound
        player:EmitSound("physics/body/body_medium_impact_soft" .. math.random(1, 7) .. ".wav", 75, 100, 0.5)
    end
    
    -- Notify client
    if SERVER then
        net.Start("ObjectAttachment_OnDetach")
        net.Send(player)
    end
    
    -- Reset state
    self.State.IsAttached = false
    self.State.AttachedObject = nil
    self.State.AttachPosition = nil
    self.State.LastDetachTime = CurTime()
    self.State.ObjectModelName = ""
end

-- Main think function that runs every frame
function ObjectAttachment:Think()
    -- Only run check every 0.2 seconds
    if CurTime() - self.State.LastGroundCheck < 0.2 then return end
    self.State.LastGroundCheck = CurTime()
    
    -- Check if feature is enabled
    if not cv_object_attach_enabled:GetBool() then
        -- If disabled and we're attached, detach
        if self.State.IsAttached then
            for _, player in ipairs(player.GetAll()) do
                if self:IsPlayerAttached(player) then
                    self:DetachFromObject(player, false)
                end
            end
        end
        return
    end
    
    -- Check each player
    for _, player in ipairs(player.GetAll()) do
        if IsValid(player) and player:Alive() and not player:InVehicle() then
            -- If already attached, handle attached state
            if self:IsPlayerAttached(player) then
                self:HandleAttachedState(player)
            else
                -- Not attached, check if we should attach
                local timeFromLastDetach = CurTime() - self.State.LastDetachTime
                if timeFromLastDetach > 1.0 then  -- Prevent re-attach too quickly
                    self:CheckForAttachment(player)
                end
            end
        end
    end
end

-- Check if player should attach to an object
function ObjectAttachment:CheckForAttachment(player)
    -- Don't attach if player is on ground
    if player:OnGround() then return end
    
    -- Check if player is near ground
    local nearGround, groundHeight = self:IsNearGround(player, self.Config.MaxAttachHeight)
    if not nearGround then return end
    
    -- Calculate height above ground
    local heightAboveGround = player:GetPos().z - groundHeight
    
    -- Only attach if within height range
    if heightAboveGround < self.Config.MinAttachHeight or heightAboveGround > self.Config.MaxAttachHeight then
        return
    end
    
    -- Find attachable objects
    local objects = self:FindAttachableObjects(player)
    if #objects == 0 then return end
    
    -- Get closest object
    local closestObject = objects[1]
    
    -- Check if player is looking somewhat toward the object
    local lookDir = player:GetAimVector()
    local toObject = (closestObject.position - player:GetPos()):GetNormalized()
    local lookDot = lookDir:Dot(toObject)
    
    -- Attach if player is looking roughly toward object or nearby
    if lookDot > 0.3 or closestObject.distance < 50 then
        self:AttachToObject(player, closestObject)
    end
end

-- Handle player state while attached
function ObjectAttachment:HandleAttachedState(player)
    -- Make sure we still have a valid attached object
    if not IsValid(self.State.AttachedObject) then
        self:DetachFromObject(player, false)
        return
    end
    
    -- Check if player wants to detach (jump)
    if player:KeyPressed(IN_JUMP) then
        self:DetachFromObject(player, true)
        return
    end
    
    -- Keep player in place relative to the object (in case object moves)
    local attachedObject = self.State.AttachedObject
    local objectPos = attachedObject:GetPos()
    
    -- Calculate player's position
    local playerPos = player:GetPos()
    local toObject = (objectPos - playerPos):GetNormalized()
    
    -- If object moves, keep the player attached to it
    if objectPos:Distance(self.State.AttachPosition) > 1 then
        local newPos = objectPos - toObject * 30
        newPos.z = playerPos.z  -- Keep same height
        player:SetPos(newPos)
        
        -- Update stored attach position
        self.State.AttachPosition = objectPos
    end
    
    -- Keep player facing the object
    local attachAngle = toObject:Angle()
    attachAngle.p = 0
    player:SetEyeAngles(attachAngle)
    
    -- Keep player's velocity zeroed
    player:SetLocalVelocity(Vector(0, 0, 0))
    
    -- If player presses primary attack while attached, allow swinging
    if self.Config.EnableSwinging and player:KeyPressed(IN_ATTACK) then
        local webWeapon = player:GetWeapon("webswing")
        
        if IsValid(webWeapon) and player:GetActiveWeapon() == webWeapon then
            -- Detach first
            self:DetachFromObject(player, false)
            
            -- Create a trace to the object for swinging
            local tr = {}
            tr.Hit = true
            tr.HitPos = objectPos
            tr.Entity = attachedObject
            tr.HitNormal = (playerPos - objectPos):GetNormalized()
            tr.StartPos = player:EyePos()
            tr.PhysicsBone = 0
            
            -- Call the web swing's swing function directly
            if webWeapon.StartWebSwing then
                webWeapon:StartWebSwing(tr)
            end
        end
    end
end

-- Check if a player is attached
function ObjectAttachment:IsPlayerAttached(player)
    return self.State.IsAttached and self.State.AttachedObject
end

-- Handle network request for objects (for client visualization)
if SERVER then
    net.Receive("ObjectAttachment_RequestObjects", function(len, player)
        local objects = ObjectAttachment:FindAttachableObjects(player)
        local compressed = {}
        
        -- Send only the necessary data
        for _, obj in ipairs(objects) do
            table.insert(compressed, {
                entity = obj.entity,
                position = obj.position
            })
        end
        
        -- Send list to client
        net.Start("ObjectAttachment_RequestObjects")
        net.WriteTable(compressed)
        net.Send(player)
    end)
end

-- Hook into the game's Think function
hook.Add("Think", "ObjectAttachment_Think", function()
    ObjectAttachment:Think()
end)

-- Initialize
print("[Spider-Man] Object Attachment system initialized") 