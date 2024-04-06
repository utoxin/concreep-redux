function creep_init()
	global.creepers        = {}
	global.active_creepers = 0
	wake_up_creepers()
end

function wake_up_creepers()
	global.index           = 1
	global.active_creepers = 0

	for _, surface in pairs(game.surfaces) do
		local roboports = surface.find_entities_filtered { type = "roboport" }
		for _, port in pairs(roboports) do
			if validate(port) then
				addPort(port)
			end
		end
	end

	count_active_creepers()
end

function check_roboports()
	if global.active_creepers == nil then
		init()
		return
	end

	if #global.creepers == 0 then
		wake_up_creepers()
		return
	end

	for i = 1, 10 do
		if i > #global.creepers then
			return
		end
		local creeper = get_creeper()

		if creeper == nil then
			goto continue
		end

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

		:: continue ::
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
	local roboport                    = creeper.roboport

	local available_bots              = roboport.logistic_network.available_construction_robots
	local total_bots                  = roboport.logistic_network.all_construction_robots
	local available_bot_percentage    = available_bots / total_bots

	-- If we don't have enough idle bots, break out of this roboport here
	local idle_bot_percentage_setting = settings.global["concreep-idle-bot-percentage"].value / 100
	if (available_bot_percentage < idle_bot_percentage_setting) then
		return
	end

	local surface                    = roboport.surface
	local force                      = roboport.force
	local active_port_factor         = math.min(10, global.active_creepers or 1)

	local minimum_item_count_setting = settings.global["concreep-minimum-item-count"].value
	local concreep_range_setting     = settings.global["concreep-range"].value / 100
	local area_tile_setting          = settings.global["concreep-tiles-per-area"].value

	local target_creep_radius        = roboport.logistic_cell.construction_radius
	if (settings.global["concreep-logistics-limit"].value) then
		target_creep_radius = roboport.logistic_cell.logistic_radius
	end

	local current_radius  = math.min(creeper.radius, concreep_range_setting * target_creep_radius)

	-- Figure out how many bots to use for this creep. This is limited to no more than the number allowed to be working, and is further divided by the number of roboports in the network.
	-- This keeps any individual port from pulling too much of the network's bots towards it all at once, reducing bot travel/migration.

	local working_bots    = total_bots - available_bots
	local usable_robots   = math.max(1, math.ceil((((1 - idle_bot_percentage_setting) * total_bots) - working_bots) / active_port_factor))

	creeper.usable_robots = usable_robots
	if force.max_successful_attempts_per_tick_per_construction_queue * 60 < usable_robots then
		force.max_successful_attempts_per_tick_per_construction_queue = math.floor(usable_robots / 60)
	end

	local area     = {
		{ roboport.position.x - current_radius, roboport.position.y - current_radius },
		{ roboport.position.x + current_radius, roboport.position.y + current_radius }
	}

	local in_space = false
	if remote.interfaces["space-exploration"] then
		in_space = "orbit" == remote.call("space-exploration", "get_surface_type", { surface_index = surface.index })
	end

	local creep_data = {
		current_radius             = current_radius,
		target_creep_radius        = target_creep_radius * concreep_range_setting,
		usable_robots              = usable_robots,
		area                       = area,
		minimum_item_count_setting = minimum_item_count_setting
	}

	if in_space then
		space_creep(creeper, creep_data)
	elseif area_tile_setting then
		area_tile_creep(creeper, creep_data)
	else
		standard_creep(creeper, creep_data)
	end
end

function landfill_creep(creeper, creep_data)
	local roboport     = creeper.roboport
	local surface      = roboport.surface
	local force        = roboport.force

	local ghosts       = surface.count_entities_filtered { area = creep_data["area"], name = "tile-ghost", force = force }
	local water_tiles  = surface.find_tiles_filtered { has_hidden_tile = false, area = creep_data["area"], limit = creep_data["usable_robots"], collision_mask = { "water-tile" } }

	-- Wait for ghosts to finish building first.
	if ghosts >= #water_tiles and ghosts > 0 then
		return
	end

	local count          = 0
	local landfill_count = math.max(0,
									roboport.logistic_network.get_item_count("landfill") - creep_data["minimum_item_count_setting"])
	local pump_radius = settings.global["concreep-pump-radius"].value

	for i = #water_tiles, 1, -1 do
		if count < landfill_count then
			local pump_count = 0
			if pump_radius > 0 then
				pump_count = surface.count_entities_filtered { position = water_tiles[i].position, radius = pump_radius, name = "offshore-pump"}
				pump_count = pump_count + surface.count_entities_filtered { position = water_tiles[i].position, radius = pump_radius, type = "entity-ghost", ghost_type = "offshore-pump"}
			end

			if pump_count == 0 then
				count = count + build_tile(roboport, "landfill", water_tiles[i].position)
				creeper.removal_counter = 0
			end
		end
	end
end

function standard_creep(creeper, creep_data)
	local roboport     = creeper.roboport
	local surface      = roboport.surface
	local force        = roboport.force

	if settings.global["creep-landfill"].value then
		landfill_creep(creeper, creep_data)
	end

	local ghosts       = surface.count_entities_filtered { area = creep_data["area"], name = "tile-ghost", force = force }
	local virgin_tiles = surface.find_tiles_filtered { has_hidden_tile = false, area = creep_data["area"], limit = creep_data["usable_robots"], collision_mask = surface.get_tile(roboport.position).prototype.collision_mask }

	-- Wait for ghosts to finish building first.
	if ghosts >= #virgin_tiles and ghosts > 0 then
		return
	end

	local count                  = 0
	local creep_brick_setting    = settings.global["creep-brick"].value

	local refined_concrete_count = math.max(0,
											roboport.logistic_network.get_item_count("refined-concrete") - creep_data["minimum_item_count_setting"])
	local refined_hazard_concrete_count = math.max(0,
												   roboport.logistic_network.get_item_count("refined-hazard-concrete") - creep_data["minimum_item_count_setting"])
	local concrete_count         = math.max(0,
											roboport.logistic_network.get_item_count("concrete") - creep_data["minimum_item_count_setting"])
	local brick_count            = math.max(0,
											roboport.logistic_network.get_item_count("stone-brick") - creep_data["minimum_item_count_setting"])

	for i = #virgin_tiles, 1, -1 do
		local ghost_type

		if not creeper.pattern[(virgin_tiles[i].position.x - 2) % 4 + 1][(virgin_tiles[i].position.y - 2) % 4 + 1] then
			if count < refined_concrete_count then
				ghost_type = "refined-concrete"
			elseif count < concrete_count then
				ghost_type = "concrete"
			elseif creep_brick_setting and count < brick_count then
				ghost_type = "stone-path"
			end
		else
			if roboport.logistic_network.get_item_count(creeper.item[(virgin_tiles[i].position.x - 2) % 4 + 1][(virgin_tiles[i].position.y - 2) % 4 + 1]) > creep_data["minimum_item_count_setting"] then
				ghost_type = creeper.pattern[(virgin_tiles[i].position.x - 2) % 4 + 1][(virgin_tiles[i].position.y - 2) % 4 + 1]
			end
		end

		if ghost_type then
			count = count + build_tile(roboport, ghost_type, virgin_tiles[i].position)
		end

		creeper.removal_counter = 0
	end

	if count >= creep_data["usable_robots"] then
		return true
	end

	creep_data["usable_robots"] = creep_data["usable_robots"] - count
	count                       = 0

	--Still here?  Look for upgrades that need done
	local upgrade_target_types  = {}

	if settings.global["upgrade-brick"].value and (refined_concrete_count > 0 or concrete_count > 0) then
		table.insert(upgrade_target_types, "stone-path")
	end

	if settings.global["upgrade-concrete"].value and refined_concrete_count > 0 then
		table.insert(upgrade_target_types, "concrete")
	end

	if settings.global["upgrade-concrete"].value and refined_hazard_concrete_count > 0 then
		table.insert(upgrade_target_types, "hazard-concrete-left")
		table.insert(upgrade_target_types, "hazard-concrete-right")
	end

	if creeper.upgrade then
		if #upgrade_target_types > 0 then
			local upgradable_tiles = surface.find_tiles_filtered {
				area = creep_data["area"],
				name = upgrade_target_types,
				limit = math.min(math.max(concrete_count, refined_concrete_count, 0), creep_data["usable_robots"])
			}

			for _, target_tile in pairs(upgradable_tiles) do
				local tile_type = "refined-concrete"

				if target_tile.name == "hazard-concrete-left" then
					tile_type = "refined-hazard-concrete-left"
				elseif target_tile.name == "hazard-concrete-right" then
					tile_type = "refined-hazard-concrete-right"
				elseif count >= refined_concrete_count then
					tile_type = "concrete"
				end

				count                   = count + build_tile(roboport, tile_type, target_tile.position)
				creeper.removal_counter = 0
			end

			if count >= creep_data["usable_robots"] then
				return true
			end
		end
	end

	standard_sleep_check(creeper, creep_data, upgrade_target_types)
	return false
end

function area_tile_creep(creeper, creep_data)
	local roboport     = creeper.roboport
	local surface      = roboport.surface
	local force        = roboport.force

	if settings.global["creep-landfill"].value then
		landfill_creep(creeper, creep_data)
	end

	local ghosts       = surface.count_entities_filtered { area = creep_data["area"], name = "tile-ghost", force = force }
	local virgin_tiles = surface.find_tiles_filtered { has_hidden_tile = false, area = creep_data["area"], limit = creep_data["usable_robots"], collision_mask = surface.get_tile(roboport.position).prototype.collision_mask }

	-- Wait for ghosts to finish building first.
	if ghosts >= #virgin_tiles and ghosts > 0 then
		return
	end

	local logistic_area_tile          = settings.global["concreep-logistic-area-tile"].value
	local construction_area_tile      = settings.global["concreep-construction-area-tile"].value
	local minimum_item_count_setting  = settings.global["concreep-minimum-item-count"].value

	local count                       = 0

	local logistic_radius             = roboport.logistic_cell.logistic_radius
	local available_logistic_tile     = math.max(0,
												 roboport.logistic_network.get_item_count(logistic_area_tile) - minimum_item_count_setting)
	local available_construction_tile = math.max(0,
												 roboport.logistic_network.get_item_count(construction_area_tile) - minimum_item_count_setting)

	local roboport_x                  = roboport.position.x
	local roboport_y                  = roboport.position.y

	for i = #virgin_tiles, 1, -1 do
		local ghost_type
		local tile_x = virgin_tiles[i].position.x
		local tile_y = virgin_tiles[i].position.y

		if tile_x > roboport_x then
			tile_x = tile_x + 1
		end

		if tile_y > roboport_y then
			tile_y = tile_y + 1
		end

		if (math.abs(tile_x - roboport_x) > logistic_radius or math.abs(tile_y - roboport_y) > logistic_radius) and available_construction_tile > 0 then
			available_construction_tile = available_construction_tile - 1
			ghost_type                  = construction_area_tile
		elseif (math.abs(tile_x - roboport_x) <= logistic_radius and math.abs(tile_y - roboport_y) <= logistic_radius) and available_logistic_tile > 0 then
			available_logistic_tile = available_logistic_tile - 1
			ghost_type              = logistic_area_tile
		end

		if ghost_type then
			count = count + build_tile(roboport, ghost_type, virgin_tiles[i].position)
		end

		creeper.removal_counter = 0
	end

	if count >= creep_data["usable_robots"] then
		return true
	end

	area_tile_sleep_check(creeper, creep_data)
	return false
end

function space_creep(creeper, creep_data)
	local roboport     = creeper.roboport
	local surface      = roboport.surface
	local force        = roboport.force

	local ghosts       = surface.count_entities_filtered { area = creep_data["area"], name = "tile-ghost", force = force }
	local virgin_tiles = surface.find_tiles_filtered { has_hidden_tile = false, area = creep_data["area"], limit = creep_data["usable_robots"], collision_mask = surface.get_tile(roboport.position).prototype.collision_mask }

	-- Wait for ghosts to finish building first.
	if ghosts >= #virgin_tiles and ghosts > 0 then
		return
	end

	local count                = 0

	local space_scaffold_count = math.max(0,
										  roboport.logistic_network.get_item_count("se-space-platform-scaffold") - creep_data["minimum_item_count_setting"])
	local space_tile_count     = math.max(0,
										  roboport.logistic_network.get_item_count("se-space-platform-plating") - creep_data["minimum_item_count_setting"])

	for i = #virgin_tiles, 1, -1 do
		local ghost_type

		if count < space_tile_count then
			ghost_type = "se-space-platform-plating"
		elseif count < space_scaffold_count then
			ghost_type = "se-space-platform-scaffold"
		end

		if ghost_type then
			count = count + build_tile(roboport, ghost_type, virgin_tiles[i].position)
		end

		creeper.removal_counter = 0
	end

	if count >= creep_data["usable_robots"] then
		return true
	end

	creep_data["usable_robots"] = creep_data["usable_robots"] - count
	count                       = 0

	--Still here?  Look for upgrades that need done
	local upgrade_target_types  = {}

	if settings.global["upgrade-space-scaffold"].value and space_tile_count > 0 then
		table.insert(upgrade_target_types, "se-space-platform-scaffold")
		table.insert(upgrade_target_types, "se-asteroid")
	else
		return true
	end

	if creeper.upgrade then
		if #upgrade_target_types > 0 then
			local upgradable_tiles = surface.find_tiles_filtered { area = creep_data["area"], name = upgrade_target_types, limit = math.min(math.max(space_tile_count,
																																					 0),
																																			creep_data["usable_robots"]) }
			for _, target_tile in pairs(upgradable_tiles) do
				local tile_type         = "se-space-platform-plating"
				count                   = count + build_tile(roboport, tile_type, target_tile.position)
				creeper.removal_counter = 0
			end

			if count >= creep_data["usable_robots"] then
				return true
			end
		end
	end

	standard_sleep_check(creeper, creep_data, upgrade_target_types)
	return false
end

function area_tile_sleep_check(creeper, creep_data)
	local roboport = creeper.roboport
	local surface  = roboport.surface

	if surface.count_tiles_filtered { area = creep_data["area"], has_hidden_tile = false, collision_mask = surface.get_tile(roboport.position).prototype.collision_mask } == 0 then
		if creep_data["current_radius"] < creep_data["target_creep_radius"] then
			creeper.radius = math.min(creeper.radius + 1, roboport.logistic_cell.construction_radius)
		else
			creeper.off             = true
			creeper.removal_counter = 1
			global.active_creepers  = global.active_creepers - 1
		end
	end
end

function standard_sleep_check(creeper, creep_data, upgrade_target_types)
	local roboport = creeper.roboport
	local surface  = roboport.surface

	if surface.count_tiles_filtered { area = creep_data["area"], has_hidden_tile = false, collision_mask = surface.get_tile(roboport.position).prototype.collision_mask } == 0 then
		if creep_data["current_radius"] < creep_data["target_creep_radius"] then
			creeper.radius = math.min(creeper.radius + 1, roboport.logistic_cell.construction_radius)
		else
			local switch = true

			if #upgrade_target_types > 0 and surface.count_tiles_filtered { name = upgrade_target_types, area = creep_data["area"], limit = 1 } > 0 then
				switch = false
			end
			if switch then
				creeper.off             = true
				creeper.removal_counter = 1
				global.active_creepers  = global.active_creepers - 1
			else
				creeper.radius  = 3 --Reset radius and switch to upgrade mode.
				creeper.upgrade = true
			end
		end
	end
end

function build_tile(roboport, type, position)
	local count   = 0;
	local surface = roboport.surface
	local force   = roboport.force

	if surface.can_place_entity { name = "tile-ghost", position = position, inner_name = type, force = force } then
		surface.create_entity { name = "tile-ghost", position = position, inner_name = type, force = force, expires = false }
		count = count + 1
	else
		return count
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

	return count
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
		count_active_creepers()
	end
end

function addPort(roboport)
	local surface = roboport.surface

	-- Capture the pattern the roboport sits on.
	local pattern = {}
	local it      = {}
	for xx = -2, 1, 1 do
		pattern[xx + 3] = {}
		it[xx + 3]      = {}
		for yy = -2, 1, 1 do
			local tile = surface.get_tile(roboport.position.x + xx, roboport.position.y + yy)
			if (tile.hidden_tile and tile.prototype.items_to_place_this) and not (tile.name == "stone-path" or tile.name == "concrete" or tile.name == "refined-concrete") then
				it[xx + 3][yy + 3]      = tile.prototype.items_to_place_this[1] and game.item_prototypes[tile.prototype.items_to_place_this[1].name] and tile.prototype.items_to_place_this[1].name
				pattern[xx + 3][yy + 3] = tile.name
			end
		end
	end

	table.insert(global.creepers,
				 { roboport = roboport, radius = 3, pattern = pattern, item = it, off = false, removal_counter = 0 })
end

function count_active_creepers()
	global.active_creepers = 0

	for i = #global.creepers, 1, -1 do
		if global.creepers[i].off == false then
			global.active_creepers = global.active_creepers + 1
		end
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
script.on_configuration_changed(init)
