data:extend({
    {
        type = "int-setting",
        name = "concreep-range",
        setting_type = "runtime-global",
        default_value = 100,
        minimum_value = 0,
        maximum_value = 100,
        order = "010"
    },
    {
        type = "bool-setting",
        name = "concreep-logistics-limit",
        setting_type = "runtime-global",
        default_value = false,
        order = "020"
    },
    {
        type = "int-setting",
        name = "concreep-idle-bot-percentage",
        setting_type = "runtime-global",
        default_value = 50,
        minimum_value = 0,
        maximum_value = 100,
        order = "030"
    },
    {
        type = "int-setting",
        name = "concreep-minimum-item-count",
        setting_type = "runtime-global",
        default_value = 100,
        minimum_value = 0,
        order = "035"
    },
    {
        type = "bool-setting",
        name = "creep-brick",
        setting_type = "runtime-global",
        default_value = true,
        order = "040"
    },
    {
        type = "bool-setting",
        name = "upgrade-brick",
        setting_type = "runtime-global",
        default_value = true,
        order = "050"
    },
    {
        type = "bool-setting",
        name = "upgrade-concrete",
        setting_type = "runtime-global",
        default_value = true,
        order = "060"
    },
    {
        type = "bool-setting",
        name = "upgrade-space-scaffold",
        setting_type = "runtime-global",
        default_value = true,
        order = "070"
    },
    {
        type = "bool-setting",
        name = "concreep-tiles-per-area",
        setting_type = "runtime-global",
        default_value = false,
        order = "080"
    },
    {
        type = "string-setting",
        name = "concreep-logistic-area-tile",
        setting_type = "runtime-global",
        default_value = "refined-concrete",
        auto_trim = true,
        allowed_values = {"brick", "concrete", "refined-concrete"},
        order = "090"
    },
    {
        type = "string-setting",
        name = "concreep-construction-area-tile",
        setting_type = "runtime-global",
        default_value = "concrete",
        auto_trim = true,
        allowed_values = {"brick", "concrete", "refined-concrete"},
        order = "100"
    }
})