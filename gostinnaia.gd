extends Node2D


func _ready() -> void:
	await get_tree().process_frame
	var spawn_name = GameState.spawn_point_name
	
	if spawn_name != "":
		var marker = get_node_or_null("Spawns/" + spawn_name)
		var player = get_tree().get_first_node_in_group("player")
		
		if marker == null:
			print("ОШИБКА: Не найден маркер с именем ", spawn_name, ". Проверьте папку Spawns и имя узла!")
		elif player == null:
			print("ОШИБКА: Игрок не найден! Проверьте, добавлен ли он в группу 'player' в новой сцене.")
		else:
			player.global_position = marker.global_position
			print("УСПЕХ: Игрок перемещен!")
			
		GameState.spawn_point_name = ""
