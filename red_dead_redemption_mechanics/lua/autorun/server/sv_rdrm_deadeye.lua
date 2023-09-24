print("sv_rdrm_deadeye.lua loaded")

util.AddNetworkString("rdrm_deadeye_fire_bullet") // to client
util.AddNetworkString("rdrm_deadeye_request_grenade_explosion") // from client

net.Receive("rdrm_deadeye_request_grenade_explosion", function()
    local grenade = net.ReadEntity()
    if grenade:GetClass() != "npc_grenade_frag" then return end
    grenade:SetSaveValue("m_flDetonateTime", 0)
end)

local accuracy_vars = {}
local accuracy_vars_original = {}
local function add_accuracy_var(cvar_string)
	accuracy_vars[cvar_string] = GetConVar(cvar_string)
end

for _, convar in ipairs({"arccw_mult_movedisp", "arccw_mult_hipfire", "mgbase_sv_accuracy", "mgbase_sv_recoil", "sv_tfa_spread_multiplier"}) do
    add_accuracy_var(convar)
end

local function zero_out_vars()
	for key, convar in pairs(accuracy_vars) do
		accuracy_vars_original[key] = convar:GetFloat()
		if key == "mgbase_sv_accuracy" then
			convar:SetFloat(5)
		else
			convar:SetFloat(0)
		end
	end
end

local function restore_vars()
	for key, convar in pairs(accuracy_vars) do
		convar:SetFloat(accuracy_vars_original[key])
	end
end

function rdrm.deadeye_handle_accuracy(in_deadeye)
    if in_deadeye then zero_out_vars() end
    if not in_deadeye then restore_vars() end
end

function rdrm.deadeye_handle_ammo(ply)
    pcall(function()
        local weapon = ply:GetActiveWeapon()
        local current_amount = weapon:Clip1()
        local max_amount = weapon:GetMaxClip1()
        local total_amount = ply:GetAmmoCount(weapon:GetPrimaryAmmoType())
        local required = max_amount - current_amount

        if required <= total_amount then
            if not GetConVar("arc9_infinite_ammo"):GetBool() then ply:RemoveAmmo(required, weapon:GetPrimaryAmmoType()) end
            weapon:SetClip1(max_amount)
        end
    end)
end

local function broadcast_shot(data)
    if data.Entity:IsPlayer() then
        local delay = 0

        if game.SinglePlayer() and rdrm.in_deadeye[data.Entity] and math.abs(rdrm.timescale - game.GetTimeScale()) < 0.01 then
    		delay = math.max((data.Weapon:GetNextPrimaryFire() - CurTime()) * rdrm.timescale, 0.005)
    		data.Weapon:SetNextPrimaryFire(CurTime() + delay)
        else
            delay = math.abs(data.Weapon:GetNextPrimaryFire() - CurTime())
        end
        
    	net.Start("rdrm_deadeye_fire_bullet")
        net.WriteFloat(delay)
    	net.Send(data.Entity)
    end
end

local function arc9_detour(args)
    local bullet = args[2]
    local attacker = bullet.Attacker

    if attacker.rdrm_fired_in_same_tick == nil then attacker.rdrm_fired_in_same_tick = false end
    if attacker.rdrm_fired_in_same_tick then return end
    if table.Count(bullet.Damaged) != 0 or bullet.rdrm_detected then return end

    local weapon = bullet.Weapon

    timer.Simple(0, function()
        local data = {}
        data.Entity = attacker
        data.Weapon = attacker:GetActiveWeapon()
        broadcast_shot(data)
    end)

    bullet.rdrm_detected = true
    attacker.rdrm_fired_in_same_tick = true

    timer.Simple(engine.TickInterval(), function() attacker.rdrm_fired_in_same_tick = false end)
end

hook.Add("PlayerTick", "rdrm_make_weapons_behave", function(ply, cmd)
	if rdrm.in_deadeye[ply] then
		local weapon = ply:GetActiveWeapon()

        if weapon == NULL or not weapon then return end
        
		ply:SetViewPunchAngles(Angle(0, 0, 0))
		ply:SetViewPunchVelocity(Angle(0, 0, 0))

		// mw2019 stuff
		if weapon.Trigger and weapon:GetTriggerDelta() < 1 then
			weapon:SetTriggerDelta(1)
		end

        if string.StartWith(weapon:GetClass() , "arc9_") then
            weapon:SetReady(true)
        end

        game.SetTimeScale(rdrm.timescale) // arc9 causes timescale to set back to 1 when deploying. idk why lol
	end

end)

hook.Add("InitPostEntity", "rdrm_init_pb_hooks", function()
    if ARC9 then
        local function arc9_wrapper(a)    -- a = old function
          return function(...)
            local args = { ... }
            arc9_detour(args)
            return a(...)
          end
        end
        ARC9.SendBullet = arc9_wrapper(ARC9.SendBullet)
    end

    if TFA then
        hook.Add("Think", "rdrm_detect_tfa_pb", function()
            local latest_pb = TFA.Ballistics.Bullets["bullet_registry"][table.Count(TFA.Ballistics.Bullets["bullet_registry"])]
            if latest_pb == nil then return end
            if latest_pb["rdrm_detected"] then return end

            local weapon = latest_pb["inflictor"]
            local entity = latest_pb["inflictor"]:GetOwner()

            if entity.rdrm_fired_in_same_tick == nil then entity.rdrm_fired_in_same_tick = false end
            if entity.rdrm_fired_in_same_tick then return end
            entity.rdrm_fired_in_same_tick = true
            timer.Simple(engine.TickInterval(), function() entity.rdrm_fired_in_same_tick = false end)

            local data = {}
            data.Entity = latest_pb["inflictor"]:GetOwner()
            data.Weapon = latest_pb["inflictor"]
            broadcast_shot(data)

            latest_pb["rdrm_detected"] = true
        end)
    end

    if ArcCW then
        hook.Add("Think", "rdrm_detect_arccw_pb", function()
            if ArcCW.PhysBullets[table.Count(ArcCW.PhysBullets)] == nil then return end
            local latest_pb = ArcCW.PhysBullets[table.Count(ArcCW.PhysBullets)]
            if latest_pb["rdrm_detected"] then return end
            if latest_pb["Attacker"] == Entity(0) then return end
            local entity = latest_pb["Attacker"]

            if entity.rdrm_fired_in_same_tick == nil then entity.rdrm_fired_in_same_tick = false end
            if entity.rdrm_fired_in_same_tick then return end
            entity.rdrm_fired_in_same_tick = true
            timer.Simple(engine.TickInterval(), function() entity.rdrm_fired_in_same_tick = false end)

            local weapon = latest_pb["Weapon"]

            local data = {}
            data.Entity = latest_pb["Attacker"]
            data.Weapon = latest_pb["Attacker"]:GetActiveWeapon()
            broadcast_shot(data)
            
            latest_pb["rdrm_detected"] = true
        end)
    end

    if MW_ATTS then -- global var from mw2019 sweps
        hook.Add("OnEntityCreated", "rdrm_detect_mw2019_pb", function(ent)
            if ent:GetClass() != "mg_sniper_bullet" and ent:GetClass() != "mg_slug" then return end
            timer.Simple(0, function()
                local attacker = ent:GetOwner()
                local entity = attacker
                local weapon = attacker:GetActiveWeapon()

                if entity.rdrm_fired_in_same_tick == nil then entity.rdrm_fired_in_same_tick = false end
                if entity.rdrm_fired_in_same_tick then return end
                entity.rdrm_fired_in_same_tick = true
                timer.Simple(engine.TickInterval(), function() entity.rdrm_fired_in_same_tick = false end)

                local data = {}
                data.Entity = attacker
                data.Weapon = attacker:GetActiveWeapon()

                broadcast_shot(data)
            end)
        end)
    end

    hook.Remove("InitPostEntity", "rdrm_init_pb_hooks")
end)

hook.Add("EntityFireBullets", "rdrm_entity_fire_bullets", function(attacker, data)
    if data.Spread.z == 0.125 then return end

    local entity = NULL
    local weapon = NULL
    local weird_weapon = false

    if attacker:IsPlayer() or attacker:IsNPC() then
        entity = attacker
        weapon = entity:GetActiveWeapon()
    else
        weapon = attacker
        entity = weapon:GetOwner()
        if entity == NULL then 
            entity = attacker
            weird_weapon = true
        end
    end

    if not weird_weapon and weapon != NULL and entity.GetShootPos != nil then -- should solve all of the issues caused by external bullet sources (such as the turret mod)
        local weapon_class = weapon:GetClass()

        if weapon_class == "mg_arrow" then return end -- mw2019 sweps crossbow
        if weapon_class == "mg_sniper_bullet" and data.Spread == Vector(0,0,0) then return end -- physical bullets in mw2019
        if weapon_class == "mg_slug" and data.Spread == Vector(0,0,0) then return end -- physical bullets in mw2019

        if data.Distance < 200 then return end -- melee

        if string.StartWith(weapon_class, "arccw_") then
            if data.Distance == 20000 then -- grenade launchers in arccw
                return
            end
            if GetConVar("arccw_bullet_enable"):GetInt() == 1 and data.Spread == Vector(0, 0, 0) then -- bullet physics in arcw
                return
            end
        end

        if string.StartWith(weapon_class, "arc9_") then
            if GetConVar("arc9_bullet_physics"):GetInt() == 1 and data.Spread == Vector(0, 0, 0) then -- bullet physics in arc9
                return
            end
        end

        if entity.rdrm_fired_in_same_tick == nil then entity.rdrm_fired_in_same_tick = false end
        if entity.rdrm_fired_in_same_tick then return end
        entity.rdrm_fired_in_same_tick = true
        timer.Simple(engine.TickInterval(), function() entity.rdrm_fired_in_same_tick = false end)
                                                                                             
        if #data.AmmoType > 2 then ammotype = data.AmmoType elseif weapon.Primary then ammotype = weapon.Primary.Ammo end

        if rdrm.in_deadeye[entity] then
		    local rdrm_data = {}
		    rdrm_data.Entity = entity
		    rdrm_data.Weapon = weapon
		    broadcast_shot(rdrm_data)

		    data.Spread = Vector(0,0,0)

		    return true
		end
    end
end)

hook.Add("EntityTakeDamage", "rdrm_absorb_damage", function(ent, dmg) 
    if ent:IsPlayer() and rdrm.in_deadeye[ent] and dmg:GetAttacker():IsNPC() and math.Rand(0, 1) > 0.5 then return true end
end)