extends Node
class_name CompanionMemoryManager

signal affinity_leveled_up(new_level: int, title: String)
signal mood_changed(new_mood: String)
signal memory_updated()

const MEMORY_PATH := "user://companion_memory.json"
const MAX_SAVED_MESSAGES := 80

var affinity_xp: int = 0
var affinity_level: int = 1
var affinity_title: String = "Curious Screenmate"
var current_mood: String = "cheerful" # cheerful, affectionate, thoughtful, sleepy, playful
var mood_energy: float = 1.0 # 0.0 to 1.0

var user_nickname: String = "Friend"
var user_facts: Array = [
	"Likes having an anime companion on desktop",
	"Focuses better with gentle company"
]

var chat_log: Array = []
var daily_streak: int = 1
var last_active_date: String = ""

var total_conversations: int = 0
var total_headpats: int = 0
var total_focus_minutes: int = 0
var total_treats_given: int = 0

const AFFINITY_TITLES := [
	{"level": 1, "title": "Curious Screenmate", "req_xp": 0},
	{"level": 2, "title": "Helpful Friend", "req_xp": 40},
	{"level": 3, "title": "Study Partner", "req_xp": 100},
	{"level": 4, "title": "Close Confidant", "req_xp": 200},
	{"level": 5, "title": "Trusted Companion", "req_xp": 350},
	{"level": 6, "title": "Cherished Companion", "req_xp": 550},
	{"level": 7, "title": "Precious Screenmate", "req_xp": 800},
	{"level": 8, "title": "Devoted Companion", "req_xp": 1150},
	{"level": 9, "title": "Inseparable Partner", "req_xp": 1600},
	{"level": 10, "title": "Desktop Soulmate ♡", "req_xp": 2200}
]

func _ready() -> void:
	load_memory()
	_update_streak()

func load_memory() -> void:
	if not FileAccess.file_exists(MEMORY_PATH):
		save_memory()
		return

	var file := FileAccess.open(MEMORY_PATH, FileAccess.READ)
	if not file:
		return

	var json_str := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(json_str)
	if parsed is Dictionary:
		affinity_xp = int(parsed.get("affinity_xp", 0))
		affinity_level = int(parsed.get("affinity_level", 1))
		affinity_title = str(parsed.get("affinity_title", "Curious Screenmate"))
		current_mood = str(parsed.get("current_mood", "cheerful"))
		mood_energy = float(parsed.get("mood_energy", 1.0))
		user_nickname = str(parsed.get("user_nickname", "Friend"))
		user_facts = parsed.get("user_facts", user_facts)
		chat_log = parsed.get("chat_log", [])
		daily_streak = int(parsed.get("daily_streak", 1))
		last_active_date = str(parsed.get("last_active_date", ""))
		total_conversations = int(parsed.get("total_conversations", 0))
		total_headpats = int(parsed.get("total_headpats", 0))
		total_focus_minutes = int(parsed.get("total_focus_minutes", 0))
		total_treats_given = int(parsed.get("total_treats_given", 0))
		_evaluate_level(false)

func save_memory() -> void:
	var file := FileAccess.open(MEMORY_PATH, FileAccess.WRITE)
	if not file:
		return

	var data := {
		"affinity_xp": affinity_xp,
		"affinity_level": affinity_level,
		"affinity_title": affinity_title,
		"current_mood": current_mood,
		"mood_energy": mood_energy,
		"user_nickname": user_nickname,
		"user_facts": user_facts,
		"chat_log": chat_log,
		"daily_streak": daily_streak,
		"last_active_date": last_active_date,
		"total_conversations": total_conversations,
		"total_headpats": total_headpats,
		"total_focus_minutes": total_focus_minutes,
		"total_treats_given": total_treats_given
	}
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	memory_updated.emit()

func _update_streak() -> void:
	var now := Time.get_date_dict_from_system()
	var today_str := "%04d-%02d-%02d" % [now.year, now.month, now.day]
	if last_active_date.is_empty():
		last_active_date = today_str
		daily_streak = 1
		save_memory()
	elif last_active_date != today_str:
		# Check if yesterday
		last_active_date = today_str
		daily_streak += 1
		add_affinity(15, "Daily Visit Streak")
		save_memory()

func add_affinity(amount: int, _reason: String = "") -> bool:
	affinity_xp += amount
	var leveled_up := _evaluate_level(true)
	save_memory()
	return leveled_up

func _evaluate_level(emit_signal: bool) -> bool:
	var old_level := affinity_level
	var highest_lvl := 1
	var title_str := "Curious Screenmate"

	for entry in AFFINITY_TITLES:
		if affinity_xp >= entry["req_xp"]:
			highest_lvl = entry["level"]
			title_str = entry["title"]

	affinity_level = highest_lvl
	affinity_title = title_str

	if affinity_level > old_level and emit_signal:
		affinity_leveled_up.emit(affinity_level, affinity_title)
		return true
	return false

func get_next_level_xp() -> int:
	for entry in AFFINITY_TITLES:
		if entry["level"] == affinity_level + 1:
			return entry["req_xp"]
	return affinity_xp

func get_current_level_base_xp() -> int:
	for entry in AFFINITY_TITLES:
		if entry["level"] == affinity_level:
			return entry["req_xp"]
	return 0

func set_mood(new_mood: String) -> void:
	if current_mood != new_mood:
		current_mood = new_mood
		mood_changed.emit(current_mood)
		save_memory()

func add_chat_message(role: String, content: String, expression: String = "neutral") -> void:
	var now := Time.get_time_dict_from_system()
	var time_str := "%02d:%02d" % [now.hour, now.minute]
	var entry := {
		"role": role,
		"content": content.strip_edges(),
		"expression": expression,
		"timestamp": time_str
	}
	chat_log.append(entry)
	if role == "user":
		total_conversations += 1
		add_affinity(5, "Chatted with companion")
		_auto_extract_facts(content)

	if chat_log.size() > MAX_SAVED_MESSAGES:
		chat_log.remove_at(0)
	save_memory()

func _auto_extract_facts(user_text: String) -> void:
	var lower := user_text.to_lower()
	if "my name is " in lower or "i am " in lower or "call me " in lower:
		for prefix in ["my name is ", "call me "]:
			var idx = lower.find(prefix)
			if idx != -1:
				var name_part = user_text.substr(idx + prefix.length()).strip_edges().split(" ")[0]
				name_part = name_part.trim_suffix(".").trim_suffix("!").trim_suffix(",")
				if name_part.length() > 1 and name_part.length() < 20:
					user_nickname = name_part
					add_fact("User's preferred name is " + name_part)
					break

	if "i like " in lower or "i love " in lower:
		var phrase = user_text.substr(max(lower.find("i like "), lower.find("i love "))).strip_edges()
		if phrase.length() < 50:
			add_fact(phrase)

func add_fact(fact: String) -> void:
	var clean := fact.strip_edges()
	if clean.is_empty(): return
	for existing in user_facts:
		if existing.to_lower() == clean.to_lower():
			return
	user_facts.append(clean)
	if user_facts.size() > 8:
		user_facts.remove_at(0)
	save_memory()

func clear_chat_history() -> void:
	chat_log.clear()
	save_memory()

func get_recent_turns(count: int = 12) -> Array:
	var turns: Array = []
	var start_idx = max(0, chat_log.size() - count)
	for i in range(start_idx, chat_log.size()):
		var m = chat_log[i]
		turns.append({"role": m["role"], "content": m["content"]})
	return turns

func build_system_prompt(companion_name: String, base_custom_prompt: String = "") -> String:
	if not base_custom_prompt.strip_edges().is_empty():
		return base_custom_prompt

	var facts_summary := ""
	if user_facts.size() > 0:
		facts_summary = " User context: " + ", ".join(user_facts) + "."

	var prompt := "You are %s, an affectionate, witty anime desktop companion living right on the user's screen. " % companion_name
	prompt += "Your current bond level with %s is Lv.%d (%s). " % [user_nickname, affinity_level, affinity_title]
	prompt += "Your current mood is %s. " % current_mood
	prompt += facts_summary + " Respond warmly in character in 35 words or less. Never break character. Mention user's name or shared journey naturally when appropriate."
	return prompt
