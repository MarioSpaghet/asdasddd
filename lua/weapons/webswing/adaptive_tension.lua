-- Adaptive Tension System for Web Swinging
-- Makes web tension adapt naturally to player intentions and movement

local AdaptiveTension = {}

-- Configuration
AdaptiveTension.Config = {
    -- Tension Response: How quickly the web tension responds to inputs
    ResponseScale = 1.0,
    
    -- Maximum tension multiplicative range (min/max tension)
    MinTensionMult = 0.6,  -- 60% of normal tension = very loose web
    MaxTensionMult = 1.8,  -- 180% of normal tension = very tight web
    
    -- Input mapping
    PrimaryTensionKey = IN_DUCK,     -- Default: Crouch key tightens web
    SecondaryTensionKey = IN_JUMP,   -- Default: Jump key loosens web
    
    -- Auto-tension based on context
    EnableAutoTension = true,        -- Automatically adjust tension based on context
    CornerDetectionFactor = 1.3,     -- How much to loosen when cornering
    SpeedBoostThreshold = 600,       -- Speed threshold for high-speed auto-tightening
    VerticalClimbFactor = 1.4,       -- How much to tighten when climbing
    
    -- Tension Feedback
    EnableHapticFeedback = true,     -- Provide haptic feedback for tension changes
    EnableSoundFeedback = true,      -- Provide sound feedback for tension changes
    EnableVisualFeedback = true,     -- Provide visual feedback (web thickness changes)
    
    -- Advanced physics
    MassFactorAdjustment = true,     -- Adjust physics mass based on tension
    DampingAdjustment = true,        -- Adjust physics damping based on tension
    
    -- Intention detection
    IntentionDetectionStrength = 0.6, -- How strongly to respond to detected player intentions
    MomentumPreservationFactor = 0.8  -- How much to adjust tension to preserve momentum
}

-- State variables
AdaptiveTension.State = {
    CurrentTensionMultiplier = 1.0,   -- Current tension multiplier (1.0 = normal)
    TargetTensionMultiplier = 1.0,    -- Target tension multiplier 
    LastTensionChange = 0,            -- Last time tension was changed
    TensionChangeRate = 0,            -- Rate of tension change
    LastVerticalAngle = 0,            -- Track last vertical angle for climb detection
    IntentionVector = Vector(0,0,0),  -- Detected player intention direction
    ContextTension = 1.0,             -- Context-based tension component
    InputTension = 1.0,               -- Input-based tension component
    AutomaticTensionMode = 0,         -- 0=neutral, 1=auto-tighten, -1=auto-loosen
    LastTensionSoundTime = 0,         -- Last time a tension sound was played
    VisualThicknessMultiplier = 1.0,  -- Visual thickness of the web
    LastConstraintUpdate = 0          -- Last time the constraint was updated
}

-- Initialize the adaptive tension system
function AdaptiveTension:Initialize()
    -- Load ConVars for configuration
    self:LoadConVarSettings()
    
    -- Set default state
    self.State.CurrentTensionMultiplier = 1.0
    self.State.TargetTensionMultiplier = 1.0
    
    -- Register any needed hooks
    if CLIENT and self.Config.EnableVisualFeedback then
        hook.Add("PreDrawEffects", "AdaptiveTension_WebThickness", function()
            self:UpdateWebVisuals()
        end)
    end
    
    return self
end

-- Load settings from ConVars
function AdaptiveTension:LoadConVarSettings()
    -- Load values from global ConVars
    self.Config.ResponseScale = GetConVar("webswing_tension_response"):GetFloat()
    self.Config.EnableAutoTension = GetConVar("webswing_auto_tension"):GetBool()
    self.Config.EnableSoundFeedback = GetConVar("webswing_tension_feedback"):GetBool()
    self.Config.EnableHapticFeedback = GetConVar("webswing_tension_feedback"):GetBool()
    self.Config.MinTensionMult = GetConVar("webswing_tension_min_mult"):GetFloat()
    self.Config.MaxTensionMult = GetConVar("webswing_tension_max_mult"):GetFloat()
end

-- Update the tension based on player input and context
function AdaptiveTension:Update(owner, constraintController, currentVelocity, frameTime, ragdoll)
    if not IsValid(owner) or not constraintController then return end
    
    -- Reload ConVar settings occasionally
    if CurTime() % 5 < frameTime then
        self:LoadConVarSettings()
    end
    
    -- Skip if adaptive tension is disabled
    if not GetConVar("webswing_adaptive_tension"):GetBool() then 
        return constraintController.current_length
    end
    
    -- Calculate base values needed for tension calculations
    local currentSpeed = currentVelocity:Length()
    local horizontalSpeed = Vector(currentVelocity.x, currentVelocity.y, 0):Length()
    local verticalVelocity = currentVelocity.z
    local eyeAngles = owner:EyeAngles()
    
    -- Calculate vertical angle of the web (for climb detection)
    local attachPos = constraintController.rope:GetPos()
    local physObj = ragdoll:GetPhysicsObjectNum(11) -- Main body bone
    local toAttach = (attachPos - physObj:GetPos()):GetNormalized()
    local verticalAngle = math.deg(math.acos(math.abs(toAttach:Dot(Vector(0, 0, 1)))))
    
    -- Store for climb detection
    local verticalAngleDelta = verticalAngle - self.State.LastVerticalAngle
    self.State.LastVerticalAngle = verticalAngle
    
    -- 1. Process manual input for tension control
    local inputTension = self:ProcessInputTension(owner, frameTime)
    
    -- 2. Process contextual tension if enabled
    local contextTension = 1.0
    if self.Config.EnableAutoTension then
        contextTension = self:CalculateContextTension(
            horizontalSpeed, 
            verticalVelocity, 
            verticalAngle, 
            verticalAngleDelta, 
            eyeAngles.p
        )
    end
    
    -- 3. Process intention-based tension
    local intentionTension = self:DetectPlayerIntention(owner, currentVelocity, eyeAngles)
    
    -- Combine tension components with respective weights
    local manualWeight = inputTension ~= 1.0 and 0.7 or 0.0  -- Give higher priority to manual input
    local contextWeight = self.Config.EnableAutoTension and 0.5 or 0.0
    local intentionWeight = self.Config.IntentionDetectionStrength
    
    local totalWeight = manualWeight + contextWeight + intentionWeight
    if totalWeight > 0 then
        self.State.TargetTensionMultiplier = 
            (inputTension * manualWeight + 
             contextTension * contextWeight + 
             intentionTension * intentionWeight) / totalWeight
    else
        self.State.TargetTensionMultiplier = 1.0
    end
    
    -- Apply limits
    self.State.TargetTensionMultiplier = math.Clamp(
        self.State.TargetTensionMultiplier,
        self.Config.MinTensionMult,
        self.Config.MaxTensionMult
    )
    
    -- Apply smooth transition to new tension
    local tensionChangeSpeed = 2.0 * self.Config.ResponseScale
    self.State.CurrentTensionMultiplier = Lerp(
        frameTime * tensionChangeSpeed,
        self.State.CurrentTensionMultiplier,
        self.State.TargetTensionMultiplier
    )
    
    -- Apply the new tension to the constraint length
    self:ApplyTensionToConstraint(constraintController, frameTime)
    
    -- Apply feedback effects
    self:ApplyTensionFeedback(owner, constraintController)
    
    -- Adjust physics properties if enabled
    if self.Config.MassFactorAdjustment or self.Config.DampingAdjustment then
        self:AdjustPhysicsProperties(ragdoll)
    end
    
    return constraintController.current_length
end

-- Process player input for manual tension control
function AdaptiveTension:ProcessInputTension(owner, frameTime)
    if not IsValid(owner) then return 1.0 end
    
    local targetTension = 1.0
    
    -- Process primary tension key (tighten)
    if owner:KeyDown(self.Config.PrimaryTensionKey) then
        targetTension = 0.7 -- Tighten the web
        
        -- Add an extra tightening effect if player is also pressing forward
        if owner:KeyDown(IN_FORWARD) then
            targetTension = 0.6 -- Even tighter
        end
        
        self.State.AutomaticTensionMode = 1 -- Auto-tighten mode
    end
    
    -- Process secondary tension key (loosen)
    if owner:KeyDown(self.Config.SecondaryTensionKey) then
        targetTension = 1.4 -- Loosen the web
        
        -- Add an extra loosening effect if player is also pressing a directional key
        if owner:KeyDown(IN_MOVELEFT) or owner:KeyDown(IN_MOVERIGHT) then
            targetTension = 1.5 -- Even looser for sharper turns
        end
        
        self.State.AutomaticTensionMode = -1 -- Auto-loosen mode
    end
    
    -- Reset automatic mode if no keys are held
    if not owner:KeyDown(self.Config.PrimaryTensionKey) and not owner:KeyDown(self.Config.SecondaryTensionKey) then
        self.State.AutomaticTensionMode = 0
    end
    
    -- Smooth transition for input tension
    self.State.InputTension = Lerp(frameTime * 5, self.State.InputTension, targetTension)
    
    return self.State.InputTension
end

-- Calculate contextual tension based on movement, environment and physics
function AdaptiveTension:CalculateContextTension(horizontalSpeed, verticalVelocity, verticalAngle, verticalAngleDelta, lookPitch)
    local contextTension = 1.0
    
    -- Detect sharp cornering - loosen web
    if RopeDynamics and RopeDynamics.LastCornerTime and CurTime() - RopeDynamics.LastCornerTime < 0.5 then
        local timeSinceCorner = CurTime() - RopeDynamics.LastCornerTime
        local cornerFactor = Lerp(timeSinceCorner / 0.5, self.Config.CornerDetectionFactor, 1.0)
        contextTension = contextTension * cornerFactor
    end
    
    -- Detect vertical climbing - tighten web
    local isClimbing = verticalVelocity > 50 and verticalAngle < 45
    if isClimbing then
        -- Tighten more for steeper climbs
        local climbFactor = Lerp(1 - (verticalAngle / 45), self.Config.VerticalClimbFactor, 1.0)
        contextTension = contextTension / climbFactor -- Divide to tighten
    end
    
    -- Detect high-speed swinging - gradually tighten web to maintain momentum
    if horizontalSpeed > self.Config.SpeedBoostThreshold then
        local speedFactor = math.Clamp((horizontalSpeed - self.Config.SpeedBoostThreshold) / 400, 0, 0.3)
        contextTension = contextTension * (1 - speedFactor)
    end
    
    -- Detect if player is looking up - slightly loosen web for upward swing
    if lookPitch < -20 then
        local upwardFactor = math.Clamp((-lookPitch - 20) / 70, 0, 0.2)
        contextTension = contextTension * (1 + upwardFactor)
    end
    
    -- Detect if player is looking down - slightly tighten web for downward swing/dive
    if lookPitch > 20 then
        local downwardFactor = math.Clamp((lookPitch - 20) / 70, 0, 0.2)
        contextTension = contextTension / (1 + downwardFactor)
    end
    
    -- Store for other systems
    self.State.ContextTension = contextTension
    
    return contextTension
end

-- Analyze player inputs and movement to detect intention
function AdaptiveTension:DetectPlayerIntention(owner, velocity, eyeAngles)
    if not IsValid(owner) then return 1.0 end
    
    -- Default neutral tension
    local intentionTension = 1.0
    
    -- Create intention vector from inputs
    local intentionVec = Vector(0, 0, 0)
    
    -- Add contributions from movement keys
    if owner:KeyDown(IN_FORWARD) then 
        intentionVec = intentionVec + eyeAngles:Forward()
    end
    if owner:KeyDown(IN_BACK) then 
        intentionVec = intentionVec - eyeAngles:Forward()
    end
    if owner:KeyDown(IN_MOVELEFT) then 
        intentionVec = intentionVec - eyeAngles:Right()
    end
    if owner:KeyDown(IN_MOVERIGHT) then 
        intentionVec = intentionVec + eyeAngles:Right()
    end
    
    -- If no inputs, use current velocity direction
    if intentionVec:Length() < 0.1 then
        if velocity:Length() > 100 then
            intentionVec = velocity:GetNormalized()
        else
            intentionVec = eyeAngles:Forward() -- Default to look direction
        end
    else
        intentionVec:Normalize()
    end
    
    -- Store intention vector for other systems
    self.State.IntentionVector = intentionVec
    
    -- Calculate deviation from current velocity
    local velNorm = velocity:Length() > 100 and velocity:GetNormalized() or Vector(0,0,0)
    local intentionAlignment = velNorm:Dot(intentionVec)
    
    -- Adjust tension based on alignment
    if intentionAlignment < 0.5 then
        -- Sharp turn or reversal intention - loosen web
        local turnFactor = 1 + (0.5 - intentionAlignment) * 0.8
        intentionTension = intentionTension * turnFactor
    elseif intentionAlignment > 0.8 then
        -- Trying to go faster in same direction - tighten web
        local straightFactor = 1 - (intentionAlignment - 0.8) * 0.5
        intentionTension = intentionTension * straightFactor
    end
    
    return intentionTension
end

-- Apply the calculated tension to the constraint
function AdaptiveTension:ApplyTensionToConstraint(constraintController, frameTime)
    if not constraintController then return end
    
    -- Calculate the tension adjustment factor
    local tensionFactor = self.State.CurrentTensionMultiplier
    
    -- Apply to the constraint length
    local baseLength = constraintController.initial_length or 100
    local targetLength = baseLength * tensionFactor
    
    -- Apply rate limiting for smoother transitions
    local currentLength = constraintController.current_length
    local maxChange = math.max(5, baseLength * 0.05) * frameTime * self.Config.ResponseScale
    local newLength = math.Clamp(
        targetLength,
        currentLength - maxChange,
        currentLength + maxChange
    )
    
    -- Update the constraint if the change is significant enough
    if math.abs(newLength - currentLength) > 0.5 then
        constraintController.current_length = newLength
        
        -- Only update the constraint occasionally to reduce network traffic
        local timeSinceLastUpdate = CurTime() - self.State.LastConstraintUpdate
        if timeSinceLastUpdate > 0.05 then
            constraintController:Set()
            self.State.LastConstraintUpdate = CurTime()
        end
    end
end

-- Apply feedback effects based on tension changes
function AdaptiveTension:ApplyTensionFeedback(owner, constraintController)
    if not IsValid(owner) then return end
    
    -- Calculate tension change for feedback intensity
    local tensionChange = math.abs(self.State.CurrentTensionMultiplier - self.State.TargetTensionMultiplier)
    
    -- Apply haptic feedback if enabled
    if CLIENT and self.Config.EnableHapticFeedback then
        if tensionChange > 0.03 then
            local intensity = math.Clamp(tensionChange * 5, 0, 1)
            
            -- Only for local player
            if owner == LocalPlayer() then
                -- Use subtle haptic feedback for tension changes
                util.ScreenShake(Vector(0,0,0), intensity * 0.5, 5, 0.2, 0)
            end
        end
    end
    
    -- Apply sound feedback if enabled
    if SERVER and self.Config.EnableSoundFeedback then
        local timeSinceLastSound = CurTime() - self.State.LastTensionSoundTime
        
        if tensionChange > 0.05 and timeSinceLastSound > 0.5 then
            local intensity = math.Clamp(tensionChange * 10, 0, 1)
            
            -- Different sounds for tightening vs loosening
            if self.State.CurrentTensionMultiplier < 1.0 then
                -- Tightening sound
                owner:EmitSound("physics/rubber/rubber_tire_strain" .. math.random(1, 3) .. ".wav", 
                    50 + intensity * 25, 
                    100 + intensity * 50)
            else
                -- Loosening sound
                owner:EmitSound("physics/plastic/plastic_barrel_strain" .. math.random(1, 3) .. ".wav", 
                    50 + intensity * 25, 
                    80 + intensity * 40)
            end
            
            self.State.LastTensionSoundTime = CurTime()
        end
    end
    
    -- Update visual thickness multiplier for web rendering
    if self.Config.EnableVisualFeedback then
        local targetThickness = 1 / self.State.CurrentTensionMultiplier -- Inverse relation: tighter = thinner
        self.State.VisualThicknessMultiplier = Lerp(0.1, self.State.VisualThicknessMultiplier, targetThickness)
    end
end

-- Update web visuals (thickness) based on tension
function AdaptiveTension:UpdateWebVisuals()
    -- This would be implemented to change the web's visual thickness
    -- For now this is a placeholder, as it would require changes to the web rendering system
end

-- Adjust physics properties based on tension
function AdaptiveTension:AdjustPhysicsProperties(ragdoll)
    if not IsValid(ragdoll) then return end
    
    local tensionFactor = self.State.CurrentTensionMultiplier
    
    -- Apply to physics objects if needed
    if self.Config.MassFactorAdjustment or self.Config.DampingAdjustment then
        for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
            local physObj = ragdoll:GetPhysicsObjectNum(i)
            if IsValid(physObj) then
                -- Adjust mass based on tension (tighter = more responsive = slightly lower mass)
                if self.Config.MassFactorAdjustment then
                    local baseMass = PhysicsSystem.STANDARD_RAGDOLL_MASS or 1
                    local massAdjust = Lerp(tensionFactor, 0.9, 1.1) -- 0.9-1.1x mass range
                    physObj:SetMass(baseMass * massAdjust)
                end
                
                -- Adjust damping based on tension (tighter = more control = higher damping)
                if self.Config.DampingAdjustment then
                    local dampingAdjust = Lerp(tensionFactor, 0.3, 0.1) -- Higher damping for tighter web
                    local angularAdjust = Lerp(tensionFactor, 0.9, 0.6) -- Higher angular damping for tighter web
                    physObj:SetDamping(dampingAdjust, angularAdjust)
                end
            end
        end
    end
end

return AdaptiveTension 