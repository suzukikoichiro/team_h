extends RefCounted

static func now_parts() -> Dictionary:
	var now := Time.get_datetime_dict_from_system()
	return {
		"year": int(now["year"]),
		"month": int(now["month"]),
		"day": int(now["day"]),
		"hour": int(now["hour"]),
		"minute": int(now["minute"]),
	}


static func today_date_string() -> String:
	var now := now_parts()
	return date_string(int(now["year"]), int(now["month"]), int(now["day"]))


static func date_string(year: int, month: int, day: int) -> String:
	return "%04d-%02d-%02d" % [year, month, day]


static func iso_string(date_text: String, hour: int, minute: int) -> String:
	if date_text == "":
		return ""
	return "%sT%02d:%02d:00" % [date_text, hour, minute]


static func parse_iso(value: String) -> Dictionary:
	if value == "":
		return {}
	var localized := jst_iso_string(value)
	if localized == "":
		return {}
	var date_part := localized.substr(0, 10)
	var pieces := date_part.split("-")
	if pieces.size() != 3:
		return {}
	return {
		"year": int(pieces[0]),
		"month": int(pieces[1]),
		"date": date_part,
		"hour": int(localized.substr(11, 2)) if localized.length() >= 13 else -1,
		"minute": round_minute_to_step(int(localized.substr(14, 2))) if localized.length() >= 16 else -1,
	}


static func jst_iso_string(value: String) -> String:
	# The API may return either the legacy UTC value or the current JST value.
	# Normalize both before displaying or editing a scheduled memo.
	if value.length() < 16:
		return ""
	var date_part := value.substr(0, 10)
	var date_pieces := date_part.split("-")
	if date_pieces.size() != 3:
		return ""
	var datetime := {
		"year": int(date_pieces[0]),
		"month": int(date_pieces[1]),
		"day": int(date_pieces[2]),
		"hour": int(value.substr(11, 2)),
		"minute": int(value.substr(14, 2)),
		"second": int(value.substr(17, 2)) if value.length() >= 19 else 0,
	}
	var unix_time := Time.get_unix_time_from_datetime_dict(datetime)
	var offset_seconds := _utc_offset_seconds(value)
	var jst := Time.get_datetime_dict_from_unix_time(unix_time - offset_seconds + 9 * 60 * 60)
	return "%04d-%02d-%02dT%02d:%02d:%02d+09:00" % [
		int(jst["year"]), int(jst["month"]), int(jst["day"]),
		int(jst["hour"]), int(jst["minute"]), int(jst["second"]),
	]


static func _utc_offset_seconds(value: String) -> int:
	if value.ends_with("Z"):
		return 0
	var plus := value.rfind("+")
	var minus := value.rfind("-")
	var offset_start: int = maxi(plus, minus)
	if offset_start <= 10 or value.length() < offset_start + 6:
		# Times sent by the app have no offset and are Japan Standard Time.
		return 9 * 60 * 60
	var offset := int(value.substr(offset_start + 1, 2)) * 60 * 60 + int(value.substr(offset_start + 4, 2)) * 60
	return offset if value.substr(offset_start, 1) == "+" else -offset


static func move_month(year: int, month: int, delta: int) -> Dictionary:
	var next_year := year
	var next_month := month + delta
	while next_month < 1:
		next_month += 12
		next_year -= 1
	while next_month > 12:
		next_month -= 12
		next_year += 1
	return {"year": next_year, "month": next_month}


static func days_in_month(year: int, month: int) -> int:
	match month:
		2:
			return 29 if is_leap_year(year) else 28
		4, 6, 9, 11:
			return 30
		_:
			return 31


static func is_leap_year(year: int) -> bool:
	return year % 400 == 0 or (year % 4 == 0 and year % 100 != 0)


static func first_weekday(year: int, month: int) -> int:
	var first_day := {
		"year": year,
		"month": month,
		"day": 1,
		"hour": 0,
		"minute": 0,
		"second": 0,
	}
	return int(Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_dict(first_day))["weekday"])


static func round_minute_to_step(value: int, step := 5) -> int:
	return int(clamp(round(float(value) / float(step)) * float(step), 0.0, 55.0))
