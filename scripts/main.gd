extends Node2D

var dragging: bool = false
var drag_offset: Vector2i = Vector2i.ZERO
var drag_start_mouse_pos: Vector2i
var prev_mouse_pos: Vector2i = Vector2i.ZERO
var drag_velocity: Vector2 = Vector2.ZERO
var toss_velocity_x: float = 0.0

var is_lifted: bool = false
var is_falling: bool = false
var fall_velocity: float = 0.0
const GRAVITY: float = 3400.0
const MAX_FALL_SPEED: float = 2400.0

@onready var reze_container: SubViewportContainer = $RezeViewportContainer
@onready var reze_3d = $RezeViewportContainer/RezeViewport/Reze3D
@onready var live2d_model = $Live2DModel
@onready var heart_particles: CPUParticles2D = $HeartParticles
@onready var sparkle_particles: CPUParticles2D = $SparkleParticles
@onready var ai_client = $AIClient

# UI elements
@onready var bubble_container: MarginContainer = $UI/BubbleContainer
@onready var bubble_panel: PanelContainer = $UI/BubbleContainer/SpeechBubble
@onready var speaker_badge: Label = $UI/BubbleContainer/SpeechBubble/MarginContainer/VBox/SpeakerBadge
@onready var bubble_label: Label = $UI/BubbleContainer/SpeechBubble/MarginContainer/VBox/BubbleLabel
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

# Emote Buttons
@onready var btn_emote_happy: Button = $UI/ContextMenu/Margin/VBox/EmoteRow/BtnEmoteHappy
@onready var btn_emote_blush: Button = $UI/ContextMenu/Margin/VBox/EmoteRow/BtnEmoteBlush
@onready var btn_emote_curious: Button = $UI/ContextMenu/Margin/VBox/EmoteRow/BtnEmoteCurious
@onready var btn_emote_sparkle: Button = $UI/ContextMenu/Margin/VBox/EmoteRow/BtnEmoteSparkle

# Quick Action Dock (Mini HUD)
@onready var quick_dock: PanelContainer = $UI/QuickDock
@onready var btn_dock_chat: Button = $UI/QuickDock/Margin/HBox/BtnDockChat
@onready var btn_dock_outfit: Button = $UI/QuickDock/Margin/HBox/BtnDockOutfit
@onready var btn_dock_gravity: Button = $UI/QuickDock/Margin/HBox/BtnDockGravity
@onready var btn_dock_poke: Button = $UI/QuickDock/Margin/HBox/BtnDockPoke
@onready var btn_dock_menu: Button = $UI/QuickDock/Margin/HBox/BtnDockMenu

var gravity_enabled: bool = true

# Live2D Parameters Map
var param_map: Dictionary = {}

# Available Models (Free Live2D Models Roster)
var model_list: Array = [
	{
		"name": "Camellya (Wuthering Waves)",
		"short_name": "Camellya",
		"type": "live2d",
		"path": "res://assets/live2d/camellya/camellya.model3.json",
		"scale": Vector2(0.09, 0.09),
		"pos": Vector2(240, 480)
	},
	{
		"name": "Hiyori (Official Live2D Full-Body)",
		"short_name": "Hiyori",
		"type": "live2d",
		"path": "res://assets/live2d/hiyori/Hiyori.model3.json",
		"scale": Vector2(0.24, 0.24),
		"pos": Vector2(240, 580)
	},
	{
		"name": "Ellen Joe (ZZZ)",
		"short_name": "Ellen Joe",
		"type": "live2d",
		"path": "res://assets/live2d/ellen/ellen.model3.json",
		"scale": Vector2(0.082, 0.082),
		"pos": Vector2(240, 520)
	},
	{
		"name": "Jane Doe (ZZZ)",
		"short_name": "Jane Doe",
		"type": "live2d",
		"path": "res://assets/live2d/jane/jane.model3.json",
		"scale": Vector2(0.078, 0.078),
		"pos": Vector2(240, 485)
	},
	{
		"name": "Mao (Official Live2D)",
		"short_name": "Mao",
		"type": "live2d",
		"path": "res://assets/live2d/mao/Mao.model3.json",
		"scale": Vector2(0.086, 0.086),
		"pos": Vector2(260, 490)
	},
	{
		"name": "Tingyun (Honkai Star Rail)",
		"short_name": "Tingyun",
		"type": "live2d",
		"path": "res://assets/live2d/tingyun/tingyun.model3.json",
		"scale": Vector2(0.12, 0.12),
		"pos": Vector2(240, 480)
	},
	{
		"name": "Fu Xuan (Honkai Star Rail)",
		"short_name": "Fu Xuan",
		"type": "live2d",
		"path": "res://assets/live2d/fuxuan/fuxuan.model3.json",
		"scale": Vector2(0.10, 0.10),
		"pos": Vector2(240, 480)
	},
	{
		"name": "Murasame (Senren Banka)",
		"short_name": "Murasame",
		"type": "live2d",
		"path": "res://assets/live2d/murasame/Murasame.model3.json",
		"scale": Vector2(0.19, 0.19),
		"pos": Vector2(240, 475)
	},
	{
		"name": "Nicole Demara (ZZZ)",
		"short_name": "Nicole",
		"type": "live2d",
		"path": "res://assets/live2d/nicole/Nicole.model3.json",
		"scale": Vector2(0.10, 0.10),
		"pos": Vector2(240, 480)
	},
	{
		"name": "Reze (3D Chainsaw Man)",
		"short_name": "Reze",
		"type": "3d",
		"path": ""
	}
]
var current_model_idx: int = 0

# Animation & Life Dynamics states
var is_speaking: bool = false
var mouth_open: bool = false
var is_blinking: bool = false

var anim_time: float = 0.0
var blink_timer: float = 3.5
var idle_action_timer: float = 12.0
var idle_glance_offset: float = 0.0
var talk_anim_timer: float = 0.0
var mouth_toggle_timer: float = 0.0
var bubble_hide_timer: float = 5.0

# Typewriter text streaming
var full_target_text: String = ""
var displayed_char_progress: float = 0.0
var is_typing: bool = false
const TYPEWRITER_SPEED: float = 40.0

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

	# Connect Emote Buttons
	btn_emote_happy.pressed.connect(func(): play_emote("happy"))
	btn_emote_blush.pressed.connect(func(): play_emote("blush"))
	btn_emote_curious.pressed.connect(func(): play_emote("curious"))
	btn_emote_sparkle.pressed.connect(func(): play_emote("sparkle"))

	# Connect Quick Action Dock
	btn_dock_chat.pressed.connect(_toggle_chat_input)
	btn_dock_outfit.pressed.connect(_cycle_next_model)
	btn_dock_gravity.pressed.connect(_toggle_gravity)
	btn_dock_poke.pressed.connect(func(): _handle_character_tap(Vector2(240, 200)))
	btn_dock_menu.pressed.connect(func(): _open_context_menu(Vector2(240, 360)))

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
	var label_text = "🌍 Gravity Drop: ON" if gravity_enabled else "🪶 Floating Mode: ON"
	ctx_gravity.text = label_text
	btn_dock_gravity.text = "🌍" if gravity_enabled else "🪶"
	btn_dock_gravity.tooltip_text = label_text
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

	# Passthrough polygon matching character silhouette + quickdock in 480x720 window
	var poly := PackedVector2Array([
		Vector2(20, 15),
		Vector2(460, 15),
		Vector2(460, 150),
		Vector2(420, 200),
		Vector2(430, 520),
		Vector2(370, 660),
		Vector2(360, 712),
		Vector2(120, 712),
		Vector2(110, 660),
		Vector2(50, 520),
		Vector2(60, 200),
		Vector2(20, 150)
	])
	get_window().mouse_passthrough_polygon = poly

func _process(delta: float) -> void:
	anim_time += delta

	# Track mouse drag velocity for toss throw inertia
	if dragging:
		var curr_mouse = DisplayServer.mouse_get_position()
		if prev_mouse_pos != Vector2i.ZERO and delta > 0.001:
			var instant_vel = Vector2(curr_mouse - prev_mouse_pos) / delta
			drag_velocity = drag_velocity.lerp(instant_vel, delta * 12.0)
		prev_mouse_pos = curr_mouse
	else:
		prev_mouse_pos = Vector2i.ZERO

	# Gravity & Dropping down with toss horizontal momentum
	if gravity_enabled and is_falling and not dragging:
		var floor_y = get_floor_y()
		fall_velocity = min(fall_velocity + GRAVITY * delta, MAX_FALL_SPEED)
		
		# Apply decaying toss horizontal velocity
		if abs(toss_velocity_x) > 5.0:
			get_window().position.x += int(toss_velocity_x * delta)
			toss_velocity_x = lerp(toss_velocity_x, 0.0, delta * 5.0)

		var next_y = get_window().position.y + int(fall_velocity * delta)
		if next_y >= floor_y:
			get_window().position.y = floor_y
			is_falling = false
			fall_velocity = 0.0
			toss_velocity_x = 0.0
			is_lifted = false
			say("Phew! Back on solid ground.", "neutral")
			_trigger_landing_bounce()
		else:
			get_window().position.y = next_y

	# Typewriter text streaming
	if is_typing:
		displayed_char_progress += delta * TYPEWRITER_SPEED
		var target_count = int(displayed_char_progress)
		if target_count >= full_target_text.length():
			bubble_label.text = full_target_text
			is_typing = false
		else:
			bubble_label.text = full_target_text.substr(0, target_count)

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
			var target_x = clamp(diff.x / 440.0, -1.0, 1.0)
			var target_y = clamp(-diff.y / 440.0, -1.0, 1.0)

			# Add organic idle micro-sway
			var idle_sway_z = sin(anim_time * 1.4) * 3.0
			var idle_sway_body = sin(anim_time * 1.1) * 2.5

			# Idle glance looking around every 14s
			idle_action_timer -= delta
			if idle_action_timer <= 0.0:
				idle_action_timer = randf_range(12.0, 18.0)
				idle_glance_offset = randf_range(-0.5, 0.5)
				get_tree().create_timer(1.2).timeout.connect(func(): idle_glance_offset = 0.0)

			# Angle Head & Eyes smoothly towards mouse + idle sway
			_set_param("ParamAngleX", (target_x + idle_glance_offset * 0.4) * 30.0, delta * 6.0)
			_set_param("ParamAngleY", target_y * 26.0, delta * 6.0)
			_set_param("ParamAngleZ", -target_x * 8.0 + idle_sway_z, delta * 5.0)
			_set_param("ParamEyeBallX", target_x + idle_glance_offset, delta * 8.0)
			_set_param("ParamEyeBallY", target_y, delta * 8.0)
			_set_param("ParamBodyAngleX", target_x * 10.0 + idle_sway_body, delta * 4.0)
		else:
			# Dangle / Picked-up flight physics: Body tilts into the direction of drag
			var tilt_z = clamp(-drag_velocity.x * 0.03, -16.0, 16.0)
			_set_param("ParamAngleZ", tilt_z, delta * 8.0)
			_set_param("ParamBodyAngleX", tilt_z * 0.5, delta * 6.0)
			_set_param("ParamEyeLOpen", 1.1, delta * 10.0)
			_set_param("ParamEyeROpen", 1.1, delta * 10.0)

		# Live2D Breathing
		var breath_val = (sin(anim_time * 2.2) + 1.0) * 0.5
		_set_param_direct("ParamBreath", breath_val)

		# Live2D Natural Blinking (with realistic 35% chance of double-blink)
		blink_timer -= delta
		if blink_timer <= 0.0 and not dragging:
			if not is_blinking:
				is_blinking = true
				var is_double = randf() < 0.35
				_set_param_direct("ParamEyeLOpen", 0.0)
				_set_param_direct("ParamEyeROpen", 0.0)
				get_tree().create_timer(0.12).timeout.connect(func():
					_set_param_direct("ParamEyeLOpen", 1.0)
					_set_param_direct("ParamEyeROpen", 1.0)
					if is_double:
						get_tree().create_timer(0.08).timeout.connect(func():
							_set_param_direct("ParamEyeLOpen", 0.0)
							_set_param_direct("ParamEyeROpen", 0.0)
							get_tree().create_timer(0.11).timeout.connect(func():
								is_blinking = false
								_set_param_direct("ParamEyeLOpen", 1.0)
								_set_param_direct("ParamEyeROpen", 1.0)
							)
						)
					else:
						is_blinking = false
				)
			blink_timer = randf_range(3.2, 5.8)

		# Live2D Mouth Flap while speaking
		if is_speaking:
			mouth_toggle_timer -= delta
			if mouth_toggle_timer <= 0.0:
				mouth_toggle_timer = 0.12
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
			var fade_tween = create_tween()
			fade_tween.tween_property(bubble_panel, "modulate:a", 0.0, 0.25)
			fade_tween.tween_callback(func():
				bubble_panel.visible = false
				bubble_panel.modulate.a = 1.0
				update_passthrough()
			)

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
		# Check click on speech bubble to skip typewriter
		if bubble_panel.visible and bubble_panel.get_global_rect().has_point(event.position):
			if is_typing:
				bubble_label.text = full_target_text
				is_typing = false
				return

		if input_container.visible and input_container.get_global_rect().has_point(event.position): return
		if context_menu.visible and context_menu.get_global_rect().has_point(event.position): return
		if settings_panel.visible and settings_panel.get_global_rect().has_point(event.position): return
		if quick_dock.visible and quick_dock.get_global_rect().has_point(event.position): return

		# RIGHT-CLICK: Context Menu
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_open_context_menu(event.position)
			return

		# LEFT-CLICK: Dragging or Hitbox Interactions (Multi-zone poke)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				is_falling = false
				fall_velocity = 0.0
				toss_velocity_x = 0.0
				is_lifted = false
				drag_start_mouse_pos = DisplayServer.mouse_get_position()
				drag_offset = DisplayServer.mouse_get_position() - get_window().position
				prev_mouse_pos = DisplayServer.mouse_get_position()
				drag_velocity = Vector2.ZERO
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
							toss_velocity_x = clamp(drag_velocity.x * 0.35, -500.0, 500.0)
							fall_velocity = max(60.0, drag_velocity.y * 0.25)
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
	
	# Magical landing sparkle stars burst
	if sparkle_particles:
		sparkle_particles.position = Vector2(240, 680)
		sparkle_particles.restart()
		sparkle_particles.emitting = true

func _handle_character_tap(click_pos: Vector2) -> void:
	# Multi-zone poke physics based on click Y coordinate
	if click_pos.y < 280:
		# Head zone: Affectionate headpat / stroke
		heart_particles.position = click_pos
		heart_particles.restart()
		heart_particles.emitting = true
		_set_param_direct("ParamCheekPuff", 0.6)
		_set_param_direct("ParamMouthForm", 1.0)
		var head_lines := [
			"Ehehe~ (≧◡≦) That feels so nice!",
			"(⁄ ⁄>⁄ ▽ ⁄<⁄ ⁄) Ah, you're patting my head!",
			"Hehe, you're so sweet today! ♡",
			"Keep going... I don't mind at all~"
		]
		say(head_lines.pick_random(), "happy")
	elif click_pos.y < 500:
		# Torso zone: Playful poke / tickle
		sparkle_particles.position = click_pos
		sparkle_particles.restart()
		sparkle_particles.emitting = true
		_set_param_direct("ParamCheekPuff", 0.3)
		var torso_lines := [
			"H-hey! That tickles! (≧▽≦)",
			"Wah! You surprised me!",
			"Need my help or just keeping me company?",
			"Right-click me or use the dock below anytime!"
		]
		say(torso_lines.pick_random(), "surprised")
	else:
		# Lower zone: Hop / bounce
		var base_scale: Vector2 = model_list[current_model_idx].scale if model_list[current_model_idx].type == "live2d" else Vector2.ONE
		var target_node = live2d_model if model_list[current_model_idx].type == "live2d" else reze_container
		var hop_tween = create_tween()
		hop_tween.tween_property(target_node, "position:y", model_list[current_model_idx].pos.y - 18, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hop_tween.tween_property(target_node, "position:y", model_list[current_model_idx].pos.y, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		var leg_lines := [
			"Boing! Ready for action! (★ω★)",
			"Stretching my legs! Let's get things done!",
			"Firmly on duty right beside you! (*^‿^*)"
		]
		say(leg_lines.pick_random(), "neutral")

func play_emote(emote_type: String) -> void:
	context_menu.visible = false
	update_passthrough()
	match emote_type:
		"happy":
			heart_particles.position = Vector2(240, 260)
			heart_particles.restart()
			heart_particles.emitting = true
			_set_param_direct("ParamMouthForm", 1.0)
			_set_param_direct("ParamCheekPuff", 0.5)
			say("I'm having so much fun being here with you! (≧◡≦)", "happy")
		"blush":
			heart_particles.position = Vector2(240, 240)
			heart_particles.restart()
			heart_particles.emitting = true
			_set_param_direct("ParamCheekPuff", 1.0)
			_set_param_direct("ParamEyeBallY", -0.3)
			say("(⁄ ⁄>⁄ ▽ ⁄<⁄ ⁄) S-stop staring so intently...!", "blush")
		"curious":
			_set_param_direct("ParamAngleZ", 12.0)
			_set_param_direct("ParamEyeBallX", 0.4)
			say("Hmm? What are you working on right now? Tell me!", "curious")
		"sparkle":
			sparkle_particles.position = Vector2(240, 400)
			sparkle_particles.restart()
			sparkle_particles.emitting = true
			say("✨ Let's do our absolute best today! You got this! ✨", "happy")

func _cycle_next_model() -> void:
	var next_idx = (current_model_idx + 1) % model_list.size()
	_on_model_selected(next_idx)

func _toggle_chat_input() -> void:
	context_menu.visible = false
	input_container.visible = not input_container.visible
	if input_container.visible:
		input_box.grab_focus()
	update_passthrough()

func _open_context_menu(pos: Vector2) -> void:
	context_menu.position = Vector2(
		clamp(pos.x - 70, 15, 230),
		clamp(pos.y - 40, 30, 400)
	)
	context_menu.visible = true
	update_passthrough()

func _on_model_selected(idx: int) -> void:
	if idx < 0 or idx >= model_list.size(): return
	current_model_idx = idx
	ctx_model_dropdown.selected = current_model_idx
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
		
	# Sparkle burst on outfit change!
	if sparkle_particles:
		sparkle_particles.position = Vector2(240, 500)
		sparkle_particles.restart()
		sparkle_particles.emitting = true

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
	full_target_text = text
	displayed_char_progress = 0.0
	is_typing = true
	
	# Update speaker badge with clean short name
	speaker_badge.text = " ✦ " + model_list[current_model_idx].short_name + " "
	
	bubble_label.text = ""
	bubble_panel.visible = true
	bubble_panel.modulate.a = 0.0
	
	# Smooth spring entrance tween
	bubble_container.scale = Vector2(0.92, 0.92)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(bubble_panel, "modulate:a", 1.0, 0.16)
	tween.tween_property(bubble_container, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	bubble_hide_timer = max(5.0, text.length() * 0.09)
	is_speaking = true
	talk_anim_timer = min(2.5, max(1.2, text.length() * 0.04))
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
		"builtin": provider_option.selected = 3

func _on_settings_save() -> void:
	ai_client.api_key = api_key_input.text.strip_edges()
	match provider_option.selected:
		0: ai_client.provider = "groq"
		1: ai_client.provider = "openrouter"
		2: ai_client.provider = "openai"
		3: ai_client.provider = "builtin"
	ai_client.save_config()
	settings_panel.visible = false
	say("Settings saved successfully! Ready to chat.", "neutral")
	update_passthrough()
