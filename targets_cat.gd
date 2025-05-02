extends Spatial

export(NodePath) var objetivo_path
export(float) var offset_y

onready var objetivo = get_node(objetivo_path)
onready var t_backL = $"RootNode (gltf orientation matrix)/RootNode (model correction matrix)/catfbx/Node_3/RootNode/Armature/t_backL"
onready var t_backR = $"RootNode (gltf orientation matrix)/RootNode (model correction matrix)/catfbx/Node_3/RootNode/Armature/t_backR"
onready var t_frontL = $"RootNode (gltf orientation matrix)/RootNode (model correction matrix)/catfbx/Node_3/RootNode/Armature/t_frontL"
onready var t_frontR = $"RootNode (gltf orientation matrix)/RootNode (model correction matrix)/catfbx/Node_3/RootNode/Armature/t_frontR"
onready var ik_backL = $"RootNode (gltf orientation matrix)/RootNode (model correction matrix)/catfbx/Node_3/RootNode/Armature/Skeleton/ik_backL"
onready var ik_backR = $"RootNode (gltf orientation matrix)/RootNode (model correction matrix)/catfbx/Node_3/RootNode/Armature/Skeleton/ik_backR"
onready var ik_frontL = $"RootNode (gltf orientation matrix)/RootNode (model correction matrix)/catfbx/Node_3/RootNode/Armature/Skeleton/ik_frontL"
onready var ik_frontR = $"RootNode (gltf orientation matrix)/RootNode (model correction matrix)/catfbx/Node_3/RootNode/Armature/Skeleton/ik_frontR"


onready var hueso =  $"RootNode (gltf orientation matrix)/RootNode (model correction matrix)/catfbx/Node_3/RootNode/Armature/Skeleton"

func update_root_pos_rot():
	var center = objetivo.call("obtener_centro")
	center.y = center.y - offset_y
	global_transform.origin = center

	var dir = objetivo.call("obtener_direccion")
	
	var angle_y = atan2(dir.x, dir.z)
	global_transform.basis = Basis(Vector3.UP, angle_y)
	rotate_y(deg2rad(-90)) # modelo mira a -X

func update_targets_pos():
	var patas = objetivo.call("obtener_patas")
	t_backL.global_position = patas["backL"]
	t_backR.global_position = patas["backR"]
	t_frontL.global_position = patas["frontL"]
	t_frontR.global_position = patas["frontR"]
	
func update_hips_positions():
	pass

func update_column():
	update_hips_positions()
	#hueso1, hueso2 positions = get_center_column_positions()
	pass

func _process(delta):
	if not objetivo:
		return
		
	if Input.is_key_pressed(KEY_P):
		offset_y += 0.1
	if Input.is_key_pressed(KEY_O):
		offset_y -= 0.1
	
		
	update_root_pos_rot()
	update_targets_pos()
	update_column()



func _ready():
	ik_backL.start()
	ik_backR.start()
	ik_frontL.start()
	ik_frontR.start()

