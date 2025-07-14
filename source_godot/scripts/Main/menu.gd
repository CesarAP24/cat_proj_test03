# Script adjunto al nodo raíz MenuGato
extends Control

func _ready():
	pass
	
func _on_jugar_pressed():
	get_tree().change_scene_to_file("res://tests/city_test_night.tscn")

func _on_great_pressed():
	get_tree().change_scene_to_file("res://tests/thegreat.tscn")
	
func _on_egg_pressed():
	get_tree().change_scene_to_file("res://tests/abandoned.tscn")

func _on_test_pressed():
	get_tree().change_scene_to_file("res://tests/test03.tscn")
