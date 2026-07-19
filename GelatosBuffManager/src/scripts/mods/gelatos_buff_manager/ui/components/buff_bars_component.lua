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

-- Static labels resolved ONCE at load; this component was re-localizing all of them for every
-- bar, every frame. Only parameterised strings stay dynamic.
local L = {
	REMOVE_BUFF = mod:localize("gbm_remove_from_bar"),
	NO_BARS = mod:localize("gbm_no_bars"),
	OVER_LIMIT = mod:localize("gbm_bar_over_limit"),
	OVER_LIMIT_DESC = mod:localize("gbm_bar_over_limit_description"),
	BAR_ACTIVE = mod:localize("gbm_bar_active"),
	SLOT_INFO = mod:localize("gbm_bar_slot_info"),
	TOGGLE_DEFAULT_BAR = mod:localize("gbm_toggle_default_bar"),
	CREATE_BAR = mod:localize("gbm_create_bar"),
	SELECT_BAR = mod:localize("gbm_select_bar"),
	CLEAR_BAR = mod:localize("gbm_clear_bar"),
	DELETE_BAR = mod:localize("gbm_delete_bar"),
	NO_BAR_SELECTED_ERROR = mod:localize("gbm_no_bar_selected_error"),
	PRIO_LABEL = mod:localize("gbm_prio_label"),
	MOVE_UP = mod:localize("gbm_move_bar_up"),
	MOVE_DOWN = mod:localize("gbm_move_bar_down"),
	WARN_CREATE_EMPTY = mod:localize("gbm_hist_warn_create_empty"),
	WARN_ADD_NO_BAR = mod:localize("gbm_hist_warn_add_no_bar"),
	WARN_ADD_NONE = mod:localize("gbm_hist_warn_add_none"),
	WARN_REMOVE_NO_BAR = mod:localize("gbm_hist_warn_remove_no_bar"),
	WARN_REMOVE_NONE = mod:localize("gbm_hist_warn_remove_none"),
	DEFAULT_BAR_ON = mod:localize("gbm_hist_default_bar_on"),
	DEFAULT_BAR_OFF = mod:localize("gbm_hist_default_bar_off"),
}

local NEW_BAR_INPUT_ID = CLASS_NAME .. "_NEW_BAR"
local SELECT_BAR_COMBO_ID = CLASS_NAME .. "_SELECT_BAR"

local PRIO_COMBO_ITEMS = { "0", "1", "2" }
local PRIO_COMBO_WIDTH = 34
local SELECT_BAR_COMBO_WIDTH = 320
local MAX_TEXT_INPUT_LENGTH = 50

-- Bar count guardrails. Per-frame cost is fine well past these numbers; the real limits are that
-- recreate_hud() rebuilds the ENTIRE player HUD on every assignment change (cost grows with bar
-- count), and that stacked bars start colliding with other HUD elements high on the screen.
local MAX_BARS = 10
local SOFT_WARN_BAR_COUNT = 6

-- -------------------------------
-- ------- Local Functions -------
-- -------------------------------

-- Hoisted: a fresh closure per table.sort call is a needless allocation.
local function _by_name(a, b)
	return (a.name or "") < (b.name or "")
end

-- Entries carry their pre-composed ImGui IDs, built during the dirty-gated cache rebuild.
-- Previously both were formatted fresh for every buff on every frame.
local function _update_buffs(entries)
	local same_line_flag = false
	local removed_any = false

	for i = 1, #entries do
		local entry = entries[i]
		local buff = entry.data

		if buff then
			if same_line_flag then
				Imgui.same_line()
			end

			Imgui.begin_child_window(entry.window_id, UiSettings.BUFF_WINDOW_SIZE[1], UiSettings.BUFF_WINDOW_SIZE[2],
				false)

			if buff.icon and buff.icon ~= "" then
				Imgui.image_button(buff.icon, UiSettings.BUFF_IMAGE_SIZE[1], UiSettings.BUFF_IMAGE_SIZE[2], 255, 255,
					255, 1)
			else
				Imgui.text(buff.name or "???")
			end

			Imgui.text(L.PRIO_LABEL)
			Imgui.same_line()
			-- Global per-buff value: every dropdown for this buff (any bar, any pane) reads and
			-- writes the same entry, so a change here live-updates them all plus the HUD sort.
			local current_priority = BuffPriorities.get(buff.name)
			local width_pushed = Imgui_helpers.push_width(PRIO_COMBO_WIDTH)
			local new_prio_index = Imgui.combo(entry.prio_id, "", PRIO_COMBO_ITEMS, current_priority + 1, false)
			Imgui_helpers.pop_width(width_pushed)
			if new_prio_index and new_prio_index - 1 ~= current_priority then
				BuffPriorities.set(buff.name, new_prio_index - 1)
				ActionHistory.log(mod:localize("gbm_hist_prio_set", buff.name, new_prio_index - 1))
			end

			local remove = Imgui.button(L.REMOVE_BUFF)

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

	-- Ordered view models, one per bar, each carrying its pre-composed ImGui IDs and header text.
	self._cached_bars = {}
	self._dirty = true
	self._last_buffs_data_revision = -1
	self._bar_action_error = nil
end

-- -------------------------------
-- ------ Private Functions ------
-- -------------------------------

function BuffBarsComponent:_rebuild_cache()
	table.clear(self._cached_bars)

	if table.is_nil_or_empty(self._bars) then
		self._dirty = false
		return
	end

	local max_buffs = Limits.max_buffs_per_bar()

	for bar_index = 1, #self._bars do
		local bar = self._bars[bar_index]
		local window_id = ("%s_%s"):format(CLASS_NAME, bar)

		local entries = {}
		local count = 0

		if not table.is_nil_or_empty(self._buffs_data) then
			for _, data in pairs(self._buffs_data) do
				if data.bar_name == bar then
					count = count + 1
					entries[count] = data
				end
			end
		end

		if count > 0 then
			table.sort(entries, _by_name)
		end

		-- Swap each sorted BuffData for an entry that also carries its two ImGui IDs. Both depend
		-- only on the bar and the buff name, so they are stable until the next rebuild.
		for i = 1, count do
			local data = entries[i]
			local buff_window_id = ("%s_%s"):format(window_id, data.name)
			entries[i] = {
				data = data,
				window_id = buff_window_id,
				prio_id = buff_window_id .. "_PRIO",
			}
		end

		local over_limit = count > max_buffs
		local header_label
		if over_limit then
			header_label = ("%s (%d/%d %s)###%s"):format(bar, count, max_buffs, L.OVER_LIMIT, bar)
		else
			header_label = ("%s (%d/%d)###%s"):format(bar, count, max_buffs, bar)
		end

		self._cached_bars[bar_index] = {
			name = bar,
			push_id = ("%s_%s"):format(CLASS_NAME, bar),
			window_id = window_id,
			header_label = header_label,
			entries = entries,
			count = count,
			over_limit = over_limit,
		}
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
	self._dirty = true

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

	self._dirty = true
	mod:bump_buffs_data_revision()
	BuffsDataPersist.save(self._buffs_data)
	mod.recreate_hud()
	ActionHistory.log(mod:localize("gbm_hist_bar_deleted", bar))
end

function BuffBarsComponent:_create_bar()
	if string.is_nil_or_whitespace(self._new_bar_name) then
		ActionHistory.warn(L.WARN_CREATE_EMPTY)
		return
	end

	if table.contains(self._bars, self._new_bar_name) then
		ActionHistory.warn(mod:localize("gbm_hist_warn_create_duplicate", self._new_bar_name))
		self._new_bar_name = ""
		return
	end

	if #self._bars >= MAX_BARS then
		ActionHistory.warn(mod:localize("gbm_hist_warn_bar_limit_reached", MAX_BARS))
		mod:warning(("Gelato's Buff Manager: bar limit of %d reached; '%s' was not created."):format(
			MAX_BARS, self._new_bar_name))
		return
	end

	table.insert(self._bars, 1, self._new_bar_name)
	mod:set(BARS_SETTING_ID, self._bars)
	self._dirty = true

	if self._selected_bar_index then
		self._selected_bar_index = self._selected_bar_index + 1
	end

	ActionHistory.log(mod:localize("gbm_hist_bar_created", self._new_bar_name))
	self._new_bar_name = ""

	local bar_count = #self._bars
	if bar_count >= SOFT_WARN_BAR_COUNT then
		ActionHistory.warn(mod:localize("gbm_hist_warn_bar_soft_limit", bar_count, MAX_BARS))
	end
end

function BuffBarsComponent:_update_bar_controls()
	local create_bar = Imgui.button(L.CREATE_BAR)
	Imgui.same_line()
	local new_bar_name = Imgui.ided_input_text(NEW_BAR_INPUT_ID, self._new_bar_name)
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
		self:_create_bar()
	end

	Imgui.text(L.SELECT_BAR)
	Imgui.same_line()
	local previous_bar_index = self._selected_bar_index
	-- Bounded width: at the old-ImGui default (65% of pane) this combo pushed the
	-- Clear/Delete buttons past the pane edge on narrower windows, clipping them.
	local width_pushed = Imgui_helpers.push_width(SELECT_BAR_COMBO_WIDTH)
	self._selected_bar_index = Imgui.combo(SELECT_BAR_COMBO_ID, "", self._bars, self._selected_bar_index)
	Imgui_helpers.pop_width(width_pushed)
	if self._selected_bar_index ~= previous_bar_index then
		self._dirty = true
		if self._nav_tree_component then
			self._nav_tree_component:mark_dirty()
		end
	end

	local selected_names = self._nav_tree_component and self._nav_tree_component:get_selected_names()
	local selected_count = self._nav_tree_component and self._nav_tree_component:get_selected_count() or 0

	if Imgui.button(mod:localize("gbm_add_selected", selected_count)) then
		if not self._selected_bar_index then
			self._bar_action_error = L.NO_BAR_SELECTED_ERROR
			ActionHistory.warn(L.WARN_ADD_NO_BAR)
		elseif selected_count == 0 then
			ActionHistory.warn(L.WARN_ADD_NONE)
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
	if Imgui.button(mod:localize("gbm_remove_selected", selected_count)) then
		if not self._selected_bar_index then
			self._bar_action_error = L.NO_BAR_SELECTED_ERROR
			ActionHistory.warn(L.WARN_REMOVE_NO_BAR)
		elseif selected_count == 0 then
			ActionHistory.warn(L.WARN_REMOVE_NONE)
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
	local new_flag = Imgui.checkbox(L.TOGGLE_DEFAULT_BAR, current)
	if new_flag ~= current then
		mod:set(TOGGLE_DEFAULT_BAR_SETTING_ID, new_flag)
		ActionHistory.log(new_flag and L.DEFAULT_BAR_ON or L.DEFAULT_BAR_OFF)
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

	Imgui.text(L.SLOT_INFO)
	Imgui.separator()

	if table.is_nil_or_empty(self._bars) then
		Imgui.text(L.NO_BARS)
		return
	end

	local removed_a_buff = false
	local pending_delete_bar = nil
	local pending_move_bar, pending_move_dir = nil, nil

	for i = 1, #self._cached_bars do
		local bar_view = self._cached_bars[i]
		local bar = bar_view.name

		Imgui.push_id(bar_view.push_id)

		if Imgui.button(L.MOVE_UP) then
			pending_move_bar, pending_move_dir = bar, -1
		end
		Imgui.same_line()
		if Imgui.button(L.MOVE_DOWN) then
			pending_move_bar, pending_move_dir = bar, 1
		end
		Imgui.same_line()

		local is_active = mod.is_bar_active(bar)
		local new_active = Imgui.checkbox(L.BAR_ACTIVE, is_active)
		if new_active ~= is_active then
			mod.set_bar_active(bar, new_active)
			mod.recreate_hud()
			ActionHistory.log(mod:localize(new_active and "gbm_hist_bar_activated" or "gbm_hist_bar_deactivated", bar))
		end
		Imgui.same_line()

		if Imgui.button(L.CLEAR_BAR) then
			local cleared_count = self:_clear_bar_buffs(bar)
			if cleared_count > 0 then
				ActionHistory.log(mod:localize("gbm_hist_bar_cleared", bar, cleared_count))
			else
				ActionHistory.warn(mod:localize("gbm_hist_warn_bar_clear_empty", bar))
			end
		end
		Imgui.same_line()
		if Imgui.button(L.DELETE_BAR) then
			pending_delete_bar = bar
		end
		Imgui.same_line()

		-- Header rendered directly in the pane (no wrapping child window); a nested header
		-- child was what corrupted the pane's vertical scroll. Matches BBM's structure.
		if Imgui.collapsing_header(bar_view.header_label) then
			local over_limit_height = bar_view.over_limit and UiSettings.OVER_LIMIT_LINE_HEIGHT or 0
			Imgui.begin_child_window(bar_view.window_id, UiSettings.BAR_WINDOW_SIZE[1],
				UiSettings.BAR_WINDOW_SIZE[2] + over_limit_height, true,
				"always_auto_resize", "horizontal_scrollbar")

			if bar_view.over_limit then
				Imgui.text(L.OVER_LIMIT_DESC)
			end

			if bar_view.count > 0 then
				if _update_buffs(bar_view.entries) then
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
