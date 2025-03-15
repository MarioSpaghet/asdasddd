-- Web Beam Effect for Spider-Man Web Shooters
-- Creates a beam effect for web lines

EFFECT.Mat = Material("effects/webswing_trail")

function EFFECT:Init(data)
    self.StartPos = data:GetStart()
    self.EndPos = data:GetOrigin()
    self.Entity:SetRenderBoundsWS(self.StartPos, self.EndPos)
    
    -- Duration of the effect
    self.DieTime = CurTime() + 0.5
    
    -- Get weapon reference if available
    self.Weapon = data:GetEntity()
    
    -- Starting width of beam
    self.StartWidth = 2
    
    -- Color of the beam (white by default)
    self.Color = Color(255, 255, 255)
end

function EFFECT:Think()
    -- Remove the effect after duration has expired
    return (CurTime() < self.DieTime)
end

function EFFECT:Render()
    -- Calculate alpha based on remaining time
    local alpha = 255 * (self.DieTime - CurTime()) / 0.5
    
    -- Render the beam
    render.SetMaterial(self.Mat)
    render.DrawBeam(
        self.StartPos,
        self.EndPos,
        self.StartWidth,
        0,
        0,
        Color(self.Color.r, self.Color.g, self.Color.b, alpha)
    )
end 