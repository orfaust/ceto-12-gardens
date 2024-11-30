extends CanvasLayer

@onready var grid_container: GridContainer = %GridContainer
@onready var alias_container: HBoxContainer = %AliasContainer
@onready var alias_edit: LineEdit = %AliasEdit
@onready var save_score_value: Label = %SaveScoreValue

signal save_pressed(alias: String)

func _ready() -> void:
	alias_container.hide()
	pass

func add_item(player_name: String, score: int):
	var nameLabel = Label.new()
	nameLabel.text = player_name
	
	var scoreLabel = Label.new()
	scoreLabel.text = str(score)
	scoreLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	grid_container.add_child(nameLabel)
	grid_container.add_child(scoreLabel)

func empty():
	for child in grid_container.get_children():
		child.queue_free()

func show_prompt(score):
	save_score_value.text = str(score)
	alias_container.show()

func hide_prompt():
	alias_container.hide()

func _on_save_score_button_button_down() -> void:
	save_pressed.emit(alias_edit.text)
