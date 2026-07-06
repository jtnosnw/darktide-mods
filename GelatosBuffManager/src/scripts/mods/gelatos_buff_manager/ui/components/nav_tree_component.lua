local mod = get_mod("gelatos_buff_manager")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/table")
local Imgui_helpers = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/imgui")
local BuffPriorities = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/buff_priorities")
local ActionHistory = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/action_history")

-- Localized once at load; indexed by live priority value each frame.
local PRIO_VALUE_LABELS = {
	[0] = mod:localize("gbm_prio_value_0"),
	[1] = mod:localize("gbm_prio_value_1"),
	[2] = mod:localize("gbm_prio_value_2"),
}
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/ui/components/base_buff_component")
local UiSettings = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/ui/settings")
local Classifier = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/classification/buff_classifier")

local CLASS_NAME = "NavTreeComponent"

local NAV_HELP_LOC_ID = "gbm_nav_help"
local SEARCH_LOC_ID = "gbm_search_placeholder"
local CLEAR_SEARCH_LOC_ID = "gbm_clear_search"
local SELECT_ALL_LOC_ID = "gbm_select_all"
local DESELECT_ALL_LOC_ID = "gbm_deselect_all"
local SELECTION_COUNTER_LOC_ID = "gbm_selection_counter_text"
local FILTER_WEAPON_LOC_ID = "gbm_filter_weapon"
local FILTER_TDR_LOC_ID = "gbm_filter_tdr"
local FILTER_TOUGHNESS_LOC_ID = "gbm_filter_toughness"
local FILTER_CRIT_LOC_ID = "gbm_filter_crit"
local FILTER_COHERENCY_LOC_ID = "gbm_filter_coherency"
local FILTER_PLAYER_DEBUFFS_LOC_ID = "gbm_filter_player_debuffs"
local FILTER_STIM_LOC_ID = "gbm_filter_stim"
local FILTER_CDR_LOC_ID = "gbm_filter_cdr"
local FILTER_LIVE_EVENTS_LOC_ID = "gbm_filter_live_events"
local HIDE_ADDED_LOC_ID = "gbm_hide_added"
local MAX_TEXT_INPUT_LENGTH = 50

local NAV_WIDTH_STEP = 20

-- -------------------------------
-- ------- Local Functions -------
-- -------------------------------

local function _icon_size()
	local scale = 0.8
	local base = UiSettings.BUFF_IMAGE_SIZE[1]
	local size = math.floor(base * scale + 0.5)
	return size, size
end

-- -------------------------------
-- --------- Constructor ---------
-- -------------------------------
local NavTreeComponent = class(CLASS_NAME, "BaseBuffComponent")

function NavTreeComponent:init(buffs_data)
	NavTreeComponent.super.init(self, buffs_data)

	-- Set by ManagementWindow after both components exist (see window.lua) -- lets the
	-- "hide already added" filter ask which bar is currently selected without NavTreeComponent
	-- owning bar-list state itself (that now lives in BuffBarsComponent, per the mockup).
	self._bars_component = nil

	self._search_text = ""
	self._search_text_lower = ""
	self._selected = {}

	-- Filter chip state: archetype filters are OR'd with the weapon filter to pick which
	-- top-level groups are visible; the rest are independent AND-narrowing toggles.
	self._filter_archetypes = {}
	self._filter_weapon = false
	self._filter_tdr = false
	self._filter_toughness = false
	self._filter_crit = false
	self._filter_coherency = false
	self._filter_player_debuffs = false
	self._filter_stim = false
	self._filter_cdr = false
	self._filter_live_events = false
	self._hide_added = false

	-- Width the user can widen via the +/- buttons; UiSettings.NAV_WINDOW_SIZE[1] is the floor.
	self._nav_width = UiSettings.NAV_WINDOW_SIZE[1]

	self._grouped = {}
	self._dirty = true
	self._last_buffs_data_revision = -1
	self._had_zero_results = false
	self._collapse_epoch = 0

	self:_rebuild_groups()
end

-- -------------------------------
-- ------ Private Functions ------
-- -------------------------------

function NavTreeComponent:_matches_search(name)
	if self._search_text_lower == "" then
		return true
	end
	return type(name) == "string" and name:lower():find(self._search_text_lower, 1, true) ~= nil
end

function NavTreeComponent:_any_category_filter_active()
	if self._filter_weapon then
		return true
	end
	for _ in pairs(self._filter_archetypes) do
		return true
	end
	return false
end

function NavTreeComponent:_get_selected_bar_name()
	if self._bars_component then
		return self._bars_component:get_selected_bar_name()
	end
	return nil
end

function NavTreeComponent:_matches_filters(data)
	if self:_any_category_filter_active() then
		local passes_category = false
		if self._filter_weapon and data.category == Classifier.CATEGORY.weapon then
			passes_category = true
		end
		if not passes_category and data.archetype and self._filter_archetypes[data.archetype] then
			passes_category = true
		end
		if not passes_category then
			return false
		end
	end

	if self._filter_tdr and not Classifier.is_tdr(data.name) then
		return false
	end

	if self._filter_toughness and not Classifier.is_toughness(data.name) then
		return false
	end

	if self._filter_crit and not Classifier.is_crit(data.name) then
		return false
	end

	if self._filter_coherency and not Classifier.is_coherency(data.name) then
		return false
	end

	if self._filter_player_debuffs and not Classifier.is_player_debuff(data.name) then
		return false
	end

	if self._filter_stim and not Classifier.is_stim(data.name) then
		return false
	end

	if self._filter_cdr and not Classifier.is_cdr(data.name) then
		return false
	end

	if self._filter_live_events and not Classifier.is_live_event(data.name) then
		return false
	end

	if self._hide_added then
		local selected_bar = self:_get_selected_bar_name()
		if selected_bar and data.bar_name == selected_bar then
			return false
		end
	end

	return true
end

function NavTreeComponent:_prune_selection_for_hidden_added()
	if not self._hide_added then
		return
	end
	local selected_bar = self:_get_selected_bar_name()
	if not selected_bar then
		return
	end
	for name in pairs(self._selected) do
		local data = self._buffs_data[name]
		if data and data.bar_name == selected_bar then
			self._selected[name] = nil
		end
	end
end

function NavTreeComponent:_rebuild_groups()
	self:_prune_selection_for_hidden_added()
	table.clear(self._grouped)

	if table.is_nil_or_empty(self._buffs_data) then
		self._dirty = false
		return
	end

	for _, category in ipairs(Classifier.CATEGORY_ORDER) do
		self._grouped[category] = {}
	end

	for name, data in pairs(self._buffs_data) do
		if data.icon and data.icon ~= "" and self:_matches_search(name) and self:_matches_filters(data) then
			local bucket = self._grouped[data.category or Classifier.CATEGORY.other]
			if bucket then
				bucket[#bucket + 1] = data
			end
		end
	end

	for _, bucket in pairs(self._grouped) do
		table.sort(bucket, function(a, b)
			return (a.name or "") < (b.name or "")
		end)
	end

	local total = 0
	for _, bucket in pairs(self._grouped) do
		total = total + #bucket
	end

	local any_narrowing_active = self._search_text_lower ~= "" or self:_any_category_filter_active() or
		self._filter_tdr or self._filter_toughness or self._filter_crit or self._filter_coherency or
		self._filter_player_debuffs or self._filter_stim or self._filter_cdr or self._filter_live_events or
		self._hide_added

	if total == 0 and any_narrowing_active then
		self._had_zero_results = true
	elseif total > 0 and self._had_zero_results then
		self._collapse_epoch = self._collapse_epoch + 1
		self._had_zero_results = false
	end

	self._dirty = false
end

function NavTreeComponent:_update_intro_text()
	Imgui.text(mod:localize(NAV_HELP_LOC_ID))
end

function NavTreeComponent:_update_search_box()
	Imgui.text(mod:localize(SEARCH_LOC_ID))
	Imgui.same_line()

	local width_pushed = Imgui_helpers.push_width(590)
	local new_text = Imgui.ided_input_text(self.__class_name .. "_SEARCH", "", self._search_text)
	Imgui_helpers.pop_width(width_pushed)
	if new_text ~= self._search_text then
		if new_text and #new_text > MAX_TEXT_INPUT_LENGTH then
			new_text = new_text:sub(1, MAX_TEXT_INPUT_LENGTH)
			if not self._search_length_warned then
				self._search_length_warned = true
				mod:warning(("Gelato's Buff Manager: search input capped at %d characters."):format(
					MAX_TEXT_INPUT_LENGTH))
			end
		elseif self._search_length_warned then
			self._search_length_warned = false
		end
		self._search_text = new_text
		self._search_text_lower = (new_text or ""):lower()
		self._dirty = true
	end

	Imgui.same_line()
	if Imgui.button(mod:localize(CLEAR_SEARCH_LOC_ID) .. "##gbm_clear_search") then
		self._search_text = ""
		self._search_text_lower = ""
		self._dirty = true
		ActionHistory.log(mod:localize("gbm_hist_search_cleared"))
	end
end

function NavTreeComponent:_update_filter_chips()
	local changed = false

	for i, archetype in ipairs(Classifier.ARCHETYPE_ORDER) do
		if i > 1 then
			Imgui.same_line()
		end

		local checked = self._filter_archetypes[archetype] or false
		local new_checked = Imgui.checkbox(mod:localize(Classifier.ARCHETYPE_LOCALIZATION_KEY[archetype]), checked)
		if new_checked ~= checked then
			if new_checked then
				self._filter_archetypes[archetype] = true
			else
				self._filter_archetypes[archetype] = nil
			end
			changed = true
		end
	end

	local new_weapon = Imgui.checkbox(mod:localize(FILTER_WEAPON_LOC_ID), self._filter_weapon)
	if new_weapon ~= self._filter_weapon then
		self._filter_weapon = new_weapon
		changed = true
	end

	Imgui.same_line()
	local new_tdr = Imgui.checkbox(mod:localize(FILTER_TDR_LOC_ID), self._filter_tdr)
	if new_tdr ~= self._filter_tdr then
		self._filter_tdr = new_tdr
		changed = true
	end

	Imgui.same_line()
	local new_toughness = Imgui.checkbox(mod:localize(FILTER_TOUGHNESS_LOC_ID), self._filter_toughness)
	if new_toughness ~= self._filter_toughness then
		self._filter_toughness = new_toughness
		changed = true
	end

	Imgui.same_line()
	local new_crit = Imgui.checkbox(mod:localize(FILTER_CRIT_LOC_ID), self._filter_crit)
	if new_crit ~= self._filter_crit then
		self._filter_crit = new_crit
		changed = true
	end

	Imgui.same_line()
	local new_cdr = Imgui.checkbox(mod:localize(FILTER_CDR_LOC_ID), self._filter_cdr)
	if new_cdr ~= self._filter_cdr then
		self._filter_cdr = new_cdr
		changed = true
	end

	Imgui.same_line()
	local new_coherency = Imgui.checkbox(mod:localize(FILTER_COHERENCY_LOC_ID), self._filter_coherency)
	if new_coherency ~= self._filter_coherency then
		self._filter_coherency = new_coherency
		changed = true
	end

	Imgui.same_line()
	local new_player_debuffs = Imgui.checkbox(mod:localize(FILTER_PLAYER_DEBUFFS_LOC_ID), self._filter_player_debuffs)
	if new_player_debuffs ~= self._filter_player_debuffs then
		self._filter_player_debuffs = new_player_debuffs
		changed = true
	end

	Imgui.same_line()
	local new_stim = Imgui.checkbox(mod:localize(FILTER_STIM_LOC_ID), self._filter_stim)
	if new_stim ~= self._filter_stim then
		self._filter_stim = new_stim
		changed = true
	end

	Imgui.same_line()
	local new_live_events = Imgui.checkbox(mod:localize(FILTER_LIVE_EVENTS_LOC_ID), self._filter_live_events)
	if new_live_events ~= self._filter_live_events then
		self._filter_live_events = new_live_events
		changed = true
	end

	if changed then
		self._dirty = true
	end
end

function NavTreeComponent:_draw_buff_row(data, icon_w, icon_h)
	Imgui.push_id(self.__class_name .. "_ROW_" .. data.name)

	local checked = self._selected[data.name] or false
	local new_checked = Imgui.checkbox("##checkbox", checked)
	if new_checked ~= checked then
		if new_checked then
			self._selected[data.name] = true
		else
			self._selected[data.name] = nil
		end
	end

	Imgui.same_line()
	if data.icon and data.icon ~= "" then
		Imgui.image_button(data.icon, icon_w, icon_h, 255, 255, 255, 1)
		Imgui.same_line()
	end

	local bar_name = data.bar_name or ""
	-- Embedded newlines keep every line x-aligned with the name (cursor is already past
	-- the checkbox and icon). Priority is read live, so dropdown edits reflect instantly.
	if bar_name ~= "" then
		Imgui.text(data.name .. "\n[" .. bar_name .. "]\n" .. PRIO_VALUE_LABELS[BuffPriorities.get(data.name)])
	else
		Imgui.text(data.name)
	end

	Imgui.pop_id()
end

function NavTreeComponent:_update_hide_added_checkbox()
	local new_hide_added = Imgui.checkbox(mod:localize(HIDE_ADDED_LOC_ID), self._hide_added)
	if new_hide_added ~= self._hide_added then
		self._hide_added = new_hide_added
		self._dirty = true
		ActionHistory.log(mod:localize(new_hide_added and "gbm_hist_hide_added_on" or "gbm_hist_hide_added_off"))
	end
end

function NavTreeComponent:_count_selected()
	local count = 0
	for _ in pairs(self._selected) do
		count = count + 1
	end
	return count
end

function NavTreeComponent:_update_select_all_controls()
	if self._dirty then
		self:_rebuild_groups()
	end

	if Imgui.button(mod:localize(SELECT_ALL_LOC_ID)) then
		for _, category in ipairs(Classifier.CATEGORY_ORDER) do
			local bucket = self._grouped[category]
			if bucket then
				for i = 1, #bucket do
					self._selected[bucket[i].name] = true
				end
			end
		end
		ActionHistory.log(mod:localize("gbm_hist_select_all", self:_count_selected()))
	end

	Imgui.same_line()
	if Imgui.button(mod:localize(DESELECT_ALL_LOC_ID)) then
		ActionHistory.log(mod:localize("gbm_hist_deselect_all", self:_count_selected()))
		table.clear(self._selected)
	end

	local selected_count = self:_count_selected()
	Imgui.same_line()
	Imgui.text(mod:localize(SELECTION_COUNTER_LOC_ID))
	Imgui.same_line()
	Imgui.text(tostring(selected_count))
end

function NavTreeComponent:_update_tree_list()
	if self._dirty then
		self:_rebuild_groups()
	end

	local icon_w, icon_h = _icon_size()

	local min_width = UiSettings.NAV_WINDOW_SIZE[1]
	if Imgui.small_button("-##gbm_nav_width") then
		self._nav_width = math.max(min_width, self._nav_width - NAV_WIDTH_STEP)
	end
	Imgui.same_line()
	if Imgui.small_button("+##gbm_nav_width") then
		self._nav_width = math.min(900, self._nav_width + NAV_WIDTH_STEP)
	end
	Imgui.same_line()
	Imgui.text(mod:localize("gbm_nav_width_label"))

	-- height = 0 fills whatever vertical space remains in the window below this point,
	-- so the list grows/shrinks as the user resizes the window instead of being fixed.
	Imgui.begin_child_window(self.__class_name .. "_TREE", self._nav_width, 0, true,
		"horizontal_scrollbar")

	for _, category in ipairs(Classifier.CATEGORY_ORDER) do
		local bucket = self._grouped[category]
		if bucket and #bucket > 0 then
			-- "###category" (triple-hash) makes the ID depend ONLY on the category key, fully
			-- ignoring the visible "(count)" text for ID purposes. A double-hash still folds the
			-- whole string (including the changing count) into the ID, which would still reset
			-- the persisted open/closed state whenever the count changes -- this is the actual
			-- fix, not just a cosmetic ID suffix.
			local label = ("%s (%d)###%s_%d"):format(mod:localize(Classifier.CATEGORY_LOCALIZATION_KEY[category]),
				#bucket, category, self._collapse_epoch)
			Imgui.push_id(self.__class_name .. "_CAT_" .. category)

			if Imgui.tree_node(label) then
				for i = 1, #bucket do
					self:_draw_buff_row(bucket[i], icon_w, icon_h)
				end
				Imgui.tree_pop()
			end

			Imgui.pop_id()
		end
	end

	Imgui.end_child_window()
end

-- -------------------------------
-- ------- Public Functions ------
-- -------------------------------

function NavTreeComponent:mark_dirty()
	self._dirty = true
end

function NavTreeComponent:get_width()
	return self._nav_width
end

function NavTreeComponent:set_bars_component(bars_component)
	self._bars_component = bars_component
end

function NavTreeComponent:get_selected_names()
	return self._selected
end

function NavTreeComponent:get_selected_count()
	return self:_count_selected()
end

function NavTreeComponent:clear_selection()
	table.clear(self._selected)
end

function NavTreeComponent:_refresh_revision()
	local revision = mod:get_buffs_data_revision()
	if revision ~= self._last_buffs_data_revision then
		self._last_buffs_data_revision = revision
		self._dirty = true
	end
end

-- Top-of-window content -- called by window.lua in the exact order requested.
function NavTreeComponent:update_intro_row()
	self:_refresh_revision()
	self:_update_intro_text()
end

function NavTreeComponent:update_search_row()
	self:_update_search_box()
end

function NavTreeComponent:update_filter_chips_row()
	self:_update_filter_chips()
end

-- "BUFF NAV-TREE" column content -- called by window.lua inside the left column.
function NavTreeComponent:update_tree_section()
	self:_refresh_revision()
	self:_update_hide_added_checkbox()
	self:_update_select_all_controls()
	self:_update_tree_list()
end

return NavTreeComponent
