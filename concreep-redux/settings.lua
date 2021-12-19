data:extend({
    {
        type = "int-setting",
        name = "concreep-range",
        setting_type = "runtime-global",
        default_value = 100,
        minimum_value = 0,
        maximum_value = 100,
        order = "01"
    },
    {
        type = "int-setting",
        name = "concreep-idle-bot-percentage",
        setting_type = "runtime-global",
        default_value = 50,
        minimum_value = 0,
        maximum_value = 100,
        order = "02"
    },
    {
        type = "bool-setting",
        name = "creep-brick",
        setting_type = "runtime-global",
        default_value = true,
        order = "03"
    },
    {
        type = "bool-setting",
        name = "upgrade-brick",
        setting_type = "runtime-global",
        default_value = true,
        order = "04"
    },
    {
        type = "bool-setting",
        name = "upgrade-concrete",
        setting_type = "runtime-global",
        default_value = true,
        order = "05"
    }
})