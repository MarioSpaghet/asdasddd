-- Effects for Zip Web

function EFFECT:Init(data)
    self.StartPos = data:GetOrigin()
    self.EndPos = data:GetStart() -- GetStart() is used for the beam's end position
    self.Duration = data:GetScale()
    self.LifeTime = self.Duration
    self.DieTime = CurTime() + self.Duration

    self.BeamColor = Color(150, 200, 255, 200) -- Blue-ish for zip
    self.BeamWidth = 5
end

function EFFECT:Think()
    if CurTime() > self.DieTime then
        return false -- Effect is finished
    end
    return true
end

function EFFECT:Render()
    if not self.StartPos or not self.EndPos then return end

    -- Calculate remaining lifetime fraction
    local timeLeft = self.DieTime - CurTime()
    local fraction = math.max(0, timeLeft / self.Duration)

    -- Fade out alpha and width
    local currentAlpha = self.BeamColor.a * fraction
    local currentWidth = self.BeamWidth * fraction

    if currentAlpha <= 0 or currentWidth <= 0 then return end

    local renderColor = Color(self.BeamColor.r, self.BeamColor.g, self.BeamColor.b, currentAlpha)
    
    render.SetMaterial(Material("cable/white")) -- Using a common material that tints well
    render.DrawBeam(self.StartPos, self.EndPos, currentWidth, 0, 1, renderColor)
end
