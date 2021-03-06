if script.active_mods["gvv"] then require("__gvv__.gvv")() end

MINIMUM_ROBOTS = 30
MINIMUM_ITEM_COUNT = 200

function init()
    global.creepers = {}
    global.index = 1
    find_fastest_tile()
    for _, surface in pairs(game.surfaces) do
        local roboports = surface.find_entities_filtered { type = "roboport" }
        for _, port in pairs(roboports) do
            if validate(port) then
                addPort(port)
            end
        end
    end
end

function wake_up_creepers()
    global.index = 1
    find_fastest_tile()
    for _, surface in pairs(game.surfaces) do
        local roboports = surface.find_entities_filtered { type = "roboport" }
        for _, port in pairs(roboports) do
            if validate(port) then
                addPort(port)
            end
        end
    end
end

function check_roboports()
    -- Iterate over up to 5 entities
    if #global.creepers == 0 then
        wake_up_creepers()
        return
    end
    for i = 1, 5 do
        if i > #global.creepers then
            return
        end
        local creeper = get_creeper()
        if creeper == nil then
            return
        end --This is where I want a 'continue' keyword.
        local roboport = creeper.roboport
        if roboport.logistic_network and roboport.logistic_network.valid then
            --Check if powered and full energy
            if roboport.prototype.electric_energy_source_prototype then
                if roboport.prototype.electric_energy_source_prototype.buffer_capacity == roboport.energy then
                    creep(creeper)
                end
            else
                --Checking fully powered status is much trickier for non-electric energy sources.
                creep(creeper)
            end
        end
    end
end

function get_creeper()
    if global.index > #global.creepers then
        global.index = 1
    end
    local creeper = global.creepers[global.index]
    if not (creeper.roboport and creeper.roboport.valid) or creeper.off then
        if creeper.roboport and creeper.roboport.valid and creeper.off and creeper.removal_counter and creeper.removal_counter < 10 then
            creeper.removal_counter = creeper.removal_counter + 1
            return
        end

        --Roboport removed
        table.remove(global.creepers, global.index)
        return
    end
    global.index = global.index + 1
    return creeper
end

function checkRoboports()
    if global.creepers and #global.creepers > 0 then
        if settings.global["concreep-range"].value == 0 then
            return
        end
        local creeper = global.creepers[global.index]
        if creeper then
            -- Redundant?
            local roboport = creeper.roboport
            local amount = 0
            -- Place a tile per every 10 robots.
            if roboport and roboport.valid then
                --Check if still alive
                if roboport.logistic_network and roboport.logistic_network.valid and roboport.prototype.electric_energy_source_prototype.buffer_capacity == roboport.energy then
                    --Check if powered!
                    if roboport.logistic_network.available_construction_robots > MINIMUM_ROBOTS then
                        amount = math.floor(roboport.logistic_network.available_construction_robots / 2)
                        roboport.force.max_successful_attempts_per_tick_per_construction_queue = math.max(roboport.force.max_successful_attempts_per_tick_per_construction_queue, math.floor(amount / 60))
                        if creep(global.index, amount) then
                            return true
                        end
                    end
                else
                    return false
                end
            else
                -- Roboport died
                table.remove(global.creepers, global.index)
            end
        else
            table.remove(global.creepers, global.index)
        end
    end
end

function creep(creeper)
    local roboport = creeper.roboport
    local surface = roboport.surface
    local force = roboport.force
    local radius = math.min(creeper.radius, settings.global["concreep-range"].value * roboport.logistic_cell.construction_radius / 100)
    local idle_robots = roboport.logistic_network.available_construction_robots / 2

    local count = 0

    local area = { { roboport.position.x - radius, roboport.position.y - radius }, { roboport.position.x + radius, roboport.position.y + radius } }
    local ghosts = surface.count_entities_filtered { area = area, name = "tile-ghost", force = force }

    if force.max_successful_attempts_per_tick_per_construction_queue * 60 < idle_robots then
        force.max_successful_attempts_per_tick_per_construction_queue = math.floor(idle_robots / 60)
    end

    local refined_concrete_count = math.max(0, roboport.logistic_network.get_item_count("refined-concrete") - MINIMUM_ITEM_COUNT)
    local concrete_count = math.max(0, roboport.logistic_network.get_item_count("concrete") - MINIMUM_ITEM_COUNT)
    local brick_count = math.max(0, roboport.logistic_network.get_item_count("stone-brick") - MINIMUM_ITEM_COUNT)

    local function build_tile(type, position)
        if surface.can_place_entity { name = "tile-ghost", position = position, inner_name = type, force = force } then
            surface.create_entity { name = "tile-ghost", position = position, inner_name = type, force = force, expires = false }
            count = count + 1
        else
            return
        end
        local tree_area = { { position.x - 0.2, position.y - 0.2 }, { position.x + 0.8, position.y + 0.8 } }
        for _, tree in pairs(surface.find_entities_filtered { type = "tree", area = tree_area }) do
            tree.order_deconstruction(roboport.force)
            count = count + 1
        end
        for _, rock in pairs(surface.find_entities_filtered { type = "simple-entity", area = tree_area }) do
            rock.order_deconstruction(roboport.force)
            count = count + 1
        end
        for _, cliff in pairs(surface.find_entities_filtered { type = "cliff", limit = 1, area = tree_area }) do
            if roboport.logistic_network.get_item_count("cliff-explosives") > 0 then
                cliff.order_deconstruction(roboport.force)
                count = count + 1
            end
        end
    end

    local virgin_tiles = surface.find_tiles_filtered { has_hidden_tile = false, area = area, limit = idle_robots, collision_mask = surface.get_tile(roboport.position).prototype.collision_mask }
    if ghosts > #virgin_tiles then
        return
    end --Wait for ghosts to finish building first.
    for i = #virgin_tiles, 1, -1 do
        local ghost_type
        if not creeper.pattern[(virgin_tiles[i].position.x - 2) % 4 + 1][(virgin_tiles[i].position.y - 2) % 4 + 1] then
            if count < refined_concrete_count then
                ghost_type = "refined-concrete"
            elseif count < concrete_count then
                ghost_type = "concrete"
            elseif settings.global["creep-brick"].value and count < brick_count then
                ghost_type = "stone-path"
            end
        else
            if roboport.logistic_network.get_item_count(creeper.item[(virgin_tiles[i].position.x - 2) % 4 + 1][(virgin_tiles[i].position.y - 2) % 4 + 1]) > MINIMUM_ITEM_COUNT then
                ghost_type = creeper.pattern[(virgin_tiles[i].position.x - 2) % 4 + 1][(virgin_tiles[i].position.y - 2) % 4 + 1]
            end
        end
        if ghost_type then
            build_tile(ghost_type, virgin_tiles[i].position)
        end

        creeper.removal_counter = 0
    end

    if count >= idle_robots then
        return true
    end
    idle_robots = idle_robots - count

    --Still here?  Look for concrete to upgrade
    local upgrade_target_types = {}
    if settings.global["upgrade-brick"].value then
        table.insert(upgrade_target_types, "stone-path")
    end
    if settings.global["upgrade-concrete"].value then
        table.insert(upgrade_target_types, "concrete")
        table.insert(upgrade_target_types, "hazard-concrete-left")
        table.insert(upgrade_target_types, "hazard-concrete-right")
    end

    if creeper.upgrade then
        if #upgrade_target_types > 0 then
            local squishy_targets = surface.find_tiles_filtered { area = area, name = upgrade_target_types, limit = math.min(math.max(concrete_count, refined_concrete_count, 0), idle_robots) }
            for _, v in pairs(squishy_targets) do
                local tile_type = "refined-concrete"
                if v.name == "hazard-concrete-left" then
                    tile_type = "refined-hazard-concrete-left"
                elseif v.name == "hazard-concrete-right" then
                    tile_type = "refined-hazard-concrete-right"
                elseif count >= refined_concrete_count then
                    tile_type = "concrete"
                end
                build_tile(tile_type, v.position)
                creeper.removal_counter = 0
            end

            if count >= idle_robots then
                return true
            end
            idle_robots = idle_robots - count

            if count >= idle_robots then
                return true
            end
        end
    end

    --Still here?  Check to see if the roboport should turn off.
    if surface.count_tiles_filtered { area = area, has_hidden_tile = false, collision_mask = surface.get_tile(roboport.position).prototype.collision_mask } == 0 then
        if radius < roboport.logistic_cell.construction_radius * settings.global["concreep-range"].value / 100 then
            creeper.radius = math.min(creeper.radius + 2, roboport.logistic_cell.construction_radius) -- Todo for next version
        else
            local switch = true

            if #upgrade_target_types > 0 and surface.count_tiles_filtered { name = upgrade_target_types, area = area, limit = 1 } > 0 then
                switch = false
            end
            if switch then
                creeper.off = true
                creeper.removal_counter = 1
            else
                creeper.radius = 4 --Reset radius and switch to upgrade mode.
                creeper.upgrade = true
            end
        end
    end
    return false
end

--Is this a valid roboport?
function validate(entity)
    if entity and entity.valid and (entity.type == "roboport") and entity.logistic_cell and (entity.logistic_cell.construction_radius > 0) then
        return true
    end
    return false
end

function roboports(event)
    local entity = event.created_entity or event.destination or event.entity
    if not global.creepers then
        init()
    end
    if validate(entity) then
        addPort(entity)
    end
end

function addPort(roboport)
    local surface = roboport.surface

    -- Capture the pattern the roboport sits on.
    local patt = {}
    local it = {}
    for xx = -2, 1, 1 do
        patt[xx + 3] = {}
        it[xx + 3] = {}
        for yy = -2, 1, 1 do
            local tile = surface.get_tile(roboport.position.x + xx, roboport.position.y + yy)
            if (tile.hidden_tile and tile.prototype.items_to_place_this) and not (tile.name == "stone-path" or tile.name == "concrete" or tile.name == "refined-concrete") then
                it[xx + 3][yy + 3] = tile.prototype.items_to_place_this[1] and game.item_prototypes[tile.prototype.items_to_place_this[1].name] and tile.prototype.items_to_place_this[1].name
                patt[xx + 3][yy + 3] = tile.name
            end
        end
    end

    table.insert(global.creepers, { roboport = roboport, radius = 1, pattern = patt, item = it, off = false, removal_counter = 0 })
end

--This does not check collision mask.
function find_fastest_tile()
    local walking_speed_modifier = 1
    local tile_name
    for _, tile in pairs(game.tile_prototypes) do
        if tile.items_to_place_this and tile.walking_speed_modifier and tile.walking_speed_modifier > walking_speed_modifier then
            walking_speed_modifier = tile.walking_speed_modifier
            tile_name = tile.name
        end
    end
    if tile_name ~= "refined-concrete" then
        global.fastest = tile_name
        return
    end
    global.fastest = nil
end

function validate_tile_names()
    for i = #global.creepers, 1, -1 do
        local creep = global.creepers[i]
        if creep.roboport.valid then
            addPort(creep.roboport)
        end
        table.remove(global.creepers, i)
    end
    --This part may be out of scope but...
    find_fastest_tile()
end

script.on_event(
        {
            defines.events.on_built_entity,
            defines.events.on_robot_built_entity,
            defines.events.on_entity_cloned,
            defines.events.script_raised_revive
        },
        roboports
    )
script.on_nth_tick(60, check_roboports)
script.on_init(init)
script.on_configuration_changed(validate_tile_names)
