local mod = get_mod("gelatos_buff_manager")
local Imgui_helpers = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/imgui")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/ui/components/base_component")
local BuffPriorities = mod:io_dofile(
	"gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/buff_priorities")
local ActionHistory = mod:io_dofile(
	"gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/action_history")

local CLASS_NAME = "PriorityComponent"

local PRIORITY_HELP_LOC_ID = "gbm_priority_help"
local SET_SELECTED_LABEL_LOC_ID = "gbm_priority_set_selected_label"
local SET_SELECTED_DEFAULT_LOC_ID = "gbm_priority_set_selected_default"
local RESET_ALL_LOC_ID = "gbm_priority_reset_all"
local APPLIED_LOC_ID = "gbm_priority_applied"
local RESET_ALL_DONE_LOC_ID = "gbm_priority_reset_all_done"
local NO_SELECTION_ERROR_LOC_ID = "gbm_priority_no_selection_error"

local PRIORITY_COMBO_ITEMS = { "0", "1 (default)", "2" }
local DEFAULT_COMBO_INDEX = BuffPriorities.DEFAULT + 1
local COMBO_WIDTH = 110

local PriorityComponent = class(CLASS_NAME, "BaseComponent")

function PriorityComponent:init(nav_tree_component)
	PriorityComponent.super.init(self)

	self._nav_tree_component = nav_tree_component
	self._combo_index = DEFAULT_COMBO_INDEX
	self._action_status = nil
end

function PriorityComponent:_apply_to_selected(priority_value)
	local nav_tree = self._nav_tree_component
	local selected_names = nav_tree and nav_tree:get_selected_names()
	local selected_count = nav_tree and nav_tree:get_selected_count() or 0

	if selected_count == 0 or not selected_names then
		self._action_status = mod:localize(NO_SELECTION_ERROR_LOC_ID)
		ActionHistory.warn(mod:localize("gbm_hist_warn_prio_none"))
		return
	end

	BuffPriorities.set_many(selected_names, priority_value)
	self._action_status = mod:localize(APPLIED_LOC_ID, selected_count, priority_value)
	ActionHistory.log(mod:localize("gbm_hist_prio_selected", selected_count, priority_value))
end

function PriorityComponent:update()
	Imgui.text(mod:localize(PRIORITY_HELP_LOC_ID))
	Imgui.separator()

	Imgui.text(mod:localize(SET_SELECTED_LABEL_LOC_ID))
	Imgui.same_line()

	local width_pushed = Imgui_helpers.push_width(COMBO_WIDTH)
	local new_index = Imgui.combo(self.__class_name .. "_SET_PRIORITY", "", PRIORITY_COMBO_ITEMS,
		self._combo_index, false)
	Imgui_helpers.pop_width(width_pushed)

	if new_index and new_index ~= self._combo_index then
		self:_apply_to_selected(new_index - 1)
		-- Snap back so the baseline is always "1 (default)" and re-applying the same
		-- value to a fresh selection still registers as a change.
		self._combo_index = DEFAULT_COMBO_INDEX
	end

	if Imgui.button(mod:localize(SET_SELECTED_DEFAULT_LOC_ID)) then
		self:_apply_to_selected(BuffPriorities.DEFAULT)
	end

	if Imgui.button(mod:localize(RESET_ALL_LOC_ID)) then
		local cleared_count = BuffPriorities.reset_all()
		self._action_status = mod:localize(RESET_ALL_DONE_LOC_ID, cleared_count)
		ActionHistory.log(mod:localize("gbm_hist_prio_reset_all", cleared_count))
	end

	-- Always reserve this line so the layout doesn't jump when a status appears.
	Imgui.text(self._action_status or "")
end

return PriorityComponent
