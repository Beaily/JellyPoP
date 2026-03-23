extends Area3D

func _on_body_entered(body):
	if body.has_method("return_to_black"):
		body.return_to_black()
