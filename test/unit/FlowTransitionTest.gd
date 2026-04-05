extends GdUnitTestSuite

const FlowTransitionScript: GDScript = preload("res://Scripts/FlowTransition.gd")


func test_play_fade_in_shows_target_and_ends_at_full_alpha() -> void:
	var root: Control = auto_free(Control.new())
	add_child(root)
	await await_idle_frame()

	var target: PanelContainer = auto_free(PanelContainer.new())
	root.add_child(target)
	target.visible = false
	target.modulate = Color(1.0, 1.0, 1.0, 0.5)

	var tween: Tween = FlowTransitionScript.play_fade_in(root, target, 0.02, 0.0)
	assert_object(tween).is_not_null()
	assert_bool(target.visible).is_true()
	await tween.finished

	assert_float(target.modulate.a).is_equal_approx(1.0, 0.01)


func test_play_fade_out_hides_target_and_restores_alpha() -> void:
	var root: Control = auto_free(Control.new())
	add_child(root)
	await await_idle_frame()

	var target: PanelContainer = auto_free(PanelContainer.new())
	root.add_child(target)
	target.visible = true
	target.modulate = Color(1.0, 1.0, 1.0, 1.0)

	var tween: Tween = FlowTransitionScript.play_fade_out(root, target, 0.02)
	assert_object(tween).is_not_null()
	await tween.finished

	assert_bool(target.visible).is_false()
	assert_float(target.modulate.a).is_equal_approx(1.0, 0.01)


func test_play_fade_out_returns_null_when_target_already_hidden() -> void:
	var root: Control = auto_free(Control.new())
	add_child(root)
	await await_idle_frame()

	var target: PanelContainer = auto_free(PanelContainer.new())
	root.add_child(target)
	target.visible = false

	var tween: Tween = FlowTransitionScript.play_fade_out(root, target, 0.02)
	assert_object(tween).is_null()
