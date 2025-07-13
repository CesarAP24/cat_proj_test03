# Script adjunto al nodo raíz MenuGato
extends Control

# La ruta baja por el árbol: VBoxContain -> Jugar
@onready var primer_boton = $Buscador/mandarSeed

func _ready():
	primer_boton.grab_focus()

func _on_jugar_pressed():
	get_tree().change_scene_to_file("res://tests/city_test_night.tscn")
