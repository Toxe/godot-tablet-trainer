extends Node2D

const margin_screen_ratio := 0.15
const target_line_min_length_workspace_ratio := 0.5
const target_line_max_length_workspace_ratio := 2.0

var info_count_points := 0
var info_sum_distance_to_target := 0.0
var info_drawing_length := 0.0
var info_line_coverage_points_inside := 0
var info_line_coverage_points_outside := 0
var info_covered_length_inside := 0.0
var info_covered_length_outside := 0.0

var show_debug_info := false
var debug_lines: Node2D = null
var last_debug_line: Line2D = null
var projected_line_points: Array[Dictionary] = []

@onready var drawing: Drawing = $Drawing
@onready var trainer_ui: TrainerUI = $TrainerUI
@onready var target_line: Line2D = $TargetLine
@onready var prev_target_line: Line2D = $OldTargetLine
@onready var info_label: Label = $InfoLabel


func _ready() -> void:
    create_new_target_line()

    reset_info_stats()
    update_info_label()


func _draw() -> void:
    if show_debug_info:
        const debug_line_width := 10
        const dark_gray := Color(0.25, 0.25, 0.25)
        var workspace := get_workspace()

        # draw workspace rect
        draw_rect(workspace, dark_gray, false, debug_line_width)

        # draw min and max target line lengths
        var margin := get_workspace_margin()
        var workspace_center := workspace.get_center()
        var min_line_length := get_min_line_length()
        var max_line_length := get_max_line_length()
        var min_max_lines_center_y := workspace.end.y + margin / 2.0

        draw_line(Vector2(workspace_center.x - min_line_length / 2.0, min_max_lines_center_y - 15), Vector2(workspace_center.x + min_line_length / 2.0, min_max_lines_center_y - 15), dark_gray, debug_line_width)
        draw_line(Vector2(workspace_center.x - max_line_length / 2.0, min_max_lines_center_y + 15), Vector2(workspace_center.x + max_line_length / 2.0, min_max_lines_center_y + 15), dark_gray, debug_line_width)

        # projected points on target line
        for p in projected_line_points:
            draw_arc(p.point, 5, 0, 2.0 * PI, 8, p.color)


func get_workspace_margin() -> int:
    var window_size := get_window().size
    return roundi(mini(window_size.x, window_size.y) * margin_screen_ratio)


func get_workspace() -> Rect2i:
    var window_size := get_window().size
    var margin := get_workspace_margin()
    return Rect2i(margin, margin, window_size.x - 2 * margin, window_size.y - 2 * margin)


func get_min_line_length() -> float:
    var rect := get_workspace()
    return minf(rect.size.x, rect.size.y) * target_line_min_length_workspace_ratio


func get_max_line_length() -> float:
    var rect := get_workspace()
    return minf(rect.size.x, rect.size.y) * target_line_max_length_workspace_ratio


func create_new_target_line() -> void:
    var workspace := get_workspace()
    var min_line_length := get_min_line_length()
    var max_line_length := get_max_line_length()

    var calc_random_point_in_workspace := func() -> Vector2i: return Vector2i(randi_range(workspace.position.x, workspace.end.x), randi_range(workspace.position.y, workspace.end.y))
    var p0: Vector2i = calc_random_point_in_workspace.call()
    var p1: Vector2i = calc_random_point_in_workspace.call()

    while Vector2(p0).distance_to(p1) < min_line_length or Vector2(p0).distance_to(p1) > max_line_length:
        p1 = calc_random_point_in_workspace.call()

    target_line.clear_points()
    target_line.add_point(p0)
    target_line.add_point(p1)


func reset_info_stats() -> void:
    info_count_points = 0
    info_sum_distance_to_target = 0.0
    info_drawing_length = 0.0
    info_line_coverage_points_inside = 0
    info_line_coverage_points_outside = 0
    info_covered_length_inside = 0.0
    info_covered_length_outside = 0.0


func update_info_label() -> void:
    var average_distance_to_target := (info_sum_distance_to_target / info_count_points) if info_count_points > 0 else 0.0
    var target_line_length := target_line.points[0].distance_to(target_line.points[1])
    var covered_target_length_ratio_inside := (info_covered_length_inside / target_line_length) if info_count_points > 0 else 0.0
    var covered_target_length_ratio_outside := (info_covered_length_outside / target_line_length) if info_count_points > 0 else 0.0

    info_label.text = "points: %d, sum distance to target line: %d, average distance: %0.2f\ntarget line length: %d\ndrawing length: %d, drawing length : target line length = %.03f\nline coverage: %d points inside, %d points outside\ncovered target length: %d inside + %d outside = %d\ncovered target length, inside : target = %0.3f, outside : target = %0.3f" % [
        info_count_points, info_sum_distance_to_target, average_distance_to_target,
        target_line_length,
        info_drawing_length, info_drawing_length / target_line_length,
        info_line_coverage_points_inside, info_line_coverage_points_outside,
        info_covered_length_inside, info_covered_length_outside, info_covered_length_inside + info_covered_length_outside,
        covered_target_length_ratio_inside, covered_target_length_ratio_outside
    ]


func add_debug_line(point: Vector2) -> Line2D:
    var p0 := target_line.points[0]
    var p1 := target_line.points[1]
    var point_on_line := project_point_onto_line(point, target_line)

    # add a new container for the debug lines
    if debug_lines == null:
        debug_lines = Node2D.new()
        debug_lines.name = "debug_lines"
        debug_lines.visible = show_debug_info
        add_child(debug_lines)

    var line := Line2D.new()
    line.width = 1
    line.add_point(point)
    line.add_point(point_on_line)
    debug_lines.add_child(line)

    # draw the debug line to the start/end of the line if the point is before/after the line
    if point_before_line(point_on_line, target_line):
        line.points[1] = p0
    elif point_behind_line(point_on_line, target_line):
        line.points[1] = p1

    # color of the first debug line (additional debug lines will be colored in _on_drawing_segment_added())
    if last_debug_line == null:
        if point_inside_line(point_on_line, target_line):
            line.default_color = Color.GREEN
        elif point_before_line(point_on_line, target_line):
            line.default_color = Color.ORANGE
        elif point_behind_line(point_on_line, target_line):
            line.default_color = Color.YELLOW
        else:
            push_warning("Unable to determine projected line point position:\nline: %s --> %s, point: %s" % [p0, p1, point_on_line])
            line.default_color = Color.RED

        projected_line_points.append({"point": point_on_line, "color": line.default_color})

    var distance_from_point_to_line := point.distance_to(point_on_line)
    var debug_line_direction := line.points[0].direction_to(line.points[1])
    var debug_line_normal := Vector2(-debug_line_direction.y, debug_line_direction.x)

    var label := Label.new()
    label.text = "%d" % [distance_from_point_to_line]
    label.position = point
    label.position += debug_line_direction * -10.0 + debug_line_normal * label.size.y / 2.0
    label.rotation = line.points[1].angle_to_point(line.points[0])
    label.z_index = 1
    line.add_child(label)

    return line


func delete_debug_lines() -> void:
    if debug_lines:
        debug_lines.queue_free()
        debug_lines = null
        last_debug_line = null
        projected_line_points.clear()
    if show_debug_info:
        queue_redraw()


func update_prev_target_line(line: Line2D) -> void:
    prev_target_line.clear_points()
    prev_target_line.add_point(line.points[0])
    prev_target_line.add_point(line.points[1])


func project_point_onto_line(point: Vector2, line: Line2D) -> Vector2:
    var p0 := line.points[0]
    var p1 := line.points[1]
    var direction := p0.direction_to(p1)
    var normal := Vector2(direction.y, -direction.x)
    var distance_from_origin_to_line := normal.dot(p0)
    var distance_from_point_to_line := normal.dot(point) - distance_from_origin_to_line
    return point - normal * distance_from_point_to_line


func point_inside_line(point_on_line: Vector2, line: Line2D) -> bool:
    var p0 := line.points[0]
    var p1 := line.points[1]
    var dist_p0_to_p1 := p0.distance_to(p1)
    var dist_p0_to_point := p0.distance_to(point_on_line)
    var dist_p1_to_point := p1.distance_to(point_on_line)
    return dist_p0_to_point <= dist_p0_to_p1 and dist_p1_to_point <= dist_p0_to_p1


func point_before_line(point_on_line: Vector2, line: Line2D) -> bool:
    var p0 := line.points[0]
    var p1 := line.points[1]
    var dist_p0_to_p1 := p0.distance_to(p1)
    var dist_p0_to_point := p0.distance_to(point_on_line)
    var dist_p1_to_point := p1.distance_to(point_on_line)
    return dist_p0_to_point < dist_p1_to_point and dist_p1_to_point > dist_p0_to_p1


func point_behind_line(point_on_line: Vector2, line: Line2D) -> bool:
    var p0 := line.points[0]
    var p1 := line.points[1]
    var dist_p0_to_p1 := p0.distance_to(p1)
    var dist_p0_to_point := p0.distance_to(point_on_line)
    var dist_p1_to_point := p1.distance_to(point_on_line)
    return dist_p1_to_point < dist_p0_to_point and dist_p0_to_point > dist_p0_to_p1


func _on_drawing_started(_point: Vector2i) -> void:
    reset_info_stats()
    update_info_label()

    delete_debug_lines()


func _on_drawing_stopped(_point: Vector2i) -> void:
    update_prev_target_line(target_line)
    create_new_target_line()


func _on_drawing_point_added(point: Vector2i) -> void:
    var point_on_line := project_point_onto_line(point, target_line)
    var distance_point_to_target_line := Vector2(point).distance_to(point_on_line)

    info_count_points += 1
    info_sum_distance_to_target += distance_point_to_target_line

    if point_inside_line(point_on_line, target_line):
        info_line_coverage_points_inside += 1
    else:
        info_line_coverage_points_outside += 1

    last_debug_line = add_debug_line(point)


func _on_drawing_segment_added(start_point: Vector2i, end_point: Vector2i) -> void:
    assert(last_debug_line != null)

    var p0 := target_line.points[0]
    var p1 := target_line.points[1]

    info_drawing_length += Vector2(start_point).distance_to(end_point)

    # ---- covered length inside/outside
    var a := project_point_onto_line(start_point, target_line)
    var b := project_point_onto_line(end_point, target_line)

    var dist_a_to_b := a.distance_to(b)
    var dist_p0_to_a := p0.distance_to(a)
    var dist_p1_to_a := p1.distance_to(a)
    var dist_p0_to_b := p0.distance_to(b)
    var dist_p1_to_b := p1.distance_to(b)

    if point_before_line(a, target_line) and point_before_line(b, target_line):
        # a and b left of line
        info_covered_length_outside += dist_a_to_b
        last_debug_line.default_color = Color.ORANGE
    elif point_before_line(a, target_line) and point_inside_line(b, target_line):
        # a left of line, b inside
        info_covered_length_inside += dist_p0_to_b
        info_covered_length_outside += dist_p0_to_a
        last_debug_line.default_color = Color.BLUE
    elif point_inside_line(a, target_line) and point_inside_line(b, target_line):
        # a and b inside
        info_covered_length_inside += dist_a_to_b
        last_debug_line.default_color = Color.GREEN
    elif point_inside_line(a, target_line) and point_behind_line(b, target_line):
        # a inside, b right of line
        info_covered_length_inside += dist_p1_to_a
        info_covered_length_outside += dist_p1_to_b
        last_debug_line.default_color = Color.TURQUOISE
    elif point_behind_line(a, target_line) and point_behind_line(b, target_line):
        # a and b right of line
        info_covered_length_outside += dist_a_to_b
        last_debug_line.default_color = Color.YELLOW
    elif point_behind_line(a, target_line) and point_inside_line(b, target_line):  # <--
        # a right of line, b inside
        info_covered_length_inside += dist_p1_to_b
        info_covered_length_outside += dist_p1_to_a
        last_debug_line.default_color = Color.DARK_MAGENTA
    elif point_inside_line(a, target_line) and point_before_line(b, target_line):  # <--
        # a inside, b left of line
        info_covered_length_inside += dist_p0_to_a
        info_covered_length_outside += dist_p0_to_b
        last_debug_line.default_color = Color.MAGENTA
    else:
        push_warning("Unable to determine projected line points positions:\nline: %s --> %s, prev point: %s, new point: %s" % [p0, p1, a, b])
        last_debug_line.default_color = Color.RED

    projected_line_points.append({"point": b, "color": last_debug_line.default_color})

    if show_debug_info:
        queue_redraw()

    update_info_label()


func _on_trainer_ui_toggle_debug_info(should_show_debug_info: bool) -> void:
    show_debug_info = should_show_debug_info
    if debug_lines:
        debug_lines.visible = show_debug_info
    queue_redraw()


func _on_trainer_ui_toggle_stats(should_show_stats: bool) -> void:
    info_label.visible = should_show_stats
