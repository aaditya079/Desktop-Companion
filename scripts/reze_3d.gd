extends Node3D

var model: Node3D = null
var mesh: MeshInstance3D = null
var skel: Skeleton3D = null

var head_bone_idx: int = -1
var neck_bone_idx: int = -1
var eye_bone_idx: int = -1
var spine_bone_idx: int = -1
var r_arm_idx: int = -1
var l_arm_idx: int = -1
var r_elbow_idx: int = -1
var l_elbow_idx: int = -1

var blink_shape_idx: int = -1
var mouth_shape_idx: int = -1
var smile_shape_idx: int = -1
var blush_shape_idx: int = -1

# Animation state
var anim_time: float = 0.0
var blink_timer: float = 3.5
var is_blinking: bool = false
var blink_progress: float = 0.0

var is_speaking: bool = false
var mouth_open_amount: float = 0.0

# Mouse gaze tracking
var target_head_yaw: float = 0.0
var target_head_pitch: float = 0.0
var current_head_yaw: float = 0.0
var current_head_pitch: float = 0.0

var q_r_arm: Quaternion = Quaternion.IDENTITY
var q_l_arm: Quaternion = Quaternion.IDENTITY

func _ready() -> void:
	_find_nodes(self)
	
	if not skel:
		printerr("[Reze3D] Skeleton3D not found!")
		return
	
	head_bone_idx = skel.find_bone("頭")
	neck_bone_idx = skel.find_bone("首")
	eye_bone_idx = skel.find_bone("両目")
	spine_bone_idx = skel.find_bone("上半身")
	r_arm_idx = skel.find_bone("右腕")
	l_arm_idx = skel.find_bone("左腕")
	r_elbow_idx = skel.find_bone("右ひじ")
	l_elbow_idx = skel.find_bone("左ひじ")
	
	if mesh:
		blink_shape_idx = mesh.find_blend_shape_by_name("まばたき")
		mouth_shape_idx = mesh.find_blend_shape_by_name("あ")
		smile_shape_idx = mesh.find_blend_shape_by_name("笑い")
		blush_shape_idx = mesh.find_blend_shape_by_name("照れ")
		
		# Set baseline charming expression
		if smile_shape_idx != -1:
			mesh.set_blend_shape_value(smile_shape_idx, 0.15)
		if blush_shape_idx != -1:
			mesh.set_blend_shape_value(blush_shape_idx, 0.35)
	
	# Natural resting arm pose along sides
	q_r_arm = Quaternion(Vector3.FORWARD, deg_to_rad(-55.0)) * Quaternion(Vector3.UP, deg_to_rad(-10.0))
	q_l_arm = Quaternion(Vector3.FORWARD, deg_to_rad(55.0)) * Quaternion(Vector3.UP, deg_to_rad(10.0))

func _find_nodes(node: Node) -> void:
	if not skel and node is Skeleton3D:
		skel = node
	if not mesh and node is MeshInstance3D:
		mesh = node
	for c in node.get_children():
		_find_nodes(c)

func update_gaze_target(mouse_screen_pos: Vector2, window_center: Vector2) -> void:
	var diff = mouse_screen_pos - window_center
	var nx = clampf(diff.x / 500.0, -1.0, 1.0)
	var ny = clampf(diff.y / 500.0, -1.0, 1.0)
	
	target_head_yaw = -nx * 0.35
	target_head_pitch = -ny * 0.20

func set_speaking(speaking: bool) -> void:
	is_speaking = speaking

func _process(delta: float) -> void:
	if not skel:
		return
		
	anim_time += delta
	
	# Smoothly interpolate head gaze
	current_head_yaw = lerpf(current_head_yaw, target_head_yaw, delta * 6.0)
	current_head_pitch = lerpf(current_head_pitch, target_head_pitch, delta * 6.0)
	
	# 1. Breathing motion (spine)
	var breath = sin(anim_time * 2.0) * 0.015
	if spine_bone_idx != -1:
		skel.set_bone_pose_rotation(spine_bone_idx, Quaternion(Vector3.RIGHT, breath * 0.5))
	
	# 2. Gaze tracking (head bone & eyes)
	if head_bone_idx != -1:
		var head_rot = Quaternion(Vector3.UP, current_head_yaw) * Quaternion(Vector3.RIGHT, current_head_pitch + breath)
		skel.set_bone_pose_rotation(head_bone_idx, head_rot)
		
	if eye_bone_idx != -1:
		var eye_rot = Quaternion(Vector3.UP, current_head_yaw * 0.5) * Quaternion(Vector3.RIGHT, current_head_pitch * 0.5)
		skel.set_bone_pose_rotation(eye_bone_idx, eye_rot)
		
	# Keep arms posed naturally along sides
	if r_arm_idx != -1:
		skel.set_bone_pose_rotation(r_arm_idx, q_r_arm)
	if l_arm_idx != -1:
		skel.set_bone_pose_rotation(l_arm_idx, q_l_arm)
		
	# 3. Eye blinking
	blink_timer -= delta
	if blink_timer <= 0.0:
		is_blinking = true
		blink_progress = 0.0
		blink_timer = randf_range(3.0, 4.8)
		
	if is_blinking:
		blink_progress += delta * 7.5
		var blink_val = sin(clampf(blink_progress, 0.0, 1.0) * PI)
		if blink_shape_idx != -1 and mesh:
			mesh.set_blend_shape_value(blink_shape_idx, blink_val)
		if blink_progress >= 1.0:
			is_blinking = false
			if blink_shape_idx != -1 and mesh:
				mesh.set_blend_shape_value(blink_shape_idx, 0.0)
				
	# 4. Mouth flap when speaking
	if mesh and mouth_shape_idx != -1:
		if is_speaking:
			mouth_open_amount = absf(sin(anim_time * 16.0)) * 0.75
		else:
			mouth_open_amount = lerpf(mouth_open_amount, 0.0, delta * 12.0)
		mesh.set_blend_shape_value(mouth_shape_idx, mouth_open_amount)
