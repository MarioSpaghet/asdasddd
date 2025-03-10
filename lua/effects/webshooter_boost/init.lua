function EFFECT:Init(data)
    local pos = data:GetOrigin()
    local scale = data:GetScale() or 1
    local magnitude = data:GetMagnitude() or 1
    
    local emitter = ParticleEmitter(pos)
    
    -- Determine colors based on chain level
    local colors = {
        [1] = Color(200, 200, 255),  -- Light blue for first chain
        [2] = Color(150, 200, 255),  -- Blue for second chain
        [3] = Color(100, 150, 255),  -- Medium blue for third chain
        [4] = Color(50, 100, 255),   -- Dark blue for fourth chain
        [5] = Color(0, 50, 255)      -- Deep blue for max chain
    }
    
    local color = colors[math.min(scale, 5)] or colors[1]
    local particleCount = 15 * magnitude
    
    -- Create spiral particles
    for i = 1, particleCount do
        -- Spiral pattern
        local angle = (i / particleCount) * math.pi * 4
        local radius = i * 2
        local x = math.cos(angle) * radius
        local y = math.sin(angle) * radius
        
        local particle = emitter:Add("effects/select_ring", pos + Vector(x, y, i * 3))
        
        if particle then
            particle:SetVelocity(Vector(x, y, 20) * scale)
            particle:SetDieTime(0.5 + 0.1 * scale)
            particle:SetStartAlpha(200)
            particle:SetEndAlpha(0)
            particle:SetStartSize(5 * scale)
            particle:SetEndSize(2 * scale)
            particle:SetRoll(math.Rand(0, 360))
            particle:SetRollDelta(math.Rand(-2, 2))
            particle:SetColor(color.r, color.g, color.b)
            particle:SetCollide(false)
            particle:SetGravity(Vector(0, 0, -50))
        end
    end
    
    -- Create burst particles
    for i = 1, 10 * scale do
        local offset = VectorRand() * 20 * scale
        offset.z = math.abs(offset.z) + 10  -- Move upwards
        
        local particle = emitter:Add("effects/blueflare1", pos + offset)
        
        if particle then
            particle:SetVelocity(VectorRand() * 50 * scale + Vector(0, 0, 50))
            particle:SetDieTime(0.5 + 0.3 * scale)
            particle:SetStartAlpha(200)
            particle:SetEndAlpha(0)
            particle:SetStartSize(10 * scale)
            particle:SetEndSize(5 * scale)
            particle:SetRoll(math.Rand(0, 360))
            particle:SetRollDelta(math.Rand(-1, 1))
            particle:SetColor(color.r, color.g, color.b)
            particle:SetCollide(false)
            particle:SetGravity(Vector(0, 0, -50))
        end
    end
    
    emitter:Finish()
    
    -- Add a light flash
    local dlight = DynamicLight(LocalPlayer():EntIndex())
    if dlight then
        dlight.pos = pos
        dlight.r = color.r
        dlight.g = color.g
        dlight.b = color.b
        dlight.brightness = 2 * scale
        dlight.Decay = 1000
        dlight.Size = 250 * scale
        dlight.DieTime = CurTime() + 0.5
    end
end

function EFFECT:Think()
    return false
end

function EFFECT:Render()
end 