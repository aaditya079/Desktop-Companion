extends Node

signal reply_received(content: String, expression: String)
signal request_failed(error_msg: String)
signal thinking_started()
signal test_completed(success: bool, message: String)

# Config settings (persisted in user://config.json)
var api_key: String = ""
var provider: String = "groq" # "custom", "groq", "openrouter", "openai", "deepseek", "local", "builtin"
var base_url: String = "https://api.groq.com/openai/v1/chat/completions"
var model_name: String = "llama-3.3-70b-versatile"
var custom_system_prompt: String = ""

var http_request: HTTPRequest
var test_http_request: HTTPRequest
var is_requesting: bool = false
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

func set_companion_name(name: String) -> void:
	active_companion_name = name

func load_config() -> void:
	var path := "user://config.json"
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var text := file.get_as_text()
			var parsed = JSON.parse_string(text)
			if parsed is Dictionary:
				api_key = parsed.get("api_key", "")
				provider = parsed.get("provider", "groq")
				base_url = parsed.get("base_url", "https://api.groq.com/openai/v1/chat/completions")
				model_name = parsed.get("model_name", "llama-3.3-70b-versatile")
				custom_system_prompt = parsed.get("custom_system_prompt", "")
				if not custom_system_prompt.is_empty() and conversation_history.size() > 0:
					conversation_history[0]["content"] = custom_system_prompt

func save_config() -> void:
	var path := "user://config.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		var data := {
			"api_key": api_key,
			"provider": provider,
			"base_url": base_url,
			"model_name": model_name,
			"custom_system_prompt": custom_system_prompt
		}
		file.store_string(JSON.stringify(data, "  "))

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
	if "openrouter.ai" in endpoint:
		headers.append("HTTP-Referer: https://desktop-companion.local")
		headers.append("X-Title: DesktopCompanion")

	var test_payload := {
		"model": test_model.strip_edges() if not test_model.strip_edges().is_empty() else "llama-3.3-70b-versatile",
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
		var text_body := body.get_string_from_utf8()
		var parsed = JSON.parse_string(text_body)
		if parsed is Dictionary and parsed.has("choices"):
			test_completed.emit(true, "Connected successfully! API responded OK.")
		else:
			test_completed.emit(true, "HTTP 200 received from endpoint.")
	elif response_code == 401:
		test_completed.emit(false, "Error 401: Invalid or missing API key")
	elif response_code == 404:
		test_completed.emit(false, "Error 404: Endpoint URL or model name not found")
	elif response_code == 429:
		test_completed.emit(false, "Error 429: Rate limit exceeded or quota reached")
	else:
		test_completed.emit(false, "Error %d returned from API" % response_code)

func send_message(user_text: String) -> void:
	if is_requesting:
		return

	user_text = user_text.strip_edges()
	if user_text.is_empty():
		return

	# If provider is explicitly built-in or no API key and not a local endpoint, use built-in dialogue engine
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

	if provider == "openrouter" or "openrouter.ai" in endpoint:
		headers.append("HTTP-Referer: https://desktop-companion.local")
		headers.append("X-Title: DesktopCompanion")

	var payload := {
		"model": model_name.strip_edges() if not model_name.strip_edges().is_empty() else "llama-3.3-70b-versatile",
		"messages": messages_payload,
		"max_tokens": 120,
		"temperature": 0.7
	}

	var err := http_request.request(endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		is_requesting = false
		_handle_smart_dialogue(user_text)

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
	elif "what are you doing" in lower or "what's up" in lower:
		reply = "Just keeping you company and watching you do great things!"
		expression = "neutral"
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
