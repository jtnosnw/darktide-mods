require("scripts/ui/hud/elements/player_buffs/hud_element_player_buffs_polling")

local mod = get_mod("gelatos_buff_manager")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/table")
local BuffBarDefinitions = mod:io_dofile(
	"gelatos_buff_manager/scripts/mods/gelatos_buff_manager/hud/hud_element_buff_bar_definitions")

-- Cache vanilla definitions for the temporary swap trick
local VanillaDefinitions = require(
	"scripts/ui/hud/elements/player_buffs/hud_element_player_buffs_definitions"
)

local PlayerBuffsSettings = require(
	"scripts/ui/hud/elements/player_buffs/hud_element_player_buffs_settings"
)

local ok_buff_settings, BuffSettings = pcall(require, "scripts/settings/buff/buff_settings")
local buff_categories = ok_buff_settings and BuffSettings.buff_categories or nil
local buff_category_order = ok_buff_settings and BuffSettings.buff_category_order or nil

local BuffPriorities = mod:io_dofile(
	"gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/buff_priorities")

local GROUP_BUFFS_IN_CATEGORIES_SETTING_ID = "group_buffs_in_categories"

-- 15 positive / 5 negative slot split, derived exactly like the vanilla polling file.
local MAX_BUFFS = PlayerBuffsSettings.max_buffs
local QUARTER_MAX_BUFF = math.floor(MAX_BUFFS * 0.25)
local THREE_QUARTER_MAX_BUFF = MAX_BUFFS - QUARTER_MAX_BUFF

local math_huge = math.huge
local math_max = math.max

-- Stable reference to the ONE global priority table (mutated in place, never replaced).
local _priorities = BuffPriorities.raw()

-- Priority tier first (2 High > 1 Default > 0 Low), then the exact vanilla order
-- (activated_time, hud_priority, start_index) so behavior inside a tier is unchanged.
local function _compare_buffs_prioritized(a, b)
	local priority_a = _priorities[a.buff_name] or 1
	local priority_b = _priorities[b.buff_name] or 1

	if priority_a ~= priority_b then
		return priority_a > priority_b
	end

	if a.activated_time == b.activated_time then
		local hud_priority_a = a.hud_priority
		local hud_priority_b = b.hud_priority

		if hud_priority_a ~= hud_priority_b then
			if hud_priority_a and not hud_priority_b then
				return true
			end
			if not hud_priority_a and hud_priority_b then
				return false
			end
			return hud_priority_a < hud_priority_b
		end

		return a.start_index < b.start_index
	end

	return a.activated_time < b.activated_time
end

-- Half a buff-slot gap inserted between non-empty categories, identical to the
-- vanilla default bar (HudElementPlayerBuffs._update_buff_alignments).
local GAP_OFFSET_SIZE = 0.5

-- Scratch maps reused across frames to avoid per-frame allocation.
local _number_of_buffs_per_category = {}
local _category_numbers = {}

local type = type

local function _resolve_buff_template_name(buff_instance)
	if buff_instance == nil then
		return nil
	end

	local cached = buff_instance._gbm_template_name
	if cached ~= nil then
		return cached ~= false and cached or nil
	end

	local buff_template = nil
	if type(buff_instance.template) == "function" then
		buff_template = buff_instance:template()
	end

	local template_name = buff_template and buff_template.name or nil

	if type(template_name) ~= "string" or template_name == "" then
		template_name = buff_instance._template_name
	end

	if (type(template_name) ~= "string" or template_name == "") and type(buff_instance.template_name) == "function" then
		template_name = buff_instance:template_name()
	end

	if type(template_name) ~= "string" or template_name == "" then
		buff_instance._gbm_template_name = false
		return nil
	end

	buff_instance._gbm_template_name = template_name
	return template_name
end

local function _filter_matches_buff(filter, buff_instance)
	if filter == nil or buff_instance == nil then
		return false
	end

	local template_name = _resolve_buff_template_name(buff_instance)
	return template_name ~= nil and filter[template_name] == true
end

local function _clear_array(tbl)
	if table.clear then
		table.clear(tbl)
		return
	end
	for i = #tbl, 1, -1 do
		tbl[i] = nil
	end
end

local function _clear_map(tbl)
	if table.clear then
		table.clear(tbl)
		return
	end
	for k in pairs(tbl) do
		tbl[k] = nil
	end
end

-- -------------------------------
-- --------- Constructor ---------
-- -------------------------------
local HudElementBuffBar = class("GBMHudElementBuffBar", "HudElementPlayerBuffs")

function HudElementBuffBar:init(parent, draw_layer, start_scale, filter, bar_index)
	local orig_scenegraph = VanillaDefinitions.scenegraph_definition
	local orig_widget_defs = VanillaDefinitions.widget_definitions
	local orig_buff_def = VanillaDefinitions.buff_widget_definition

	-- Per-instance scenegraph (not the shared module-level table) so each bar's position
	-- is correct from construction, not dependent on a post-init mutation that could get
	-- overwritten by anything re-reading the shared default.
	local instance_scenegraph = BuffBarDefinitions.build_scenegraph_definition(bar_index)
	local instance_definitions = {
		animations = BuffBarDefinitions.animations,
		buff_widget_definition = BuffBarDefinitions.buff_widget_definition,
		widget_definitions = BuffBarDefinitions.widget_definitions,
		scenegraph_definition = instance_scenegraph,
	}

	VanillaDefinitions.scenegraph_definition = instance_scenegraph
	VanillaDefinitions.widget_definitions = BuffBarDefinitions.widget_definitions
	VanillaDefinitions.buff_widget_definition = BuffBarDefinitions.buff_widget_definition

	HudElementBuffBar.super.init(self, parent, draw_layer, start_scale, instance_definitions)

	VanillaDefinitions.scenegraph_definition = orig_scenegraph
	VanillaDefinitions.widget_definitions = orig_widget_defs
	VanillaDefinitions.buff_widget_definition = orig_buff_def

	self._definitions = instance_definitions
	self._filter = filter
	self._filtered_buffs_cache = {}
	self._use_categories = (ok_buff_settings and mod:get(GROUP_BUFFS_IN_CATEGORIES_SETTING_ID)) and true or false
end

-- -------------------------------
-- ------- Event Functions -------
-- -------------------------------

function HudElementBuffBar:event_player_buff_added(player, buff_instance)
	if _filter_matches_buff(self._filter, buff_instance) then
		HudElementBuffBar.super.event_player_buff_added(self, player, buff_instance)
	end
end

function HudElementBuffBar:event_player_buff_stack_added(player, buff_instance)
	if _filter_matches_buff(self._filter, buff_instance) then
		HudElementBuffBar.super.event_player_buff_stack_added(self, player, buff_instance)
	end
end

-- -------------------------------
-- ------ Private Functions ------
-- -------------------------------

-- CONFIRMED from the actual game source (hud_element_player_buffs_polling.lua): the vanilla
-- super class already caps actual widget assignment at 20 per instance (15 positive/5
-- negative slots) and does so gracefully (a nil widget from _get_available_widget() is
-- null-checked, not a crash), picking which buffs get a slot by activation time then
-- hud_priority. We just filter to this bar's assigned buffs and hand everything through --
-- letting vanilla's own prioritization decide beats any pre-truncation we could do here.
function HudElementBuffBar:_sync_current_active_buffs(buffs)
	if not buffs then
		return
	end

	local filter = self._filter
	local filtered_buffs = self._filtered_buffs_cache
	_clear_array(filtered_buffs)

	local count = 0
	for i = 1, #buffs do
		local buff = buffs[i]
		if filter and _filter_matches_buff(filter, buff) then
			count = count + 1
			filtered_buffs[count] = buff
		end
	end

	if not filter or count == 0 then
		return
	end

	HudElementBuffBar.super._sync_current_active_buffs(self, filtered_buffs)
end

-- Frees a widget the same way vanilla's own hide path does, so a higher-priority buff
-- can claim it next poll. Also rewinds the _old_* counters vanilla uses for capacity
-- checks, otherwise the freed slot would be invisible for one extra frame.
function HudElementBuffBar:_release_widget_for_priority(buff_data, ui_renderer, is_negative)
	local widget = buff_data.widget

	buff_data.widget = nil
	buff_data.icon = nil
	buff_data.icon_gradient_map = nil
	buff_data.stack_count = nil
	buff_data.show_stack_count = nil
	buff_data.activated_time = math_huge

	self:_return_widget(widget, ui_renderer)

	self._old_visible_buffs = math_max((self._old_visible_buffs or 0) - 1, 0)
	if is_negative then
		self._old_active_negative_buffs = math_max((self._old_active_negative_buffs or 0) - 1, 0)
	else
		self._old_active_positive_buffs = math_max((self._old_active_positive_buffs or 0) - 1, 0)
	end
end

-- SUBCLASS-ONLY override: the vanilla HudElementPlayerBuffs instance never runs this, so
-- GBM priorities can never affect the game's default buff bar. Runs the untouched vanilla
-- poll first, then layers the priority tiers on top.
--
-- After the tiered re-sort, the first 15 positive / 5 negative shown buffs in array order
-- are the ones entitled to a widget slot. Vanilla widget assignment is sticky, so when an
-- entitled buff has no widget while a lower-ranked one still holds one, that widget is
-- released; the entitled buff claims it on the next poll. No deficit -> zero churn, and
-- within a tier the vanilla activation-time rotation is fully preserved.
function HudElementBuffBar:_update_buffs(t, ui_renderer)
	HudElementBuffBar.super._update_buffs(self, t, ui_renderer)

	if next(_priorities) == nil then
		return
	end

	local active_buffs_data = self._active_buffs_data
	local num_active_buffs = active_buffs_data and #active_buffs_data or 0

	if num_active_buffs < 2 then
		return
	end

	table.sort(active_buffs_data, _compare_buffs_prioritized)

	local positive_seen, negative_seen = 0, 0
	local positive_deficit, negative_deficit = 0, 0

	for i = 1, num_active_buffs do
		local buff_data = active_buffs_data[i]

		if buff_data.show and not buff_data.remove then
			local widget = buff_data.widget

			if buff_data.is_negative then
				negative_seen = negative_seen + 1
				if negative_seen <= QUARTER_MAX_BUFF then
					if not widget then
						negative_deficit = negative_deficit + 1
					end
				elseif widget and negative_deficit > 0 then
					negative_deficit = negative_deficit - 1
					self:_release_widget_for_priority(buff_data, ui_renderer, true)
				end
			else
				positive_seen = positive_seen + 1
				if positive_seen <= THREE_QUARTER_MAX_BUFF then
					if not widget then
						positive_deficit = positive_deficit + 1
					end
				elseif widget and positive_deficit > 0 then
					positive_deficit = positive_deficit - 1
					self:_release_widget_for_priority(buff_data, ui_renderer, false)
				end
			end
		end
	end
end

-- Single-row layout. Vanilla _update_buff_alignments lifts negative buffs
-- (debuffs) by -42 -- that is the vanilla two-row positive/negative split.
-- In a buff bar every icon must sit on ONE row inside the box, so lay them
-- all out in a single sequence at y = 0 regardless of sign.
--
-- When self._use_categories is set (and scripts/settings/buff/buff_settings
-- was available at load time), buffs are grouped by buff_category in
-- buff_category_order with a half-buff gap between non-empty categories.
function HudElementBuffBar:_update_buff_alignments(force_update, dt)
	local active_buffs_data = self._active_buffs_data
	if not active_buffs_data then
		return
	end

	local horizontal_spacing = PlayerBuffsSettings.horizontal_spacing
	local num_active_buffs = #active_buffs_data
	local use_categories = self._use_categories and buff_categories ~= nil and buff_category_order ~= nil

	if use_categories then
		_clear_map(_number_of_buffs_per_category)

		for i = 1, num_active_buffs do
			local buff_data = active_buffs_data[i]
			if buff_data and buff_data.show then
				local buff_category = buff_data.buff_category or buff_categories.generic
				_number_of_buffs_per_category[buff_category] = (_number_of_buffs_per_category[buff_category] or 0) + 1
			end
		end

		_clear_map(_category_numbers)

		local current_number = 0
		for _, buff_category in ipairs(buff_category_order) do
			local number_in_category = _number_of_buffs_per_category[buff_category] or 0
			_category_numbers[buff_category] = current_number
			current_number = current_number + number_in_category + (number_in_category > 0 and GAP_OFFSET_SIZE or 0)
		end
	end

	local index = 0

	for i = 1, num_active_buffs do
		local buff_data = active_buffs_data[i]
		local widget = buff_data and buff_data.widget

		if widget then
			local offset = widget.offset
			offset[2] = 0

			local old_x = offset[1]
			local target_x

			if use_categories then
				local buff_category = buff_data.buff_category or buff_categories.generic
				local aligned = _category_numbers[buff_category] or 0
				target_x = horizontal_spacing * aligned
				_category_numbers[buff_category] = aligned + 1
			else
				target_x = horizontal_spacing * index
			end

			if force_update then
				offset[1] = target_x
				widget.dirty = true
			elseif widget.initialize_offset then
				widget.initialize_offset = nil
				offset[1] = target_x + horizontal_spacing
				widget.content.opacity = 0
			else
				offset[1] = math.lerp(old_x, target_x, dt * 6)
				widget.content.opacity = math.lerp(widget.content.opacity, 1, dt * 4)
			end

			if old_x ~= offset[1] then
				widget.dirty = true
			end

			index = index + 1
		end
	end
end

-- -------------------------------
-- ------- Public Functions ------
-- -------------------------------

function HudElementBuffBar:draw(dt, t, ui_renderer, render_settings, input_service)
	-- The filter cache still holds the last poll's buff instances. Syncing stops while hidden, so
	-- drop them rather than pinning them alive until the next HUD recreate.
	if self._is_hidden or mod:is_in_hub() then
		_clear_array(self._filtered_buffs_cache)
		return
	end

	HudElementBuffBar.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
end

return HudElementBuffBar
