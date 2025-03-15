-- Flow State HUD for Web Swinging
-- Visual feedback for the flow state system

local FlowStateHUD = {}

-- Configuration
FlowStateHUD.Config = {
    Scale = 0.8,                -- Overall scale of the HUD
    Opacity = 0.8,              -- Base opacity
    EnableFlowMeter = true,     -- Display flow meter
    EnableChainCounter = true,  -- Display chain counter
    EnableAbilityIndicators = true, -- Display ability indicators
    EnableSpeedometer = true,   -- Display speed indicator
    Position = {
        x = 160,                -- Position from bottom-right corner (x)
        y = 140                 -- Position from bottom-right corner (y)
    },
    Animation = {
        PulsateSpeed = 4,       -- Speed of pulsating effects
        GlowIntensity = 0.7,    -- Intensity of glow effects
        FadeSpeed = 5           -- Speed of fade animations
    }
}

-- Colors
FlowStateHUD.Colors = {
    Background = Color(0, 0, 0, 150),
    Border = Color(100, 100, 100, 150),
    Text = Color(255, 255, 255, 230),
    FlowMeter = {
        Background = Color(30, 30, 30, 150),
        Fill = Color(100, 200, 255, 200), -- Default color, changes with level
        Border = Color(150, 150, 150, 200)
    },
    ChainCounter = {
        Background = Color(40, 40, 40, 170),
        Text = Color(255, 255, 255, 230),
        Chain1 = Color(180, 180, 180, 200), -- Grey
        Chain2 = Color(100, 255, 100, 200), -- Green
        Chain3 = Color(255, 255, 100, 200), -- Yellow
        Chain4 = Color(255, 160, 0, 200),   -- Orange
        Chain5Plus = Color(255, 50, 50, 200) -- Red
    },
    Abilities = {
        Available = Color(0, 255, 100, 255),
        Unavailable = Color(150, 150, 150, 150),
        Active = Color(255, 255, 255, 255)
    },
    Speedometer = {
        Background = Color(30, 30, 30, 150),
        Needle = Color(255, 50, 50, 230),
        Text = Color(255, 255, 255, 200)
    }
}

-- Initialize the HUD elements
function FlowStateHUD:Initialize()
    -- Set up animated values for smooth transitions
    self.AnimatedValues = {
        FlowScore = 0,
        FlowLevel = 0,
        ChainCount = 0,
        ChainMultiplier = 1.0,
        Speed = 0,
        AbilityGlow = 0,
        FlowBarWidth = 0,
        FlowPulse = 0,
    }
    
    -- Initialize effect timers
    self.EffectTimers = {
        LastLevelUp = 0,
        LastChainIncrease = 0,
        LastAbilityActivation = 0
    }
    
    -- Initialize ability icons
    self.AbilityIcons = {
        QuickRelease = {
            name = "Quick Release",
            desc = "Perfect timing for web releases",
            material = Material("gui/silkicons/star"),
            color = Color(100, 255, 100, 255)
        },
        TimeDilation = {
            name = "Time Dilation", 
            desc = "Briefly slow down time on perfect releases",
            material = Material("gui/silkicons/time"),
            color = Color(100, 100, 255, 255)
        }
    }
    
    -- Pre-calculate some values
    self.FlowBarWidth = 150 * self.Config.Scale
    self.FlowBarHeight = 12 * self.Config.Scale
    self.ChainCounterSize = 32 * self.Config.Scale
    self.AbilityIconSize = 24 * self.Config.Scale
    self.SpeedometerSize = 50 * self.Config.Scale
    
    return self
end

-- Main draw function
function FlowStateHUD:Draw(flowStateSystem)
    if not GetConVar("webswing_flow_enabled"):GetBool() then return end
    if not GetConVar("webswing_flow_effects"):GetBool() then return end
    
    -- Get flow state information
    local flowInfo = flowStateSystem and flowStateSystem:GetStatusInfo()
    if not flowInfo then return end
    
    -- Get screen dimensions
    local screenW, screenH = ScrW(), ScrH()
    local baseX = screenW - self.Config.Position.x
    local baseY = screenH - self.Config.Position.y
    local currentTime = CurTime()
    
    -- Update animated values
    self:UpdateAnimatedValues(flowInfo, currentTime)
    
    -- Calculate vertical spacing
    local yOffset = 0
    
    -- Draw main background panel if in flow state or transitioning
    if self.AnimatedValues.FlowScore > 0.05 then
        local panelHeight = 0
        
        -- Calculate panel height based on enabled elements
        if self.Config.EnableFlowMeter then
            panelHeight = panelHeight + self.FlowBarHeight + 15
        end
        
        if self.Config.EnableChainCounter and flowInfo.chainCount > 0 then
            panelHeight = panelHeight + self.ChainCounterSize + 10
        end
        
        if self.Config.EnableAbilityIndicators and 
           (flowInfo.abilitiesAvailable.QuickRelease or flowInfo.abilitiesAvailable.TimeDilation) then
            panelHeight = panelHeight + self.AbilityIconSize + 12
        end
        
        if self.Config.EnableSpeedometer then
            panelHeight = panelHeight + self.SpeedometerSize + 10
        end
        
        -- Add padding
        panelHeight = panelHeight + 15
        
        -- Draw the background panel
        self:DrawPanel(baseX - self.FlowBarWidth - 20, baseY - panelHeight, 
                       self.FlowBarWidth + 20, panelHeight, flowInfo)
    end
    
    -- Draw flow meter
    if self.Config.EnableFlowMeter then
        yOffset = yOffset + self:DrawFlowMeter(baseX, baseY - yOffset, flowInfo)
    end
    
    -- Draw chain counter
    if self.Config.EnableChainCounter and flowInfo.chainCount > 0 then
        yOffset = yOffset + self:DrawChainCounter(baseX, baseY - yOffset, flowInfo)
    end
    
    -- Draw ability indicators
    if self.Config.EnableAbilityIndicators and 
       (flowInfo.abilitiesAvailable.QuickRelease or flowInfo.abilitiesAvailable.TimeDilation) then
        yOffset = yOffset + self:DrawAbilityIndicators(baseX, baseY - yOffset, flowInfo)
    end
    
    -- Draw speedometer
    if self.Config.EnableSpeedometer then
        yOffset = yOffset + self:DrawSpeedometer(baseX, baseY - yOffset, flowInfo)
    end
end

-- Draw the background panel
function FlowStateHUD:DrawPanel(x, y, width, height, flowInfo)
    -- Base panel with glow based on flow level
    local flowColor = flowInfo.flowColor or Color(255, 255, 255)
    local glowIntensity = self.AnimatedValues.FlowScore * self.Config.Animation.GlowIntensity
    
    -- Background
    draw.RoundedBox(6, x, y, width, height, self.Colors.Background)
    
    -- Glowing border based on flow level
    if flowInfo.flowLevel > 0 then
        local pulseVal = (math.sin(CurTime() * self.Config.Animation.PulsateSpeed) + 1) / 2
        local borderColor = Color(
            flowColor.r,
            flowColor.g,
            flowColor.b,
            80 + (glowIntensity * pulseVal * 100)
        )
        
        -- Draw border
        surface.SetDrawColor(borderColor)
        surface.DrawOutlinedRect(x, y, width, height, 2)
    end
    
    -- Header text
    draw.SimpleText("FLOW STATE", "DermaDefault", x + width/2, y + 8, self.Colors.Text, TEXT_ALIGN_CENTER)
    
    -- Draw level indicator
    if flowInfo.flowLevel > 0 then
        local levelText = "LEVEL " .. flowInfo.flowLevel
        local textColor = Color(
            flowColor.r,
            flowColor.g,
            flowColor.b,
            self.Colors.Text.a
        )
        
        -- Draw with glow effect if recently leveled up
        local timeSinceLevelUp = CurTime() - self.EffectTimers.LastLevelUp
        if timeSinceLevelUp < 1.0 then
            local pulseVal = (1.0 - timeSinceLevelUp) * 0.5
            local glowColor = Color(
                flowColor.r,
                flowColor.g,
                flowColor.b,
                150 * pulseVal
            )
            
            -- Draw glow text
            draw.SimpleText(levelText, "DermaDefaultBold", x + width/2 + 1, y + 8 + 1, glowColor, TEXT_ALIGN_CENTER)
            draw.SimpleText(levelText, "DermaDefaultBold", x + width/2 - 1, y + 8 - 1, glowColor, TEXT_ALIGN_CENTER)
        end
        
        draw.SimpleText(levelText, "DermaDefaultBold", x + width/2, y + 8, textColor, TEXT_ALIGN_CENTER)
    end
end

-- Draw the flow meter
function FlowStateHUD:DrawFlowMeter(x, y, flowInfo)
    local barWidth = self.FlowBarWidth
    local barHeight = self.FlowBarHeight
    local padding = 10 * self.Config.Scale
    
    -- Calculate position
    local barX = x - barWidth
    local barY = y - barHeight - padding
    
    -- Background
    draw.RoundedBox(4, barX, barY, barWidth, barHeight, self.Colors.FlowMeter.Background)
    
    -- Flow bar fill
    if self.AnimatedValues.FlowScore > 0 then
        local fillWidth = barWidth * self.AnimatedValues.FlowScore
        
        -- Get flow color based on level
        local flowColor = flowInfo.flowColor or self.Colors.FlowMeter.Fill
        
        -- Create interpolated color
        local fillColor = Color(
            flowColor.r,
            flowColor.g,
            flowColor.b,
            self.Colors.FlowMeter.Fill.a
        )
        
        -- Draw the fill bar
        draw.RoundedBox(4, barX, barY, fillWidth, barHeight, fillColor)
        
        -- Draw level markers
        local scorePerLevel = 1.0 / flowInfo.flowLevel
        for i = 1, flowInfo.flowLevel do
            local markerPos = barX + barWidth * (i / flowInfo.flowLevel)
            surface.SetDrawColor(Color(255, 255, 255, 100))
            surface.DrawLine(markerPos, barY, markerPos, barY + barHeight)
        end
        
        -- Draw pulsating effect for almost-full flow
        if self.AnimatedValues.FlowScore > 0.95 then
            local pulseVal = (math.sin(CurTime() * 6) + 1) / 2
            local pulseColor = Color(
                255,
                255,
                255,
                pulseVal * 100
            )
            
            surface.SetDrawColor(pulseColor)
            surface.DrawOutlinedRect(barX, barY, barWidth, barHeight, 2)
        end
    end
    
    -- Draw border
    surface.SetDrawColor(self.Colors.FlowMeter.Border)
    surface.DrawOutlinedRect(barX, barY, barWidth, barHeight, 1)
    
    -- Draw label
    draw.SimpleText("FLOW", "DermaDefault", barX + barWidth/2, barY - 10, self.Colors.Text, TEXT_ALIGN_CENTER)
    
    return barHeight + padding + 10
end

-- Draw the chain counter
function FlowStateHUD:DrawChainCounter(x, y, flowInfo)
    if flowInfo.chainCount <= 0 then return 0 end
    
    local size = self.ChainCounterSize
    local padding = 10 * self.Config.Scale
    
    -- Calculate position
    local counterX = x - size - 10
    local counterY = y - size - padding
    
    -- Determine chain color based on count
    local chainColor
    if flowInfo.chainCount <= 1 then
        chainColor = self.Colors.ChainCounter.Chain1
    elseif flowInfo.chainCount <= 2 then
        chainColor = self.Colors.ChainCounter.Chain2
    elseif flowInfo.chainCount <= 3 then
        chainColor = self.Colors.ChainCounter.Chain3
    elseif flowInfo.chainCount <= 4 then
        chainColor = self.Colors.ChainCounter.Chain4
    else
        chainColor = self.Colors.ChainCounter.Chain5Plus
    end
    
    -- Background circle
    draw.RoundedBox(size/2, counterX, counterY, size, size, self.Colors.ChainCounter.Background)
    
    -- Draw border with chain color
    local pulseVal = (math.sin(CurTime() * self.Config.Animation.PulsateSpeed) + 1) / 2
    local borderColor = Color(
        chainColor.r,
        chainColor.g,
        chainColor.b,
        chainColor.a * (0.5 + pulseVal * 0.5)
    )
    
    surface.SetDrawColor(borderColor)
    surface.DrawOutlinedRect(counterX, counterY, size, size, 2, 8)
    
    -- Draw chain count
    local chainText = tostring(math.floor(self.AnimatedValues.ChainCount))
    draw.SimpleText(chainText, "DermaDefaultBold", counterX + size/2, counterY + size/2 - 2, 
                    self.Colors.ChainCounter.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    -- Draw multiplier text
    local multiplierText = string.format("%.1fx", self.AnimatedValues.ChainMultiplier)
    draw.SimpleText(multiplierText, "DermaDefault", counterX + size/2, counterY + size + 2, 
                    chainColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    
    -- Draw "CHAIN" label
    draw.SimpleText("CHAIN", "DermaDefault", counterX + size/2, counterY - 5, 
                    self.Colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    
    -- If chain recently increased, draw effect
    local timeSinceIncrease = CurTime() - self.EffectTimers.LastChainIncrease
    if timeSinceIncrease < 0.5 then
        local effectSize = size * (1 + timeSinceIncrease)
        local effectAlpha = 255 * (1 - timeSinceIncrease * 2)
        local effectColor = Color(
            chainColor.r,
            chainColor.g,
            chainColor.b,
            effectAlpha
        )
        
        surface.SetDrawColor(effectColor)
        surface.DrawOutlinedRect(
            counterX + size/2 - effectSize/2, 
            counterY + size/2 - effectSize/2, 
            effectSize, 
            effectSize, 
            2, 
            16
        )
    end
    
    return size + padding + 10
end

-- Draw ability indicators
function FlowStateHUD:DrawAbilityIndicators(x, y, flowInfo)
    if not flowInfo.abilitiesAvailable.QuickRelease and 
       not flowInfo.abilitiesAvailable.TimeDilation then
        return 0
    end
    
    local size = self.AbilityIconSize
    local padding = 8 * self.Config.Scale
    local spacing = 4 * self.Config.Scale
    
    -- Calculate position
    local startX = x - size * 2 - spacing - 10
    local iconY = y - size - padding
    
    -- Draw label
    draw.SimpleText("ABILITIES", "DermaDefault", startX + size, iconY - 5, 
                    self.Colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    
    -- Draw each ability icon
    local xOffset = 0
    
    -- Draw Quick Release ability
    if flowInfo.abilitiesAvailable.QuickRelease then
        local iconColor = self.Colors.Abilities.Available
        local icon = self.AbilityIcons.QuickRelease
        
        self:DrawAbilityIcon(startX + xOffset, iconY, size, icon, iconColor)
        xOffset = xOffset + size + spacing
    end
    
    -- Draw Time Dilation ability
    if flowInfo.abilitiesAvailable.TimeDilation then
        local iconColor = self.Colors.Abilities.Available
        local icon = self.AbilityIcons.TimeDilation
        
        -- If time dilation is active, use active color and add effect
        if flowInfo.timeDilated then
            iconColor = self.Colors.Abilities.Active
        end
        
        self:DrawAbilityIcon(startX + xOffset, iconY, size, icon, iconColor)
    end
    
    return size + padding + 10
end

-- Draw single ability icon
function FlowStateHUD:DrawAbilityIcon(x, y, size, icon, color)
    -- Background
    draw.RoundedBox(4, x, y, size, size, self.Colors.Background)
    
    -- Icon
    surface.SetDrawColor(color)
    surface.SetMaterial(icon.material)
    surface.DrawTexturedRect(x + 4, y + 4, size - 8, size - 8)
    
    -- Border
    surface.SetDrawColor(color.r, color.g, color.b, color.a * 0.7)
    surface.DrawOutlinedRect(x, y, size, size, 1)
    
    -- Tooltip on hover
    local mouseX, mouseY = input.GetCursorPos()
    if mouseX >= x and mouseX <= x + size and
       mouseY >= y and mouseY <= y + size then
        
        local tooltipWidth = 150
        local tooltipX = x + size/2 - tooltipWidth/2
        local tooltipY = y - 30
        
        -- Background
        draw.RoundedBox(4, tooltipX, tooltipY, tooltipWidth, 25, Color(0, 0, 0, 200))
        
        -- Name and description
        draw.SimpleText(icon.name, "DermaDefault", tooltipX + tooltipWidth/2, tooltipY + 5, 
                       Color(255, 255, 255, 255), TEXT_ALIGN_CENTER)
        draw.SimpleText(icon.desc, "DermaDefault", tooltipX + tooltipWidth/2, tooltipY + 15, 
                       Color(200, 200, 200, 200), TEXT_ALIGN_CENTER)
        
        -- Border
        surface.SetDrawColor(color)
        surface.DrawOutlinedRect(tooltipX, tooltipY, tooltipWidth, 25, 1)
    end
end

-- Draw speedometer
function FlowStateHUD:DrawSpeedometer(x, y, flowInfo)
    local size = self.SpeedometerSize
    local padding = 10 * self.Config.Scale
    
    -- Calculate position
    local speedX = x - size - 10
    local speedY = y - size - padding
    
    -- Draw background
    draw.RoundedBox(size/2, speedX, speedY, size, size, self.Colors.Speedometer.Background)
    
    -- Draw speed text
    local speedText = math.floor(self.AnimatedValues.Speed)
    draw.SimpleText(speedText, "DermaDefaultBold", speedX + size/2, speedY + size/2, 
                    self.Colors.Speedometer.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    -- Draw "SPEED" label
    draw.SimpleText("SPEED", "DermaDefault", speedX + size/2, speedY - 5, 
                   self.Colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    
    -- Calculate rotation angle based on speed
    -- Assuming max speed of 1200 units/sec for a full rotation
    local angle = math.min(self.AnimatedValues.Speed / 1200, 1) * 270 - 45
    
    -- Calculate needle endpoint
    local centerX = speedX + size/2
    local centerY = speedY + size/2
    local needleLength = size/2 - 5
    local radians = math.rad(angle - 90) -- Adjust for drawing angle
    local endX = centerX + math.cos(radians) * needleLength
    local endY = centerY + math.sin(radians) * needleLength
    
    -- Draw needle
    surface.SetDrawColor(self.Colors.Speedometer.Needle)
    surface.DrawLine(centerX, centerY, endX, endY)
    
    -- Draw needle base circle
    draw.RoundedBox(3, centerX - 3, centerY - 3, 6, 6, self.Colors.Speedometer.Needle)
    
    -- Draw speed unit
    draw.SimpleText("u/s", "DermaDefault", speedX + size/2, speedY + size - 2, 
                   self.Colors.Speedometer.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    
    return size + padding + 10
end

-- Update animated values for smooth transitions
function FlowStateHUD:UpdateAnimatedValues(flowInfo, currentTime)
    local frameTime = FrameTime()
    local fadeSpeed = self.Config.Animation.FadeSpeed
    
    -- Flow score animation
    self.AnimatedValues.FlowScore = Lerp(frameTime * fadeSpeed, 
                                         self.AnimatedValues.FlowScore, 
                                         flowInfo.flowScore or 0)
    
    -- Flow level animation (step function)
    local targetLevel = flowInfo.flowLevel or 0
    if targetLevel > self.AnimatedValues.FlowLevel then
        -- Level up effect
        self.EffectTimers.LastLevelUp = currentTime
        self.AnimatedValues.FlowLevel = targetLevel
    else
        self.AnimatedValues.FlowLevel = targetLevel
    end
    
    -- Chain count animation (step function for visual impact)
    local targetChain = flowInfo.chainCount or 0
    if targetChain > self.AnimatedValues.ChainCount then
        -- Chain increase effect
        self.EffectTimers.LastChainIncrease = currentTime
        self.AnimatedValues.ChainCount = targetChain
    else
        self.AnimatedValues.ChainCount = targetChain
    end
    
    -- Chain multiplier smooth animation
    self.AnimatedValues.ChainMultiplier = Lerp(frameTime * fadeSpeed, 
                                              self.AnimatedValues.ChainMultiplier, 
                                              flowInfo.chainMultiplier or 1.0)
    
    -- Speed animation
    self.AnimatedValues.Speed = Lerp(frameTime * fadeSpeed * 0.5, 
                                    self.AnimatedValues.Speed, 
                                    flowInfo.peakSpeed or 0)
    
    -- Ability glow animation
    local targetGlow = (flowInfo.abilitiesAvailable.QuickRelease or 
                       flowInfo.abilitiesAvailable.TimeDilation) and 1 or 0
    self.AnimatedValues.AbilityGlow = Lerp(frameTime * fadeSpeed, 
                                          self.AnimatedValues.AbilityGlow, 
                                          targetGlow)
    
    -- Flow pulse animation
    self.AnimatedValues.FlowPulse = (math.sin(currentTime * self.Config.Animation.PulsateSpeed) + 1) / 2
end

return FlowStateHUD 