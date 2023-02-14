print("cl_rdrm.lua loaded")

rdrm.in_deadeye = false
rdrm.in_killcam = false

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

/*
sound.Add({
	name = "killcam_bloodsplatter",
	channel = CHAN_STATIC,
	volume = 1.0,
	level = 0,
	pitch = {95,105},
	sound = "killcam/bloodsplatter.wav"
})
*/

net.Receive("rdrm_ragdoll_spawned", function()
	local owner = net.ReadEntity()
	local ragdoll = net.ReadEntity()
	hook.Run("rdrm_received_ragdoll_event", owner, ragdoll)
end)

function rdrm.change_state(data)
	net.Start("rdrm_request_change_state")
	net.WriteString(data.state_type)
	net.WriteBool(data.state)
	net.WriteBool(data.smooth or false)
	net.WriteBool(data.slowmotion and true)
	net.SendToServer()
end