extends Spatial

export(NodePath) var objetivo_path

onready var objetivo = get_node(objetivo_path)

func _process(delta):
	if not objetivo:
		return

	var center = objetivo.call("obtener_centro")
	
	var offset = Vector3(0, 0, 0)
	global_transform.origin = center + offset
