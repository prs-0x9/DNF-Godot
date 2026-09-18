@tool
class_name TrackGenerator
extends Path3D
## Procedural track surface for DNF. Attach to a Path3D and draw the curve in
## the editor — a CSGPolygon3D road (with collision) is extruded along it and
## kept in sync as you move points. The generated child is transient (not saved
## into the scene); it is rebuilt in _ready at runtime too.

const SURFACE_NAME := "TrackSurface"

@export var track_width: float = 14.0:
	set(value):
		track_width = maxf(value, 0.1)
		_request_rebuild()

@export var track_thickness: float = 0.5:
	set(value):
		track_thickness = maxf(value, 0.05)
		_request_rebuild()

## Join the last curve point back to the first (circuit). Leave off for
## point-to-point stages.
@export var closed_loop: bool = true:
	set(value):
		closed_loop = value
		_request_rebuild()

## Distance in meters between extrusion slices. Smaller = smoother corners,
## more triangles.
@export var slice_interval: float = 2.0:
	set(value):
		slice_interval = maxf(value, 0.1)
		_request_rebuild()

@export var surface_material: Material:
	set(value):
		surface_material = value
		_request_rebuild()

@export_tool_button("Rebuild Track") var _rebuild_button := rebuild

var _rebuild_queued := false


func _ready() -> void:
	if Engine.is_editor_hint() and not curve_changed.is_connected(_request_rebuild):
		# Live-update while dragging curve points in the editor.
		curve_changed.connect(_request_rebuild)
	rebuild()


## Coalesces bursts of changes (setters + curve edits) into one rebuild.
func _request_rebuild() -> void:
	if _rebuild_queued or not is_node_ready():
		return
	_rebuild_queued = true
	rebuild.call_deferred()


func rebuild() -> void:
	_rebuild_queued = false
	if curve == null or curve.point_count < 2:
		return

	var surface := get_node_or_null(SURFACE_NAME) as CSGPolygon3D
	if surface == null:
		surface = CSGPolygon3D.new()
		surface.name = SURFACE_NAME
		add_child(surface)

	# Road cross-section in the XY plane (counter-clockwise), top surface at
	# y = 0 so the curve you draw sits exactly on the asphalt.
	var half_w := track_width * 0.5
	surface.polygon = PackedVector2Array([
		Vector2(-half_w, -track_thickness),
		Vector2(half_w, -track_thickness),
		Vector2(half_w, 0.0),
		Vector2(-half_w, 0.0),
	])

	surface.mode = CSGPolygon3D.MODE_PATH
	surface.path_node = surface.get_path_to(self)
	surface.path_local = true
	surface.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
	surface.path_interval = slice_interval
	# PATH_FOLLOW respects each curve point's Tilt, so corners can be banked
	# by rotating the green tilt handles in the editor.
	surface.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
	surface.path_joined = closed_loop
	surface.smooth_faces = true
	surface.use_collision = true
	surface.material = surface_material
