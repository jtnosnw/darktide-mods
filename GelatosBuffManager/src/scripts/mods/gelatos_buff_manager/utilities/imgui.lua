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

-- SHARED LIST RENDERER -- every list/pane in GBM must go through this, never a hand-rolled loop.
--
-- Emitting a widget per row for a few thousand buffs costs thousands of ImGui commands and image
-- draws every frame, whether or not the rows are on screen. This draws only the rows inside the
-- scroll viewport and replaces the rest with two spacer blocks of the correct height, so scroll
-- position and scrollbar length stay exactly as if every row had been drawn.
--
-- The ImGui binding shipped with Darktide is old and we cannot assume the scroll query functions
-- exist, so capability is probed once. When anything required is missing we fall back to drawing
-- every row -- correct, just as slow as before, never broken.

local VIRTUAL_OVERSCAN_ROWS = 4
local MIN_ROW_HEIGHT = 4

local _virtualization_supported = nil
local _virtualization_logged = false

local function _window_height()
	if Imgui.get_window_size then
		local _, height = Imgui.get_window_size()
		return height
	end
	if Imgui.get_window_height then
		return Imgui.get_window_height()
	end
	return nil
end

local function _can_virtualize()
	if _virtualization_supported == nil then
		_virtualization_supported = (Imgui.get_scroll_y ~= nil)
			and (Imgui.get_cursor_pos_y ~= nil)
			and (Imgui.dummy ~= nil)
			and (Imgui.get_window_size ~= nil or Imgui.get_window_height ~= nil)

		if not _virtualization_logged then
			_virtualization_logged = true
			if _virtualization_supported then
				mod:info("Gelato's Buff Manager: ImGui scroll queries available -- long lists are virtualized.")
			else
				mod:info(
					"Gelato's Buff Manager: ImGui scroll queries unavailable -- long lists draw every row (slower, but correct).")
			end
		end
	end

	return _virtualization_supported
end

-- draw_row(index) draws exactly one row. Rows must be uniform height (GBM's are: the buff icon is
-- always the tallest element, so a 1-line and a 3-line label produce the same advance).
--
-- row_height is a starting estimate only. The true height is measured from the rows actually drawn
-- and returned, so the caller can feed it back next frame and the layout self-corrects rather than
-- drifting on a stale constant.
function ImguiHelpers.draw_virtualized_rows(count, row_height, draw_row)
	if type(count) ~= "number" or count <= 0 or type(draw_row) ~= "function" then
		return row_height
	end

	if not _can_virtualize() then
		for i = 1, count do
			draw_row(i)
		end
		return row_height
	end

	if type(row_height) ~= "number" or row_height < MIN_ROW_HEIGHT then
		row_height = MIN_ROW_HEIGHT
	end

	local list_top = Imgui.get_cursor_pos_y()
	local scroll_y = Imgui.get_scroll_y() or 0
	local view_height = _window_height() or 0

	local first = math.floor((scroll_y - list_top) / row_height) + 1 - VIRTUAL_OVERSCAN_ROWS
	local last = math.ceil((scroll_y + view_height - list_top) / row_height) + VIRTUAL_OVERSCAN_ROWS

	-- Clamped so at least one row is ALWAYS drawn. row_height starts as an estimate, and the only
	-- way to correct it is to measure a real row -- if a bad estimate ever pushed the range off
	-- the end of the list we would draw nothing, measure nothing, and stay wrong forever with a
	-- blank list. Drawing one row costs nothing and guarantees the estimate converges.
	if first < 1 then
		first = 1
	elseif first > count then
		first = count
	end

	if last > count then
		last = count
	elseif last < first then
		last = first
	end

	if first > 1 then
		Imgui.dummy(1, (first - 1) * row_height)
	end

	local measure_top = Imgui.get_cursor_pos_y()

	for i = first, last do
		draw_row(i)
	end

	local drawn = last - first + 1
	local measured = (Imgui.get_cursor_pos_y() - measure_top) / drawn

	if last < count then
		Imgui.dummy(1, (count - last) * row_height)
	end

	if measured >= MIN_ROW_HEIGHT then
		return measured
	end

	return row_height
end

return ImguiHelpers
