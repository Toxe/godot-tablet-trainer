extends Node2D

enum DrawingArcDirection { none, CW, CCW }

const margin_screen_ratio := 0.15
const target_circle_line_width := 15
const target_circle_min_radius_screen_ratio := 0.1
const target_circle_max_radius_screen_ratio := 0.3

@export var precision_length_curve: Curve = null
@export var precision_coverage_curve: Curve = null
@export var precision_distance_sum_curve: Curve = null
@export var precision_distance_average_curve: Curve = null

var target_circle_position := Vector2i.ZERO
var target_circle_radius := 0.0
var prev_target_circle_position := Vector2i.ZERO
var prev_target_circle_radius := 0.0

var info_count_points := 0
var info_sum_distance_to_target := 0.0
var info_drawing_length := 0.0
var info_drawing_arc_direction := DrawingArcDirection.none
var info_drawing_arc_radius := 0.0
var info_drawing_arc_angle := 0.0
var info_drawing_arc_length := 0.0
var info_drawing_arc_revolutions := 0
var info_drawing_arc_position := Vector2.ZERO
var info_drawing_arc_first_point := Vector2.ZERO
var info_drawing_arc_last_point := Vector2.ZERO

var show_debug_info := false
var debug_lines: Node2D = null
var projected_circle_points: Array[Vector2] = []

@onready var drawing: Drawing = $Drawing
@onready var trainer_ui: TrainerUI = $TrainerUI
@onready var info_label: Label = $InfoLabel


func _ready() -> void:
    create_new_target_circle()

    reset_info_stats()
    update_info_label()


func _draw() -> void:
    # draw workspace rect and min/max circle radius
    if show_debug_info:
        const debug_line_width := 10
        const dark_gray := Color(0.25, 0.25, 0.25)

        var workspace := get_workspace()
        var margin := get_workspace_margin()
        var min_circle_radius := get_min_circle_radius()
        var max_circle_radius := get_max_circle_radius()
        var debug_circle_position := Vector2(margin + max_circle_radius, workspace.end.y - max_circle_radius)

        draw_rect(workspace, dark_gray, false, debug_line_width)
        draw_arc(debug_circle_position, min_circle_radius, 0.0, 2.0 * PI, 128, dark_gray, debug_line_width)
        draw_arc(debug_circle_position, max_circle_radius, 0.0, 2.0 * PI, 128, dark_gray, debug_line_width)

    # previous target circle
    draw_arc(prev_target_circle_position, prev_target_circle_radius, 0.0, 2.0 * PI, 128, Color(0.4, 0.4, 0.4), target_circle_line_width)

    # drawing arc
    if show_debug_info:
        if info_drawing_arc_direction != DrawingArcDirection.none:
            var start_angle := info_drawing_arc_position.angle_to_point(info_drawing_arc_first_point)
            var end_angle := start_angle + info_drawing_arc_angle + info_drawing_arc_revolutions * PI * (2.0 if info_drawing_arc_direction == DrawingArcDirection.CW else -2.0)

            draw_arc(info_drawing_arc_position, info_drawing_arc_radius, start_angle, end_angle, 128, Color.BLUE, target_circle_line_width)
            draw_line(info_drawing_arc_position, info_drawing_arc_first_point, Color.DARK_GREEN, 2)
            draw_line(info_drawing_arc_position, info_drawing_arc_last_point, Color.GREEN, 2)

    # target circle
    draw_arc(target_circle_position, target_circle_radius, 0.0, 2.0 * PI, 128, Color.WHITE, target_circle_line_width)

    # projected points on target circle
    if show_debug_info:
        for p in projected_circle_points:
            draw_arc(p, 5, 0, 2.0 * PI, 8, Color.BLUE)


func get_workspace_margin() -> int:
    var window_size := get_window().size
    return roundi(mini(window_size.x, window_size.y) * margin_screen_ratio)


func get_workspace() -> Rect2i:
    var window_size := get_window().size
    var margin := get_workspace_margin()
    return Rect2i(margin, margin, window_size.x - 2 * margin, window_size.y - 2 * margin)


func get_min_circle_radius() -> float:
    var rect := get_workspace()
    return mini(rect.size.x, rect.size.y) * target_circle_min_radius_screen_ratio


func get_max_circle_radius() -> float:
    var rect := get_workspace()
    return mini(rect.size.x, rect.size.y) * target_circle_max_radius_screen_ratio


func create_new_target_circle() -> void:
    var workspace := get_workspace()
    # var margin := get_workspace_margin()

    # target_circle_radius = randf_range(get_min_circle_radius(), get_max_circle_radius())
    target_circle_radius = get_max_circle_radius()

    # var x_min := int(margin + target_circle_radius)
    # var y_min := int(margin + target_circle_radius)
    # var x_max := int(workspace.end.x - target_circle_radius)
    # var y_max := int(workspace.end.y - target_circle_radius)

    # target_circle_position = Vector2i(randi_range(x_min, x_max), randi_range(y_min, y_max))
    target_circle_position = workspace.get_center()

    queue_redraw()


func reset_info_stats() -> void:
    info_count_points = 0
    info_sum_distance_to_target = 0.0
    info_drawing_length = 0.0
    info_drawing_arc_direction = DrawingArcDirection.none
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
    var total_arc_angle := absf(info_drawing_arc_angle + info_drawing_arc_revolutions * PI * (2.0 if info_drawing_arc_direction == DrawingArcDirection.CW else -2.0))

    info_label.text = "points: %d, sum distance to target circle: %d, average distance: %0.2f\ntarget circle circumference: %d\ndrawing length: %d, drawing length : target circle circumference = %.03f\ndrawing arc direction: %s, angle: %0.1f° (%0.2f%%)\ndrawing arc length: %d (%0.2f%%), %d revolutions" % [
        info_count_points, info_sum_distance_to_target, average_distance_to_target,
        target_circle_circumference,
        info_drawing_length, info_drawing_length / target_circle_circumference,
        DrawingArcDirection.find_key(info_drawing_arc_direction), rad_to_deg(total_arc_angle), 100.0 * total_arc_angle / (2 * PI),
        info_drawing_arc_length, 100.0 * info_drawing_arc_length / target_circle_circumference, info_drawing_arc_revolutions
    ]

    var length_factor := 0.0
    var coverage_factor := 0.0
    var distance_sum_factor := 0.0
    var distance_average_factor := 0.0

    if info_count_points > 0:
        # length
        # 0 ..   1 --> 0.0 .. 1.0
        # 1 .. >=2 --> 1.0 .. 0.0
        var length_curve_pos := clampf(info_drawing_length / (2.0 * target_circle_circumference), 0.0, 1.0)
        length_factor = precision_length_curve.sample(length_curve_pos)

        # coverage
        # 0 ..   1 --> 0.0 .. 1.0
        # 1 .. >=2 --> 1.0 .. 0.0
        var coverage_curve_pos := clampf(info_drawing_arc_length / (2.0 * target_circle_circumference), 0.0, 1.0)
        coverage_factor = precision_coverage_curve.sample(coverage_curve_pos)

        # distance
        var distance_sum_pos := clampf(info_sum_distance_to_target / (10.0 * target_circle_circumference), 0.0, 1.0)
        var distance_average_pos := clampf(average_distance_to_target / (target_circle_circumference / 10.0), 0.0, 1.0)
        distance_sum_factor = precision_distance_sum_curve.sample(distance_sum_pos)
        distance_average_factor = precision_distance_average_curve.sample(distance_average_pos)

    %LabelLengthFactor.text = "%0.3f" % length_factor
    %LabelCoverageFactor.text = "%0.3f" % coverage_factor
    %LabelDistanceSumFactor.text = "%0.3f" % distance_sum_factor
    %LabelDistanceAverageFactor.text = "%0.3f" % distance_average_factor
    %LabelPrecisionMulValue.text = "%0.3f" % [length_factor * coverage_factor * distance_sum_factor * distance_average_factor]
    %LabelPrecisionAddValue.text = "%0.3f" % [(length_factor + coverage_factor + distance_sum_factor + distance_average_factor) / 4.0]


func add_debug_line(point: Vector2) -> void:
    var direction_to_center := point.direction_to(target_circle_position)
    var distance_to_center := point.distance_to(target_circle_position)
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


func delete_debug_lines() -> void:
    if debug_lines:
        debug_lines.queue_free()
        debug_lines = null
        projected_circle_points.clear()
    if show_debug_info:
        queue_redraw()


func update_prev_target_circle() -> void:
    prev_target_circle_position = target_circle_position
    prev_target_circle_radius = target_circle_radius


func is_new_point_for_arc(arc_direction: DrawingArcDirection, angle_start_to_end: float, angle_drawing_arc_last_point_to_end_point: float) -> bool:
    if arc_direction == DrawingArcDirection.CW:
        return angle_start_to_end > 0.0 and angle_drawing_arc_last_point_to_end_point > 0.0
    else:
        return angle_start_to_end < 0.0 and angle_drawing_arc_last_point_to_end_point < 0.0


func relative_to_absolute_arc_angle(arc_direction: DrawingArcDirection, relative_arc_angle: float) -> float:
    var absolute_arc_angle := relative_arc_angle

    if arc_direction == DrawingArcDirection.CW and relative_arc_angle < 0.0:
        absolute_arc_angle += 2.0 * PI
    elif arc_direction == DrawingArcDirection.CCW and relative_arc_angle > 0.0:
        absolute_arc_angle -= 2.0 * PI

    return absolute_arc_angle


func is_bigger_than_drawing_arc_angle(arc_direction: DrawingArcDirection, absolute_arc_angle: float, drawing_arc_angle: float) -> float:
    if arc_direction == DrawingArcDirection.CW:
        return absolute_arc_angle > drawing_arc_angle
    else:
        return absolute_arc_angle < drawing_arc_angle


func has_finished_one_revolution(arc_direction: DrawingArcDirection, relative_arc_angle: float, prev_relative_arc_angle: float) -> bool:
    if arc_direction == DrawingArcDirection.CW:
        return relative_arc_angle >= 0.0 and prev_relative_arc_angle < 0.0
    else:
        return relative_arc_angle <= 0.0 and prev_relative_arc_angle > 0.0


func _on_drawing_started() -> void:
    reset_info_stats()
    update_info_label()

    delete_debug_lines()


func _on_drawing_stopped() -> void:
    update_prev_target_circle()
    create_new_target_circle()


func _on_drawing_point_added(point: Vector2i) -> void:
    var distance_to_center := Vector2(point).distance_to(target_circle_position)

    info_count_points += 1
    info_sum_distance_to_target += absf(target_circle_radius - distance_to_center)

    add_debug_line(point)

    update_info_label()


func _on_drawing_segment_added(start_point: Vector2i, end_point: Vector2i) -> void:
    info_drawing_length += Vector2(start_point).distance_to(end_point)

    if info_drawing_arc_direction == DrawingArcDirection.none:
        info_drawing_arc_radius = target_circle_radius * 0.75
        info_drawing_arc_position = target_circle_position
        info_drawing_arc_first_point = start_point
        info_drawing_arc_last_point = end_point

        var dir_to_start_point := info_drawing_arc_position.direction_to(start_point)
        var dir_to_end_point := info_drawing_arc_position.direction_to(end_point)
        var angle_start_to_end := dir_to_start_point.angle_to(dir_to_end_point)

        info_drawing_arc_direction = DrawingArcDirection.CW if angle_start_to_end >= 0.0 else DrawingArcDirection.CCW
        info_drawing_arc_angle = angle_start_to_end
    else:
        assert(info_drawing_arc_direction in [DrawingArcDirection.CW, DrawingArcDirection.CCW])

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
