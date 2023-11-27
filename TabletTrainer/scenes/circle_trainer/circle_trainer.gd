extends Node2D

const margin_screen_ratio := 0.1
const target_circle_line_width := 15
const target_circle_min_radius_screen_ratio := 0.1
const target_circle_max_radius_screen_ratio := 0.3

var target_circle_position := Vector2.ZERO
var target_circle_radius := 0.0
var old_target_circle_position := Vector2.ZERO
var old_target_circle_radius := 0.0

var info_count_points := 0
var info_sum_distance_to_target := 0.0
var info_drawing_length := 0.0

var debug_lines: Node2D = null
var last_debug_line: Line2D = null

@onready var drawing: Drawing = $Drawing
@onready var trainer_ui: TrainerUI = $TrainerUI
@onready var info_label: Label = $InfoLabel


func _ready() -> void:
    create_new_target_circle()

    reset_info_stats()
    update_info_label()


func _draw() -> void:
    draw_arc(old_target_circle_position, old_target_circle_radius, 0.0, 2.0 * PI, 128, Color(0.4, 0.4, 0.4), target_circle_line_width)
    draw_arc(target_circle_position, target_circle_radius, 0.0, 2.0 * PI, 128, Color.WHITE, target_circle_line_width)


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


func reset_info_stats() -> void:
    info_count_points = 0
    info_sum_distance_to_target = 0.0
    info_drawing_length = 0.0


func update_info_label() -> void:
    var average_distance_to_target := (info_sum_distance_to_target / info_count_points) if info_count_points > 0 else 0.0
    var target_circle_circumference := 2.0 * PI * target_circle_radius

    info_label.text = "points: %d, sum distance to target circle: %d, average distance: %0.2f\ntarget circle circumference: %d\ndrawing length: %d, drawing length : target circle circumference = %.03f" % [
        info_count_points, info_sum_distance_to_target, average_distance_to_target,
        target_circle_circumference,
        info_drawing_length, info_drawing_length / target_circle_circumference,
    ]


func add_debug_line(point: Vector2) -> Line2D:
    var direction_to_center := point.direction_to(target_circle_position)
    var distance_to_center := point.distance_to(target_circle_position)
    var distance_to_circle := absf(target_circle_radius - distance_to_center)

    # add a new container for the debug lines
    if debug_lines == null:
        debug_lines = Node2D.new()
        debug_lines.name = "debug_lines"
        add_child(debug_lines)

    var line := Line2D.new()
    line.width = 1
    line.default_color = Color.YELLOW if distance_to_center >= target_circle_radius else Color.ORANGE
    line.add_point(point)
    line.add_point(point + direction_to_center * (distance_to_center - target_circle_radius))
    debug_lines.add_child(line)

    var debug_line_normal := Vector2(-direction_to_center.y, direction_to_center.x)

    var label := Label.new()
    label.text = "%d" % [distance_to_circle]
    label.position = point
    label.position += direction_to_center * -10.0 + debug_line_normal * label.size.y / 2.0
    label.rotation = line.points[1].angle_to_point(line.points[0])
    label.z_index = 1
    line.add_child(label)

    return line


func delete_debug_lines() -> void:
    if debug_lines:
        debug_lines.queue_free()
        queue_redraw()


func update_old_target_circle() -> void:
    old_target_circle_position = target_circle_position
    old_target_circle_radius = target_circle_radius


func _on_drawing_started(_point: Vector2) -> void:
    reset_info_stats()
    update_info_label()

    delete_debug_lines()


func _on_drawing_stopped(_point: Vector2) -> void:
    update_old_target_circle()
    create_new_target_circle()


func _on_drawing_point_added(point: Vector2) -> void:
    var distance_to_center := point.distance_to(target_circle_position)

    info_count_points += 1
    info_sum_distance_to_target += absf(target_circle_radius - distance_to_center)

    last_debug_line = add_debug_line(point)

    update_info_label()


func _on_drawing_line_drawn(start_point: Vector2, end_point: Vector2) -> void:
    info_drawing_length += start_point.distance_to(end_point)
