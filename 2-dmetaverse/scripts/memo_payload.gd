extends RefCounted

const MemoSchedule := preload("res://scripts/memo_schedule.gd")


static func personal_save(text: String, status: String, scheduled_at: String) -> Dictionary:
	return {
		"text": text,
		"status": status,
		"scheduled_at": scheduled_at,
	}


static func status_update(status: String, existing_scheduled_at: String) -> Dictionary:
	var payload := {"status": status}
	if status == "planned" and existing_scheduled_at == "":
		var now := MemoSchedule.now_parts()
		payload["scheduled_at"] = MemoSchedule.iso_string(
			MemoSchedule.date_string(int(now["year"]), int(now["month"]), int(now["day"])),
			int(now["hour"]),
			int(now["minute"])
		)
	return payload


static func teacher_distribution(scope: String, class_ids: Array, student_ids: Array, text: String, status: String, scheduled_at: String) -> Dictionary:
	var payload := {
		"scope": scope,
		"class_ids": class_ids,
		"student_ids": student_ids,
		"text": text,
		"status": status,
	}
	if status == "planned":
		payload["scheduled_at"] = scheduled_at
	return payload
