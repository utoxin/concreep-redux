if script.active_mods["gvv"] then require("__gvv__.gvv")() end

function init()
    global.creepers = {}
    global.index = 1
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
            goto continue
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

        ::continue::
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

function creep(creeper)
    local roboport = creeper.roboport
    local surface = roboport.surface
    local force = roboport.force
    local minimum_item_count = settings.global["concreep-minimum-item-count"].value

    local target_creep_radius = roboport.logistic_cell.construction_radius
    if (settings.global["concreep-logistics-limit"].value) then
        target_creep_radius = roboport.logistic_cell.logistic_radius
    end

    local current_radius = math.min(creeper.radius, settings.global["concreep-range"].value * target_creep_radius / 100)

    local network_cellcount = #roboport.logistic_network.cells
    local available_bots = roboport.logistic_network.available_construction_robots
    local total_bots = roboport.logistic_network.all_construction_robots
    local available_bot_percentage = (available_bots / total_bots) * 100

    -- If we don't have enough idle bots, break out of this roboport here
    if (available_bot_percentage < settings.global["concreep-idle-bot-percentage"].value) then
        return
    end

    -- Figure out how many bots to use for this creep. This is limited to no more than the number required to be idle, and is further divided by the number of roboports in the network.
    -- This keeps any individual port from pulling too much of the network's bots towards it all at once, reducing bot travel/migration.
    local usable_robots = math.max(1, math.ceil(((settings.global["concreep-idle-bot-percentage"].value / 100) * total_bots) / network_cellcount))

    local count = 0

    local area = { { roboport.position.x - current_radius, roboport.position.y - current_radius }, { roboport.position.x + current_radius, roboport.position.y + current_radius } }
    local ghosts = surface.count_entities_filtered { area = area, name = "tile-ghost", force = force }

    local in_space = false
    if remote.interfaces["space-exploration"] then
        in_space = "orbit" == remote.call("space-exploration", "get_surface_type", {surface_index = surface.index})
    end

    if force.max_successful_attempts_per_tick_per_construction_queue * 60 < usable_robots then
        force.max_successful_attempts_per_tick_per_construction_queue = math.floor(usable_robots / 60)
    end

    local refined_concrete_count = math.max(0, roboport.logistic_network.get_item_count("refined-concrete") - minimum_item_count)
    local concrete_count = math.max(0, roboport.logistic_network.get_item_count("concrete") - minimum_item_count)
    local brick_count = math.max(0, roboport.logistic_network.get_item_count("stone-brick") - minimum_item_count)

    local space_scaffold_count = 0
    local space_tile_count = 0
    if remote.interfaces["space-exploration"] and in_space then
        space_scaffold_count = math.max(0, roboport.logistic_network.get_item_count("se-space-platform-scaffold") - minimum_item_count)
        space_tile_count = math.max(0, roboport.logistic_network.get_item_count("se-space-platform-plating") - minimum_item_count)
    end

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

    local virgin_tiles = surface.find_tiles_filtered { has_hidden_tile = false, area = area, limit = usable_robots, collision_mask = surface.get_tile(roboport.position).prototype.collision_mask }
    if ghosts > #virgin_tiles then
        return
    end --Wait for ghosts to finish building first.
    for i = #virgin_tiles, 1, -1 do
        local ghost_type
        if not creeper.pattern[(virgin_tiles[i].position.x - 2) % 4 + 1][(virgin_tiles[i].position.y - 2) % 4 + 1] then
            if count < refined_concrete_count and not in_space then
                ghost_type = "refined-concrete"
            elseif count < concrete_count and not in_space then
                ghost_type = "concrete"
            elseif settings.global["creep-brick"].value and count < brick_count and not in_space then
                ghost_type = "stone-path"
            elseif remote.interfaces["space-exploration"] and count < space_tile_count and in_space then
                ghost_type = "se-space-platform-plating"
            elseif remote.interfaces["space-exploration"] and count < space_scaffold_count and in_space then
                ghost_type = "se-space-platform-scaffold"
            end
        else
            if roboport.logistic_network.get_item_count(creeper.item[(virgin_tiles[i].position.x - 2) % 4 + 1][(virgin_tiles[i].position.y - 2) % 4 + 1]) > minimum_item_count then
                ghost_type = creeper.pattern[(virgin_tiles[i].position.x - 2) % 4 + 1][(virgin_tiles[i].position.y - 2) % 4 + 1]
            end
        end
        if ghost_type then
            build_tile(ghost_type, virgin_tiles[i].position)
        end

        creeper.removal_counter = 0
    end

    if count >= usable_robots then
        return true
    end
    usable_robots = usable_robots - count

    --Still here?  Look for concrete to upgrade
    local upgrade_target_types = {}
    if settings.global["upgrade-brick"].value and not in_space then
        table.insert(upgrade_target_types, "stone-path")
    end
    if settings.global["upgrade-concrete"].value and not in_space then
        table.insert(upgrade_target_types, "concrete")
        table.insert(upgrade_target_types, "hazard-concrete-left")
        table.insert(upgrade_target_types, "hazard-concrete-right")
    end
    if remote.interfaces["space-exploration"] and settings.global["upgrade-space-scaffold"].value and in_space then
        table.insert(upgrade_target_types, "se-space-platform-scaffold")
    end

    if creeper.upgrade then
        if #upgrade_target_types > 0 then
            local squishy_targets = surface.find_tiles_filtered { area = area, name = upgrade_target_types, limit = math.min(math.max(concrete_count, refined_concrete_count, 0), usable_robots) }
            for _, v in pairs(squishy_targets) do
                local tile_type = "refined-concrete"
                if (remote.interfaces["space-exploration"]) and in_space then
                    tile_type = "se-space-platform-plating"
                else
                    if v.name == "hazard-concrete-left" then
                        tile_type = "refined-hazard-concrete-left"
                    elseif v.name == "hazard-concrete-right" then
                        tile_type = "refined-hazard-concrete-right"
                    elseif count >= refined_concrete_count then
                        tile_type = "concrete"
                    end
                end
                build_tile(tile_type, v.position)
                creeper.removal_counter = 0
            end

            if count >= usable_robots then
                return true
            end
            usable_robots = usable_robots - count

            if count >= usable_robots then
                return true
            end
        end
    end

    --Still here?  Check to see if the roboport should turn off.
    if surface.count_tiles_filtered { area = area, has_hidden_tile = false, collision_mask = surface.get_tile(roboport.position).prototype.collision_mask } == 0 then
        if current_radius < target_creep_radius * settings.global["concreep-range"].value / 100 then
            creeper.radius = math.min(creeper.radius + 2, roboport.logistic_cell.construction_radius)
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

function validate_tile_names()
    for i = #global.creepers, 1, -1 do
        local creep = global.creepers[i]
        if creep.roboport.valid then
            addPort(creep.roboport)
        end
        table.remove(global.creepers, i)
    end
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
