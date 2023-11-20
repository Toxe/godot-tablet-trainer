extends Node2D

const margin_screen_ratio := 0.1
const target_line_width := 15
const target_line_min_length_screen_ratio := 0.2

@onready var drawing: Drawing = $Drawing
@onready var trainer_ui: TrainerUI = $TrainerUI
@onready var target_line: Line2D = $TargetLine


func _ready() -> void:
    create_new_target_line()


func create_new_target_line() -> void:
    var window_size := get_window().size
    var margin: float = min(window_size.x, window_size.y) * margin_screen_ratio

    var min_line_length: float = min(window_size.x, window_size.y) * target_line_min_length_screen_ratio

    var x_min := margin
    var y_min := margin
    var x_max := window_size.x - margin
    var y_max := window_size.y - margin

    var p0 := Vector2(randf_range(x_min, x_max), randf_range(y_min, y_max))
    var p1 := Vector2.ZERO

    while true:
        p1 = Vector2(randf_range(x_min, x_max), randf_range(y_min, y_max))
        if p0.distance_to(p1) >= min_line_length:
            break

    target_line.clear_points()
    target_line.add_point(p0)
    target_line.add_point(p1)


func _on_drawing_started() -> void:
    for child in get_children():
        if child is Line2D and child != target_line:
            child.queue_free()


func _on_drawing_stopped() -> void:
    create_new_target_line()


func _on_drawing_point_added(point: Vector2) -> void:
    var p0 := target_line.points[0] + target_line.position as Vector2
    var p1 := target_line.points[1] + target_line.position as Vector2
    var dvec := p0.direction_to(p1)
    var N := Vector2(dvec.y, -dvec.x)
    var D := N.dot(p0)
    var distance := N.dot(point) - D

    var point_on_plane := point - N * distance
    var debug_line := Line2D.new()
    debug_line.width = 1
    debug_line.default_color = Color.GREEN
    debug_line.add_point(point)
    debug_line.add_point(point_on_plane)
    add_child(debug_line)

    var dist_p0_to_p1 := p0.distance_to(p1)
    var dist_p0_to_point_on_plane := p0.distance_to(point_on_plane)
    var dist_p1_to_point_on_plane := p1.distance_to(point_on_plane)

    if dist_p0_to_point_on_plane > dist_p0_to_p1:
        debug_line.default_color = Color.RED
        debug_line.points[1] = p1
    elif dist_p1_to_point_on_plane > dist_p0_to_p1:
        debug_line.default_color = Color.RED
        debug_line.points[1] = p0
