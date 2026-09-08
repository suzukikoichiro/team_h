import datetime
import json
from zoneinfo import ZoneInfo

from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

from ..models import StudentUser, TeacherUser, UserMemo
from .api_common import chat_context, session_user_position

JST = ZoneInfo("Asia/Tokyo")


def _serialize_memo(memo):
    return {
        "id": memo.id,
        "text": memo.text,
        "status": memo.status,
        "status_label": dict(UserMemo.STATUS_CHOICES).get(memo.status, memo.status),
        # Calendar input is entered and displayed in Japan time.  Convert from
        # the UTC value stored by Django explicitly so this stays correct even
        # if the server process has a different active timezone.
        "scheduled_at": timezone.localtime(memo.scheduled_at, JST).isoformat() if memo.scheduled_at else "",
        "source": memo.source,
        "source_label": "先生" if memo.source == "teacher" else "自分",
        "created_at": memo.created_at.isoformat(),
        "updated_at": memo.updated_at.isoformat(),
    }


def _parse_memo_schedule(value):
    value = str(value or "").strip()
    if not value:
        return None
    try:
        parsed = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if timezone.is_naive(parsed):
        parsed = timezone.make_aware(parsed, JST)
    return parsed


def memos(request):
    school, user_id, _school_code = chat_context(request)
    if school is None:
        return JsonResponse({"memos": []}, status=401)
    status = request.GET.get("status", "").strip()
    qs = UserMemo.objects.filter(school=school, user_id=user_id)
    if status and status != "all":
        qs = qs.filter(status=status)
    if request.GET.get("scheduled", "").strip() == "1":
        qs = qs.filter(status="planned", scheduled_at__isnull=False)
    qs = qs.order_by("-updated_at")[:200]
    return JsonResponse({"memos": [_serialize_memo(memo) for memo in qs]})


@csrf_exempt
@require_POST
def memo_create(request):
    school, user_id, _school_code = chat_context(request)
    if school is None:
        return JsonResponse({"error": "not_logged_in"}, status=401)
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "invalid_json"}, status=400)
    text = str(data.get("text", "")).strip()
    status = str(data.get("status", "none")).strip()
    if not text:
        return JsonResponse({"error": "empty_text"}, status=400)
    if status not in dict(UserMemo.STATUS_CHOICES):
        status = "none"
    scheduled_at = _parse_memo_schedule(data.get("scheduled_at"))
    memo = UserMemo.objects.create(
        school=school,
        user_id=user_id,
        text=text[:1000],
        status=status,
        scheduled_at=scheduled_at if status == "planned" else None,
        source="personal",
    )
    return JsonResponse({"memo": _serialize_memo(memo)})


@csrf_exempt
@require_POST
def memo_update(request):
    school, user_id, _school_code = chat_context(request)
    if school is None:
        return JsonResponse({"error": "not_logged_in"}, status=401)
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "invalid_json"}, status=400)
    memo = UserMemo.objects.filter(school=school, user_id=user_id, id=int(data.get("id", 0))).first()
    if memo is None:
        return JsonResponse({"error": "not_found"}, status=404)
    if "status" in data:
        status = str(data.get("status", "")).strip()
        if status in dict(UserMemo.STATUS_CHOICES):
            memo.status = status
    if "text" in data:
        text = str(data.get("text", "")).strip()
        if text:
            memo.text = text[:1000]
    if "scheduled_at" in data:
        memo.scheduled_at = _parse_memo_schedule(data.get("scheduled_at"))
    if memo.status != "planned":
        memo.scheduled_at = None
    memo.save()
    return JsonResponse({"memo": _serialize_memo(memo)})


@csrf_exempt
@require_POST
def memo_delete(request):
    school, user_id, _school_code = chat_context(request)
    if school is None:
        return JsonResponse({"error": "not_logged_in"}, status=401)
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "invalid_json"}, status=400)
    deleted, _ = UserMemo.objects.filter(school=school, user_id=user_id, id=int(data.get("id", 0))).delete()
    return JsonResponse({"success": bool(deleted), "id": int(data.get("id", 0))})


def teacher_memo_targets(request):
    school, user_id, _school_code = chat_context(request)
    if school is None:
        return JsonResponse({"classes": [], "students": []}, status=401)
    if session_user_position(request) != 1:
        return JsonResponse({"classes": [], "students": []}, status=403)
    teacher = TeacherUser.objects.filter(school=school, user_id=user_id).prefetch_related("classes").first()
    if teacher is None:
        return JsonResponse({"classes": [], "students": []}, status=404)

    class_ids = list(teacher.classes.values_list("class_id", flat=True))
    classes = teacher.classes.order_by("grade", "class_id")
    students = (
        StudentUser.objects.filter(school=school, classes__class_id__in=class_ids)
        .prefetch_related("classes")
        .distinct()
        .order_by("user_id")
    )
    return JsonResponse({
        "classes": [
            {
                "class_id": c.class_id,
                "label": f"{c.grade}年 {c.class_name}",
            }
            for c in classes
        ],
        "students": [
            {
                "user_id": s.user_id,
                "user_name": s.user_name,
                "classes": [
                    {
                        "class_id": c.class_id,
                        "label": f"{c.grade}年 {c.class_name}",
                    }
                    for c in s.classes.filter(class_id__in=class_ids).order_by("grade", "class_id")
                ],
            }
            for s in students
        ],
    })


@csrf_exempt
@require_POST
def teacher_memo_distribute(request):
    school, user_id, _school_code = chat_context(request)
    if school is None:
        return JsonResponse({"error": "not_logged_in"}, status=401)
    if session_user_position(request) != 1:
        return JsonResponse({"error": "teacher_only"}, status=403)
    teacher = TeacherUser.objects.filter(school=school, user_id=user_id).prefetch_related("classes").first()
    if teacher is None:
        return JsonResponse({"error": "teacher_not_found"}, status=404)
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "invalid_json"}, status=400)

    text = str(data.get("text", "")).strip()
    status = str(data.get("status", "none")).strip()
    scope = str(data.get("scope", "students")).strip()
    if not text:
        return JsonResponse({"error": "empty_text"}, status=400)
    if status not in dict(UserMemo.STATUS_CHOICES):
        status = "none"
    scheduled_at = _parse_memo_schedule(data.get("scheduled_at"))

    managed_class_ids = set(teacher.classes.values_list("class_id", flat=True))
    if not managed_class_ids:
        return JsonResponse({"error": "no_managed_classes"}, status=400)

    if scope == "classes":
        raw_class_ids = data.get("class_ids", [])
        target_class_ids = {int(class_id) for class_id in raw_class_ids if str(class_id).isdigit()}
        target_class_ids &= managed_class_ids
        if not target_class_ids:
            return JsonResponse({"error": "no_targets"}, status=400)
        students = StudentUser.objects.filter(school=school, classes__class_id__in=target_class_ids).distinct()
    else:
        raw_student_ids = data.get("student_ids", [])
        target_student_ids = {int(student_id) for student_id in raw_student_ids if str(student_id).isdigit()}
        if not target_student_ids:
            return JsonResponse({"error": "no_targets"}, status=400)
        students = StudentUser.objects.filter(
            school=school,
            user_id__in=target_student_ids,
            classes__class_id__in=managed_class_ids,
        ).distinct()

    created = []
    for student in students:
        memo = UserMemo.objects.create(
            school=school,
            user_id=student.user_id,
            text=text[:1000],
            status=status,
            scheduled_at=scheduled_at if status == "planned" else None,
            source="teacher",
        )
        created.append({
            "user_id": student.user_id,
            "user_name": student.user_name,
            "memo": _serialize_memo(memo),
        })
    return JsonResponse({"created_count": len(created), "targets": created})
