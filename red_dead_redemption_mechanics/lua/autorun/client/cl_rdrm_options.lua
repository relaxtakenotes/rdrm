hook.Add("PopulateToolMenu", "rdrm_settings_populate", function()
    spawnmenu.AddToolMenuOption("Options", "rdrm_8841_tool", "rdrm_8841_deadeye", "Deadeye", nil, nil, function(panel)
        panel:ClearControls()

        panel:CheckBox("Slowdown time", "cl_rdrm_deadeye_slowdown")
        panel:ControlHelp("Forced off in Multiplayer!")
        panel:CheckBox("Draw deadeye indicator", "cl_rdrm_deadeye_bar")
        panel:CheckBox("Original deadeye indicator", "cl_rdrm_deadeye_bar_mode")
        panel:CheckBox("Infinite mode", "cl_rdrm_deadeye_infinite")
        panel:CheckBox("Transfer marks to dead bodies", "cl_rdrm_deadeye_transfer_to_ragdolls")
        panel:ControlHelp("Make sure keep corpses is enabled for this feature!")
    
        panel:NumSlider("Deadeye Time", "cl_rdrm_deadeye_timer", 0, 100, 1)
        panel:ControlHelp("Set to 0 to disable deadeye.")
        panel:NumSlider("Deadeye Refill Multiplier", "cl_rdrm_deadeye_refill_multiplier", 0, 10, 1)
    
        panel:NumSlider("Deadeye indicator X offset", "cl_rdrm_deadeye_bar_offset_x", -9999, 9999, 1)
        panel:NumSlider("Deadeye indicator Y offset", "cl_rdrm_deadeye_bar_offset_y", -9999, 9999, 1)
        panel:NumSlider("Deadeye indicator size", "cl_rdrm_deadeye_bar_size", 0, 50, 1)
    end)

    spawnmenu.AddToolMenuOption("Options", "rdrm_8841_tool", "rdrm_8841_killcam", "Killcam", nil, nil, function(panel)
        panel:ClearControls()
        panel:NumSlider("Killcam Chance", "cl_rdrm_killcam_chance", 0, 1, 2)
        panel:NumSlider("Killcam Length Multiplier", "cl_rdrm_killcam_length", 0, 5, 2)
        panel:CheckBox("Killcam FX", "cl_rdrm_killcam_filter")
        panel:ControlHelp("Enable all those shmancy effects")
    end)

    spawnmenu.AddToolMenuOption("Options", "rdrm_8841_tool", "rdrm_8841_lowhp", "Low HP", nil, nil, function(panel)
        panel:ClearControls()
        panel:NumSlider("Low HP effect trigger", "cl_rdrm_low_hp_trigger", -1, 100, 0)
        panel:ControlHelp("Set to -1 to disable it. Pretty demanding!")
        panel:CheckBox("Allow sway", "cl_rdrm_low_hp_sway")
        panel:NumSlider("Sway Multiplier", "cl_rdrm_low_hp_sway_mult", 0, 10, 1)
    end) 

    spawnmenu.AddToolMenuOption("Options", "rdrm_8841_tool", "rdrm_8841_spawndeathfx", "Spawn/Death FX", nil, nil, function(panel)
        panel:ClearControls()
        panel:CheckBox("Allow death effect", "cl_rdrm_death_effect_enabled")
        panel:CheckBox("Allow spawn effect", "cl_rdrm_spawn_effect_enabled")
    end)

    spawnmenu.AddToolMenuOption("Options", "rdrm_8841_tool", "rdrm_8841_default", "Reset to Default", nil, nil, function(panel)
        panel:ClearControls()
        panel:Button("Reset", "cl_rdrm_default")
    end)

    
end)

hook.Add("AddToolMenuCategories", "rdrm_add_category", function() 
    spawnmenu.AddToolCategory("Options", "rdrm_8841_tool", "RDRM")
end)