local mod = get_mod("gelatos_buff_manager")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/string")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/table")
local Imgui_helpers = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/imgui")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/ui/components/base_buff_component")
local UiSettings = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/ui/settings")
local Limits = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/limits")
local BuffsDataPersist = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/buffs_data_persist")
local BuffPriorities = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/buff_priorities")
local ActionHistory = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/action_history")

local CLASS_NAME = "BuffBarsComponent"

local BARS_SETTING_ID = "bars"
local BAR_SLOTS_SETTING_ID = "gbm_bar_slots"
local TOGGLE_DEFAULT_BAR_SETTING_ID = "default_buff_bar_enabled"
local REMOVE_BUFF_LOC_ID = "gbm_remove_from_bar"
local NO_BARS_LOC_ID = "gbm_no_bars"
local OVER_LIMIT_LOC_ID = "gbm_bar_over_limit"
local OVER_LIMIT_DESC_LOC_ID = "gbm_bar_over_limit_description"
local BAR_ACTIVE_LOC_ID = "gbm_bar_active"
local SLOT_INFO_LOC_ID = "gbm_bar_slot_info"
local TOGGLE_DEFAULT_BAR_LOC_ID = "gbm_toggle_default_bar"
local CREATE_BAR_LOC_ID = "gbm_create_bar"
local SELECT_BAR_LOC_ID = "gbm_select_bar"
local CLEAR_BAR_LOC_ID = "gbm_clear_bar"
local DELETE_BAR_LOC_ID = "gbm_delete_bar"
local ADD_SELECTED_LOC_ID = "gbm_add_selected"
local REMOVE_SELECTED_LOC_ID = "gbm_remove_selected"
local NO_BAR_SELECTED_ERROR_LOC_ID = "gbm_no_bar_selected_error"
local PRIO_LABEL_LOC_ID = "gbm_prio_label"
local MOVE_UP_LOC_ID = "gbm_move_bar_up"
local MOVE_DOWN_LOC_ID = "gbm_move_bar_down"

local PRIO_COMBO_ITEMS = { "0", "1", "2" }
local PRIO_COMBO_WIDTH = 34
local SELECT_BAR_COMBO_WIDTH = 320
local MAX_TEXT_INPUT_LENGTH = 50

-- -------------------------------
-- ------- Local Functions -------
-- -------------------------------

local function _update_buffs(window_id, buffs)
	local same_line_flag = false
	local removed_any = false
	for i = 1, #buffs do
		local buff = buffs[i]
		if buff then
			if same_line_flag then
				Imgui.same_line()
			end

			local buff_window_id = ("%s_%s"):format(window_id, buff.name)
			Imgui.begin_child_window(buff_window_id, UiSettings.BUFF_WINDOW_SIZE[1], UiSettings.BUFF_WINDOW_SIZE[2], false)

			if buff.icon and buff.icon ~= "" then
				Imgui.image_button(buff.icon, UiSettings.BUFF_IMAGE_SIZE[1], UiSettings.BUFF_IMAGE_SIZE[2], 255, 255, 255, 1)
			else
				Imgui.text(buff.name or "???")
			end

			Imgui.text(mod:localize(PRIO_LABEL_LOC_ID))
			Imgui.same_line()
			-- Global per-buff value: every dropdown for this buff (any bar, any pane) reads and
			-- writes the same entry, so a change here live-updates them all plus the HUD sort.
			local current_priority = BuffPriorities.get(buff.name)
			local width_pushed = Imgui_helpers.push_width(PRIO_COMBO_WIDTH)
			local new_prio_index = Imgui.combo(buff_window_id .. "_PRIO", "", PRIO_COMBO_ITEMS,
				current_priority + 1, false)
			Imgui_helpers.pop_width(width_pushed)
			if new_prio_index and new_prio_index - 1 ~= current_priority then
				BuffPriorities.set(buff.name, new_prio_index - 1)
				ActionHistory.log(mod:localize("gbm_hist_prio_set", buff.name, new_prio_index - 1))
			end

			local remove = Imgui.button(mod:localize(REMOVE_BUFF_LOC_ID))

			Imgui.end_child_window()

			if Imgui.is_item_hovered() then
				Imgui.begin_tool_tip()
				Imgui.text(buff.name)
				Imgui.end_tool_tip()
			end

			if remove then
				ActionHistory.log(mod:localize("gbm_hist_buff_removed", buff.name, buff.bar_name or ""))
				buff.bar_name = ""
				removed_any = true
			end

			same_line_flag = true
		end
	end
	return removed_any
end

-- -------------------------------
-- --------- Constructor ---------
-- -------------------------------
local BuffBarsComponent = class(CLASS_NAME, "BaseBuffComponent")

function BuffBarsComponent:init(buffs_data, nav_tree_component)
	BuffBarsComponent.super.init(self, buffs_data)

	self._nav_tree_component = nav_tree_component

	self._bars = mod:get(BARS_SETTING_ID) or {}
	self._new_bar_name = ""
	self._selected_bar_index = nil

	self._cached_bar_data = {}
	self._dirty = true
	self._last_buffs_data_revision = -1
	self._bar_action_error = nil
end

-- -------------------------------
-- ------ Private Functions ------
-- -------------------------------

function BuffBarsComponent:_rebuild_cache()
	table.clear(self._cached_bar_data)

	if table.is_nil_or_empty(self._bars) or table.is_nil_or_empty(self._buffs_data) then
		self._dirty = false
		return
	end

	for _, bar in ipairs(self._bars) do
		local bar_data = {}
		local count = 0
		for _, data in pairs(self._buffs_data) do
			if data.bar_name == bar then
				count = count + 1
				bar_data[count] = data
			end
		end
		if count > 0 then
			table.sort(bar_data, function(a, b)
				return (a.name or "") < (b.name or "")
			end)
		end
		self._cached_bar_data[bar] = bar_data
	end

	self._dirty = false
end

function BuffBarsComponent:_move_bar(bar, direction)
	local from = nil
	for i = 1, #self._bars do
		if self._bars[i] == bar then
			from = i
			break
		end
	end

	if not from then
		return
	end

	local to = from + direction
	if to < 1 or to > #self._bars then
		return
	end

	self._bars[from], self._bars[to] = self._bars[to], self._bars[from]
	mod:set(BARS_SETTING_ID, self._bars)

	local selected_index = self._selected_bar_index
	if selected_index == from then
		self._selected_bar_index = to
	elseif selected_index == to then
		self._selected_bar_index = from
	end

	-- Cosmetic list order only -- in-game positions come from persisted slots, never this.
	mod:info(("Gelato's Buff Manager: moved bar '%s' %s to list position %d (list order only)."):format(
		bar, direction < 0 and "up" or "down", to))
end

function BuffBarsComponent:_clear_bar_buffs(bar)
	local cleared_count = 0
	for _, data in pairs(self._buffs_data) do
		if data.bar_name == bar then
			data.bar_name = ""
			cleared_count = cleared_count + 1
		end
	end

	if cleared_count > 0 then
		mod:bump_buffs_data_revision()
		BuffsDataPersist.save(self._buffs_data)
		mod.recreate_hud()
	end

	return cleared_count
end

function BuffBarsComponent:_delete_bar(bar)
	local bar_index = nil
	for i = 1, #self._bars do
		if self._bars[i] == bar then
			bar_index = i
			break
		end
	end

	if not bar_index then
		return
	end

	for _, data in pairs(self._buffs_data) do
		if data.bar_name == bar then
			data.bar_name = ""
		end
	end

	table.remove(self._bars, bar_index)
	mod:set(BARS_SETTING_ID, self._bars)

	-- Free the bar's persisted stack slot; drop the key entirely when none remain.
	local slots = mod:get(BAR_SLOTS_SETTING_ID)
	if type(slots) == "table" and slots[bar] ~= nil then
		slots[bar] = nil
		mod:set(BAR_SLOTS_SETTING_ID, next(slots) ~= nil and slots or nil)
	end

	-- Keep the Selected Buff Bar combo pointing at the same bar after the indices shift.
	local selected_index = self._selected_bar_index
	if selected_index then
		if selected_index == bar_index then
			self._selected_bar_index = nil
		elseif bar_index < selected_index then
			self._selected_bar_index = selected_index - 1
		end
	end

	mod:bump_buffs_data_revision()
	BuffsDataPersist.save(self._buffs_data)
	mod.recreate_hud()
	ActionHistory.log(mod:localize("gbm_hist_bar_deleted", bar))
end

function BuffBarsComponent:_update_bar_controls()
	local create_bar = Imgui.button(mod:localize(CREATE_BAR_LOC_ID))
	Imgui.same_line()
	local new_bar_name = Imgui.ided_input_text(self.__class_name .. "_NEW_BAR", self._new_bar_name)
	if new_bar_name and #new_bar_name > MAX_TEXT_INPUT_LENGTH then
		new_bar_name = new_bar_name:sub(1, MAX_TEXT_INPUT_LENGTH)
		if not self._bar_name_length_warned then
			self._bar_name_length_warned = true
			mod:warning(("Gelato's Buff Manager: bar name input capped at %d characters."):format(
				MAX_TEXT_INPUT_LENGTH))
		end
	elseif self._bar_name_length_warned then
		self._bar_name_length_warned = false
	end
	self._new_bar_name = new_bar_name

	if create_bar then
		if string.is_nil_or_whitespace(self._new_bar_name) then
			ActionHistory.warn(mod:localize("gbm_hist_warn_create_empty"))
		elseif table.contains(self._bars, self._new_bar_name) then
			ActionHistory.warn(mod:localize("gbm_hist_warn_create_duplicate", self._new_bar_name))
			self._new_bar_name = ""
		else
			table.insert(self._bars, 1, self._new_bar_name)
			mod:set(BARS_SETTING_ID, self._bars)
			if self._selected_bar_index then
				self._selected_bar_index = self._selected_bar_index + 1
			end
			ActionHistory.log(mod:localize("gbm_hist_bar_created", self._new_bar_name))
			self._new_bar_name = ""
		end
	end

	Imgui.text(mod:localize(SELECT_BAR_LOC_ID))
	Imgui.same_line()
	local previous_bar_index = self._selected_bar_index
	-- Bounded width: at the old-ImGui default (65% of pane) this combo pushed the
	-- Clear/Delete buttons past the pane edge on narrower windows, clipping them.
	local width_pushed = Imgui_helpers.push_width(SELECT_BAR_COMBO_WIDTH)
	self._selected_bar_index = Imgui.combo(self.__class_name .. "_SELECT_BAR", "", self._bars, self._selected_bar_index)
	Imgui_helpers.pop_width(width_pushed)
	if self._selected_bar_index ~= previous_bar_index then
		self._dirty = true
		if self._nav_tree_component then
			self._nav_tree_component:mark_dirty()
		end
	end

	local selected_names = self._nav_tree_component and self._nav_tree_component:get_selected_names()
	local selected_count = self._nav_tree_component and self._nav_tree_component:get_selected_count() or 0
	local add_selected_label = mod:localize(ADD_SELECTED_LOC_ID, selected_count)

	if Imgui.button(add_selected_label) then
		if not self._selected_bar_index then
			self._bar_action_error = mod:localize(NO_BAR_SELECTED_ERROR_LOC_ID)
			ActionHistory.warn(mod:localize("gbm_hist_warn_add_no_bar"))
		elseif selected_count == 0 then
			ActionHistory.warn(mod:localize("gbm_hist_warn_add_none"))
		elseif selected_names then
			local selected_bar = self._bars[self._selected_bar_index]
			local added_count = 0
			for name in pairs(selected_names) do
				local data = self._buffs_data[name]
				if data then
					data.bar_name = selected_bar
					added_count = added_count + 1
				end
			end
			if added_count > 0 then
				mod:bump_buffs_data_revision()
				BuffsDataPersist.save(self._buffs_data)
				mod.recreate_hud()
				self._nav_tree_component:clear_selection()
			end
			ActionHistory.log(mod:localize("gbm_hist_added_to_bar", added_count, selected_bar))
			self._bar_action_error = nil
		end
	end

	Imgui.same_line()
	if Imgui.button(mod:localize(REMOVE_SELECTED_LOC_ID, selected_count)) then
		if not self._selected_bar_index then
			self._bar_action_error = mod:localize(NO_BAR_SELECTED_ERROR_LOC_ID)
			ActionHistory.warn(mod:localize("gbm_hist_warn_remove_no_bar"))
		elseif selected_count == 0 then
			ActionHistory.warn(mod:localize("gbm_hist_warn_remove_none"))
		elseif selected_names then
			local removed_count = 0
			for name in pairs(selected_names) do
				local data = self._buffs_data[name]
				if data and (data.bar_name or "") ~= "" then
					data.bar_name = ""
					removed_count = removed_count + 1
				end
			end
			if removed_count > 0 then
				mod:bump_buffs_data_revision()
				BuffsDataPersist.save(self._buffs_data)
				mod.recreate_hud()
			end
			ActionHistory.log(mod:localize("gbm_hist_removed_from_bar", removed_count,
				self._bars[self._selected_bar_index]))
			self._bar_action_error = nil
		end
	end

	-- Always reserve this line so the layout below doesn't jump when the error appears.
	Imgui.text(self._bar_action_error or "")
end

function BuffBarsComponent:_update_toggle_default_bar()
	local current = mod:get(TOGGLE_DEFAULT_BAR_SETTING_ID)
	local new_flag = Imgui.checkbox(mod:localize(TOGGLE_DEFAULT_BAR_LOC_ID), current)
	if new_flag ~= current then
		mod:set(TOGGLE_DEFAULT_BAR_SETTING_ID, new_flag)
		ActionHistory.log(mod:localize(new_flag and "gbm_hist_default_bar_on" or "gbm_hist_default_bar_off"))
		mod.recreate_hud()
	end
end

-- -------------------------------
-- ------- Public Functions ------
-- -------------------------------

function BuffBarsComponent:get_selected_bar_name()
	if self._selected_bar_index then
		return self._bars[self._selected_bar_index]
	end
	return nil
end

function BuffBarsComponent:update()
	local revision = mod:get_buffs_data_revision()
	if revision ~= self._last_buffs_data_revision then
		self._last_buffs_data_revision = revision
		self._dirty = true
	end

	if self._dirty then
		self:_rebuild_cache()
	end

	self:_update_bar_controls()
	Imgui.separator()
	self:_update_toggle_default_bar()
	Imgui.separator()

	Imgui.text(mod:localize(SLOT_INFO_LOC_ID))
	Imgui.separator()

	if table.is_nil_or_empty(self._bars) then
		Imgui.text(mod:localize(NO_BARS_LOC_ID))
		return
	end

	local max_buffs = Limits.max_buffs_per_bar()
	local removed_a_buff = false
	local pending_delete_bar = nil
	local pending_move_bar, pending_move_dir = nil, nil

	for _, bar in ipairs(self._bars) do
		Imgui.push_id(self.__class_name .. "_" .. bar)

		if Imgui.button(mod:localize(MOVE_UP_LOC_ID)) then
			pending_move_bar, pending_move_dir = bar, -1
		end
		Imgui.same_line()
		if Imgui.button(mod:localize(MOVE_DOWN_LOC_ID)) then
			pending_move_bar, pending_move_dir = bar, 1
		end
		Imgui.same_line()

		local is_active = mod.is_bar_active(bar)
		local new_active = Imgui.checkbox(mod:localize(BAR_ACTIVE_LOC_ID), is_active)
		if new_active ~= is_active then
			mod.set_bar_active(bar, new_active)
			mod.recreate_hud()
			ActionHistory.log(mod:localize(new_active and "gbm_hist_bar_activated" or "gbm_hist_bar_deactivated", bar))
		end
		Imgui.same_line()

		if Imgui.button(mod:localize(CLEAR_BAR_LOC_ID)) then
			local cleared_count = self:_clear_bar_buffs(bar)
			if cleared_count > 0 then
				ActionHistory.log(mod:localize("gbm_hist_bar_cleared", bar, cleared_count))
			else
				ActionHistory.warn(mod:localize("gbm_hist_warn_bar_clear_empty", bar))
			end
		end
		Imgui.same_line()
		if Imgui.button(mod:localize(DELETE_BAR_LOC_ID)) then
			pending_delete_bar = bar
		end
		Imgui.same_line()

		local sorted_data = self._cached_bar_data[bar]
		local count = sorted_data and #sorted_data or 0
		local label
		if count > max_buffs then
			label = ("%s (%d/%d %s)###%s"):format(bar, count, max_buffs, mod:localize(OVER_LIMIT_LOC_ID), bar)
		else
			label = ("%s (%d/%d)###%s"):format(bar, count, max_buffs, bar)
		end

		-- Header rendered directly in the pane (no wrapping child window); a nested header
		-- child was what corrupted the pane's vertical scroll. Matches BBM's structure.
		local expanded = Imgui.collapsing_header(label)

		if expanded then
			local window_id = ("%s_%s"):format(self.__class_name, bar)
			local over_limit_height = count > max_buffs and UiSettings.OVER_LIMIT_LINE_HEIGHT or 0
			Imgui.begin_child_window(window_id, UiSettings.BAR_WINDOW_SIZE[1],
				UiSettings.BAR_WINDOW_SIZE[2] + over_limit_height, true,
				"always_auto_resize", "horizontal_scrollbar")

			if count > max_buffs then
				Imgui.text(mod:localize(OVER_LIMIT_DESC_LOC_ID))
			end

			if sorted_data and #sorted_data > 0 then
				if _update_buffs(window_id, sorted_data) then
					removed_a_buff = true
				end
			end

			Imgui.end_child_window()
		end

		Imgui.pop_id()
	end

	if pending_delete_bar then
		self:_delete_bar(pending_delete_bar)
	end

	if pending_move_bar then
		self:_move_bar(pending_move_bar, pending_move_dir)
	end

	if removed_a_buff then
		mod:bump_buffs_data_revision()
		BuffsDataPersist.save(self._buffs_data)
		mod.recreate_hud()
	end
end

return BuffBarsComponent
