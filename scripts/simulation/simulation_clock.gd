class_name BonsaiClock
extends RefCounted

const DEFAULT_SECONDS_PER_DAY := 10800.0
var real_seconds_per_day := DEFAULT_SECONDS_PER_DAY
var pending_days := 0.0
var paused := false

# All trees share one elapsed-time remainder, so switching cannot skip or repeat time.
func advance_grove(trees: Array, active: BonsaiTree, seconds: float, offline := false) -> Dictionary:
	var previous_pending := pending_days
	var result := {"days": 0.0, "dormant_days": 0.0, "steps": 0}
	for specimen: BonsaiTree in trees:
		pending_days = previous_pending
		var elapsed := advance(specimen, BonsaiSimulation.new(BonsaiCatalog.profile(specimen.species_id)), seconds, offline)
		if specimen == active: result = elapsed
	return result

static func upgrade_rate(settings: Dictionary) -> void:
	if is_equal_approx(float(settings.get("real_seconds_per_day", 3600)), 3600):
		settings.real_seconds_per_day = DEFAULT_SECONDS_PER_DAY

func advance(tree: BonsaiTree, simulation: BonsaiSimulation, seconds: float, _offline := false) -> Dictionary:
	if paused or seconds <= 0 or not is_finite(seconds):
		return {"days": 0.0, "dormant_days": 0.0, "steps": 0}
	var days := seconds / maxf(60, real_seconds_per_day)
	# Also bounds a missed foreground tick after OS suspension without a lifecycle signal.
	var dormant := maxf(0, days - BonsaiSimulation.MAX_ACTIVE_OFFLINE_DAYS)
	pending_days += days - dormant
	var steps := int(floor((pending_days + 0.00000001) / BonsaiSimulation.STEP_DAYS))
	var simulated := steps * BonsaiSimulation.STEP_DAYS
	if steps > 0:
		simulation.advance_days(tree, simulated)
		pending_days = maxf(0, pending_days - simulated)
	# Dormancy is an explicit game rule, not silently discarded elapsed time.
	tree.age_days += dormant
	return {"days": simulated + dormant, "dormant_days": dormant, "steps": steps}
