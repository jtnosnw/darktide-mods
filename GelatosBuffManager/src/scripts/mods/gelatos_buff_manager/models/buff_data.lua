local mod = get_mod("gelatos_buff_manager")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/string")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/table")

local CLASS_NAME = "BuffData"
local ERROR_PREFIX = ("[%s][%s]"):format(mod:localize("mod_name"), CLASS_NAME)

local function validate_params(params)
	if type(params) ~= "table" then
		error(ERROR_PREFIX .. " constructor requires parameters passed via a table", 1)
	end
	if string.is_nil_or_whitespace(params.name) then
		error(ERROR_PREFIX .. " parameters.name is missing", 1)
	end
end

local BuffData = class(CLASS_NAME)

function BuffData:init(params)
	validate_params(params)

	self.name = params.name
	self.icon = params.icon
	self.category = params.category
	self.archetype = params.archetype
	self.is_hidden = params.is_hidden or false
	self.bar_name = params.bar_name or ""
end

-- Mirrors BBM's save shape exactly: icon/category are re-resolved from the
-- catalog on load, not duplicated into every saved assignment.
function BuffData:save_data()
	return {
		name = self.name,
		is_hidden = self.is_hidden,
		bar_name = self.bar_name,
	}
end

function BuffData:toggle_hidden()
	self.is_hidden = not self.is_hidden
end

return BuffData
