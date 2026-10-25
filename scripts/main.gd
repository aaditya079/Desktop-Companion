extends Node2D

var dragging: bool = false
var drag_offset: Vector2i = Vector2i.ZERO
var drag_start_mouse_pos: Vector2i
var is_lifted: bool = false
var is_falling: bool = false
var fall_velocity: float = 0.0
const GRAVITY: float = 3400.0
const MAX_FALL_SPEED: float = 2400.0

@onready var reze_container: SubViewportContainer = $RezeViewportContainer
@onready var reze_3d = $RezeViewportContainer/RezeViewport/Reze3D
@onready var live2d_model = $Live2DModel
@onready var heart_particles: CPUParticles2D = $HeartParticles
@onready var ai_client = $AIClient

# UI elements
@onready var bubble_container: MarginContainer = $UI/BubbleContainer
@onready var bubble_panel: PanelContainer = $UI/BubbleContainer/SpeechBubble
@onready var bubble_label: Label = $UI/BubbleContainer/SpeechBubble/MarginContainer/BubbleLabel
@onready var input_container: PanelContainer = $UI/InputContainer
@onready var input_box: LineEdit = $UI/InputContainer/Margin/HBox/InputBox
@onready var send_btn: Button = $UI/InputContainer/Margin/HBox/SendButton
@onready var context_menu: PanelContainer = $UI/ContextMenu
@onready var settings_panel: PanelContainer = $UI/SettingsPanel
@onready var api_key_input: LineEdit = $UI/SettingsPanel/Margin/VBox/KeyInput
@onready var provider_option: OptionButton = $UI/SettingsPanel/Margin/VBox/ProviderOption
@onready var save_btn: Button = $UI/SettingsPanel/Margin/VBox/HBox/SaveButton
@onready var close_btn: Button = $UI/SettingsPanel/Margin/VBox/HBox/CloseButton

# Context Menu Buttons & Controls
@onready var ctx_talk: Button = $UI/ContextMenu/Margin/VBox/BtnTalk
@onready var ctx_model_dropdown: OptionButton = $UI/ContextMenu/Margin/VBox/ModelDropdown
@onready var ctx_gravity: Button = $UI/ContextMenu/Margin/VBox/BtnGravity
@onready var ctx_settings: Button = $UI/ContextMenu/Margin/VBox/BtnSettings
@onready var ctx_quit: Button = $UI/ContextMenu/Margin/VBox/BtnQuit

var gravity_enabled: bool = true

# Live2D Parameters Map
var param_map: Dictionary = {}

# Available Models (Free Live2D Models Roster)
var model_list: Array = [
	{
		"name": "Camellya (Wuthering Waves)",
		"type": "live2d",
		"path": "res://assets/live2d/camellya/camellya.model3.json",
		"scale": Vector2(0.09, 0.09),
		"pos": Vector2(240, 480)
	},
	{
		"name": "Hiyori (Official Live2D Full-Body)",
		"type": "live2d",
		"path": "res://assets/live2d/hiyori/Hiyori.model3.json",
		"scale": Vector2(0.24, 0.24),
		"pos": Vector2(240, 580)
	},
	{
		"name": "Ellen Joe (ZZZ)",
		"type": "live2d",
		"path": "res://assets/live2d/ellen/ellen.model3.json",
		"scale": Vector2(0.082, 0.082),
		"pos": Vector2(240, 520)
	},
	{
		"name": "Jane Doe (ZZZ)",
		"type": "live2d",
		"path": "res://assets/live2d/jane/jane.model3.json",
		"scale": Vector2(0.078, 0.078),
		"pos": Vector2(240, 485)
	},
	{
		"name": "Mao (Official Live2D)",
		"type": "live2d",
		"path": "res://assets/live2d/mao/Mao.model3.json",
		"scale": Vector2(0.086, 0.086),
		"pos": Vector2(260, 490)
	},
	{
		"name": "Tingyun (Honkai Star Rail)",
		"type": "live2d",
		"path": "res://assets/live2d/tingyun/tingyun.model3.json",
		"scale": Vector2(0.12, 0.12),
		"pos": Vector2(240, 480)
	},
	{
		"name": "Fu Xuan (Honkai Star Rail)",
		"type": "live2d",
		"path": "res://assets/live2d/fuxuan/fuxuan.model3.json",
		"scale": Vector2(0.10, 0.10),
		"pos": Vector2(240, 480)
	},
	{
		"name": "Murasame (Senren Banka)",
		"type": "live2d",
		"path": "res://assets/live2d/murasame/Murasame.model3.json",
		"scale": Vector2(0.19, 0.19),
		"pos": Vector2(240, 475)
	},
	{
		"name": "Nicole Demara (ZZZ)",
		"type": "live2d",
		"path": "res://assets/live2d/nicole/Nicole.model3.json",
		"scale": Vector2(0.10, 0.10),
		"pos": Vector2(240, 480)
	},
	{
		"name": "Reze (3D Chainsaw Man)",
		"type": "3d",
		"path": ""
	}
]
var current_model_idx: int = 0

# Animation states
var is_speaking: bool = false
var mouth_open: bool = false
var is_blinking: bool = false

var anim_time: float = 0.0
var blink_timer: float = 3.5
var talk_anim_timer: float = 0.0
var mouth_toggle_timer: float = 0.0
var bubble_hide_timer: float = 5.0

func get_floor_y() -> int:
	var win = get_window()
	var screen_idx = win.current_screen
	var screen_rect := DisplayServer.screen_get_usable_rect(screen_idx)
	if screen_rect.size.x <= 100 or screen_rect.size.y <= 100:
		var scr_size = DisplayServer.screen_get_size(screen_idx)
		if scr_size.x > 100:
			screen_rect = Rect2i(0, 0, scr_size.x, scr_size.y - 40)
		else:
			screen_rect = Rect2i(0, 0, 1920, 1040)
	return screen_rect.position.y + screen_rect.size.y - win.size.y

func _ready() -> void:
	print(">>> MAIN _READY STARTED <<<")
	# Configure transparent borderless floating window
	var win := get_window()
	win.transparent = true
	win.borderless = true
	win.always_on_top = true
	get_tree().root.transparent_bg = true

	# Idle optimization
	Engine.max_fps = 30
	OS.low_processor_usage_mode = true

	# Set Camellya Live2D as default model
	reze_container.visible = false
	live2d_model.visible = true
	var default_model = model_list[0]
	live2d_model.assets = default_model.path
	live2d_model.scale = default_model.scale
	live2d_model.position = default_model.pos

	param_map.clear()
	for p in live2d_model.get_parameters():
		param_map[p.id] = p

	# Place window in bottom right of desktop directly touching taskbar
	var screen_idx = win.current_screen
	var screen_rect := DisplayServer.screen_get_usable_rect(screen_idx)
	if screen_rect.size.x <= 100 or screen_rect.size.y <= 100:
		var scr_size = DisplayServer.screen_get_size(screen_idx)
		if scr_size.x > 100:
			screen_rect = Rect2i(0, 0, scr_size.x, scr_size.y - 40)
		else:
			screen_rect = Rect2i(0, 0, 1920, 1040)
	var px = screen_rect.position.x + screen_rect.size.x - win.size.x - 10
	var py = get_floor_y()
	win.position = Vector2i(px, py)
	win.always_on_top = true
	print(">>> Window positioned at: ", win.position, " size: ", win.size, " floor_y: ", py)

	# Connect UI Signals
	input_box.text_submitted.connect(_on_input_submitted)
	send_btn.pressed.connect(func(): _on_input_submitted(input_box.text))
	
	ctx_talk.pressed.connect(_toggle_chat_input)
	ctx_gravity.pressed.connect(_toggle_gravity)
	ctx_settings.pressed.connect(_open_settings)
	ctx_quit.pressed.connect(func(): get_tree().quit())

	# Setup model dropdown
	ctx_model_dropdown.clear()
	for i in range(model_list.size()):
		ctx_model_dropdown.add_item(model_list[i].name, i)
	ctx_model_dropdown.selected = current_model_idx
	ctx_model_dropdown.item_selected.connect(_on_model_selected)

	save_btn.pressed.connect(_on_settings_save)
	close_btn.pressed.connect(func(): settings_panel.visible = false; update_passthrough())

	ai_client.thinking_started.connect(_on_ai_thinking)
	ai_client.reply_received.connect(_on_ai_reply)
	ai_client.request_failed.connect(_on_ai_error)

	# Setup settings provider options
	provider_option.clear()
	provider_option.add_item("Groq (Free & Fast)", 0)
	provider_option.add_item("OpenRouter", 1)
	provider_option.add_item("OpenAI", 2)
	provider_option.add_item("Built-in Standalone", 3)

	_show_time_greeting()
	update_passthrough()
	print(">>> MAIN _READY COMPLETED <<<")

func _toggle_gravity() -> void:
	gravity_enabled = not gravity_enabled
	ctx_gravity.text = "🌍 Gravity Drop: ON" if gravity_enabled else "🪶 Floating Mode: ON"
	if gravity_enabled:
		say("Gravity enabled! I'll drop down to the taskbar.", "neutral")
		var floor_y = get_floor_y()
		if get_window().position.y < floor_y - 4:
			is_falling = true
			fall_velocity = 80.0
	else:
		is_falling = false
		fall_velocity = 0.0
		say("Floating mode! You can place me anywhere on screen.", "neutral")
	context_menu.visible = false
	update_passthrough()

func update_passthrough() -> void:
	if context_menu.visible or settings_panel.visible or input_container.visible:
		get_window().mouse_passthrough_polygon = PackedVector2Array()
		return

	# Passthrough polygon matching character silhouette in 480x720 window
	var poly := PackedVector2Array([
		Vector2(20, 15),
		Vector2(460, 15),
		Vector2(460, 150),
		Vector2(420, 200),
		Vector2(430, 520),
		Vector2(370, 718),
		Vector2(110, 718),
		Vector2(50, 520),
		Vector2(60, 200),
		Vector2(20, 150)
	])
	get_window().mouse_passthrough_polygon = poly

func _process(delta: float) -> void:
	anim_time += delta

	# Gravity & Dropping down to taskbar baseline
	if gravity_enabled and is_falling and not dragging:
		var floor_y = get_floor_y()
		fall_velocity = min(fall_velocity + GRAVITY * delta, MAX_FALL_SPEED)
		var next_y = get_window().position.y + int(fall_velocity * delta)
		if next_y >= floor_y:
			get_window().position.y = floor_y
			is_falling = false
			fall_velocity = 0.0
			is_lifted = false
			say("Phew! Back on solid ground.", "neutral")
			_trigger_landing_bounce()
		else:
			get_window().position.y = next_y

	var mouse_global = DisplayServer.mouse_get_position()
	var char_global_center = get_window().position + Vector2i(240, 360)

	# Reze (3D Model Active)
	if model_list[current_model_idx].type == "3d":
		if reze_3d:
			if not dragging:
				reze_3d.update_gaze_target(Vector2(mouse_global), Vector2(char_global_center))
			reze_3d.set_speaking(is_speaking)
	else:
		# Live2D Model Active
		if not dragging:
			var diff = Vector2(mouse_global - char_global_center)
			# Mouse tracking math:
			# diff.x > 0 means mouse is to the right of companion
			# -diff.y > 0 means mouse is above companion (since Y grows downwards in screen space)
			var target_x = clamp(diff.x / 420.0, -1.0, 1.0)
			var target_y = clamp(-diff.y / 420.0, -1.0, 1.0)

			# Angle Head & Eyes smoothly towards mouse
			_set_param("ParamAngleX", target_x * 30.0, delta * 6.0)
			_set_param("ParamAngleY", target_y * 26.0, delta * 6.0)
			_set_param("ParamAngleZ", -target_x * 8.0, delta * 5.0)
			_set_param("ParamEyeBallX", target_x, delta * 8.0)
			_set_param("ParamEyeBallY", target_y, delta * 8.0)
			_set_param("ParamBodyAngleX", target_x * 10.0, delta * 4.0)

		# Live2D Breathing
		var breath_val = (sin(anim_time * 2.2) + 1.0) * 0.5
		_set_param_direct("ParamBreath", breath_val)

		# Live2D Blinking
		blink_timer -= delta
		if blink_timer <= 0.0:
			if not is_blinking:
				is_blinking = true
				_set_param_direct("ParamEyeLOpen", 0.0)
				_set_param_direct("ParamEyeROpen", 0.0)
				get_tree().create_timer(0.14).timeout.connect(func():
					is_blinking = false
					_set_param_direct("ParamEyeLOpen", 1.0)
					_set_param_direct("ParamEyeROpen", 1.0)
				)
			blink_timer = randf_range(3.0, 5.5)

		# Live2D Mouth Flap
		if is_speaking:
			mouth_toggle_timer -= delta
			if mouth_toggle_timer <= 0.0:
				mouth_toggle_timer = 0.13
				mouth_open = not mouth_open
				_set_param_direct("ParamMouthOpenY", 0.85 if mouth_open else 0.0)

	# Global speech animation timer
	if is_speaking:
		talk_anim_timer -= delta
		if talk_anim_timer <= 0.0:
			is_speaking = false
			mouth_open = false
			_set_param_direct("ParamMouthOpenY", 0.0)

	# Auto-Hide Speech Bubble
	if bubble_panel.visible:
		bubble_hide_timer -= delta
		if bubble_hide_timer <= 0.0:
			bubble_panel.visible = false
			update_passthrough()

func _set_param(param_id: String, target_val: float, weight: float) -> void:
	if param_map.has(param_id):
		var p = param_map[param_id]
		p.value = lerp(p.value, target_val, weight)

func _set_param_direct(param_id: String, val: float) -> void:
	if param_map.has(param_id):
		param_map[param_id].value = val

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if context_menu.visible:
				context_menu.visible = false
				update_passthrough()
				return
			if settings_panel.visible:
				settings_panel.visible = false
				update_passthrough()
				return
			if input_container.visible:
				input_container.visible = false
				update_passthrough()
				return
			get_tree().quit()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if not input_container.visible:
				_toggle_chat_input()

	if event is InputEventMouseButton:
		if input_container.visible and input_container.get_global_rect().has_point(event.position): return
		if context_menu.visible and context_menu.get_global_rect().has_point(event.position): return
		if settings_panel.visible and settings_panel.get_global_rect().has_point(event.position): return

		# RIGHT-CLICK: Context Menu
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_open_context_menu(event.position)
			return

		# LEFT-CLICK: Dragging or Hitbox Interactions (Poke)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				is_falling = false
				fall_velocity = 0.0
				is_lifted = false
				drag_start_mouse_pos = DisplayServer.mouse_get_position()
				drag_offset = DisplayServer.mouse_get_position() - get_window().position
				context_menu.visible = false
			else:
				if dragging:
					dragging = false
					var drag_dist = (DisplayServer.mouse_get_position() - drag_start_mouse_pos).length()
					if drag_dist < 6:
						_handle_character_tap(event.position)
					else:
						var floor_y = get_floor_y()
						if gravity_enabled and get_window().position.y < floor_y - 4:
							is_falling = true
							fall_velocity = 120.0
						else:
							if gravity_enabled:
								get_window().position.y = floor_y
							if is_lifted:
								is_lifted = false
								say("Phew! Thanks for putting me down.", "neutral")
								if gravity_enabled:
									_trigger_landing_bounce()

	elif event is InputEventMouseMotion and dragging:
		var moved_dist = (DisplayServer.mouse_get_position() - drag_start_mouse_pos).length()
		if moved_dist > 8:
			if not is_lifted:
				is_lifted = true
				var lift_lines := [
					"W-wait a second...! Where are we going?",
					"A-ah! Put me down gently!",
					"Flying mode activated! (≧◡≦)",
					"Hold on tight!"
				]
				say(lift_lines.pick_random(), "neutral")
			var target_pos = DisplayServer.mouse_get_position() - drag_offset
			if gravity_enabled:
				var floor_y = get_floor_y()
				target_pos.y = min(target_pos.y, floor_y)
			get_window().position = target_pos

func _trigger_landing_bounce() -> void:
	var base_scale: Vector2 = model_list[current_model_idx].scale if model_list[current_model_idx].type == "live2d" else Vector2.ONE
	var target_node = live2d_model if model_list[current_model_idx].type == "live2d" else reze_container
	var tween = create_tween()
	# Subtle squish down on impact
	tween.tween_property(target_node, "scale", Vector2(base_scale.x * 1.08, base_scale.y * 0.92), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Rebound slightly
	tween.tween_property(target_node, "scale", Vector2(base_scale.x * 0.97, base_scale.y * 1.03), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Settle back to original scale
	tween.tween_property(target_node, "scale", base_scale, 0.1).set_trans(Tween.TRANS_SINE)

func _handle_character_tap(_click_pos: Vector2) -> void:
	do_poke()

func do_poke() -> void:
	context_menu.visible = false
	var poke_lines := [
		"Hey! (≧◡≦) Did you need anything?",
		"Need my help or just checking in?",
		"Right-click me to change my outfit or chat!",
		"Boop! I'm right here with you."
	]
	say(poke_lines.pick_random(), "neutral")

func _toggle_chat_input() -> void:
	context_menu.visible = false
	input_container.visible = not input_container.visible
	if input_container.visible:
		input_box.grab_focus()
	update_passthrough()

func _open_context_menu(pos: Vector2) -> void:
	context_menu.position = Vector2(
		clamp(pos.x - 70, 15, 210),
		clamp(pos.y - 40, 40, 420)
	)
	context_menu.visible = true
	update_passthrough()

func _on_model_selected(idx: int) -> void:
	if idx < 0 or idx >= model_list.size(): return
	current_model_idx = idx
	var info = model_list[current_model_idx]
	
	if info.type == "3d":
		reze_container.visible = true
		live2d_model.visible = false
	else:
		reze_container.visible = false
		live2d_model.visible = true
		live2d_model.assets = info.path
		live2d_model.scale = info.scale
		live2d_model.position = info.pos
		
		param_map.clear()
		for p in live2d_model.get_parameters():
			param_map[p.id] = p
		
	say("Switched to " + info.name + "!", "neutral")
	context_menu.visible = false
	update_passthrough()

func _open_settings() -> void:
	context_menu.visible = false
	settings_panel.visible = true
	_update_settings_ui()
	update_passthrough()

func _show_time_greeting() -> void:
	var hour: int = Time.get_time_dict_from_system().hour
	if hour >= 23 or hour < 5:
		say("It's late at night... shouldn't you be asleep? Don't strain your eyes! ( ᴗ˳ᴗ)", "neutral")
	elif hour >= 5 and hour < 12:
		say("Good morning! Let's get things done today! Right-click me anytime.", "neutral")
	elif hour >= 12 and hour < 18:
		say("Good afternoon! Working hard? Don't forget to stay hydrated!", "neutral")
	else:
		say("Good evening! Unwinding or still busy? I'm right here with you.", "neutral")

func say(text: String, _expression: String = "neutral") -> void:
	bubble_label.text = text
	bubble_panel.visible = true
	bubble_hide_timer = max(4.5, text.length() * 0.08)
	is_speaking = true
	talk_anim_timer = min(2.5, max(1.0, text.length() * 0.035))
	update_passthrough()

func _on_input_submitted(text: String) -> void:
	var clean := text.strip_edges()
	if clean.is_empty(): return
	input_box.clear()
	input_container.visible = false
	update_passthrough()
	ai_client.send_message(clean)

func _on_ai_thinking() -> void:
	say("Thinking...", "neutral")

func _on_ai_reply(reply: String, expression: String) -> void:
	say(reply, expression)

func _on_ai_error(err_msg: String) -> void:
	say(err_msg, "sad")

func _update_settings_ui() -> void:
	api_key_input.text = ai_client.api_key
	match ai_client.provider:
		"groq": provider_option.selected = 0
		"openrouter": provider_option.selected = 1
		"openai": provider_option.selected = 2
		_: provider_option.selected = 3

func _on_settings_save() -> void:
	ai_client.api_key = api_key_input.text.strip_edges()
	match provider_option.selected:
		0:
			ai_client.provider = "groq"
			ai_client.base_url = "https://api.groq.com/openai"
			ai_client.model_name = "llama-3.3-70b-versatile"
		1:
			ai_client.provider = "openrouter"
			ai_client.base_url = "https://openrouter.ai/api"
			ai_client.model_name = "meta-llama/llama-3.2-3b-instruct:free"
		2:
			ai_client.provider = "openai"
			ai_client.base_url = "https://api.openai.com"
			ai_client.model_name = "gpt-4o-mini"
		3:
			ai_client.provider = "offline"
			ai_client.api_key = ""

	ai_client.save_config()
	settings_panel.visible = false
	say("Settings saved! Ready to talk.", "neutral")
	update_passthrough()
