extends CanvasLayer


# UI.gd


@onready var result_panel = $ResultPanel # 假设你把那些按钮和Label都放在这个容器里
@onready var score_label = $ResultPanel/ScoreLabel

func _ready():
	# 游戏开始时确保它是隐藏的
	result_panel.hide()

func show_game_over(score: int):
	# 显示面板并更新分数
	if result_panel:	
		result_panel.show()
	if score_label:
		score_label.text = "Score: " + str(score)

# 给你的 RestartButton 连接这个信号

func _on_restart_button_pressed():
	
	result_panel.hide()
	
	var player = get_tree().get_root().get_node("Main/Player")
	
	if player:
		player.return_to_black()
		
		player.has_jumped = false
		player.has_moved = false
		player.move_time = 0.0
	
	# 手动关闭 tutorial UI（注意缩进必须在函数里面）
	var ui = get_tree().get_root().get_node("Main/UI")
	
	ui.get_node("JumpLabel").visible = false
	ui.get_node("MoveLabel").visible = false
	ui.get_node("Arrow").visible = false
	ui.get_node("TokenHint").visible = false

	
	
		
