print("cl_rdrm_lowhp.lua loaded")

local min_hp = CreateConVar("cl_rdrm_low_hp_trigger", "30", {FCVAR_ARCHIVE}, "-1 to disable")
local sway = CreateConVar("cl_rdrm_low_hp_sway", "1", {FCVAR_ARCHIVE}, "Allow view sway at low hp")
local sway_mult = CreateConVar("cl_rdrm_low_hp_sway_mult", "1.5", {FCVAR_ARCHIVE}, "Sway multiplier")

local cc_low_hp = {
	["$pp_colour_addr"] = 0.713,
	["$pp_colour_addg"] = 0.174,
	["$pp_colour_addb"] = 0.713,
	["$pp_colour_brightness"] = -0.8,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 0.5,
}

local cc_normal_hp = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
}

local fx_intensity = 0
local wish_intensity = 0
local sway_angle_delta = Angle()
local sway_angle_first = Angle()
local sway_angle_last = Angle()

hook.Add("CreateMove", "rdrm_low_hp_sway", function(cmd) 
    if fx_intensity > 0 and sway:GetBool() then
        cmd:SetViewAngles(cmd:GetViewAngles() + sway_angle_delta * fx_intensity * sway_mult:GetFloat())
    end
end)

hook.Add("RenderScreenspaceEffects", "rdrm_low_hp_effects", function() 
    local lp = LocalPlayer()

    if lp:Health() <= min_hp:GetFloat() then
        wish_intensity = math.Remap(lp:Health(), 0, min_hp:GetFloat(), 1, 0)
    else
        wish_intensity = 0
    end

    fx_intensity = math.Clamp(math.Approach(fx_intensity, wish_intensity, math.abs(fx_intensity - wish_intensity) * RealFrameTime() * 2 + 0.001), 0, 1)

    if fx_intensity > 0 then
        local variable_stuff = math.sin((fx_intensity + CurTime()) * 2)
        variable_stuff = math.Remap(variable_stuff, -1, 1, fx_intensity/2, fx_intensity)
        sway_angle_last = sway_angle_first
        sway_angle_first = Angle(
            math.cos((fx_intensity + RealTime()) * 2) * 0.5,
            math.sin((fx_intensity + RealTime()) / 2) * 1.25,
            0
        )
        sway_angle_delta = sway_angle_first - sway_angle_last

        local cc = {
            ["$pp_colour_addr"] = Lerp(variable_stuff, cc_normal_hp["$pp_colour_addr"], cc_low_hp["$pp_colour_addr"]),
            ["$pp_colour_addg"] = Lerp(variable_stuff, cc_normal_hp["$pp_colour_addg"], cc_low_hp["$pp_colour_addg"]),
            ["$pp_colour_addb"] = Lerp(variable_stuff, cc_normal_hp["$pp_colour_addb"], cc_low_hp["$pp_colour_addb"]),
            ["$pp_colour_brightness"] = Lerp(variable_stuff, cc_normal_hp["$pp_colour_brightness"], cc_low_hp["$pp_colour_brightness"]),
            ["$pp_colour_contrast"] = Lerp(variable_stuff, cc_normal_hp["$pp_colour_contrast"], cc_low_hp["$pp_colour_contrast"]),
            ["$pp_colour_colour"] = Lerp(variable_stuff, cc_normal_hp["$pp_colour_colour"], cc_low_hp["$pp_colour_colour"]),
        }

        DrawColorModify(cc)

        // that's the part that eats up a shitton of fps
        // sadly if i remove even one function it'll look way off from what i want so gotta cope i guess
        rdrm.draw_vignette(variable_stuff)
        rdrm.draw_vignette(fx_intensity)
        rdrm.draw_vignette(fx_intensity * 2)
        rdrm.draw_refraction(variable_stuff)
        rdrm.draw_refraction(fx_intensity)
        rdrm.chromatic_abberation(math.Remap(fx_intensity, 0, 1, 0.3, 1.25))
    end
end)