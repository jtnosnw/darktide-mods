return {
	mod_name = {
		en = "Gelato's Buff Manager",
	},
	mod_description = {
		en = "Build custom buff/debuff bars using keyword filtering, search strings, and more.",
	},
	header_general = {
		en = "General Options",
	},
	configure_buffs = {
		en = "Open Gelato's Buff Manager",
	},
	default_buff_bar_enabled = {
		en = "Show Default Buff Bar",
	},
	default_buff_bar_enabled_description = {
		en = "Show the game's default buff bar alongside your custom bars.",
	},
	group_buffs_in_categories = {
		en = "Group Buffs By Category",
	},
	group_buffs_in_categories_description = {
		en = "Group icons on your custom bars the same way the vanilla bar does, with a small gap between categories.",
	},
	gbm_nav_help = {
		en = "--- Instructions ---\n" .. 
			"1. Create a custom buff bar first, use keyword filters and search string to find buffs.\n" ..
			"2. Tick the buffs/debuffs you want, ensure a bar is selected before adding/removing selected.\n" ..
			"3. Use the Action History panel at the bottom to see the last 5 actions you performed inc. warnings.\n" ..
			"4. To apply default priority on selected buffs, use \"Set selected to default\" button instead of dropdown.\n" ..
			"Note: Window off-screen? Close and reopen with the keybind to reset its position.",
	},
	gbm_search_placeholder = {
		en = "Search",
	},
	gbm_clear_search = {
		en = "Clear",
	},
	gbm_select_all = {
		en = "Select All",
	},
	gbm_deselect_all = {
		en = "Deselect All",
	},
	gbm_selection_counter_text = {
		en = "Total selected:",
	},
	gbm_create_bar = {
		en = "Create buff bar",
	},
	gbm_select_bar = {
		en = "Selected Buff Bar",
	},
	gbm_clear_bar = {
		en = "Clear",
	},
	gbm_delete_bar = {
		en = "Delete",
	},
	gbm_add_selected = {
		en = "Add %d selected buffs from nav-tree to bar",
	},
	gbm_remove_selected = {
		en = "Remove %d selected from bar",
	},
	gbm_no_bar_selected_error = {
		en = "Select a buff bar above first.",
	},
	gbm_toggle_default_bar = {
		en = "Show default buff bar",
	},
	gbm_header_action_history = {
		en = "ACTION HISTORY",
	},
	gbm_hist_select_all = {
		en = "Clicked \"Select All\" for %d buff(s).",
	},
	gbm_hist_deselect_all = {
		en = "Clicked \"Deselect All\" for %d buff(s).",
	},
	gbm_hist_search_cleared = {
		en = "Cleared the buff search.",
	},
	gbm_hist_hide_added_on = {
		en = "\"Hide buffs already in selected bar\" enabled.",
	},
	gbm_hist_hide_added_off = {
		en = "\"Hide buffs already in selected bar\" disabled.",
	},
	gbm_hist_bar_created = {
		en = "Created bar: [%s].",
	},
	gbm_hist_warn_create_empty = {
		en = "Clicked \"Create buff bar\", but the name is empty. Nothing created.",
	},
	gbm_hist_warn_create_duplicate = {
		en = "Clicked \"Create buff bar\", but [%s] already exists. Nothing created.",
	},
	gbm_hist_warn_bar_soft_limit = {
		en = "You now have %d of a maximum %d bars. Each extra bar makes every add/remove slower and stacks higher up the screen.",
	},
	gbm_hist_warn_bar_limit_reached = {
		en = "Bar limit of %d reached. Delete a bar before creating another one.",
	},
	gbm_hist_added_to_bar = {
		en = "Added %d selected buff(s) to bar: [%s].",
	},
	gbm_hist_warn_add_no_bar = {
		en = "Clicked \"Add selected buffs\", but no bar selected. Nothing added.",
	},
	gbm_hist_warn_add_none = {
		en = "Clicked \"Add selected buffs\", but 0 buffs selected. Nothing added.",
	},
	gbm_hist_removed_from_bar = {
		en = "Removed %d selected buff(s) from bar: [%s].",
	},
	gbm_hist_warn_remove_no_bar = {
		en = "Clicked \"Remove selected\", but no bar selected. Nothing removed.",
	},
	gbm_hist_warn_remove_none = {
		en = "Clicked \"Remove selected\", but 0 buffs selected. Nothing removed.",
	},
	gbm_hist_buff_removed = {
		en = "Removed \"%s\" from bar: [%s].",
	},
	gbm_hist_bar_cleared = {
		en = "\"Clear\" pressed for [%s]. Removed %d buff(s).",
	},
	gbm_hist_warn_bar_clear_empty = {
		en = "Clicked \"Clear\" for [%s], but the bar was empty. Nothing cleared.",
	},
	gbm_hist_bar_deleted = {
		en = "Deleted bar: [%s].",
	},
	gbm_hist_bar_activated = {
		en = "Bar [%s] activated.",
	},
	gbm_hist_bar_deactivated = {
		en = "Bar [%s] deactivated.",
	},
	gbm_hist_default_bar_on = {
		en = "\"Show default buff bar\" enabled.",
	},
	gbm_hist_default_bar_off = {
		en = "\"Show default buff bar\" disabled.",
	},
	gbm_hist_prio_set = {
		en = "Set \"%s\" priority to %d.",
	},
	gbm_hist_prio_selected = {
		en = "Set %d selected buff(s) to priority %d.",
	},
	gbm_hist_warn_prio_none = {
		en = "Priority change clicked, but no buffs ticked. Nothing set.",
	},
	gbm_hist_prio_reset_all = {
		en = "Reset ALL buff priorities (%d cleared).",
	},
	gbm_hist_reindexed = {
		en = "Reindexed the buff catalog.",
	},
	gbm_hist_settings_reset = {
		en = "All settings reset to default.",
	},
	gbm_hist_imgui_dumped = {
		en = "Dumped Imgui API to the console log.",
	},
	gbm_reindex_catalog = {
		en = "Reindex buff catalog",
	},
	gbm_reindex_catalog_description = {
		en = "Rescan all buff templates -- run this after a game update if new buffs are missing.",
	},
	gbm_dump_imgui_api = {
		en = "Dump Imgui API",
	},
	gbm_dump_imgui_api_description = {
		en = "Debug: outputs to the DMF console log file (%%appdata%%\\Fatshark\\Darktide\\console_logs).",
	},
	gbm_reset_settings = {
		en = "Reset all settings",
	},
	gbm_reset_settings_description = {
		en = "Deletes all your custom bars and buff priorities, and resets every setting above to default.",
	},
	gbm_header_buff_priority = {
		en = "SET BUFF PRIORITY",
	},
	gbm_priority_help = {
		en = "2 = High, 1 = Default, 0 = Low.\nHigh buffs claim bar slots first,\nLow buffs give theirs up first.\nOnly affects your custom bars.",
	},
	gbm_priority_set_selected_label = {
		en = "Set selected to:",
	},
	gbm_priority_set_selected_default = {
		en = "Set selected to default",
	},
	gbm_priority_reset_all = {
		en = "Reset ALL to default",
	},
	gbm_priority_applied = {
		en = "Set %d buff(s) to priority %d.",
	},
	gbm_priority_reset_all_done = {
		en = "Priorities reset (%d cleared).",
	},
	gbm_priority_no_selection_error = {
		en = "Tick buffs in the nav-tree first.",
	},
	gbm_prio_label = {
		en = "Prio",
	},
	gbm_move_bar_up = {
		en = "^",
	},
	gbm_move_bar_down = {
		en = "v",
	},
	gbm_prio_value_0 = {
		en = "Prio: 0 (low)",
	},
	gbm_prio_value_1 = {
		en = "Prio: 1 (default)",
	},
	gbm_prio_value_2 = {
		en = "Prio: 2 (high)",
	},
	gbm_remove_from_bar = {
		en = "Remove",
	},
	gbm_no_bars = {
		en = "No buff bars yet -- create one first!",
	},
	gbm_category_archetypes = {
		en = "Archetypes",
	},
	gbm_category_weapons = {
		en = "Weapons",
	},
	gbm_category_other = {
		en = "Other",
	},
	gbm_archetype_arbites = {
		en = "Arbites",
	},
	gbm_archetype_hive_scum = {
		en = "Hive Scum",
	},
	gbm_archetype_ogryn = {
		en = "Ogryn",
	},
	gbm_archetype_psyker = {
		en = "Psyker",
	},
	gbm_archetype_skitarii = {
		en = "Skitarii",
	},
	gbm_archetype_veteran = {
		en = "Veteran",
	},
	gbm_archetype_zealot = {
		en = "Zealot",
	},
	gbm_filter_weapon = {
		en = "Weapon",
	},
	gbm_filter_tdr = {
		en = "TDR",
	},
	gbm_filter_toughness = {
		en = "Toughness",
	},
	gbm_filter_crit = {
		en = "Crit",
	},
	gbm_filter_coherency = {
		en = "Coherency",
	},
	gbm_filter_player_debuffs = {
		en = "Player Debuffs",
	},
	gbm_filter_stim = {
		en = "Stims",
	},
	gbm_filter_cdr = {
		en = "CDR",
	},
	gbm_filter_live_events = {
		en = "Live Events",
	},
	gbm_hide_added = {
		en = "Hide buffs already in selected bar",
	},
	gbm_nav_width_label = {
		en = "Panel width",
	},
	gbm_bar_over_limit = {
		en = "20+",
	},
	gbm_bar_over_limit_description = {
		en = "More than 20 buffs assigned. This is informational, not a problem",
	},
	gbm_bar_active = {
		en = "Active",
	},
	gbm_header_buff_filters = {
		en = "BUFF FILTERS",
	},
	gbm_header_buff_nav_tree = {
		en = "BUFF NAV-TREE",
	},
	gbm_header_buff_bars = {
		en = "BUFF BARS",
	},
	gbm_bar_slot_info = {
		en = "Each bar shows up to 15 buffs + 5 debuffs at once: highest priority first, then oldest-active - extras wait their turn until a slot frees up.",
	},
}
