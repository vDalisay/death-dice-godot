extends Control

@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var play_again_button: Button = $VBoxContainer/PlayAgainButton
@onready var boxes: Array[Button] = [
	$VBoxContainer/GridContainer/Box0,
	$VBoxContainer/GridContainer/Box1,
	$VBoxContainer/GridContainer/Box2,
	$VBoxContainer/GridContainer/Box3,
]

var score: int = 0
var box_contents: Array[bool] = []

func _ready() -> void:
	play_again_button.pressed.connect(_on_play_again_pressed)
	for i in range(4):
		boxes[i].pressed.connect(_on_box_pressed.bind(i))
	start_round()

func start_round() -> void:
	box_contents = [false, false, false, true]
	box_contents.shuffle()
	for box in boxes:
		box.disabled = false
		box.text = "?"
		box.modulate = Color(0.75, 0.75, 0.75)
	status_label.text = "Pick a box!"
	status_label.modulate = Color.WHITE
	play_again_button.visible = false

func _on_box_pressed(index: int) -> void:
	# Reveal all boxes
	for i in range(4):
		boxes[i].disabled = true
		if box_contents[i]:
			boxes[i].text = "GREEN"
			boxes[i].modulate = Color(0.2, 0.85, 0.2)
		else:
			boxes[i].text = "RED"
			boxes[i].modulate = Color(0.85, 0.2, 0.2)

	if box_contents[index]:
		score += 1
		score_label.text = "Score: " + str(score)
		status_label.text = "You WIN! You found the green box!"
		status_label.modulate = Color(0.2, 0.85, 0.2)
	else:
		status_label.text = "You LOSE! That was a red box!"
		status_label.modulate = Color(0.85, 0.2, 0.2)

	play_again_button.visible = true

func _on_play_again_pressed() -> void:
	start_round()
