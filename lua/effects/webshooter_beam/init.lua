EFFECT.Mat = Material("effects/tool_tracer")

function EFFECT:Init(data)
    self.StartPos = data:GetStart()
    self.EndPos = data:GetOrigin()
    self.Dir = (self.EndPos - self.StartPos):GetNormalized()
    self.Length = (self.EndPos - self.StartPos):Length()
    
    self.TracerTime = 0.1
    self.DieTime = CurTime() + self.TracerTime
end

function EFFECT:Think()
    return CurTime() <= self.DieTime
end

function EFFECT:Render()
    local fDelta = (self.DieTime - CurTime()) / self.TracerTime
    fDelta = math.Clamp(fDelta, 0, 1)
            
    render.SetMaterial(self.Mat)
    render.DrawBeam(self.StartPos, self.EndPos, 2 * fDelta, 0, 1, Color(255, 255, 255, 255 * fDelta))
end

effects.Register(EFFECT, "webshooter_beam")
