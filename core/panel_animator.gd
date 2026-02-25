class_name PanelAnimator
extends RefCounted

## Reusable panel open/close animations (fade + scale).


static func open_panel(panel: Control) -> Tween:
	## Animate panel in: fade from 0, scale from 0.92 to 1.0.
	panel.pivot_offset = panel.size / 2.0
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	panel.visible = true

	var tween := panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return tween


static func close_panel(panel: Control, callback: Callable = Callable()) -> Tween:
	## Animate panel out: fade to 0, scale to 0.92, then hide + reset.
	panel.pivot_offset = panel.size / 2.0

	var tween := panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "scale", Vector2(0.92, 0.92), 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	tween.chain().tween_callback(func() -> void:
		panel.visible = false
		panel.modulate.a = 1.0
		panel.scale = Vector2.ONE
		if callback.is_valid():
			callback.call()
	)
	return tween
