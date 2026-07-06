local HudElementPlayerBuffsDefinitions = require(
	"scripts/ui/hud/elements/player_buffs/hud_element_player_buffs_definitions"
)
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local BAR_SIZE = { 80, 40 }
local BUFF_SIZE = { 38, 38 }

-- CONFIRMED from the real vanilla scenegraph: the default buff bar is bottom-anchored at
-- x=550, y=-50, size 1125x80.
local VANILLA_X = 550
local VANILLA_Y = -50
-- Step between the vanilla bar and the first custom bar (slot 1).
local VANILLA_STEP = 75
-- Bars render a single 38px icon row; step = icon height + minimal padding.
local BAR_STACK_STEP = 50

-- Builds a FRESH table per bar -- sharing one static table made bars snap to the same spot.
-- slot counts from the bottom: slot 1 sits just above the vanilla bar, higher slots stack upward.
local function build_scenegraph_definition(slot)
	local index = slot or 1
	local y = VANILLA_Y - VANILLA_STEP
	if index > 1 then
		y = y - (index - 1) * BAR_STACK_STEP
	end

	return {
		screen = UIWorkspaceSettings.screen,
		background = {
			horizontal_alignment = "left",
			parent = "screen",
			vertical_alignment = "bottom",
			size = { BAR_SIZE[1], BAR_SIZE[2] },
			position = { VANILLA_X, y, 1 },
		},
		buff = {
			horizontal_alignment = "left",
			parent = "background",
			vertical_alignment = "bottom",
			size = { BUFF_SIZE[1], BUFF_SIZE[2] },
			position = { 0, 0, 1 },
		},
	}
end

return {
	animations = HudElementPlayerBuffsDefinitions.animations,
	buff_widget_definition = HudElementPlayerBuffsDefinitions.buff_widget_definition,
	widget_definitions = HudElementPlayerBuffsDefinitions.widget_definitions,
	scenegraph_definition = build_scenegraph_definition(1),
	build_scenegraph_definition = build_scenegraph_definition,
	VANILLA_X = VANILLA_X,
	VANILLA_Y = VANILLA_Y,
}
