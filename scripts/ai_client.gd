extends Node

signal reply_received(content: String, expression: String)
signal request_failed(error_msg: String)
signal thinking_started()

# Config settings (persisted in user://config.json)
var api_key: String = ""
var provider: String = "groq" # "groq", "openrouter", "openai", "custom", "offline"
var base_url: String = "https://api.groq.com/openai"
var model_name: String = "llama-3.3-70b-versatile"

var http_request: HTTPRequest
var is_requesting: bool = false

var conversation_history: Array = [
	{"role": "system", "content": "You are Lumina, a charming, witty anime desktop companion. Respond warmly in 30 words or less. Always stay in character."}
]

func _ready() -> void:
	http_request = HTTPRequest.new()
	http_request.timeout = 12.0
	add_child(http_request)
	http_request.request_completed.connect(_on_http_completed)
	load_config()

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
				base_url = parsed.get("base_url", "https://api.groq.com/openai")
				model_name = parsed.get("model_name", "llama-3.3-70b-versatile")

func save_config() -> void:
	var path := "user://config.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		var data := {
			"api_key": api_key,
			"provider": provider,
			"base_url": base_url,
			"model_name": model_name
		}
		file.store_string(JSON.stringify(data, "  "))

func send_message(user_text: String) -> void:
	if is_requesting:
		return
		
	user_text = user_text.strip_edges()
	if user_text.is_empty():
		return

	# If no API key configured, use our built-in Smart Companion Dialogue Engine!
	if api_key.is_empty():
		thinking_started.emit()
		# Add a realistic tiny delay so it feels natural
		get_tree().create_timer(0.4).timeout.connect(func():
			_handle_smart_dialogue(user_text)
		)
		return

	is_requesting = true
	thinking_started.emit()
	conversation_history.append({"role": "user", "content": user_text})

	if conversation_history.size() > 10:
		conversation_history.remove_at(1)

	var endpoint := base_url.trim_suffix("/") + "/v1/chat/completions"
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]
	
	if provider == "openrouter":
		headers.append("HTTP-Referer: https://desktop-companion.local")
		headers.append("X-Title: DesktopCompanion")
		
	var payload := {
		"model": model_name,
		"messages": conversation_history,
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
		# Fall back gracefully to local companion dialogue instead of breaking the immersion
		var last_user_turn: String = ""
		for msg in conversation_history:
			if msg["role"] == "user":
				last_user_turn = msg["content"]
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

	conversation_history.append({"role": "assistant", "content": reply})
	
	# Detect sentiment for facial expression
	var expression := _detect_expression(reply)
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

# Built-in instant companion response engine (Zero setup required for end users!)
func _handle_smart_dialogue(user_text: String) -> void:
	var lower := user_text.to_lower().strip_edges()
	var reply := ""
	var expression := "neutral"

	if lower in ["hi", "hello", "hey", "sup", "yo"]:
		var greetings = [
			"Hey there! Ready to get some work done together?",
			"Hello master! I'm right here keeping you company.",
			"Hi! Need any help or just saying hello?"
		]
		reply = greetings.pick_random()
		expression = "neutral"
	elif "who are you" in lower or "your name" in lower:
		reply = "I'm Lumina, your personal desktop companion! I live in the corner of your screen to keep you focused and happy."
		expression = "inlove"
	elif "love you" in lower or "cute" in lower or "pretty" in lower:
		reply = "Aww, you're making me blush! (⁄ ⁄>⁄ ▽ ⁄<⁄ ⁄) Thank you!"
		expression = "inlove"
	elif "time" in lower or "what time" in lower:
		var time := Time.get_time_dict_from_system()
		var hour: int = time.hour
		var minute: int = time.minute
		var ampm = "AM" if hour < 12 else "PM"
		var display_hour = hour % 12
		if display_hour == 0: display_hour = 12
		reply = "It's %02d:%02d %s! Remember to take water breaks!" % [display_hour, minute, ampm]
		expression = "neutral"
	elif "date" in lower or "today" in lower:
		var date := Time.get_date_dict_from_system()
		reply = "Today is %04d-%02d-%02d! Let's make it a productive day!" % [date.year, date.month, date.day]
		expression = "neutral"
	elif "joke" in lower:
		var jokes = [
			"Why do programmers prefer dark mode? Because light attracts bugs!",
			"There are 10 types of people in the world: those who understand binary, and those who don't.",
			"Why was the JavaScript developer sad? Because they didn't Node how to Express themselves!"
		]
		reply = jokes.pick_random()
		expression = "inlove"
	elif "sad" in lower or "tired" in lower or "exhausted" in lower:
		reply = "I'm sorry you're feeling down. Take a deep breath, stretch your arms, and take it one step at a time. I'm right here with you."
		expression = "sad"
	elif "bye" in lower or "quit" in lower or "exit" in lower:
		reply = "Press ESC anytime if you need to dismiss me. I'll be waiting for you!"
		expression = "neutral"
	elif "ai" in lower or "api" in lower or "key" in lower or "groq" in lower or "settings" in lower:
		reply = "To unlock full unlimited LLM chat, click the ⚙ Settings button and paste a free Groq or OpenRouter API key!"
		expression = "neutral"
	else:
		var fallbacks = [
			"I hear you! You can chat with me, or paste an API key in settings for unlimited AI thoughts.",
			"Interesting thought! I'm currently running in standalone companion mode.",
			"Got it! Let me know if you want to set a reminder or just talk.",
			"Working alongside you is always fun!"
		]
		reply = fallbacks.pick_random()
		expression = "neutral"

	reply_received.emit(reply, expression)
