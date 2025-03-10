EFFECT.Mat = Material("effects/select_ring")

function EFFECT:Init(data)
    self.Position = data:GetOrigin()
    self.Normal = data:GetNormal()
    self.Scale = data:GetScale() or 1
    
    local emitter = ParticleEmitter(self.Position)
    
    for i = 1, 10 do
        local particle = emitter:Add("effects/select_ring", self.Position)
        
        if particle then
            particle:SetVelocity(VectorRand() * 50 * self.Scale)
            particle:SetLifeTime(0)
            particle:SetDieTime(math.Rand(0.5, 1.0))
            particle:SetStartAlpha(255)
            particle:SetEndAlpha(0)
            particle:SetStartSize(5 * self.Scale)
            particle:SetEndSize(2 * self.Scale)
            particle:SetRoll(math.Rand(0, 360))
            particle:SetRollDelta(math.Rand(-2, 2))
            particle:SetColor(150, 150, 150)
            particle:SetGravity(Vector(0, 0, -100))
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