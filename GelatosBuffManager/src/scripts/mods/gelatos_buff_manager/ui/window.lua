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
local BuffIconIndex = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/classification/buff_icon_index")
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

-- Reused across the whole catalog build so the per-template loop allocates nothing.
local _candidates_scratch = {}

function ManagementWindow:_reindex_catalog_data()
	local catalog = {}
	local cached_items = MASTER_ITEMS.get_cached()

	-- Rebuilt every time, not just once at load, so a re-index after a game patch is honest.
	local ok_index, index_err = pcall(BuffIconIndex.build, BUFF_TEMPLATES, cached_items)
	if not ok_index then
		mod:error(("Gelato's Buff Manager: failed to build the buff icon index: %s"):format(tostring(index_err)))
		self._catalog_cache = catalog
		self._catalog_cache_ready = true
		return catalog
	end

	for key, template in pairs(BUFF_TEMPLATES) do
		if not BuffIconIndex.NON_TEMPLATE_KEYS[key] and type(template) == "table" and template.name then
			local ok, icon = pcall(BuffIconIndex.get_icon, template, _candidates_scratch)
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
