extends GutTest

## Tests for AudioManager procedural sound generation and PanelAnimator.


# --- AudioManager: gen_tone ---

func test_gen_tone_correct_sample_count():
	var samples := AudioManager.gen_tone(440.0, 0.1, 0.5)
	var expected: int = int(0.1 * 44100.0)
	assert_eq(samples.size(), expected, "0.1s tone should have 4410 samples")


func test_gen_tone_amplitude_within_range():
	var samples := AudioManager.gen_tone(440.0, 0.05, 0.6)
	for i in samples.size():
		assert_true(absf(samples[i]) <= 0.6 + 0.001,
			"Sample %d should not exceed requested amplitude" % i)


func test_gen_tone_fade_out_decreases():
	var samples := AudioManager.gen_tone(440.0, 0.1, 0.5, true)
	# Compare amplitude near start vs near end (use RMS of small windows)
	var start_sum := 0.0
	var end_sum := 0.0
	var window := 100
	for i in window:
		start_sum += absf(samples[i])
		end_sum += absf(samples[samples.size() - 1 - i])
	assert_gt(start_sum, end_sum, "Fade-out tone should be louder at start than end")


# --- AudioManager: gen_noise ---

func test_gen_noise_correct_sample_count():
	var samples := AudioManager.gen_noise(0.1, 0.3)
	var expected: int = int(0.1 * 44100.0)
	assert_eq(samples.size(), expected, "0.1s noise should have 4410 samples")


# --- AudioManager: gen_chord ---

func test_gen_chord_correct_sample_count():
	var freqs: Array[float] = [440.0, 550.0, 660.0]
	var samples := AudioManager.gen_chord(freqs, 0.1, 0.3)
	var expected: int = int(0.1 * 44100.0)
	assert_eq(samples.size(), expected, "0.1s chord should have 4410 samples")


# --- PanelAnimator ---

func test_open_panel_sets_visible():
	var panel := PanelContainer.new()
	panel.visible = false
	panel.size = Vector2(200, 100)
	add_child_autofree(panel)

	PanelAnimator.open_panel(panel)
	assert_true(panel.visible, "Panel should be visible after open_panel")


func test_open_panel_returns_tween():
	var panel := PanelContainer.new()
	panel.size = Vector2(200, 100)
	add_child_autofree(panel)

	var tween := PanelAnimator.open_panel(panel)
	assert_not_null(tween, "open_panel should return a Tween")
