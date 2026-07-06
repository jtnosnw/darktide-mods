return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`gelatos_buff_manager` requires the Darktide Mod Framework.")

		local MOD_DATA_PATH = "gelatos_buff_manager/scripts/mods/gelatos_buff_manager/gelatos_buff_manager_data"

		local mod = new_mod("gelatos_buff_manager", {
			mod_script       = "gelatos_buff_manager/scripts/mods/gelatos_buff_manager/gelatos_buff_manager",
			mod_data         = MOD_DATA_PATH,
			mod_localization = "gelatos_buff_manager/scripts/mods/gelatos_buff_manager/gelatos_buff_manager_localization",
		})

		-- mod:get_internal_data("options") only resolves if we patch it in here --
		-- this mirrors BBM's own manifest, which does the same for the same reason.
		local mod_data = mod:io_dofile(MOD_DATA_PATH)

		if mod_data then
			getmetatable(mod._data).__index["options"] = mod_data.options
		end
	end,
	packages = {},
}
