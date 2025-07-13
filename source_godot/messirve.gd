extends AnimationPlayer

func _ready() -> void:
	get_animation("mixamo_com").loop = true
	play("mixamo_com")
