extends CharacterBody3D

# =========================
# 移动参数
# =========================
var forward_speed = 8
var steer_speed = 6
var jump_force = 8
var gravity = 20


# 左右控制
var steer_input = 0.0
var max_steer = 1.0

# token
var token_count = 0
var current_color = "none"


@onready var sprite = $Visual/AnimatedSprite3D
@onready var token_label = get_tree().get_root().get_node("Main/UI/TokenLabel")


# =========================
# 主逻辑
# =========================
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

	move_and_slide()

	# 更新角色视觉（方向 + 状态）
	update_sprite()

	# 让角色慢慢回到中间（平滑）
	steer_input = lerp(steer_input, 0.0, 4 * delta)


# =========================
# 输入（滚轮控制左右）
# =========================
func _input(event):

	if event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			steer_input -= 0.4

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			steer_input += 0.4

	# 限制最大偏移
	steer_input = clamp(steer_input, -max_steer, max_steer)

func update_sprite():

	# jump
	if not is_on_floor():
		play_anim("jump")
		return

	# scroll wheel
	var anim = "front_run"

	if steer_input < -0.3:
		anim = "left_run"
	elif steer_input > 0.3:
		anim = "right_run"
	else:
		anim = "front_run"

	play_anim(anim)

func play_anim(anim_name):

	if sprite.animation != anim_name:
		sprite.play(anim_name)

func update_ui():
	token_label.text = "Token: " + str(token_count)

func collect_token(value, color):
	token_count += value
	current_color = color
	update_ui()
