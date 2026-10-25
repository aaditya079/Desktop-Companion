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

# UI Speech Bubble & Chat Input
@onready var bubble_container: MarginContainer = $UI/BubbleContainer
@onready var bubble_panel: PanelContainer = $UI/BubbleContainer/SpeechBubble
@onready var speaker_badge: Label = $UI/BubbleContainer/SpeechBubble/MarginContainer/VBox/SpeakerBadge
@onready var bubble_label: Label = $UI/BubbleContainer/SpeechBubble/MarginContainer/VBox/BubbleLabel
@onready var input_container: PanelContainer = $UI/InputContainer
@onready var input_box: LineEdit = $UI/InputContainer/Margin/HBox/InputBox
@onready var send_btn: Button = $UI/InputContainer/Margin/HBox/SendButton

# Focus Timer Widget & Audio
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer
@onready var focus_widget: PanelContainer = $UI/FocusTimerWidget
@onready var focus_label: Label = $UI/FocusTimerWidget/Margin/HBox/TimerLabel
@onready var btn_stop_focus: Button = $UI/FocusTimerWidget/Margin/HBox/BtnStopTimer

# 9-Pill Action Menu (Visual Novel / Desktop Companion HUD)
@onready var pill_menu: Control = $UI/PillMenu
@onready var btn_snack: Button = $UI/PillMenu/VBox/BtnSnack
@onready var btn_note: Button = $UI/PillMenu/VBox/BtnNote
@onready var btn_feelings: Button = $UI/PillMenu/VBox/BtnFeelings
@onready var btn_day: Button = $UI/PillMenu/VBox/BtnDay
@onready var btn_time: Button = $UI/PillMenu/VBox/BtnTime
@onready var btn_music: Button = $UI/PillMenu/VBox/BtnMusic
@onready var btn_comfort: Button = $UI/PillMenu/VBox/BtnComfort
@onready var btn_memory: Button = $UI/PillMenu/VBox/BtnMemory
@onready var btn_settings: Button = $UI/PillMenu/VBox/BtnSettings

# Quick Note / Memo Popup
@onready var note_popup: PanelContainer = $UI/NotePopup
@onready var note_edit: TextEdit = $UI/NotePopup/Margin/VBox/NoteEdit
@onready var btn_save_note: Button = $UI/NotePopup/Margin/VBox/BtnSaveNote
@onready var btn_close_note: Button = $UI/NotePopup/Margin/VBox/HeaderHBox/BtnCloseNote

# Memory & Journey Popup
@onready var memory_popup: PanelContainer = $UI/MemoryPopup
@onready var btn_close_memory: Button = $UI/MemoryPopup/Margin/VBox/HeaderHBox/BtnCloseMemory
@onready var lbl_pats: Label = $UI/MemoryPopup/Margin/VBox/StatsVBox/LblPats
@onready var lbl_focus: Label = $UI/MemoryPopup/Margin/VBox/StatsVBox/LblFocus
@onready var lbl_notes: Label = $UI/MemoryPopup/Margin/VBox/StatsVBox/LblNotes
@onready var lbl_model: Label = $UI/MemoryPopup/Margin/VBox/StatsVBox/LblModel
@onready var lbl_affinity: Label = $UI/MemoryPopup/Margin/VBox/StatsVBox/LblAffinity
@onready var lbl_mood: Label = $UI/MemoryPopup/Margin/VBox/StatsVBox/LblMood
@onready var lbl_facts: Label = $UI/MemoryPopup/Margin/VBox/StatsVBox/LblFacts

# Chat History & Memory Drawer
@onready var chat_drawer: PanelContainer = $UI/ChatLogDrawer
@onready var chat_drawer_close: Button = $UI/ChatLogDrawer/Margin/VBox/HeaderHBox/CloseChatLog
@onready var chat_drawer_affinity: Label = $UI/ChatLogDrawer/Margin/VBox/AffinityTag
@onready var chat_drawer_list: VBoxContainer = $UI/ChatLogDrawer/Margin/VBox/Scroll/MessageList
@onready var chat_drawer_clear: Button = $UI/ChatLogDrawer/Margin/VBox/BottomRow/BtnClearChat
@onready var chat_drawer_open_input: Button = $UI/ChatLogDrawer/Margin/VBox/BottomRow/BtnOpenInput

# Tool Execution & Security Confirmation
@onready var tool_chip: PanelContainer = $UI/BubbleContainer/SpeechBubble/MarginContainer/VBox/ToolChip
@onready var tool_chip_label: Label = $UI/BubbleContainer/SpeechBubble/MarginContainer/VBox/ToolChip/ToolChipMargin/ToolChipLabel
@onready var tool_confirm_modal: PanelContainer = $UI/ToolConfirmModal
@onready var tool_name_lbl: Label = $UI/ToolConfirmModal/Margin/VBox/ToolNameLabel
@onready var command_text_lbl: Label = $UI/ToolConfirmModal/Margin/VBox/CodeScroll/CommandText
@onready var btn_authorize_tool: Button = $UI/ToolConfirmModal/Margin/VBox/ActionHBox/BtnAuthorizeTool
@onready var btn_deny_tool: Button = $UI/ToolConfirmModal/Margin/VBox/ActionHBox/BtnDenyTool
@onready var btn_close_confirm: Button = $UI/ToolConfirmModal/Margin/VBox/HeaderHBox/BtnCloseConfirm
var pending_tool_id: String = ""
var is_backend_connected: bool = false

var ambient_timer: float = 90.0

# Comprehensive Settings Panel
@onready var settings_panel: PanelContainer = $UI/SettingsPanel
@onready var model_dropdown: OptionButton = $UI/SettingsPanel/Margin/VBox/ModelDropdown
@onready var scale_dropdown: OptionButton = $UI/SettingsPanel/Margin/VBox/ScaleDropdown
@onready var btn_perch: Button = $UI/SettingsPanel/Margin/VBox/TogglesRow/BtnPerch
@onready var btn_gravity: Button = $UI/SettingsPanel/Margin/VBox/TogglesRow/BtnGravity
@onready var btn_sound: Button = $UI/SettingsPanel/Margin/VBox/TogglesRow/BtnSound
@onready var provider_option: OptionButton = $UI/SettingsPanel/Margin/VBox/ProviderOption
@onready var endpoint_input: LineEdit = $UI/SettingsPanel/Margin/VBox/EndpointInput
@onready var model_name_input: LineEdit = $UI/SettingsPanel/Margin/VBox/ModelNameInput
@onready var api_key_input: LineEdit = $UI/SettingsPanel/Margin/VBox/KeyInput
@onready var btn_test_api: Button = $UI/SettingsPanel/Margin/VBox/TestRow/BtnTestApi
@onready var test_status_lbl: Label = $UI/SettingsPanel/Margin/VBox/TestRow/TestStatusLabel
@onready var save_btn: Button = $UI/SettingsPanel/Margin/VBox/HBox/SaveButton
@onready var close_btn: Button = $UI/SettingsPanel/Margin/VBox/HBox/CloseButton
@onready var close_x_btn: Button = $UI/SettingsPanel/Margin/VBox/HeaderHBox/CloseX

var gravity_enabled: bool = true
var sound_enabled: bool = false
var current_scale_multiplier: float = 1.0

# OS Window Topology & Perching Engine
var perch_enabled: bool = false
var is_perching: bool = false
var target_perch_pos: Vector2 = Vector2.ZERO
var tracked_app_name: String = ""
var tracked_app_title: String = ""
var last_app_comment_time: float = 0.0
var window_topology_active: bool = false

# Headpat Animation State
var is_headpatting: bool = false
var headpat_timer: float = 0.0
var headpat_stroke_time: float = 0.0

# Focus Mode state
var focus_active: bool = false
var focus_time_left: float = 1500.0 # 25 min default

# Memory & Journey Statistics
var total_headpats: int = 0
var total_focus_minutes: int = 0

# Shake & Dizzy Physics
var shake_energy: float = 0.0
var prev_drag_vel_x: float = 0.0
var is_dizzy: bool = false
var dizzy_timer: float = 0.0

# Hydration & Ergonomics Check-in
var hydration_timer: float = 2700.0 # 45 minutes

# Procedural Audio Cache
var sfx_library: Dictionary = {}

# System Tray IPC (UDP Server on 127.0.0.1:48291)
var udp_server: PacketPeerUDP = null
const UDP_PORT: int = 48291

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
		"pos": Vector2(160, 480)
	},
	{
		"name": "Hiyori (Official Live2D Full-Body)",
		"short_name": "Hiyori",
		"type": "live2d",
		"path": "res://assets/live2d/hiyori/Hiyori.model3.json",
		"scale": Vector2(0.24, 0.24),
		"pos": Vector2(160, 580)
	},
	{
		"name": "Ellen Joe (ZZZ)",
		"short_name": "Ellen Joe",
		"type": "live2d",
		"path": "res://assets/live2d/ellen/ellen.model3.json",
		"scale": Vector2(0.082, 0.082),
		"pos": Vector2(160, 520)
	},
	{
		"name": "Jane Doe (ZZZ)",
		"short_name": "Jane Doe",
		"type": "live2d",
		"path": "res://assets/live2d/jane/jane.model3.json",
		"scale": Vector2(0.078, 0.078),
		"pos": Vector2(160, 485)
	},
	{
		"name": "Mao (Official Live2D)",
		"short_name": "Mao",
		"type": "live2d",
		"path": "res://assets/live2d/mao/Mao.model3.json",
		"scale": Vector2(0.086, 0.086),
		"pos": Vector2(175, 490)
	},
	{
		"name": "Tingyun (Honkai Star Rail)",
		"short_name": "Tingyun",
		"type": "live2d",
		"path": "res://assets/live2d/tingyun/tingyun.model3.json",
		"scale": Vector2(0.12, 0.12),
		"pos": Vector2(160, 480)
	},
	{
		"name": "Fu Xuan (Honkai Star Rail)",
		"short_name": "Fu Xuan",
		"type": "live2d",
		"path": "res://assets/live2d/fuxuan/fuxuan.model3.json",
		"scale": Vector2(0.10, 0.10),
		"pos": Vector2(160, 480)
	},
	{
		"name": "Murasame (Senren Banka)",
		"short_name": "Murasame",
		"type": "live2d",
		"path": "res://assets/live2d/murasame/Murasame.model3.json",
		"scale": Vector2(0.19, 0.19),
		"pos": Vector2(160, 475)
	},
	{
		"name": "Nicole Demara (ZZZ)",
		"short_name": "Nicole",
		"type": "live2d",
		"path": "res://assets/live2d/nicole/Nicole.model3.json",
		"scale": Vector2(0.10, 0.10),
		"pos": Vector2(160, 480)
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

func get_usable_screen_rect() -> Rect2i:
	var win = get_window()
	var screen_idx = win.current_screen
	var screen_rect := DisplayServer.screen_get_usable_rect(screen_idx)
	if screen_rect.size.x <= 100 or screen_rect.size.y <= 100:
		var scr_size = DisplayServer.screen_get_size(screen_idx)
		if scr_size.x > 100:
			screen_rect = Rect2i(0, 0, scr_size.x, scr_size.y - 40)
		else:
			screen_rect = Rect2i(0, 0, 1920, 1040)
	return screen_rect

func get_floor_y() -> int:
	var rect = get_usable_screen_rect()
	var win = get_window()
	return rect.position.y + rect.size.y - win.size.y

func clamp_window_pos(pos: Vector2i) -> Vector2i:
	var rect = get_usable_screen_rect()
	var win = get_window()
	var min_x = rect.position.x
	var max_x = rect.position.x + rect.size.x - win.size.x
	var min_y = rect.position.y
	var max_y = get_floor_y()
	return Vector2i(
		clampi(pos.x, min_x, max_x),
		clampi(pos.y, min_y, max_y)
	)

func _ready() -> void:
	print(">>> MAIN _READY STARTED <<<")
	# Configure transparent borderless floating window
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(580, 720)
	DisplayServer.window_set_size(Vector2i(580, 720))
	win.transparent = true
	win.borderless = true
	win.always_on_top = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
	get_tree().root.transparent_bg = true

	# Set taskbar window icon if available
	if FileAccess.file_exists("res://assets/app_icon.png"):
		var icon_img = Image.load_from_file("res://assets/app_icon.png")
		if icon_img:
			DisplayServer.set_icon(icon_img)

	# Initialize UDP IPC server for system tray launcher
	udp_server = PacketPeerUDP.new()
	var udp_err = udp_server.bind(UDP_PORT, "127.0.0.1")
	if udp_err == OK:
		print(">>> System Tray IPC listening on 127.0.0.1:%d <<<" % UDP_PORT)

	# Idle optimization
	Engine.max_fps = 30
	OS.low_processor_usage_mode = true

	# Load saved memory statistics
	_load_stats()

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
	var screen_rect := get_usable_screen_rect()
	var px = screen_rect.position.x + screen_rect.size.x - win.size.x - 10
	var py = get_floor_y()
	win.position = clamp_window_pos(Vector2i(px, py))
	win.always_on_top = true
	win.show()
	DisplayServer.window_move_to_foreground()
	print(">>> Window positioned at: ", win.position, " size: ", win.size, " floor_y: ", py)

	# Connect Chat Input Signals
	input_box.text_submitted.connect(_on_input_submitted)
	send_btn.pressed.connect(func(): _on_input_submitted(input_box.text))

	# Connect Focus Widget Stop Button
	btn_stop_focus.pressed.connect(func(): _stop_focus_timer(false))

	# Connect 9 Pill Buttons
	btn_snack.pressed.connect(_on_btn_snack)
	btn_note.pressed.connect(_on_btn_note)
	btn_feelings.pressed.connect(_on_btn_feelings)
	btn_day.pressed.connect(_on_btn_day)
	btn_time.pressed.connect(_on_btn_time)
	btn_music.pressed.connect(_on_btn_music)
	btn_comfort.pressed.connect(_on_btn_comfort)
	btn_memory.pressed.connect(_on_btn_memory)
	btn_settings.pressed.connect(_on_btn_settings)

	# Connect Note Popup Buttons
	btn_save_note.pressed.connect(_save_note)
	btn_close_note.pressed.connect(func(): note_popup.visible = false; update_passthrough())

	# Connect Memory Popup Buttons
	btn_close_memory.pressed.connect(func(): memory_popup.visible = false; update_passthrough())

	# Connect Chat History Drawer Buttons
	chat_drawer_close.pressed.connect(func(): chat_drawer.visible = false; update_passthrough())
	chat_drawer_clear.pressed.connect(_on_chat_clear_pressed)
	chat_drawer_open_input.pressed.connect(func():
		input_container.visible = true
		input_box.grab_focus()
		update_passthrough()
	)

	# Connect Settings Panel Controls
	model_dropdown.clear()
	for i in range(model_list.size()):
		model_dropdown.add_item(model_list[i].name, i)
	model_dropdown.selected = current_model_idx
	model_dropdown.item_selected.connect(_on_model_selected)

	scale_dropdown.clear()
	scale_dropdown.add_item("100% (Standard)", 0)
	scale_dropdown.add_item("85% (Compact)", 1)
	scale_dropdown.add_item("118% (Large)", 2)
	scale_dropdown.selected = 0
	scale_dropdown.item_selected.connect(_on_scale_selected)

	btn_perch.pressed.connect(_toggle_perch)
	btn_gravity.pressed.connect(_toggle_gravity)
	btn_sound.pressed.connect(_toggle_sound)

	save_btn.pressed.connect(_on_settings_save)
	close_btn.pressed.connect(func(): settings_panel.visible = false; update_passthrough())
	close_x_btn.pressed.connect(func(): settings_panel.visible = false; update_passthrough())

	# Setup settings provider options
	provider_option.clear()
	provider_option.add_item("Custom OpenAI-Compatible API", 0)
	provider_option.add_item("Groq (Free & Fast Llama-3.3)", 1)
	provider_option.add_item("OpenRouter (Claude, Gemini, etc.)", 2)
	provider_option.add_item("OpenAI (GPT-4o, GPT-4o-mini)", 3)
	provider_option.add_item("DeepSeek (deepseek-chat)", 4)
	provider_option.add_item("Local / LM Studio (localhost:1234)", 5)
	provider_option.add_item("Built-in Standalone (No Key)", 6)
	provider_option.item_selected.connect(_on_provider_selected)

	btn_test_api.pressed.connect(_on_test_api_pressed)

	# Initialize procedural audio cache
	_init_sfx()

	ai_client.thinking_started.connect(_on_ai_thinking)
	ai_client.reply_received.connect(_on_ai_reply)
	ai_client.request_failed.connect(_on_ai_error)
	ai_client.test_completed.connect(_on_ai_test_completed)
	ai_client.subtitle_chunk_received.connect(_on_ai_subtitle)
	ai_client.tool_status_updated.connect(_on_ai_tool_status)
	ai_client.backend_connection_changed.connect(_on_backend_connection_changed)

	btn_authorize_tool.pressed.connect(_on_tool_authorized)
	btn_deny_tool.pressed.connect(_on_tool_denied)
	btn_close_confirm.pressed.connect(_on_tool_denied)

	if ai_client and ai_client.memory_mgr:
		ai_client.memory_mgr.affinity_leveled_up.connect(_on_affinity_leveled_up)

	_show_time_greeting()
	update_passthrough()
	print(">>> MAIN _READY COMPLETED <<<")

func _toggle_pill_menu() -> void:
	if pill_menu.visible:
		_close_pill_menu()
	else:
		_open_pill_menu()

func _open_pill_menu() -> void:
	# Hide secondary popups
	settings_panel.visible = false
	note_popup.visible = false
	memory_popup.visible = false
	chat_drawer.visible = false
	input_container.visible = false

	pill_menu.visible = true
	pill_menu.modulate.a = 0.0

	# Smooth staggered entrance cascade for pill buttons
	var vbox = pill_menu.get_node("VBox")
	var pills = vbox.get_children()
	for i in range(pills.size()):
		var pill: Control = pills[i]
		pill.position.x = 35.0
		pill.modulate.a = 0.0
		var delay = i * 0.022
		var tween = create_tween()
		tween.tween_interval(delay)
		tween.tween_property(pill, "position:x", 0.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		var alpha_tween = create_tween()
		alpha_tween.tween_interval(delay)
		alpha_tween.tween_property(pill, "modulate:a", 1.0, 0.12)

	var menu_tween = create_tween()
	menu_tween.tween_property(pill_menu, "modulate:a", 1.0, 0.15)

	play_sfx("chime")
	update_passthrough()

func _close_pill_menu() -> void:
	var tween = create_tween()
	tween.tween_property(pill_menu, "modulate:a", 0.0, 0.14)
	tween.tween_callback(func():
		pill_menu.visible = false
		pill_menu.modulate.a = 1.0
		update_passthrough()
	)

# ==============================================================================
# 9 Pill Action Handlers (Desktop Companion Original HUD)
# ==============================================================================
func _on_btn_snack() -> void:
	# Action 1: Chat & Converse (Opens dialogue log drawer + quick input)
	_close_pill_menu()
	chat_drawer.visible = true
	_refresh_chat_drawer()
	input_container.visible = true
	input_box.placeholder_text = "Talk to " + model_list[current_model_idx].short_name + " (Enter)..."
	input_box.grab_focus()
	play_sfx("chime")
	update_passthrough()

func _on_btn_note() -> void:
	# Action 2: Gentle Headpat
	_close_pill_menu()
	_trigger_headpat(Vector2(160, 200))

func _on_btn_feelings() -> void:
	# Action 3: Perch on Window
	_close_pill_menu()
	_toggle_perch()

func _on_btn_day() -> void:
	# Action 4: Focus Sprint (25m)
	_close_pill_menu()
	_toggle_focus_timer()

func _on_btn_time() -> void:
	# Action 5: Switch Wardrobe / Model
	_close_pill_menu()
	_cycle_next_model()

func _on_btn_music() -> void:
	# Action 6: Desktop Soundscape
	_close_pill_menu()
	play_sfx("cheer")
	heart_particles.position = Vector2(160, 240)
	heart_particles.restart()
	heart_particles.emitting = true
	var sound_quotes := [
		"Harmonic chimes activated! 🎵 Keeping the desktop vibe bright and cheerful!",
		"Soundtrack of the day! Music and good focus go hand in hand. ✨",
		"Soft melody playing! Let's make today productive and fun. (*^‿^*)"
	]
	say(sound_quotes.pick_random(), "happy")

func _on_btn_comfort() -> void:
	# Action 7: Gentle Care, Sweet Treats & Rest
	_close_pill_menu()
	play_sfx("sparkle")
	heart_particles.position = Vector2(160, 260)
	heart_particles.restart()
	heart_particles.emitting = true

	var treat_names := ["Strawberry Cake 🍰", "Boba Milk Tea 🧋", "Matcha Latte 🍵", "Sweet Macaron 🧁", "Warm Cocoa ☕"]
	var chosen_treat: String = treat_names.pick_random()

	if ai_client and ai_client.memory_mgr:
		var mm = ai_client.memory_mgr
		mm.total_treats_given += 1
		mm.mood_energy = 1.0
		mm.set_mood("affectionate")
		var leveled = mm.add_affinity(8, "Sweet treat shared")
		if not leveled:
			say("Aww, %s! Thank you so much! ( ˶ᵔ ᵕ ᵔ˶ ) ♡ You're so sweet to me!" % chosen_treat, "inlove")
	else:
		say("Thank you for the delicious treat! ( ˶ᵔ ᵕ ᵔ˶ ) ♡", "inlove")

func _on_btn_memory() -> void:
	# Action 8: Our Journey & Stats
	_close_pill_menu()
	_load_stats()
	var notes = _load_notes()
	lbl_pats.text = "💖 Headpats Shared: %d" % total_headpats
	lbl_focus.text = "⏱ Focus Time: %d minutes" % total_focus_minutes
	lbl_notes.text = "📝 Saved Notes in Memory: %d" % notes.size()
	lbl_model.text = "🌸 Current Companion: %s" % model_list[current_model_idx].short_name

	if ai_client and ai_client.memory_mgr:
		var mm = ai_client.memory_mgr
		lbl_affinity.text = "💖 Bond: Lv.%d %s (%d XP)" % [mm.affinity_level, mm.affinity_title, mm.affinity_xp]
		lbl_mood.text = "✨ Mood: %s (Streak %d days)" % [mm.current_mood.capitalize(), mm.daily_streak]
		if mm.user_facts.size() > 0:
			lbl_facts.text = "🧠 Remembered: " + ", ".join(mm.user_facts)
		else:
			lbl_facts.text = "🧠 Remembered: Getting to know you better with each chat!"
	memory_popup.visible = true
	play_sfx("sparkle")
	update_passthrough()

func _on_btn_settings() -> void:
	# Action 9: Companion Settings
	_close_pill_menu()
	settings_panel.visible = true
	_update_settings_ui()
	play_sfx("chime")
	update_passthrough()

# ==============================================================================
# Persistent Notes & Memories
# ==============================================================================
func _save_note() -> void:
	var text = note_edit.text.strip_edges()
	if text.is_empty():
		return
	var notes = _load_notes()
	notes.append({
		"time": Time.get_datetime_string_from_system(),
		"text": text
	})
	var f = FileAccess.open("user://notes.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(notes))
		f.close()
	note_edit.clear()
	note_popup.visible = false
	say("I saved your note to our memories! ♡", "happy")
	play_sfx("chime")
	update_passthrough()

func _load_notes() -> Array:
	if not FileAccess.file_exists("user://notes.json"):
		return []
	var f = FileAccess.open("user://notes.json", FileAccess.READ)
	if not f: return []
	var json = JSON.new()
	var err = json.parse(f.get_as_text())
	f.close()
	if err == OK and json.data is Array:
		return json.data
	return []

func _load_stats() -> void:
	if FileAccess.file_exists("user://stats.json"):
		var f = FileAccess.open("user://stats.json", FileAccess.READ)
		if f:
			var json = JSON.new()
			if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
				total_headpats = json.data.get("headpats", 0)
				total_focus_minutes = json.data.get("focus_minutes", 0)
			f.close()

func _save_stats() -> void:
	var f = FileAccess.open("user://stats.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"headpats": total_headpats,
			"focus_minutes": total_focus_minutes
		}))
		f.close()

# ==============================================================================
# Core Companion Features (Gravity, Perch, Sound, Focus Timer)
# ==============================================================================
func _toggle_gravity() -> void:
	gravity_enabled = not gravity_enabled
	var label_text = "🌍 Gravity Drop: ON" if gravity_enabled else "🪶 Floating Mode: ON"
	btn_gravity.text = label_text
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
	update_passthrough()

func _toggle_perch() -> void:
	perch_enabled = not perch_enabled
	var label_text = "🪟 Window Perch: ON" if perch_enabled else "🪟 Window Perch: OFF"
	btn_perch.text = label_text
	if not perch_enabled:
		if is_perching:
			is_perching = false
			window_topology_active = false
			if gravity_enabled:
				is_falling = true
				fall_velocity = 0.0
		say("Window perching OFF. Resting on taskbar!", "neutral")
	else:
		say("Window perching ON! I'll hop onto your active windows.", "happy")
		play_sfx("sparkle")
	update_passthrough()

func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	btn_sound.text = "🔊 Sound: ON" if sound_enabled else "🔇 Sound: OFF"
	say("Sound effects " + ("ON" if sound_enabled else "OFF") + "!", "neutral")
	if sound_enabled: play_sfx("chime")

func _toggle_focus_timer() -> void:
	if focus_active:
		var mins_left = int(focus_time_left / 60.0)
		say("Focus timer is currently active! %d minutes remaining. Keep going!" % mins_left, "happy")
	else:
		focus_active = true
		focus_time_left = 1500.0 # 25 minutes
		focus_widget.visible = true
		_update_focus_label()
		say("Focus mode started! ⏱ 25 minutes on the clock. Put distractions away, I'll quietly cheer for you! ✨", "happy")
		play_sfx("cheer")
	update_passthrough()

func _stop_focus_timer(completed: bool) -> void:
	focus_active = false
	focus_widget.visible = false
	if completed:
		total_focus_minutes += 25
		_save_stats()
		say("Ding ding ding! 🎉 25 minutes completed! You did fantastic! Take a well-deserved 5 minute break.", "happy")
		play_sfx("cheer")
		sparkle_particles.position = Vector2(160, 480)
		sparkle_particles.restart()
		sparkle_particles.emitting = true
	else:
		say("Focus timer stopped. We can always start another session whenever you're ready!", "neutral")
	update_passthrough()

func _update_focus_label() -> void:
	var mins = int(focus_time_left) / 60
	var secs = int(focus_time_left) % 60
	focus_label.text = "⏱ %02d:%02d" % [mins, secs]

func _toggle_chat_input() -> void:
	_close_pill_menu()
	input_container.visible = not input_container.visible
	if input_container.visible:
		input_box.grab_focus()
	update_passthrough()

func _handle_perch_packet(pkt: String) -> void:
	var parts = pkt.split(":", true, 3)
	if parts.size() < 2: return

	var data = parts[1]
	if data == "NONE":
		if is_perching:
			is_perching = false
			window_topology_active = false
			tracked_app_name = ""
			tracked_app_title = ""
			if gravity_enabled:
				is_falling = true
				fall_velocity = 0.0
			say("Whoosh! Window minimized, dropping down!", "surprised")
			play_sfx("sparkle")
		return

	if not perch_enabled or dragging:
		return

	var coords = data.split(",")
	if coords.size() != 4: return
	var wx = int(coords[0])
	var wy = int(coords[1])
	var ww = int(coords[2])
	var wh = int(coords[3])

	var screen_rect := get_usable_screen_rect()

	# If the target window is maximized or covers almost the full screen height, do not try to climb above the monitor!
	if wh >= screen_rect.size.y - 120 and wy <= 30:
		return

	var target_y = wy - 680
	var target_x = wx + ww - 380
	if ww < 450:
		target_x = wx + int((ww - 580) * 0.5)

	target_perch_pos = Vector2(clamp_window_pos(Vector2i(target_x, target_y)))
	window_topology_active = true

	var proc_name = parts[2] if parts.size() > 2 else ""
	var win_title = parts[3] if parts.size() > 3 else ""

	if not is_perching:
		is_perching = true
		is_falling = false
		fall_velocity = 0.0
		_trigger_perch_hop(target_perch_pos)
	else:
		var curr_pos = Vector2(get_window().position)
		if curr_pos.distance_to(target_perch_pos) > 1.5:
			get_window().position = clamp_window_pos(Vector2i(curr_pos.lerp(target_perch_pos, 0.45)))

	if proc_name != tracked_app_name:
		_on_active_window_changed(proc_name, win_title)

func _trigger_perch_hop(target_pos: Vector2) -> void:
	play_sfx("chime")
	var curr_win = get_window()
	var start_pos = Vector2(curr_win.position)

	var hop_tween = create_tween().set_parallel(false)
	var peak_y = int(min(start_pos.y, target_pos.y) - 35.0)

	hop_tween.tween_property(curr_win, "position:y", peak_y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop_tween.tween_property(curr_win, "position:y", int(target_pos.y), 0.20).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	var hop_x_tween = create_tween()
	hop_x_tween.tween_property(curr_win, "position:x", int(target_pos.x), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	sparkle_particles.position = Vector2(160, 500)
	sparkle_particles.restart()

func _on_active_window_changed(proc_name: String, win_title: String) -> void:
	tracked_app_name = proc_name
	tracked_app_title = win_title

	if anim_time - last_app_comment_time < 35.0:
		return
	last_app_comment_time = anim_time

	var p = proc_name.to_lower()
	var t = win_title.to_lower()

	if not ai_client.api_key.is_empty():
		ai_client.send_message("The user just switched to application '%s' with window title '%s'. Give a brief, sweet, 1-sentence ambient micro-reaction." % [proc_name, win_title])
		return

	var comment := ""
	var expression := "happy"

	if "code" in p or "devenv" in p or "idea" in p or "godot" in p or "pycharm" in p:
		var code_quotes = [
			"Coding mode! Let's build something clean and robust today.",
			"Deep in the flow state. Remember to commit often!",
			"Refactoring time? Take your time, you got this!"
		]
		comment = code_quotes[randi() % code_quotes.size()]
	elif "spotify" in p or "music" in p or "itunes" in p:
		comment = "Good soundtrack choice! Music always helps the groove."
	elif "chrome" in p or "firefox" in p or "edge" in p or "brave" in p:
		if "github" in t:
			comment = "Checking GitHub! Hope all your CI checks are passing green."
		elif "youtube" in t:
			comment = "A little video break? Enjoy your watch!"
		elif "stackoverflow" in t or "docs" in t:
			comment = "Researching docs? Hope you find the exact solution!"
		else:
			comment = "Browsing around? Don't forget your posture!"
		expression = "neutral"
	elif "discord" in p or "telegram" in p or "slack" in p:
		comment = "Connecting with friends? Say hi for me!"
	elif "steam" in p or "game" in t or "valorant" in p or "genshin" in p:
		comment = "Game time! Have fun and go get that win!"
		expression = "surprised"
	elif "wt" in p or "powershell" in p or "cmd" in p:
		comment = "Terminal warrior! Command line magic at your fingertips."
		expression = "neutral"

	var time_dict = Time.get_time_dict_from_system()
	if time_dict.hour >= 23 or time_dict.hour < 5:
		comment = "It's past midnight... please don't stay up too late, okay?"
		expression = "shy"

	if not comment.is_empty():
		say(comment, expression)
		play_sfx("chime")

func _reset_to_default_position() -> void:
	var win = get_window()
	var screen_rect := get_usable_screen_rect()
	var px = screen_rect.position.x + screen_rect.size.x - win.size.x - 10
	var py = get_floor_y()
	win.position = clamp_window_pos(Vector2i(px, py))
	win.show()
	win.always_on_top = true
	is_falling = false
	is_perching = false
	fall_velocity = 0.0
	toss_velocity_x = 0.0
	say("I'm right here! ✦ Ready to hang out.", "happy")
	play_sfx("chime")
	sparkle_particles.position = Vector2(160, 500)
	sparkle_particles.restart()

func _show_and_focus() -> void:
	var win = get_window()
	win.position = clamp_window_pos(win.position)
	win.show()
	win.always_on_top = true
	say("I'm right here! (Double-click me for actions)", "happy")
	play_sfx("sparkle")
	sparkle_particles.position = Vector2(160, 500)
	sparkle_particles.restart()

func update_passthrough() -> void:
	if pill_menu.visible or settings_panel.visible or note_popup.visible or memory_popup.visible or input_container.visible or focus_widget.visible or chat_drawer.visible:
		get_window().mouse_passthrough_polygon = PackedVector2Array()
		return

	# Passthrough polygon tightly framing companion silhouette in 580x720 window
	var poly := PackedVector2Array([
		Vector2(20, 20),
		Vector2(300, 20),
		Vector2(300, 150),
		Vector2(290, 480),
		Vector2(240, 712),
		Vector2(60, 712),
		Vector2(25, 480),
		Vector2(20, 150)
	])
	get_window().mouse_passthrough_polygon = poly

# ==============================================================================
# Main Process Loop
# ==============================================================================
func _process(delta: float) -> void:
	anim_time += delta

	# Poll System Tray IPC commands from DesktopCompanion.exe launcher
	if udp_server and udp_server.get_available_packet_count() > 0:
		var pkt = udp_server.get_packet().get_string_from_utf8().strip_edges()
		if pkt.begins_with("PERCH:"):
			_handle_perch_packet(pkt)
		else:
			match pkt:
				"HEADPAT":
					_trigger_headpat()
				"TOGGLE_MENU":
					_toggle_pill_menu()
				"OPEN_MENU":
					_open_pill_menu()
				"CLOSE_MENU":
					_close_pill_menu()
				"OPEN_SETTINGS":
					_on_btn_settings()
				"TOGGLE_PERCH":
					_toggle_perch()
				"NEXT_MODEL":
					_cycle_next_model()
				"TOGGLE_CHAT":
					_toggle_chat_input()
				"TOGGLE_GRAVITY":
					_toggle_gravity()
				"TOGGLE_FOCUS":
					_toggle_focus_timer()
				"TOGGLE_SOUND":
					_toggle_sound()
				"RESET_POSITION":
					_reset_to_default_position()
				"SHOW_WINDOW":
					_show_and_focus()
				"HIDE_WINDOW":
					get_window().hide()
				"TOGGLE_WINDOW":
					if get_window().visible:
						get_window().hide()
					else:
						_show_and_focus()
				"QUIT":
					get_tree().quit()

	# Focus Timer countdown
	if focus_active:
		focus_time_left -= delta
		_update_focus_label()
		if focus_time_left <= 0.0:
			_stop_focus_timer(true)

	# Periodic Ergonomic & Hydration Reminder
	hydration_timer -= delta
	if hydration_timer <= 0.0:
		hydration_timer = 2700.0
		say("Friendly check-in! 💧 Have you taken a sip of water or stretched recently? Let's take a quick 1-minute break!", "happy")
		play_sfx("chime")

	# Autonomous Ambient Proactive Behavior Loop
	ambient_timer -= delta
	if ambient_timer <= 0.0:
		ambient_timer = randf_range(80.0, 140.0)
		_trigger_ambient_behavior()

	# Track mouse drag velocity for toss throw inertia
	if dragging:
		var curr_mouse = DisplayServer.mouse_get_position()
		if prev_mouse_pos != Vector2i.ZERO and delta > 0.001:
			var instant_vel = Vector2(curr_mouse - prev_mouse_pos) / delta
			drag_velocity = drag_velocity.lerp(instant_vel, delta * 12.0)
		prev_mouse_pos = curr_mouse

		# Shake detection for dizzy reaction
		if abs(drag_velocity.x) > 850.0 and (drag_velocity.x * prev_drag_vel_x < -20000.0):
			shake_energy += delta * 5.0
		else:
			shake_energy = max(0.0, shake_energy - delta * 1.5)
		prev_drag_vel_x = drag_velocity.x

		if shake_energy >= 2.0 and not is_dizzy:
			is_dizzy = true
			dizzy_timer = 3.2
			shake_energy = 0.0
			say("Whoaaa! Stop shaking me, my head is spinning! (@_@)", "surprised")
			play_sfx("sparkle")
	else:
		prev_mouse_pos = Vector2i.ZERO
		shake_energy = max(0.0, shake_energy - delta * 2.5)
		prev_drag_vel_x = 0.0

	# Gravity & Dropping down with toss horizontal momentum
	if gravity_enabled and is_falling and not dragging:
		var floor_y = get_floor_y()
		fall_velocity = min(fall_velocity + GRAVITY * delta, MAX_FALL_SPEED)

		if abs(toss_velocity_x) > 5.0:
			var next_x = get_window().position.x + int(toss_velocity_x * delta)
			var rect = get_usable_screen_rect()
			get_window().position.x = clampi(next_x, rect.position.x, rect.position.x + rect.size.x - get_window().size.x)
			toss_velocity_x = lerp(toss_velocity_x, 0.0, delta * 5.0)

		var next_y = get_window().position.y + int(fall_velocity * delta)
		if next_y >= floor_y:
			get_window().position.y = floor_y
			is_falling = false
			fall_velocity = 0.0
			toss_velocity_x = 0.0
			get_window().position = clamp_window_pos(get_window().position)
			if is_lifted:
				is_lifted = false
				say("Phew! Back on solid ground.", "neutral")
			_trigger_landing_bounce()
		else:
			get_window().position.y = next_y
			get_window().position = clamp_window_pos(get_window().position)

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
	var char_global_center = get_window().position + Vector2i(160, 360)

	# Reze (3D Model Active)
	if model_list[current_model_idx].type == "3d":
		if reze_3d:
			if not dragging:
				reze_3d.update_gaze_target(Vector2(mouse_global), Vector2(char_global_center))
			reze_3d.set_speaking(is_speaking)
	else:
		# Live2D Model Active
		if is_dizzy:
			dizzy_timer -= delta
			var swirl_x = cos(anim_time * 12.0) * 0.95
			var swirl_y = sin(anim_time * 12.0) * 0.95
			_set_param_direct("ParamEyeBallX", swirl_x)
			_set_param_direct("ParamEyeBallY", swirl_y)
			_set_param_direct("ParamAngleZ", sin(anim_time * 8.0) * 16.0)
			_set_param_direct("ParamBodyAngleX", -sin(anim_time * 8.0) * 8.0)
			_set_param_direct("ParamCheekPuff", 0.7)
			if dizzy_timer <= 0.0:
				is_dizzy = false
				say("Phew... the room finally stopped spinning!", "happy")
		elif is_headpatting:
			headpat_timer -= delta
			headpat_stroke_time += delta

			var stroke_cycle = sin(headpat_stroke_time * 7.0)
			_set_param("ParamAngleZ", stroke_cycle * 9.0 + 3.0, delta * 8.0)
			_set_param("ParamAngleY", -10.0 + stroke_cycle * 2.5, delta * 8.0)
			_set_param("ParamBodyAngleX", stroke_cycle * 5.0, delta * 6.0)

			_set_param_direct("ParamEyeLOpen", 0.0)
			_set_param_direct("ParamEyeROpen", 0.0)
			_set_param_direct("ParamEyeLSmile", 1.0)
			_set_param_direct("ParamEyeRSmile", 1.0)
			_set_param_direct("ParamCheekPuff", 1.0)
			_set_param_direct("ParamMouthForm", 1.0)
			_set_param_direct("ParamMouthOpenY", 0.25)

			if headpat_timer <= 0.0:
				is_headpatting = false
				_set_param_direct("ParamEyeLOpen", 1.0)
				_set_param_direct("ParamEyeROpen", 1.0)
				_set_param_direct("ParamEyeLSmile", 0.0)
				_set_param_direct("ParamEyeRSmile", 0.0)
				_set_param_direct("ParamCheekPuff", 0.0)
		elif not dragging:
			var diff = Vector2(mouse_global - char_global_center)
			var target_x = clamp(diff.x / 440.0, -1.0, 1.0)
			var target_y = clamp(-diff.y / 440.0, -1.0, 1.0)

			var dist_to_cursor = diff.length()
			var curiosity = clamp(1.0 - (dist_to_cursor / 180.0), 0.0, 1.0)

			var idle_sway_z = sin(anim_time * 1.4) * 3.0
			var idle_sway_body = sin(anim_time * 1.1) * 2.5

			idle_action_timer -= delta
			if idle_action_timer <= 0.0:
				idle_action_timer = randf_range(12.0, 18.0)
				idle_glance_offset = randf_range(-0.5, 0.5)
				get_tree().create_timer(1.2).timeout.connect(func(): idle_glance_offset = 0.0)

			_set_param("ParamAngleX", (target_x + idle_glance_offset * 0.4) * 30.0, delta * 6.0)
			_set_param("ParamAngleY", target_y * 26.0, delta * 6.0)
			_set_param("ParamAngleZ", -target_x * 8.0 + idle_sway_z, delta * 5.0)
			_set_param("ParamEyeBallX", target_x + idle_glance_offset, delta * 8.0)
			_set_param("ParamEyeBallY", target_y, delta * 8.0)
			_set_param("ParamBodyAngleX", target_x * 10.0 + idle_sway_body, delta * 4.0)
			if curiosity > 0.05:
				_set_param("ParamEyeLOpen", 1.0 + curiosity * 0.1, delta * 6.0)
				_set_param("ParamEyeROpen", 1.0 + curiosity * 0.1, delta * 6.0)
		else:
			var tilt_z = clamp(-drag_velocity.x * 0.03, -16.0, 16.0)
			_set_param("ParamAngleZ", tilt_z, delta * 8.0)
			_set_param("ParamBodyAngleX", tilt_z * 0.5, delta * 6.0)
			_set_param("ParamEyeLOpen", 1.1, delta * 10.0)
			_set_param("ParamEyeROpen", 1.1, delta * 10.0)

		# Live2D Breathing
		var breath_val = (sin(anim_time * 2.2) + 1.0) * 0.5
		_set_param_direct("ParamBreath", breath_val)

		# Live2D Natural Blinking
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

# ==============================================================================
# Mouse & Keyboard Event Dispatching
# ==============================================================================
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if pill_menu.visible:
				_close_pill_menu()
				return
			if settings_panel.visible:
				settings_panel.visible = false
				update_passthrough()
				return
			if note_popup.visible:
				note_popup.visible = false
				update_passthrough()
				return
			if memory_popup.visible:
				memory_popup.visible = false
				update_passthrough()
				return
			if chat_drawer.visible:
				chat_drawer.visible = false
				update_passthrough()
				return
			if input_container.visible:
				input_container.visible = false
				update_passthrough()
				return
			return
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
		if pill_menu.visible and pill_menu.get_global_rect().has_point(event.position): return
		if settings_panel.visible and settings_panel.get_global_rect().has_point(event.position): return
		if note_popup.visible and note_popup.get_global_rect().has_point(event.position): return
		if memory_popup.visible and memory_popup.get_global_rect().has_point(event.position): return
		if focus_widget.visible and focus_widget.get_global_rect().has_point(event.position): return

		# RIGHT-CLICK: Toggle Pill Menu
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_toggle_pill_menu()
			return

		# LEFT-CLICK: Dragging, Double-click (Toggle Pill Menu), or Hitbox Interactions
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.double_click:
					# Double-click companion to toggle the 9-pill action menu!
					_toggle_pill_menu()
					dragging = false
					return
				dragging = true
				is_falling = false
				is_perching = false
				fall_velocity = 0.0
				toss_velocity_x = 0.0
				is_lifted = false
				drag_start_mouse_pos = DisplayServer.mouse_get_position()
				drag_offset = DisplayServer.mouse_get_position() - get_window().position
				prev_mouse_pos = DisplayServer.mouse_get_position()
				drag_velocity = Vector2.ZERO
				if pill_menu.visible:
					_close_pill_menu()
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
							get_window().position = clamp_window_pos(get_window().position)
							if is_lifted:
								is_lifted = false
								say("Phew! Thanks for putting me down.", "neutral")
								if gravity_enabled:
									_trigger_landing_bounce()

	elif event is InputEventMouseMotion and dragging:
		var moved_dist = (DisplayServer.mouse_get_position() - drag_start_mouse_pos).length()
		if moved_dist > 8:
			if pill_menu.visible:
				_close_pill_menu()
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
			get_window().position = clamp_window_pos(target_pos)

func _trigger_landing_bounce() -> void:
	var base_scale: Vector2 = model_list[current_model_idx].scale if model_list[current_model_idx].type == "live2d" else Vector2.ONE
	var target_node = live2d_model if model_list[current_model_idx].type == "live2d" else reze_container
	var tween = create_tween()
	tween.tween_property(target_node, "scale", Vector2(base_scale.x * 1.08, base_scale.y * 0.92), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(target_node, "scale", Vector2(base_scale.x * 0.97, base_scale.y * 1.03), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(target_node, "scale", base_scale, 0.1).set_trans(Tween.TRANS_SINE)

	if sparkle_particles:
		sparkle_particles.position = Vector2(160, 680)
		sparkle_particles.restart()
		sparkle_particles.emitting = true

func _handle_character_tap(click_pos: Vector2) -> void:
	play_sfx("pop")
	if click_pos.y < 280:
		# Head zone: Dedicated headpat sequence!
		_trigger_headpat(click_pos)
		return
	elif click_pos.y < 500:
		# Torso zone: Playful poke
		sparkle_particles.position = click_pos
		sparkle_particles.restart()
		sparkle_particles.emitting = true
		_set_param_direct("ParamCheekPuff", 0.3)
		var torso_lines := [
			"H-hey! That tickles! (≧▽≦)",
			"Wah! You surprised me!",
			"Double-click me to see what we can do together! ✨",
			"Need something or just keeping me company? ♡"
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

func _trigger_headpat(contact_pos: Vector2 = Vector2(160, 200)) -> void:
	is_headpatting = true
	headpat_timer = 2.4
	headpat_stroke_time = 0.0

	total_headpats += 1
	_save_stats()

	if ai_client and ai_client.memory_mgr:
		ai_client.memory_mgr.total_headpats += 1
		ai_client.memory_mgr.add_affinity(3, "Gentle headpat")
		if ai_client.memory_mgr.current_mood != "affectionate":
			ai_client.memory_mgr.set_mood("playful")

	heart_particles.position = contact_pos
	heart_particles.restart()
	heart_particles.emitting = true

	play_sfx("chime")

	# Affectionate squish-spring reaction under petting hand
	var base_scale: Vector2 = model_list[current_model_idx].scale if model_list[current_model_idx].type == "live2d" else Vector2.ONE
	var target_node = live2d_model if model_list[current_model_idx].type == "live2d" else reze_container
	var pat_tween = create_tween()
	pat_tween.tween_property(target_node, "scale", Vector2(base_scale.x * 1.05, base_scale.y * 0.94), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pat_tween.tween_property(target_node, "scale", base_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var pat_lines := [
		"Ehehe~ ♡ (≧◡≦) Your headpats are the best!",
		"Mmm... don't stop, that feels so soothing~ ♡",
		"Hehe, patting my head again? I love it! ♡",
		"Pats accepted! (★ω★) My energy is fully recharged! ✨"
	]
	say(pat_lines.pick_random(), "happy")

func _cycle_next_model() -> void:
	var next_idx = (current_model_idx + 1) % model_list.size()
	_on_model_selected(next_idx)

func _on_model_selected(idx: int) -> void:
	if idx < 0 or idx >= model_list.size(): return
	current_model_idx = idx
	model_dropdown.selected = current_model_idx
	var info = model_list[current_model_idx]

	if info.type == "3d":
		reze_container.visible = true
		live2d_model.visible = false
	else:
		reze_container.visible = false
		live2d_model.visible = true
		live2d_model.assets = info.path
		live2d_model.scale = info.scale * current_scale_multiplier
		live2d_model.position = info.pos

		param_map.clear()
		for p in live2d_model.get_parameters():
			param_map[p.id] = p

	if sparkle_particles:
		sparkle_particles.position = Vector2(160, 500)
		sparkle_particles.restart()
		sparkle_particles.emitting = true

	if ai_client:
		ai_client.set_companion_name(info.name)

	say("Switched to " + info.name + "!", "neutral")
	play_sfx("sparkle")
	update_passthrough()

func _on_scale_selected(idx: int) -> void:
	match idx:
		0: current_scale_multiplier = 1.0
		1: current_scale_multiplier = 0.85
		2: current_scale_multiplier = 1.18

	var info = model_list[current_model_idx]
	if info.type == "live2d":
		live2d_model.scale = info.scale * current_scale_multiplier
	say("Scale adjusted to " + scale_dropdown.get_item_text(idx) + "!", "neutral")
	play_sfx("chime")

func _show_time_greeting() -> void:
	var hour: int = Time.get_time_dict_from_system().hour
	if hour >= 23 or hour < 5:
		say("It's late at night... shouldn't you be asleep? Don't strain your eyes! ( ᴗ˳ᴗ)", "neutral")
	elif hour >= 5 and hour < 12:
		say("Good morning! Let's get things done today! Double-click me anytime. ✦", "neutral")
	elif hour >= 12 and hour < 18:
		say("Good afternoon! Working hard? Don't forget to stay hydrated!", "neutral")
	else:
		say("Good evening! Unwinding or still busy? I'm right here with you.", "neutral")

func say(text: String, _expression: String = "neutral") -> void:
	full_target_text = text
	displayed_char_progress = 0.0
	is_typing = true

	speaker_badge.text = " ✦ " + model_list[current_model_idx].short_name + " "

	bubble_label.text = ""
	bubble_panel.visible = true
	bubble_panel.modulate.a = 0.0

	bubble_container.scale = Vector2(0.92, 0.92)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(bubble_panel, "modulate:a", 1.0, 0.16)
	tween.tween_property(bubble_container, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	bubble_hide_timer = max(5.0, text.length() * 0.09)
	is_speaking = true
	talk_anim_timer = min(2.5, max(1.2, text.length() * 0.04))
	_apply_companion_expression(_expression)
	update_passthrough()

func _apply_companion_expression(expr: String) -> void:
	if current_model_idx < model_list.size() and model_list[current_model_idx].type == "3d":
		if reze_3d and reze_3d.mesh:
			match expr:
				"happy", "inlove":
					if reze_3d.smile_shape_idx != -1: reze_3d.mesh.set_blend_shape_value(reze_3d.smile_shape_idx, 0.65)
					if reze_3d.blush_shape_idx != -1: reze_3d.mesh.set_blend_shape_value(reze_3d.blush_shape_idx, 0.5)
				"sad", "confused":
					if reze_3d.smile_shape_idx != -1: reze_3d.mesh.set_blend_shape_value(reze_3d.smile_shape_idx, 0.0)
					if reze_3d.blush_shape_idx != -1: reze_3d.mesh.set_blend_shape_value(reze_3d.blush_shape_idx, 0.1)
				"think":
					if reze_3d.smile_shape_idx != -1: reze_3d.mesh.set_blend_shape_value(reze_3d.smile_shape_idx, 0.1)
				_:
					if reze_3d.smile_shape_idx != -1: reze_3d.mesh.set_blend_shape_value(reze_3d.smile_shape_idx, 0.15)
					if reze_3d.blush_shape_idx != -1: reze_3d.mesh.set_blend_shape_value(reze_3d.blush_shape_idx, 0.35)
	elif live2d_model and live2d_model.has_method("set_expression"):
		live2d_model.set_expression(expr)

func _on_input_submitted(text: String) -> void:
	var clean := text.strip_edges()
	if clean.is_empty(): return
	input_box.clear()
	input_container.visible = false
	update_passthrough()
	ai_client.send_message(clean)
	if chat_drawer.visible:
		_refresh_chat_drawer()

func _on_ai_thinking() -> void:
	tool_chip.visible = false
	say("Thinking...", "think")

func _on_ai_subtitle(subtitle: String, expression: String) -> void:
	say(subtitle, expression)
	if chat_drawer.visible:
		_refresh_chat_drawer()

func _on_ai_reply(reply: String, expression: String) -> void:
	tool_chip.visible = false
	say(reply, expression)
	if chat_drawer.visible:
		_refresh_chat_drawer()

func _on_ai_error(err_msg: String) -> void:
	tool_chip.visible = false
	say(err_msg, "sad")

func _on_ai_tool_status(tool_id: String, tool_name: String, status: String, arguments: Dictionary) -> void:
	var lower_name = tool_name.to_lower()
	var is_read_only = ("search" in lower_name or "time" in lower_name or "read" in lower_name or "fetch" in lower_name or "status" in lower_name)

	if is_read_only:
		tool_chip.visible = true
		var query_summary = ""
		if arguments.has("query"):
			query_summary = " \"%s\"" % str(arguments["query"]).substr(0, 25)
		elif arguments.has("text"):
			query_summary = " \"%s\"" % str(arguments["text"]).substr(0, 25)
		tool_chip_label.text = "🔍 %s%s..." % [tool_name.capitalize(), query_summary]
		say("Checking %s for you..." % tool_name.capitalize(), "think")
	else:
		pending_tool_id = tool_id
		tool_confirm_modal.visible = true
		tool_name_lbl.text = "Tool: %s (Authorization Required)" % tool_name
		var cmd_text = JSON.stringify(arguments, "  ")
		if arguments.has("command"):
			cmd_text = str(arguments["command"])
		command_text_lbl.text = cmd_text
		update_passthrough()
		say("⚠️ Security Authorization Required to execute %s." % tool_name, "surprised")

func _on_tool_authorized() -> void:
	tool_confirm_modal.visible = false
	update_passthrough()
	tool_chip.visible = true
	tool_chip_label.text = "⚙️ Executing Authorized Tool..."
	say("Authorized! Executing command now.", "happy")
	if ai_client.is_ws_connected:
		var resp = {
			"type": "tool_confirmation_response",
			"tool_id": pending_tool_id,
			"allowed": true
		}
		ai_client.ws_peer.send_text(JSON.stringify(resp))
	pending_tool_id = ""

func _on_tool_denied() -> void:
	tool_confirm_modal.visible = false
	update_passthrough()
	tool_chip.visible = false
	say("Action cancelled. Safety first! ♡", "neutral")
	if ai_client.is_ws_connected:
		var resp = {
			"type": "tool_confirmation_response",
			"tool_id": pending_tool_id,
			"allowed": false
		}
		ai_client.ws_peer.send_text(JSON.stringify(resp))
	pending_tool_id = ""

func _on_backend_connection_changed(connected: bool) -> void:
	is_backend_connected = connected
	if connected:
		speaker_badge.text = " ✦ %s " % model_list[current_model_idx].short_name
		speaker_badge.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		tool_chip.visible = false
	else:
		speaker_badge.text = " ✦ %s (Offline) " % model_list[current_model_idx].short_name
		speaker_badge.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8))
		say("AI engine disconnected. Reconnecting in background... I'm still right here with you! ♡", "confused")

func _update_settings_ui() -> void:
	api_key_input.text = ai_client.api_key
	endpoint_input.text = ai_client.base_url
	model_name_input.text = ai_client.model_name
	test_status_lbl.text = "Ready to test"
	test_status_lbl.modulate = Color(0.4, 0.45, 0.55)

	match ai_client.provider:
		"custom": provider_option.selected = 0
		"groq": provider_option.selected = 1
		"openrouter": provider_option.selected = 2
		"openai": provider_option.selected = 3
		"deepseek": provider_option.selected = 4
		"local": provider_option.selected = 5
		"builtin": provider_option.selected = 6
		_:
			provider_option.selected = 0

func _on_provider_selected(idx: int) -> void:
	match idx:
		0: # Custom OpenAI-Compatible
			if endpoint_input.text.strip_edges().is_empty():
				endpoint_input.text = "https://api.openai.com/v1/chat/completions"
			if model_name_input.text.strip_edges().is_empty():
				model_name_input.text = "gpt-4o-mini"
		1: # Groq
			endpoint_input.text = "https://api.groq.com/openai/v1/chat/completions"
			model_name_input.text = "llama-3.3-70b-versatile"
		2: # OpenRouter
			endpoint_input.text = "https://openrouter.ai/api/v1/chat/completions"
			model_name_input.text = "anthropic/claude-3.5-sonnet"
		3: # OpenAI
			endpoint_input.text = "https://api.openai.com/v1/chat/completions"
			model_name_input.text = "gpt-4o-mini"
		4: # DeepSeek
			endpoint_input.text = "https://api.deepseek.com/chat/completions"
			model_name_input.text = "deepseek-chat"
		5: # Local / LM Studio
			endpoint_input.text = "http://localhost:1234/v1/chat/completions"
			model_name_input.text = "local-model"
		6: # Built-in Standalone
			endpoint_input.text = ""
			model_name_input.text = ""
			api_key_input.text = ""

func _on_test_api_pressed() -> void:
	test_status_lbl.text = "⚡ Testing..."
	test_status_lbl.modulate = Color(0.95, 0.75, 0.2)
	btn_test_api.disabled = true
	var endpoint = endpoint_input.text.strip_edges()
	var model = model_name_input.text.strip_edges()
	var key = api_key_input.text.strip_edges()
	ai_client.test_api_connection(endpoint, model, key)

func _on_ai_test_completed(success: bool, message: String) -> void:
	btn_test_api.disabled = false
	if success:
		test_status_lbl.text = "✓ " + message
		test_status_lbl.modulate = Color(0.18, 0.8, 0.44)
		play_sfx("sparkle")
	else:
		test_status_lbl.text = "✕ " + message
		test_status_lbl.modulate = Color(0.9, 0.25, 0.25)
		play_sfx("pop")

func _on_settings_save() -> void:
	ai_client.api_key = api_key_input.text.strip_edges()
	ai_client.base_url = endpoint_input.text.strip_edges()
	ai_client.model_name = model_name_input.text.strip_edges()
	match provider_option.selected:
		0: ai_client.provider = "custom"
		1: ai_client.provider = "groq"
		2: ai_client.provider = "openrouter"
		3: ai_client.provider = "openai"
		4: ai_client.provider = "deepseek"
		5: ai_client.provider = "local"
		6: ai_client.provider = "builtin"
		_: ai_client.provider = "custom"
	ai_client.save_config()
	settings_panel.visible = false
	say("Settings saved! Ready to chat with your chosen AI.", "neutral")
	play_sfx("chime")
	update_passthrough()

# ==============================================================================
# Chat Log Drawer & Memory Rendering
# ==============================================================================
func _refresh_chat_drawer() -> void:
	if not ai_client or not ai_client.memory_mgr:
		return
	var mm = ai_client.memory_mgr
	chat_drawer_affinity.text = "💖 Lv.%d %s • Mood: %s • Streak %d days" % [mm.affinity_level, mm.affinity_title, mm.current_mood.capitalize(), mm.daily_streak]

	for c in chat_drawer_list.get_children():
		c.queue_free()

	if mm.chat_log.size() == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "No messages yet. Say hello or click 'Send Message' below!"
		empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55))
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		chat_drawer_list.add_child(empty_lbl)
		return

	for entry in mm.chat_log:
		var row = PanelContainer.new()
		var is_user = entry.get("role", "") == "user"
		var style = StyleBoxFlat.new()
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4

		if is_user:
			style.bg_color = Color(0.92, 0.94, 0.98, 0.95)
			style.border_color = Color(0.7, 0.78, 0.9, 1.0)
			style.border_width_left = 2
		else:
			style.bg_color = Color(1.0, 1.0, 1.0, 0.98)
			style.border_color = Color(0.88, 0.88, 0.92, 1.0)
			style.border_width_left = 2
		row.add_theme_stylebox_override("panel", style)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)

		var header = HBoxContainer.new()
		var sender_lbl = Label.new()
		sender_lbl.add_theme_font_size_override("font_size", 10)
		if is_user:
			sender_lbl.text = "You"
			sender_lbl.add_theme_color_override("font_color", Color(0.2, 0.4, 0.8))
		else:
			sender_lbl.text = "✦ " + model_list[current_model_idx].short_name
			sender_lbl.add_theme_color_override("font_color", Color(0.85, 0.25, 0.45))
		header.add_child(sender_lbl)

		var time_lbl = Label.new()
		time_lbl.text = " (" + str(entry.get("timestamp", "")) + ")"
		time_lbl.add_theme_font_size_override("font_size", 9)
		time_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
		header.add_child(time_lbl)
		vbox.add_child(header)

		_render_message_content(vbox, str(entry.get("content", "")), is_user)

		row.add_child(vbox)
		chat_drawer_list.add_child(row)

func _render_message_content(parent: VBoxContainer, text: String, _is_user: bool) -> void:
	if not "```" in text:
		var rich_lbl = RichTextLabel.new()
		rich_lbl.bbcode_enabled = true
		rich_lbl.fit_content = true
		rich_lbl.scroll_active = false
		rich_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rich_lbl.text = _format_simple_markdown(text)
		rich_lbl.add_theme_font_size_override("normal_font_size", 11)
		rich_lbl.add_theme_color_override("default_color", Color(0.12, 0.12, 0.16))
		parent.add_child(rich_lbl)
		return

	var parts = text.split("```")
	for i in range(parts.size()):
		var part = parts[i]
		if part.strip_edges().is_empty():
			continue

		if i % 2 == 0:
			var rich_lbl = RichTextLabel.new()
			rich_lbl.bbcode_enabled = true
			rich_lbl.fit_content = true
			rich_lbl.scroll_active = false
			rich_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rich_lbl.text = _format_simple_markdown(part)
			rich_lbl.add_theme_font_size_override("normal_font_size", 11)
			rich_lbl.add_theme_color_override("default_color", Color(0.12, 0.12, 0.16))
			parent.add_child(rich_lbl)
		else:
			var lines = part.split("\n", true, 1)
			var lang = lines[0].strip_edges() if lines.size() > 1 else ""
			var code_content = lines[1] if lines.size() > 1 else lines[0]
			_add_copyable_code_block(parent, code_content, lang)

func _add_copyable_code_block(parent: VBoxContainer, code_text: String, lang: String) -> void:
	var code_card = PanelContainer.new()
	var code_style = StyleBoxFlat.new()
	code_style.bg_color = Color(0.12, 0.14, 0.18, 0.98)
	code_style.border_color = Color(0.28, 0.32, 0.40, 1.0)
	code_style.border_width_left = 1
	code_style.border_width_top = 1
	code_style.border_width_right = 1
	code_style.border_width_bottom = 1
	code_style.corner_radius_top_left = 6
	code_style.corner_radius_top_right = 6
	code_style.corner_radius_bottom_left = 6
	code_style.corner_radius_bottom_right = 6
	code_style.content_margin_left = 10
	code_style.content_margin_right = 10
	code_style.content_margin_top = 6
	code_style.content_margin_bottom = 8
	code_card.add_theme_stylebox_override("panel", code_style)

	var code_vbox = VBoxContainer.new()
	code_vbox.add_theme_constant_override("separation", 4)

	var header = HBoxContainer.new()
	var lang_lbl = Label.new()
	lang_lbl.text = (lang if not lang.is_empty() else "code").to_upper()
	lang_lbl.add_theme_font_size_override("font_size", 9)
	lang_lbl.add_theme_color_override("font_color", Color(0.65, 0.70, 0.85))
	lang_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(lang_lbl)

	var copy_btn = Button.new()
	copy_btn.text = "📋 Copy"
	copy_btn.flat = true
	copy_btn.add_theme_font_size_override("font_size", 9)
	copy_btn.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0))
	copy_btn.pressed.connect(func():
		DisplayServer.clipboard_set(code_text.strip_edges())
		copy_btn.text = "✓ Copied!"
		get_tree().create_timer(2.0).timeout.connect(func():
			if is_instance_valid(copy_btn):
				copy_btn.text = "📋 Copy"
		)
	)
	header.add_child(copy_btn)
	code_vbox.add_child(header)

	var code_lbl = Label.new()
	code_lbl.text = code_text.strip_edges()
	code_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	code_lbl.add_theme_font_size_override("font_size", 10)
	code_lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	code_vbox.add_child(code_lbl)

	code_card.add_child(code_vbox)
	parent.add_child(code_card)

func _format_simple_markdown(text: String) -> String:
	var out := text
	# Bold **text** -> [b]text[/b]
	var bold_regex := RegEx.new()
	bold_regex.compile("\\*\\*(.*?)\\*\\*")
	out = bold_regex.sub(out, "[b]$1[/b]", true)

	# Inline code `text` -> [code][color=#a02050]text[/color][/code]
	var code_regex := RegEx.new()
	code_regex.compile("`(.*?)`")
	out = code_regex.sub(out, "[code][color=#902050]$1[/color][/code]", true)

	return out

func _on_chat_clear_pressed() -> void:
	if ai_client and ai_client.memory_mgr:
		ai_client.memory_mgr.clear_chat_history()
	_refresh_chat_drawer()
	play_sfx("pop")
	say("Chat memory cleared! Starting a fresh chapter together. ♡", "neutral")

func _on_affinity_leveled_up(new_lvl: int, title: String) -> void:
	play_sfx("cheer")
	heart_particles.position = Vector2(160, 200)
	heart_particles.restart()
	heart_particles.emitting = true
	say("✦ Bond Level Up! We reached Lv.%d: %s! Thank you for spending time with me! ♡" % [new_lvl, title], "inlove")

func _on_mood_changed(new_mood: String) -> void:
	match new_mood:
		"cheerful":
			play_sfx("sparkle")
		"affectionate":
			play_sfx("chime")
		"sleepy":
			pass
		"playful":
			play_sfx("pop")

func _trigger_ambient_behavior() -> void:
	# Only speak unprompted if idle, not dragging, and no modal is open
	if dragging or is_typing or bubble_panel.visible or pill_menu.visible or settings_panel.visible or chat_drawer.visible or memory_popup.visible or note_popup.visible:
		return

	var now := Time.get_time_dict_from_system()
	var hour: int = int(now.hour)

	if hour >= 23 or hour < 5:
		if ai_client and ai_client.memory_mgr:
			ai_client.memory_mgr.set_mood("sleepy")
		var late_quotes = [
			"It's getting late... please don't strain your eyes, okay? ( ᴗ˳ᴗ)",
			"Still up working? Remember to rest soon. I'm right here beside you. ♡",
			"Yaaawn... the quiet night is cozy, but make sure you get enough sleep! ✨"
		]
		say(late_quotes.pick_random(), "neutral")
		play_sfx("chime")
	elif hour >= 6 and hour < 10:
		if ai_client and ai_client.memory_mgr:
			ai_client.memory_mgr.set_mood("cheerful")
		var morning_quotes = [
			"Good morning! Let's make today productive and bright! ☀️",
			"A fresh new day! Take a deep breath and let's do our best. ✨",
			"Morning sunshine! Remember your breakfast and water today! (*^‿^*)"
		]
		say(morning_quotes.pick_random(), "happy")
		play_sfx("sparkle")
	elif hour >= 12 and hour < 14:
		var lunch_quotes = [
			"Midday check-in! Have you had lunch yet? Don't skip meals! 🍱",
			"Taking a quick pause? A short stretch can recharge your focus! ✦"
		]
		say(lunch_quotes.pick_random(), "neutral")
	else:
		var idle_quotes = [
			"Watching you concentrate always motivates me! Keep going! ✨",
			"I'm keeping watch right by your screen corner. You got this! ♡",
			"Just admiring your workspace! Feel free to talk to me whenever you want a break.",
			"Remember: unclench your jaw, relax your shoulders, and breathe easy~ (*^‿^*)"
		]
		say(idle_quotes.pick_random(), "neutral")

# ==============================================================================
# Procedural Audio Synthesizer (Zero external dependencies)
# ==============================================================================
func _init_sfx() -> void:
	sfx_library["pop"] = _synthesize_tone(720.0, 360.0, 0.06, 0.22)
	sfx_library["chime"] = _synthesize_tone(523.25, 659.25, 0.15, 0.20)
	sfx_library["sparkle"] = _synthesize_tone(880.0, 1318.5, 0.16, 0.18)
	sfx_library["cheer"] = _synthesize_arpeggio([523.25, 659.25, 783.99, 1046.5], 0.32, 0.22)

func _synthesize_tone(freq_start: float, freq_end: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var num_samples = int(sample_rate * duration)
	var byte_array = PackedByteArray()
	byte_array.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var progress = t / duration
		var freq = lerp(freq_start, freq_end, progress)
		var envelope = sin(progress * PI)
		var sample_val = sin(t * freq * TAU) * envelope * volume
		var sample_16 = int(clamp(sample_val, -1.0, 1.0) * 32767.0)
		byte_array.encode_s16(i * 2, sample_16)

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_array
	return stream

func _synthesize_arpeggio(freqs: Array, duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var num_samples = int(sample_rate * duration)
	var byte_array = PackedByteArray()
	byte_array.resize(num_samples * 2)
	var step_duration = duration / freqs.size()
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var step_idx = min(int(t / step_duration), freqs.size() - 1)
		var freq = freqs[step_idx]
		var step_t = fmod(t, step_duration)
		var envelope = sin((step_t / step_duration) * PI) * (1.0 - (t / duration) * 0.4)
		var sample_val = sin(t * freq * TAU) * envelope * volume
		var sample_16 = int(clamp(sample_val, -1.0, 1.0) * 32767.0)
		byte_array.encode_s16(i * 2, sample_16)

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_array
	return stream

func play_sfx(name: String) -> void:
	if not sound_enabled:
		return
	if sfx_library.has(name) and sfx_player:
		sfx_player.stream = sfx_library[name]
		sfx_player.play()
