function EFFECT:Init(data)
    local pos = data:GetOrigin()
    local norm = data:GetNormal()
    
    local emitter = ParticleEmitter(pos)
    
    for i = 1, 5 do
        local particle = emitter:Add("effects/spark", pos)
        
        if particle then
            particle:SetVelocity(norm * 50 + VectorRand() * 20)
            particle:SetDieTime(0.5)
            particle:SetStartAlpha(255)
            particle:SetEndAlpha(0)
            particle:SetStartSize(2)
            particle:SetEndSize(0)
            particle:SetRoll(math.Rand(0, 360))
            particle:SetRollDelta(math.Rand(-2, 2))
            particle:SetColor(255, 255, 255)
            particle:SetCollide(true)
            particle:SetBounce(0.3)
        end
    end
    
    emitter:Finish()
end

function EFFECT:Think()
    return false
end

function EFFECT:Render()
end

effects.Register(EFFECT, "webshooter_impact")
