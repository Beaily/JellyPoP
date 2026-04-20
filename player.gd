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
#========
#动画
#========
var was_in_air = false
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
		if lvl == null: continue

		if key == "black":
			lvl.visible = true
			lvl.process_mode = Node.PROCESS_MODE_ALWAYS
			lvl.global_position = Vector3.ZERO # 在原位
		else:
			lvl.visible = false
			lvl.process_mode = Node.PROCESS_MODE_DISABLED
			lvl.global_position = Vector3(0, -1000, 0) # 扔到地底下 1000 米
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
	# --- A. 落地瞬间检测 (必须放在最前面) ---
	if is_on_floor():
		if was_in_air:
			on_player_landed() # 执行落地逻辑
			was_in_air = false # 落地后重置标记
		falling_timer = 0.0
	else:
		# 只要不在地面，就标记为“在空中”
		was_in_air = true
		velocity.y -= gravity * delta
		falling_timer += delta
		if falling_timer >= 3.0:
			game_over_by_falling()

	# --- B. 基础移动 ---
	velocity.z = -forward_speed
	velocity.x = steer_input * steer_speed

	# --- C. 动画切换 ---
	if is_on_floor():
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			play_anim("squat")
		else:
			update_sprite()
	else:
		play_anim("jump")

	move_and_slide() 
	
	steer_input = lerp(steer_input, 0.0, 4 * delta)

func on_player_landed():
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector3(1.2, 0.8, 1.2), 0.05)
	tween.tween_property(sprite, "scale", Vector3(1.0, 1.0, 1.0), 0.1)

	# 2. 根据关卡区分相机抖动
	if current_level == "green":
		apply_camera_shake(0.8) 
	elif current_level == "yellow":
		apply_camera_shake(0.02)
	else:
		apply_camera_shake(0.0) 

   
		
# =========================
# 特效辅助函数：屏幕抖动
# =========================
func apply_camera_shake(intensity: float):
	# 获取当前活动相机
	var cam = get_viewport().get_camera_3d()
	if not cam: return

	# 停止该相机上可能存在的其他 Tween，防止冲突
	var shake_tween = create_tween()
	
	# 记录相机初始位置
	var original_pos = cam.position
	
	# 暴力抖动方案：上下快速跳动
	# 1. 向上弹起
	shake_tween.tween_property(cam, "position", original_pos + Vector3(0, intensity, 0), 0.05)
	# 2. 向下砸
	shake_tween.tween_property(cam, "position", original_pos + Vector3(0, -intensity, 0), 0.05)
	# 3. 回到原位
	shake_tween.tween_property(cam, "position", original_pos, 0.05)
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
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			steer_input -= 0.4
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			steer_input += 0.4
			
		# 新增：检测左键松开
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if is_on_floor():
				velocity.y = jump_force
				play_anim("jump") # 松开瞬间变跳跃

# =========================
# 动画
# =========================
func update_sprite():
	# 如果在空中，保持跳跃动画
	if not is_on_floor():
		return # 不在这里处理，由跳跃触发逻辑处理

	# 如果回到地面，自动切换回跑步逻辑
	var anim = "front_run"
	if steer_input < -0.3:
		anim = "left_run"
	elif steer_input > 0.3:
		anim = "right_run"
	
	# 只要在地面且没有按住鼠标蹲下，就播跑步动画
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
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
		if token_yellow >= 1 and not level_yellow_triggered:
			trigger_level_swap("yellow")
	elif color == "green":
		token_green += value
		if token_green >= 2 and not level_green_triggered:
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
	current_level = color
	if color == "yellow":
		level_yellow_triggered = true
		
	elif color == "green":
		level_green_triggered = true
	elif color == "pink":
		level_pink_triggered = true

	if current_level == "black":
		saved_black_position = global_position

	

	# 关卡显示状态切换
	for lvl in levels.values():
		if lvl:
			lvl.visible = false
			lvl.process_mode = Node.PROCESS_MODE_DISABLED
			lvl.global_position = Vector3(0, -1000, 0) # 藏起旧的

	var target = levels.get(color)
	if target:
		target.visible = true
		target.process_mode = Node.PROCESS_MODE_ALWAYS
		target.global_position = Vector3.ZERO # 👈 让黄关地板先回到原位

	# 2. ⭐【最重要的一行】等待物理帧刷新
	# 这会让程序停一下，等物理引擎确认地板已经在那了，再执行后面的代码
	await get_tree().physics_frame 

	# 3. 最后再移动玩家
	# 即使高度重合，也建议给玩家一个 0.5 到 1.0 的额外高度，防止脚陷进地里
	if color == "yellow":
		global_position = start_position + Vector3(0.2,12.0,40)
	else:
		global_position = start_position + Vector3(1, 8.0, 0)
			
	

	# --- 变身与数值处理 ---
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if color == "green":
	
		# 巨人模式：6倍大，速度和跳跃必须大幅提升才有快感
		tween.tween_property(self, "scale", Vector3(6, 6, 6), 0.5)
		forward_speed = 45.0  
		jump_force = 25.0
		gravity = 50.0 
	elif color == "yellow":
		tween.tween_property(self, "scale", DEFAULT_SCALE, 0.5)
		forward_speed = DEFAULT_SPEED
		jump_force = 15
		gravity = 25.0 
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
		black.global_position = Vector3.ZERO

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
