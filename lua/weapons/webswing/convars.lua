if SERVER then
	-- Server-side ConVars
	CreateConVar("webswing_swing_speed", "800", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Base swing force when using web swing", 1, 90000)
	CreateConVar("webswing_manual_mode", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Use manual web-swing mode (old style)", 0, 1)
	CreateConVar("webswing_enable_fall_damage", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable fall damage when using WebSwing", 0, 1)
	CreateConVar("webswing_rope_material", "cable/xbeam", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Material used for the web rope")
	CreateConVar("webswing_map_height_mult", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Multiplier for optimal swing height")
	CreateConVar("webswing_map_range_mult", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Multiplier for web range")
	CreateConVar("webswing_rope_alpha", "255", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Alpha transparency of the web rope (0-255)", 0, 255)
	CreateConVar("webswing_rope_color_r", "255", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Red component of web rope color (0-255)", 0, 255)
	CreateConVar("webswing_rope_color_g", "255", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Green component of web rope color (0-255)", 0, 255)
	CreateConVar("webswing_rope_color_b", "255", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Blue component of web rope color (0-255)", 0, 255)
	CreateConVar("webswing_momentum_preservation", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How much momentum to preserve during swings (0-2)", 0, 2)
	CreateConVar("webswing_ground_safety", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How much to prioritize avoiding ground collision (0-2)", 0, 2)
	CreateConVar("webswing_assist_strength", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How strong the swing point selection assist should be (0-2)", 0, 2)
	CreateConVar("webswing_web_length", "1500", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Maximum allowed web length", 300, 3000)
	CreateConVar("webswing_swing_curve", "1.0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How pronounced the swing arc should be (0-2)", 0, 2)
	CreateConVar("webswing_keep_webs", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Keep webs for 30 seconds after detaching", 0, 1)
	CreateConVar("webswing_gravity_reduction", "0.65", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How much to reduce gravity during swings (0-1)", 0, 1)
	CreateConVar("webswing_gravity_speed_factor", "1.2", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How much speed affects gravity reduction (0-2)", 0, 2)
	CreateConVar("webswing_gravity_angle_factor", "1.2", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How much rope angle affects gravity reduction (0-2)", 0, 2)
	-- Dynamic rope length ConVars
	CreateConVar("webswing_dynamic_length", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable dynamic rope length adjustment", 0, 1)
	CreateConVar("webswing_length_angle_factor", "1.0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How much swing angle affects rope length (0-2)", 0, 2)
	CreateConVar("webswing_min_length_ratio", "0.5", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Minimum rope length as ratio of initial length (0.1-1)", 0.1, 1)
	CreateConVar("webswing_length_smoothing", "0.8", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Smoothing factor for rope length changes (0-1)", 0, 1)
	CreateConVar("webswing_max_length_change", "100", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Maximum length change per second", 10, 500)
	-- Sky web attachment ConVars
	CreateConVar("webswing_allow_sky_attach", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Allow attaching webs to the sky", 0, 1)
	CreateConVar("webswing_sky_height", "1000", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Height for sky web attachment points", 300, 3000)
	
	-- Advanced Momentum System ConVars
	CreateConVar("webswing_momentum_building", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable momentum building from consecutive perfect swings", 0, 1)
	CreateConVar("webswing_momentum_boost_per_swing", "0.15", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Speed boost percentage per consecutive perfect swing (0-0.5)", 0, 0.5)
	CreateConVar("webswing_momentum_max_swings", "5", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Maximum consecutive perfect swings to count (1-10)", 1, 10)
	CreateConVar("webswing_momentum_decay_rate", "0.5", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How quickly momentum decays when not swinging (0-2)", 0, 2)
	CreateConVar("webswing_dive_boost_factor", "1.5", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Speed multiplier during dive boost (1-3)", 1, 3)
	CreateConVar("webswing_dive_duration", "0.75", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Duration of dive boost in seconds (0.1-2)", 0.1, 2)
	
	-- AI Swing Point Intelligence ConVars
	CreateConVar("webswing_ai_predictive_targeting", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable predictive swing point selection", 0, 1)
	CreateConVar("webswing_ai_prediction_strength", "1.0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Strength of predictive targeting (0-2)", 0, 2)
	CreateConVar("webswing_ai_dynamic_points", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable dynamic point generation in areas with few swing points", 0, 1)
	CreateConVar("webswing_ai_dynamic_points_max", "4", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Maximum number of dynamic points to generate (1-8)", 1, 8)
	CreateConVar("webswing_ai_momentum_awareness", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable momentum-aware targeting", 0, 1)
	CreateConVar("webswing_ai_momentum_factor", "1.0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Strength of momentum-aware targeting (0-2)", 0, 2)
	CreateConVar("webswing_ai_curved_paths", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable curved path planning around buildings", 0, 1)
	CreateConVar("webswing_ai_curve_strength", "1.0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Strength of curved path influence (0-2)", 0, 2)
	CreateConVar("webswing_ai_flow_threshold", "500", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Speed threshold for entering flow state (100-1000)", 100, 1000)
	CreateConVar("webswing_ai_flow_duration", "5", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How long flow state lasts in seconds (1-10)", 1, 10)
else
	-- Client-side ConVars (if required)
	-- Currently, no client specific convars; add here if needed
end 