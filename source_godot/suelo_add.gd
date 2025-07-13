extends Node3D

func agregar_a_grupo_suelo(nodo):
	nodo.add_to_group("suelo")
	for hijo in nodo.get_children():
		agregar_a_grupo_suelo(hijo)

func _ready():
	agregar_a_grupo_suelo(self)
