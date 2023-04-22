print("sv_rdrm.lua loaded")

rdrm.in_deadeye = {}
rdrm.in_deadeye_last = {}
rdrm.in_killcam = false
rdrm.in_killcam_last = false
rdrm.in_deadstate = false
rdrm.in_deadstate_last = false

rdrm.timescale = 1

local timescale_lerp = 1

util.AddNetworkString("rdrm_ragdoll_spawned") // to client
util.AddNetworkString("rdrm_request_change_state") // from client
util.AddNetworkString("rdrm_player_death") // to client
util.AddNetworkString("rdrm_player_spawn") // to client

hook.Add("CreateEntityRagdoll", "rdrm_broadcast_ragdolls", function(owner, ent)
	if not owner.rdrm_was_attacked then return end // we only need this to determine if we killed someone
	net.Start("rdrm_ragdoll_spawned")
		net.WriteEntity(owner)
		net.WriteEntity(ent)
	net.Send(owner.rdrm_attacker)
end)

hook.Add("PlayerDeath", "rdrm_player_death", function(victim, inflictor, attacker) 
	net.Start("rdrm_player_death")
	net.Send(victim)
end)

hook.Add("PlayerSpawn", "rdrm_player_spawn", function(ply, transition ) 
	net.Start("rdrm_player_spawn")
	net.Send(ply)
end)

if game.SinglePlayer() then
	hook.Add("Think", "rdrm_lerp_time_scale", function() 
		if timescale_lerp == 1 then
			game.SetTimeScale(1)
			return 
		end
		
		game.SetTimeScale(Lerp(timescale_lerp, 0.1, 1))

		timescale_lerp = math.Clamp(timescale_lerp + engine.TickInterval() * 5, 0, 1)
		rdrm.timescale = timescale_lerp
	end)
end

local function save_state(ply, typee, state)
	if typee == "in_deadeye" then
		if rdrm.in_deadeye[ply] != nil then rdrm.in_deadeye_last[ply] = rdrm.in_deadeye[ply] else rdrm.in_deadeye_last[ply] = false end
		rdrm.in_deadeye[ply] = state
	end

	if typee == "in_killcam" then
		rdrm.in_killcam_last = rdrm.in_killcam
		rdrm.in_killcam = state
	end

	if typee == "in_deadstate" then
		rdrm.in_deadstate_last = rdrm.in_deadstate
		rdrm.in_deadstate = state
	end
end

local function state_updated(typee, ply)
	if typee == "in_deadeye" then
		if rdrm.in_deadeye[ply] != rdrm.in_deadeye_last[ply] then return rdrm.in_deadeye[ply] end
	end

	if typee == "in_killcam" then
		if rdrm.in_killcam != rdrm.in_killcam_last then return rdrm.in_killcam end
	end

	if typee == "in_deadstate" then
		if rdrm.in_deadstate != rdrm.in_deadstate_last then return rdrm.in_deadstate end
	end

	return NULL
end

local function process_states(ply, smooth, slowdown)
	local timescale = 1

	if state_updated("in_deadeye", ply) == true and slowdown then
		timescale = 0.2
	end

	if state_updated("in_killcam") == true and slowdown then
		timescale = 0.1
	end

	if state_updated("in_killcam") == false and smooth and not rdrm.in_deadeye[ply] then
		timescale_lerp = 0
	end

	if state_updated("in_deadstate") == true and slowdown then
		timescale = 0.1
	end

	if state_updated("in_deadstate") == false and smooth and not rdrm.in_deadeye[ply] then
		timescale_lerp = 0
	end

	rdrm.timescale = timescale
	game.SetTimeScale(timescale)
end

net.Receive("rdrm_request_change_state", function(len, ply)
	local state_type = net.ReadString()
	local state = net.ReadBool()
	local smooth_ending = net.ReadBool()
	local slowdown = net.ReadBool()

	save_state(ply, state_type, state)

	if rdrm.in_deadeye[ply] then
		rdrm.deadeye_handle_ammo(ply)
	end

	if game.SinglePlayer() then
		process_states(ply, smooth_ending, slowdown)
	end
end)

if game.SinglePlayer() then
	hook.Add("EntityTakeDamage", "rdrm_detect_damage", function(ent, dmg)
		if ent:IsNPC() and dmg:GetAttacker():IsPlayer() then
			ent.rdrm_was_attacked = true
			ent.rdrm_attacker = dmg:GetAttacker()
			timer.Simple(0.1, function() 
				if IsValid(ent) then ent.rdrm_was_attacked = false end
			end)
		end
	end)
end