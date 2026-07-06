local HudElementsDefinitions = require("scripts/ui/hud/hud_elements_player")

local mod = get_mod("gelatos_buff_manager")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/table")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/string")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/mod")

mod.version = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/gelatos_buff_manager_version")
mod:info(("Gelato's Buff Manager v%s loaded."):format(mod.version))

-- One-time migration: versions before 0.4.0 persisted the full buff catalog to
-- user_settings.config. It's fully deterministic and never read from there anymore, so
-- clear the stale blob rather than leaving it to sit there forever.
if mod:get("buffs_catalog") ~= nil then
	mod:set("buffs_catalog", nil)
end

-- Options removed in v0.21.0; purge stale persisted values so they can't silently apply.
if mod:get("nav_icon_scale") ~= nil then
	mod:set("nav_icon_scale", nil)
end
if mod:get("max_buffs_per_bar") ~= nil then
	mod:set("max_buffs_per_bar", nil)
end

mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/buff_priorities")
local HudElementBuffBar = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/hud/hud_element_buff_bar")
local management_window = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/ui/window"):new()

local BUFFS_DATA_SETTING_ID = "buffs_data"
local BARS_SETTING_ID = "bars"
local TOGGLE_DEFAULT_BAR_SETTING_ID = "default_buff_bar_enabled"
local GROUP_BUFFS_IN_CATEGORIES_SETTING_ID = "group_buffs_in_categories"

local HUD_ELEMENT_PLAYER_BUFFS = "HudElementPlayerBuffs"
local _, PlayerBuffsDefinition = table.find_by_key(HudElementsDefinitions, "class_name", HUD_ELEMENT_PLAYER_BUFFS)

-- -------------------------------
-- ------- Local Functions -------
-- -------------------------------

local function recreate_hud()
	local ui_manager = Managers.ui
	if not ui_manager then
		mod:info("Gelato's Buff Manager: recreate_hud skipped, Managers.ui not available.")
		return
	end

	local hud = ui_manager._hud
	if not hud then
		mod:info("Gelato's Buff Manager: recreate_hud skipped, no active gameplay HUD (not in a mission?).")
		return
	end

	local ok, err = pcall(function()
		local player = Managers.player:local_player(1)
		local peer_id = player:peer_id()
		local local_player_id = player:local_player_id()
		local elements = hud._element_definitions
		local visibility_groups = hud._visibility_groups

		ui_manager:destroy_player_hud()
		ui_manager:create_player_hud(peer_id, local_player_id, elements, visibility_groups)
	end)

	if not ok then
		mod:error(("Gelato's Buff Manager: failed to recreate HUD after a bar change: %s"):format(tostring(err)))
	else
		mod:info("Gelato's Buff Manager: HUD recreated.")
	end
end

mod.recreate_hud = recreate_hud

local function remove_buff_bar_hud_definitions(definitions)
	local index = table.index_of_condition(definitions, function(definition)
		return string.starts_with(definition.class_name, "GBMHudElementBuffBar")
	end)
	while index > 0 do
		table.remove(definitions, index)
		index = table.index_of_condition(definitions, function(definition)
			return string.starts_with(definition.class_name, "GBMHudElementBuffBar")
		end)
	end
end

local Limits = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/limits")

local function get_filter_for_bar(buffs_data, bar_name)
	if table.is_nil_or_empty(buffs_data) then
		return nil
	end

	local matching_names = {}
	for _, data in pairs(buffs_data) do
		if data.bar_name == bar_name and not data.is_hidden then
			matching_names[#matching_names + 1] = data.name
		end
	end

	if #matching_names == 0 then
		return nil
	end

	-- CONFIRMED from the actual game source (hud_element_player_buffs_polling.lua): each HUD
	-- buff-bar instance -- default or custom -- gets its own independent pool of exactly 20
	-- widget slots (15 reserved for positive buffs, 5 for negative), and in the current game
	-- version, running out of slots is handled gracefully: HudElementPlayerBuffs._get_available
	-- _widget() returning nil is null-checked and just stops adding more, no crash. Which 20
	-- (of however many are assigned) actually show is decided by the game itself, sorted by
	-- activation time (oldest surviving buff keeps its slot) then explicit hud_priority. That's
	-- smarter than any pre-truncation we could do here, so we no longer truncate the filter --
	-- we just pass everything through and let the vanilla engine pick.
	local max_buffs = Limits.max_buffs_per_bar()

	if #matching_names > max_buffs then
		mod:info(("Gelato's Buff Manager: bar '%s' has %d buffs assigned, above the informational " ..
			"%d threshold. This isn't truncated -- the game only ever shows up to 20 at a time per bar " ..
			"anyway (15 positive + 5 negative slots), picking which ones by activation time, so extra " ..
			"assignments just mean some rotate in and out on their own."):format(
			bar_name, #matching_names, max_buffs))
	end

	local filter_data = {}
	for i = 1, #matching_names do
		filter_data[matching_names[i]] = true
	end

	return filter_data
end

local BAR_ACTIVE_SETTING_ID = "bar_active_states"

local function is_bar_active(bar_name)
	local active_states = mod:get(BAR_ACTIVE_SETTING_ID)
	if type(active_states) ~= "table" or active_states[bar_name] == nil then
		return true
	end
	return active_states[bar_name] == true
end

mod.is_bar_active = is_bar_active

function mod.set_bar_active(bar_name, active)
	local active_states = mod:get(BAR_ACTIVE_SETTING_ID)
	if type(active_states) ~= "table" then
		active_states = {}
	end
	active_states[bar_name] = active
	mod:set(BAR_ACTIVE_SETTING_ID, active_states)
end

local BAR_SLOTS_SETTING_ID = "gbm_bar_slots"

local function _load_bar_slots()
	local saved = mod:get(BAR_SLOTS_SETTING_ID)
	local slots = {}
	local max_slot = 0

	if type(saved) == "table" then
		for name, slot in pairs(saved) do
			if type(name) == "string" and type(slot) == "number" and slot >= 1 then
				slots[name] = slot
				if slot > max_slot then
					max_slot = slot
				end
			end
		end
	end

	return slots, max_slot
end

local function add_buff_bar_hud_definitions(definitions)
	local buffs_data = mod:get(BUFFS_DATA_SETTING_ID)
	local bars = mod:get(BARS_SETTING_ID)

	if table.is_nil_or_empty(buffs_data) or table.is_nil_or_empty(bars) then
		return
	end

	-- Slots are assigned ONCE, the first time a bar registers, then persisted -- so
	-- reordering the list, toggling bars, or restarting never moves a bar in-game.
	local slots, max_slot = _load_bar_slots()
	local slots_changed = false

	-- Bottom-up so bars from pre-slot versions keep their previous stacking order.
	for i = #bars, 1, -1 do
		local bar_name = bars[i]
		if is_bar_active(bar_name) and not slots[bar_name] and get_filter_for_bar(buffs_data, bar_name) then
			max_slot = max_slot + 1
			slots[bar_name] = max_slot
			slots_changed = true
			mod:info(("Gelato's Buff Manager: bar '%s' assigned permanent stack slot %d."):format(bar_name, max_slot))
		end
	end

	if slots_changed then
		mod:set(BAR_SLOTS_SETTING_ID, slots)
	end

	for _, bar_name in ipairs(bars) do
		if not is_bar_active(bar_name) then
			mod:info(("Gelato's Buff Manager: bar '%s' is deactivated, skipping HUD registration."):format(bar_name))
		else
			local buffs_filter = get_filter_for_bar(buffs_data, bar_name)
			if buffs_filter then
				local slot = slots[bar_name]
				local filter_count = 0
				for _ in pairs(buffs_filter) do
					filter_count = filter_count + 1
				end
				mod:info(("Gelato's Buff Manager: registering HUD bar '%s' with %d buff(s) at stack slot %d."):format(
					bar_name, filter_count, slot))

				table.insert(definitions, {
					package = "packages/ui/hud/player_buffs/player_buffs",
					use_retained_mode = true,
					use_hud_scale = true,
					class_name = ("GBMHudElementBuffBar_%s"):format(string.to_pascal_case(bar_name, " ")),
					filename = "gelatos_buff_manager/scripts/mods/gelatos_buff_manager/hud/hud_element_buff_bar",
					visibility_groups = { "dead", "alive", "communication_wheel" },
					buffs_filter = buffs_filter,
					bar_index = slot,
				})
			else
				mod:info(("Gelato's Buff Manager: bar '%s' has no buffs assigned yet, skipping HUD registration."):format(
					bar_name))
			end
		end
	end
end

local function add_or_remove_default_buff_bar(definitions)
	local index = table.index_of_condition(definitions, function(definition)
		return definition.class_name == HUD_ELEMENT_PLAYER_BUFFS
	end)

	if not PlayerBuffsDefinition then
		mod:error("Gelato's Buff Manager: could not find the vanilla HudElementPlayerBuffs definition to toggle.")
		return
	end

	local should_show = mod:get(TOGGLE_DEFAULT_BAR_SETTING_ID) ~= false

	if not should_show then
		if index > 0 then
			table.remove(definitions, index)
			mod:info("Gelato's Buff Manager: removed vanilla default buff bar from HUD definitions.")
		else
			mod:info("Gelato's Buff Manager: default buff bar toggle is off, and it wasn't present anyway.")
		end
	elseif index <= 0 then
		table.insert(definitions, PlayerBuffsDefinition)
		mod:info("Gelato's Buff Manager: re-added vanilla default buff bar to HUD definitions.")
	else
		mod:info("Gelato's Buff Manager: default buff bar toggle is on, and it was already present.")
	end
end

-- -------------------------------
-- ------- Public Functions ------
-- -------------------------------

mod._buffs_data_revision = 0

mod.get_buffs_data_revision = function()
	return mod._buffs_data_revision or 0
end

mod.bump_buffs_data_revision = function()
	mod._buffs_data_revision = (mod._buffs_data_revision or 0) + 1
end

mod.configure_buffs = function()
	if management_window.is_open then
		management_window:close()
		recreate_hud()
	elseif not mod:is_in_hub() then
		management_window:open()
	end
end

mod.reindex_buffs_catalog = function()
	if management_window and management_window.reindex_catalog then
		management_window:reindex_catalog()
	end
end

mod.on_setting_changed = function(setting_id)
	if setting_id == TOGGLE_DEFAULT_BAR_SETTING_ID or setting_id == GROUP_BUFFS_IN_CATEGORIES_SETTING_ID then
		recreate_hud()
	end
end

mod.update = function(dt)
	management_window:update()
end

mod.on_unload = function(exit_game)
	if management_window.is_open then
		pcall(function() management_window:close() end)
	end
end

mod.on_disabled = function()
	if management_window.is_open then
		pcall(function() management_window:close() end)
	end
end

-- -------------------------------
-- ------------ Hooks ------------
-- -------------------------------

mod:hook("UIManager", "using_input", function(func, ...)
	return management_window.is_open or func(...)
end)

mod:hook("UIHud", "init", function(func, self, definitions, visibility_groups, params)
	add_or_remove_default_buff_bar(definitions)
	remove_buff_bar_hud_definitions(definitions)
	add_buff_bar_hud_definitions(definitions)

	return func(self, definitions, visibility_groups, params)
end)

mod:hook("UIHud", "_add_element", function(func, self, definition, elements, elements_array)
	if string.starts_with(definition.class_name, "GBMHudElementBuffBar") then
		-- Proven visible since v0.1.0; vanilla buff cohort verified at 301 in-game (07/2026).
		local draw_layer = 100
		local hud_scale = definition.use_hud_scale and (self._hud_scale ~= nil and self:_hud_scale()) or
			RESOLUTION_LOOKUP.scale
		local hud_element = HudElementBuffBar:new(self, draw_layer, hud_scale, definition.buffs_filter, definition.bar_index)
		hud_element.__class_name = definition.class_name
		elements[definition.class_name] = hud_element
		table.insert(elements_array, hud_element)
	else
		func(self, definition, elements, elements_array)
	end
end)
