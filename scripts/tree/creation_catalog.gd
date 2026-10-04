class_name BonsaiCatalog
extends RefCounted

const SPECIES := ["ficus_microcarpa", "portulacaria_afra", "ulmus_parvifolia", "olea_europaea", "salix_babylonica"]
const POTS := ["slate_rectangle", "terracotta_round", "ivory_round", "blue_rectangle"]
const NAMES := {
	"ficus_microcarpa": "Ficus microcarpa",
	"portulacaria_afra": "Dwarf jade",
	"ulmus_parvifolia": "Chinese elm",
	"olea_europaea": "Olive",
	"salix_babylonica": "Weeping willow",
	"slate_rectangle": "Slate ceramic",
	"terracotta_round": "Round terracotta",
	"ivory_round": "Ivory ceramic",
	"blue_rectangle": "Blue glazed ceramic",
}
const DESCRIPTIONS := {
	"ficus_microcarpa": "A broad canopy with glossy leaves. A forgiving first tree.",
	"portulacaria_afra": "A compact succulent with fleshy leaves. Enjoys drier soil.",
	"ulmus_parvifolia": "An airy tree with small leaves and fine branching.",
	"olea_europaea": "Narrow silver-green leaves and a sturdy trunk. Grows slowly and prefers drier soil.",
	"salix_babylonica": "Long slender leaves and cascading branches. Grows quickly and needs more water.",
}
const POT_COLORS := {
	"slate_rectangle": Color("495551"), "terracotta_round": Color("b56e4d"),
	"ivory_round": Color("e5dcc4"), "blue_rectangle": Color("3f6683"),
}

static func profile(id: String) -> BonsaiSpecies:
	if id not in SPECIES: return null
	return load("res://resources/species/%s.tres" % id)

static func create(species: String, pot: String) -> BonsaiTree:
	if species not in SPECIES or pot not in POTS: return null
	var tree := BonsaiTree.starter()
	tree.species_id = species
	tree.pot_id = pot
	var species_profile := profile(species)
	for branch: BonsaiBranch in tree.branches.values():
		branch.length *= species_profile.initial_length_scale
		branch.bend *= species_profile.initial_bend_scale
		branch.thickness *= species_profile.initial_thickness_scale
		if branch.parent_id >= 0:
			branch.direction = (branch.direction + Vector3(0, species_profile.branch_vertical_bias, 0)).normalized()
			if species_profile.leaf_shape == "willow" and not branch.leaves.is_empty():
				branch.bend.y -= branch.length * 0.3
		for leaf: Dictionary in branch.leaves:
			leaf.size = species_profile.leaf_size
	return tree
