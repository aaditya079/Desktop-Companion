extends Node

signal reply_received(content: String, expression: String)
signal subtitle_chunk_received(text: String, expression: String)
signal audio_chunk_received(audio_data: PackedByteArray, volumes: Array, slice_length: int)
signal tool_status_updated(tool_id: String, tool_name: String, status: String, arguments: Dictionary)
signal request_failed(error_msg: String)
signal thinking_started()
signal test_completed(success: bool, message: String)
signal backend_connection_changed(connected: bool)

# Config settings (persisted in user://config.json)
var api_key: String = ""
var provider: String = "open_llm_vtuber" # "open_llm_vtuber", "groq", "custom", "openrouter", "openai", "deepseek", "local", "builtin"
var base_url: String = "https://api.groq.com/openai/v1/chat/completions"
var ws_url: String = "ws://127.0.0.1:12393/client-ws"
var model_name: String = "openai/gpt-oss-120b"
var custom_system_prompt: String = ""

# WebSocket Client for Open-LLM-VTuber backend
var ws_peer: WebSocketPeer = WebSocketPeer.new()
var is_ws_connected: bool = false
var reconnect_timer: float = 0.0
const RECONNECT_INTERVAL: float = 3.0

# WebSocket Heartbeat & Keep-Alive
var heartbeat_timer: float = 0.0
const HEARTBEAT_INTERVAL: float = 12.0

# Request Watchdog & Turn Accumulator
var is_requesting: bool = false
var request_watchdog_timer: float = 0.0
const REQUEST_TIMEOUT_MAX: float = 20.0
var accumulated_reply_text: String = ""
var last_expression: String = "neutral"

var http_request: HTTPRequest
var test_http_request: HTTPRequest
var is_testing: bool = false

const MemoryManagerScript = preload("res://scripts/memory_manager.gd")
var active_companion_name: String = "Camellya"
var memory_mgr: Node

var conversation_history: Array = [
	{"role": "system", "content": "You are Camellya, an affectionate, charming anime desktop companion. Respond warmly in 35 words or less. Always stay in character."}
]

func _ready() -> void:
	memory_mgr = MemoryManagerScript.new()
	add_child(memory_mgr)

	http_request = HTTPRequest.new()
	http_request.timeout = 15.0
	add_child(http_request)
	http_request.request_completed.connect(_on_http_completed)

	test_http_request = HTTPRequest.new()
	test_http_request.timeout = 10.0
	add_child(test_http_request)
	test_http_request.request_completed.connect(_on_test_http_completed)

	load_config()
	_try_connect_ws()

func set_companion_name(name: String) -> void:
	active_companion_name = name

func _process(delta: float) -> void:
	ws_peer.poll()
	var state = ws_peer.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not is_ws_connected:
			is_ws_connected = true
			backend_connection_changed.emit(true)
			print(">>> Connected to AI Backend via WebSocket (%s) <<<" % ws_url)

		# Keep-alive heartbeat ping
		heartbeat_timer += delta
		if heartbeat_timer >= HEARTBEAT_INTERVAL:
			heartbeat_timer = 0.0
			var ping_msg = {"type": "heartbeat"}
			ws_peer.send_text(JSON.stringify(ping_msg))

		# Read available WebSocket packets
		while ws_peer.get_available_packet_count() > 0:
			var pkt = ws_peer.get_packet()
			var raw_str = pkt.get_string_from_utf8()
			_handle_ws_packet(raw_str)

	elif state == WebSocketPeer.STATE_CLOSED or state == WebSocketPeer.STATE_CLOSING:
		if is_ws_connected:
			is_ws_connected = false
			backend_connection_changed.emit(false)
			print(">>> AI Backend WebSocket disconnected <<<")

		reconnect_timer += delta
		if reconnect_timer >= RECONNECT_INTERVAL:
			reconnect_timer = 0.0
			_try_connect_ws()

	# Watchdog timer to prevent is_requesting from getting stuck
	if is_requesting:
		request_watchdog_timer += delta
		if request_watchdog_timer >= REQUEST_TIMEOUT_MAX:
			request_watchdog_timer = 0.0
			is_requesting = false
			if not accumulated_reply_text.is_empty():
				var final_txt = accumulated_reply_text.strip_edges()
				accumulated_reply_text = ""
				if memory_mgr:
					memory_mgr.add_chat_message("assistant", final_txt, last_expression)
				reply_received.emit(final_txt, last_expression)
	else:
		request_watchdog_timer = 0.0

func _try_connect_ws() -> void:
	var state = ws_peer.get_ready_state()
	if state == WebSocketPeer.STATE_CONNECTING or state == WebSocketPeer.STATE_OPEN:
		return
	var err = ws_peer.connect_to_url(ws_url)
	if err != OK:
		# Silent retry on next interval
		pass

func _handle_ws_packet(raw_str: String) -> void:
	var parsed = JSON.parse_string(raw_str)
	if not (parsed is Dictionary):
		return

	var msg_type: String = parsed.get("type", "")

	match msg_type:
		"heartbeat-ack":
			# Connection is healthy and acknowledged
			pass

		"full-text":
			var text: String = parsed.get("text", "")
			if text == "Connection established":
				if not is_ws_connected:
					is_ws_connected = true
					backend_connection_changed.emit(true)
				return
			elif text == "Thinking...":
				is_requesting = true
				thinking_started.emit()
				return

			is_requesting = false
			var expression := _detect_expression(text)
			if memory_mgr:
				memory_mgr.add_chat_message("assistant", text, expression)
			reply_received.emit(text.strip_edges(), expression)

		"audio":
			# Open-LLM-VTuber audio payload: contains text inside display_text dict, actions, and base64 audio
			var subtitle: String = ""
			var disp = parsed.get("display_text")
			if disp is Dictionary:
				subtitle = disp.get("text", "")
			elif disp is String:
				subtitle = disp
			elif parsed.has("text"):
				subtitle = str(parsed.get("text", ""))

			var raw_exprs = []
			var actions = parsed.get("actions")
			if actions is Dictionary and actions.has("expressions"):
				raw_exprs = actions.get("expressions")
			elif parsed.has("expressions"):
				raw_exprs = parsed.get("expressions")

			var expr := _map_expression(raw_exprs)
			if expr != "neutral":
				last_expression = expr

			if not subtitle.is_empty():
				if not accumulated_reply_text.is_empty():
					accumulated_reply_text += " " + subtitle
				else:
					accumulated_reply_text = subtitle
				subtitle_chunk_received.emit(subtitle, expr)

			var audio_b64 = parsed.get("audio")
			if audio_b64 is String and not audio_b64.is_empty():
				var raw_bytes := Marshalls.base64_to_raw(audio_b64)
				var vols = parsed.get("volumes", [])
				var slice_len: int = parsed.get("slice_length", 20)
				audio_chunk_received.emit(raw_bytes, vols, slice_len)

		"backend-synth-complete":
			# Backend finished generating audio/text. Acknowledge playback complete to finalize turn
			if is_ws_connected and ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
				ws_peer.send_text(JSON.stringify({"type": "frontend-playback-complete"}))

			if not accumulated_reply_text.is_empty():
				var final_txt = accumulated_reply_text.strip_edges()
				accumulated_reply_text = ""
				is_requesting = false
				if memory_mgr:
					memory_mgr.add_chat_message("assistant", final_txt, last_expression)
				reply_received.emit(final_txt, last_expression)

		"tool_call_status":
			var t_id: String = parsed.get("tool_id", "")
			var t_name: String = parsed.get("tool_name", "")
			var t_status: String = parsed.get("status", "")
			var t_args: Dictionary = parsed.get("arguments", {})
			tool_status_updated.emit(t_id, t_name, t_status, t_args)

		"control":
			var cmd: String = parsed.get("command", "")
			if cmd.is_empty():
				cmd = parsed.get("text", "")
			if cmd == "conversation-chain-start":
				is_requesting = true
				accumulated_reply_text = ""
				last_expression = "neutral"
				thinking_started.emit()
			elif cmd == "conversation-chain-end":
				is_requesting = false
				if not accumulated_reply_text.is_empty():
					var final_txt = accumulated_reply_text.strip_edges()
					accumulated_reply_text = ""
					if memory_mgr:
						memory_mgr.add_chat_message("assistant", final_txt, last_expression)
					reply_received.emit(final_txt, last_expression)

		"error":
			is_requesting = false
			var err_msg: String = parsed.get("message", "AI backend error occurred.")
			request_failed.emit(err_msg)

func _map_expression(raw_expr) -> String:
	if raw_expr is Array and raw_expr.size() > 0:
		var first = raw_expr[0]
		if first is int:
			match first:
				1: return "happy"
				2: return "sad"
				3: return "angry"
				4: return "surprised"
				5: return "think"
				6: return "inlove"
				_: return "neutral"
		elif first is String:
			return _normalize_expression(first)
	elif raw_expr is String:
		return _normalize_expression(raw_expr)
	return "neutral"

func _normalize_expression(name: String) -> String:
	var l := name.to_lower()
	if "happy" in l or "smile" in l or "joy" in l:
		return "happy"
	elif "sad" in l or "cry" in l or "sorrow" in l:
		return "sad"
	elif "angry" in l or "annoy" in l:
		return "angry"
	elif "surpris" in l or "shock" in l:
		return "surprised"
	elif "think" in l or "ponder" in l:
		return "think"
	elif "love" in l or "blush" in l or "heart" in l:
		return "inlove"
	return "neutral"

func load_config() -> void:
	var path := "user://config.json"
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var text := file.get_as_text()
			var parsed = JSON.parse_string(text)
			if parsed is Dictionary:
				api_key = parsed.get("api_key", "")
				provider = parsed.get("provider", "open_llm_vtuber")
				base_url = parsed.get("base_url", "https://api.groq.com/openai/v1/chat/completions")
				ws_url = parsed.get("ws_url", "ws://127.0.0.1:12393/client-ws")
				model_name = parsed.get("model_name", "openai/gpt-oss-120b")
				custom_system_prompt = parsed.get("custom_system_prompt", "")

func save_config() -> void:
	var path := "user://config.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		var data := {
			"api_key": api_key,
			"provider": provider,
			"base_url": base_url,
			"ws_url": ws_url,
			"model_name": model_name,
			"custom_system_prompt": custom_system_prompt
		}
		file.store_string(JSON.stringify(data, "  "))

func send_message(user_text: String) -> void:
	if is_requesting:
		return

	user_text = user_text.strip_edges()
	if user_text.is_empty():
		return

	# Priority 1: Use Open-LLM-VTuber WebSocket backend if connected
	if is_ws_connected and ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if memory_mgr:
			memory_mgr.add_chat_message("user", user_text)
		is_requesting = true
		accumulated_reply_text = ""
		thinking_started.emit()
		var msg_payload := {
			"type": "text-input",
			"text": user_text
		}
		ws_peer.send_text(JSON.stringify(msg_payload))
		return

	# Priority 2: If explicitly built-in or no API key, use offline smart dialogue
	var endpoint := get_clean_endpoint(base_url)
	var is_local := "localhost" in endpoint or "127.0.0.1" in endpoint
	if provider == "builtin" or (api_key.strip_edges().is_empty() and not is_local):
		if memory_mgr:
			memory_mgr.add_chat_message("user", user_text)
		thinking_started.emit()
		get_tree().create_timer(0.35).timeout.connect(func():
			_handle_smart_dialogue(user_text)
		)
		return

	# Priority 3: Fallback HTTP Request
	if memory_mgr:
		memory_mgr.add_chat_message("user", user_text)

	is_requesting = true
	thinking_started.emit()

	var sys_prompt := ""
	if memory_mgr:
		sys_prompt = memory_mgr.build_system_prompt(active_companion_name, custom_system_prompt)
	else:
		sys_prompt = "You are %s, an affectionate desktop companion. Respond in 35 words or less." % active_companion_name

	var messages_payload: Array = [
		{"role": "system", "content": sys_prompt}
	]
	if memory_mgr:
		messages_payload.append_array(memory_mgr.get_recent_turns(10))
	else:
		messages_payload.append({"role": "user", "content": user_text})

	var headers: PackedStringArray = [
		"Content-Type: application/json"
	]
	if not api_key.strip_edges().is_empty():
		headers.append("Authorization: Bearer " + api_key.strip_edges())

	var payload := {
		"model": model_name.strip_edges() if not model_name.strip_edges().is_empty() else "openai/gpt-oss-120b",
		"messages": messages_payload,
		"max_tokens": 120,
		"temperature": 0.7
	}

	var err := http_request.request(endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		is_requesting = false
		_handle_smart_dialogue(user_text)

func get_clean_endpoint(url: String) -> String:
	var clean := url.strip_edges()
	if clean.is_empty():
		return "https://api.groq.com/openai/v1/chat/completions"
	clean = clean.trim_suffix("/")
	if not clean.ends_with("/chat/completions"):
		if clean.ends_with("/v1"):
			clean += "/chat/completions"
		else:
			clean += "/v1/chat/completions"
	return clean

func _on_http_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_requesting = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var last_user_turn: String = ""
		if memory_mgr and memory_mgr.chat_log.size() > 0:
			for i in range(memory_mgr.chat_log.size() - 1, -1, -1):
				if memory_mgr.chat_log[i]["role"] == "user":
					last_user_turn = memory_mgr.chat_log[i]["content"]
					break
		if last_user_turn.is_empty():
			last_user_turn = "hello"
		_handle_smart_dialogue(last_user_turn)
		return

	var text_body := body.get_string_from_utf8()
	var parsed = JSON.parse_string(text_body)
	if parsed == null:
		request_failed.emit("Failed to parse cloud AI response.")
		return

	var reply: String = ""
	if parsed is Dictionary and parsed.has("choices") and parsed["choices"] is Array and parsed["choices"].size() > 0:
		var first = parsed["choices"][0]
		if first is Dictionary and first.has("message") and first["message"] is Dictionary:
			reply = first["message"].get("content", "")

	if reply.is_empty():
		request_failed.emit("Empty reply received from AI.")
		return

	var expression := _detect_expression(reply)
	if memory_mgr:
		memory_mgr.add_chat_message("assistant", reply, expression)
	reply_received.emit(reply.strip_edges(), expression)

func _detect_expression(text: String) -> String:
	var lower := text.to_lower()
	if "love" in lower or "heart" in lower or "cute" in lower or "blush" in lower or "happy" in lower:
		return "inlove"
	elif "sorry" in lower or "sad" in lower or "regret" in lower or "error" in lower or "bad" in lower:
		return "sad"
	elif "angry" in lower or "annoy" in lower or "stop" in lower or "baka" in lower:
		return "angry"
	elif "think" in lower or "wait" in lower or "searching" in lower:
		return "think"
	return "neutral"

func _handle_smart_dialogue(user_text: String) -> void:
	var lower := user_text.to_lower().strip_edges()
	var reply := ""
	var expression := "neutral"

	if lower in ["hi", "hello", "hey", "sup", "yo"]:
		var greetings = [
			"Hey there! Ready to get some work done together?",
			"Hello! Glad you're here beside me.",
			"Hi! How are you feeling today?"
		]
		reply = greetings[randi() % greetings.size()]
		expression = "happy"
	elif "how are you" in lower:
		reply = "I'm feeling wonderful, especially now that you're hanging out with me! ♡"
		expression = "happy"
	elif "thank" in lower:
		reply = "You're always so welcome! I love helping you out. (*^‿^*)"
		expression = "happy"
	elif "tired" in lower or "sleepy" in lower:
		reply = "You've worked so hard... please rest your eyes and grab some water, okay? ♡"
		expression = "shy"
	else:
		var default_replies = [
			"I hear you! Let's stay focused and make today amazing.",
			"That's interesting! I'm right here with you every step of the way.",
			"You got this! Take a deep breath and keep going. ✨",
			"I'm listening! Tell me more whenever you feel like chatting."
		]
		reply = default_replies[randi() % default_replies.size()]
		expression = "neutral"

	if memory_mgr:
		memory_mgr.add_chat_message("assistant", reply, expression)

	reply_received.emit(reply, expression)

func test_api_connection(test_url: String, test_model: String, test_key: String) -> void:
	if is_testing:
		return
	is_testing = true

	var endpoint := get_clean_endpoint(test_url)
	var headers: PackedStringArray = [
		"Content-Type: application/json"
	]
	if not test_key.strip_edges().is_empty():
		headers.append("Authorization: Bearer " + test_key.strip_edges())

	var test_payload := {
		"model": test_model.strip_edges() if not test_model.strip_edges().is_empty() else "openai/gpt-oss-120b",
		"messages": [
			{"role": "user", "content": "Respond with 1 word: Ready"}
		],
		"max_tokens": 8,
		"temperature": 0.2
	}

	var err := test_http_request.request(endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(test_payload))
	if err != OK:
		is_testing = false
		test_completed.emit(false, "Failed to start HTTP request (Error %d)" % err)

func _on_test_http_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_testing = false
	if result != HTTPRequest.RESULT_SUCCESS:
		test_completed.emit(false, "Network error: Connection timed out or unreachable")
		return

	if response_code == 200:
		test_completed.emit(true, "Connected successfully! API responded OK.")
	elif response_code == 401:
		test_completed.emit(false, "Error 401: Invalid or missing API key")
	elif response_code == 404:
		test_completed.emit(false, "Error 404: Endpoint URL or model name not found")
	elif response_code == 429:
		test_completed.emit(false, "Error 429: Rate limit exceeded or quota reached")
	else:
		test_completed.emit(false, "Error %d returned from API" % response_code)
