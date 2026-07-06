local mod = get_mod("gelatos_buff_manager")

local VERSION = mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/gelatos_buff_manager_version")
local AUTHOR_NAME = "Gelato" -- change this to whatever name/handle you want shown in the mod menu

-- Confirmed working inline color markup (found in Markers Improved's own source, which uses
-- the exact same "{#color(r,g,b)}text{#reset()}" pattern for its Gold/Silver/Steel labels).
-- Per-character interpolation gives a purple -> blue gradient across the title text.
local function gradient_text(text, r1, g1, b1, r2, g2, b2)
	local length = #text
	if length == 0 then
		return text
	end
	if length == 1 then
		return ("{#color(%d,%d,%d)}%s{#reset()}"):format(r1, g1, b1, text)
	end

	local parts = {}
	for i = 1, length do
		local t = (i - 1) / (length - 1)
		local r = math.floor(r1 + (r2 - r1) * t + 0.5)
		local g = math.floor(g1 + (g2 - g1) * t + 0.5)
		local b = math.floor(b1 + (b2 - b1) * t + 0.5)
		parts[i] = ("{#color(%d,%d,%d)}%s{#reset()}"):format(r, g, b, text:sub(i, i))
	end
	return table.concat(parts)
end

-- No version suffix here per request -- this is the Mod Options title/list entry only; the
-- in-game floating window title (window.lua) still shows version separately.
local TITLE_GRADIENT = gradient_text(mod:localize("mod_name"), 168, 60, 230, 56, 189, 248)

-- No native DMF Author/Version field exists; gold labels use Fatshark {#color()} text markup.
local LABEL_GOLD = "{#color(255,195,45)}"
local DESCRIPTION = ("%s\n" .. LABEL_GOLD .. "Author:{#reset()} %s\n" .. LABEL_GOLD .. "Version:{#reset()} %s"):format(
	mod:localize("mod_description"), AUTHOR_NAME, VERSION)

return {
	name = TITLE_GRADIENT,
	description = DESCRIPTION,
	author = AUTHOR_NAME,
	version = VERSION,
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "header_general",
				type = "group",
				sub_widgets = {
					{
						setting_id = "configure_buffs",
						type = "keybind",
						default_value = {},
						keybind_global = false,
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "configure_buffs",
					},
					{
						setting_id = "default_buff_bar_enabled",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "group_buffs_in_categories",
						type = "checkbox",
						default_value = true,
					},
				},
			},
		},
	},
}
