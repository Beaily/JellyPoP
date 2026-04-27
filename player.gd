extends CharacterBody3D

# =========================
# 初始标准参数
# =========================
const DEFAULT_SPEED = 8.0
const DEFAULT_JUMP = 8.0
const DEFAULT_SCALE = Vector3(1.0, 1.0, 1.0)
const DEFAULT_GRAVITY = 10.0  

# =========================
# level change
# =========================
var saved_black_position = Vector3.ZERO 
var level_yellow_triggered = false
var level_green_triggered = false
var level_pink_triggered = false    
var start_position = Vector3.ZERO   
var falling_timer = 0.0
var is_transferring = false 

var levels = {}
var current_level = "black"    

# =========================
# 移动参数
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
# 动画/状态
# =========================
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
			lvl.global_position = Vector3.ZERO
		else:
			lvl.visible = false
			lvl.process_mode = Node.PROCESS_MODE_DISABLED
			lvl.global_position = Vector3(0, -1000, 0)
			
	current_level = "black"
	switch_camera("black")

# =========================
# 相机切换
# =========================
func switch_camera(mode):
	if cam_side == null or cam_back == null or cam_farside == null:
		return

	cam_side.current = false
	cam_back.current = false
	cam_farside.current = false

	await get_tree().process_frame

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
	if is_transferring:
		velocity.y = 0
		move_and_slide()
		falling_timer = 0.0
		return
	
	if is_on_floor():
		if was_in_air:
			on_player_landed()
			was_in_air = false
		falling_timer = 0.0
	else:
		was_in_air = true
		velocity.y -= gravity * delta
		
		if not is_transferring:
			falling_timer += delta
		if falling_timer >= 6.0:
			game_over_by_falling()

	velocity.z = -forward_speed
	velocity.x = steer_input * steer_speed

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

	if current_level == "green":
		apply_camera_shake(0.8) 
	elif current_level == "yellow":
		apply_camera_shake(0.02)

func apply_camera_shake(intensity: float):
	var cam = get_viewport().get_camera_3d()
	if not cam: return
	var shake_tween = create_tween()
	var original_pos = cam.position
	shake_tween.tween_property(cam, "position", original_pos + Vector3(0, intensity, 0), 0.05)
	shake_tween.tween_property(cam, "position", original_pos + Vector3(0, -intensity, 0), 0.05)
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
			
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if is_on_floor():
				velocity.y = jump_force
				play_anim("jump")

	steer_input = clamp(steer_input, -max_steer, max_steer)

# =========================
# 动画
# =========================
func update_sprite():
	if not is_on_floor(): return
	var anim = "front_run"
	if steer_input < -0.3: anim = "left_run"
	elif steer_input > 0.3: anim = "right_run"
	
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
		if token_yellow >= 10 and not level_yellow_triggered:
			trigger_level_swap("yellow")
	elif color == "green":
		token_green += value
		if token_green >= 1 and not level_green_triggered:
			trigger_level_swap("green")
	elif color == "pink":
		token_pink += value
		# 新逻辑：如果在 black 关卡 pink 分数达到 10，强制再次进入 pink 关卡
		if current_level == "black" and token_pink >= 4:
			trigger_level_swap("pink")
		elif token_pink >= 1 and not level_pink_triggered:
			trigger_level_swap("pink")
	update_ui()

# =========================
# 切换关卡逻辑
# =========================
func trigger_level_swap(color):
	# 1. 核心修复：如果是离开 black，记录当前坐标
	if current_level == "black":
		saved_black_position = global_position
		
	current_level = color
	falling_timer = 0.0 # 重置死亡计时

	if color == "yellow": level_yellow_triggered = true
	elif color == "green": level_green_triggered = true
	elif color == "pink": level_pink_triggered = true

	# 关卡显示状态切换
	for lvl in levels.values():
		if lvl:
			lvl.visible = false
			lvl.process_mode = Node.PROCESS_MODE_DISABLED
			lvl.global_position = Vector3(0, -1000, 0)

	var target = levels.get(color)
	if target:
		target.visible = true
		target.process_mode = Node.PROCESS_MODE_ALWAYS
		target.global_position = Vector3.ZERO

	await get_tree().physics_frame 

	# 移动玩家
	if color == "yellow":
		global_position = start_position + Vector3(0.2, 12.0, 40)
	elif color == "pink":
		global_position = start_position + Vector3(0, 0.5, -10)
	else:
		global_position = start_position + Vector3(1, 8.0, 0)

	# 变身处理
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if color == "green":
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
		tween.tween_property(self, "scale", DEFAULT_SCALE, 0.5)
		forward_speed = DEFAULT_SPEED
		jump_force = DEFAULT_JUMP
		gravity = DEFAULT_GRAVITY

	# 相机切换逻辑：如果进入 pink 且分数 >= 10，用背后视角
	if color == "yellow":
		switch_camera("yellow")
	elif color == "green":
		switch_camera("green")
	elif color == "pink":
		if token_pink >= 4:
			switch_camera("yellow") # 对应 cam_back
		else:
			switch_camera("black") # 默认侧面视角
	else:
		switch_camera("black")

# =========================
# 返回 black
# =========================
func return_to_black():
	is_transferring = true
	falling_timer = 0.0
	velocity = Vector3.ZERO
	
	for lvl in levels.values():
		if lvl:
			lvl.visible = false
			lvl.process_mode = Node.PROCESS_MODE_DISABLED
			lvl.global_position = Vector3(0, -1000, 0)

	var black = levels.get("black")
	if black:
		black.visible = true
		black.process_mode = Node.PROCESS_MODE_ALWAYS
		black.global_position = Vector3.ZERO

	await get_tree().physics_frame

	if saved_black_position == Vector3.ZERO:
		global_position = start_position + Vector3(0, 2.0, 0)
	else:
		global_position = saved_black_position + Vector3(0, 2.0, 0)
		

	await get_tree().create_timer(0.5).timeout
	
	current_level = "black"
	forward_speed = DEFAULT_SPEED
	jump_force = DEFAULT_JUMP
	gravity = DEFAULT_GRAVITY
	
	var tween = create_tween()
	tween.tween_property(self, "scale", DEFAULT_SCALE, 0.4)

	switch_camera("black")
	
	falling_timer = 0.0
	is_transferring = false

# =========================
# UI 与 结束
# =========================
func update_ui():
	var total = token_yellow + token_green + token_pink
	var text = "Tokens: " + str(total) + " | "
	text += "[color=yellow]" + str(token_yellow) + "[/color] ; "
	text += "[color=green]" + str(token_green) + "[/color] ; "
	text += "[color=pink]" + str(token_pink) + "[/color]"
	if token_label: token_label.text = text

func reach_end_target():
	var total_score = token_yellow + token_green + token_pink
	var ui_canvas = get_tree().get_root().get_node_or_null("Main/UI")
	if ui_canvas and ui_canvas.has_method("show_game_over"):
		ui_canvas.show_game_over(total_score)
	
	forward_speed = 0 
	set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func game_over_by_falling():
	if is_transferring or current_level == "":
		falling_timer = 0.0
		return
	
	falling_timer = 0.0
	reach_end_target()
