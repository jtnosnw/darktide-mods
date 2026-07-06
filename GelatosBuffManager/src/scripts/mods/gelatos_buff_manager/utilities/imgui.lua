local mod = get_mod("gelatos_buff_manager")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/string")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/table")

local ERROR_PREFIX = ("[%s][%s]"):format(mod:localize("mod_name"), "Imgui")
local ERRORS = {
	COMBO_ID_MUST_BE_STRING = ("%s combo_id must be a string"):format(ERROR_PREFIX),
	COMBO_ID_CANNOT_BE_WHITESPACE = ("%s combo_id cannot be whitespace"):format(ERROR_PREFIX),
	INPUT_ID_MUST_BE_STRING = ("%s input_id must be a string"):format(ERROR_PREFIX),
	INPUT_ID_CANNOT_BE_WHITESPACE = ("%s input_id cannot be whitespace"):format(ERROR_PREFIX),
}

-- UNCONDITIONAL overwrite, matching BBM's own utilities/imgui.lua exactly. An `or` guard here
-- would silently defer to a native Imgui.combo with a different arg shape if one exists,
-- which is exactly what produced the "NavTreeComponent_SELECT_BAR" literal-text bug.

-- combo_id, combo_label, combo_items(array<string>), selected_index(nil|number), add_empty_entry(bool, default true)
Imgui.combo = function(combo_id, combo_label, combo_items, selected_index, add_empty_entry)
	if type(combo_id) ~= "string" then
		error(ERRORS.COMBO_ID_MUST_BE_STRING, 2)
	elseif string.is_whitespace(combo_id) then
		error(ERRORS.COMBO_ID_CANNOT_BE_WHITESPACE, 2)
	end

	if add_empty_entry == nil then
		add_empty_entry = true
	end

	local selected_text = ""
	if combo_items and selected_index then
		selected_text = combo_items[selected_index]
	end

	Imgui.push_id(combo_id)
	if Imgui.begin_combo(combo_label or "", selected_text) then
		if not table.is_nil_or_empty(combo_items) then
			if add_empty_entry then
				local is_selected_index_nil = selected_index == nil
				if Imgui.selectable("", is_selected_index_nil) then
					selected_index = nil
				end
				if is_selected_index_nil then
					Imgui.set_item_default_focus()
				end
			end

			for index, text in ipairs(combo_items) do
				local is_item_selected = selected_index == index
				if Imgui.selectable(text, is_item_selected) then
					selected_index = index
				end
				if is_item_selected then
					Imgui.set_item_default_focus()
				end
			end
		end
		Imgui.end_combo()
	end
	Imgui.pop_id()

	return selected_index
end

Imgui.ided_input_text = function(...)
	local args = { ... }
	local input_id = args[1]

	if type(input_id) ~= "string" then
		error(ERRORS.INPUT_ID_MUST_BE_STRING, 2)
	elseif string.is_whitespace(input_id) then
		error(ERRORS.INPUT_ID_CANNOT_BE_WHITESPACE, 2)
	end

	local label = ""
	local value = ""
	if select("#", ...) == 2 then
		value = args[2]
	elseif select("#", ...) >= 3 then
		if args[2] ~= nil then
			label = args[2]
		end
		if args[3] ~= nil then
			value = args[3]
		end
	end

	Imgui.push_id(input_id)
	value = Imgui.input_text(label, value)
	Imgui.pop_id()

	return value
end

local warned_no_item_width = false

local ImguiHelpers = {}

-- Old-ImGui width control: push_item_width/pop_item_width (set_next_item_width postdates this binding).
function ImguiHelpers.push_width(width)
	if Imgui.push_item_width then
		Imgui.push_item_width(width)
		return true
	end
	if not warned_no_item_width then
		warned_no_item_width = true
		mod:info("Gelato's Buff Manager: Imgui.push_item_width unavailable -- widget widths fall back to defaults.")
	end
	return false
end

function ImguiHelpers.pop_width(pushed)
	if pushed and Imgui.pop_item_width then
		Imgui.pop_item_width()
	end
end

return ImguiHelpers
