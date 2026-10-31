extends Node
## Ивенты с таймером и концовки, зависящие от значений шкал.
## Регистрация: Autoload, имя "EventManager" (ПОСЛЕ GameManager и DialogueManager).

## Запущен таймер ивента (hint — текст для UI, пустой = скрытый ивент).
signal event_timer_started(event_id: String, duration: float, hint: String)
## Таймер ивента остановлен (отменён или истёк).
signal event_timer_stopped(event_id: String)
## Ивент сработал: стартовал его диалог.
signal event_triggered(event_id: String)
## Условие концовки выполнено: финальный диалог стартует в этом же кадре.
signal ending_triggered(ending_id: String)

## ---------------------------------------------------------------------------
## Ивенты с таймером.
## Условие выполнилось → запускается таймер на delay секунд.
## Условие перестало выполняться до конца таймера → ивент отменяется.
## Таймер истёк, условие всё ещё выполнено → стартует диалог с узла node.
## Если в этот момент идёт другой диалог, ивент ждёт его окончания.
## Поля:
##   id    — уникальный ID ивента
##   stat  — "mental_health" или "parents_relationship"
##   op    — "<", "<=", ">", ">=", "=="
##   value — порог
##   delay — задержка в секундах
##   node  — ID стартового узла в dialogues.json
##   hint  — текст в UI на время таймера ("" — игрок таймер не видит)
##   once  — true: срабатывает один раз за игру
## ---------------------------------------------------------------------------
var timed_events: Array[Dictionary] = [
	# Пример: отношения с родителями упали ниже 30.
	{
		"id": "low_relationship",
		"stat": "parents_relationship",
		"op": "<",
		"value": 30,
		"delay": 15.0,
		"node": "event_low_rel_001",
		"hint": "[ПОДСКАЗКА ИВЕНТА]",
		"once": true,
	},
]

## ---------------------------------------------------------------------------
## Концовки. Проверяются при каждом изменении шкал, по порядку; срабатывает первая.
## Концовка прерывает текущий диалог и останавливает все ивенты.
##   node  — ID первого узла финального диалога
##   scene — путь к сцене финала ("" — просто зафиксировать game_over)
## ---------------------------------------------------------------------------
var endings: Array[Dictionary] = [
	{
		"id": "kicked_out",
		"stat": "parents_relationship",
		"op": "<=",
		"value": 0,
		"node": "ending_kicked_out_001",
		"scene": "",
	},
	{
		"id": "breakdown",
		"stat": "mental_health",
		"op": "<=",
		"value": 0,
		"node": "ending_breakdown_001",
		"scene": "",
	},
]

enum EndingState { NONE, PENDING, PLAYING }

var _timers: Dictionary = {}       # event_id -> Timer
var _pending: Array[String] = []   # ивенты, ждущие окончания текущего диалога
var _ending_state := EndingState.NONE
var _ending: Dictionary = {}       # активная концовка


func _ready() -> void:
	GameManager.stats_changed.connect(_on_stats_changed)
	GameManager.game_reset.connect(_on_game_reset)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	_evaluate()


## Сколько секунд осталось до ивента (0 — таймер не запущен).
func get_time_left(event_id: String) -> float:
	var timer: Timer = _timers.get(event_id)
	return timer.time_left if timer != null else 0.0


# ---------------------------------------------------------------------------
# Проверка условий
# ---------------------------------------------------------------------------

func _on_stats_changed(_mental: int, _relationship: int) -> void:
	_evaluate()


func _evaluate() -> void:
	if GameManager.is_game_over or _ending_state != EndingState.NONE:
		return
	if _check_endings():
		return
	_update_timed_events()


func _is_condition_met(condition: Dictionary) -> bool:
	var current: int = GameManager.get_stat(condition["stat"])
	var target := int(condition["value"])
	match condition["op"]:
		"<":
			return current < target
		"<=":
			return current <= target
		">":
			return current > target
		">=":
			return current >= target
		"==":
			return current == target
	push_error("EventManager: неизвестный оператор '%s'" % condition["op"])
	return false


# ---------------------------------------------------------------------------
# Концовки
# ---------------------------------------------------------------------------

## true — концовка запущена.
func _check_endings() -> bool:
	for ending in endings:
		if _is_condition_met(ending):
			_ending = ending
			_ending_state = EndingState.PENDING
			_stop_all_events()
			ending_triggered.emit(ending["id"])
			# Отложенно: DialogueManager должен закончить обработку текущего выбора.
			_start_ending.call_deferred()
			return true
	return false


func _start_ending() -> void:
	_ending_state = EndingState.PLAYING
	if not DialogueManager.start_dialogue(_ending["node"]):
		# Узла финала нет в JSON — завершение без диалога.
		_complete_ending()


func _complete_ending() -> void:
	var scene_path: String = _ending.get("scene", "")
	GameManager.end_game(_ending["id"])
	if not scene_path.is_empty():
		get_tree().change_scene_to_file(scene_path)


# ---------------------------------------------------------------------------
# Ивенты с таймером
# ---------------------------------------------------------------------------

func _update_timed_events() -> void:
	for event in timed_events:
		var event_id: String = event["id"]
		if event.get("once", true) and GameManager.has_flag(_flag_name(event_id)):
			continue
		var met := _is_condition_met(event)
		if met and not _timers.has(event_id) and not _pending.has(event_id):
			_start_timer(event)
		elif not met and _timers.has(event_id):
			# Шкала вернулась выше порога до конца таймера — ивент отменён.
			_stop_timer(event_id)


func _start_timer(event: Dictionary) -> void:
	var event_id: String = event["id"]
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(float(event["delay"]), 0.05)  # Timer не принимает 0
	timer.timeout.connect(_on_timer_timeout.bind(event_id))
	add_child(timer)
	timer.start()
	_timers[event_id] = timer
	event_timer_started.emit(event_id, timer.wait_time, str(event.get("hint", "")))


func _stop_timer(event_id: String) -> void:
	var timer: Timer = _timers.get(event_id)
	if timer == null:
		return
	_timers.erase(event_id)
	timer.queue_free()
	event_timer_stopped.emit(event_id)


func _stop_all_events() -> void:
	for event_id in _timers.keys():
		_stop_timer(event_id)
	_pending.clear()


func _on_timer_timeout(event_id: String) -> void:
	_stop_timer(event_id)
	var event := _find_event(event_id)
	if event.is_empty() or not _is_condition_met(event):
		return
	if DialogueManager.is_active:
		# Текущий диалог не прерывается: ивент стартует после него.
		_pending.append(event_id)
	else:
		_fire_event(event)


func _fire_event(event: Dictionary) -> void:
	var event_id: String = event["id"]
	GameManager.set_flag(_flag_name(event_id))
	event_triggered.emit(event_id)
	DialogueManager.start_dialogue(event["node"])


func _on_dialogue_ended(_last_node_id: String) -> void:
	match _ending_state:
		EndingState.PLAYING:
			_complete_ending()
		EndingState.NONE:
			# Отложенно: UI должен успеть обработать окончание текущего диалога.
			_process_pending.call_deferred()
		EndingState.PENDING:
			pass  # финальный диалог стартует отложенно


func _process_pending() -> void:
	while not _pending.is_empty() and not DialogueManager.is_active:
		if GameManager.is_game_over or _ending_state != EndingState.NONE:
			_pending.clear()
			return
		var event := _find_event(_pending.pop_front())
		# Условие перепроверяется: за время диалога шкала могла восстановиться.
		if not event.is_empty() and _is_condition_met(event):
			_fire_event(event)


func _find_event(event_id: String) -> Dictionary:
	for event in timed_events:
		if event["id"] == event_id:
			return event
	return {}


func _flag_name(event_id: String) -> String:
	return "event_done_" + event_id


func _on_game_reset() -> void:
	_stop_all_events()
	_ending_state = EndingState.NONE
	_ending = {}
	_evaluate()
