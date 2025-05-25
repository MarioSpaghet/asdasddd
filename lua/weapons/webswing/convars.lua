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

	-- Advanced Momentum System ConVars (perfect swing functionality disabled)
	CreateConVar("webswing_momentum_building", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable momentum building from consecutive perfect swings", 0, 1)
	CreateConVar("webswing_momentum_boost_per_swing", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Speed boost percentage per consecutive perfect swing (0-0.5)", 0, 0.5)
	CreateConVar("webswing_momentum_max_swings", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Maximum consecutive perfect swings to count (1-10)", 1, 10)
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

	-- Adaptive Tension System ConVars
	CreateConVar("webswing_adaptive_tension", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable adaptive web tension", 0, 1)
	CreateConVar("webswing_tension_response", "1.0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How quickly web tension responds to inputs (0.1-3.0)", 0.1, 3.0)
	CreateConVar("webswing_auto_tension", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Automatically adjust tension based on context", 0, 1)
	CreateConVar("webswing_tension_feedback", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable audio/haptic feedback for tension changes", 0, 1)
	CreateConVar("webswing_tension_min_mult", "0.6", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Minimum tension multiplier (tighter web) (0.3-1.0)", 0.3, 1.0)
	CreateConVar("webswing_tension_max_mult", "1.8", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Maximum tension multiplier (looser web) (1.0-3.0)", 1.0, 3.0)

	-- Pendulum Physics Enhancement ConVars
	CreateConVar("webswing_pendulum_arc_emphasis", "1.2", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How much to emphasize pendulum arcs (0.5-2.0)", 0.5, 2.0)
	CreateConVar("webswing_pendulum_frequency", "1.0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Natural oscillation frequency (0.7-1.3)", 0.7, 1.3)
	CreateConVar("webswing_pendulum_apex_slowdown", "0.8", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Slowdown at swing apex (0.5-1.0)", 0.5, 1.0)
	CreateConVar("webswing_pendulum_gravity_mod", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable gravity modulation for better arcs", 0, 1)
	CreateConVar("webswing_pendulum_apex_gravity", "0.7", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Gravity factor at the apex of swing (0.4-1.0)", 0.4, 1.0)
	CreateConVar("webswing_pendulum_down_gravity", "1.2", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Gravity factor on downward swing (1.0-1.5)", 1.0, 1.5)
	CreateConVar("webswing_pendulum_body_rotation", "1.2", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Body rotation during swings (1.0-2.0)", 1.0, 2.0)
	CreateConVar("webswing_pendulum_exit_boost", "1.15", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Speed boost when exiting at optimal angle (1.0-1.5)", 1.0, 1.5)
	CreateConVar("webswing_pendulum_bobble_reduction", "0.7", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Reduction of side-to-side bobble (0.3-1.0)", 0.3, 1.0)

	-- Web Release Dynamics ConVars (perfect release functionality disabled)
	CreateConVar("webswing_release_momentum", "1.25", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Momentum conservation on web release (1.0-1.5)", 1.0, 1.5)
	CreateConVar("webswing_release_direction", "0.35", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Directional influence on web release (0.0-1.0)", 0.0, 1.0)
	CreateConVar("webswing_optimal_release", "1.0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Speed boost for perfect timing (1.0-1.5)", 1.0, 1.5)
	CreateConVar("webswing_chain_bonus", "1.0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Chain bonus for consecutive well-timed releases (1.0-1.3)", 1.0, 1.3)
	CreateConVar("webswing_midair_correction", "0.3", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Mid-air correction strength after release (0.0-0.5)", 0.0, 0.5)
	CreateConVar("webswing_slowmo_enabled", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable brief slow motion on perfect releases", 0, 1)

	-- Momentum Conversion System ConVars
	CreateConVar("webswing_momentum_conversion", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable momentum conversion system", 0, 1)
	CreateConVar("webswing_conversion_efficiency", "0.7", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Efficiency of momentum conversion (0.0-1.0)", 0, 1)
	CreateConVar("webswing_min_conversion_speed", "300", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Minimum speed for momentum conversion", 100, 500)
	CreateConVar("webswing_conversion_boost", "1.3", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Boost multiplier for perfect conversion timing", 1.0, 2.0)
	CreateConVar("webswing_conversion_direction", "0.6", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Directional influence on momentum conversion", 0.0, 1.0)

	-- Web of Shadows Physics System ConVars
	CreateConVar("webswing_use_wos_physics", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Use Web of Shadows style physics (recommended)", 0, 1)
	CreateConVar("webswing_wos_gravity", "620", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Base gravity value for Web of Shadows physics", 500, 800)
	CreateConVar("webswing_wos_momentum", "1.6", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Momentum preservation factor for Web of Shadows physics", 1.0, 2.0)
	CreateConVar("webswing_wos_arc_emphasis", "1.7", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Arc emphasis factor for Web of Shadows physics", 1.0, 2.0)
	CreateConVar("webswing_wos_fall_boost", "2.0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Fall-to-swing boost factor for Web of Shadows physics", 1.0, 2.5)
	CreateConVar("webswing_wos_swing_accel", "1.5", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Swing acceleration for Web of Shadows physics", 1.0, 2.0)
	CreateConVar("webswing_wos_apex_float", "0.3", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Apex float time for Web of Shadows physics", 0.1, 0.5)
	CreateConVar("webswing_wos_dive_accel", "1.8", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Dive acceleration for Web of Shadows physics", 1.0, 2.0)
	CreateConVar("webswing_wos_max_dive_speed", "1300", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Maximum dive speed for Web of Shadows physics", 800, 1500)
	CreateConVar("webswing_wos_centripetal", "1.5", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Centripetal force emphasis for Web of Shadows physics", 1.0, 2.0)
	CreateConVar("webswing_wos_tangential", "1.4", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Tangential force emphasis for Web of Shadows physics", 1.0, 2.0)
	CreateConVar("webswing_wos_inertia_comp", "0.6", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Inertia compensation for Web of Shadows physics", 0.5, 1.0)
	CreateConVar("webswing_wos_perfect_timing", "1.0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Perfect timing boost for Web of Shadows physics (disabled)", 1.0, 2.0)
	
	-- Web of Shadows Targeting System ConVars
	CreateConVar("webswing_wos_targeting", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enables Web of Shadows style targeting", 0, 1)
	CreateConVar("webswing_wos_targeting_intelligence", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enables intelligent mode for WoS targeting", 0, 1)
	CreateConVar("webswing_wos_height_adjustment", "200", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Base height adjustment for WoS targeting", 0, 500)
	CreateConVar("webswing_wos_anticipation", "0.7", FCVAR_ARCHIVE + FCVAR_REPLICATED, "How much to anticipate player's next move (0-1)", 0, 1)
	CreateConVar("webswing_show_ai_indicator", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Shows debug indicators for AI targeting decisions", 0, 1)
	CreateConVar("webswing_obstacle_debug", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Shows obstacle prediction debug information", 0, 1)

	-- Zip-to-Point ConVars
	CreateConVar("webswing_zip_max_range", "2000", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Maximum range for Zip-to-Point targeting.", 500, 5000)
	CreateConVar("webswing_zip_input_mode", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Input mode for Zip-to-Point. 0: Disabled, 1: IN_WALK + IN_ATTACK2, 2: IN_ZOOM + IN_ATTACK2.", 0, 2)
	CreateConVar("webswing_zip_speed", "2500", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Speed of the Zip-to-Point movement.", 1000, 5000)
	CreateConVar("webswing_zip_max_duration", "1.5", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Maximum duration of a Zip-to-Point.", 0.5, 3.0)
	CreateConVar("webswing_zip_arrival_behavior", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Behavior on arrival at zip point. 0: Simple Stop, 1: Launch if Jump held.", 0, 1)

	-- Air Control ConVars
	CreateConVar("webswing_air_strafe_force", "75", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Force applied for lateral air control during swings.", 0, 200)
	CreateConVar("webswing_air_influence_force", "50", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Force applied for forward/backward air influence during swings.", 0, 150)
	CreateConVar("webswing_rope_adjust_speed", "60", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Speed at which the web is shortened or slackened by player input.", 10, 200)

	-- Camera ConVars
	CreateConVar("webswing_camera_zip_fov_boost", "10", FCVAR_ARCHIVE + FCVAR_REPLICATED, "FOV boost applied during Zip-to-Point.", 0, 25)

	-- Glide Mechanic ConVars
	CreateConVar("webswing_glide_enable", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable simplified glide mechanic.", 0, 1)
	CreateConVar("webswing_glide_gravity_scale", "0.3", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Gravity scale during glide (0.1 = less gravity, 1.0 = normal).", 0.1, 1.0)
	CreateConVar("webswing_glide_forward_force", "150", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Forward force applied during glide.", 0, 500)
	CreateConVar("webswing_glide_steer_force", "75", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Steering force during glide.", 0, 200)
	CreateConVar("webswing_glide_min_start_speed", "200", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Minimum horizontal speed required to start gliding.", 0, 1000)
	CreateConVar("webswing_glide_activation_key", "IN_SPEED", FCVAR_ARCHIVE, "Key to hold for gliding (e.g., IN_SPEED, IN_WALK, IN_JUMP). This is a string ConVar for the key name.")

	-- Camera ConVars (Glide Specific)
	CreateConVar("webswing_camera_glide_fov_boost", "8", FCVAR_ARCHIVE + FCVAR_REPLICATED, "FOV boost applied during gliding.", 0, 20)
	CreateConVar("webswing_camera_glide_distance_mult", "1.1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Camera distance multiplier during gliding.", 0.8, 1.5)
else
	-- Client-side ConVars (if required)
	-- Currently, no client specific convars; add here if needed
end