print("cl_rdrm_killcam.lua loaded")

rdrm.killcam_time = 0 // we need it even if we're in mp\
rdrm.killcam_willswitch = false
rdrm.switch_to_local = false

if not game.SinglePlayer() then return end

local chance = CreateConVar("cl_rdrm_killcam_chance", "0.35", {FCVAR_ARCHIVE}, "Normalized chance of the killcam starting to play.", 0, 10000)
local filter = CreateConVar("cl_rdrm_killcam_filter", "1", {FCVAR_ARCHIVE}, "Allow FX to work.", 0, 1)
local length_mult = CreateConVar("cl_rdrm_killcam_length", "1", {FCVAR_ARCHIVE}, "Length Multiplier.", 0, 5)

local desired_angle = Angle()
local desired_pos = Vector()
local current_ent = NULL
local switched = false
local sent = false
local past_breaking_point = false
local past_ten = false

local events = {}

local function is_usable_for_killcam(ent)
	if not IsValid(ent) or not ent.GetModel or not ent.GetClass then return false end
	if not ent:GetModel() or not ent:GetClass() then return false end 
	if not ent:IsNPC() and not ent:IsPlayer() then return false end

	return true
end

local function set_random_angle(ent, is_flashcut)
	if not IsValid(ent) then print("[RDRM] Unable to set a random angle cause the entity is invalid. Notify the dev about it on github. Please give context!") return false end

	local pos = ent:GetPos()

	if not ent:IsRagdoll() then pos.z = pos.z + ent:BoundingRadius() * 4/3 end

	local offset = ent:GetAngles():Forward()
	local valid_offset = false
	local mult = 1
	local iter = 0
	while not valid_offset do
		iter = iter + 1

		offset = ent:GetAngles():Forward()
		if not is_flashcut then
			local rand = AngleRand()
			rand.z = 0
			offset:Rotate(rand)
		end
		if not ent:IsRagdoll() then offset.z = offset.z * 0.5 end

		offset = offset * 100 * mult

		local tr_f = util.TraceHull({
			start = pos,
			endpos = pos + offset,
			mins = Vector(-5, -5, -5),
			maxs = Vector(5, 5, 5),
			mask = MASK_VISIBLE
		})

		local tr_t = util.TraceHull({
			start = pos + offset,
			endpos = pos,
			mins = Vector(-5, -5, -5),
			maxs = Vector(5, 5, 5),
			mask = MASK_VISIBLE
		})

		if iter > 20 then
			if tr_f.StartSolid or tr_t.StartSolid then offset:Rotate(-offset:Angle()) end
			break
		end

		if (pos+offset):Distance(pos) < 100 then
			mult = mult + 0.1
			continue
		end

		if not (tr_f.HitPos:IsEqualTol(pos + offset, 10) and tr_t.HitPos:IsEqualTol(pos, 10)) then
			continue
		end

		valid_offset = true
	end

	desired_pos = pos + offset
	desired_angle = (pos - desired_pos):Angle()

	return true
end

local function rdrm_killcam_apply(ent, ragdoll)
	if not is_usable_for_killcam(ent) then return end
	if math.Rand(0, 1) > chance:GetFloat() then return end
	if rdrm.killcam_time > 0 then return end

	LocalPlayer():EmitSound("killcam_bloodsplatter")

	sent = false
	switched = false
	current_ent = ragdoll

	local weapon = LocalPlayer():GetActiveWeapon()
	local is_flashcut = IsValid(weapon) and weapon:GetClass() == "weapon_flashcut2" and LocalPlayer():GetVelocity():Length() <= 0

	if is_flashcut then
		if not set_random_angle(ent, is_flashcut) then return end
	else
		if not set_random_angle(current_ent, is_flashcut) then return end
	end
	
	rdrm.killcam_time = 1

	rdrm.killcam_willswitch = math.Rand(0, 1) > 0.35
	rdrm.switch_to_local = math.Rand(0, 1) > 0.6

	if rdrm.killcam_willswitch then
		rdrm.create_event(events, 2.5 * length_mult:GetFloat(), function()
			if rdrm.switch_to_local or is_flashcut then
				set_random_angle(LocalPlayer(), is_flashcut)
			else
				set_random_angle(current_ent, is_flashcut)
			end
		end)

		rdrm.create_event(events, 4.6 * length_mult:GetFloat(), function()
			rdrm.in_killcam = false
			rdrm.change_state({state_type="in_killcam", state=rdrm.in_killcam, smooth=true, slowmotion=true})			
		end)
	else
		rdrm.create_event(events, 2.6 * length_mult:GetFloat(), function()
			rdrm.in_killcam = false
			rdrm.change_state({state_type="in_killcam", state=rdrm.in_killcam, smooth=true, slowmotion=true})			
		end)

		rdrm.create_event(events, 2.4 * length_mult:GetFloat(), function() 
			rdrm.killcam_time = 0.15 * length_mult:GetFloat()
		end)
	end

	rdrm.in_killcam = true
	rdrm.change_state({state_type="in_killcam", state=rdrm.in_killcam, slowmotion=true})
end

hook.Add("CalcView", "rdrm_killcam_view", function(ply, pos, angles, fov)
	if rdrm.killcam_time <= 0 then return end

	local view = {
		origin = desired_pos,
		angles = desired_angle,
		fov = 40,
		drawviewer = true
	}

	return view
end)

hook.Add("Think", "rdrm_killcam_think", function()
	rdrm.execute_events(events)

	rdrm.killcam_time = math.Clamp(rdrm.killcam_time - RealFrameTime() / 5 / length_mult:GetFloat(), 0, 1)
end)

hook.Add("HUDShouldDraw", "rdrm_killcam_hide_hud", function(element) 
	if rdrm.killcam_time > 0 then return false end
end)

table.insert(rdrm.hooks["ragdoll_event"], function(owner, ragdoll) 
	rdrm_killcam_apply(owner, ragdoll)
end)

local pp_in_killcam = {
	["$pp_colour_addr"] = 0.5,
	["$pp_colour_addg"] = 0.5,
	["$pp_colour_addb"] = 0.7,
	["$pp_colour_brightness"] = -0.36,
	["$pp_colour_contrast"] = 0.7,
	["$pp_colour_colour"] = 0.1,
}

local pp_out_killcam = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
}

local vignettemat = Material("rdrm/screen_overlay/vignette01")
local pp_lerp = 0
local pp_fraction = 0.1
local need_to_fade = false
local fade_lerp = 0

hook.Add("RenderScreenspaceEffects", "zzzxczxc_rdrm_killcam_overlay", function()
	if not filter:GetBool() then return end

	if rdrm.killcam_time > 0 then
		need_to_fade = true

		local tab = table.Copy(pp_in_killcam)
		tab["$pp_colour_brightness"] = Lerp(pp_lerp, 0, pp_in_killcam["$pp_colour_brightness"])
		
		pp_lerp = math.Clamp(pp_lerp + pp_fraction * RealFrameTime() * 7, 0, 1)
		
		DrawColorModify(tab)
		vignettemat:SetFloat("$alpha", 1)
		render.SetMaterial(vignettemat)
		render.DrawScreenQuad()

		render.UpdateScreenEffectTexture()
	else
		pp_lerp = 0
	end

	if rdrm.killcam_time <= 0 and need_to_fade then
		local tab = table.Copy(pp_out_killcam)
		fade_lerp = math.Clamp(fade_lerp + RealFrameTime() * 3.5, 0, 1)
		tab["$pp_colour_brightness"] = Lerp(fade_lerp, -1, pp_out_killcam["$pp_colour_brightness"])
		DrawColorModify(tab)
		if fade_lerp == 1 then fade_lerp = 0 need_to_fade = false end
	end
end)