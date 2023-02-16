print("cl_rdrm_deadeye.lua loaded")

local slowmotion_allowed = CreateConVar("cl_rdrm_deadeye_slowdown", "1", {FCVAR_ARCHIVE}, "Slow down the time when using deadeye.", 0, 1)
local draw_deadeye_icon = CreateConVar("cl_rdrm_deadeye_bar", "1", {FCVAR_ARCHIVE}, "Draw the deadeye charge bar", 0, 1)
local deadeye_icon_style = CreateConVar("cl_rdrm_deadeye_bar_mode", "1", {FCVAR_ARCHIVE}, "0 - bar, 1 - circular, like in the game", 0, 2)
local deadeye_icon_offset_x = CreateConVar("cl_rdrm_deadeye_bar_offset_x", "0", {FCVAR_ARCHIVE}, "X axis offset", -9999, 9999)
local deadeye_icon_offset_y = CreateConVar("cl_rdrm_deadeye_bar_offset_y", "0", {FCVAR_ARCHIVE}, "Y axis offset", -9999, 9999)
local deadeye_icon_scale = CreateConVar("cl_rdrm_deadeye_bar_size", "1", {FCVAR_ARCHIVE}, "Size multiplier", 0, 1000)
local infinite_mode = CreateConVar("cl_rdrm_deadeye_infinite", "0", {FCVAR_ARCHIVE}, "Make the thang infinite.", 0, 1)
local transfer_marks = CreateConVar("cl_rdrm_deadeye_transfer_to_ragdolls", "0", {FCVAR_ARCHIVE}, "Transfer the marks of an entity that just died to their ragdoll. Requires keep corpses enabled. Also might be a bit wonky at times...", 0, 1)
local debug_mode = CreateConVar("cl_rdrm_deadeye_debug", "0", {FCVAR_ARCHIVE}, "Debug!!!", 0, 1)
local max_deadeye_timer = CreateConVar("cl_rdrm_deadeye_timer", "10", {FCVAR_ARCHIVE}, "Timer, for you know what.", 0, 10000)
local deadeye_timer = max_deadeye_timer:GetFloat()

local deadeye_marks = {}
local current_mark = {}
local last_mark = {}

local already_started = false
local mark_added = false
local no_ammo_spent_timer = 0
local shooting_quota = 0
local release_attack = false

local start_angle = Angle()
local aim_lerp = 0

local toggle_timeout = false
local pitch_changing = false
local bg_sfx = NULL

local node_fx_lerp = 0
local inde_fx_lerp = 0
local distort_fx_lerp = 0

local function is_usable_for_deadeye(ent)
	if not IsValid(ent) or not ent.GetModel or not ent.GetClass then return false end
	if not ent:GetModel() or not ent:GetClass() then return false end 
	local is_explosive = string.find(ent:GetModel(), "explosive") or string.find(ent:GetModel(), "gascan") or string.find(ent:GetModel(), "propane_tank") or string.find(ent:GetClass(), "npc_grenade_frag")

	if not ent:IsNPC() and not is_explosive and not ent:IsPlayer() then return false end
	return true
end

local function get_hitbox_info(ent, hitboxid)
	local set_number, set_string = ent:GetHitboxSet()
	return ent:GetBonePosition(ent:GetHitBoxBone(hitboxid, set_number))
end

local function get_hitbox_matrix(ent, hitboxid)
	local set_number, set_string = ent:GetHitboxSet()
	return ent:GetBoneMatrix(ent:GetHitBoxBone(hitboxid, set_number))
end

local function toggle_deadeye()
	if max_deadeye_timer:GetFloat() <= 0 then return end
	if rdrm.in_killcam then return end
	if toggle_timeout then return end
	toggle_timeout = true
	timer.Simple(0.1, function() toggle_timeout = false end)

	local lp = LocalPlayer()
	if not rdrm.in_deadeye and (not lp:Alive() or not lp:GetActiveWeapon().Clip1 or lp:GetActiveWeapon():Clip1() == 0 or deadeye_timer < 1) then
		lp:EmitSound("deadeye_click")
		node_fx_lerp = 1
		return 
	end

	rdrm.in_deadeye = !rdrm.in_deadeye
	rdrm.change_state({state_type="in_deadeye", state=rdrm.in_deadeye, slowmotion=slowmotion_allowed:GetBool()})

	if rdrm.in_deadeye then
		lp:EmitSound("deadeye_start")
    	bg_sfx = CreateSound(lp, "rdrm/deadeye/background.wav")
    	bg_sfx:SetSoundLevel(0)
    	bg_sfx:Play()
    else
		if bg_sfx != NULL then bg_sfx:Stop() end
		lp:EmitSound("deadeye_end")
		timer.Simple(0.3, function() 
			for i, ent in ipairs(ents.GetAll()) do
				ent.rdrm_stop_render = nil
				ent.rdrm_force_render = nil
			end
		end)
	end

	current_mark = {}
	deadeye_marks = {}
	pitch_changing = false
	already_started = false
	shooting_quota = 0
	no_ammo_spent_timer = 0
	mark_added = false
	release_attack = false
end

local function create_mark() 
	if max_deadeye_timer:GetFloat() <= 0 then return end
	local lp = LocalPlayer()

	if not rdrm.in_deadeye then return end
	if lp:GetActiveWeapon():Clip1() <= table.Count(deadeye_marks) then return end

	local vtr = NULL

	local tr = util.TraceLine({
		start = lp:EyePos(),
		endpos = lp:EyePos() + lp:EyeAngles():Forward() * 10000,
		filter = lp,
		mask = MASK_SHOT_PORTAL
	})

	local tr_g = util.TraceHull({
		start = lp:EyePos(),
		endpos = lp:EyePos() + lp:EyeAngles():Forward() * 10000,
		filter = lp,
		mins = Vector(-10, -10, -10),
		maxs = Vector(10, 10, 10),
		mask = MASK_SHOT_PORTAL
	})

	if (tr.Entity == NULL or not IsValid(tr.Entity)) or not is_usable_for_deadeye(tr.Entity) then
		if (tr_g.Entity == NULL or not IsValid(tr_g.Entity)) or not is_usable_for_deadeye(tr_g.Entity) or not string.find(tr_g.Entity:GetClass(), "npc_grenade_frag") then return end
		vtr = tr_g
	else
		vtr = tr
	end

	if vtr == NULL or not vtr then 
		return 
	end

	local hitbox_matrix = get_hitbox_matrix(vtr.Entity, vtr.HitBox)
	local precision_multiplier = math.Remap(vtr.Fraction, 0, 1, 1, 10)
	vtr.HitPos = vtr.HitPos + (hitbox_matrix:GetTranslation() - vtr.HitPos):GetNormalized() * precision_multiplier + vtr.Normal * 2

	local data = {
		pos = hitbox_matrix:GetTranslation(),
		hitbox = vtr.HitBox,
		entity = vtr.Entity,
		entindex = vtr.Entity:EntIndex(),
		offset = hitbox_matrix:GetTranslation() - vtr.HitPos,
		order = table.Count(deadeye_marks) + 1,
		brightness = 255
	}
	
	if string.find(tr_g.Entity:GetClass(), "npc_grenade_frag") then 
		data.offset = Vector()
	end
	data.offset:Rotate(-tr.Entity:GetAngles())

	table.insert(deadeye_marks, data)

	lp:EmitSound("deadeye_mark")

	mark_added = true
end

concommand.Add("deadeye_mark", create_mark)
concommand.Add("deadeye_toggle", toggle_deadeye)

local function update_marks()
	for i, data in ipairs(deadeye_marks) do
		//mark.pos =get_hitbox_matrix(ent, data.hitbox_id)
		if not IsValid(data.entity) then
			table.remove(deadeye_marks, i) 
			continue
		end
		local hitbox_matrix = get_hitbox_matrix(data.entity, data.hitbox)
		local offset = Vector(data.offset:Unpack())

		if not hitbox_matrix then // invalid cuz not rendered
			local pos, _ = get_hitbox_info(data.entity, data.hitbox)
			offset:Rotate(-data.entity:GetAngles())
			data.pos = pos - offset
			continue
		end

		local pos = hitbox_matrix:GetTranslation()
		offset:Rotate(data.entity:GetAngles())
		data.pos = pos - offset
	end
end

hook.Add("rdrm_received_ragdoll_event", "rdrm_deadeye_ragdoll_event", function(owner, ragdoll)
	if max_deadeye_timer:GetFloat() <= 0 then return end
	if not transfer_marks:GetBool() then return end
	
	owner.rdrm_stop_render = true
	ragdoll.rdrm_force_render = true

	if not is_usable_for_deadeye(owner) then return end

	for i, data in ipairs(deadeye_marks) do
		if data.entindex == owner:EntIndex() then
			data.entity = ragdoll
			data.entindex = ragdoll:EntIndex()
		end
	end
end)

net.Receive("rdrm_deadeye_fire_bullet", function()
	if max_deadeye_timer:GetFloat() <= 0 then return end
	if not rdrm.in_deadeye then return end

	local lp = LocalPlayer()
	local weapon = lp:GetActiveWeapon()
	local delay = net.ReadFloat()

	release_attack = true
	timer.Simple(delay, function() 
		release_attack = false
	end)

	local tr = util.TraceHull({
		start = lp:EyePos(),
		endpos = lp:EyePos() + lp:EyeAngles():Forward() * 10000,
		filter = lp,
		mins = Vector(-10, -10, -10),
		maxs = Vector(10, 10, 10),
		mask = MASK_SHOT_PORTAL,
		ignoreworld = true // u can shoot a grenade through the wall and it'll explode kek
	})

	if tr.Entity and tr.Entity != NULL and tr.Entity:GetClass() == "npc_grenade_frag" then
		net.Start("rdrm_deadeye_request_grenade_explosion")
		net.WriteEntity(tr.Entity)
		net.SendToServer()
	end

	table.remove(deadeye_marks, 1)

	if shooting_quota > 0 then
		shooting_quota = table.Count(deadeye_marks)
	end

	start_angle = lp:EyeAngles()
	aim_lerp = 0
end)

hook.Add("CreateMove", "rdrm_deadeye_aim", function(cmd) 
	if max_deadeye_timer:GetFloat() <= 0 then return end
	local lp = LocalPlayer()

	if rdrm.in_deadeye then
		deadeye_timer = math.Clamp(deadeye_timer - RealFrameTime(), 0, max_deadeye_timer:GetFloat())
	else
		deadeye_timer = math.Clamp(deadeye_timer + RealFrameTime() / 3, 0, max_deadeye_timer:GetFloat())
	end

	if infinite_mode:GetBool() then
		deadeye_timer = max_deadeye_timer:GetFloat()
	end

	if rdrm.in_deadeye then
		if SetViewPunchAngles then
			SetViewPunchAngles(Angle(0,0,0))
		end

		if max_deadeye_timer:GetFloat() - deadeye_timer > max_deadeye_timer:GetFloat() * 0.8 and not pitch_changing then
			bg_sfx:ChangePitch(255, deadeye_timer)
			pitch_changing = true
		end

		if not lp:Alive() or lp:GetActiveWeapon() == NULL then
			toggle_deadeye()
		end

		update_marks()
		last_mark = current_mark
		current_mark = deadeye_marks[1]

		if lp:Alive() and lp:GetActiveWeapon() != NULL and (table.Count(deadeye_marks) >= lp:GetActiveWeapon():Clip1() or cmd:KeyDown(IN_ATTACK) or deadeye_timer <= 0) then
			shooting_quota = table.Count(deadeye_marks)
		end

		if (last_mark and current_mark) and last_mark.order != current_mark.order then
			start_angle = lp:EyeAngles()
			aim_lerp = 0
		end

		if table.Count(deadeye_marks) <= 0 then
			shooting_quota = 0
			if mark_added or deadeye_timer <= 0 then
				toggle_deadeye()
			end
		end

		if cmd:KeyDown(IN_ATTACK) and not mark_added then
			toggle_deadeye()
		end

		if lp:Alive() and lp:GetActiveWeapon() != NULL and (not lp:GetActiveWeapon().Clip1 or lp:GetActiveWeapon():Clip1() == 0) then
			toggle_deadeye()
		end

		if shooting_quota > 0 and table.Count(deadeye_marks) > 0 then
			cmd:AddKey(IN_ATTACK)
		end

		local currently_waiting = false
		if current_mark and IsValid(current_mark.entity) and (release_attack or (no_ammo_spent_timer >= 1 and shooting_quota > 0 and table.Count(deadeye_marks) > 0)) then
			cmd:RemoveKey(IN_ATTACK)
			timer.Simple(engine.TickInterval(), function() no_ammo_spent_timer = 0 end)
			currently_waiting = true
		elseif shooting_quota > 0 and table.Count(deadeye_marks) > 0 then
			no_ammo_spent_timer = math.Clamp(no_ammo_spent_timer + engine.TickInterval() / 5, 0, 1)
			currently_waiting = false
		end	

		if current_mark and IsValid(current_mark.entity) and (cmd:KeyDown(IN_ATTACK) or already_aiming) then
			local interval = math.Clamp(RealFrameTime(), 0, engine.TickInterval())
			local actual_shoot_position = lp:GetShootPos() + (lp:GetVelocity() - current_mark.entity:GetVelocity()) * interval
			local aimangles = (current_mark.pos - actual_shoot_position):Angle()
			
			aim_lerp = math.Clamp(aim_lerp + RealFrameTime() * 3 + 0.01, 0, 1)
			
			local lerped_angles = LerpAngle(math.ease.InOutCubic(aim_lerp), start_angle, aimangles)

			cmd:SetViewAngles(lerped_angles)
			
			if aim_lerp < 1 then
				cmd:RemoveKey(IN_ATTACK)
			elseif not currently_waiting then
				cmd:AddKey(IN_ATTACK)
			end
			
			already_aiming = true
		else
			start_angle = lp:EyeAngles()
			aim_lerp = 0
			already_aiming = false
		end
	end
end)

local deadeye_cross = Material("rdrm/deadeye/deadeye_cross")
local deadeye_core = Material("rdrm/deadeye/deadeye_core")
local deadeye_core_circle = Material("rdrm/deadeye/rpg_meter_track_9")
local highlight = Material("rdrm/deadeye/chams/highlight")

local cc_in_deadeye = {
	["$pp_colour_addr"] = 0.8,
	["$pp_colour_addg"] = 0.4,
	["$pp_colour_addb"] = 0.0,
	["$pp_colour_brightness"] = -0.45,
	["$pp_colour_contrast"] = 0.6,
	["$pp_colour_colour"] = 0.8,
}

local cc_no_deadeye = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
}

local cc_empty_deadeye = {
	["$pp_colour_addr"] = cc_in_deadeye["$pp_colour_addr"] * 0.5,
	["$pp_colour_addg"] = cc_in_deadeye["$pp_colour_addg"] * 0.5,
	["$pp_colour_addb"] = cc_in_deadeye["$pp_colour_addb"] * 0.5,
	["$pp_colour_brightness"] = cc_in_deadeye["$pp_colour_brightness"] * 0.5,
	["$pp_colour_contrast"] = cc_in_deadeye["$pp_colour_contrast"],
	["$pp_colour_colour"] = cc_in_deadeye["$pp_colour_colour"],
}

local function draw_circ_bar(x, y, w, h, progress, color)
	// https://gist.github.com/Joseph10112/6e6e896b5feee50f7aa2145aabaf6e8c
	// i love pasting xD

	if game.SinglePlayer() and infinite_mode:GetBool() then
		surface.SetDrawColor(color)
		surface.SetMaterial(deadeye_core_circle)
		surface.DrawTexturedRect(x, y, w, h)
		return	
	end

	local dummy = {}
	table.insert(dummy, {x = x + (w / 2), y = y + (h / 2)})
	for i = 180, -180 + progress * 360, -1 do
		table.insert(dummy, {x = x + (w / 2) + math.sin(math.rad(i)) * w, y = y + (h / 2) + math.cos(math.rad(i)) * h})
	end
	table.insert(dummy, {x = x + (w / 2), y = y + (h / 2)})
	
	render.SetStencilWriteMask(-1)
	render.SetStencilTestMask(-1)
	render.SetStencilReferenceValue(0)
	
	render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
	render.SetStencilPassOperation(STENCILOPERATION_KEEP)
	render.SetStencilFailOperation(STENCILOPERATION_KEEP)
	render.SetStencilZFailOperation(STENCILOPERATION_KEEP)
	render.ClearStencil()

	render.SetStencilEnable(true)
		render.SetStencilReferenceValue(1)
		render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
		
		surface.SetDrawColor(Color(255, 255, 255))
		surface.DrawPoly(dummy)
		render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)

		surface.SetDrawColor(color)
		surface.SetMaterial(deadeye_core_circle)
		surface.DrawTexturedRect(x, y, w, h)
		
	render.SetStencilEnable(false)
end

local function draw_marks()
	surface.SetMaterial(deadeye_cross)
	for i, data in ipairs(deadeye_marks) do
		local pos2d = data.pos:ToScreen()
		data.brightness = math.Clamp(data.brightness - RealFrameTime() * 1000, 0, 255)
		surface.SetDrawColor(255, data.brightness, data.brightness, 255)
		surface.DrawTexturedRect(pos2d.x-8, pos2d.y-8, 16, 16)
	end
end

local function draw_hud()
	if not draw_deadeye_icon:GetBool() then return end

	if deadeye_icon_style:GetInt() == 0 then
		surface.SetDrawColor(0, 0, 0, 128)
		surface.DrawRect(34+deadeye_icon_offset_x:GetFloat(), ScrH()-250-deadeye_icon_offset_y:GetFloat(), 150*deadeye_icon_scale:GetFloat(), 12*deadeye_icon_scale:GetFloat())

		if game.SinglePlayer() and infinite_mode:GetBool() then 
			surface.SetDrawColor(255, 190, 48, 128)
		else
			surface.SetDrawColor(255, 255, 255, 128)
		end

		surface.DrawRect(34+deadeye_icon_offset_x:GetFloat(), ScrH()-250-deadeye_icon_offset_y:GetFloat(), math.Remap(deadeye_timer, 0, max_deadeye_timer:GetFloat(), 0, 150)*deadeye_icon_scale:GetFloat(), 12*deadeye_icon_scale:GetFloat())
	else
		surface.SetMaterial(deadeye_core)
		if game.SinglePlayer() and infinite_mode:GetBool() then 
			surface.SetDrawColor(255, 190, 48, 255)
		else
			surface.SetDrawColor(255, 255, 255, 255)
		end
		surface.DrawTexturedRect(34+deadeye_icon_offset_x:GetFloat(), ScrH()-250-deadeye_icon_offset_y:GetFloat(), 42*deadeye_icon_scale:GetFloat(), 42*deadeye_icon_scale:GetFloat())
		
		local progress = math.Remap(deadeye_timer, 0, max_deadeye_timer:GetFloat(), 1, 0)

		if progress != 1 then
			local color
			if game.SinglePlayer() and infinite_mode:GetBool() then 
				color = Color(255, 190, 48, 255)
			else
				color = Color(255, 255, 255, 255)
			end

			draw_circ_bar(34-(5.5*deadeye_icon_scale:GetFloat())+deadeye_icon_offset_x:GetFloat(), ScrH()-250-(5.5*deadeye_icon_scale:GetFloat())-deadeye_icon_offset_y:GetFloat(), 53*deadeye_icon_scale:GetFloat(), 53*deadeye_icon_scale:GetFloat(), progress, color)
		end
	end
end

local function draw_chams()
	render.UpdateScreenEffectTexture()
	if inde_fx_lerp > 0 then
		local eased_lerp = math.ease.InOutSine(inde_fx_lerp)
		highlight:SetVector("$selfillumtint", Vector(eased_lerp/50, eased_lerp/50, eased_lerp/50))
		highlight:SetVector("$envmaptint", Vector(eased_lerp, eased_lerp, eased_lerp))
		
		cam.Start3D()
			for _, ent in ipairs(ents.GetAll()) do
				if not ent.rdrm_force_render and not is_usable_for_deadeye(ent) then continue end
				if ent.rdrm_stop_render then continue end
				render.MaterialOverride(highlight)
				render.SuppressEngineLighting(true)
				ent:DrawModel()
				render.SuppressEngineLighting(false)
				render.MaterialOverride(nil)
			end
		cam.End3D()
	end
end

hook.Add("HUDPaint", "rdrm_deadeye_hud", function() 
	if max_deadeye_timer:GetFloat() <= 0 then return end
	draw_hud()
	draw_marks()
end)

hook.Add("RenderScreenspaceEffects", "rdrm_deadeye_effects", function()
	if max_deadeye_timer:GetFloat() <= 0 then return end
	if rdrm.in_deadeye then
		inde_fx_lerp = math.Clamp(inde_fx_lerp + RealFrameTime() * 2.5, 0, 1)
		distort_fx_lerp = math.Remap(deadeye_timer, 0, max_deadeye_timer:GetFloat(), 1, 0)
	else
		rdrm.noggin = false
		inde_fx_lerp = math.Clamp(inde_fx_lerp - RealFrameTime() * 2.5, 0, 1)
		distort_fx_lerp = math.Clamp(distort_fx_lerp - RealFrameTime() * 2, 0, 1)
	end

	node_fx_lerp = math.Clamp(node_fx_lerp - RealFrameTime() * 3, 0, 1)

	if rdrm.in_killcam or rdrm.killcam_time > 0 then 
		inde_fx_lerp = 0 
		distort_fx_lerp = 0
		rdrm.noggin = true
		return
	end

	if inde_fx_lerp > 0 then
		draw_chams()
		rdrm.draw_screen_overlay(inde_fx_lerp, cc_no_deadeye, cc_in_deadeye)
		rdrm.draw_distortion(distort_fx_lerp)
	end

	if node_fx_lerp > 0 then
		rdrm.draw_screen_overlay(node_fx_lerp, cc_no_deadeye, cc_empty_deadeye)
		rdrm.draw_distortion(node_fx_lerp)
	end
end)
