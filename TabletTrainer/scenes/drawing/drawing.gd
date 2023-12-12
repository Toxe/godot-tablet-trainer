class_name Drawing extends Node2D

signal started(point: Vector2i)
signal stopped(point: Vector2i)
signal point_added(point: Vector2i)
signal segment_added(start_point: Vector2i, end_point: Vector2i)

var is_drawing := false
var line: Line2D = null


func _unhandled_input(event: InputEvent) -> void:
    var mouse_motion_event := event as InputEventMouseMotion
    if mouse_motion_event:
        if is_drawing:
            if mouse_motion_event.button_mask & MOUSE_BUTTON_MASK_LEFT:
                add_point(mouse_motion_event.position)
            else:
                stop_drawing(mouse_motion_event)
        else:
            if mouse_motion_event.button_mask & MOUSE_BUTTON_MASK_LEFT:
                start_drawing(mouse_motion_event)


func start_drawing(mouse_motion_event: InputEventMouseMotion) -> void:
    assert(!is_drawing)

    is_drawing = true

    if line:
        line.queue_free()

    line = Line2D.new()
    line.width = 5
    line.default_color = Color.BLACK
    add_child(line)

    started.emit(mouse_motion_event.position)

    add_point(mouse_motion_event.position)


func stop_drawing(mouse_motion_event: InputEventMouseMotion) -> void:
    assert(is_drawing)
    assert(line != null)

    if not mouse_motion_event.relative.is_zero_approx():
        add_point(mouse_motion_event.position)

    is_drawing = false

    stopped.emit(mouse_motion_event.position)


func add_point(point: Vector2) -> void:
    assert(is_drawing)
    assert(line != null)

    line.add_point(point)

    point_added.emit(point)

    if line.get_point_count() > 1:
        segment_added.emit(line.points[-2], point)
