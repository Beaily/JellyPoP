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
	get_tree().reload_current_scene()
