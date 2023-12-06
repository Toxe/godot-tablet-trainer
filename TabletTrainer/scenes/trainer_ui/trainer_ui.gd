class_name TrainerUI extends CanvasLayer

signal toggle_debug_info(should_show_debug_info: bool)

var is_drawing := false
var show_debug_info := false

var start_time := 0.0
var end_time := 0.0

@onready var time_label: Label = $TimeLabel


func _process(_delta: float) -> void:
    if is_drawing:
        update_end_time()


func update_start_time() -> void:
    start_time = Time.get_ticks_msec()
    update_time_label()


func update_end_time() -> void:
    end_time = Time.get_ticks_msec()
    update_time_label()


func update_time_label() -> void:
    time_label.text = "Time: %d msecs" % [end_time - start_time]


func _on_quit_button_pressed() -> void:
    get_tree().change_scene_to_packed(load("res://scenes/main_menu/main_menu.tscn"))


func _on_toggle_debug_info_button_pressed() -> void:
    show_debug_info = !show_debug_info
    toggle_debug_info.emit(show_debug_info)


func _on_drawing_started(_point: Vector2) -> void:
    is_drawing = true
    update_start_time()


func _on_drawing_stopped(_point: Vector2) -> void:
    is_drawing = false
    update_end_time()
