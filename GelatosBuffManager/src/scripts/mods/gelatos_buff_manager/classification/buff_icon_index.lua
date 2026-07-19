local mod = get_mod("gelatos_buff_manager")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/string")
mod:io_dofile("gelatos_buff_manager/scripts/mods/gelatos_buff_manager/utilities/table")

-- Reverse indices for icon resolution.
--
-- The previous resolver called table.find_by_key(BUFF_TEMPLATES, ...) once per candidate name
-- per template -- a full linear scan of every template, up to 4x, for every template. That is
-- O(templates^2), and with several thousand templates it is what caused the 1-2 second stall on
-- first opening the window. It then did the same thing against every cached master item.
--
-- Everything those scans looked for is derivable from a single pass, so we build three maps once
-- and every lookup afterwards is O(1). Resolution ORDER and PREFERENCE are preserved exactly:
--   1. hide_icon_in_hud  -> no icon
--   2. own hud_icon
--   3. a parent template whose child_buff_template matches one of our candidate names
--   4. our own child_buff_template's hud_icon
--   5. a master item carrying a matching trait name (item.icon preferred over item.hud_icon)
--
-- Two deliberate improvements over the old scans, both strictly for the better:
--   - The old code took whatever `pairs` happened to hand it first, so a buff's icon could
--     differ between sessions. Ties are now broken by lowest key name, making the catalog
--     deterministic.
--   - The old parent scan could latch onto a parent that had no hud_icon and give up, even
--     when an icon-bearing parent existed. We only ever index parents that actually have an
--     icon, so those buffs now resolve instead of silently vanishing from the catalog.

local M = {}

-- Keys in BUFF_TEMPLATES that are not buff templates.
local NON_TEMPLATE_KEYS = {
	PREDICTED = true,
	NON_PREDICTED = true,
}

M.NON_TEMPLATE_KEYS = NON_TEMPLATE_KEYS

local _parent_hud_icon_by_child = {}
local _template_by_name = {}
local _icon_by_trait_name = {}
local _built = false

local function _is_template(key, template)
	return not NON_TEMPLATE_KEYS[key] and type(template) == "table" and type(template.name) == "string"
		and template.name ~= ""
end

-- Deterministic tie-break: lowest key name wins when several sources offer an icon.
local function _claim(map, key, owner_key, icon)
	if key == nil or key == "" or icon == nil or icon == "" then
		return
	end

	local existing = map[key]
	if existing == nil or owner_key < existing.owner then
		map[key] = { owner = owner_key, icon = icon }
	end
end

local function _item_icon(item)
	if type(item.icon) == "string" and item.icon ~= "" then
		return item.icon
	end
	if type(item.hud_icon) == "string" and item.hud_icon ~= "" then
		return item.hud_icon
	end
	return nil
end

-- Every trait name shape the old _item_has_trait_name() accepted.
local function _index_item_traits(item, item_key, icon)
	_claim(_icon_by_trait_name, item.trait, item_key, icon)
	_claim(_icon_by_trait_name, item.trait_name, item_key, icon)

	if type(item.traits) ~= "table" then
		return
	end

	for _, trait in pairs(item.traits) do
		if type(trait) == "string" then
			_claim(_icon_by_trait_name, trait, item_key, icon)
		elseif type(trait) == "table" then
			_claim(_icon_by_trait_name, trait.name, item_key, icon)
			_claim(_icon_by_trait_name, trait.id, item_key, icon)
			_claim(_icon_by_trait_name, trait.trait, item_key, icon)
			_claim(_icon_by_trait_name, trait.trait_name, item_key, icon)
		end
	end
end

-- Rebuilt (not just built once at load) so a mid-session re-index picks up a patched game.
function M.build(buff_templates, cached_items)
	table.clear(_parent_hud_icon_by_child)
	table.clear(_template_by_name)
	table.clear(_icon_by_trait_name)

	local template_count = 0

	if type(buff_templates) == "table" then
		for key, template in pairs(buff_templates) do
			if _is_template(key, template) then
				template_count = template_count + 1
				_template_by_name[template.name] = template

				local child_name = template.child_buff_template
				if type(child_name) == "string" and child_name ~= "" then
					_claim(_parent_hud_icon_by_child, child_name, template.name, template.hud_icon)
				end
			end
		end
	end

	local item_count = 0

	if type(cached_items) == "table" then
		for item_key, item in pairs(cached_items) do
			if type(item) == "table" and type(item_key) == "string" then
				local icon = _item_icon(item)
				if icon then
					item_count = item_count + 1
					_index_item_traits(item, item_key, icon)
				end
			end
		end
	end

	_built = true

	mod:info(("Gelato's Buff Manager: icon index built from %d buff template(s) and %d icon-bearing item(s)."):format(
		template_count, item_count))
end

function M.is_built()
	return _built
end

-- Candidate names, in the same order the old resolver tried them. Written into a caller-owned
-- scratch array so the per-template hot loop allocates nothing.
function M.fill_name_candidates(out, buff_name)
	table.clear(out)

	if type(buff_name) ~= "string" or buff_name == "" then
		return out
	end

	out[1] = buff_name

	local count = 1
	local suffixes = { "_parent$", "_child$", "_proc$" }

	for i = 1, #suffixes do
		local stripped = buff_name:gsub(suffixes[i], "")
		if stripped ~= "" then
			local is_duplicate = false
			for j = 1, count do
				if out[j] == stripped then
					is_duplicate = true
					break
				end
			end
			if not is_duplicate then
				count = count + 1
				out[count] = stripped
			end
		end
	end

	return out
end

function M.get_icon(buff_template, candidates_scratch)
	if type(buff_template) ~= "table" or buff_template.hide_icon_in_hud then
		return nil
	end

	if type(buff_template.hud_icon) == "string" and buff_template.hud_icon ~= "" then
		return buff_template.hud_icon
	end

	local candidates = M.fill_name_candidates(candidates_scratch or {}, buff_template.name)

	for i = 1, #candidates do
		local entry = _parent_hud_icon_by_child[candidates[i]]
		if entry then
			return entry.icon
		end
	end

	local child_name = buff_template.child_buff_template
	if type(child_name) == "string" and child_name ~= "" then
		local child_template = _template_by_name[child_name]
		if child_template and type(child_template.hud_icon) == "string" and child_template.hud_icon ~= "" then
			return child_template.hud_icon
		end
	end

	for i = 1, #candidates do
		local entry = _icon_by_trait_name[candidates[i]]
		if entry then
			return entry.icon
		end
	end

	return nil
end

return M
