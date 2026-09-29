class_name BonsaiSave
extends RefCounted

const VERSION := 1
var path := "user://grove.json"
var last_error := ""
var read_only := false
var recovered := false

func make_document(trees: Array, active: String, settings: Dictionary, timestamp: float, pending: float) -> Dictionary:
	var rows: Array = []
	for tree: BonsaiTree in trees:
		rows.append(tree.to_data())
	return {"version": VERSION, "active_tree": active, "trees": rows,
		"settings": settings.duplicate(true), "last_real_timestamp": timestamp,
		"pending_days": pending, "owned_items": ["ficus_microcarpa", "slate_rectangle", "daylight_studio"],
		"owned_trees": rows.map(func(row): return row.id)}

func write_document(document: Dictionary) -> bool:
	if read_only:
		last_error = "Save is protected. Reset explicitly to start a new tree."
		return false
	if not valid(document):
		last_error = "Refused invalid save state."
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Could not write save file (%d)." % FileAccess.get_open_error()
		return false
	file.store_string(JSON.stringify(document))
	file.flush()
	file.close()
	if _read(path + ".tmp").is_empty():
		last_error = "Save verification failed."
		return false
	# Copy only a known-good primary; never rotate corruption over a valid backup.
	if not _read(path).is_empty():
		if DirAccess.copy_absolute(path, path + ".bak") != OK:
			last_error = "Could not preserve previous save."
			return false
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		last_error = "Could not replace save file."
		return false
	last_error = ""
	return true

func load_document() -> Dictionary:
	last_error = ""
	recovered = false
	read_only = false
	if FileAccess.file_exists(path):
		var raw: Variant = _parse(FileAccess.get_file_as_string(path))
		if raw is Dictionary and _number(raw.get("version")) and raw.version > VERSION:
			read_only = true
			last_error = "This save belongs to a newer version. It has been preserved."
			return {}
	var document := _read(path)
	if not document.is_empty(): return document
	for candidate in [path + ".bak", path + ".tmp"]:
		document = _read(candidate)
		if not document.is_empty():
			recovered = true
			last_error = "Recovered the tree from a backup."
			return document
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak") or FileAccess.file_exists(path + ".tmp"):
		read_only = true
		last_error = "Save could not be read. Original files were preserved."
	return {}

func _read(filename: String) -> Dictionary:
	if not FileAccess.file_exists(filename): return {}
	var file := FileAccess.open(filename, FileAccess.READ)
	if file == null or file.get_length() > 16000000: return {}
	var raw: Variant = _parse(file.get_as_text())
	file.close()
	if not raw is Dictionary: return {}
	var data := migrate(raw)
	return data if valid(data) else {}

func migrate(data: Dictionary) -> Dictionary:
	# Add explicit version-to-version transformations here as the schema changes.
	return data if data.get("version") == VERSION else {}

func _parse(text: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(text) == OK else null

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _vector(value: Variant) -> bool:
	if not value is Array or value.size() != 3: return false
	for axis in value:
		if not _number(axis) or absf(axis) > 100: return false
	return true

func valid(data: Dictionary) -> bool:
	if data.get("version") != VERSION or not data.get("trees") is Array: return false
	if data.trees.is_empty() or data.trees.size() > 32: return false
	if not _number(data.get("last_real_timestamp")) or data.last_real_timestamp < 0: return false
	if not _number(data.get("pending_days")) or data.pending_days < 0 or data.pending_days >= 0.25: return false
	if not data.get("settings") is Dictionary: return false
	var settings: Dictionary = data.settings
	if not _number(settings.get("real_seconds_per_day")) or settings.real_seconds_per_day < 60 or settings.real_seconds_per_day > 86400: return false
	if not settings.get("sound") is bool or not settings.get("quality") in ["Low", "Medium", "High"]: return false
	var ids: Array = []
	for row in data.trees:
		if not row is Dictionary or not _valid_tree(row) or row.id in ids: return false
		ids.append(row.id)
	return data.get("active_tree") in ids

func _valid_tree(row: Dictionary) -> bool:
	for key in ["id", "species", "pot"]:
		if not row.get(key) is String or row[key].is_empty(): return false
	for key in ["age_days", "acquired_at", "next_id", "moisture", "nutrients", "root_health", "root_mass", "energy", "stress", "pruning_stress", "water_capacity", "drainage"]:
		if not _number(row.get(key)) or row[key] < 0: return false
	if row.water_capacity <= 0 or row.moisture > 1.8 or row.nutrients > 2 or row.root_health > 1: return false
	if not row.get("environment") is Dictionary: return false
	for key in ["light", "temperature", "humidity"]:
		if not _number(row.environment.get(key)): return false
	if not _vector(row.environment.get("light_direction")): return false
	if not row.get("roots") is Array or row.roots.size() > 32: return false
	for root in row.roots:
		if not root is Dictionary: return false
		for key in ["angle", "length", "thickness"]:
			if not _number(root.get(key)): return false
	if not row.get("history") is Array or row.history.size() > 256: return false
	if not row.get("branches") is Array or row.branches.is_empty() or row.branches.size() > BonsaiTree.MAX_BRANCHES: return false
	var parents: Dictionary = {}
	var root_count := 0
	for b in row.branches:
		if not b is Dictionary: return false
		for key in ["id", "parent", "attachment", "length", "thickness", "age", "health", "energy", "buds", "bud_charge"]:
			if not _number(b.get(key)): return false
		if b.id < 0 or b.id != int(b.id) or b.parent != int(b.parent) or b.id >= row.next_id or parents.has(int(b.id)): return false
		if b.length <= 0 or b.length > 10 or b.thickness <= 0 or b.thickness > 1 or b.attachment < 0 or b.attachment > 1: return false
		if not _vector(b.get("direction")) or not _vector(b.get("bend")): return false
		if Vector3(b.direction[0], b.direction[1], b.direction[2]).length() < 0.1: return false
		if not b.get("pruned") is bool or not b.get("wiring") is Dictionary: return false
		if not b.get("leaves") is Array or b.leaves.size() > BonsaiTree.MAX_LEAVES: return false
		for leaf in b.leaves:
			if not leaf is Dictionary: return false
			for key in ["at", "age", "health", "angle", "size"]:
				if not _number(leaf.get(key)): return false
			if leaf.at < 0 or leaf.at > 1 or leaf.size < 0 or leaf.size > 3: return false
		parents[int(b.id)] = int(b.parent)
		if int(b.parent) == -1: root_count += 1
	if root_count != 1: return false
	for id: int in parents:
		var seen: Dictionary = {}
		var cursor := id
		while cursor != -1:
			if seen.has(cursor) or not parents.has(cursor) or seen.size() > 64: return false
			seen[cursor] = true
			cursor = parents[cursor]
	return true
