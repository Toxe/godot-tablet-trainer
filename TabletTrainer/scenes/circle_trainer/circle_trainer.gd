extends Node2D

const margin_screen_ratio := 0.15
const target_circle_line_width := 15
const target_circle_min_radius_screen_ratio := 0.1
const target_circle_max_radius_screen_ratio := 0.3

var target_circle_position := Vector2.ZERO
var target_circle_radius := 0.0
var prev_target_circle_position := Vector2.ZERO
var prev_target_circle_radius := 0.0

var info_count_points := 0
var info_sum_distance_to_target := 0.0
var info_drawing_length := 0.0
var info_drawing_arc_direction := "--"
var info_drawing_arc_radius := 0.0
var info_drawing_arc_angle := 0.0
var info_drawing_arc_length := 0.0
var info_drawing_arc_revolutions := 0
var info_drawing_arc_position := Vector2.ZERO
var info_drawing_arc_first_point := Vector2.ZERO
var info_drawing_arc_last_point := Vector2.ZERO

var show_debug_info := false
var debug_lines: Node2D = null
var last_debug_line: Line2D = null
var projected_circle_points: Array[Vector2] = []

@onready var drawing: Drawing = $Drawing
@onready var trainer_ui: TrainerUI = $TrainerUI
@onready var info_label: Label = $InfoLabel


func _ready() -> void:
    create_new_target_circle()

    reset_info_stats()
    update_info_label()


func _draw() -> void:
    draw_arc(prev_target_circle_position, prev_target_circle_radius, 0.0, 2.0 * PI, 128, Color(0.4, 0.4, 0.4), target_circle_line_width)
    draw_arc(target_circle_position, target_circle_radius, 0.0, 2.0 * PI, 128, Color.WHITE, target_circle_line_width)

    if show_debug_info:
        const debug_line_width := 10
        const dark_gray := Color(0.25, 0.25, 0.25)
        var workspace := get_workspace()

        # draw workspace rect
        draw_rect(workspace, dark_gray, false, debug_line_width)

        # draw min and max circle radius
        var margin := get_workspace_margin()
        var min_circle_radius := get_min_circle_radius()
        var max_circle_radius := get_max_circle_radius()
        var debug_circle_position := Vector2(margin + max_circle_radius, workspace.end.y - max_circle_radius)

        draw_arc(debug_circle_position, min_circle_radius, 0.0, 2.0 * PI, 128, dark_gray, debug_line_width)
        draw_arc(debug_circle_position, max_circle_radius, 0.0, 2.0 * PI, 128, dark_gray, debug_line_width)

        # projected points on target circle
        for p in projected_circle_points:
            draw_arc(p, 5, 0, 2.0 * PI, 8, Color.BLUE)

        # drawing arc
        if info_drawing_arc_direction != "--":
            var start_angle := info_drawing_arc_position.angle_to_point(info_drawing_arc_first_point)
            var end_angle := start_angle + info_drawing_arc_angle + info_drawing_arc_revolutions * PI * (2.0 if info_drawing_arc_direction == "CW" else -2.0)

            draw_arc(info_drawing_arc_position, info_drawing_arc_radius, start_angle, end_angle, 128, Color.BLUE, target_circle_line_width)

            draw_line(info_drawing_arc_position, info_drawing_arc_first_point, Color.DARK_GREEN, 2)
            draw_line(info_drawing_arc_position, info_drawing_arc_last_point, Color.GREEN, 2)


func get_workspace_margin() -> float:
    var window_size := get_window().size
    return mini(window_size.x, window_size.y) * margin_screen_ratio


func get_workspace() -> Rect2:
    var window_size := get_window().size
    var margin := get_workspace_margin()
    return Rect2(margin, margin, window_size.x - 2 * margin, window_size.y - 2 * margin)


func get_min_circle_radius() -> float:
    var rect := get_workspace()
    return minf(rect.size.x, rect.size.y) * target_circle_min_radius_screen_ratio


func get_max_circle_radius() -> float:
    var rect := get_workspace()
    return minf(rect.size.x, rect.size.y) * target_circle_max_radius_screen_ratio


func create_new_target_circle() -> void:
    var workspace := get_workspace()
    var margin := get_workspace_margin()

    target_circle_radius = randf_range(get_min_circle_radius(), get_max_circle_radius())

    var x_min := margin + target_circle_radius
    var y_min := margin + target_circle_radius
    var x_max := workspace.end.x - target_circle_radius
    var y_max := workspace.end.y - target_circle_radius

    target_circle_position = Vector2(randf_range(x_min, x_max), randf_range(y_min, y_max))

    queue_redraw()


func reset_info_stats() -> void:
    info_count_points = 0
    info_sum_distance_to_target = 0.0
    info_drawing_length = 0.0
    info_drawing_arc_direction = "--"
    info_drawing_arc_radius = 0.0
    info_drawing_arc_angle = 0.0
    info_drawing_arc_length = 0.0
    info_drawing_arc_revolutions = 0
    info_drawing_arc_position = Vector2.ZERO
    info_drawing_arc_first_point = Vector2.ZERO
    info_drawing_arc_last_point = Vector2.ZERO


func update_info_label() -> void:
    var average_distance_to_target := (info_sum_distance_to_target / info_count_points) if info_count_points > 0 else 0.0
    var target_circle_circumference := 2.0 * PI * target_circle_radius
    var total_arc_angle := absf(info_drawing_arc_angle + info_drawing_arc_revolutions * PI * (2.0 if info_drawing_arc_direction == "CW" else -2.0))

    info_label.text = "points: %d, sum distance to target circle: %d, average distance: %0.2f\ntarget circle circumference: %d\ndrawing length: %d, drawing length : target circle circumference = %.03f\ndrawing arc direction: %s, angle: %0.1f° (%0.2f%%)\ndrawing arc length: %d (%0.2f%%), %d revolutions" % [
        info_count_points, info_sum_distance_to_target, average_distance_to_target,
        target_circle_circumference,
        info_drawing_length, info_drawing_length / target_circle_circumference,
        info_drawing_arc_direction, rad_to_deg(total_arc_angle), 100.0 * total_arc_angle / (2 * PI),
        info_drawing_arc_length, 100.0 * info_drawing_arc_length / target_circle_circumference, info_drawing_arc_revolutions
    ]


func add_debug_line(point: Vector2) -> Line2D:
    var direction_to_center := point.direction_to(target_circle_position)
    var distance_to_center := point.distance_to(target_circle_position)
    var distance_to_circle := absf(target_circle_radius - distance_to_center)
    var point_on_circle := point + direction_to_center * (distance_to_center - target_circle_radius)

    # add a new container for the debug lines
    if debug_lines == null:
        debug_lines = Node2D.new()
        debug_lines.name = "debug_lines"
        debug_lines.visible = show_debug_info
        add_child(debug_lines)

    var line := Line2D.new()
    line.width = 1
    line.default_color = Color.YELLOW if distance_to_center >= target_circle_radius else Color.ORANGE
    line.add_point(point)
    line.add_point(point_on_circle)
    debug_lines.add_child(line)

    projected_circle_points.append(point_on_circle)

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
        debug_lines = null
        last_debug_line = null
        projected_circle_points.clear()
    if show_debug_info:
        queue_redraw()


func update_prev_target_circle() -> void:
    prev_target_circle_position = target_circle_position
    prev_target_circle_radius = target_circle_radius


func is_new_point_for_arc(arc_direction: String, angle_start_to_end: float, angle_drawing_arc_last_point_to_end_point: float) -> bool:
    if arc_direction == "CW":
        return angle_start_to_end > 0.0 and angle_drawing_arc_last_point_to_end_point > 0.0
    else:
        return angle_start_to_end < 0.0 and angle_drawing_arc_last_point_to_end_point < 0.0


func relative_to_absolute_arc_angle(arc_direction: String, relative_arc_angle: float) -> float:
    var absolute_arc_angle := relative_arc_angle

    if arc_direction == "CW" and relative_arc_angle < 0.0:
        absolute_arc_angle += 2.0 * PI
    elif arc_direction == "CCW" and relative_arc_angle > 0.0:
        absolute_arc_angle -= 2.0 * PI

    return absolute_arc_angle


func is_bigger_than_drawing_arc_angle(arc_direction: String, absolute_arc_angle: float, drawing_arc_angle: float) -> float:
    if arc_direction == "CW":
        return absolute_arc_angle > drawing_arc_angle
    else:
        return absolute_arc_angle < drawing_arc_angle


func has_finished_one_revolution(arc_direction: String, relative_arc_angle: float, prev_relative_arc_angle: float) -> bool:
    if arc_direction == "CW":
        return relative_arc_angle >= 0.0 and prev_relative_arc_angle < 0.0
    else:
        return relative_arc_angle <= 0.0 and prev_relative_arc_angle > 0.0


func _on_drawing_started(_point: Vector2) -> void:
    reset_info_stats()
    update_info_label()

    delete_debug_lines()


func _on_drawing_stopped(_point: Vector2) -> void:
    update_prev_target_circle()
    create_new_target_circle()


func _on_drawing_point_added(point: Vector2) -> void:
    var distance_to_center := point.distance_to(target_circle_position)

    info_count_points += 1
    info_sum_distance_to_target += absf(target_circle_radius - distance_to_center)

    last_debug_line = add_debug_line(point)

    update_info_label()


func _on_drawing_segment_added(start_point: Vector2, end_point: Vector2) -> void:
    info_drawing_length += start_point.distance_to(end_point)

    if info_drawing_arc_direction == "--":
        info_drawing_arc_radius = target_circle_radius * 0.75
        info_drawing_arc_position = target_circle_position
        info_drawing_arc_first_point = start_point
        info_drawing_arc_last_point = end_point

        var dir_to_start_point := info_drawing_arc_position.direction_to(start_point)
        var dir_to_end_point := info_drawing_arc_position.direction_to(end_point)
        var angle_start_to_end := dir_to_start_point.angle_to(dir_to_end_point)

        if angle_start_to_end >= 0.0:
            info_drawing_arc_direction = "CW"
        else:
            info_drawing_arc_direction = "CCW"

        info_drawing_arc_angle = angle_start_to_end
    else:
        assert(info_drawing_arc_direction in ["CW", "CCW"])

        var prev_dir_to_drawing_arc_first_point := info_drawing_arc_position.direction_to(info_drawing_arc_first_point)
        var prev_dir_to_drawing_arc_last_point := info_drawing_arc_position.direction_to(info_drawing_arc_last_point)
        var prev_relative_arc_angle := prev_dir_to_drawing_arc_first_point.angle_to(prev_dir_to_drawing_arc_last_point)

        var dir_to_start_point := info_drawing_arc_position.direction_to(start_point)
        var dir_to_end_point := info_drawing_arc_position.direction_to(end_point)
        var angle_start_to_end := dir_to_start_point.angle_to(dir_to_end_point)

        var dir_to_drawing_arc_first_point := info_drawing_arc_position.direction_to(info_drawing_arc_first_point)
        var dir_to_drawing_arc_last_point := info_drawing_arc_position.direction_to(info_drawing_arc_last_point)
        var angle_drawing_arc_last_point_to_end_point := dir_to_drawing_arc_last_point.angle_to(dir_to_end_point)

        info_drawing_arc_last_point = end_point
        dir_to_drawing_arc_last_point = info_drawing_arc_position.direction_to(info_drawing_arc_last_point)

        var relative_arc_angle := dir_to_drawing_arc_first_point.angle_to(dir_to_drawing_arc_last_point)

        if is_new_point_for_arc(info_drawing_arc_direction, angle_start_to_end, angle_drawing_arc_last_point_to_end_point):
            var target_circle_circumference := 2.0 * PI * target_circle_radius
            var absolute_arc_angle := relative_to_absolute_arc_angle(info_drawing_arc_direction, relative_arc_angle)

            if is_bigger_than_drawing_arc_angle(info_drawing_arc_direction, absolute_arc_angle, info_drawing_arc_angle):
                info_drawing_arc_angle = absolute_arc_angle
                info_drawing_arc_length = target_circle_circumference * (absf(info_drawing_arc_angle) + info_drawing_arc_revolutions * 2.0 * PI) / (2.0 * PI)
            elif has_finished_one_revolution(info_drawing_arc_direction, relative_arc_angle, prev_relative_arc_angle):
                info_drawing_arc_revolutions += 1
                info_drawing_arc_angle = absolute_arc_angle
                info_drawing_arc_length = target_circle_circumference * (absf(info_drawing_arc_angle) + info_drawing_arc_revolutions * 2.0 * PI) / (2.0 * PI)

    if show_debug_info:
        queue_redraw()


func _on_trainer_ui_toggle_debug_info(should_show_debug_info: bool) -> void:
    show_debug_info = should_show_debug_info
    if debug_lines:
        debug_lines.visible = show_debug_info
    queue_redraw()


func _on_trainer_ui_toggle_stats(should_show_stats: bool) -> void:
    info_label.visible = should_show_stats
