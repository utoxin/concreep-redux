if script.active_mods["gvv"] then
	require("__gvv__.gvv")()
end

require('logic.creep_logic')
require('gui.config_window')

function init()
	gui_init()
	creep_init()
end

script.on_init(init)