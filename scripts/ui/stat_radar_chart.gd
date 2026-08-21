extends Control

# Compact five-axis radar chart for the RPG's core attributes.
# The largest comparable attribute defines the chart scale and therefore always
# touches the outer ring. Only attribute icons are drawn around the chart;
# numeric values stay in the surrounding UI.
#
# IMPORTANT: Max HP uses a different runtime formula from the other four stats:
#   max_hp = scaled_base + level + 10
#   other  = scaled_base + 5
# For the radar only, HP is therefore converted back onto the same comparison
# scale with max_hp - level - 5. This is exact for every level with the current
# stat formulas (including level 50+); the real displayed/battle HP is untouched.

const STAT_KEYS: Array[String] = ["max_hp", "attack", "defense", "special", "speed"]
const STAT_ICONS: Array[String] = ["❤️", "⚔️", "🛡️", "🔮", "⚡"]
const RING_COUNT: int = 4

var _values: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var _scale_max: float = 1.0


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)
    queue_redraw()


func set_stats(stats: Dictionary, level: int = 0) -> void:
    var next_values: Array[float] = []
    for key: String in STAT_KEYS:
        var value: float = maxf(0.0, float(stats.get(key, 0.0)))
        if key == "max_hp" and level > 0:
            value = _radar_hp(value, level)
        next_values.append(value)
    _set_values(next_values)


func set_values(values: Array) -> void:
    var next_values: Array[float] = []
    for index: int in range(STAT_KEYS.size()):
        var value: float = 0.0
        if index < values.size():
            value = maxf(0.0, float(values[index]))
        next_values.append(value)
    _set_values(next_values)


func scale_max() -> float:
    return _scale_max


func _radar_hp(max_hp: float, level: int) -> float:
    # Runtime HP: scaled_base + level + 10
    # Runtime other stats: scaled_base + 5
    # Removing level + 5 from HP leaves scaled_base + 5, i.e. exactly the
    # comparison scale used by Attack, Defense, Special and Speed.
    return maxf(0.0, max_hp - float(maxi(1, level)) - 5.0)


func _set_values(values: Array[float]) -> void:
    _values = values.duplicate()
    _scale_max = 1.0
    for value: float in _values:
        _scale_max = maxf(_scale_max, value)
    queue_redraw()


func _draw() -> void:
    if size.x < 40.0 or size.y < 40.0:
        return

    var center := Vector2(size.x * 0.5, size.y * 0.5)
    var half_width: float = maxf(0.0, size.x * 0.5 - 22.0)
    var half_height: float = maxf(0.0, size.y * 0.5 - 18.0)
    var radius: float = maxf(10.0, minf(half_width, half_height) * 0.92)

    var grid_color := Color(0.62, 0.85, 0.76, 0.25)
    var axis_color := Color(0.62, 0.85, 0.76, 0.36)
    var fill_color := Color(1.0, 0.90, 0.46, 0.22)
    var outline_color := Color(1.0, 0.90, 0.46, 0.92)

    for ring: int in range(1, RING_COUNT + 1):
        var ratio: float = float(ring) / float(RING_COUNT)
        var ring_points: Array[Vector2] = []
        for axis: int in range(STAT_KEYS.size()):
            ring_points.append(_point_for_axis(center, radius, axis, ratio))
        draw_polyline(_closed_points(ring_points), grid_color, 1.0, true)

    for axis: int in range(STAT_KEYS.size()):
        draw_line(center, _point_for_axis(center, radius, axis, 1.0), axis_color, 1.0, true)

    var data_points: Array[Vector2] = []
    for axis: int in range(STAT_KEYS.size()):
        var ratio: float = clampf(_values[axis] / _scale_max, 0.0, 1.0)
        data_points.append(_point_for_axis(center, radius, axis, ratio))

    if data_points.size() >= 3:
        draw_colored_polygon(PackedVector2Array(data_points), fill_color)
        draw_polyline(_closed_points(data_points), outline_color, 2.0, true)

    var font: Font = get_theme_default_font()
    var icon_distance: float = radius * 1.32
    for axis: int in range(STAT_ICONS.size()):
        var icon_pos: Vector2 = _point_for_axis(center, icon_distance, axis, 1.0)
        draw_string(
            font,
            Vector2(icon_pos.x - 16.0, icon_pos.y + 6.0),
            STAT_ICONS[axis],
            HORIZONTAL_ALIGNMENT_CENTER,
            32.0,
            16,
            Color.WHITE
        )


func _point_for_axis(center: Vector2, radius: float, axis: int, ratio: float) -> Vector2:
    var angle: float = -PI * 0.5 + TAU * float(axis) / float(STAT_KEYS.size())
    return center + Vector2(cos(angle), sin(angle)) * radius * ratio


func _closed_points(points: Array[Vector2]) -> PackedVector2Array:
    var result := PackedVector2Array()
    for point: Vector2 in points:
        result.append(point)
    if not points.is_empty():
        result.append(points[0])
    return result