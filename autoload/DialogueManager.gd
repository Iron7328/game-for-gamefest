extends Node
## Data-driven диалоги: загрузка из JSON, переходы между узлами, применение эффектов выбора.
## Регистрация: Autoload, имя "DialogueManager" (после GameManager).
## Сам ничего не рисует — UI подписывается на сигналы.

## Диалог начался (до этого ни один диалог не был активен).
signal dialogue_started(node_id: String)
## Показать узел. node = {id, speaker, text, choices: [{text, type, next, effects}]}
signal node_shown(node: Dictionary)
## Игрок выбрал вариант (эффекты на шкалы уже применены).
signal choice_made(node_id: String, choice_index: int)
## Диалог закончился (выбран вариант с пустым "next").
signal dialogue_ended(last_node_id: String)

const DIALOGUES_PATH := "res://data/dialogues.json"
const MAX_CHOICES := 3

## ID стартового узла (поле "start_node" в JSON).
var start_node_id := ""
var current_node_id := ""
var is_active := false

var _nodes: Dictionary = {}  # id -> нормализованный узел


func _ready() -> void:
	load_dialogues(DIALOGUES_PATH)


# ---------------------------------------------------------------------------
# Загрузка и парсинг JSON
# ---------------------------------------------------------------------------

## Загрузить диалоги из файла. Возвращает false при ошибке (старые данные сохраняются).
func load_dialogues(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DialogueManager: не удалось открыть %s (код %d)" % [path, FileAccess.get_open_error()])
		return false

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("DialogueManager: ошибка JSON в %s, строка %d: %s"
			% [path, json.get_error_line(), json.get_error_message()])
		return false

	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("nodes")) != TYPE_ARRAY:
		push_error("DialogueManager: %s — ожидается объект с массивом \"nodes\"" % path)
		return false

	var parsed := {}
	for raw_node in data["nodes"]:
		var node := _parse_node(raw_node)
		if node.is_empty():
			continue
		if parsed.has(node["id"]):
			push_warning("DialogueManager: дублируется id '%s' — используется последний" % node["id"])
		parsed[node["id"]] = node

	_nodes = parsed
	start_node_id = _to_id(data.get("start_node"))
	_validate_links()
	return true


## Приводит узел из JSON к фиксированной структуре. Возвращает {} при ошибке.
func _parse_node(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("DialogueManager: элемент \"nodes\" не является объектом — пропущен")
		return {}
	var node_id := _to_id(raw.get("id"))
	if node_id.is_empty():
		push_warning("DialogueManager: узел без \"id\" — пропущен")
		return {}

	var choices: Array = []
	var raw_choices: Variant = raw.get("choices", [])
	if typeof(raw_choices) == TYPE_ARRAY:
		for raw_choice in raw_choices:
			if typeof(raw_choice) != TYPE_DICTIONARY:
				push_warning("DialogueManager: %s — вариант не является объектом, пропущен" % node_id)
				continue
			if choices.size() == MAX_CHOICES:
				push_warning("DialogueManager: %s — больше %d вариантов, лишние отброшены" % [node_id, MAX_CHOICES])
				break
			choices.append({
				"text": str(raw_choice.get("text", "")),
				"type": _parse_choice_type(str(raw_choice.get("type", "neutral")), node_id),
				"next": _to_id(raw_choice.get("next")),
				"effects": _parse_effects(raw_choice.get("effects")),
			})

	if choices.is_empty():
		# Без вариантов игрок застрянет — добавляется вариант завершения диалога.
		push_warning("DialogueManager: %s — нет вариантов, добавлен вариант завершения" % node_id)
		choices.append({"text": "[ДАЛЕЕ]", "type": GameManager.ChoiceType.NEUTRAL, "next": "", "effects": {}})

	return {
		"id": node_id,
		"speaker": str(raw.get("speaker", "")),
		"text": str(raw.get("text", "")),
		"choices": choices,
	}


## "positive" / "neutral" / "negative" → GameManager.ChoiceType.
func _parse_choice_type(type_name: String, node_id: String) -> int:
	match type_name.to_lower():
		"positive":
			return GameManager.ChoiceType.POSITIVE
		"negative":
			return GameManager.ChoiceType.NEGATIVE
		"neutral":
			return GameManager.ChoiceType.NEUTRAL
	push_warning("DialogueManager: %s — неизвестный type '%s', считается neutral" % [node_id, type_name])
	return GameManager.ChoiceType.NEUTRAL


## Необязательное поле "effects": если задано, ЗАМЕНЯЕТ стандартный эффект типа ответа.
func _parse_effects(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return {
		GameManager.STAT_MENTAL_HEALTH: int(value.get(GameManager.STAT_MENTAL_HEALTH, 0)),
		GameManager.STAT_PARENTS_RELATIONSHIP: int(value.get(GameManager.STAT_PARENTS_RELATIONSHIP, 0)),
	}


## null / отсутствие поля → "" (конец диалога). ID в JSON должны быть строками.
func _to_id(value: Variant) -> String:
	return "" if value == null else str(value).strip_edges()


## Проверка ссылок "next" и "start_node" после загрузки.
func _validate_links() -> void:
	if not _nodes.has(start_node_id):
		push_warning("DialogueManager: start_node '%s' не найден" % start_node_id)
	for node_id in _nodes:
		for choice in _nodes[node_id]["choices"]:
			var next_id: String = choice["next"]
			if not next_id.is_empty() and not _nodes.has(next_id):
				push_warning("DialogueManager: %s → '%s': узел не найден" % [node_id, next_id])


# ---------------------------------------------------------------------------
# Управление диалогом
# ---------------------------------------------------------------------------

## Начать диалог с узла node_id (пусто — со start_node).
## Если диалог уже идёт, он заменяется новым без сигнала dialogue_ended.
func start_dialogue(node_id: String = "") -> bool:
	var target_id := start_node_id if node_id.is_empty() else node_id
	if not _nodes.has(target_id):
		push_error("DialogueManager: узел '%s' не найден" % target_id)
		return false
	if not is_active:
		is_active = true
		dialogue_started.emit(target_id)
	_show_node(target_id)
	return true


## Выбор варианта ответа (индекс 0..2). Вызывается из UI.
func choose(index: int) -> void:
	if not is_active:
		return
	var choices: Array = _nodes[current_node_id]["choices"]
	if index < 0 or index >= choices.size():
		push_warning("DialogueManager: неверный индекс варианта %d" % index)
		return

	var choice: Dictionary = choices[index]
	var from_id := current_node_id
	_apply_effects(choice)
	choice_made.emit(from_id, index)

	# Обработчик сигнала мог сам переключить/завершить диалог — тогда не вмешиваемся.
	if not is_active or current_node_id != from_id:
		return

	var next_id: String = choice["next"]
	if next_id.is_empty():
		end_dialogue()
	elif _nodes.has(next_id):
		_show_node(next_id)
	else:
		push_error("DialogueManager: узел '%s' не найден, диалог завершён" % next_id)
		end_dialogue()


## Принудительно завершить текущий диалог.
func end_dialogue() -> void:
	if not is_active:
		return
	var last_id := current_node_id
	is_active = false
	current_node_id = ""
	dialogue_ended.emit(last_id)


func has_dialogue_node(node_id: String) -> bool:
	return _nodes.has(node_id)


## Копия узла (изменение копии не влияет на загруженные данные).
func get_dialogue_node(node_id: String) -> Dictionary:
	return _nodes.get(node_id, {}).duplicate(true)


func _show_node(node_id: String) -> void:
	current_node_id = node_id
	node_shown.emit(get_dialogue_node(node_id))


func _apply_effects(choice: Dictionary) -> void:
	var effects: Dictionary = choice["effects"]
	if effects.is_empty():
		GameManager.apply_choice(choice["type"])
	else:
		GameManager.change_stats(
			effects[GameManager.STAT_MENTAL_HEALTH],
			effects[GameManager.STAT_PARENTS_RELATIONSHIP])
