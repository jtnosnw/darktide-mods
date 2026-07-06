local mod = get_mod("gelatos_buff_manager")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/table")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/ui/components/base_component")

local BaseBuffComponent = class("BaseBuffComponent", "BaseComponent")

function BaseBuffComponent:init(buffs_data)
	BaseBuffComponent.super.init(self)
	self._buffs_data = buffs_data
end

function BaseBuffComponent:_get_buffs_for_bar(bar_name, buffs_data)
	buffs_data = buffs_data or self._buffs_data
	if table.is_nil_or_empty(buffs_data) then
		return nil
	end
	return table.filter(buffs_data, function(data)
		return data.bar_name == bar_name
	end)
end

function BaseBuffComponent:update()
	BaseBuffComponent.super.update(self)
end

return BaseBuffComponent
