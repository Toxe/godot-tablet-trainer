extends Node2D

const margin_screen_ratio := 0.1
const target_circle_line_width := 15
const target_circle_min_radius_screen_ratio := 0.1
const target_circle_max_radius_screen_ratio := 0.3

var target_circle_position := Vector2.ZERO
var target_circle_radius := 0.0

@onready var drawing: Drawing = $Drawing
@onready var trainer_ui: TrainerUI = $TrainerUI


func _ready() -> void:
    create_new_target_circle()


func create_new_target_circle() -> void:
    var window_size := get_window().size
    var margin: float = min(window_size.x, window_size.y) * margin_screen_ratio

    var min_radius: float = min(window_size.x, window_size.y) * target_circle_min_radius_screen_ratio
    var max_radius: float = min(window_size.x, window_size.y) * target_circle_max_radius_screen_ratio
    target_circle_radius = randf_range(min_radius, max_radius)

    var x_min := margin + target_circle_radius
    var y_min := margin + target_circle_radius
    var x_max := window_size.x - (margin + target_circle_radius)
    var y_max := window_size.y - (margin + target_circle_radius)

    target_circle_position = Vector2(randf_range(x_min, x_max), randf_range(y_min, y_max))

    queue_redraw()


func _draw() -> void:
    draw_arc(target_circle_position, target_circle_radius, 0.0, 2.0 * PI, 128, Color.WHITE, target_circle_line_width)


func _on_drawing_started() -> void:
    for child in get_children():
        if child is Line2D:
            child.queue_free()


func _on_drawing_stopped() -> void:
    create_new_target_circle()


func _on_drawing_point_added(point: Vector2) -> void:
    var direction_to_center := point.direction_to(target_circle_position)
    var distance_to_center := point.distance_to(target_circle_position)

    var debug_line := Line2D.new()
    debug_line.width = 1
    debug_line.default_color = Color.GREEN
    debug_line.add_point(point)
    debug_line.add_point(point + direction_to_center * (distance_to_center - target_circle_radius))
    add_child(debug_line)
