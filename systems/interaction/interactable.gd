class_name Interactable
extends Area3D

## Marks something the player can interact with: a person, a memory, a prop.
##
## Attach as a child of whatever should be interactable, set `prompt`, and
## connect `interacted`. The component knows nothing about what the interaction
## *does* — that stays with the scene or chapter script, so the same component
## serves NPCs, environmental memories and triggers alike.
##
## The area must sit on the "interactable" physics layer (4) so the player's
## InteractionSensor can see it.

signal interacted(interactor: Node3D)

## Shown to the player when this is the closest interactable in range.
@export var prompt: String = "Ansehen"
## Disabled interactables are ignored entirely — no prompt, no interaction.
@export var enabled: bool = true
## Interact once, then disable itself. Right for scripted story beats; wrong
## for things the player may want to look at twice.
@export var one_shot: bool = false


func interact(interactor: Node3D) -> void:
	if not enabled:
		return
	if one_shot:
		enabled = false
	interacted.emit(interactor)
