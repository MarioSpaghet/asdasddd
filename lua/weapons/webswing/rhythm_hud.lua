-- Rhythm HUD for web swinging

local RhythmHUD = {}

-- Configuration
RhythmHUD.Config = {
    Scale = 0.8,               -- Overall scale of the HUD
    Opacity = 0.7,             -- Base opacity
    EnableRhythmIndicator = true,
    EnableSwingPhaseBar = true,
    EnableRhythmMeter = true,
    EnableMomentumDisplay = true, -- Display momentum building system
    Position = {
        x = 100,               -- Position from bottom-right corner (x)
        y = 100                -- Position from bottom-right corner (y)
    }
}

-- Colors
RhythmHUD.Colors = {
    Background = Color(0, 0, 0, 120),
    RhythmBar = Color(255, 255, 255, 180),
    RhythmBarBG = Color(30, 30, 30, 150),
    RhythmHighlight = Color(255, 255, 255, 255),
    SwingPhase = Color(220, 220, 220, 200),
    OptimalRelease = Color(0, 255, 120, 255),
    Text = Color(255, 255, 255, 200),
    Border = Color(100, 100, 100, 150),
    Momentum = {
        Base = Color(255, 223, 0, 180),         -- Gold for momentum
        Level1 = Color(255, 223, 0, 200),       -- Level 1 (1 perfect swing)
        Level2 = Color(255, 165, 0, 220),       -- Level 2 (2 perfect swings)
        Level3 = Color(255, 100, 0, 240),       -- Level 3 (3 perfect swings)
        Level4 = Color(255, 50, 0, 255),        -- Level 4 (4 perfect swings)
        Level5 = Color(255, 0, 128, 255),       -- Level 5 (5 perfect swings)
        Diving = Color(0, 200, 255, 255)        -- Color for dive boost
    }
}

-- Initialize the HUD elements
function RhythmHUD:Initialize()
    -- Create materials or prepare resources
    self.LastRhythmScore = 0
    self.ScoreInterpolated = 0
    self.PhaseBarWidth = 140 * self.Config.Scale
    self.AnimatedValues = {
        RhythmScore = 0,
        SwingPhase = 0,
        OptimalPoint = 0
    }
end

-- Draw the rhythm meter
function RhythmHUD:DrawRhythmMeter(x, y, rhythmScore, inRhythm)
    local barWidth = 120 * self.Config.Scale
    local barHeight = 8 * self.Config.Scale
    
    -- Interpolate the score for smoother visual changes
    self.AnimatedValues.RhythmScore = Lerp(FrameTime() * 8, self.AnimatedValues.RhythmScore, rhythmScore)
    
    -- Background
    draw.RoundedBox(4, x, y, barWidth, barHeight, self.Colors.RhythmBarBG)
    
    -- Rhythm bar
    local fillWidth = barWidth * self.AnimatedValues.RhythmScore
    local fillColor = Color(
        Lerp(self.AnimatedValues.RhythmScore, 255, 100),
        Lerp(self.AnimatedValues.RhythmScore, 50, 255),
        Lerp(self.AnimatedValues.RhythmScore, 50, 150),
        200
    )
    
    draw.RoundedBox(4, x, y, fillWidth, barHeight, fillColor)
    
    -- Indicator text
    draw.SimpleText("RHYTHM", "DermaDefault", x + barWidth / 2, y - 12, self.Colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    -- In-rhythm indicator
    if inRhythm then
        local pulseVal = (math.sin(CurTime() * 6) + 1) / 2
        local highlightColor = Color(
            fillColor.r,
            fillColor.g,
            fillColor.b,
            Lerp(pulseVal, 100, 255)
        )
        
        surface.SetDrawColor(highlightColor)
        surface.DrawOutlinedRect(x, y, barWidth, barHeight, 2)
    end
    
    return y + barHeight + 10
end

-- Draw the swing phase indicator
function RhythmHUD:DrawSwingPhaseBar(x, y, swingPhase, optimalReleasePoint)
    local barWidth = self.PhaseBarWidth
    local barHeight = 12 * self.Config.Scale
    
    -- Interpolate values for smooth animation
    self.AnimatedValues.SwingPhase = Lerp(FrameTime() * 10, self.AnimatedValues.SwingPhase, swingPhase)
    self.AnimatedValues.OptimalPoint = Lerp(FrameTime() * 5, self.AnimatedValues.OptimalPoint, optimalReleasePoint)
    
    -- Background
    draw.RoundedBox(4, x, y, barWidth, barHeight, self.Colors.RhythmBarBG)
    
    -- Current phase indicator
    local phaseX = x + barWidth * self.AnimatedValues.SwingPhase
    
    -- Draw the phase line
    surface.SetDrawColor(self.Colors.SwingPhase)
    surface.DrawRect(x, y, phaseX - x, barHeight)
    
    -- Highlight the optimal release point
    local optimalX = x + barWidth * self.AnimatedValues.OptimalPoint
    local optimalWidth = 3 * self.Config.Scale
    surface.SetDrawColor(self.Colors.OptimalRelease)
    surface.DrawRect(optimalX - optimalWidth/2, y - 2, optimalWidth, barHeight + 4)
    
    -- Add markers for start/end
    surface.SetDrawColor(self.Colors.Border)
    surface.DrawOutlinedRect(x, y, barWidth, barHeight, 1)
    
    -- Phase indicator text
    draw.SimpleText("SWING PHASE", "DermaDefault", x + barWidth / 2, y - 12, self.Colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    -- Draw proximity to optimal release feedback
    local proximityToOptimal = 1 - math.abs(self.AnimatedValues.SwingPhase - self.AnimatedValues.OptimalPoint) * 2
    if proximityToOptimal > 0.5 then
        local pulseVal = (math.sin(CurTime() * 8) + 1) / 2
        local highlightAlpha = Lerp(proximityToOptimal, 0, 255) * pulseVal
        local highlightColor = Color(50, 255, 100, highlightAlpha)
        
        surface.SetDrawColor(highlightColor)
        surface.DrawOutlinedRect(x, y, barWidth, barHeight, 2)
        
        if proximityToOptimal > 0.8 then
            draw.SimpleText("RELEASE!", "DermaDefault", x + barWidth + 10, y + barHeight/2, 
                            Color(50, 255, 100, highlightAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    
    return y + barHeight + 10
end

-- Draw the next swing timing indicator
function RhythmHUD:DrawNextSwingIndicator(x, y, nextSwingTime, currentTime)
    local timeRemaining = nextSwingTime - currentTime
    if timeRemaining <= 0 then return y end
    
    local indicatorWidth = 80 * self.Config.Scale
    local indicatorHeight = 8 * self.Config.Scale
    
    -- Only show if we're getting close to the next swing
    if timeRemaining > 1.5 then return y end
    
    -- Calculate countdown visual
    local countdownProgress = math.Clamp(1 - (timeRemaining / 1.5), 0, 1)
    local fillWidth = indicatorWidth * countdownProgress
    
    -- Draw background
    draw.RoundedBox(4, x, y, indicatorWidth, indicatorHeight, self.Colors.RhythmBarBG)
    
    -- Draw fill
    local fillColor = Color(255, 255, 255, 200)
    if countdownProgress > 0.8 then
        -- Pulse when it's time to swing
        local pulseVal = (math.sin(CurTime() * 10) + 1) / 2
        fillColor = Color(50, 255, 100, Lerp(pulseVal, 150, 255))
    end
    draw.RoundedBox(4, x, y, fillWidth, indicatorHeight, fillColor)
    
    -- Indicator text
    draw.SimpleText("NEXT SWING", "DermaDefault", x + indicatorWidth / 2, y - 12, self.Colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    if countdownProgress > 0.8 then
        draw.SimpleText("NOW!", "DermaDefault", x + indicatorWidth + 10, y + indicatorHeight/2, 
                        fillColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    
    return y + indicatorHeight + 10
end

-- Draw the momentum building display
function RhythmHUD:DrawMomentumSystem(x, y, momentumData)
    if not self.Config.EnableMomentumDisplay or not momentumData then return end
    
    local consecutiveSwings = momentumData.consecutivePerfectSwings or 0
    local momentumMultiplier = momentumData.momentumMultiplier or 1.0
    local isDiving = momentumData.isDiving or false
    local peakSpeed = momentumData.peakSpeed or 0
    
    -- Calculate dimensions
    local width = 150 * self.Config.Scale
    local height = 40 * self.Config.Scale
    local barHeight = 10 * self.Config.Scale
    local padding = 5 * self.Config.Scale
    
    -- Draw background
    draw.RoundedBox(4, x, y, width, height, self.Colors.Background)
    draw.RoundedBoxEx(4, x, y, width, 18 * self.Config.Scale, Color(20, 20, 20, 150), true, true, false, false)
    
    -- Draw title
    draw.SimpleText("MOMENTUM", "DermaDefault", x + width/2, y + 9 * self.Config.Scale, self.Colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    -- Draw momentum bars
    local barY = y + 22 * self.Config.Scale
    local barWidth = (width - padding*2) / 5 -- 5 levels of momentum
    
    -- Draw all bar backgrounds
    for i = 1, 5 do
        local barX = x + padding + (i-1) * barWidth
        draw.RoundedBox(2, barX, barY, barWidth - 2, barHeight, self.Colors.RhythmBarBG)
    end
    
    -- Draw active momentum bars
    local activeLevel = math.min(5, math.ceil(consecutiveSwings))
    for i = 1, activeLevel do
        local barX = x + padding + (i-1) * barWidth
        local momentumColor
        
        -- Select color based on level
        if i == 1 then momentumColor = self.Colors.Momentum.Level1
        elseif i == 2 then momentumColor = self.Colors.Momentum.Level2
        elseif i == 3 then momentumColor = self.Colors.Momentum.Level3
        elseif i == 4 then momentumColor = self.Colors.Momentum.Level4
        else momentumColor = self.Colors.Momentum.Level5 end
        
        draw.RoundedBox(2, barX, barY, barWidth - 2, barHeight, momentumColor)
    end
    
    -- Draw dive indicator if active
    if isDiving then
        draw.RoundedBox(4, x + width - 15 * self.Config.Scale, y + 5 * self.Config.Scale, 10 * self.Config.Scale, 10 * self.Config.Scale, self.Colors.Momentum.Diving)
    end
    
    -- Draw speed text
    local speedText = math.floor(peakSpeed) .. " u/s"
    draw.SimpleText(speedText, "DermaDefault", x + width - padding, barY + barHeight + padding, self.Colors.Text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    
    return height + 5 * self.Config.Scale -- Return height for positioning other elements
end

-- Main draw function
function RhythmHUD:Draw(rhythmSystem)
    if not GetConVar("webswing_rhythm_feedback"):GetBool() then return end
    
    local rhythmData = rhythmSystem and rhythmSystem.FeedbackData
    if not rhythmData then return end
    
    local screenW, screenH = ScrW(), ScrH()
    local baseX = screenW - self.Config.Position.x
    local baseY = screenH - self.Config.Position.y
    local yOffset = 0
    
    -- Draw the rhythms elements only if enabled and we have data
    if rhythmData.rhythmScore and self.Config.EnableRhythmMeter then
        self:DrawRhythmMeter(baseX - 120 * self.Config.Scale, baseY - yOffset, rhythmData.rhythmScore, rhythmData.inRhythm)
        yOffset = yOffset + 15 * self.Config.Scale
    end
    
    if rhythmData.swingPhase and self.Config.EnableSwingPhaseBar then
        self:DrawSwingPhaseBar(baseX - self.PhaseBarWidth, baseY - yOffset, 
                               rhythmData.swingPhase, 
                               rhythmData.optimalReleasePoint)
        yOffset = yOffset + 25 * self.Config.Scale
    end
    
    -- Draw the new momentum display
    if self.Config.EnableMomentumDisplay then
        local momentumHeight = self:DrawMomentumSystem(baseX - 150 * self.Config.Scale, baseY - yOffset, rhythmData)
        yOffset = yOffset + momentumHeight
    end
    
    -- Draw the rhythm indicator
    if self.Config.EnableRhythmIndicator then
        self:DrawRhythmIndicator(baseX - 40 * self.Config.Scale, baseY - yOffset, 
                                 rhythmData.nextSwingTime, 
                                 rhythmData.currentTime)
    end
end

-- Update function (called each frame)
function RhythmHUD:Update()
    -- Update animations or states if needed
end

return RhythmHUD 