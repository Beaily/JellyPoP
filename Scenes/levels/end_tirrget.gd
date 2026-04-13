extends Area3D
func _on_body_entered(body):
	# 检查进入区域的物体（玩家）是否有处理“到达终点”的方法
	if body.has_method("reach_end_target"):
		body.reach_end_target()
