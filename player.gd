extends CharacterBody3D

# =========================
# 初始标准参数
# =========================
const DEFAULT_SPEED = 7.0
const DEFAULT_JUMP = 8.0
const DEFAULT_SCALE = Vector3(1.0, 1.0, 1.0)
const DEFAULT_GRAVITY = 10.0  

# =========================
# level change
# =========================
var saved_black_position = Vector3.ZERO 
var level_yellow_triggered = false
var level_green_triggered = false 
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
# touch design
var touch_start_x = 0.0
var touch_sensitivity = 0.015
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
var pink_enter_count = 0

# =========================
# UI
# =========================
var has_jumped = false
var has_moved = false
var has_collected = false
var move_time = 0.0
#music
var can_auto_forward = true
var bgm_pitch_by_level = {
	"yellow": 1.25,
	"green": 0.85,
	"black": 0.9,
	"pink": 1.35
}

var token_pitch_by_color = {
	"yellow": 1.2,
	"green": 1.0,
	"pink": 1.45
}
# =========================
# 节点引用
# =========================
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var token_pickup_player: AudioStreamPlayer = $TokenPickupPlayer
@onready var level_switch_player: AudioStreamPlayer = $LevelSwitchPlayer

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
	if GameManager.tutorial_done:
		hide_jump_ui()
	else:
		show_jump_ui()
	start_position = global_position
	update_bgm_for_level("black")
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

	if can_auto_forward:
		velocity.z = -forward_speed
	else:
		velocity.z = 0
	if current_level == "green":
		velocity.x = 0
		steer_input = 0.0
	else:
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
	# =========================
	# UI 移动检测（加这里）
	# =========================
	if has_jumped and not has_moved:
		
		if abs(steer_input) > 0.1:
			move_time += delta

			if move_time > 2:
				has_moved = true
				hide_move_ui()
				hide_arrow()
				GameManager.tutorial_done = true 

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
	
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start_x = event.position.x
		else:
			if is_on_floor():
				velocity.y = jump_force
				play_anim("jump")

	if event is InputEventScreenDrag:
		if current_level != "green":
			var drag_distance = event.position.x - touch_start_x
			steer_input = drag_distance * touch_sensitivity
			steer_input = clamp(steer_input, -max_steer, max_steer)
		else:
			steer_input = 0.0
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if GameManager.tutorial_done:
				return
			if not has_jumped:
				has_jumped = true
				hide_jump_ui()
				show_move_ui()
				show_arrow()
		if current_level != "green":
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				steer_input -= 0.4
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				steer_input += 0.4
		else:
			steer_input = 0.0
			
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if is_on_floor():
				velocity.y = jump_force
				play_anim("jump")

	steer_input = clamp(steer_input, -max_steer, max_steer)
#==测试快捷键=
func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		# 按 1 跳转到 Yellow Level
		if event.keycode == KEY_1:
			print("手动跳转到 Yellow")
			velocity = Vector3.ZERO
			trigger_level_swap("yellow")
			
		# 按 2 跳转到 Green Level
		if event.keycode == KEY_2:
			print("跳转到 Green")
			velocity = Vector3.ZERO
			trigger_level_swap("green")
			
		# 按 3 跳转到 Pink Level (第一次进入)
		if event.keycode == KEY_3:
			print("跳转到 Pink")
			pink_enter_count = 0 
			trigger_level_swap("pink")
		if event.keycode == KEY_4:
			print("跳转到 Pink2")
			pink_enter_count = 1
			token_pink = 20
			trigger_level_swap("pink")

		# 按 R 键立即返回 Black Level
		if event.keycode == KEY_R:
			print("手动返回 Black")
			velocity = Vector3.ZERO
			return_to_black()
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
		
	if not has_collected:
		has_collected = true
		show_token_ui()
	var total_token = token_yellow + token_green + token_pink
	if total_token >= 3:
		hide_token_ui()
	
	play_token_pickup_sound(color)
	if color == "yellow":
		token_yellow += value
		if token_yellow >= 3 and not level_yellow_triggered:
			trigger_level_swap("yellow")
	elif color == "green":
		token_green += value
		if token_green >= 1 and not level_green_triggered:
			trigger_level_swap("green")
	elif color == "pink":
		token_pink += value
		if current_level == "black" and token_pink >= 4:
			trigger_level_swap("pink")
		elif token_pink >= 2 and current_level != "pink":
			trigger_level_swap("pink")
	update_ui()

# =========================
# 切换关卡逻辑
# =========================
func trigger_level_swap(color):

	var ui = get_tree().get_root().get_node("Main/UI")

	var token_count = 0

	if color == "yellow":
		token_count = token_yellow
	elif color == "green":
		token_count = token_green
	elif color == "pink":
		token_count = token_pink

	is_transferring = true
	velocity = Vector3.ZERO
	var text = "Collected: " + str(token_count) + "\nGoing to " + color + " level"

	play_level_switch_sound(color)

	await ui.show_transition(text)

	update_bgm_for_level(color)
	
	print("--- 触发跳转，目标颜色是: ", color, " ---")
	

	# =========================
	# 关键修复 1：记录 pink 是否第一次
	# =========================
	
	if color == "pink":
		if pink_enter_count >= 2:
			is_transferring = false
			return
		
		pink_enter_count += 1

	# =========================
	# 记录 black 位置
	# =========================
	if current_level == "black":
		saved_black_position = global_position
		
	current_level = color
	falling_timer = 0.0

	# =========================
	# 关键修复 2：冻结移动（防止位置被覆盖）
	# =========================
	is_transferring = true
	velocity = Vector3.ZERO

	# =========================
	# 更新触发状态（放在后面）
	# =========================
	if color == "yellow":
		level_yellow_triggered = true
	elif color == "green":
		level_green_triggered = true


	# =========================
	# 关卡显示切换
	# =========================
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
	
	if color == "yellow":
		global_position = start_position + Vector3(-2, 20.0, 28)

	elif color == "pink":
		print("Pink 次数:", pink_enter_count)

		if pink_enter_count == 1:
			print("第一次位置")
			global_position = start_position + Vector3(-1, 10, -5)

		elif pink_enter_count == 2:
			print("第二次位置")
			global_position = start_position + Vector3(-12, 10, -10)

	else:
		global_position = start_position + Vector3(-4, 10, 10)

	# =========================
	# 等待位置稳定
	# =========================
	await get_tree().process_frame

	# =========================
	# 变身处理
	# =========================
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
	elif color == "pink":
		tween.tween_property(self, "scale", DEFAULT_SCALE, 0.5)
		forward_speed = min( DEFAULT_SPEED + token_pink * 0.5,20)
		jump_force = 18
		gravity = 20 
		
		if pink_enter_count == 2:
			steer_speed = 12
		else :
			steer_speed = 6
		
	else:
		tween.tween_property(self, "scale", DEFAULT_SCALE, 0.5)
		forward_speed = DEFAULT_SPEED
		jump_force = DEFAULT_JUMP
		gravity = DEFAULT_GRAVITY

	# =========================
	# 相机切换
	# =========================
	if color == "yellow":
		switch_camera("yellow")
	elif color == "green":
		switch_camera("green")
	elif color == "pink":
		if token_pink >= 4:
			switch_camera("yellow")
		else:
			switch_camera("black")
	else:
		switch_camera("black")

	# =========================
	# 解除冻结（恢复移动）
	# =========================
	await get_tree().create_timer(0.2).timeout

	is_transferring = false
	can_auto_forward = false
	velocity.z = 0

	await get_tree().create_timer(3.0).timeout

	can_auto_forward = true
	
func return_to_black():
	print("开始返回...")
	play_level_switch_sound("black")
	update_bgm_for_level("black")
	
	is_transferring = true
	falling_timer = 0.0
	velocity = Vector3.ZERO # 必须重置速度
	
	# 1. 立即停止所有物理处理
	set_physics_process(false) 

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

	# 2. 强制同步物理状态
	await get_tree().process_frame

	# 设置位置：确保 Y 轴足够高，避免卡进地板
	#if saved_black_position == Vector3.ZERO:
			#global_position = start_position + Vector3(0, 3.0, 0)
	#else:
		#global_position = saved_black_position + Vector3(0, 3.0, 0)

	global_position = start_position + Vector3(0, 3.0, 0)
	await get_tree().create_timer(0.5).timeout

	current_level = "black"
	forward_speed = DEFAULT_SPEED
	jump_force = DEFAULT_JUMP
	gravity = DEFAULT_GRAVITY
	set_physics_process(true)
	
	var tween = create_tween()
	tween.tween_property(self, "scale", DEFAULT_SCALE, 0.4)

	switch_camera("black")
	
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
	if is_transferring:
		print("拦截：正在传送中，无视终点线")
		return

	print("正式结束游戏！")
	var total_score = token_yellow + token_green + token_pink
	var ui_canvas = get_tree().get_root().get_node_or_null("Main/UI")
	if ui_canvas and ui_canvas.has_method("show_game_over"):
		ui_canvas.show_game_over(total_score)
	
	forward_speed = 0 
	set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func game_over_by_falling():
	print("游戏结束触发：掉落超时，当前计时器：", falling_timer)
	if is_transferring or current_level == "":
		falling_timer = 0.0
		return
	
	falling_timer = 0.0
	reach_end_target()
# =========================
# UI 控制函数（必须加）
# =========================
@onready var ui = get_tree().get_root().get_node("Main/UI")

func show_jump_ui():
	ui.get_node("JumpLabel").visible = true

func hide_jump_ui():
	ui.get_node("JumpLabel").visible = false

func show_move_ui():
	ui.get_node("MoveLabel").visible = true

func hide_move_ui():
	ui.get_node("MoveLabel").visible = false

func show_arrow():
	ui.get_node("Arrow").visible = true

func hide_arrow():
	ui.get_node("Arrow").visible = false

func show_token_ui():
	ui.get_node("TokenHint").visible = true

func hide_token_ui():
	ui.get_node("TokenHint").visible = false

#music
func update_bgm_for_level(level_color: String) -> void:
	if not bgm_pitch_by_level.has(level_color):
		level_color = "black"

	bgm_player.pitch_scale = bgm_pitch_by_level[level_color]

	if not bgm_player.playing:
		bgm_player.play()


func play_level_switch_sound(level_color: String) -> void:
	if not bgm_pitch_by_level.has(level_color):
		level_color = "black"

	level_switch_player.stop()
	level_switch_player.pitch_scale = bgm_pitch_by_level[level_color]
	level_switch_player.play()


func play_token_pickup_sound(token_color: String) -> void:
	if not token_pitch_by_color.has(token_color):
		token_color = "normal"

	token_pickup_player.stop()
	token_pickup_player.pitch_scale = token_pitch_by_color[token_color]
	token_pickup_player.play()
