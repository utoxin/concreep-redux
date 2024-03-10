data:extend({
    {
        type = "int-setting",
        name = "concreep-range",
        setting_type = "runtime-global",
        default_value = 100,
        minimum_value = 0,
        maximum_value = 100,
        order = "10"
    },
    {
        type = "bool-setting",
        name = "concreep-logistics-limit",
        setting_type = "runtime-global",
        default_value = false,
        order = "20"
    },
    {
        type = "int-setting",
        name = "concreep-idle-bot-percentage",
        setting_type = "runtime-global",
        default_value = 50,
        minimum_value = 0,
        maximum_value = 100,
        order = "30"
    },
    {
        type = "int-setting",
        name = "concreep-minimum-item-count",
        setting_type = "runtime-global",
        default_value = 100,
        minimum_value = 0,
        order = "35"
    },
    {
        type = "bool-setting",
        name = "creep-brick",
        setting_type = "runtime-global",
        default_value = true,
        order = "40"
    },
    {
        type = "bool-setting",
        name = "upgrade-brick",
        setting_type = "runtime-global",
        default_value = true,
        order = "50"
    },
    {
        type = "bool-setting",
        name = "upgrade-concrete",
        setting_type = "runtime-global",
        default_value = true,
        order = "60"
    },
    {
        type = "bool-setting",
        name = "upgrade-space-scaffold",
        setting_type = "runtime-global",
        default_value = true,
        order = "70"
    }
})