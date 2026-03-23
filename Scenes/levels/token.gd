extends Area3D

@export var value = 1
@export var color = "yellow"

func _ready():
	# 连接信号：当有物体进入此区域时触发
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# 检查进入的物体是不是玩家（是否有 collect_token 方法）
	if body.has_method("collect_token"):
		body.collect_token(value, color)
		queue_free() # 销毁 Token 避免重复触发
