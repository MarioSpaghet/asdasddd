-- Web Impact Effect for Spider-Man Web Shooters
-- Creates an impact effect when web hits a surface

EFFECT.Mat = Material("effects/webswing_impact")

function EFFECT:Init(data)
    self.Position = data:GetOrigin()
    self.Normal = data:GetNormal()
    self.Scale = data:GetScale() or 1
    
    -- Set up particles
    local emitter = ParticleEmitter(self.Position)
    if emitter then
        for i = 1, 8 do
            local particle = emitter:Add(self.Mat, self.Position)
            if particle then
                local vel = self.Normal + VectorRand() * 0.5
                particle:SetVelocity(vel * math.Rand(20, 50))
                particle:SetLifeTime(0)
                particle:SetDieTime(math.Rand(0.5, 1.0))
                particle:SetStartAlpha(255)
                particle:SetEndAlpha(0)
                particle:SetStartSize(2 * self.Scale)
                particle:SetEndSize(1 * self.Scale)
                particle:SetRoll(math.Rand(0, 360))
                particle:SetRollDelta(math.Rand(-2, 2))
                particle:SetColor(255, 255, 255)
                particle:SetGravity(Vector(0, 0, -100))
                particle:SetCollide(true)
                particle:SetBounce(0.2)
            end
        end
        emitter:Finish()
    end
    
    -- Create a decal
    util.Decal("SmallScorch", self.Position + self.Normal, self.Position - self.Normal)
    
    -- Play sound
    sound.Play("physics/flesh/flesh_impact_bullet" .. math.random(1, 5) .. ".wav", self.Position, 75, math.Rand(90, 110), 1)
end

function EFFECT:Think()
    return false
end

function EFFECT:Render()
    -- This effect doesn't need continuous rendering
end 