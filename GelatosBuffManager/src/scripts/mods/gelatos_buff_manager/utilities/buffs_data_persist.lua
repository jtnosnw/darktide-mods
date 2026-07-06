local mod = get_mod("gelatos_buff_manager")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/string")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/table")

local BUFFS_DATA_SETTING_ID = "buffs_data"

local M = {}

-- Shared by window.lua (on close) and nav_tree_component.lua (live updates while the window
-- stays open) so both save the same shape and recreate_hud() always sees current assignments.
function M.save(buffs_data)
	local save_data = {}

	if not table.is_nil_or_empty(buffs_data) then
		for _, data in pairs(buffs_data) do
			if not string.is_nil_or_whitespace(data.bar_name) then
				save_data[data.name] = data:save_data()
			end
		end
	end

	mod:set(BUFFS_DATA_SETTING_ID, save_data)
end

return M
