local mod = get_mod("gelatos_buff_manager")

-- Cached game-mode state, refreshed lazily and on game_state_changed.
local _is_in_hub_cache = nil

local function _refresh_is_in_hub()
	local gm = Managers.state and Managers.state.game_mode
	if not gm then
		_is_in_hub_cache = nil
		return
	end
	local game_mode_name = gm:game_mode_name()
	if game_mode_name then
		_is_in_hub_cache = string.find(game_mode_name, "hub") ~= nil
	else
		_is_in_hub_cache = nil
	end
end

local _prior_on_game_state_changed = mod.on_game_state_changed

mod.on_game_state_changed = function(status, state_name)
	if status == "enter" or status == "exit" then
		_is_in_hub_cache = nil
	end
	if _prior_on_game_state_changed then
		_prior_on_game_state_changed(status, state_name)
	end
end

function mod:is_in_hub()
	if _is_in_hub_cache == nil then
		_refresh_is_in_hub()
	end
	return _is_in_hub_cache == true
end
