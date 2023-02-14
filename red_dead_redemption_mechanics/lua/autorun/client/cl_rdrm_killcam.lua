print("cl_rdrm_killcam.lua loaded")

if not game.SinglePlayer() then return end

local chance = CreateConVar("cl_rdrm_killcam_chance", "0.35", {FCVAR_ARCHIVE}, "Normalized chance of the killcam starting to play.", 0, 10000)

local killcam_time = 0
local desired_angle = Angle()
local desired_pos = Vector()
local current_ent = NULL
local switched = false
local sent = false
local sm_lerp = 0
local sm_sent = true

local function is_usable_for_killcam(ent)
	if not IsValid(ent) or not ent.GetModel or not ent.GetClass then return false end
	if not ent:GetModel() or not ent:GetClass() then return false end 
	if not ent:IsNPC() and not ent:IsPlayer() then return false end

	return true
end

local function set_random_angle(ent)
	local pos = ent:GetPos()
	if not ent:IsRagdoll() then pos.z = pos.z + 52 end

	local offset = ent:GetAngles():Forward()
	local valid_offset = false
	local mult = 1
	local iter = 0
	while not valid_offset do
		iter = iter + 1

		offset = ent:GetAngles():Forward()
		offset:Rotate(Angle(math.Rand(-1.5, 1.5), math.Rand(-1.5, 1.5), 0) * 45)
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
end

local function rdrm_killcam_apply(ent, ragdoll)
	if not is_usable_for_killcam(ent) then return end
	if math.Rand(0, 1) > chance:GetFloat() then return end

	sent = false
	switched = false
	current_ent = ragdoll
	set_random_angle(ent)
	killcam_time = 1
	past_breaking_point = false

	rdrm.in_killcam = true
	rdrm.change_state({state_type="in_killcam", state=rdrm.in_killcam})
end

hook.Add("CalcView", "rdrm_killcam_view", function(ply, pos, angles, fov)
	if killcam_time <= 0 then return end

	local view = {
		origin = desired_pos,
		angles = desired_angle,
		fov = 40,
		drawviewer = true
	}

	return view
end)


local past_breaking_point = false
hook.Add("Think", "rdrm_killcam_think", function()
	if killcam_time == 0 and not sent then
		switched = false
		sent = true
		past_breaking_point = false
	end

	if killcam_time == 0 then return end

	if killcam_time <= 0.5 and not switched then
		local will_switch = math.Rand(0, 1) > 0.35
		local switch_to_local = math.Rand(0, 1) > 0.6

		if will_switch then
			if switch_to_local then
				set_random_angle(LocalPlayer())
			else
				set_random_angle(current_ent)
			end
		else
			killcam_time = 0.15
		end
		switched = true
	end

	if killcam_time <= 0.15 and not past_breaking_point then
        rdrm.in_killcam = false
		rdrm.change_state({state_type="in_killcam", state=rdrm.in_killcam, smooth=true})
		past_breaking_point = true
	end

	killcam_time = math.Clamp(killcam_time - RealFrameTime() / 5, 0, 1)
end)

hook.Add("HUDShouldDraw", "rdrm_killcam_hide_hud", function(element) 
	if killcam_time > 0 then return false end
end)


hook.Add("rdrm_received_ragdoll_event", "rdrm_killcam_ragdoll_event", function(owner, ragdoll)
	rdrm_killcam_apply(owner, ragdoll)
end)

local pp_in_killcam = {
	["$pp_colour_addr"] = 1,
	["$pp_colour_addg"] = 0.6,
	["$pp_colour_addb"] = 0.7,
	["$pp_colour_brightness"] = -0.6,
	["$pp_colour_contrast"] = 0.8,
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

hook.Add("RenderScreenspaceEffects", "zzzxczxc_rdrm_killcam_overlay", function()
	if killcam_time > 0 then
		local tab = {
			["$pp_colour_brightness"] = Lerp(pp_lerp, 0, pp_in_killcam["$pp_colour_brightness"])
		}

		pp_lerp = math.Clamp(pp_lerp + pp_fraction * RealFrameTime() * 7, 0, 1)

		DrawColorModify(tab)
		DrawColorModify(pp_in_killcam)
		vignettemat:SetFloat("$alpha", 1)
		render.SetMaterial(vignettemat)
		render.DrawScreenQuad()
	else
		pp_lerp = 0
	end
end)