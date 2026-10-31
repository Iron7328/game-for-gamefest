extends CanvasLayer
## UI: шкалы (левый нижний угол), окно диалога (правый верхний угол), таймер ивента.
## Узлы, к которым идёт обращение через %, должны иметь флаг "Access as Unique Name"
## (ПКМ по узлу в дереве сцены → Access as Unique Name).

## Запустить диалог со start_node при загрузке сцены.
@export var auto_start_dialogue := true
## Длительность анимации изменения шкал в секундах (0 — без анимации).
@export var bar_tween_time := 0.3

@onready var _mental_bar: TextureProgressBar = %MentalHealthBar
@onready var _relationship_bar: TextureProgressBar = %RelationshipBar
@onready var _dialogue_panel: PanelContainer = %DialoguePanel
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _dialogue_text: RichTextLabel = %DialogueText
@onready var _choice_buttons: Array[Button] = [%ChoiceButton1, %ChoiceButton2, %ChoiceButton3]
@onready var _event_label: Label = %EventLabel

var _bar_tweens: Dictionary = {}  # TextureProgressBar -> Tween
var _tracked_event_id := ""       # ивент, чей таймер показан в EventLabel
var _tracked_event_hint := ""


func _ready() -> void:
	# --- Шкалы: диапазон и начальные значения берутся из GameManager ---
	for bar: TextureProgressBar in [_mental_bar, _relationship_bar]:
		bar.min_value = GameManager.STAT_MIN
		bar.max_value = GameManager.STAT_MAX
	_mental_bar.value = GameManager.mental_health
	_relationship_bar.value = GameManager.parents_relationship
	GameManager.mental_health_changed.connect(_on_mental_health_changed)
	GameManager.parents_relationship_changed.connect(_on_parents_relationship_changed)

	# --- Диалог: кнопка i → DialogueManager.choose(i) ---
	for i in _choice_buttons.size():
		_choice_buttons[i].pressed.connect(_on_choice_pressed.bind(i))
	DialogueManager.node_shown.connect(_on_node_shown)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	_dialogue_panel.hide()

	# --- Таймер ивента ---
	EventManager.event_timer_started.connect(_on_event_timer_started)
	EventManager.event_timer_stopped.connect(_on_event_timer_stopped)
	_event_label.hide()
	set_process(false)

	if auto_start_dialogue:
		DialogueManager.start_dialogue()


func _process(_delta: float) -> void:
	# Обратный отсчёт видимого ивента (включается только пока таймер идёт).
	var time_left: float = EventManager.get_time_left(_tracked_event_id)
	_event_label.text = "%s %d" % [_tracked_event_hint, ceili(time_left)]


func _unhandled_input(event: InputEvent) -> void:
	# Выбор ответа клавишами 1–3.
	if not _dialogue_panel.visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var index: int = key.keycode - KEY_1
	if index >= 0 and index < _choice_buttons.size() and _choice_buttons[index].visible:
		get_viewport().set_input_as_handled()
		_on_choice_pressed(index)


# ---------------------------------------------------------------------------
# Диалог
# ---------------------------------------------------------------------------

func _on_node_shown(node: Dictionary) -> void:
	var speaker: String = node["speaker"]
	_speaker_label.text = speaker
	_speaker_label.visible = not speaker.is_empty()
	_dialogue_text.text = node["text"]

	# Вариантов может быть 1–3: лишние кнопки скрываются.
	var choices: Array = node["choices"]
	for i in _choice_buttons.size():
		var button := _choice_buttons[i]
		if i < choices.size():
			button.text = "%d. %s" % [i + 1, choices[i]["text"]]
			button.show()
		else:
			button.hide()

	_dialogue_panel.show()
	# Фокус на первый вариант — для клавиатуры/геймпада.
	if not choices.is_empty():
		_choice_buttons[0].grab_focus()


func _on_dialogue_ended(_last_node_id: String) -> void:
	_dialogue_panel.hide()


func _on_choice_pressed(index: int) -> void:
	DialogueManager.choose(index)


# ---------------------------------------------------------------------------
# Шкалы
# ---------------------------------------------------------------------------

func _on_mental_health_changed(new_value: int, _old_value: int) -> void:
	_animate_bar(_mental_bar, new_value)


func _on_parents_relationship_changed(new_value: int, _old_value: int) -> void:
	_animate_bar(_relationship_bar, new_value)


func _animate_bar(bar: TextureProgressBar, target: int) -> void:
	var previous: Tween = _bar_tweens.get(bar)
	if previous != null and previous.is_valid():
		previous.kill()
	if bar_tween_time <= 0.0:
		bar.value = target
		return
	var tween := create_tween()
	tween.tween_property(bar, "value", float(target), bar_tween_time)
	_bar_tweens[bar] = tween


# ---------------------------------------------------------------------------
# Ивенты
# ---------------------------------------------------------------------------

func _on_event_timer_started(event_id: String, _duration: float, hint: String) -> void:
	if hint.is_empty():
		return  # скрытый ивент — таймер не показывается
	_tracked_event_id = event_id
	_tracked_event_hint = hint
	_event_label.show()
	set_process(true)


func _on_event_timer_stopped(event_id: String) -> void:
	if event_id != _tracked_event_id:
		return
	_tracked_event_id = ""
	_event_label.hide()
	set_process(false)
