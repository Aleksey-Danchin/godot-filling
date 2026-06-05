extends Control

signal back_requested

const AUTHOR_LINK := "https://example.com"


func _on_back_pressed() -> void:
	back_requested.emit()


func _on_author_link_pressed() -> void:
	OS.shell_open(AUTHOR_LINK)
