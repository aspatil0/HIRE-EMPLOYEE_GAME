class_name SettingsPanel
extends ModalPanel
## Volume sliders per audio bus and a fullscreen toggle. Changes apply live
## and are saved to user://settings.cfg when the panel closes.

const ROWS := [[&"Master", "MASTER VOLUME"], [&"Music", "MUSIC"], [&"SFX", "SOUND EFFECTS"], [&"Ambience", "AMBIENCE"]]


func _init() -> void:
	title = "SETTINGS"
	subtitle = "Audio and display"
	panel_size = Vector2(860, 620)


func _build_content(body: VBoxContainer) -> void:
	body.add_theme_constant_override(&"separation", 22)
	body.add_child(ModalPanel.section_label("Audio"))
	for row: Array in ROWS:
		body.add_child(_volume_row(row[0], row[1]))
	body.add_child(ModalPanel.hsep())
	body.add_child(ModalPanel.section_label("Display"))
	var fs := CheckButton.new()
	fs.text = "FULLSCREEN   (F11)"
	fs.focus_mode = Control.FOCUS_NONE
	fs.button_pressed = GameSettings.fullscreen
	fs.add_theme_font_size_override(&"font_size", 20)
	fs.toggled.connect(func(on: bool) -> void:
		AudioManager.play_sfx(&"ui_click")
		GameSettings.set_fullscreen(on))
	body.add_child(fs)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	var done := UITheme.button("DONE")
	done.size_flags_horizontal = Control.SIZE_SHRINK_END
	done.pressed.connect(close)
	body.add_child(done)


func _volume_row(bus: StringName, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 24)
	var l := UITheme.label(label_text, &"DimLabel", 17, UITheme.INK)
	l.custom_minimum_size = Vector2(240, 0)
	row.add_child(l)
	var slider := HSlider.new()
	slider.name = "Slider_%s" % bus
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = GameSettings.get_volume(bus)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.add_child(slider)
	var pct := UITheme.label("%d%%" % roundi(slider.value * 100.0), &"MonoLabel", 18, UITheme.WARM)
	pct.custom_minimum_size = Vector2(70, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pct)
	slider.value_changed.connect(func(v: float) -> void:
		GameSettings.set_volume(bus, v)
		pct.text = "%d%%" % roundi(v * 100.0))
	slider.drag_ended.connect(func(_changed: bool) -> void: AudioManager.play_sfx(&"ui_click", -6.0))
	return row


func _on_closing() -> void:
	GameSettings.save_settings()
