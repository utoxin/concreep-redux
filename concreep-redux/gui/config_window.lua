function gui_init()
	-- Nothing to do here?
end

local function toggle_interface(player)
	local main_frame = player.gui.screen.ccr_config_window

	if main_frame == nil then
		build_interface(player)
	else
		main_frame.destroy()
	end
end

function build_interface(player)
	local screen_element = player.gui.screen
	local main_frame = screen_element.add{type="frame", name="ccr_config_window", caption={"ccr.config_window_caption"}}

	local outer_frame_1 = main_frame.add{type="frame", name="outer_frame_1", direction="horizontal", style="ccr_content_frame"}
	local tile_list_frame = outer_frame_1.add{type="frame", name="tile_list_frame", direction="vertical", style="ccr_content_frame", caption="Tile Priority"}
	local settings_frame = outer_frame_1.add{type="frame", name="settings_frame", direction="vertical", style="ccr_content_frame", caption="Settings"}

	main_frame.style.size = {800, 600}
	main_frame.auto_center = true

	build_tile_list_frame(tile_list_frame)

	player.opened = main_frame
end

function build_tile_list_frame(tile_list_frame)
	tile_list_frame.clear()

	local main_vertical_flow = tile_list_frame.add{type="flow", direction="vertical"}

--	local horizontal_flow = main_vertical_flow.add{type="frame", style="tile_list_row"}
--	horizontal_flow.add{type="choose-elem-button", elem_type="item", elem_filters={{filter="place-as-tile"}}}

	build_tile_list_row(tile_list_frame)
	build_tile_list_row(tile_list_frame)
	build_tile_list_row(tile_list_frame)
	build_tile_list_row(tile_list_frame)
	build_tile_list_row(tile_list_frame)
	build_tile_list_row(tile_list_frame)
	build_tile_list_row(tile_list_frame)
	build_tile_list_row(tile_list_frame)
end

function build_tile_list_row(tile_list_frame)
	local row_frame = tile_list_frame.add{type="frame", direction="horizontal", style="ccr_tile_list_row"}

	row_frame.add{type="choose-elem-button", elem_type="item", elem_filters={{filter="place-as-tile"}}}
	row_frame.add{type="empty-widget", elem_type="filler", style="ccr_tile_list_draghandle"}
end

script.on_event(defines.events.on_gui_click, function (event)
	if event.element.name == "ccr_controls_toggle" then
		local player_global = global.players[event.player_index]
		player_global.controls_active = not player_global.controls_active

		local control_toggle = event.element
		control_toggle.caption = (player_global.controls_active) and {"ccr.deactivate"} or {"ccr.activate"}
	end
end)

script.on_event(defines.events.on_gui_closed, function(event)
	if event.element and event.element.name == "ccr_config_window" then
		local player = game.get_player(event.player_index)
		toggle_interface(player)
	end
end)

script.on_event("concreep_toggle_interface", function(event)
	local player = game.get_player(event.player_index)
	toggle_interface(player)
end)