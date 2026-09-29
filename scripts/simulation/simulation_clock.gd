class_name BonsaiClock
extends RefCounted

var real_seconds_per_day := 3600.0
var pending_days := 0.0
var paused := false

func advance(tree: BonsaiTree, simulation: BonsaiSimulation, seconds: float, offline := false) -> Dictionary:
	if paused or seconds <= 0 or not is_finite(seconds):
		return {"days": 0.0, "dormant_days": 0.0, "steps": 0}
	var days := seconds / maxf(60, real_seconds_per_day)
	var dormant := maxf(0, days - BonsaiSimulation.MAX_ACTIVE_OFFLINE_DAYS) if offline else 0.0
	pending_days += days - dormant
	var steps := int(floor((pending_days + 0.00000001) / BonsaiSimulation.STEP_DAYS))
	var simulated := steps * BonsaiSimulation.STEP_DAYS
	if steps > 0:
		simulation.advance_days(tree, simulated)
		pending_days = maxf(0, pending_days - simulated)
	# Dormancy is an explicit game rule, not silently discarded elapsed time.
	tree.age_days += dormant
	return {"days": simulated + dormant, "dormant_days": dormant, "steps": steps}
