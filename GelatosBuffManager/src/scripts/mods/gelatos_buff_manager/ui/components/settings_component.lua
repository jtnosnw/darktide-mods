local mod = get_mod("gelatos_buff_manager")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/table")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/imgui")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/ui/components/base_component")
local BuffPriorities = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/buff_priorities")
local ActionHistory = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/action_history")

local CLASS_NAME = "SettingsComponent"

local TOGGLE_DEFAULT_BAR_SETTING_ID = "default_buff_bar_enabled"
local RESET_SETTINGS_LOC_ID = "gbm_reset_settings"
local RESET_SETTINGS_DESC_LOC_ID = "gbm_reset_settings_description"
local REINDEX_CATALOG_LOC_ID = "gbm_reindex_catalog"
local REINDEX_CATALOG_DESC_LOC_ID = "gbm_reindex_catalog_description"
local DUMP_IMGUI_API_LOC_ID = "gbm_dump_imgui_api"
local DUMP_IMGUI_API_DESC_LOC_ID = "gbm_dump_imgui_api_description"

local ERROR_PREFIX_FMT = "[%s][%s]"

local function validate_settings_widgets(settings_widgets)
	if settings_widgets == nil or table.is_empty(settings_widgets) then
		error(ERROR_PREFIX_FMT:format(mod:localize("mod_name"), CLASS_NAME) ..
			" SettingsComponent requires a non-empty settings_widgets table", 1)
	end
end

-- Only the catalog reindex/reset actions live here now -- these render in the full-width
-- BUFF FILTERS row (see window.lua). "Toggle default buff bar" moved to BuffBarsComponent,
-- since the mockup groups it under BUFF BARS instead.
local SettingsComponent = class(CLASS_NAME, "BaseComponent")

function SettingsComponent:init(settings_widgets)
	SettingsComponent.super.init(self)
	validate_settings_widgets(settings_widgets)

	self._settings_widgets = settings_widgets
end

function SettingsComponent:_update_reindex_catalog()
	if Imgui.button(mod:localize(REINDEX_CATALOG_LOC_ID)) then
		ActionHistory.log(mod:localize("gbm_hist_reindexed"))
		mod:reindex_buffs_catalog()
	end
	Imgui.same_line()
	Imgui.text(mod:localize(REINDEX_CATALOG_DESC_LOC_ID))
end

function SettingsComponent:_update_dump_imgui_api()
	if Imgui.button(mod:localize(DUMP_IMGUI_API_LOC_ID)) then
		ActionHistory.log(mod:localize("gbm_hist_imgui_dumped"))
		local keys = {}
		for key in pairs(Imgui) do
			keys[#keys + 1] = tostring(key)
		end
		table.sort(keys)
		mod:dump(keys)
		mod:info(("Gelato's Buff Manager: dumped %d Imgui keys to the log."):format(#keys))
		local history = ActionHistory.entries()
		mod:info(("Gelato's Buff Manager: ACTION HISTORY (%d entries):"):format(#history))
		for i = 1, #history do
			mod:info("Gelato's Buff Manager: " .. history[i])
		end
	end
	Imgui.same_line()
	Imgui.text(mod:localize(DUMP_IMGUI_API_DESC_LOC_ID))
end

local function _reset_widgets_recursive(widgets)
	for _, widget in ipairs(widgets) do
		-- Never unbind the open-GBM hotkey: resetting settings must not clear keybinds.
		if widget.setting_id and widget.default_value ~= nil and widget.type ~= "keybind" then
			mod:set(widget.setting_id, widget.default_value)
		end
		if widget.sub_widgets then
			_reset_widgets_recursive(widget.sub_widgets)
		end
	end
end

function SettingsComponent:_update_reset_settings()
	if Imgui.button(mod:localize(RESET_SETTINGS_LOC_ID)) then
		_reset_widgets_recursive(self._settings_widgets)
		mod:set("bars", {})
		mod:set("buffs_data", {})
		mod:set("bar_active_states", {})
		mod:set("gbm_bar_slots", nil)
		BuffPriorities.reset_all()
		ActionHistory.log(mod:localize("gbm_hist_settings_reset"))
		mod:bump_buffs_data_revision()
		mod:reindex_buffs_catalog()
		mod.recreate_hud()
	end
	Imgui.same_line()
	Imgui.text(mod:localize(RESET_SETTINGS_DESC_LOC_ID))
end

function SettingsComponent:update()
	self:_update_reindex_catalog()
	self:_update_reset_settings()
	self:_update_dump_imgui_api()
end

return SettingsComponent
