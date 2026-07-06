local mod = get_mod("gelatos_buff_manager")

local MAX_ENTRIES = 5
-- The ImGui font is ASCII-only, so the unicode warning glyph would render as garbage.
local WARNING_PREFIX = "!!! WARNING !!! "

-- Lives on the mod singleton: io_dofile may re-execute this file, and every UI component
-- must share ONE history. In-memory only: survives window reopen, clears on game exit.
local entries = mod._gbm_action_history
if entries == nil then
	entries = {}
	mod._gbm_action_history = entries
end

local M = {}

local function _timestamp()
	local ok, stamp = pcall(os.date, "%H:%M")
	if ok and type(stamp) == "string" then
		return stamp
	end
	return "--:--"
end

local function _push(line)
	entries[#entries + 1] = line
	if #entries > MAX_ENTRIES then
		table.remove(entries, 1)
	end
end

function M.log(message)
	_push(("[%s] %s"):format(_timestamp(), message))
end

function M.warn(message)
	_push(("[%s] %s%s"):format(_timestamp(), WARNING_PREFIX, message))
end

function M.entries()
	return entries
end

return M
