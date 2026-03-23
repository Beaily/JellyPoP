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
var token_yellow = 0
var token_green = 0


@onready var sprite = $Visual/AnimatedSprite3D
@onready var token_label = get_tree().get_root().get_node("Main/UI/TokenLabel")



func _ready():
	# 稍微延迟一丁点时间，确保所有节点都加载完毕
	await get_tree().process_frame
	
	# 从根节点开始递归清理
	clean_ghost_nodes(get_tree().root)

# 递归函数：遍历所有子孙节点
func clean_ghost_nodes(current_node: Node):
	for child in current_node.get_children():
		
		# --- 判定条件：你可以根据名字或者类型来抓捕它们 ---
		# 比如名字里带 "Cube" 或者 "Orange"
		if "Cube" in child.name or "Orange" in child.name:
			
			# 1. 强制关闭碰撞层（解决挡路问题）
			if child is CollisionObject3D:
				child.collision_layer = 0
				child.collision_mask = 0
				# 如果它有子节点是 CollisionShape3D，也把它禁用
				for sub_child in child.get_children():
					if sub_child is CollisionShape3D:
						sub_child.disabled = true
			
			# 2. 彻底移除（如果你连看都不想看到它）
			child.queue_free()
			print("已成功驱逐幽灵节点: ", child.name)
		
		# 继续递归查找子节点的子节点
		clean_ghost_nodes(child)
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

func collect_token(value, color):
	# 根据颜色增加对应的计数
	if color == "yellow":
		token_yellow += value
	elif color == "green":
		token_green += value
		
	update_ui()
	
func update_ui():
	# [color=颜色代码]内容[/color] 是 BBCode 的语法
	# 我们用分号隔开：总数 ; 黄色 ; 绿色
	var total = token_yellow + token_green
	
	var text = "Tokens: "
	text += str(total) + " | " # 总数（白色）
	text += "[color=yellow]" + str(token_yellow) + "[/color] ; " # 黄色数字
	text += "[color=green]" + str(token_green) + "[/color]"    # 绿色数字
	
	token_label.text = text
