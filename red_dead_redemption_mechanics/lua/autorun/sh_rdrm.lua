if SERVER then print("sh_rdrm.lua loaded on server") end
if CLIENT then print("sh_rdrm.lua loaded on client") end

rdrm = {}

timer.Simple(15, function()
	hook.Remove("EntityEmitSound", "zzz_TFA_EntityEmitSound")
	hook.Remove("EntityEmitSound", "ARC9_TimeWarpSounds") 
	hook.Remove("EntityEmitSound", "drc_timewarpsnd") 
	hook.Remove("EntityEmitSound", "JMOD_EntityEmitSound") // >timescale sound pitch scaling should be a part of gmod by default - jmod
														   // only if it didn't sound like shit and could be bypassed in the emitsound function!
end)