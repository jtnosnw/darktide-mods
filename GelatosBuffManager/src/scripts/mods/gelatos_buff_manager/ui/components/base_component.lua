local mod = get_mod("gelatos_buff_manager")

local ERROR_PREFIX = ("[%s][%s]"):format(mod:localize("mod_name"), "%s")
local UPDATE_NOT_IMPLEMENTED = ERROR_PREFIX .. " %s:update is not implemented"

local BaseComponent = class("BaseComponent")

function BaseComponent:init()
end

function BaseComponent:update()
	error(UPDATE_NOT_IMPLEMENTED:format(self.__class_name, self.__class_name))
end

return BaseComponent
