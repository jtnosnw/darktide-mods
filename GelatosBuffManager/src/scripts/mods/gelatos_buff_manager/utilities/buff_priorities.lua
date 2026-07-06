local mod = get_mod("gelatos_buff_manager")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/table")

local PRIORITY_SETTING_ID = "gbm_buff_priorities"

local PRIORITY_LOW = 0
local PRIORITY_DEFAULT = 1
local PRIORITY_HIGH = 2

-- Shared live state lives on the mod singleton: io_dofile may re-execute this file, and
-- every consumer (UI components, every HUD bar instance) must read/write ONE table.
local priorities = mod._buff_priorities

if priorities == nil then
	priorities = {}
	mod._buff_priorities = priorities

	local saved = mod:get(PRIORITY_SETTING_ID)
	if type(saved) == "table" then
		local invalid_count = 0
		for name, value in pairs(saved) do
			if type(name) == "string" and name ~= "" and (value == PRIORITY_LOW or value == PRIORITY_HIGH) then
				priorities[name] = value
			elseif value ~= PRIORITY_DEFAULT then
				invalid_count = invalid_count + 1
			end
		end
		if invalid_count > 0 then
			mod:info(("Gelato's Buff Manager: %d invalid saved buff priority entries coerced to default (1)."):format(
				invalid_count))
		end
	elseif saved ~= nil then
		mod:info("Gelato's Buff Manager: saved buff priorities were not a table; reset to defaults.")
		mod:set(PRIORITY_SETTING_ID, nil)
	end
end

-- Persist a copy, never the live table, so DMF can't hold a reference to mutable state.
-- Sparse: only non-default entries are written; an empty table removes the key entirely.
local function _persist()
	if next(priorities) == nil then
		mod:set(PRIORITY_SETTING_ID, nil)
		return
	end
	local save_data = {}
	for name, value in pairs(priorities) do
		save_data[name] = value
	end
	mod:set(PRIORITY_SETTING_ID, save_data)
end

local function _coerce(value, name)
	if value ~= PRIORITY_LOW and value ~= PRIORITY_DEFAULT and value ~= PRIORITY_HIGH then
		mod:info(("Gelato's Buff Manager: invalid priority '%s' for buff '%s' coerced to default (1)."):format(
			tostring(value), tostring(name)))
		return PRIORITY_DEFAULT
	end
	return value
end

local M = {
	LOW = PRIORITY_LOW,
	DEFAULT = PRIORITY_DEFAULT,
	HIGH = PRIORITY_HIGH,
	SETTING_ID = PRIORITY_SETTING_ID,
}

-- Stable reference for zero-allocation per-poll reads (mutated in place, never replaced).
function M.raw()
	return priorities
end

function M.get(name)
	local value = priorities[name]
	if value == nil then
		return PRIORITY_DEFAULT
	end
	return value
end

function M.set(name, value)
	if type(name) ~= "string" or name == "" then
		mod:info("Gelato's Buff Manager: ignored priority write for an invalid buff name.")
		return false
	end

	value = _coerce(value, name)

	local old_value = M.get(name)
	if old_value == value then
		return false
	end

	priorities[name] = value ~= PRIORITY_DEFAULT and value or nil
	_persist()
	mod:info(("Gelato's Buff Manager: buff priority '%s' changed %d -> %d."):format(name, old_value, value))
	return true
end

-- names_set is set-shaped ({ [buff_name] = true }); one persist + one log line for the batch.
function M.set_many(names_set, value)
	if type(names_set) ~= "table" then
		return 0
	end

	value = _coerce(value, "selection")

	local changed_count = 0
	for name in pairs(names_set) do
		if type(name) == "string" and name ~= "" and M.get(name) ~= value then
			priorities[name] = value ~= PRIORITY_DEFAULT and value or nil
			changed_count = changed_count + 1
		end
	end

	if changed_count > 0 then
		_persist()
		mod:info(("Gelato's Buff Manager: set buff priority %d on %d buff(s)."):format(value, changed_count))
	end

	return changed_count
end

-- Clears IN PLACE so cached references (HUD comparators) stay valid.
function M.reset_all()
	local cleared_count = 0
	for _ in pairs(priorities) do
		cleared_count = cleared_count + 1
	end

	if cleared_count > 0 then
		table.clear(priorities)
		_persist()
	end

	mod:info(("Gelato's Buff Manager: reset ALL buff priorities to default (%d entries cleared)."):format(
		cleared_count))
	return cleared_count
end

return M
