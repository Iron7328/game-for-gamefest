extends Area2D

# ID диалога из вашего файла dialogues.json (с какого узла начать)
@export var dialogue_start_node: String = "day1_001"

func _ready():
	# Подключаем сигнал клика мышкой по зоне
	input_event.connect(_on_input_event)
	# Подключаем сигналы наведения мыши для смены курсора
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

# Обработка клика по NPC
func _on_input_event(_viewport, event, _shape_idx):
	# Проверяем, что событие — это клик мышкой
	print("КЛИК ПО NPC СРАБОТАЛ!")
	if event is InputEventMouseButton:
		# Проверяем, что нажата Левая Кнопка Мыши (ЛКМ) и именно нажатие
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Если сейчас нет активного диалога, запускаем наш
			if not DialogueManager.is_active:
				DialogueManager.start_dialogue(dialogue_start_node)

# Когда мышка наводится на NPC
func _on_mouse_entered():
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

# Когда мышка уходит с NPC
func _on_mouse_exited():
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
