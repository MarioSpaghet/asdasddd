-- Small Web Impact Effect for Spider-Man Web Shooters
-- Creates a smaller impact effect for less important hits

EFFECT.Mat = Material("effects/webswing_impact")

function EFFECT:Init(data)
    self.Position = data:GetOrigin()
    self.Normal = data:GetNormal()
    
    -- Set up particles (fewer and smaller than web_impact)
    local emitter = ParticleEmitter(self.Position)
    if emitter then
        for i = 1, 4 do
            local particle = emitter:Add(self.Mat, self.Position)
            if particle then
                local vel = self.Normal + VectorRand() * 0.3
                particle:SetVelocity(vel * math.Rand(10, 30))
                particle:SetLifeTime(0)
                particle:SetDieTime(math.Rand(0.3, 0.7))
                particle:SetStartAlpha(200)
                particle:SetEndAlpha(0)
                particle:SetStartSize(1)
                particle:SetEndSize(0.5)
                particle:SetRoll(math.Rand(0, 360))
                particle:SetRollDelta(math.Rand(-1, 1))
                particle:SetColor(255, 255, 255)
                particle:SetGravity(Vector(0, 0, -50))
                particle:SetCollide(true)
                particle:SetBounce(0.1)
            end
        end
        emitter:Finish()
    end
    
    -- No decal for small impacts
    
    -- Play a quieter sound
    sound.Play("physics/flesh/flesh_impact_bullet" .. math.random(1, 5) .. ".wav", self.Position, 50, math.Rand(100, 120), 0.5)
end

function EFFECT:Think()
    return false
end

function EFFECT:Render()
    -- This effect doesn't need continuous rendering
end 