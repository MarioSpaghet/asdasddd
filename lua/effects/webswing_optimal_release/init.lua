-- Web Swing Optimal Release Effect
-- Visual indicator for optimal web release timing

EFFECT.Mat = Material("effects/webswing_trail")

function EFFECT:Init(data)
    self.Position = data:GetOrigin()
    self.Entity = data:GetEntity() -- Player or weapon
    self.Scale = data:GetScale() or 1
    
    -- Duration of the effect
    self.DieTime = CurTime() + 0.5
    
    -- Effect parameters
    self.Radius = 15 * self.Scale
    self.Color = Color(255, 215, 0) -- Gold for optimal release
    
    -- Play sound
    if IsValid(self.Entity) then
        sound.Play("buttons/lightswitch2.wav", self.Position, 75, 150, 0.4)
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
    local progress = timeLeft / 0.5
    local alpha = 255 * progress
    local size = self.Radius * (2 - progress) -- Grow as it fades
    
    -- Draw a pulsing indicator
    render.SetMaterial(self.Mat)
    
    -- Draw central flash
    render.DrawQuadEasy(
        self.Position,
        Vector(0, 0, 1), -- Upward facing
        size * 0.8, 
        size * 0.8,
        Color(self.Color.r, self.Color.g, self.Color.b, alpha),
        0
    )
    
    -- Draw expanding ring
    render.DrawQuadEasy(
        self.Position,
        Vector(0, 0, 1), -- Upward facing
        size * 1.5, 
        size * 1.5,
        Color(self.Color.r, self.Color.g, self.Color.b, alpha * 0.5),
        45
    )
end 