extends Node

## KillMatrix Lookup Table
## Maps Attacker and Victim pieces across High Fantasy, Cyberpunk, and Eldritch themes
## to unique capture and duel execution animations.

const THEME_HIGH_FANTASY = "high_fantasy"
const THEME_CYBERPUNK = "cyberpunk"
const THEME_ELDRITCH = "eldritch"

# Structure: matrix[theme][attacker_type][victim_type] -> Dictionary
var _matrix: Dictionary = {}

func _init() -> void:
	_build_kill_matrix()

func _build_kill_matrix() -> void:
	_matrix = {
		THEME_HIGH_FANTASY: _build_high_fantasy_matrix(),
		THEME_CYBERPUNK: _build_cyberpunk_matrix(),
		THEME_ELDRITCH: _build_eldritch_matrix(),
	}

func get_duel_animation(theme: String, attacker: String, victim: String) -> Dictionary:
	var current_theme = theme.to_lower()
	if not _matrix.has(current_theme):
		current_theme = THEME_HIGH_FANTASY

	var theme_table = _matrix[current_theme]
	var atk = attacker.to_upper()
	var vic = victim.to_upper()

	var raw_data: Dictionary
	if theme_table.has(atk) and theme_table[atk].has(vic):
		raw_data = theme_table[atk][vic]
	else:
		raw_data = _get_thematic_fallback(current_theme, atk, vic)

	return _enrich_with_3act_data(current_theme, atk, vic, raw_data)

func _enrich_with_3act_data(theme: String, atk: String, vic: String, data: Dictionary) -> Dictionary:
	var result = data.duplicate()
	var atk_name = _piece_name(atk)
	var vic_name = _piece_name(vic)

	result["duration"] = 8.0
	result["act1_duration"] = 2.5
	result["act2_duration"] = 2.5
	result["act3_duration"] = 2.5
	result["camera_angle"] = "capture_zoom"

	if not result.has("victim_collapse"):
		match atk:
			"N", "K": result["victim_collapse"] = "decapitate"
			"B", "Q": result["victim_collapse"] = "disintegrate"
			_: result["victim_collapse"] = "collapse"

	match theme:
		THEME_CYBERPUNK:
			if not result.has("act1_name"):
				result["act1_name"] = "Plasma Salvo"
			if not result.has("act1_desc"):
				result["act1_desc"] = "The %s unloads a heavy plasma burst, deflected by the %s's kinetic barrier!" % [atk_name, vic_name]
			if not result.has("act2_name"):
				result["act2_name"] = "EMP Counter-Surge"
			if not result.has("act2_desc"):
				result["act2_desc"] = "The %s retaliates with an overcharged shockwave, but the %s sidesteps the arc!" % [vic_name, atk_name]
			if not result.has("act3_name"):
				result["act3_name"] = "Thermal Core Execution"
			if not result.has("act3_desc"):
				result["act3_desc"] = "The %s overcharges its core, obliterating the %s in a blinding flash of energy!" % [atk_name, vic_name]
		THEME_ELDRITCH:
			if not result.has("act1_name"):
				result["act1_name"] = "Void Tendril Lash"
			if not result.has("act1_desc"):
				result["act1_desc"] = "The %s lashes shadowy abyssal tendrils, repelled by the %s's defensive barrier!" % [atk_name, vic_name]
			if not result.has("act2_name"):
				result["act2_name"] = "Psychic Backlash"
			if not result.has("act2_desc"):
				result["act2_desc"] = "The %s unleashes a psychic curse scream, deflected by the %s's dark aura!" % [vic_name, atk_name]
			if not result.has("act3_name"):
				result["act3_name"] = "Abyssal Maw Rapture"
			if not result.has("act3_desc"):
				result["act3_desc"] = "The %s tears open a cosmic void rift, consuming the %s into the eternal abyss!" % [atk_name, vic_name]
		_: # High Fantasy default
			if not result.has("act1_name"):
				result["act1_name"] = "Opening Strike"
			if not result.has("act1_desc"):
				result["act1_desc"] = "The %s lunges forward with a heavy opening blow, deflected by the %s's guard!" % [atk_name, vic_name]
			if not result.has("act2_name"):
				result["act2_name"] = "Counter-Blow"
			if not result.has("act2_desc"):
				result["act2_desc"] = "The %s retaliates with a fierce counter-attack, but the %s deftly evades the strike!" % [vic_name, atk_name]
			if not result.has("act3_name"):
				result["act3_name"] = "The Finisher"
			if not result.has("act3_desc"):
				result["act3_desc"] = "The %s executes their signature theme finisher, striking down the %s!" % [atk_name, vic_name]

	return result

func _build_high_fantasy_matrix() -> Dictionary:
	return {
		# Pawn captures
		"P": {
			"P": {
				"anim_id": "hf_pawn_spear_skewer",
				"duration": 2.4,
				"impact_time": 1.1,
				"camera_angle": "side_tracking_medium",
				"vfx": "blood_spurt_sparks",
				"sfx": "metal_spear_thrust",
				"narrative": "The peasant spearman thrusts forward with desperate rage, impaling the rival infantryman through the breastplate."
			},
			"N": {
				"anim_id": "hf_pawn_unhorse_halberd",
				"duration": 3.0,
				"impact_time": 1.6,
				"camera_angle": "low_angle_upward",
				"vfx": "dust_horse_collapse",
				"sfx": "horse_whinny_armor_crash",
				"narrative": "Hooking the knight's stirrups with a peasant billhook, the pawn drags the arrogant armored knight down into the mud and executes him."
			},
			"Q": {
				"anim_id": "hf_pawn_underdog_assassination",
				"duration": 3.4,
				"impact_time": 1.9,
				"camera_angle": "dramatic_dolly_zoom",
				"vfx": "magic_shatter_burst",
				"sfx": "dagger_heart_pierce",
				"narrative": "Ducking underneath the Queen's blinding sorcery barrage, the peasant drives an iron dagger directly through her sorceress amulet."
			},
			"R": {
				"anim_id": "hf_pawn_siege_oil_ignite",
				"duration": 3.2,
				"impact_time": 1.5,
				"camera_angle": "high_angle_collapse",
				"vfx": "flame_blast_rubble",
				"sfx": "stone_crumble_inferno",
				"narrative": "The foot soldier lodges oil flasks into the stone golem's masonry joints, hurling a torch to ignite an explosive structural collapse."
			}
		},
		# Knight captures
		"N": {
			"P": {
				"anim_id": "hf_knight_lance_trample",
				"duration": 2.2,
				"impact_time": 0.9,
				"camera_angle": "gallop_follow_cam",
				"vfx": "ground_crack_dust",
				"sfx": "heavy_gallop_shield_smash",
				"narrative": "Lowering an oak jousting lance at full gallop, the knight shatters the peasant militia into airborne armor fragments."
			},
			"N": {
				"anim_id": "hf_knight_joust_decapitation",
				"duration": 2.8,
				"impact_time": 1.4,
				"camera_angle": "split_screen_clash",
				"vfx": "iron_sparks_splinters",
				"sfx": "lance_shatter_clash",
				"narrative": "Two armored knights charge head-on; the attacker's lance deflects the opponent's shield and snaps his helm clean off."
			},
			"Q": {
				"anim_id": "hf_knight_whirlwind_broadsword",
				"duration": 3.1,
				"impact_time": 1.7,
				"camera_angle": "orbit_360_slowmo",
				"vfx": "golden_holy_arc",
				"sfx": "blade_sing_critical",
				"narrative": "Vaulting off his armored warhorse, the knight cleaves his broadsword through the Queen's magical forcefield."
			}
		},
		# Bishop captures
		"B": {
			"R": {
				"anim_id": "hf_bishop_divine_pillar_smite",
				"duration": 3.5,
				"impact_time": 1.8,
				"camera_angle": "sky_orbital_pan",
				"vfx": "divine_pillar_golden_beam",
				"sfx": "cathedral_bell_smite",
				"narrative": "Chanting ancient ecclesiastical verses, the Bishop summons a pillar of celestial wrath that pulverizes the castle battlement to ash."
			},
			"P": {
				"anim_id": "hf_bishop_incense_purification",
				"duration": 2.5,
				"impact_time": 1.2,
				"camera_angle": "cinematic_side",
				"vfx": "radiant_burn_smoke",
				"sfx": "holy_whisper_flame",
				"narrative": "The Bishop touches the soldier's forehead with a consecrated burning mace, incinerating him in holy penitence."
			}
		},
		# Rook captures
		"R": {
			"K": {
				"anim_id": "hf_rook_colossus_throne_crush",
				"duration": 3.6,
				"impact_time": 2.0,
				"camera_angle": "low_angle_earthquake",
				"vfx": "massive_dust_shockwave",
				"sfx": "boulder_impact_quake",
				"narrative": "The living fortress towers over the King, slamming two granite fist ramparts down to crush the royal monarch into oblivion."
			},
			"N": {
				"anim_id": "hf_rook_catapult_countercharge",
				"duration": 2.7,
				"impact_time": 1.3,
				"camera_angle": "isometric_impact",
				"vfx": "stone_rubble_impact",
				"sfx": "stone_thud_splinter",
				"narrative": "The Rook unhinges its portcullis jaws, catching the galloping knight mid-air and smashing horse and rider into dust."
			}
		},
		# Queen captures
		"Q": {
			"Q": {
				"anim_id": "hf_queen_sorcery_cataclysm",
				"duration": 4.0,
				"impact_time": 2.2,
				"camera_angle": "dynamic_aerial_duel",
				"vfx": "arcane_vortex_disintegration",
				"sfx": "reality_tear_arcane_blast",
				"narrative": "Both Queens engage in an arcane spell duel; the winning Queen unleashes an elder supernova that evaporates her rival."
			},
			"K": {
				"anim_id": "hf_queen_regicide_execution",
				"duration": 3.2,
				"impact_time": 1.6,
				"camera_angle": "close_up_dramatic",
				"vfx": "frost_blood_crystallize",
				"sfx": "ice_shatter_crown_drop",
				"narrative": "With cold royal grace, the Queen freezes the enemy King in glacial frost and shatters his frozen torso with a touch of her staff."
			}
		},
		# King captures
		"K": {
			"P": {
				"anim_id": "hf_king_monarch_beheading",
				"duration": 2.6,
				"impact_time": 1.2,
				"camera_angle": "regal_portrait_cam",
				"vfx": "royal_gold_splash",
				"sfx": "heavy_claymore_swing",
				"narrative": "Drawing the gilded royal claymore, the Sovereign cleanly decapitates the trespassing foot soldier."
			}
		}
	}

func _build_cyberpunk_matrix() -> Dictionary:
	return {
		"P": {
			"P": {
				"anim_id": "cp_street_pawn_mono_wire_slice",
				"duration": 2.3,
				"impact_time": 1.0,
				"camera_angle": "cyber_glitch_third_person",
				"vfx": "neon_blue_spark_wires",
				"sfx": "laser_whip_hum_flesh_cut",
				"narrative": "The cyber-grunt unspools a finger-mounted monomolecular wire, garroting the opposing synthetic drone into glowing cyber-slices."
			},
			"N": {
				"anim_id": "cp_pawn_emp_drone_takedown",
				"duration": 2.8,
				"impact_time": 1.4,
				"camera_angle": "low_dutch_angle",
				"vfx": "blue_emp_shockwave_glitch",
				"sfx": "circuit_fry_servo_scream",
				"narrative": "The pawn detonates an overclocked EMP grenade, frying the cyber-biker's neural link and causing a catastrophic bike crash."
			}
		},
		"N": {
			"P": {
				"anim_id": "cp_knight_hoverbike_overrun",
				"duration": 2.4,
				"impact_time": 1.1,
				"camera_angle": "rear_chase_cam",
				"vfx": "pink_neon_exhaust_trail",
				"sfx": "jet_engine_whine_splat",
				"narrative": "Blasting through the grid on a high-speed hoverbike, the cyber-knight incinerates the pawn with dual plasma thrusters."
			},
			"R": {
				"anim_id": "cp_knight_mantis_blade_core_drill",
				"duration": 3.2,
				"impact_time": 1.7,
				"camera_angle": "climbing_action_cam",
				"vfx": "overheating_steam_core_vent",
				"sfx": "hydraulic_drill_metal_groan",
				"narrative": "Leaping onto the mechanical combat walker, the knight plunges thermal mantis blades through the cockpit windshield."
			}
		},
		"B": {
			"Q": {
				"anim_id": "cp_bishop_orbital_railgun_target",
				"duration": 3.6,
				"impact_time": 2.1,
				"camera_angle": "satellite_targeting_hud",
				"vfx": "kinetic_slug_atmospheric_plasma",
				"sfx": "railgun_sonic_crack_bass_drop",
				"narrative": "The Netrunner Bishop paints the target with a laser designator; a tungsten kinetic slug from low-orbit obliterates the cyborg Queen."
			}
		},
		"R": {
			"N": {
				"anim_id": "cp_rook_mech_gatling_shred",
				"duration": 3.0,
				"impact_time": 1.2,
				"camera_angle": "heavy_mech_turret_perspective",
				"vfx": "tracer_rounds_casing_rain",
				"sfx": "rotary_cannon_spin_up_roar",
				"narrative": "The quadrupedal mech lock-targets the agile biker, shredding machine and rider with depleted uranium Gatling fire."
			}
		},
		"Q": {
			"K": {
				"anim_id": "cp_queen_cyber_overclock_synapse_fry",
				"duration": 3.5,
				"impact_time": 1.8,
				"camera_angle": "matrix_code_hack_cam",
				"vfx": "digital_code_rain_blood_glitch",
				"sfx": "synapse_burn_flatline_tone",
				"narrative": "The Corporate Matriarch hacks the enemy King's cyberware, forcing his cybernetic limbs to rip his own head off."
			}
		}
	}

func _build_eldritch_matrix() -> Dictionary:
	return {
		"P": {
			"P": {
				"anim_id": "el_cultist_sacrifice_blade",
				"duration": 2.5,
				"impact_time": 1.2,
				"camera_angle": "unhinged_tilted_cam",
				"vfx": "black_ooze_tentacle_sprout",
				"sfx": "flesh_tear_whispers",
				"narrative": "The deranged cultist pawn mutters in R'lyehian, driving an obsidian sacrificial kris into the victim as void tendrils sprout from the wound."
			},
			"Q": {
				"anim_id": "el_pawn_void_portal_consumption",
				"duration": 3.8,
				"impact_time": 2.0,
				"camera_angle": "abyssal_eye_perspective",
				"vfx": "cosmic_madness_purple_nebula",
				"sfx": "sanity_loss_shriek_vacuum",
				"narrative": "The cultist tears open his own ribcage, unveiling a miniature singularity of madness that pulls the celestial Queen into the void."
			}
		},
		"N": {
			"N": {
				"anim_id": "el_tentacle_beast_maw_devour",
				"duration": 3.0,
				"impact_time": 1.5,
				"camera_angle": "shaky_horror_cam",
				"vfx": "purple_ichor_jaw_snap",
				"sfx": "bone_crunch_guttural_roar",
				"narrative": "A many-eyed nightmare steed unhinges four vertical maws, engulfing the opposing abomination whole in a flurry of snapping mandibles."
			}
		},
		"B": {
			"P": {
				"anim_id": "el_bishop_madness_stare",
				"duration": 2.8,
				"impact_time": 1.4,
				"camera_angle": "extreme_close_up_eyes",
				"vfx": "eyeball_burst_black_ink",
				"sfx": "maddening_piping_flutes",
				"narrative": "The Star-Spawn Bishop pulls down his veil; one glimpse of the non-Euclidean truth causes the pawn's head to implode from sheer madness."
			}
		},
		"R": {
			"P": {
				"anim_id": "el_rook_monolith_abyssal_drown",
				"duration": 3.4,
				"impact_time": 1.7,
				"camera_angle": "low_angle_suffocating",
				"vfx": "deep_sea_abyss_ink",
				"sfx": "oceanic_crush_drown",
				"narrative": "The living obelisk sinks into the ground, turning the battlefield into an abyssal bog that pulls the footman down into eternal darkness."
			}
		},
		"Q": {
			"K": {
				"anim_id": "el_queen_black_goat_shub_maw",
				"duration": 4.2,
				"impact_time": 2.4,
				"camera_angle": "apocalyptic_wide_pan",
				"vfx": "eldritch_thousand_young_swarm",
				"sfx": "cosmic_howl_flesh_feast",
				"narrative": "The Queen of the Thousand Young manifests cosmic tentacles across the board, pulling the helpless King into an endless cosmic abyss."
			}
		}
	}

func _get_thematic_fallback(theme: String, attacker: String, victim: String) -> Dictionary:
	var atk_name = _piece_name(attacker)
	var vic_name = _piece_name(victim)

	match theme:
		THEME_CYBERPUNK:
			return {
				"anim_id": "cp_generic_plasma_execution",
				"duration": 2.6,
				"impact_time": 1.2,
				"camera_angle": "cyber_side_pan",
				"vfx": "cyan_plasma_burst_sparks",
				"sfx": "plasma_blast_recharge",
				"narrative": "The %s overcharges its neural core, releasing a focused thermal plasma blast that terminates the %s." % [atk_name, vic_name]
			}
		THEME_ELDRITCH:
			return {
				"anim_id": "el_generic_tentacle_drag",
				"duration": 3.0,
				"impact_time": 1.5,
				"camera_angle": "distorted_horror_zoom",
				"vfx": "abyssal_shadow_smoke",
				"sfx": "slimy_tentacle_drag_shriek",
				"narrative": "Writhing shadowy tendrils erupt beneath the %s, pulling the %s into the screaming void." % [atk_name, vic_name]
			}
		_:
			return {
				"anim_id": "hf_generic_weapon_cleave",
				"duration": 2.5,
				"impact_time": 1.2,
				"camera_angle": "cinematic_action_tracking",
				"vfx": "steel_sparks_blood_burst",
				"sfx": "sword_slash_armor_clatter",
				"narrative": "The %s strikes with lethal combat precision, striking down the %s in a flurry of steel." % [atk_name, vic_name]
			}

func _piece_name(type_char: String) -> String:
	match type_char.to_upper():
		"P": return "Pawn"
		"N": return "Knight"
		"B": return "Bishop"
		"R": return "Rook"
		"Q": return "Queen"
		"K": return "King"
		_: return "Piece"
