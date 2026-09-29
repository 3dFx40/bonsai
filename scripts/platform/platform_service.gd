class_name BonsaiPlatform
extends Node

signal suspend_requested
signal resumed
signal quit_requested

func unix_time() -> float:
	return Time.get_unix_time_from_system()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED: suspend_requested.emit()
		NOTIFICATION_APPLICATION_RESUMED: resumed.emit()
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST: quit_requested.emit()
