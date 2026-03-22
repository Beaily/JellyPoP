extends Area3D

@export var value = 1
@export var color = "yellow"

func _ready():
	connect("body_entered", _on_body_entered)


func _on_body_entered(body):
	print("hit:", body.name)

	if body.name == "Player":
		print("WORKS")
		body.collect_token(value, color)
		queue_free()
