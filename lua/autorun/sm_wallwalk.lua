local WALL_WALK_ACTIVATION_DIST = 100
local WALL_WALK_GRAVITY = 0.1
local SURFACE_ALIGN_SPEED = 8
local WALK_SPEED_MULTIPLIER = 1.2

if SERVER then
    util.AddNetworkString("WallWalkState")
    
    local function UpdateWallWalk(ply)
        if not IsValid(ply) then return end
        
        local trace = util.TraceLine({
            start = ply:GetPos(),
            endpos = ply:GetPos() + ply:GetAimVector() * WALL_WALK_ACTIVATION_DIST,
            filter = ply
        })
        
        if ply:KeyDown(IN_JUMP) and trace.Hit and not ply:InVehicle() then
            if not ply.IsWallWalking then
                ply:SetGravity(WALL_WALK_GRAVITY)
                ply:SetVelocity(vector_origin)
                ply.IsWallWalking = true
                net.Start("WallWalkState")
                    net.WriteBool(true)
                net.Send(ply)
            end
            
            local move_ang = (trace.HitNormal * -1):Angle()
            move_ang:RotateAroundAxis(move_ang:Right(), -90)
            
            ply:SetEyeAngles(LerpAngle(FrameTime() * SURFACE_ALIGN_SPEED, ply:EyeAngles(), move_ang))
            
            local forward = ply:EyeAngles():Forward()
            local right = ply:EyeAngles():Right()
            local move = ply:GetMoveVector()
            
            ply:SetVelocity(forward * move.x * 250 + right * move.y * 250)
        elseif ply.IsWallWalking then
            ply:SetGravity(1)
            ply.IsWallWalking = false
            net.Start("WallWalkState")
                net.WriteBool(false)
            net.Send(ply)
        end
    end
    
    hook.Add("Move", "WallWalkMovement", function(ply, mv)
        if ply.IsWallWalking then
            mv:SetMaxSpeed(0)
            mv:SetMaxClientSpeed(0)
            return true
        end
    end)
    
    hook.Add("KeyPress", "WallWalkJumpReset", function(ply, key)
        if key == IN_JUMP and ply.IsWallWalking then
            ply:SetGravity(1)
            ply.IsWallWalking = false
            net.Start("WallWalkState")
                net.WriteBool(false)
            net.Send(ply)
        end
    end)

-- Client-side effects and sync
if CLIENT then
    net.Receive("WallWalkState", function()
        is_wall_walking = net.ReadBool()
        if is_wall_walking then
            LocalPlayer():EmitSound("webshooters/web_shoot1.wav")
        else
            LocalPlayer():EmitSound("webshooters/web_detach1.wav")
        end
    end)

    hook.Add("CalcView", "WallWalkView", function(ply, pos, ang, fov)
        if is_wall_walking then
            local view = {}
            view.origin = pos - ang:Up() * 15
            view.angles = ang
            view.fov = fov * 0.9
            return view
        end
    end)
end