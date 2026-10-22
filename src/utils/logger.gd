class_name Logger
extends RefCounted

## Structured logging utility for Duel of Kings: Animated Chess

enum Level {
	DEBUG,
	INFO,
	WARN,
	ERROR,
}

static var min_level: Level = Level.DEBUG

static func _format(level_str: String, tag: String, message: String) -> String:
	var time_dict = Time.get_time_dict_from_system()
	var time_str = "%02d:%02d:%02d" % [time_dict.hour, time_dict.minute, time_dict.second]
	return "[%s][%s][%s] %s" % [time_str, level_str, tag, message]

static func debug(tag: String, message: String) -> void:
	if min_level <= Level.DEBUG:
		print(_format("DEBUG", tag, message))

static func info(tag: String, message: String) -> void:
	if min_level <= Level.INFO:
		print(_format("INFO ", tag, message))

static func warn(tag: String, message: String) -> void:
	if min_level <= Level.WARN:
		push_warning(_format("WARN ", tag, message))

static func error(tag: String, message: String) -> void:
	if min_level <= Level.ERROR:
		push_error(_format("ERROR", tag, message))
