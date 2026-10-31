#extends TextureProgressBar
#
## Автоматически находим Label внутри нашей полоски
#@onready var value_label = $Label
#
#func _ready():
	## Подключаем встроенный сигнал полоски к нашей функции
	#value_changed.connect(_on_value_changed)
	#
	## Сразу вызываем функцию один раз, чтобы текст появился при старте
	#_on_value_changed(value)
#
### Эта функция будет срабатывать каждый раз, когда меняется value
##func _on_value_changed(new_value):
	### Переводим число из float (дробного) в int (целое) и пишем в текст
	##value_label.text = str(int(new_value))
