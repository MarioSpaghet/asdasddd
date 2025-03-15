-- Web Line Effect for Spider-Man Web Shooters
-- Creates a persistent web line that stays for a longer time

EFFECT.Mat = Material("effects/webswing_trail")

function EFFECT:Init(data)
    self.StartPos = data:GetStart()
    self.EndPos = data:GetOrigin()
    self.Entity:SetRenderBoundsWS(self.StartPos, self.EndPos)
    
    -- Duration of the effect (longer than web_beam)
    self.DieTime = CurTime() + 10.0
    
    -- Width parameters
    self.StartWidth = 2
    self.EndWidth = 1
    
    -- Alpha values
    self.StartAlpha = 255
    self.EndAlpha = 0
    
    -- Color of the web line
    self.Color = Color(255, 255, 255)
    
    -- Start fading time
    self.FadeStartTime = self.DieTime - 3.0
end

function EFFECT:Think()
    -- Gradually reduce the start width over time
    if CurTime() > self.FadeStartTime then
        local fadeProgress = (CurTime() - self.FadeStartTime) / 3.0
        self.StartWidth = math.Lerp(2, 0.5, fadeProgress)
    end
    
    -- Remove the effect after duration has expired
    return (CurTime() < self.DieTime)
end

function EFFECT:Render()
    -- Calculate alpha based on time
    local alpha = self.StartAlpha
    
    if CurTime() > self.FadeStartTime then
        -- Calculate fade over last 3 seconds
        local fadeProgress = (CurTime() - self.FadeStartTime) / 3.0
        alpha = math.Lerp(self.StartAlpha, self.EndAlpha, fadeProgress)
    end
    
    -- Render the web line
    render.SetMaterial(self.Mat)
    render.DrawBeam(
        self.StartPos,
        self.EndPos,
        self.StartWidth,
        0,
        1,
        Color(self.Color.r, self.Color.g, self.Color.b, alpha)
    )
end 