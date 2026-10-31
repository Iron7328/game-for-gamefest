extends Area2D

@export_file("res://gostinnaia.tscn") var target_scene_path: String
@export var target_spawn_name: String = "DefaultSpawn"
var player_in_range: bool = false

func _on_body_entered(body: Node2D) -> void:
 GameState.spawn_point_name = target_spawn_name
 if body.is_in_group("player"):
  player_in_range = true


func _on_body_exited(body: Node2D) -> void:
 if body.is_in_group("player"):
  player_in_range = false

func _process(_delta: float) -> void:
 if player_in_range and Input.is_action_just_pressed("Lmb"):
  GameState.spawn_point_name = target_spawn_name
  get_tree().change_scene_to_file("res://gostinnaia.tscn")
