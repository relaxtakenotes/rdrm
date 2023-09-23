print("cl_rdrm.lua loaded")

rdrm.in_deadeye = false
rdrm.in_killcam = false
rdrm.noggin = false // used for some color correction stuff
rdrm.hooks = {}
rdrm.hooks["ragdoll_event"] = {}

sound.Add({
	name = "rdrm_death",
	channel = CHAN_STATIC,
	volume = 1,
	level = 0,
	pitch = 100,
	sound = {"rdrm/misc/rdrm_death.wav"} 
})

sound.Add({
	name = "deadeye_start",
	channel = CHAN_STATIC,
	volume = 1.0,
	level = 0,
	pitch = {95,105},
	sound = {"rdrm/deadeye/start1.wav", "rdrm/deadeye/start2.wav"} 
})

sound.Add({
	name = "deadeye_mark",
	channel = CHAN_STATIC,
	volume = 1.0,
	level = 0,
	pitch = {95,105},
	sound = "rdrm/deadeye/mark.wav"
})

sound.Add({
	name = "deadeye_click",
	channel = CHAN_STATIC,
	volume = 0.5,
	level = 0,
	pitch = {98,102},
	sound = "rdrm/deadeye/click.wav"
})

sound.Add({
	name = "deadeye_end",
	channel = CHAN_STATIC,
	volume = 1.0,
	level = 0,
	pitch = {95,105},
	sound = "rdrm/deadeye/end.wav"
})

sound.Add({
	name = "killcam_end",
	channel = CHAN_STATIC,
	volume = 1.0,
	level = 0,
	pitch = {95,105},
	sound = "rdrm/killcam/killcam_end.wav"
})

sound.Add({
	name = "killcam_bloodsplatter",
	channel = CHAN_STATIC,
	volume = 0.6,
	level = 0,
	pitch = {95,105},
	sound = "rdrm/killcam/bloodsplatter.wav"
})

concommand.Add("cl_rdrm_default", function() 
	GetConVar("cl_rdrm_deadeye_slowdown"):Revert()
	GetConVar("cl_rdrm_deadeye_bar_mode"):Revert()
	GetConVar("cl_rdrm_deadeye_bar_offset_x"):Revert()
	GetConVar("cl_rdrm_deadeye_bar_offset_y"):Revert()
	GetConVar("cl_rdrm_deadeye_bar_size"):Revert()
	GetConVar("cl_rdrm_deadeye_infinite"):Revert()
	GetConVar("cl_rdrm_deadeye_transfer_to_ragdolls"):Revert()
	GetConVar("cl_rdrm_deadeye_debug"):Revert()
	GetConVar("cl_rdrm_deadeye_timer"):Revert()
	GetConVar("cl_rdrm_deadeye_refill_multiplier"):Revert()

	GetConVar("cl_rdrm_death_effect_enabled"):Revert()
	GetConVar("cl_rdrm_spawn_effect_enabled"):Revert()

	GetConVar("cl_rdrm_killcam_chance"):Revert()
	GetConVar("cl_rdrm_killcam_filter"):Revert()
	GetConVar("cl_rdrm_killcam_length"):Revert()

	GetConVar("cl_rdrm_low_hp_trigger"):Revert()
	GetConVar("cl_rdrm_low_hp_sway"):Revert()
	GetConVar("cl_rdrm_low_hp_sway_mult"):Revert()
end)

net.Receive("rdrm_ragdoll_spawned", function()
	local owner = net.ReadEntity()
	local ragdoll = net.ReadEntity()

	for i, func in ipairs(rdrm.hooks["ragdoll_event"]) do
		func(owner, ragdoll)
	end
end)

function rdrm.change_state(data)
	net.Start("rdrm_request_change_state")
	net.WriteString(data.state_type)
	net.WriteBool(data.state)
	net.WriteBool(data.smooth or false)
	if data.slowmotion == nil then
		net.WriteBool(false)
	else
		net.WriteBool(data.slowmotion)
	end
	net.SendToServer()
end

local vignettemat = Material("rdrm/screen_overlay/vignette01")
local distortmat = Material("rdrm/screen_overlay/distort")
local ca_r = Material("rdrm/deadeye/chromatic_abberation/ca_r")
local ca_g = Material("rdrm/deadeye/chromatic_abberation/ca_g")
local ca_b = Material("rdrm/deadeye/chromatic_abberation/ca_b")
local black = Material("vgui/black")

function rdrm.draw_refraction(t)
	render.UpdateScreenEffectTexture()
	render.SetMaterial(distortmat)
	distortmat:SetFloat("$refractamount", math.Remap(math.ease.InQuart(t), 0, 1, 0, 0.15))
	render.DrawScreenQuad()
end

function rdrm.chromatic_abberation(t)
	local mult = math.ease.InQuart(t) * 2
	
	render.UpdateScreenEffectTexture()
	render.SetMaterial(black)
	render.DrawScreenQuad()
	render.SetMaterial(ca_r)
	render.DrawScreenQuadEx(-8 * mult, -4 * mult, ScrW() + 16 * mult, ScrH() + 8 * mult)
	render.SetMaterial(ca_g)
	render.DrawScreenQuadEx(-4 * mult, -2 * mult, ScrW() + 8 * mult, ScrH() + 4 * mult)
	render.SetMaterial(ca_b)
	render.DrawScreenQuad()		
end

function rdrm.draw_vignette(t)
	render.UpdateScreenEffectTexture()
	vignettemat:SetFloat("$alpha", t)
	render.SetMaterial(vignettemat)
	render.DrawScreenQuad()
end

function rdrm.draw_screen_overlay(t, cc_no, cc_in)
	render.UpdateScreenEffectTexture()

	local cc = {
		["$pp_colour_addr"] = Lerp(t, cc_no["$pp_colour_addr"], cc_in["$pp_colour_addr"]),
		["$pp_colour_addg"] = Lerp(t, cc_no["$pp_colour_addg"], cc_in["$pp_colour_addg"]),
		["$pp_colour_addb"] = Lerp(t, cc_no["$pp_colour_addb"], cc_in["$pp_colour_addb"]),
		["$pp_colour_brightness"] = Lerp(t, cc_no["$pp_colour_brightness"], cc_in["$pp_colour_brightness"]),
		["$pp_colour_contrast"] = Lerp(t, cc_no["$pp_colour_contrast"], cc_in["$pp_colour_contrast"]),
		["$pp_colour_colour"] = Lerp(t, cc_no["$pp_colour_colour"], cc_in["$pp_colour_colour"]),
	}

	if rdrm.in_deadeye and not rdrm.noggin then
		cc["$pp_colour_brightness"] = Lerp(t, 0.8, cc_in["$pp_colour_brightness"])
		if t == 1 then rdrm.noggin = false end
	end

	DrawColorModify(cc)

	rdrm.draw_vignette(t)
end

function rdrm.draw_distortion(t)
	rdrm.draw_refraction(t)
	rdrm.chromatic_abberation(t)
end

function rdrm.create_event(event_table, in_time_from_now, event_function)
	table.insert(event_table, {func=event_function, tickcount=engine.TickCount(), offset=math.floor(in_time_from_now / engine.TickInterval())})
end

function rdrm.execute_events(event_table)
	for i, event in ipairs(event_table) do
		if engine.TickCount() >= event.tickcount + event.offset * game.GetTimeScale() then
			event.func()
			table.remove(event_table, i)
		end
	end
end