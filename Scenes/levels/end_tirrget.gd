extends Area3D
func _on_body_entered(body):
	if body.has_method("reach_end_target"):
		body.reach_end_target()
