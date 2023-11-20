extends CanvasLayer

const line_trainer_scene = preload("res://scenes/line_trainer/line_trainer.tscn")
const circle_trainer_scene = preload("res://scenes/circle_trainer/circle_trainer.tscn")


func _ready() -> void:
    create_window_title_update_timer()
    update_window_title()


func _unhandled_key_input(event: InputEvent) -> void:
    if event.is_action_pressed("quit"):
        get_tree().quit()


func create_window_title_update_timer() -> void:
    var timer := Timer.new()
    add_child(timer)
    timer.timeout.connect(update_window_title)
    timer.start(1.0)


func update_window_title() -> void:
    get_window().title = "%s [v%s, %d FPS]" % [ProjectSettings.get_setting("application/config/name"), ProjectSettings.get_setting("application/config/version"), Performance.get_monitor(Performance.TIME_FPS)]


func _on_lines_button_pressed() -> void:
    get_tree().change_scene_to_packed(line_trainer_scene)


func _on_circles_button_pressed() -> void:
    get_tree().change_scene_to_packed(circle_trainer_scene)
