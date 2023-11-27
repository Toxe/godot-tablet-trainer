extends CanvasLayer

const line_trainer_scene = preload("res://scenes/line_trainer/line_trainer.tscn")
const circle_trainer_scene = preload("res://scenes/circle_trainer/circle_trainer.tscn")


func _unhandled_key_input(event: InputEvent) -> void:
    if event.is_action_pressed("quit"):
        get_tree().quit()


func _on_lines_button_pressed() -> void:
    get_tree().change_scene_to_packed(line_trainer_scene)


func _on_circles_button_pressed() -> void:
    get_tree().change_scene_to_packed(circle_trainer_scene)
