local mod = get_mod("gelatos_buff_manager")

-- CONFIRMED directly from the game's own source (hud_element_player_buffs_settings.lua,
-- hud_element_player_buffs_polling.lua, hud_element_player_buffs_definitions.lua):
--   - HudElementPlayerBuffsSettings.max_buffs is literally 20 in the vanilla game.
--   - This is a PER-INSTANCE cap, not shared across bars: each HudElementPlayerBuffs-derived
--     object (the default bar, or any of our custom bars) gets its own independent array of
--     exactly 20 pre-defined "buff_1".."buff_20" widgets.
--   - Of those 20, 15 slots are reserved for positive buffs and 5 for negative (a fixed
--     THREE_QUATER_MAX_BUFF / QUATER_MAX_BUFF split).
--   - Overflow is handled gracefully in the current game version: _get_available_widget()
--     returning nil is null-checked, not a crash (this was a real Fatshark-acknowledged bug,
--     fixed in patch 1.8.6 -- pre-fix, the same nil case crashed the client, and BBM users
--     were told to disable the mod while waiting for that hotfix).
--   - Which buffs actually get a slot when there are more than 20 assigned is decided by the
--     game itself: sorted by activation time (oldest surviving buff keeps its slot), then
--     explicit hud_priority if a template sets one. This is smarter than any static
--     pre-truncation we could do, so GBM no longer truncates bar filters at all -- this value
--     is purely an informational threshold for the UI/log warnings, not an enforced cap.
local DEFAULT_MAX_BUFFS_PER_BAR = 20

local M = {}

function M.max_buffs_per_bar()
	return DEFAULT_MAX_BUFFS_PER_BAR
end

M.MAX_BUFFS_PER_BAR = DEFAULT_MAX_BUFFS_PER_BAR

return M
