extends CharacterBody3D

# =========================
# level change
# =========================
var saved_black_position = Vector3.ZERO 
var level_yellow_triggered = false
var level_green_triggered = false
var level_pink_triggered = false    
var start_position = Vector3.ZERO   

var levels = {}
var current_level = "black"    

# =========================
# 移动参数
# =========================
var forward_speed = 8
var steer_speed = 6
var jump_force = 8
var gravity = 20

var steer_input = 0.0
var max_steer = 1.0

# =========================
# token
# =========================
var token_yellow = 0
var token_green = 0
var token_pink = 0

# =========================
# 节点引用
# =========================
@onready var sprite = $Visual/AnimatedSprite3D
@onready var token_label = get_tree().get_root().get_node("Main/UI/TokenLabel")

@onready var level_black = get_tree().get_root().get_node("Main/Level_Black")
@onready var level_yellow = get_tree().get_root().get_node("Main/Level_Yellow")
@onready var level_green = get_tree().get_root().get_node("Main/Level_Green")
@onready var level_pink = get_tree().get_root().get_node("Main/Level_Pink")

# ✅ 相机
@onready var cam_side = $Camera3D
@onready var cam_back = $Camera3D2

# =========================
# 初始化
# =========================
func _ready():
	start_position = global_position

	# 初始化 levels（关键）
	levels = {
		"black": level_black,
		"yellow": level_yellow,
		"green": level_green,
		"pink": level_pink
	}

	# 初始化关卡状态
	for key in levels.keys():
		var lvl = levels[key]

		if lvl == null:
			push_error("Level missing: " + key)
			continue

		if key == "black":
			lvl.visible = true
			lvl.process_mode = Node.PROCESS_MODE_ALWAYS
		else:
			lvl.visible = false
			lvl.process_mode = Node.PROCESS_MODE_DISABLED

	current_level = "black"

	# ✅ 初始化相机
	switch_camera("black")

# =========================
# 相机切换（新增）
# =========================
func switch_camera(mode):

	if cam_side == null or cam_back == null:
		push_error("Camera missing")
		return

	# 强制关闭
	cam_side.current = false
	cam_back.current = false

	await get_tree().process_frame   # ⭐ 关键（确保切换刷新）

	if mode == "black":
		cam_side.current = true
		print("切换到侧面 camera")

	elif mode == "yellow":
		cam_back.current = true
		print("切换到背后 camera")


# =========================
# 主逻辑
# =========================
func _physics_process(delta):

	if not is_on_floor():
		velocity.y -= gravity * delta

	velocity.z = -forward_speed
	velocity.x = steer_input * steer_speed

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and is_on_floor():
		velocity.y = jump_force

	move_and_slide()

	update_sprite()

	steer_input = lerp(steer_input, 0.0, 4 * delta)

# =========================
# 输入
# =========================
func _input(event):

	if event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			steer_input -= 0.4

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			steer_input += 0.4

	steer_input = clamp(steer_input, -max_steer, max_steer)

# =========================
# 动画
# =========================
func update_sprite():

	if not is_on_floor():
		play_anim("jump")
		return

	var anim = "front_run"

	if steer_input < -0.3:
		anim = "left_run"
	elif steer_input > 0.3:
		anim = "right_run"

	play_anim(anim)

func play_anim(anim_name):
	if sprite.animation != anim_name:
		sprite.play(anim_name)

# =========================
# Token
# =========================
func collect_token(value, color):

	if color == "yellow":
		token_yellow += value
		if token_yellow >= 10 and not level_yellow_triggered:
			trigger_level_swap("yellow")

	elif color == "green":
		token_green += value
		if token_green >= 1 and not level_green_triggered:
			trigger_level_swap("green")

	elif color == "pink":
		token_pink += value
		if token_pink >= 10 and not level_pink_triggered:
			trigger_level_swap("pink")

	update_ui()

# =========================
# 切关卡
# =========================
func trigger_level_swap(color):

	if color == "yellow":
		level_yellow_triggered = true
	elif color == "green":
		level_green_triggered = true
	elif color == "pink":
		level_pink_triggered = true

	if current_level == "black":
		saved_black_position = global_position

	global_position = start_position

	# 关闭所有关卡
	for lvl in levels.values():
		if lvl == null:
			continue
		lvl.visible = false
		lvl.process_mode = Node.PROCESS_MODE_DISABLED

	# 打开目标关卡
	var target = levels.get(color)

	if target:
		target.visible = true
		target.process_mode = Node.PROCESS_MODE_ALWAYS

	current_level = color

	# 相机切换（只对 yellow）
	if color == "yellow":
		switch_camera("yellow")

	print("切换到 Level_", color)

# =========================
# UI
# =========================
func update_ui():

	var total = token_yellow + token_green + token_pink

	var text = "Tokens: "
	text += str(total) + " | "
	text += "[color=yellow]" + str(token_yellow) + "[/color] ; "
	text += "[color=green]" + str(token_green) + "[/color] ; "
	text += "[color=pink]" + str(token_pink) + "[/color]"

	token_label.text = text

# =========================
# 返回 black
# =========================
func return_to_black():

	global_position = saved_black_position

	for lvl in levels.values():
		if lvl == null:
			continue
		lvl.visible = false
		lvl.process_mode = Node.PROCESS_MODE_DISABLED

	var black = levels.get("black")

	if black:
		black.visible = true
		black.process_mode = Node.PROCESS_MODE_ALWAYS

	current_level = "black"

	# 相机切回侧面
	switch_camera("black")

	print("返回 Level_Black")

# 游戏结束
# =========================
func reach_end_target():
	print("玩家觸發了終點函數！") # 調試 1
	
	var total_score = token_yellow + token_green + token_pink
	
	# 這裡的路徑非常關鍵，必須和你場景樹結構完全一致
	var ui_canvas = get_tree().get_root().get_node("Main/UI")
	
	if ui_canvas:
		print("找到 UI 節點了") # 調試 2
		if ui_canvas.has_method("show_game_over"):
			print("準備調用 UI 的顯示函數") # 調試 3
			ui_canvas.show_game_over(total_score)
		else:
			print("錯誤：UI 節點上沒有 show_game_over 方法！")
	else:
		print("錯誤：找不到路徑為 Main/UI 的節點！")
	
	# 停止玩家移動
	forward_speed = 0 
	set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
