extends Node

## Ranked Elo Rating Math & Division Tier System
## Handles matchmaking expected score calculations, dynamic K-factor adjustments,
## and division categorization from Bronze through Grandmaster.

enum Tier {
	BRONZE,
	SILVER,
	GOLD,
	PLATINUM,
	DIAMOND,
	MASTER,
	GRANDMASTER
}

const TIER_THRESHOLDS = {
	Tier.BRONZE: 0,
	Tier.SILVER: 1000,
	Tier.GOLD: 1200,
	Tier.PLATINUM: 1400,
	Tier.DIAMOND: 1600,
	Tier.MASTER: 1800,
	Tier.GRANDMASTER: 2000
}

## Calculate expected score: E_A = 1 / (1 + 10^((R_B - R_A) / 400))
static func get_expected_score(rating_a: float, rating_b: float) -> float:
	var exponent = (rating_b - rating_a) / 400.0
	return 1.0 / (1.0 + pow(10.0, exponent))

## Determine dynamic K-Factor based on player rating and experience
static func get_k_factor(rating: int, matches_played: int) -> int:
	if matches_played < 30:
		return 40 # Placement / high volatility phase
	elif rating >= 2000:
		return 10 # Master / Grandmaster stability phase
	else:
		return 20 # Standard established competitor

## Calculate post-match Elo adjustments for both players
## score_a: 1.0 for player A win, 0.5 for draw, 0.0 for player B win
static func calculate_rating_change(rating_a: int, rating_b: int, score_a: float, matches_a: int = 50, matches_b: int = 50) -> Dictionary:
	var expected_a = get_expected_score(float(rating_a), float(rating_b))
	var expected_b = 1.0 - expected_a
	var score_b = 1.0 - score_a

	var k_a = get_k_factor(rating_a, matches_a)
	var k_b = get_k_factor(rating_b, matches_b)

	var delta_a = roundi(k_a * (score_a - expected_a))
	var delta_b = roundi(k_b * (score_b - expected_b))

	var new_rating_a = maxi(100, rating_a + delta_a)
	var new_rating_b = maxi(100, rating_b + delta_b)

	return {
		"player_a": {
			"old_rating": rating_a,
			"new_rating": new_rating_a,
			"delta": delta_a,
			"expected": expected_a,
			"tier": get_tier_name(new_rating_a)
		},
		"player_b": {
			"old_rating": rating_b,
			"new_rating": new_rating_b,
			"delta": delta_b,
			"expected": expected_b,
			"tier": get_tier_name(new_rating_b)
		}
	}

static func get_tier(rating: int) -> Tier:
	if rating >= TIER_THRESHOLDS[Tier.GRANDMASTER]: return Tier.GRANDMASTER
	if rating >= TIER_THRESHOLDS[Tier.MASTER]: return Tier.MASTER
	if rating >= TIER_THRESHOLDS[Tier.DIAMOND]: return Tier.DIAMOND
	if rating >= TIER_THRESHOLDS[Tier.PLATINUM]: return Tier.PLATINUM
	if rating >= TIER_THRESHOLDS[Tier.GOLD]: return Tier.GOLD
	if rating >= TIER_THRESHOLDS[Tier.SILVER]: return Tier.SILVER
	return Tier.BRONZE

static func get_tier_name(rating: int) -> String:
	var tier = get_tier(rating)
	match tier:
		Tier.GRANDMASTER: return "Grandmaster"
		Tier.MASTER: return "Master"
		Tier.DIAMOND: return "Diamond"
		Tier.PLATINUM: return "Platinum"
		Tier.GOLD: return "Gold"
		Tier.SILVER: return "Silver"
		_: return "Bronze"

static func get_division_label(rating: int) -> String:
	var tier = get_tier(rating)
	var tier_name = get_tier_name(rating)
	if tier == Tier.GRANDMASTER or tier == Tier.MASTER:
		return tier_name

	var floor_rating = TIER_THRESHOLDS[tier]
	var span = 200
	var offset = rating - floor_rating
	var sub_div = 3 - clamp(offset / (span / 3), 0, 2)
	var roman = "I" if sub_div == 1 else ("II" if sub_div == 2 else "III")
	return "%s %s" % [tier_name, roman]

static func get_tier_color(rating: int) -> Color:
	var tier = get_tier(rating)
	match tier:
		Tier.GRANDMASTER: return Color(1.0, 0.2, 0.25, 1.0) # Vivid Crimson
		Tier.MASTER: return Color(0.85, 0.35, 0.95, 1.0)     # Royal Amethyst
		Tier.DIAMOND: return Color(0.2, 0.85, 1.0, 1.0)      # Cyan Diamond
		Tier.PLATINUM: return Color(0.3, 0.95, 0.75, 1.0)    # Emerald Platinum
		Tier.GOLD: return Color(1.0, 0.85, 0.25, 1.0)        # Bright Gold
		Tier.SILVER: return Color(0.75, 0.8, 0.88, 1.0)      # Sterling Silver
		_: return Color(0.8, 0.5, 0.3, 1.0)                 # Weathered Bronze

static func get_progress_to_next_tier(rating: int) -> Dictionary:
	var tier = get_tier(rating)
	if tier == Tier.GRANDMASTER:
		return {"progress_ratio": 1.0, "points_needed": 0, "next_tier": "Max Rank"}

	var next_tier_enum = (int(tier) + 1) as Tier
	var next_floor = TIER_THRESHOLDS[next_tier_enum]
	var current_floor = TIER_THRESHOLDS[tier]
	var points_in_tier = rating - current_floor
	var total_tier_points = next_floor - current_floor
	var ratio = clampf(float(points_in_tier) / float(total_tier_points), 0.0, 1.0)

	return {
		"progress_ratio": ratio,
		"points_needed": next_floor - rating,
		"current_tier": get_tier_name(rating),
		"next_tier": get_tier_name(next_floor)
	}
