-- Classification driven directly by the real BUFF_TEMPLATES naming convention observed
-- in-game (prefixes like "adamant_", "ogryn_", "weapon_trait_"), not heuristic guessing.

local Classifier = {}

Classifier.CATEGORY = table.enum("archetype", "weapon", "other")

Classifier.ARCHETYPE = table.enum("arbites", "hive_scum", "ogryn", "psyker", "skitarii", "veteran", "zealot")

Classifier.ARCHETYPE_ORDER = {
	Classifier.ARCHETYPE.arbites,
	Classifier.ARCHETYPE.hive_scum,
	Classifier.ARCHETYPE.ogryn,
	Classifier.ARCHETYPE.psyker,
	Classifier.ARCHETYPE.skitarii,
	Classifier.ARCHETYPE.veteran,
	Classifier.ARCHETYPE.zealot,
}

-- Prefix match, checked in this order, against the lower-cased buff name.
Classifier.ARCHETYPE_PREFIX = {
	[Classifier.ARCHETYPE.arbites] = "adamant",
	[Classifier.ARCHETYPE.hive_scum] = "broker",
	[Classifier.ARCHETYPE.ogryn] = "ogryn",
	[Classifier.ARCHETYPE.psyker] = "psyker",
	[Classifier.ARCHETYPE.skitarii] = "cryptic",
	[Classifier.ARCHETYPE.veteran] = "veteran",
	[Classifier.ARCHETYPE.zealot] = "zealot",
}

Classifier.ARCHETYPE_LOCALIZATION_KEY = {
	[Classifier.ARCHETYPE.arbites] = "gbm_archetype_arbites",
	[Classifier.ARCHETYPE.hive_scum] = "gbm_archetype_hive_scum",
	[Classifier.ARCHETYPE.ogryn] = "gbm_archetype_ogryn",
	[Classifier.ARCHETYPE.psyker] = "gbm_archetype_psyker",
	[Classifier.ARCHETYPE.skitarii] = "gbm_archetype_skitarii",
	[Classifier.ARCHETYPE.veteran] = "gbm_archetype_veteran",
	[Classifier.ARCHETYPE.zealot] = "gbm_archetype_zealot",
}

Classifier.CATEGORY_LOCALIZATION_KEY = {
	[Classifier.CATEGORY.archetype] = "gbm_category_archetypes",
	[Classifier.CATEGORY.weapon] = "gbm_category_weapons",
	[Classifier.CATEGORY.other] = "gbm_category_other",
}

Classifier.CATEGORY_ORDER = {
	Classifier.CATEGORY.archetype,
	Classifier.CATEGORY.weapon,
	Classifier.CATEGORY.other,
}

local function lower(s)
	return type(s) == "string" and s:lower() or ""
end

-- Returns category, archetype_or_nil
function Classifier.classify(name)
	local lname = lower(name)

	if lname:find("^weapon_trait") then
		return Classifier.CATEGORY.weapon, nil
	end

	for _, archetype in ipairs(Classifier.ARCHETYPE_ORDER) do
		local prefix = Classifier.ARCHETYPE_PREFIX[archetype]
		if lname:find("^" .. prefix) then
			return Classifier.CATEGORY.archetype, archetype
		end
	end

	if lname:find("preacher", 1, true) then
		return Classifier.CATEGORY.archetype, Classifier.ARCHETYPE.zealot
	end

	return Classifier.CATEGORY.other, nil
end

function Classifier.is_weapon(name)
	return lower(name):find("^weapon_trait") ~= nil
end

function Classifier.is_tdr(name)
	local lname = lower(name)
	return lname:find("tdr", 1, true) ~= nil or lname:find("reduced_toughness_damage", 1, true) ~= nil
end

function Classifier.is_live_event(name)
	return lower(name):find("live_event", 1, true) ~= nil
end

function Classifier.is_toughness(name)
	return lower(name):find("toughness", 1, true) ~= nil
end

function Classifier.is_crit(name)
	-- "crit" is a substring of "crits", so a single check covers both.
	return lower(name):find("crit", 1, true) ~= nil
end

function Classifier.is_coherency(name)
	return lower(name):find("coherency", 1, true) ~= nil
end

function Classifier.is_stim(name)
	return lower(name):find("stim", 1, true) ~= nil
end

function Classifier.is_cdr(name)
	local lname = lower(name)
	return lname:find("cooldown", 1, true) ~= nil or lname:find("cdr", 1, true) ~= nil
end

local PLAYER_DEBUFF_SUBSTRINGS = { "prop_in", "chaos_", "cm_habs_tree", "cultist", "beast_of" }

function Classifier.is_player_debuff(name)
	local lname = lower(name)
	for i = 1, #PLAYER_DEBUFF_SUBSTRINGS do
		if lname:find(PLAYER_DEBUFF_SUBSTRINGS[i], 1, true) then
			return true
		end
	end
	return false
end

return Classifier
