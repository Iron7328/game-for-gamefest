extends Node
## Глобальное состояние игры.
## Регистрация: Project Settings → Globals → Autoload, имя "GameManager" (первым в списке).
## Шкалы менять ТОЛЬКО через методы (set_stats / change_stats / apply_choice):
## прямое присваивание не отправит сигналы, и UI/ивенты не узнают об изменении.

## Изменилась шкала ментального здоровья (для UI).
signal mental_health_changed(new_value: int, old_value: int)
## Изменилась шкала отношений с родителями (для UI).
signal parents_relationship_changed(new_value: int, old_value: int)
## Общий сигнал: один раз после любого изменения, когда обе шкалы уже обновлены (для ивентов).
signal stats_changed(mental_health: int, parents_relationship: int)
## Новая игра: состояние сброшено к начальному.
signal game_reset
## Игра завершена концовкой ending_id.
signal game_over(ending_id: String)

## Тип ответа в диалоге.
enum ChoiceType { POSITIVE, NEUTRAL, NEGATIVE }

const STAT_MIN := 0
const STAT_MAX := 100
## Шаг изменения шкал при позитивном/негативном ответе.
const CHOICE_DELTA := 10

const START_MENTAL_HEALTH := 50
const START_PARENTS_RELATIONSHIP := 50

## Имена шкал: используются в EventManager и в поле "effects" файла dialogues.json.
const STAT_MENTAL_HEALTH := "mental_health"
const STAT_PARENTS_RELATIONSHIP := "parents_relationship"

var mental_health: int = START_MENTAL_HEALTH
var parents_relationship: int = START_PARENTS_RELATIONSHIP
## Сюжетные флаги: просмотренные ивенты, принятые решения и т.п.
var flags: Dictionary = {}
var is_game_over := false


## Стандартный эффект ответа по его типу.
func apply_choice(choice_type: ChoiceType) -> void:
	match choice_type:
		ChoiceType.POSITIVE:
			# Угождает родителям ценой себя.
			change_stats(-CHOICE_DELTA, CHOICE_DELTA)
		ChoiceType.NEGATIVE:
			# Защищает себя ценой отношений.
			change_stats(CHOICE_DELTA, -CHOICE_DELTA)
		ChoiceType.NEUTRAL:
			pass


## Изменить шкалы на заданные величины (могут быть отрицательными).
func change_stats(mental_delta: int, relationship_delta: int) -> void:
	set_stats(mental_health + mental_delta, parents_relationship + relationship_delta)


## Установить шкалы. Значения ограничиваются диапазоном [STAT_MIN, STAT_MAX].
func set_stats(new_mental: int, new_relationship: int) -> void:
	var old_mental := mental_health
	var old_relationship := parents_relationship
	mental_health = clampi(new_mental, STAT_MIN, STAT_MAX)
	parents_relationship = clampi(new_relationship, STAT_MIN, STAT_MAX)

	var changed := false
	if mental_health != old_mental:
		mental_health_changed.emit(mental_health, old_mental)
		changed = true
	if parents_relationship != old_relationship:
		parents_relationship_changed.emit(parents_relationship, old_relationship)
		changed = true
	# Общий сигнал — один раз и уже после обновления обеих шкал.
	if changed:
		stats_changed.emit(mental_health, parents_relationship)


## Значение шкалы по имени (STAT_MENTAL_HEALTH / STAT_PARENTS_RELATIONSHIP).
func get_stat(stat_name: String) -> int:
	match stat_name:
		STAT_MENTAL_HEALTH:
			return mental_health
		STAT_PARENTS_RELATIONSHIP:
			return parents_relationship
	push_error("GameManager: неизвестная шкала '%s'" % stat_name)
	return 0


func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value


func has_flag(flag: String) -> bool:
	return flags.has(flag)


func get_flag(flag: String, default_value: Variant = null) -> Variant:
	return flags.get(flag, default_value)


## Зафиксировать окончание игры (вызывается из EventManager).
func end_game(ending_id: String) -> void:
	if is_game_over:
		return
	is_game_over = true
	game_over.emit(ending_id)


## Новая игра: сброс шкал и флагов.
func reset_game() -> void:
	flags.clear()
	is_game_over = false
	set_stats(START_MENTAL_HEALTH, START_PARENTS_RELATIONSHIP)
	game_reset.emit()
