-- cl_webswing.lua
local ClientWebEffects = {}

function ClientWebEffects.ShootPredictedWeb(ply, startPos, endPos, webType)
    if not IsValid(ply) or ply ~= LocalPlayer() then return end

    local duration = 0.2 -- seconds
    
    local effectData = EffectData()
    effectData:SetOrigin(startPos)
    effectData:SetStart(endPos) -- Using SetStart for the end position of the beam
    effectData:SetScale(duration) -- Duration of the effect
    effectData:SetEntity(ply) -- Associate with player
    
    if webType == "zip" then
        util.Effect("webshooter_beam_zip", effectData, true, true) -- Prediction enabled
    else
        util.Effect("webshooter_beam_swing", effectData, true, true) -- Prediction enabled
    end

end

_G.ClientWebEffects = ClientWebEffects
