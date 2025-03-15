-- Web Swing Boost Ready Effect
-- Visual indicator that a boost is ready to be activated

EFFECT.Mat = Material("effects/webswing_trail")

function EFFECT:Init(data)
    self.Position = data:GetOrigin()
    self.Entity = data:GetEntity() -- Player or weapon
    self.Scale = data:GetScale() or 1
    
    -- Duration of the effect
    self.DieTime = CurTime() + 1.0
    
    -- Effect parameters
    self.Radius = 20 * self.Scale
    self.Color = Color(50, 200, 50) -- Green for boost ready
    
    -- Play sound
    if IsValid(self.Entity) then
        sound.Play("buttons/button24.wav", self.Position, 75, 150, 0.5)
    end
end

function EFFECT:Think()
    -- Follow the entity if it exists
    if IsValid(self.Entity) then
        if self.Entity:IsPlayer() then
            self.Position = self.Entity:GetPos() + Vector(0, 0, 40)
        else
            self.Position = self.Entity:GetPos()
        end
    end
    
    -- Remove effect after time expires
    return (CurTime() < self.DieTime)
end

function EFFECT:Render()
    -- Calculate alpha and size based on time
    local timeLeft = self.DieTime - CurTime()
    local progress = timeLeft / 1.0
    local alpha = 255 * progress
    local size = self.Radius * (1 + math.sin(CurTime() * 10) * 0.1)
    
    -- Draw a pulsing ring
    render.SetMaterial(self.Mat)
    
    local ringCount = 3
    for i = 1, ringCount do
        local ringProgress = i / ringCount
        local ringSize = size * (1 + ringProgress * 0.5)
        local ringAlpha = alpha * (1 - ringProgress * 0.7)
        
        render.DrawQuadEasy(
            self.Position,
            Vector(0, 0, 1), -- Upward facing
            ringSize, 
            ringSize,
            Color(self.Color.r, self.Color.g, self.Color.b, ringAlpha),
            CurTime() * 30
        )
    end
end 