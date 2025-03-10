EFFECT.Mat = Material("effects/select_ring")

function EFFECT:Init(data)
    self.Position = data:GetOrigin()
    self.Normal = data:GetNormal()
    self.Scale = data:GetScale() or 1
    
    local emitter = ParticleEmitter(self.Position)
    
    for i = 1, 15 do
        local particle = emitter:Add("effects/select_ring", self.Position)
        
        if particle then
            particle:SetVelocity(VectorRand() * 100 * self.Scale)
            particle:SetLifeTime(0)
            particle:SetDieTime(math.Rand(0.3, 0.6))
            particle:SetStartAlpha(255)
            particle:SetEndAlpha(0)
            particle:SetStartSize(8 * self.Scale)
            particle:SetEndSize(0)
            particle:SetRoll(math.Rand(0, 360))
            particle:SetRollDelta(math.Rand(-5, 5))
            particle:SetColor(255, 255, 255)
            particle:SetGravity(Vector(0, 0, -50))
            particle:SetCollide(true)
            particle:SetBounce(0.4)
        end
    end
    
    emitter:Finish()
end

function EFFECT:Think()
    return false
end

function EFFECT:Render()
end