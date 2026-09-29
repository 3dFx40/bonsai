extends SceneTree

func _initialize() -> void:
	var tree := BonsaiTree.starter()
	assert(tree.branches.size() == 35)
	assert(tree.leaf_count() == 192)
	var before := tree.branches.size()
	var removed := tree.descendants(3)
	assert(tree.prune(3))
	assert(tree.branches.size() == before - removed.size())
	for id in removed:
		assert(not tree.branches.has(id))
	assert(not tree.prune(0))
	var clone := BonsaiTree.from_data(tree.to_data())
	assert(clone.to_data() == tree.to_data())
	print("PASS tree topology, subtree removal, trunk protection, serialization")
	quit()
