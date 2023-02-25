if SERVER then print("sh_rdrm.lua loaded on server") end
if CLIENT then print("sh_rdrm.lua loaded on client") end

rdrm = {}

timer.Simple(15, function() 
	hook.Remove("EntityEmitSound", "ARC9_TimeWarpSounds") // PLEASE NO MORE
end)