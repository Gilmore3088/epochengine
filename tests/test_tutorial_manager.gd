extends GutTest

## Tests for TutorialManager (autoload/tutorial_manager.gd)


func before_each() -> void:
	TutorialManager.shown_tips.clear()
	TutorialManager.tip_queue.clear()
	TutorialManager.is_dismissed_all = false


# --- Tip Display ---

func test_try_show_tip_marks_shown() -> void:
	TutorialManager.try_show_tip("welcome")
	assert_true(TutorialManager.shown_tips.has("welcome"),
		"Tip should be marked as shown")


func test_try_show_tip_adds_to_queue() -> void:
	TutorialManager.try_show_tip("welcome")
	assert_eq(TutorialManager.tip_queue.size(), 1,
		"Tip should be added to queue")
	assert_eq(TutorialManager.tip_queue[0], "welcome")


func test_try_show_tip_no_duplicate() -> void:
	TutorialManager.try_show_tip("welcome")
	TutorialManager.try_show_tip("welcome")
	assert_eq(TutorialManager.tip_queue.size(), 1,
		"Duplicate tip should not be added")


# --- Dismiss All ---

func test_dismiss_all_suppresses_future() -> void:
	TutorialManager.dismiss_all()
	TutorialManager.try_show_tip("welcome")
	assert_false(TutorialManager.shown_tips.has("welcome"),
		"Tips should not show after dismiss_all")
	assert_eq(TutorialManager.tip_queue.size(), 0)


func test_dismiss_all_clears_queue() -> void:
	TutorialManager.try_show_tip("welcome")
	TutorialManager.try_show_tip("advance_turn")
	assert_eq(TutorialManager.tip_queue.size(), 2)
	TutorialManager.dismiss_all()
	assert_eq(TutorialManager.tip_queue.size(), 0,
		"Queue should be empty after dismiss_all")


# --- Queue Management ---

func test_on_tip_dismissed_advances_queue() -> void:
	TutorialManager.try_show_tip("welcome")
	TutorialManager.try_show_tip("advance_turn")
	assert_eq(TutorialManager.tip_queue[0], "welcome")
	TutorialManager.on_tip_dismissed()
	if not TutorialManager.tip_queue.is_empty():
		assert_eq(TutorialManager.tip_queue[0], "advance_turn",
			"Queue should advance to next tip")


func test_tip_queue_order() -> void:
	TutorialManager.try_show_tip("welcome")
	TutorialManager.try_show_tip("region_panel")
	TutorialManager.try_show_tip("food_shortage")
	assert_eq(TutorialManager.tip_queue[0], "welcome")
	assert_eq(TutorialManager.tip_queue[1], "region_panel")
	assert_eq(TutorialManager.tip_queue[2], "food_shortage")


# --- Save/Load ---

func test_get_save_data_includes_shown() -> void:
	TutorialManager.try_show_tip("welcome")
	TutorialManager.dismiss_all()
	var data := TutorialManager.get_save_data()
	assert_true(data.has("shown_tips"), "Save data should include shown_tips")
	assert_true(data.has("is_dismissed_all"), "Save data should include is_dismissed_all")
	assert_true(data["shown_tips"].has("welcome"))
	assert_true(data["is_dismissed_all"])


func test_load_save_data_restores_state() -> void:
	var data := {
		"shown_tips": {"welcome": true, "advance_turn": true},
		"is_dismissed_all": true,
	}
	TutorialManager.load_save_data(data)
	assert_true(TutorialManager.shown_tips.has("welcome"))
	assert_true(TutorialManager.shown_tips.has("advance_turn"))
	assert_true(TutorialManager.is_dismissed_all)


func test_load_empty_data_defaults() -> void:
	TutorialManager.try_show_tip("welcome")
	TutorialManager.load_save_data({})
	assert_false(TutorialManager.shown_tips.has("welcome"),
		"Empty load should clear shown_tips")
	assert_false(TutorialManager.is_dismissed_all)


# --- Data Integrity ---

func test_welcome_tip_exists() -> void:
	var found := false
	for tip in TutorialManager.TIPS:
		if tip["id"] == "welcome" and tip["priority"] == 0:
			found = true
			break
	assert_true(found, "TIPS should contain 'welcome' with priority 0")


func test_all_tips_have_required_fields() -> void:
	for tip in TutorialManager.TIPS:
		assert_true(tip.has("id"), "Tip missing 'id': %s" % str(tip))
		assert_true(tip.has("title"), "Tip missing 'title': %s" % tip["id"])
		assert_true(tip.has("body"), "Tip missing 'body': %s" % tip["id"])
		assert_true(tip.has("priority"), "Tip missing 'priority': %s" % tip["id"])


func test_tip_ids_unique() -> void:
	var ids: Dictionary = {}
	for tip in TutorialManager.TIPS:
		assert_false(ids.has(tip["id"]),
			"Duplicate tip ID: %s" % tip["id"])
		ids[tip["id"]] = true
