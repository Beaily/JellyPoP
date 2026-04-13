extends CSGPolygon3D

func _ready():
	# 1. 给它一点时间生成网格（等待两帧最稳妥）
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 2. 检查是否已经有网格数据了
	var mesh = get_meshes() # CSG节点返回的是一个数组 [Transform3D, Mesh]
	if mesh.size() > 1:
		# 3. 手动创建一个静态碰撞体
		var static_body = StaticBody3D.new()
		add_child(static_body)
		
		var collision_shape = CollisionShape3D.new()
		static_body.add_child(collision_shape)
		
		# 4. 根据获取到的 Mesh 数据创建碰撞形状
		# create_trimesh_shape() 会根据网格精确生成碰撞面
		collision_shape.shape = mesh[1].create_trimesh_shape()
		
		# 5. 关闭原本那个不听话的自动碰撞
		use_collision = false
		
		print("手动碰撞体已生成！")
	else:
		print("错误：未能获取到 CSG 网格数据")
