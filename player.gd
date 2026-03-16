extends CharacterBody3D

# 移动参数
var forward_speed = 8
var steer_speed = 6
var jump_force = 8
var gravity = 20

# 左右控制
var steer_input = 0.0
var max_steer = 1.0

@onready var visual = $Visual


func _physics_process(delta):

	# 重力
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 自动前进（固定方向）
	velocity.z = -forward_speed

	# 左右移动
	velocity.x = steer_input * steer_speed

	# 跳跃
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and is_on_floor():
		velocity.y = jump_force

	# 视觉倾斜（不会影响移动方向）
	visual.rotation.z = -steer_input * 0.8

	move_and_slide()

	# 让角色慢慢回到中间
	steer_input = lerp(steer_input, 0.0, 4 * delta)


func _input(event):

	# 鼠标滚轮控制左右
	if event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			steer_input -= 0.4

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			steer_input += 0.4

	# 限制最大偏移
	steer_input = clamp(steer_input, -max_steer, max_steer)
