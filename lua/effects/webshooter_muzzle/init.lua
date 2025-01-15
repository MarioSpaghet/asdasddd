function EFFECT:Init(data)
    local pos = data:GetOrigin()
    local norm = data:GetNormal()
    
    local emitter = ParticleEmitter(pos)
    
    for i = 1, 8 do
        local particle = emitter:Add("effects/select_ring", pos)
        
        if particle then
            particle:SetVelocity(norm * 30 + VectorRand() * 10)
            particle:SetDieTime(0.2)
            particle:SetStartAlpha(255)
            particle:SetEndAlpha(0)
            particle:SetStartSize(1)
            particle:SetEndSize(3)
            particle:SetRoll(math.Rand(0, 360))
            particle:SetRollDelta(math.Rand(-2, 2))
            particle:SetColor(255, 255, 255)
        end
    end
    
    emitter:Finish()
end

function EFFECT:Think()
    return false
end

function EFFECT:Render()
end

effects.Register(EFFECT, "webshooter_muzzle")
