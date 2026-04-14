extends CharacterBody3D

# =========================
# 初始标准参数 (改这里，所有关卡的基础值都会变)
# =========================
const DEFAULT_SPEED = 8.0
const DEFAULT_JUMP = 8.0
const DEFAULT_SCALE = Vector3(1.0, 1.0, 1.0)
# 在最上方移动参数区修改
const DEFAULT_GRAVITY = 10.0  

# =========================
# level change
# =========================
var saved_black_position = Vector3.ZERO 
var level_yellow_triggered = false
var level_green_triggered = false
var level_pink_triggered = false    
var start_position = Vector3.ZERO   
# game endding
var falling_timer = 0.0

var levels = {}
var current_level = "black"    

# =========================
# 移动参数 (当前实际运行值)
# =========================
var forward_speed = DEFAULT_SPEED
var steer_speed = 6
var jump_force = DEFAULT_JUMP
var gravity = DEFAULT_GRAVITY
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
@onready var cam_farside = $Camera3D3

# =========================
# 初始化
# =========================
func _ready():
	start_position = global_position

	levels = {
		"black": level_black,
		"yellow": level_yellow,
		"green": level_green,
		"pink": level_pink
	}

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
	switch_camera("black")

# =========================
# 相机切换 (修复逻辑)
# =========================
func switch_camera(mode):
	if cam_side == null or cam_back == null or cam_farside == null:
		return

	# 全部重置为非当前
	cam_side.current = false
	cam_back.current = false
	cam_farside.current = false

	await get_tree().process_frame

	# 根据关卡激活对应镜头
	if mode == "black":
		cam_side.current = true
	elif mode == "yellow":
		cam_back.current = true
	elif mode == "green":
		cam_farside.current = true

# =========================
# 主逻辑
# =========================
func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
		falling_timer += delta
		if falling_timer >= 3.0:
			game_over_by_falling() # 调用失败函数
	else:
		# 只要脚沾地，计时器就归零
		falling_timer = 0.0

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
# 切换关卡逻辑
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

	# 关卡显示状态切换
	for lvl in levels.values():
		if lvl:
			lvl.visible = false
			lvl.process_mode = Node.PROCESS_MODE_DISABLED

	var target = levels.get(color)
	if target:
		target.visible = true
		target.process_mode = Node.PROCESS_MODE_ALWAYS

	current_level = color

	# --- 变身与数值处理 ---
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if color == "green":
		# 巨人模式：6倍大，速度和跳跃必须大幅提升才有快感
		tween.tween_property(self, "scale", Vector3(6, 6, 6), 0.5)
		forward_speed = 45.0  
		jump_force = 25.0
		gravity = 50.0     
	else:
		# 还原回初始标准参数
		tween.tween_property(self, "scale", DEFAULT_SCALE, 0.5)
		forward_speed = DEFAULT_SPEED
		jump_force = DEFAULT_JUMP
		gravity = DEFAULT_GRAVITY

	# 切换对应镜头
	if color == "yellow":
		switch_camera("yellow")
	elif color == "green":
		switch_camera("green")
	else:
		switch_camera("black")

# =========================
# 返回 black (彻底还原)
# =========================
func return_to_black():
	global_position = saved_black_position

	for lvl in levels.values():
		if lvl:
			lvl.visible = false
			lvl.process_mode = Node.PROCESS_MODE_DISABLED

	var black = levels.get("black")
	if black:
		black.visible = true
		black.process_mode = Node.PROCESS_MODE_ALWAYS

	current_level = "black"
	
	# ✨ 核心修复：使用初始常量进行一键还原
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", DEFAULT_SCALE, 0.4)
	
	forward_speed = DEFAULT_SPEED
	jump_force = DEFAULT_JUMP
	gravity = DEFAULT_GRAVITY

	switch_camera("black")

# =========================
# UI 与 结束
# =========================
func update_ui():
	var total = token_yellow + token_green + token_pink
	var text = "Tokens: " + str(total) + " | "
	text += "[color=yellow]" + str(token_yellow) + "[/color] ; "
	text += "[color=green]" + str(token_green) + "[/color] ; "
	text += "[color=pink]" + str(token_pink) + "[/color]"
	token_label.text = text

func reach_end_target():
	var total_score = token_yellow + token_green + token_pink
	var ui_canvas = get_tree().get_root().get_node("Main/UI")
	if ui_canvas and ui_canvas.has_method("show_game_over"):
		ui_canvas.show_game_over(total_score)
	
	forward_speed = 0 
	set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# =========================
# 掉落死亡处理
# =========================
func game_over_by_falling():
	print("掉入深渊太久了！游戏结束")
	
	# 重置计时器防止重复触发
	falling_timer = 0.0
	reach_end_target()
