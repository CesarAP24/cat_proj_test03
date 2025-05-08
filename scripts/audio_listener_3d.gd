extends AudioListener3D

@export var objetivo_path: NodePath

@onready var objetivo = get_node(objetivo_path)

func _process(delta: float) -> void:
	global_position = objetivo.call("obtener_centro")
