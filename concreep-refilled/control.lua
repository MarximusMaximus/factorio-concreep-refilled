DEBUG_PREFIX = "Concreep: "
pole_type="big-electric-pole" -- having this here for a future idea - let user chose what pole to use -> base the interval of the poles on the wire distance max of that pole type
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
	global.robots_given_instructions = 0 --not used atm - what was the intention here?

	global.no_work_counter = 0
	global.reinit_surfaces = {}
	global.reinit_surface_index = 1
	global.reinit_current_surface_roboports = {}
	global.reinit_current_surface_roboport_index = 1
	global.reinit_level_running = 0
	global.placed_poles_positions = {}
	global.placed_roboports_positions = {}

end

function hypercreep_builder(target_robo_pos_x,target_robo_pos_y,offset,roboport,pole_type)
	debug_print_coroutine_was_called("hypercreep_builder()")
	local surface = roboport.surface
	local force = roboport.force
	local roboport_x_pos = roboport.position.x
	local roboport_y_pos = roboport.position.y
	local half_distance_x = math.floor((target_robo_pos_x-roboport_x_pos)/2)
	local half_distance_y = math.floor((target_robo_pos_y-roboport_y_pos)/2)
	local target_pole_pos_y = target_robo_pos_y+offset
	local target_pole_pos_y_minus_half_dist = target_robo_pos_y-half_distance_y+offset
	local target_pole_pos_x_minus_half = target_robo_pos_x-half_distance_x
	local function has_value (t, v)
		for i=1,#t do
			if t[i] == v then
				return true
			end
		end
		return false
	end
	local function clear_obstructions(x,y,radius)
		local tree_area = {{x - radius, y-radius}, {x + radius, y+radius}}
		for i, tree in pairs(surface.find_entities_filtered{type = "tree", area=tree_area}) do
			tree.order_deconstruction(roboport.force)
		end
		for i, rock in pairs(surface.find_entities_filtered{type = "simple-entity", area=tree_area}) do
			rock.order_deconstruction(roboport.force)
		end
		for i, cliff in pairs(surface.find_entities_filtered{type = "cliff", limit=1, area=tree_area}) do -- maybe you can answer this -> is this limit required here? I dont think so?
			if roboport.logistic_network.get_item_count("cliff-explosives") > 0 then
				cliff.order_deconstruction(roboport.force)
			end
		end
	end

	-- this will make sure, that even if paving area isn't large enough to cover the future roboport and poles position we still will be able to place them if we can get rid of obstacles
	if settings.global["concreep range"].value * roboport.logistic_cell.construction_radius / 100 < roboport.logistic_cell.logistic_radius+3 then -- +3 can be changed to roboport.tile_width once we demand version 1.1.64
		clear_obstructions(target_robo_pos_x, target_robo_pos_y,4) -- clearing area for roboport
		clear_obstructions(target_robo_pos_x,target_pole_pos_y_minus_half_dist,2) -- clearing area for power pole y axis
		clear_obstructions(target_pole_pos_x_minus_half,target_pole_pos_y,2) -- clearing area for power pole x axis
	end
	-- cant build in uncharted areas
	local chart_radius = settings.global["concreep range"].value * roboport.logistic_cell.construction_radius / 100
	force.chart(surface, {{target_robo_pos_x            - chart_radius, target_robo_pos_y - chart_radius}                 , {target_robo_pos_x            + chart_radius, target_robo_pos_y                 + chart_radius}})
	force.chart(surface, {{target_robo_pos_x            - chart_radius, target_pole_pos_y_minus_half_dist - chart_radius} , {target_robo_pos_x            + chart_radius, target_pole_pos_y_minus_half_dist	+ chart_radius}})
	force.chart(surface, {{target_pole_pos_x_minus_half - chart_radius, target_robo_pos_y - chart_radius}                 , {target_pole_pos_x_minus_half + chart_radius, target_robo_pos_y                 + chart_radius}})

	if (
		surface.can_place_entity{name="entity-ghost", position={target_robo_pos_x,target_robo_pos_y}, inner_name=roboport.name, force=force} and
		surface.can_place_entity{name="entity-ghost", position={target_robo_pos_x,target_pole_pos_y}, inner_name=pole_type    , force=force} and
		has_value(global.placed_roboports_positions,           {target_robo_pos_x,target_robo_pos_y}) == false and
		has_value(global.placed_poles_positions,               {target_robo_pos_x,target_pole_pos_y}) == false -- doing this as the game does place multiple power poles on top of each other (and roboports), if we do it all in one frame - not entirely sure how to circumvent that any other way than this
	) then
		surface.create_entity{name="entity-ghost", position={target_robo_pos_x, target_robo_pos_y}, inner_name=roboport.name, force=force, expires=false}
		table.insert(global.placed_roboports_positions,     {target_robo_pos_x, target_robo_pos_y})
		surface.create_entity{name="entity-ghost", position={target_robo_pos_x, target_pole_pos_y}, inner_name=pole_type    , force=force, expires=false}
		table.insert(global.placed_poles_positions,         {target_robo_pos_x, target_pole_pos_y})
	end
	
	if (target_robo_pos_y ~= roboport_y_pos) then -- we are expanding vertically
		if (
			surface.can_place_entity{name="entity-ghost", position={target_robo_pos_x,target_pole_pos_y_minus_half_dist}, inner_name=pole_type, force=force} and not
			has_value(global.placed_poles_positions,               {target_robo_pos_x,target_pole_pos_y_minus_half_dist})
		) then
			surface.create_entity{name="entity-ghost", position={target_robo_pos_x,target_pole_pos_y_minus_half_dist}   , inner_name=pole_type, force=force, expires=false}
			table.insert(global.placed_poles_positions,         {target_robo_pos_x,target_pole_pos_y_minus_half_dist}) -- we are expanding vertically, placing an additional power pole in between original roboport and new roboport
		end
	end
	if (target_robo_pos_x ~= roboport_x_pos) then -- no we repeat everything if we had expanded horizontaly
		if (
			surface.can_place_entity{name="entity-ghost", position={target_pole_pos_x_minus_half,target_pole_pos_y}     , inner_name=pole_type, force=force} and not
			has_value(global.placed_poles_positions,               {target_pole_pos_x_minus_half,target_pole_pos_y})
		) then
			surface.create_entity{name="entity-ghost", position={target_pole_pos_x_minus_half,target_pole_pos_y}        , inner_name=pole_type, force=force, expires=false}
			table.insert(global.placed_poles_positions,         {target_pole_pos_x_minus_half,target_pole_pos_y}) -- we are expanding horizontaly, placing an additional power pole in between original roboport and new roboport
		end
	end
end

function hypercreep(roboport)
	debug_print_function_was_called("hypercreep")

	if not global.placed_poles_positions then
		global.placed_poles_positions = {}
	end
	if not global.placed_roboports_positions then
		global.placed_roboports_positions = {}
	end -- this is temporary, if we merged and updated version number, this wont be necessary, just used for testing so old saves dont crash

	local roboport_item_count = roboport.logistic_network.get_item_count("roboport")
	local power_pole_item_count = roboport.logistic_network.get_item_count(pole_type)
	if (roboport_item_count < 4 or power_pole_item_count < 4) then
		debug_print("Not enough roboports/power poles to hyprecreep")
		return
	end
	local offset_power_poles = 3
	local logistic_diameter = roboport.logistic_cell.logistic_radius * 2
	local roboport_x = roboport.position.x
	local roboport_y = roboport.position.y
	hypercreep_builder(roboport_x + logistic_diameter, roboport_y                    , offset_power_poles, roboport, pole_type)
	hypercreep_builder(roboport_x - logistic_diameter, roboport_y                    , offset_power_poles, roboport, pole_type)
	hypercreep_builder(roboport_x                    , roboport_y + logistic_diameter, offset_power_poles, roboport, pole_type)
	hypercreep_builder(roboport_x                    , roboport_y - logistic_diameter, offset_power_poles, roboport, pole_type)
	hypercreep_builder(roboport_x + logistic_diameter, roboport_y + logistic_diameter, offset_power_poles, roboport, pole_type)
	hypercreep_builder(roboport_x - logistic_diameter, roboport_y - logistic_diameter, offset_power_poles, roboport, pole_type)
	hypercreep_builder(roboport_x + logistic_diameter, roboport_y - logistic_diameter, offset_power_poles, roboport, pole_type)
	hypercreep_builder(roboport_x - logistic_diameter, roboport_y + logistic_diameter, offset_power_poles, roboport, pole_type)
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
	if not global.placed_poles_positions then
		global.placed_poles_positions = {}
	end
	if not global.placed_roboports_positions then
		global.placed_roboports_positions = {}
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
		if global.no_work_counter >= settings.global["no work updates before reinit"].value then
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
		-- -- limit how many settings.global["surfaces per reinit pass"].value checked per call
		-- for pass_index = 1, settings.global["surfaces per reinit pass"].value do
			-- bounds check
			debug_print("global.reinit_surface_index: " .. global.reinit_surface_index .. " #global.reinit_surfaces: " .. #global.reinit_surfaces)
			if global.reinit_surface_index <= #global.reinit_surfaces then
				-- make sure surface is still valid
				local surface = global.reinit_surfaces[global.reinit_surface_index]
				local name = ""
				for str in settings.global["allowed surfaces"].value:gmatch("([^,]+)") do
					name = str:gsub("%s+", "")
					if (
						name and
						surface and
						surface.valid and
						surface.name==name
					) then
						_reinit_reentrant_level2_start(surface)
					else
						-- degenerate case, this is what increments the outer index
						_reinit_reentrant_level2_end()
					end
				end

			end
			-- if we got here:
			--  - we either exhausted the list of settings.global["allowed surfaces"].value (so return true) or
			--  - we reached settings.global["surfaces per reinit pass"] for this call (so return false)
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
		for pass_index = 1, settings.global["roboports per reinit pass"].value do
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
		--  - we reached settings.global["roboports per reinit pass"] (so return false)
		if global.reinit_current_surface_roboport_index > #global.reinit_current_surface_roboports then
			_reinit_reentrant_level2_end()
		end
	-- pseudo: end
end

function _reinit_reentrant_level2_end()
	debug_print_coroutine_was_called("_reinit_reentrant_level2_end()")
	global.placed_poles_positions = {}
	global.placed_roboports_positions = {} -- reset list of placed poles and roboports so the array of positions doesnt get to big, and we shouldnt need the old positions anymore
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
	for i = 1, settings.global["creepers per update"].value do
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
	debug_print("Surface: " .. roboport.surface.name)

	local ghosts = surface.count_entities_filtered{area=area, name="tile-ghost", force=force}
	debug_print("# of Ghosts: " .. ghosts)
	if force.max_successful_attempts_per_tick_per_construction_queue * 60 < idle_robots then
		force.max_successful_attempts_per_tick_per_construction_queue = math.floor(idle_robots / 60)
	end
	local refined_concrete_count = math.max(0, roboport.logistic_network.get_item_count("refined-concrete") - settings.global["minimum item"].value)
	local concrete_count = math.max(0, roboport.logistic_network.get_item_count("concrete") - settings.global["minimum item"].value)
	local brick_count = math.max(0, roboport.logistic_network.get_item_count("stone-brick") - settings.global["minimum item"].value)
	local landfill_count = math.max(0, roboport.logistic_network.get_item_count("landfill") - settings.global["minimum item"].value)
	debug_print(
		" brick: " .. brick_count ..
		" concrete: " .. concrete_count ..
		" refined: " .. refined_concrete_count ..
		" landfill: " .. landfill_count
	)
	local available_worker_count = math.max(0, roboport.logistic_network.available_construction_robots - settings.global["minimum robot"].value)
	if roboport.logistic_network.available_construction_robots <= settings.global["minimum robot"].value then
		debug_print("can NOT place - minimum robots")
		return
	end

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
				creeper.radius = settings.global["initial radius"].value --Reset radius and switch to upgrade mode.
				creeper.upgrade = true
			else
				if settings.global["hypercreep"].value then
					hypercreep(roboport)
				end
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
	table.insert(global.creepers, {roboport = roboport, radius = settings.global["initial radius"].value})
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
	global.placed_poles_positions = {}
	global.placed_roboports_positions = {} -- adding this here as this function is called via script.on_configuration_changed; meaning it will be called when we update, otherwise old saves will crash due to globals being nil
	global.placed_roboports_positions = {}
end

function runtime_settings_changed()
	debug_print_function_was_called("runtime_settings_changed()")
	local listOfSurfaces = {}
	local name = ""
	for str in settings.global["allowed surfaces"].value:gmatch("([^,]+)") do
		name = str:gsub("%s+", "")
		if name and game.surfaces[name].valid then
			table.insert(listOfSurfaces, game.surfaces[name])
		end
	end
	if listOfSurfaces == {} then
		settings.global["surfaces"] = {value = "nauvis"} --if we didn't have any valid surfaces then we set the settings back to nauvis
		game.print("No valid surfaces found, using Nauvis as default. Please check your settings!")
	end
	script.on_nth_tick(nil) --unregister all nth tick handlers, so we can update the interval n script.on_nth_tick(settings.global["run every n updates"].value, creepers_update)
	if settings.global["run every n updates"].value ~= 0 then
		script.on_nth_tick(settings.global["run every n updates"].value, creepers_update)
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
script.on_init(init)
script.on_configuration_changed(is_valid_roboport_tile_names)
script.on_event(defines.events.on_runtime_mod_setting_changed, runtime_settings_changed)
script.on_nth_tick(nil) --unregister all nth tick handlers, so we can update the interval n script.on_nth_tick(settings.global["run every n updates"].value, creepers_update)
if settings.global["run every n updates"].value ~= 0 then
	script.on_nth_tick(settings.global["run every n updates"].value, creepers_update)
end
