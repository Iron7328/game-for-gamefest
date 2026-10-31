extends CanvasLayer

# Ссылки на наши узлы (мы прописали пути точно по вашему дереву сцены)
@onready var dialogue_text: RichTextLabel = $Control/DialoguePanel/VBoxContainer/DialogueText
@onready var choices_container: VBoxContainer = $Control/DialoguePanel/VBoxContainer/ChoicesContainer
@onready var choice_buttons = [
	$Control/DialoguePanel/VBoxContainer/ChoicesContainer/Choice1,
	$Control/DialoguePanel/VBoxContainer/ChoicesContainer/Choice2,
	$Control/DialoguePanel/VBoxContainer/ChoicesContainer/Choice3
]

func _ready():
	# Прячем окно при старте игры
	hide()
	
	# Подключаем сигналы нажатия на кнопки
	for i in range(3):
		choice_buttons[i].pressed.connect(_on_choice_pressed.bind(i))

# Функция для показа диалога
func show_dialogue(text: String, choices: Array):
	show() # Показываем панель
	dialogue_text.text = text
	
	for i in range(3):
		if i < choices.size():
			choice_buttons[i].text = choices[i]
			choice_buttons[i].show()
		else:
			choice_buttons[i].hide()

# Что происходит при нажатии на кнопку
func _on_choice_pressed(index: int):
	hide() # Скрываем окно после выбора
	print("Игрок выбрал вариант: ", index) 
	# В будущем тут будет передача выбора в GameManager
