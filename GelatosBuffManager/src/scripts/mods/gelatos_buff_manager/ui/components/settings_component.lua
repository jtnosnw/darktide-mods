local mod = get_mod("gelatos_buff_manager")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/table")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/imgui")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/ui/components/base_component")
local BuffPriorities = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/buff_priorities")
local ActionHistory = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/action_history")

local CLASS_NAME = "SettingsComponent"

local TOGGLE_DEFAULT_BAR_SETTING_ID = "default_buff_bar_enabled"
-- Static labels resolved once at load, not re-localized every frame.
local L = {
	RESET_SETTINGS = mod:localize("gbm_reset_settings"),
	RESET_SETTINGS_DESC = mod:localize("gbm_reset_settings_description"),
	REINDEX_CATALOG = mod:localize("gbm_reindex_catalog"),
	REINDEX_CATALOG_DESC = mod:localize("gbm_reindex_catalog_description"),
	DUMP_IMGUI_API = mod:localize("gbm_dump_imgui_api"),
	DUMP_IMGUI_API_DESC = mod:localize("gbm_dump_imgui_api_description"),
	HIST_REINDEXED = mod:localize("gbm_hist_reindexed"),
	HIST_IMGUI_DUMPED = mod:localize("gbm_hist_imgui_dumped"),
	HIST_SETTINGS_RESET = mod:localize("gbm_hist_settings_reset"),
}

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
	if Imgui.button(L.REINDEX_CATALOG) then
		ActionHistory.log(L.HIST_REINDEXED)
		mod:reindex_buffs_catalog()
	end
	Imgui.same_line()
	Imgui.text(L.REINDEX_CATALOG_DESC)
end

function SettingsComponent:_update_dump_imgui_api()
	if Imgui.button(L.DUMP_IMGUI_API) then
		ActionHistory.log(L.HIST_IMGUI_DUMPED)
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
	Imgui.text(L.DUMP_IMGUI_API_DESC)
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
	if Imgui.button(L.RESET_SETTINGS) then
		_reset_widgets_recursive(self._settings_widgets)
		mod:set("bars", {})
		mod:set("buffs_data", {})
		mod:set("bar_active_states", {})
		mod:set("gbm_bar_slots", nil)
		BuffPriorities.reset_all()
		ActionHistory.log(L.HIST_SETTINGS_RESET)
		mod:bump_buffs_data_revision()
		mod:reindex_buffs_catalog()
		mod.recreate_hud()
	end
	Imgui.same_line()
	Imgui.text(L.RESET_SETTINGS_DESC)
end

function SettingsComponent:update()
	self:_update_reindex_catalog()
	self:_update_reset_settings()
	self:_update_dump_imgui_api()
end

return SettingsComponent
