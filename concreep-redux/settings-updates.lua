if not mods["space-exploration"] then
    data.raw["bool-setting"]["upgrade-space-scaffold"].hidden = true
end

local tiles = {"brick", "concrete", "refined-concrete"}

if mods["Dectorio"] then
--    table.insert(data.raw["string-setting"]["concreep-construction-area-tile"].allowed_values, "test")
end