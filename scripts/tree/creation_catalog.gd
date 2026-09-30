class_name BonsaiCatalog
extends RefCounted

const SPECIES := ["ficus_microcarpa", "portulacaria_afra", "ulmus_parvifolia"]
const POTS := ["slate_rectangle", "terracotta_round", "ivory_round", "blue_rectangle"]
const NAMES := {
	"ficus_microcarpa": "Ficus microcarpa",
	"portulacaria_afra": "Dwarf jade",
	"ulmus_parvifolia": "Chinese elm",
	"slate_rectangle": "Slate ceramic",
	"terracotta_round": "Round terracotta",
	"ivory_round": "Ivory ceramic",
	"blue_rectangle": "Blue glazed ceramic",
}
const DESCRIPTIONS := {
	"ficus_microcarpa": "A broad canopy with glossy leaves. A forgiving first tree.",
	"portulacaria_afra": "A compact succulent with fleshy leaves. Enjoys drier soil.",
	"ulmus_parvifolia": "An airy tree with small leaves and fine branching.",
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
	var compact := species == "portulacaria_afra"
	var elm := species == "ulmus_parvifolia"
	for branch: BonsaiBranch in tree.branches.values():
		if compact:
			branch.length *= 0.75
			branch.bend *= 0.75
			branch.thickness *= 1.15
		elif elm:
			branch.thickness *= 0.72
			branch.direction = (branch.direction + Vector3(0, 0.18, 0)).normalized()
		for leaf: Dictionary in branch.leaves:
			leaf.size = 0.65 if compact else (0.62 if elm else 1.0)
	return tree
