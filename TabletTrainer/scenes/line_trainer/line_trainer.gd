extends Node2D

const margin_screen_ratio := 0.1
const target_line_width := 15
const target_line_min_length_screen_ratio := 0.2

var info_points_count := 0
var info_points_distance := 0.0
var info_drawing_length := 0.0
var info_line_coverage_points_inside := 0
var info_line_coverage_points_outside := 0
var info_covered_length_inside := 0.0
var info_covered_length_outside := 0.0

var debug_lines: Node2D = null
var last_debug_line: Line2D = null
var projected_line_points: Array[Dictionary] = []

@onready var drawing: Drawing = $Drawing
@onready var trainer_ui: TrainerUI = $TrainerUI
@onready var target_line: Line2D = $TargetLine
@onready var old_target_line: Line2D = $OldTargetLine
@onready var info_label: Label = $InfoLabel


func _ready() -> void:
    create_new_target_line()

    reset_info_stats()
    update_info_label()


func _draw() -> void:
    for p in projected_line_points:
        draw_arc(p.point, 5, 0, 2.0 * PI, 8, p.color)


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


func reset_info_stats() -> void:
    info_points_count = 0
    info_points_distance = 0.0
    info_drawing_length = 0.0
    info_line_coverage_points_inside = 0
    info_line_coverage_points_outside = 0
    info_covered_length_inside = 0.0
    info_covered_length_outside = 0.0


func update_info_label() -> void:
    var target_line_length := target_line.points[0].distance_to(target_line.points[1])

    info_label.text = "points: %d, distance: %d, average: %0.2f\ntarget line length: %d\ndrawing length: %d, drawing : target = %.03f\nline coverage: %d points inside, %d points outside\ncovered length: %d inside + %d outside = %d\ncovered length, inside : target = %0.3f, outside : target = %0.3f" % [
        info_points_count, info_points_distance, (info_points_distance / info_points_count) if info_points_count > 0 else 0.0,
        target_line_length,
        info_drawing_length, info_drawing_length / target_line_length,
        info_line_coverage_points_inside, info_line_coverage_points_outside,
        info_covered_length_inside, info_covered_length_outside, info_covered_length_inside + info_covered_length_outside,
        (info_covered_length_inside / target_line_length) if info_points_count > 0 else 0.0, (info_covered_length_outside / target_line_length) if info_points_count > 0 else 0.0
    ]


func add_debug_line(point: Vector2) -> Line2D:
    var p0 := target_line.points[0]
    var p1 := target_line.points[1]
    var point_on_line := project_point_onto_line(point, target_line)

    # add a new container for the debug lines
    if debug_lines == null:
        debug_lines = Node2D.new()
        debug_lines.name = "debug_lines"
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

    # color of the first debug line (additional debug lines will be colored in _on_drawing_line_drawn())
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
    var debug_line_direction := line.points[1].direction_to(line.points[0])
    var debug_line_normal := Vector2(debug_line_direction.y, -debug_line_direction.x)

    var label := Label.new()
    label.text = "%d" % [distance_from_point_to_line]
    label.position = point
    label.position += debug_line_direction * 10.0 + debug_line_normal * label.size.y / 2.0
    label.rotation = line.points[1].angle_to_point(line.points[0])
    label.z_index = 1
    line.add_child(label)

    return line


func delete_debug_lines() -> void:
    if debug_lines:
        debug_lines.queue_free()
        projected_line_points.clear()
        queue_redraw()


func update_old_target_line(line: Line2D) -> void:
    old_target_line.clear_points()
    old_target_line.add_point(line.points[0])
    old_target_line.add_point(line.points[1])


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


func _on_drawing_started(_point: Vector2) -> void:
    reset_info_stats()
    update_info_label()

    delete_debug_lines()


func _on_drawing_stopped(_point: Vector2) -> void:
    update_old_target_line(target_line)
    create_new_target_line()


func _on_drawing_point_added(point: Vector2) -> void:
    var point_on_line := project_point_onto_line(point, target_line)
    var distance_point_to_target_line := point.distance_to(point_on_line)

    info_points_count += 1
    info_points_distance += distance_point_to_target_line
    info_drawing_length += 1.0

    if point_inside_line(point_on_line, target_line):
        info_line_coverage_points_inside += 1
    else:
        info_line_coverage_points_outside += 1

    last_debug_line = add_debug_line(point)


func _on_drawing_line_drawn(start_point: Vector2, end_point: Vector2) -> void:
    assert(last_debug_line != null)

    var p0 := target_line.points[0]
    var p1 := target_line.points[1]

    info_drawing_length += start_point.distance_to(end_point)

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
    queue_redraw()

    update_info_label()
