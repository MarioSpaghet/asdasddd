-- Web Swing Perfect Release Effect
-- Visual indicator for perfect web release timing

EFFECT.Mat = Material("effects/webswing_trail")

function EFFECT:Init(data)
    self.Position = data:GetOrigin()
    self.Entity = data:GetEntity() -- Player or weapon
    self.Scale = data:GetScale() or 1
    
    -- Duration of the effect
    self.DieTime = CurTime() + 0.7
    
    -- Effect parameters
    self.Radius = 30 * self.Scale
    self.Color = Color(255, 50, 50) -- Red for perfect release
    
    -- Play sound
    if IsValid(self.Entity) then
        sound.Play("weapons/physcannon/energy_sing_flyby2.wav", self.Position, 75, 150, 0.5)
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
    local progress = timeLeft / 0.7
    local alpha = 255 * progress
    local size = self.Radius * (2.5 - progress * 1.5) -- Grow as it fades
    
    -- Draw a dramatic flash effect
    render.SetMaterial(self.Mat)
    
    -- Draw central flash
    render.DrawQuadEasy(
        self.Position,
        Vector(0, 0, 1), -- Upward facing
        size * 0.5, 
        size * 0.5,
        Color(255, 255, 255, alpha),
        0
    )
    
    -- Draw colored expanding rings
    local ringCount = 4
    for i = 1, ringCount do
        local ringProgress = i / ringCount
        local ringSize = size * (1 + ringProgress)
        local ringAlpha = alpha * (1 - ringProgress * 0.6)
        
        render.DrawQuadEasy(
            self.Position,
            Vector(0, 0, 1), -- Upward facing
            ringSize, 
            ringSize,
            Color(self.Color.r, self.Color.g, self.Color.b, ringAlpha),
            CurTime() * 45 * i
        )
    end
    
    -- Draw starbursts
    local burstCount = 8
    for i = 1, burstCount do
        local angle = (i / burstCount) * math.pi * 2
        local dir = Vector(math.cos(angle), math.sin(angle), 0)
        local pos = self.Position + dir * size * 0.8 * progress
        
        render.DrawBeam(
            self.Position,
            pos,
            5 * (1 - progress),
            0,
            1,
            Color(self.Color.r, self.Color.g, self.Color.b, alpha * 0.7)
        )
    end
end 