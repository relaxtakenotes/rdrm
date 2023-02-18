print("cl_rdrm_death.lua loaded")

local allow_death_effect = CreateConVar("cl_rdrm_death_effect_enabled", "1", {FCVAR_ARCHIVE}, "Do that effect when dying.", 0, 1)
local allow_spawn_effect = CreateConVar("cl_rdrm_spawn_effect_enabled", "1", {FCVAR_ARCHIVE}, "Do that effect when dying.", 0, 1)
rdrm.in_deadstate = false
rdrm.spawning = false
local blackout_lerp = 0
local brightness_lerp = 0
local allow_blackout = false
local death_angle_offset = 1
local events = {}

net.Receive("rdrm_player_death", function()
    if not allow_death_effect:GetBool() then return end

    LocalPlayer():EmitSound("rdrm_death")

    rdrm.in_deadstate = true
    brightness_lerp = 1
    death_angle_offset = 0
    rdrm.change_state({state_type="in_deadstate", state=rdrm.in_deadstate, slowmotion=true})

    rdrm.create_event(events, 4, function()
        blackout_lerp = 1
        allow_blackout = true
    end)

    rdrm.create_event(events, 6, function() 
        rdrm.change_state({state_type="in_deadstate", state=false, slowmotion=true, smooth=true})
    end)
end)

net.Receive("rdrm_player_spawn", function()
    if allow_spawn_effect:GetBool() then
        rdrm.spawning = true
        brightness_lerp = 1
    end

    if not allow_death_effect:GetBool() then return end

    rdrm.in_deadstate = false
    allow_blackout = false
    rdrm.change_state({state_type="in_deadstate", state=false, slowmotion=true})
end)

local cc_default = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
}

local cc_in_deadstate = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = -1,
}

local cc_no_color = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 0,
}

local cc_bright = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 1,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 0.2,
}

hook.Add("HUDShouldDraw", "rdrm_death_effect_wipe", function() 
    if rdrm.in_deadstate then return false end
end)

hook.Add("RenderScreenspaceEffects", "rdrm_death_effect", function()
    rdrm.execute_events(events)
    if rdrm.spawning then
        brightness_lerp = math.Clamp(brightness_lerp - RealFrameTime() / 4, 0, 1)
    else
        brightness_lerp = math.Clamp(brightness_lerp - RealFrameTime() / 5, 0, 1)
    end
    blackout_lerp = math.Clamp(blackout_lerp - RealFrameTime() / 1.5, 0, 1)

    if rdrm.in_deadstate then
        rdrm.draw_vignette(brightness_lerp)
        rdrm.draw_vignette(1)

        DrawColorModify(cc_in_deadstate)
        DrawColorModify(cc_no_color)
        
        DrawBloom(0.5, 2 * brightness_lerp * 1.5, 16, 16, 2, 1, 1, 1, 1)
        local cc = table.Copy(cc_bright)
        cc["$pp_colour_brightness"] = Lerp(brightness_lerp, 0, cc["$pp_colour_brightness"])
        cc["$pp_colour_contrast"] = Lerp(brightness_lerp, 1, cc["$pp_colour_contrast"])
        DrawColorModify(cc)
        
        if allow_blackout then
            local cc_b = table.Copy(cc_default)
            cc_b["$pp_colour_brightness"] = Lerp(math.ease.InOutCubic(blackout_lerp), -2, cc_b["$pp_colour_brightness"])
            DrawColorModify(cc_b)
        end
    end

    if rdrm.spawning then
        DrawBloom(0.5, 2 * brightness_lerp * 1.5, 16, 16, 2, 1, 1, 1, 1)
        local cc = table.Copy(cc_bright)
        cc["$pp_colour_brightness"] = Lerp(math.ease.InCubic(brightness_lerp), 0, cc["$pp_colour_brightness"])
        cc["$pp_colour_contrast"] = Lerp(math.ease.InCubic(brightness_lerp), 1, cc["$pp_colour_contrast"])
        cc["$pp_colour_colour"] = Lerp(math.ease.InCubic(brightness_lerp), 1, cc["$pp_colour_colour"])
        DrawColorModify(cc)
        if brightness_lerp <= 0 then rdrm.spawning = false end
    end
end)

hook.Add("CalcView", "rdrm_death_effect_view", function(ply, pos, angles, fov) 
    if not rdrm.in_deadstate then return end

    death_angle_offset = math.Clamp(death_angle_offset + RealFrameTime() / 10, 0, 1)

    local angle_sway = Angle(
        math.sin(death_angle_offset * 2 + RealTime()) * 5,
        math.cos(death_angle_offset * 3 + RealTime()) * 5,
        0
    )

    local angle_offset = Angle(
        death_angle_offset * -30,
        death_angle_offset * 30,
        0
    )

    local view = {
        origin = pos,
        angles = angles + angle_sway + angle_offset,
        fov = fov,
        drawviewer = true
    }

    return view
end)