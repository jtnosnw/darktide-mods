local mod = get_mod("gelatos_buff_manager")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/ui/components/base_component")

local ok_templates, BUFF_TEMPLATES = pcall(require, "scripts/settings/buff/buff_templates")
if not ok_templates then
	mod:error("Gelato's Buff Manager: scripts/settings/buff/buff_templates failed to load -- the buff catalog will be empty until this is fixed (likely a game update moved/renamed this file).")
	BUFF_TEMPLATES = {}
end

local ok_items, MASTER_ITEMS = pcall(require, "scripts/backend/master_items")
if not ok_items then
	mod:error("Gelato's Buff Manager: scripts/backend/master_items failed to load -- some buff icons may be missing.")
	MASTER_ITEMS = { get_cached = function() return {} end }
end

local BuffData = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/models/buff_data")
local Classifier = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/classification/buff_classifier")
local BuffsDataPersist = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/buffs_data_persist")
local VERSION = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/gelatos_buff_manager_version")

local UiSettings = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/ui/settings")
local ActionHistory = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/action_history")
local SettingsComponent = mod:io_dofile(
	"gelatos_buff_manager/scripts/mods/gelatos_buff_manager/ui/components/settings_component")
local PriorityComponent = mod:io_dofile(
	"gelatos_buff_manager/scripts/mods/gelatos_buff_manager/ui/components/priority_component")
local BuffBarsComponent = mod:io_dofile(
	"gelatos_buff_manager/scripts/mods/gelatos_buff_manager/ui/components/buff_bars_component")
local NavTreeComponent = mod:io_dofile(
	"gelatos_buff_manager/scripts/mods/gelatos_buff_manager/ui/components/nav_tree_component")

local CLASS_NAME = "ManagementWindow"

local WINDOW_TITLE = ("%s v%s"):format(mod:localize("mod_name"), VERSION)

local BUFFS_DATA_SETTING_ID = "buffs_data"

-- -------------------------------
-- ------- Local Functions -------
-- -------------------------------

local function _add_unique_name(candidate_names, value)
	if not value or value == "" then
		return
	end
	for _, existing_value in ipairs(candidate_names) do
		if existing_value == value then
			return
		end
	end
	table.insert(candidate_names, value)
end

local function _get_buff_name_candidates(buff_name)
	local candidate_names = {}
	_add_unique_name(candidate_names, buff_name)
	_add_unique_name(candidate_names, buff_name:gsub("_parent$", ""))
	_add_unique_name(candidate_names, buff_name:gsub("_child$", ""))
	_add_unique_name(candidate_names, buff_name:gsub("_proc$", ""))
	return candidate_names
end

local function _item_has_trait_name(item, candidate_names)
	if type(item) ~= "table" then
		return false
	end

	for _, candidate_name in ipairs(candidate_names) do
		if item.trait == candidate_name or item.trait_name == candidate_name then
			return true
		end

		if type(item.traits) == "table" then
			for _, trait in pairs(item.traits) do
				if trait == candidate_name then
					return true
				end
				if type(trait) == "table" then
					if trait.name == candidate_name or trait.id == candidate_name or trait.trait == candidate_name or
						trait.trait_name == candidate_name then
						return true
					end
				end
			end
		end
	end

	return false
end

local function get_icon(buff_template, cached_items)
	if buff_template.hide_icon_in_hud then
		return nil
	end

	if buff_template.hud_icon then
		return buff_template.hud_icon
	end

	local candidate_names = _get_buff_name_candidates(buff_template.name)

	for _, candidate_name in ipairs(candidate_names) do
		local parent = table.find_by_key(BUFF_TEMPLATES, "child_buff_template", candidate_name)
		if parent and BUFF_TEMPLATES[parent] and BUFF_TEMPLATES[parent].hud_icon then
			return BUFF_TEMPLATES[parent].hud_icon
		end
	end

	if buff_template.child_buff_template then
		local child_template = table.find_by_key(BUFF_TEMPLATES, "name", buff_template.child_buff_template)
		if child_template and child_template.hud_icon then
			return child_template.hud_icon
		end
	end

	if type(cached_items) ~= "table" then
		cached_items = {}
	end

	for _, item in pairs(cached_items) do
		if _item_has_trait_name(item, candidate_names) then
			if item.icon and item.icon ~= "" then
				return item.icon
			end
			if item.hud_icon and item.hud_icon ~= "" then
				return item.hud_icon
			end
		end
	end

	return nil
end

local function _clone_buffs_data(source_buffs_data)
	local cloned_buffs_data = {}
	if table.is_nil_or_empty(source_buffs_data) then
		return cloned_buffs_data
	end

	for name, buff_data in pairs(source_buffs_data) do
		if type(buff_data) == "table" and not string.is_nil_or_whitespace(buff_data.name or name) then
			cloned_buffs_data[name] = BuffData:new({
				name = buff_data.name or name,
				icon = buff_data.icon,
				category = buff_data.category,
				archetype = buff_data.archetype,
				is_hidden = buff_data.is_hidden,
				bar_name = buff_data.bar_name,
			})
		end
	end

	return cloned_buffs_data
end

local function _overlay_saved_assignments(buffs_data, raw_buffs_data)
	if table.is_nil_or_empty(raw_buffs_data) then
		return
	end

	for _, data in pairs(raw_buffs_data) do
		if type(data) == "table" and not string.is_nil_or_whitespace(data.name) then
			local template = BUFF_TEMPLATES[data.name]
			if template then
				if buffs_data[data.name] == nil then
					local category, archetype = Classifier.classify(data.name)
					local saved_category = Classifier.CATEGORY_LOCALIZATION_KEY[data.category] and data.category or category
					buffs_data[data.name] = BuffData:new({
						name = data.name,
						icon = data.icon,
						category = saved_category,
						archetype = data.archetype or archetype,
					})
				end
				buffs_data[data.name].is_hidden = data.is_hidden or false
				buffs_data[data.name].bar_name = data.bar_name or ""
			end
		end
	end
end

-- -------------------------------
-- --------- Constructor ---------
-- -------------------------------
local ManagementWindow = class(CLASS_NAME, "BaseComponent")

function ManagementWindow:init()
	ManagementWindow.super.init(self)

	self.is_open = false
	self._needs_reposition = true
	self._buffs_data = nil
	self._buffs_data_cache_ready = false
	self._catalog_cache = nil
	self._catalog_cache_ready = false

	self._settings_component = nil
	self._buff_bars_component = nil
	self._nav_tree_component = nil
	self._priority_component = nil
end

-- -------------------------------
-- ------ Private Functions ------
-- -------------------------------

function ManagementWindow:_reindex_catalog_data()
	local catalog = {}
	local cached_items = MASTER_ITEMS.get_cached()

	for buff_category, template in pairs(BUFF_TEMPLATES) do
		if not (buff_category == "PREDICTED" or buff_category == "NON_PREDICTED") then
			local ok, icon = pcall(get_icon, template, cached_items)
			if ok and not string.is_nil_or_whitespace(icon) then
				local category, archetype = Classifier.classify(template.name)
				catalog[template.name] = BuffData:new({
					name = template.name,
					icon = icon,
					category = category,
					archetype = archetype,
				})
			end
		end
	end

	self._catalog_cache = catalog
	self._catalog_cache_ready = true

	return catalog
end

-- The catalog is fully deterministic (BUFF_TEMPLATES + our classifier), so it's never
-- persisted to user_settings.config -- only recomputed in-memory, once per session.
function ManagementWindow:_load_catalog_data()
	if self._catalog_cache_ready and self._catalog_cache ~= nil then
		return self._catalog_cache
	end

	return self:_reindex_catalog_data()
end

function ManagementWindow:_load_buffs_data()
	if self._buffs_data_cache_ready and self._buffs_data ~= nil then
		return
	end

	local buffs_data = _clone_buffs_data(self:_load_catalog_data())
	local raw_buffs_data = mod:get(BUFFS_DATA_SETTING_ID)

	_overlay_saved_assignments(buffs_data, raw_buffs_data)

	self._buffs_data = buffs_data
	self._buffs_data_cache_ready = true
end

function ManagementWindow:_save_buffs_data()
	BuffsDataPersist.save(self._buffs_data)
end

function ManagementWindow:_create_ui_components()
	local settings_widgets = mod:get_internal_data("options").widgets
	self._settings_component = SettingsComponent:new(settings_widgets)
	self._nav_tree_component = NavTreeComponent:new(self._buffs_data)
	self._buff_bars_component = BuffBarsComponent:new(self._buffs_data, self._nav_tree_component)
	self._nav_tree_component:set_bars_component(self._buff_bars_component)
	self._priority_component = PriorityComponent:new(self._nav_tree_component)
end

function ManagementWindow:_destroy_ui_components()
	self._settings_component = nil
	self._buff_bars_component = nil
	self._nav_tree_component = nil
	self._priority_component = nil
end

-- -------------------------------
-- ------- Public Functions ------
-- -------------------------------

function ManagementWindow:open()
	local input_manager = Managers.input
	local name = self.__class_name

	if input_manager and not input_manager:cursor_active() then
		input_manager:push_cursor(name)
	end

	self:_load_buffs_data()
	self:_create_ui_components()

	self._needs_reposition = true
	self.is_open = true
	Imgui.open_imgui()
end

function ManagementWindow:close()
	local input_manager = Managers.input
	local name = self.__class_name

	if input_manager and input_manager:cursor_active() then
		input_manager:pop_cursor(name)
	end

	self:_save_buffs_data()
	self:_destroy_ui_components()

	self.is_open = false
	Imgui.close_imgui()
end

function ManagementWindow:invalidate_catalog_cache()
	self._catalog_cache = nil
	self._catalog_cache_ready = false
	self._buffs_data = nil
	self._buffs_data_cache_ready = false
end

function ManagementWindow:reindex_catalog()
	self:invalidate_catalog_cache()

	local buffs_data = self:_reindex_catalog_data()
	local raw_buffs_data = mod:get(BUFFS_DATA_SETTING_ID)

	buffs_data = _clone_buffs_data(buffs_data)
	_overlay_saved_assignments(buffs_data, raw_buffs_data)

	self._buffs_data = buffs_data
	self._buffs_data_cache_ready = true

	if self.is_open then
		self:_destroy_ui_components()
		self:_create_ui_components()
	end
end

function ManagementWindow:update()
	if not self.is_open then
		return
	end

	if self._needs_reposition then
		self._needs_reposition = false
		Imgui.set_next_window_pos(100, 100)
		Imgui.set_next_window_size(1270, 560)
	end

	local _, closed = Imgui.begin_window(WINDOW_TITLE)
	if closed then
		self:close()
	else
		self._nav_tree_component:update_intro_row()
		self._settings_component:update()
		Imgui.separator()

		Imgui.text(mod:localize("gbm_header_buff_filters"))
		self._nav_tree_component:update_search_row()
		self._nav_tree_component:update_filter_chips_row()
		Imgui.separator()

		Imgui.begin_child_window(self.__class_name .. "_LEFT_PANE", self._nav_tree_component:get_width(),
			UiSettings.HISTORY_PANEL_OFFSET, false)
		Imgui.text(mod:localize("gbm_header_buff_nav_tree"))
		self._nav_tree_component:update_tree_section()
		Imgui.end_child_window()

		Imgui.same_line()

		Imgui.begin_child_window(self.__class_name .. "_MIDDLE_PANE", UiSettings.PRIORITY_WINDOW_SIZE[1],
			UiSettings.HISTORY_PANEL_OFFSET, false)
		Imgui.text(mod:localize("gbm_header_buff_priority"))
		Imgui.separator()
		self._priority_component:update()
		Imgui.end_child_window()

		Imgui.same_line()

		Imgui.begin_child_window(self.__class_name .. "_RIGHT_PANE", 0, UiSettings.HISTORY_PANEL_OFFSET, false)
		Imgui.text(mod:localize("gbm_header_buff_bars"))
		Imgui.separator()
		self._buff_bars_component:update()
		Imgui.end_child_window()

		Imgui.separator()
		Imgui.text(mod:localize("gbm_header_action_history"))
		Imgui.begin_child_window(self.__class_name .. "_ACTION_HISTORY", 0, 0, false)
		local history = ActionHistory.entries()
		for i = 1, #history do
			Imgui.text(history[i])
		end
		Imgui.end_child_window()
	end
	Imgui.end_window()
end

return ManagementWindow
