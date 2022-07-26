MINIMUM_ROBOTS = 30
MINIMUM_ITEM_COUNT = 200

NO_WORK_UPDATES_BEFORE_REINIT = 60
SURFACES_PER_REINIT_PASS = 1
ROBOPORTS_PER_REINIT_PASS = 1

-- how many ups between creeper updates
RUN_EVERY_N_UPDATES = 60
-- how many creepers to creep per update run
CREEPERS_PER_UPDATE = 5
INITIAL_RADIUS = 1

DEBUG_PREFIX = "Concreep: "

function array_concat(t1, t2)
	local t3 = {}
	for i=1, #t1 do
		t3[i] = t1[i]
	end
	for i=1, #t2 do
		t3[#t1 + i] = t2[i]
	end
	return t3
end

function array_shallowcopy(source)
	local dest = {}
	for i=1, #source do
		dest[i] = source[i]
	end
	return dest
end

function debug_print(message)
	if settings.global["debug"].value then
		game.print(DEBUG_PREFIX .. message)
	end
end

function debug_print_function_was_called(function_name)
	if settings.global["debug function calls"].value then
		game.print(DEBUG_PREFIX .. " function called: " .. function_name)
	end
end

function debug_print_coroutine_was_called(function_name)
	if settings.global["debug coroutine calls"].value then
		game.print(DEBUG_PREFIX .. " coroutine function called: " .. function_name)
	end
end

function init()
	debug_print_function_was_called("init()")

	global.creepers = {}
	global.creeper_index = 1
	global.robots_given_instructions = 0

	global.no_work_counter = 0
	global.reinit_surfaces = {}
	global.reinit_surface_index = 1
	global.reinit_current_surface_roboports = {}
	global.reinit_current_surface_roboport_index = 1
	global.reinit_level_running = 0

	for each, surface in pairs(game.surfaces) do
		local roboports = surface.find_entities_filtered{type="roboport"}
		for index, port in pairs(roboports) do
			if is_valid_roboport(port) then
				add_creeper_for_roboport(port)
			end
		end
	end
end

-- a fake coroutine
function reinit()
	debug_print_coroutine_was_called("reinit()")

	-- bookeeping to make sure all our vars exist
	if not global.creepers then
		global.creepers = {}
	end
	if not global.creeper_index then
		global.creeper_index = 1
	end
	if not global.robots_given_instructions then
		global.robots_given_instructions = 0
	end

	if not global.no_work_counter then
		global.no_work_counter = 0
	end
	if not global.reinit_surfaces then
		global.reinit_surfaces = {}
	end
	if not global.reinit_surface_index then
		global.reinit_surface_index = 1
	end
	if not global.reinit_current_surface_roboports then
		global.reinit_current_surface_roboports = {}
	end
	if not global.reinit_current_surface_roboport_index then
		global.reinit_current_surface_roboport_index = 1
	end
	if not global.reinit_level_running then
		global.reinit_level_running = 0
	end

	-- okay, do the real work now
	_reinit_reentrant()
end

function _reinit_reentrant()
	debug_print_coroutine_was_called("_reinit_reentrant()")

	debug_print("global.reinit_level_running: " .. global.reinit_level_running)

	-- figure out which level of the loop we need to do work in
	if global.reinit_level_running == 0 then
		-- no loops running, check if we should start outer loop
		global.no_work_counter = global.no_work_counter + 1
		if global.no_work_counter >= NO_WORK_UPDATES_BEFORE_REINIT then
			_reinit_reentrant_level1_start()
		end
	elseif global.reinit_level_running == 1 then
		-- outer loop is running, call its body
		_reinit_reentrant_level1_body()
	elseif global.reinit_level_running == 2 then
		-- inner loop is running, call its body
		_reinit_reentrant_level2_body()
	end
end

function _reinit_reentrant_level1_start()
	debug_print_coroutine_was_called("_reinit_reentrant_level1_start()")
	-- initialize outer loop

	-- declare that outer loop is running
	global.reinit_level_running = 1

	-- clear the counter so that it is ready for later
	global.no_work_counter = 0

	-- set up outer arrays to iterate
	global.reinit_surfaces = array_shallowcopy(game.surfaces)
	global.reinit_surface_index = 1
	global.reinit_current_surface_roboports = {}
	global.reinit_current_surface_roboport_index = 1

	debug_print("initial: global.reinit_surface_index: " .. global.reinit_surface_index .. " #global.reinit_surfaces: " .. #global.reinit_surfaces)

	-- do first iteration
	_reinit_reentrant_level1_body()
end

function _reinit_reentrant_level1_body()
	debug_print_coroutine_was_called("_reinit_reentrant_level1_body()")

	-- pseudo: for global.reinit_surface_index, #global.reinit_surfaces do
		-- -- limit how many surfaces checked per call
		-- for pass_index = 1, SURFACES_PER_REINIT_PASS do
			-- bounds check
			debug_print("global.reinit_surface_index: " .. global.reinit_surface_index .. " #global.reinit_surfaces: " .. #global.reinit_surfaces)

			if global.reinit_surface_index <= #global.reinit_surfaces then
				-- make sure surface is still valid
				local surface = global.reinit_surfaces[global.reinit_surface_index]
				if (
					surface and
					surface.valid
				) then
					_reinit_reentrant_level2_start(surface)
				else
					-- degenerate case, this is what increments the outer index
					_reinit_reentrant_level2_end()
				end
			end
			-- if we got here:
			--  - we either exhausted the list of surfaces (so return true) or
			--  - we reached SURFACES_PER_REINIT_PASS for this call (so return false)
			if global.reinit_surface_index > #global.reinit_surfaces then
				_reinit_reentrant_level1_end()
			end
		-- end
	-- pseudo: end
end

function _reinit_reentrant_level1_end()
	debug_print_coroutine_was_called("_reinit_reentrant_level1_end()")

	global.reinit_level_running = 0
end

function _reinit_reentrant_level2_start(surface)
	debug_print_coroutine_was_called("_reinit_reentrant_level2_start()")

	-- initialize inner loop

	-- declare that inner loop is running
	global.reinit_level_running = 2

	global.reinit_current_surface_roboports = array_shallowcopy(surface.find_entities_filtered{type="roboport"})
	global.reinit_current_surface_roboport_index = 1

	-- do first iteration
	_reinit_reentrant_level2_body()
end

function _reinit_reentrant_level2_body()
	debug_print_coroutine_was_called("_reinit_reentrant_level2_body()")

	-- psuedo: for global.reinit_current_surface_roboport_index, #global.reinit_current_surface_roboports do
		-- limit how many roboports checked per call
		for pass_index = 1, ROBOPORTS_PER_REINIT_PASS do
			-- bounds check
			if global.reinit_current_surface_roboport_index <= #global.reinit_current_surface_roboports then
				-- make sure roboport is still valid
				local roboport = global.reinit_current_surface_roboports[global.reinit_current_surface_roboport_index]
				if (
					roboport and
					roboport.valid
				) then
					add_creeper_for_roboport(roboport)
				end
				-- need to manually increment
				global.reinit_current_surface_roboport_index = global.reinit_current_surface_roboport_index + 1
			end
		end
		-- if we got here:
		--  - we either exhausted the list of roboports (so return true) or
		--  - we reached ROBOPORTS_PER_REINIT_PASS (so return false)
		if global.reinit_current_surface_roboport_index > #global.reinit_current_surface_roboports then
			_reinit_reentrant_level2_end()
		end
	-- pseudo: end
end

function _reinit_reentrant_level2_end()
	debug_print_coroutine_was_called("_reinit_reentrant_level2_end()")

	global.reinit_level_running = 1

	-- need to manually increment outer loop as the inner loop ends
	global.reinit_surface_index = global.reinit_surface_index + 1
end

function creepers_update()
	debug_print_function_was_called("creepers_update()")

	-- Iterate over up to 5 entities
	if #global.creepers == 0 or global.reinit_level_running > 0 then
		reinit()
		return
	end
	for i = 1, CREEPERS_PER_UPDATE do
		-- bounds check, early bail
		if i > #global.creepers then
            return
        end

		local creeper = get_creeper()
		if creeper ~= nil then
			local roboport = creeper.roboport
			if (
				is_valid_roboport(roboport) and
				is_roboport_powered_up(roboport)
			) then
				creep(creeper)
			end
		else
			debug_print("creeper removed")
		end
    end
end

function get_creeper()
	debug_print_function_was_called("get_creeper()")

	if global.creeper_index > #global.creepers then
		global.creeper_index = 1
	end
	local creeper = global.creepers[global.creeper_index]
	if not (creeper.roboport and creeper.roboport.valid) or creeper.off then --Roboport removed
		table.remove(global.creepers, global.creeper_index)
		return nil
	end
	global.creeper_index = global.creeper_index + 1
	return creeper
end

function creep(creeper)
	debug_print_function_was_called("creep()")

	local roboport = creeper.roboport
	local surface = roboport.surface
	local force = roboport.force
	local radius = math.min(creeper.radius, settings.global["concreep range"].value * roboport.logistic_cell.construction_radius / 100)
	local idle_robots = roboport.logistic_network.available_construction_robots / 2
	local count = 0
	--if roboport.logistic_network.get_item_count("concrete") > 0 then
		-- local rando = math.random(-radius, radius) -- Pick a random point along the circumference.
		-- Need to offset up and left as +radius is outside of the actual radius.
	local area = {{roboport.position.x - radius, roboport.position.y - radius}, {roboport.position.x + radius, roboport.position.y + radius}}
	debug_print("X: " .. roboport.position.x)
	debug_print("Y: " .. roboport.position.y)
	debug_print("Rad: " .. radius)
	local ghosts = surface.count_entities_filtered{area=area, name="tile-ghost", force=force}

	if force.max_successful_attempts_per_tick_per_construction_queue * 60 < idle_robots then
		force.max_successful_attempts_per_tick_per_construction_queue = math.floor(idle_robots / 60)
	end

	local refined_concrete_count = math.max(0, roboport.logistic_network.get_item_count("refined-concrete") - MINIMUM_ITEM_COUNT)
	local concrete_count = math.max(0, roboport.logistic_network.get_item_count("concrete") - MINIMUM_ITEM_COUNT)
	local brick_count = math.max(0, roboport.logistic_network.get_item_count("stone-brick") - MINIMUM_ITEM_COUNT)
	local landfill_count = math.max(0, roboport.logistic_network.get_item_count("landfill") - MINIMUM_ITEM_COUNT)

	debug_print(
		" brick: " .. brick_count ..
		" concrete: " .. concrete_count ..
		" refined: " .. refined_concrete_count ..
		" landfill: " .. landfill_count
	)

	local function build_tile(type, position)
		debug_print_function_was_called("build_tile()")
		if surface.can_place_entity{name="tile-ghost", position=position, inner_name=type, force=force} then
			debug_print("can place " .. type)
			surface.create_entity{name="tile-ghost", position=position, inner_name=type, force=force, expires=false}
			count = count + 1
		else
			debug_print("can NOT place " .. type)
			return
		end
		local tree_area = {{position.x - 0.2,  position.y - 0.2}, {position.x + 0.8, position.y + 0.8}}
		for i, tree in pairs(surface.find_entities_filtered{type = "tree", area=tree_area}) do
			tree.order_deconstruction(roboport.force)
			count = count + 1
		end
		for i, rock in pairs(surface.find_entities_filtered{type = "simple-entity", area=tree_area}) do
			rock.order_deconstruction(roboport.force)
			count = count + 1
		end
		for i, cliff in pairs(surface.find_entities_filtered{type = "cliff", limit=1, area=tree_area}) do
			if roboport.logistic_network.get_item_count("cliff-explosives") > 0 then
				cliff.order_deconstruction(roboport.force)
				count = count + 1
				--roboport.logistic_network.remove_item({name="cliff-explosives", 1})
			end
		end
	end

	debug_print("checking for coverable tiles with radius " .. radius)

	local coverable_tiles = surface.find_tiles_filtered{has_hidden_tile=false, area=area, limit=idle_robots, collision_mask="ground-tile"}

	local landfill_tiles = {}
	if settings.global["cover landfill"].value then
		debug_print("checking for coverable landfill")
		if count < landfill_count and landfill_count > 0 then
			landfill_tiles = surface.find_tiles_filtered{name={"landfill", "unbreakable-landfill", "unbreakable-landfill-2"}, area=area, limit=idle_robots}
		else
			debug_print("not enough landfill")
		end
	end
	debug_print("initial coverable tiles: " .. #coverable_tiles .. " + landfill tiles:  " .. #landfill_tiles)

	coverable_tiles = array_concat(coverable_tiles, landfill_tiles)

	debug_print("total coverable tiles: " .. #coverable_tiles)
	-- water-mud, water-shallow, deepwater-green, water-green, deepwater, water,

	--Wait for ghosts to finish building first.
	if ghosts > #coverable_tiles then
		debug_print("Found some work to do.  Terminating early.")
		return true
	end

	--attempt to cover tiles
	for i = #coverable_tiles, 1, -1 do
		local ghost_type
		-- If we have enough refined concrete, use that.
		if count < refined_concrete_count and settings.global["creep refined concrete"].value then
			ghost_type = "refined-concrete"
		-- If not, use regular concrete
		elseif count < concrete_count and settings.global["creep regular concrete"].value then
			ghost_type = "concrete"
		--If not, use a stone path.
		elseif count < brick_count and settings.global["creep brick"].value then
			ghost_type = "stone-path"
		end
		if ghost_type then
			debug_print("using " .. ghost_type .. " for cover")
			build_tile(ghost_type, coverable_tiles[i].position)
		else
			debug_print("no available items to cover with")
		end
	end

	if count >= idle_robots then
		debug_print("Found some work to do.  Terminating early.")
		return true
	end

	local upgrade_target_types = {}
	if (
		settings.global["upgrade brick"].value and
		(
			(
				settings.global["creep regular concrete"].value and
				concrete_count > 0
			) or
			(
				settings.global["creep refined concrete"].value and
				refined_concrete_count > 0
			)
		)
	) then
		table.insert(upgrade_target_types, "stone-path")
	end
	if (
		settings.global["upgrade concrete"].value and
		settings.global["creep refined concrete"].value and
		refined_concrete_count > 0
	) then
		table.insert(upgrade_target_types, "concrete")
		table.insert(upgrade_target_types, "hazard-concrete-left")
		table.insert(upgrade_target_types, "hazard-concrete-right")
	end

	--Still here?  Look for concrete to upgrade
	if creeper.upgrade then
		debug_print("checking for tiles to upgrade")

		if #upgrade_target_types > 0 then
			local upgrade_targets = surface.find_tiles_filtered{area=area, name=upgrade_target_types, limit=math.min( math.max(concrete_count, refined_concrete_count, 0), idle_robots)}
			debug_print("#upgrade_targets: " .. #upgrade_targets)
			for k, v in pairs(upgrade_targets) do
				local tile_type
				if settings.global["creep refined concrete"].value then
					debug_print("will upgrade to refined concrete")
					tile_type = "refined-concrete"
					if v.name == "hazard-concrete-left" then
						tile_type = "refined-hazard-concrete-left"
					elseif v.name == "hazard-concrete-right" then
						tile_type = "refined-hazard-concrete-right"
					elseif (
						count >= refined_concrete_count and
						settings.global["creep regular concrete"].value
					) then
						debug_print("not enough refined concrete")
						if concrete_count > 0 then
							debug_print("will upgrade to regular conrete")
							tile_type = "concrete"
						else
							debug_print("not enough conrete")
						end
					end
				elseif settings.global["creep regular concrete"].value then
					debug_print("will upgrade to regular concrete")
					if concrete_count > 0 then
						tile_type = "concrete"
					else
						debug_print("not enough concrete")
					end
				end
				if tile_type then
					debug_print("using " .. tile_type .. " to upgrade")
					build_tile(tile_type, v.position)
				end
			end

			if count >= idle_robots then
				debug_print("Found some work to do.  Terminating early.")
				return true
			end
		else
			debug_print("No potential upgrade types defined.")
		end
	else
		debug_print("Not in upgrade mode, skipping upgrades.")
	end

	-- Alright, how about water to fill in?
	if settings.global["creep landfill"].value then
		debug_print("checking for water to fill")
		local water_tiles = surface.find_tiles_filtered{area=area, collision_mask="water-tile"}
		--Wait for ghosts to finish building first.
		if ghosts > #water_tiles then
			debug_print("Found some work to do.  Terminating early.")
			return true
		end
		if landfill_count > 0 then
			for k,v in pairs(water_tiles) do
				debug_print("Place land!")
				surface.create_entity{name="tile-ghost", position=v.position, inner_name="landfill", force=roboport.force}
			end
		else
			debug_print("not enough landfill")
		end
	end

	--Still here?  Check to see if the roboport should turn off.
	local still_coverable_tile_count = surface.count_tiles_filtered{area=area, has_hidden_tile=false, collision_mask="ground-tile"}
	debug_print("still_coverable_tile_count: " .. still_coverable_tile_count)
	if settings.global["cover landfill"].value then
		local coverable_landfill = surface.count_tiles_filtered{name={"landfill", "unbreakable-landfill", "unbreakable-landfill-2"}, area=area, limit=idle_robots}
		debug_print("coverable_landfill: " .. coverable_landfill)
		still_coverable_tile_count = still_coverable_tile_count + coverable_landfill
	end
	if settings.global["creep landfill"].value and landfill_count > 0 then
		local coverable_water = surface.count_tiles_filtered{collision_mask="water-tile", area=area}
		debug_print("coverable_water: " .. coverable_water)
		still_coverable_tile_count = still_coverable_tile_count + coverable_water
	end
	debug_print("still_coverable_tile_count (total): " .. still_coverable_tile_count)

	if still_coverable_tile_count == 0 then --and
		debug_print("Increase radius! Current radius: " .. radius)
		if radius < roboport.logistic_cell.construction_radius * settings.global["concreep range"].value / 100 then
			debug_print("Logistic cell construction radius: " .. roboport.logistic_cell.construction_radius)
			creeper.radius = math.min(creeper.radius + 1, roboport.logistic_cell.construction_radius) -- Todo for next version
			debug_print("New radius: " .. creeper.radius)
		else
			if #upgrade_target_types > 0 and surface.count_tiles_filtered{name=upgrade_target_types, area=area, limit=1} > 0 then
				creeper.radius = INITIAL_RADIUS --Reset radius and switch to upgrade mode.
				creeper.upgrade = true
			else
				creeper.off = true
				debug_print("Removing creeper")
			end
		end
	end
	return false
end

--Is this a valid roboport?
function is_valid_roboport(entity)
	debug_print_function_was_called("is_valid_roboport()")
	if (
		entity and
		entity.valid and
		entity.type == "roboport" and
		entity.logistic_cell and
		entity.logistic_cell.construction_radius > 0 and
		entity.logistic_network and
		entity.logistic_network.valid
	) then
		debug_print("Valid Roboport")
		return true
	end
	debug_print("Invalid Roboport")
	return false
end

function is_roboport_powered_up(roboport)
	if roboport.prototype.electric_energy_source_prototype then
		if roboport.prototype.electric_energy_source_prototype.buffer_capacity == roboport.energy then
			return true
		end
	else
		-- TODO: non energy source check? seems not possible?
		return true
	end
	return false
end

function on_built_entity_handler(event)
	debug_print_function_was_called("on_built_entity_handler()")

	local entity = event.created_entity or event.destination or event.entity
	if not global.creepers then
		init()
	end
	if is_valid_roboport(entity) then
		add_creeper_for_roboport(entity)
	end
end

function add_creeper_for_roboport(roboport)
	debug_print_function_was_called("add_creeper_for_roboport")

	local surface = roboport.surface

	table.insert(global.creepers, {roboport = roboport, radius = INITIAL_RADIUS})
end

function is_valid_roboport_tile_names()
	debug_print_function_was_called("is_valid_roboport_tile_names()")

	for i = #global.creepers, 1, -1 do
		local creep = global.creepers[i]
		if creep.roboport.valid then
			add_creeper_for_roboport(creep.roboport)
		end
		table.remove(global.creepers, i)
	end
end

script.on_event(
	{
		defines.events.on_built_entity,
		defines.events.on_robot_built_entity,
		defines.events.on_entity_cloned,
		defines.events.script_raised_built,
		defines.events.script_raised_revive
	},
	on_built_entity_handler
)
script.on_nth_tick(RUN_EVERY_N_UPDATES, creepers_update)
script.on_init(init)
script.on_configuration_changed(is_valid_roboport_tile_names)
