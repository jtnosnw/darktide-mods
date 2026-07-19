local mod = get_mod("gelatos_buff_manager")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/table")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/ui/components/base_component")

local BaseBuffComponent = class("BaseBuffComponent", "BaseComponent")

function BaseBuffComponent:init(buffs_data)
	BaseBuffComponent.super.init(self)
	self._buffs_data = buffs_data
end

function BaseBuffComponent:update()
	BaseBuffComponent.super.update(self)
end

return BaseBuffComponent
