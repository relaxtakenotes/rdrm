print("sv_rdrm.lua loaded")

rdrm.in_deadeye = {}
rdrm.in_killcam = false
rdrm.timescale = 1

local timescale_lerp = 1

util.AddNetworkString("rdrm_ragdoll_spawned") // to client
util.AddNetworkString("rdrm_request_change_state") // from client
util.AddNetworkString("rdrm_player_death") // from client

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

if game.SinglePlayer() then
	hook.Add("Think", "rdrm_lerp_time_scale", function() 
		if timescale_lerp == 1 then return end
		
		game.SetTimeScale(Lerp(timescale_lerp, 0.1, 1))

		timescale_lerp = math.Clamp(timescale_lerp + engine.TickInterval() * 5, 0, 1)
		rdrm.timescale = timescale_lerp
	end)
end

net.Receive("rdrm_request_change_state", function(len, ply)
	local state_type = net.ReadString()
	local state = net.ReadBool()
	local smooth_ending = net.ReadBool()
	local slowdown = net.ReadBool()

	if state_type == "in_deadeye" then
		rdrm.in_deadeye[ply] = state
	end

	if rdrm.in_deadeye[ply] then
		rdrm.deadeye_handle_ammo(ply)
	end

	if game.SinglePlayer() then
		local timescale = 1

		if state_type == "in_killcam" then
			rdrm.in_killcam = state
		end

		if state_type == "in_deadeye" then
			rdrm.deadeye_handle_accuracy(ply, state)
		end

		if rdrm.in_deadeye[ply] and slowdown then
			timescale = 0.2
		else
			timescale = 1
		end

		if rdrm.in_killcam and slowdown then
			timescale = 0.1
		end

		if not rdrm.in_killcam and not smooth_ending and not rdrm.in_deadeye[ply] then
			timescale = 1
		end

		if not rdrm.in_killcam and smooth_ending and not rdrm.in_deadeye[ply] and slowdown then
			timescale_lerp = 0
		end

		if timescale_lerp == 1 and slowdown then
			rdrm.timescale = timescale
			game.SetTimeScale(timescale)
		end

		if timescale_lerp == 1 and not slowdown then
			rdrm.timescale = 1
			game.SetTimeScale(1)
		end
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