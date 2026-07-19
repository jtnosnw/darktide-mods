local mod = get_mod("gelatos_buff_manager")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/table")
local Imgui_helpers = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/imgui")
local BuffPriorities = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/buff_priorities")
local ActionHistory = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/action_history")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/ui/components/base_buff_component")
local UiSettings = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/ui/settings")
local Classifier = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/classification/buff_classifier")

local CLASS_NAME = "NavTreeComponent"

-- Every static label resolved ONCE at load. mod:localize() is a table lookup plus a possible
-- string.format, and this component was calling it ~20 times per frame for text that never
-- changes. Only parameterised strings stay dynamic.
local L = {
	NAV_HELP = mod:localize("gbm_nav_help"),
	SEARCH = mod:localize("gbm_search_placeholder"),
	SELECT_ALL = mod:localize("gbm_select_all"),
	DESELECT_ALL = mod:localize("gbm_deselect_all"),
	SELECTION_COUNTER = mod:localize("gbm_selection_counter_text"),
	FILTER_WEAPON = mod:localize("gbm_filter_weapon"),
	FILTER_TDR = mod:localize("gbm_filter_tdr"),
	FILTER_TOUGHNESS = mod:localize("gbm_filter_toughness"),
	FILTER_CRIT = mod:localize("gbm_filter_crit"),
	FILTER_COHERENCY = mod:localize("gbm_filter_coherency"),
	FILTER_PLAYER_DEBUFFS = mod:localize("gbm_filter_player_debuffs"),
	FILTER_STIM = mod:localize("gbm_filter_stim"),
	FILTER_CDR = mod:localize("gbm_filter_cdr"),
	FILTER_LIVE_EVENTS = mod:localize("gbm_filter_live_events"),
	HIDE_ADDED = mod:localize("gbm_hide_added"),
	NAV_WIDTH = mod:localize("gbm_nav_width_label"),
	CLEAR_SEARCH_BUTTON = mod:localize("gbm_clear_search") .. "##gbm_clear_search",
	SEARCH_CLEARED = mod:localize("gbm_hist_search_cleared"),
	HIDE_ADDED_ON = mod:localize("gbm_hist_hide_added_on"),
	HIDE_ADDED_OFF = mod:localize("gbm_hist_hide_added_off"),
}

local ARCHETYPE_LABELS = {}
for _, archetype in ipairs(Classifier.ARCHETYPE_ORDER) do
	ARCHETYPE_LABELS[archetype] = mod:localize(Classifier.ARCHETYPE_LOCALIZATION_KEY[archetype])
end

local CATEGORY_LABELS = {}
for _, category in ipairs(Classifier.CATEGORY_ORDER) do
	CATEGORY_LABELS[category] = mod:localize(Classifier.CATEGORY_LOCALIZATION_KEY[category])
end

-- Indexed by live priority value.
local PRIO_VALUE_LABELS = {
	[0] = mod:localize("gbm_prio_value_0"),
	[1] = mod:localize("gbm_prio_value_1"),
	[2] = mod:localize("gbm_prio_value_2"),
}

local SEARCH_INPUT_ID = CLASS_NAME .. "_SEARCH"
local TREE_WINDOW_ID = CLASS_NAME .. "_TREE"

local MAX_TEXT_INPUT_LENGTH = 50
local NAV_WIDTH_STEP = 20
local NAV_WIDTH_MAX = 900

-- -------------------------------
-- ------- Local Functions -------
-- -------------------------------

-- Hoisted: a fresh closure per table.sort call is a needless allocation.
local function _by_name(a, b)
	return (a.name or "") < (b.name or "")
end

local function _icon_size()
	local size = math.floor(UiSettings.BUFF_IMAGE_SIZE[1] * 0.8 + 0.5)
	return size, size
end

-- Row label is composed from three mutable values, so it is cached against those values rather
-- than against a revision counter -- it cannot go stale, because what it compares IS what it
-- displays. Previously every visible row allocated four strings every frame.
local function _row_label(data)
	local bar_name = data.bar_name or ""
	local priority = BuffPriorities.get(data.name)

	if data._ui_label == nil or data._ui_label_bar ~= bar_name or data._ui_label_prio ~= priority then
		if bar_name ~= "" then
			-- Embedded newlines keep every line x-aligned with the name (cursor is already past
			-- the checkbox and icon).
			data._ui_label = data.name .. "\n[" .. bar_name .. "]\n" .. PRIO_VALUE_LABELS[priority]
		else
			data._ui_label = data.name
		end
		data._ui_label_bar = bar_name
		data._ui_label_prio = priority
	end

	return data._ui_label
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
	self._selected_count = 0

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
	-- Header text per category, rebuilt with the buckets so it costs nothing per frame.
	self._category_labels = {}
	-- Measured row height per category, fed back into the virtualizer each frame.
	self._row_heights = {}
	self._dirty = true
	self._last_buffs_data_revision = -1
	self._had_zero_results = false
	self._collapse_epoch = 0

	-- One reusable draw callback + context, so virtualizing does not allocate a closure per
	-- category per frame.
	self._draw_ctx = { bucket = nil, icon_w = 0, icon_h = 0 }
	self._draw_row_fn = function(index)
		local ctx = self._draw_ctx
		self:_draw_buff_row(ctx.bucket[index], ctx.icon_w, ctx.icon_h)
	end

	self:_rebuild_groups()
end

-- -------------------------------
-- ------ Private Functions ------
-- -------------------------------

-- Single funnel for selection writes so the cached count can never drift from the set.
function NavTreeComponent:_set_selected(name, flag)
	local was_selected = self._selected[name] ~= nil

	if flag and not was_selected then
		self._selected[name] = true
		self._selected_count = self._selected_count + 1
	elseif not flag and was_selected then
		self._selected[name] = nil
		self._selected_count = self._selected_count - 1
	end
end

function NavTreeComponent:_recount_selected()
	local count = 0
	for _ in pairs(self._selected) do
		count = count + 1
	end
	self._selected_count = count
end

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
	self:_recount_selected()
end

function NavTreeComponent:_rebuild_groups()
	self:_prune_selection_for_hidden_added()
	table.clear(self._grouped)
	table.clear(self._category_labels)

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

	local total = 0
	for _, bucket in pairs(self._grouped) do
		table.sort(bucket, _by_name)
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

	-- "###category" (triple-hash) makes the ID depend ONLY on the category key, fully ignoring
	-- the visible "(count)" text for ID purposes. A double-hash still folds the whole string
	-- (including the changing count) into the ID, which would reset the persisted open/closed
	-- state whenever the count changes. Built here rather than per frame -- the count and the
	-- collapse epoch can only change during a rebuild.
	for _, category in ipairs(Classifier.CATEGORY_ORDER) do
		local bucket = self._grouped[category]
		self._category_labels[category] = ("%s (%d)###%s_%d"):format(CATEGORY_LABELS[category],
			bucket and #bucket or 0, category, self._collapse_epoch)
	end

	-- Selection is only ever written through _set_selected, but the buff set underneath it can
	-- change (re-index, bar delete). This recount is dirty-gated and cheap, and removes any
	-- chance of the counter and the set disagreeing.
	self:_recount_selected()

	self._dirty = false
end

function NavTreeComponent:_update_intro_text()
	Imgui.text(L.NAV_HELP)
end

function NavTreeComponent:_update_search_box()
	Imgui.text(L.SEARCH)
	Imgui.same_line()

	local width_pushed = Imgui_helpers.push_width(590)
	local new_text = Imgui.ided_input_text(SEARCH_INPUT_ID, "", self._search_text)
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
	if Imgui.button(L.CLEAR_SEARCH_BUTTON) then
		self._search_text = ""
		self._search_text_lower = ""
		self._dirty = true
		ActionHistory.log(L.SEARCH_CLEARED)
	end
end

function NavTreeComponent:_update_filter_chips()
	local changed = false

	for i, archetype in ipairs(Classifier.ARCHETYPE_ORDER) do
		if i > 1 then
			Imgui.same_line()
		end

		local checked = self._filter_archetypes[archetype] or false
		local new_checked = Imgui.checkbox(ARCHETYPE_LABELS[archetype], checked)
		if new_checked ~= checked then
			self._filter_archetypes[archetype] = new_checked or nil
			changed = true
		end
	end

	local new_weapon = Imgui.checkbox(L.FILTER_WEAPON, self._filter_weapon)
	if new_weapon ~= self._filter_weapon then
		self._filter_weapon = new_weapon
		changed = true
	end

	Imgui.same_line()
	local new_tdr = Imgui.checkbox(L.FILTER_TDR, self._filter_tdr)
	if new_tdr ~= self._filter_tdr then
		self._filter_tdr = new_tdr
		changed = true
	end

	Imgui.same_line()
	local new_toughness = Imgui.checkbox(L.FILTER_TOUGHNESS, self._filter_toughness)
	if new_toughness ~= self._filter_toughness then
		self._filter_toughness = new_toughness
		changed = true
	end

	Imgui.same_line()
	local new_crit = Imgui.checkbox(L.FILTER_CRIT, self._filter_crit)
	if new_crit ~= self._filter_crit then
		self._filter_crit = new_crit
		changed = true
	end

	Imgui.same_line()
	local new_cdr = Imgui.checkbox(L.FILTER_CDR, self._filter_cdr)
	if new_cdr ~= self._filter_cdr then
		self._filter_cdr = new_cdr
		changed = true
	end

	Imgui.same_line()
	local new_coherency = Imgui.checkbox(L.FILTER_COHERENCY, self._filter_coherency)
	if new_coherency ~= self._filter_coherency then
		self._filter_coherency = new_coherency
		changed = true
	end

	Imgui.same_line()
	local new_player_debuffs = Imgui.checkbox(L.FILTER_PLAYER_DEBUFFS, self._filter_player_debuffs)
	if new_player_debuffs ~= self._filter_player_debuffs then
		self._filter_player_debuffs = new_player_debuffs
		changed = true
	end

	Imgui.same_line()
	local new_stim = Imgui.checkbox(L.FILTER_STIM, self._filter_stim)
	if new_stim ~= self._filter_stim then
		self._filter_stim = new_stim
		changed = true
	end

	Imgui.same_line()
	local new_live_events = Imgui.checkbox(L.FILTER_LIVE_EVENTS, self._filter_live_events)
	if new_live_events ~= self._filter_live_events then
		self._filter_live_events = new_live_events
		changed = true
	end

	if changed then
		self._dirty = true
	end
end

-- The ID pushed per row is the buff NAME only (a leaf ID). Uniqueness comes from this component
-- pushing its own ID around the whole pane, so the same buff may also appear in another pane
-- without the two colliding. Any future pane MUST follow the same convention.
function NavTreeComponent:_draw_buff_row(data, icon_w, icon_h)
	if not data then
		return
	end

	Imgui.push_id(data.name)

	local checked = self._selected[data.name] ~= nil
	local new_checked = Imgui.checkbox("##checkbox", checked)
	if new_checked ~= checked then
		self:_set_selected(data.name, new_checked)
	end

	Imgui.same_line()
	if data.icon and data.icon ~= "" then
		Imgui.image_button(data.icon, icon_w, icon_h, 255, 255, 255, 1)
		Imgui.same_line()
	end

	Imgui.text(_row_label(data))

	Imgui.pop_id()
end

function NavTreeComponent:_update_hide_added_checkbox()
	local new_hide_added = Imgui.checkbox(L.HIDE_ADDED, self._hide_added)
	if new_hide_added ~= self._hide_added then
		self._hide_added = new_hide_added
		self._dirty = true
		ActionHistory.log(new_hide_added and L.HIDE_ADDED_ON or L.HIDE_ADDED_OFF)
	end
end

function NavTreeComponent:_update_select_all_controls()
	if self._dirty then
		self:_rebuild_groups()
	end

	if Imgui.button(L.SELECT_ALL) then
		for _, category in ipairs(Classifier.CATEGORY_ORDER) do
			local bucket = self._grouped[category]
			if bucket then
				for i = 1, #bucket do
					self:_set_selected(bucket[i].name, true)
				end
			end
		end
		ActionHistory.log(mod:localize("gbm_hist_select_all", self._selected_count))
	end

	Imgui.same_line()
	if Imgui.button(L.DESELECT_ALL) then
		ActionHistory.log(mod:localize("gbm_hist_deselect_all", self._selected_count))
		self:clear_selection()
	end

	Imgui.same_line()
	Imgui.text(L.SELECTION_COUNTER)
	Imgui.same_line()
	Imgui.text(tostring(self._selected_count))
end

function NavTreeComponent:_update_tree_list()
	if self._dirty then
		self:_rebuild_groups()
	end

	local icon_w, icon_h = _icon_size()
	local draw_ctx = self._draw_ctx
	draw_ctx.icon_w = icon_w
	draw_ctx.icon_h = icon_h

	local min_width = UiSettings.NAV_WINDOW_SIZE[1]
	if Imgui.small_button("-##gbm_nav_width") then
		self._nav_width = math.max(min_width, self._nav_width - NAV_WIDTH_STEP)
	end
	Imgui.same_line()
	if Imgui.small_button("+##gbm_nav_width") then
		self._nav_width = math.min(NAV_WIDTH_MAX, self._nav_width + NAV_WIDTH_STEP)
	end
	Imgui.same_line()
	Imgui.text(L.NAV_WIDTH)

	-- height = 0 fills whatever vertical space remains in the window below this point,
	-- so the list grows/shrinks as the user resizes the window instead of being fixed.
	Imgui.begin_child_window(TREE_WINDOW_ID, self._nav_width, 0, true, "horizontal_scrollbar")

	-- Component-level ID scope: rows below push only their buff name, which keeps row IDs unique
	-- across panes without composing a string per row per frame.
	Imgui.push_id(CLASS_NAME)

	for _, category in ipairs(Classifier.CATEGORY_ORDER) do
		local bucket = self._grouped[category]
		if bucket and #bucket > 0 then
			Imgui.push_id(category)

			if Imgui.tree_node(self._category_labels[category]) then
				draw_ctx.bucket = bucket

				local row_height = self._row_heights[category] or UiSettings.NAV_ROW_HEIGHT
				self._row_heights[category] = Imgui_helpers.draw_virtualized_rows(#bucket, row_height,
					self._draw_row_fn)

				Imgui.tree_pop()
			end

			Imgui.pop_id()
		end
	end

	Imgui.pop_id()
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
	return self._selected_count
end

function NavTreeComponent:clear_selection()
	table.clear(self._selected)
	self._selected_count = 0
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
