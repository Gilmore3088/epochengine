extends GutTest

## Tests for war visualization features (battle markers, war status bar).


# --- Battle Marker ---

func test_pending_battle_flash_starts_false() -> void:
	var rv := RegionVisual.new()
	add_child_autofree(rv)
	assert_false(rv._pending_battle_flash,
		"_pending_battle_flash should start false")


func test_show_battle_marker_adds_child() -> void:
	var rv := RegionVisual.new()
	rv.region_data = RegionData.new()
	rv.region_data.id = 1
	rv._local_points = PackedVector2Array([
		Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100),
	])
	add_child_autofree(rv)

	var initial_children := rv.get_child_count()
	rv._show_battle_marker(true)
	assert_gt(rv.get_child_count(), initial_children,
		"Battle marker should add a child node")


func test_battle_marker_color_attacker_wins() -> void:
	var rv := RegionVisual.new()
	rv.region_data = RegionData.new()
	rv.region_data.id = 2
	rv._local_points = PackedVector2Array([
		Vector2(0, 0), Vector2(50, 0), Vector2(50, 50), Vector2(0, 50),
	])
	add_child_autofree(rv)

	rv._show_battle_marker(true)
	# The marker is the last child (Node2D), its first child (Line2D) has color
	var marker := rv.get_child(rv.get_child_count() - 1)
	var line: Line2D = marker.get_child(0) as Line2D
	assert_almost_eq(line.default_color.r, 1.0, 0.01,
		"Attacker win color should be red-tinted")


func test_battle_marker_color_defender_wins() -> void:
	var rv := RegionVisual.new()
	rv.region_data = RegionData.new()
	rv.region_data.id = 3
	rv._local_points = PackedVector2Array([
		Vector2(0, 0), Vector2(50, 0), Vector2(50, 50), Vector2(0, 50),
	])
	add_child_autofree(rv)

	rv._show_battle_marker(false)
	var marker := rv.get_child(rv.get_child_count() - 1)
	var line: Line2D = marker.get_child(0) as Line2D
	assert_almost_eq(line.default_color.r, 0.9, 0.01,
		"Defender win color should be yellow-tinted")


# --- Turn Summary Colors ---

func test_turn_summary_alliance_broken_color() -> void:
	var panel := TurnSummaryPanel.new()
	add_child_autofree(panel)
	var color: String = panel._type_color("alliance_broken")
	assert_eq(color, "#da8", "alliance_broken should have #da8 color")


func test_turn_summary_alliance_broken_prefix() -> void:
	var panel := TurnSummaryPanel.new()
	add_child_autofree(panel)
	var prefix: String = panel._type_prefix("alliance_broken")
	assert_eq(prefix, "[ALLIANCE]", "alliance_broken should have [ALLIANCE] prefix")
