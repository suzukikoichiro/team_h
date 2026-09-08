import json
import re

from django.db.models import Q
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

from ..models import StudentUser, TeacherUser, UserProfile
from .api_common import chat_context, chat_user_name, chat_user_payload, default_avatar_for_gender


def _profile_user_payload(school, user_id):
    base = chat_user_payload(school, user_id)
    profile = UserProfile.objects.filter(school=school, user_id=user_id).first()
    if profile is None:
        return {
            **base,
            "display_name": base["user_name"],
            "nickname": "",
            "age": None,
            "hobbies": "",
            "message": "",
            "avatar_key": default_avatar_for_gender(base.get("gender", 2)),
        }
    return {
        **base,
        "display_name": base["user_name"],
        "nickname": profile.nickname,
        "age": profile.age,
        "hobbies": profile.hobbies,
        "message": profile.message,
        "avatar_key": profile.avatar_key if profile.avatar_key and profile.avatar_key != "default" else default_avatar_for_gender(base.get("gender", 2)),
    }


def profile_me(request):
    school, user_id, _school_code = chat_context(request)
    if school is None:
        return JsonResponse({"error": "not_logged_in"}, status=401)
    return JsonResponse({"profile": _profile_user_payload(school, user_id)})


@csrf_exempt
@require_POST
def profile_save(request):
    school, user_id, _school_code = chat_context(request)
    if school is None:
        return JsonResponse({"error": "not_logged_in"}, status=401)
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "invalid_json"}, status=400)

    age = data.get("age", None)
    if age in ("", None):
        age_value = None
    else:
        if isinstance(age, bool) or isinstance(age, float):
            return JsonResponse({"errors": {"age": ["年齢は整数で入力してください"]}}, status=400)
        if isinstance(age, int):
            age_value = age
        elif isinstance(age, str) and re.fullmatch(r"[0-9]+", age):
            age_value = int(age)
        else:
            return JsonResponse({"errors": {"age": ["年齢は整数で入力してください"]}}, status=400)
        if age_value < 0 or age_value > 120:
            return JsonResponse({"errors": {"age": ["年齢は0から120の範囲で入力してください"]}}, status=400)

    profile, _created = UserProfile.objects.get_or_create(
        school=school,
        user_id=user_id,
        defaults={"display_name": chat_user_name(school, user_id)},
    )
    base_payload = chat_user_payload(school, user_id)
    default_avatar = default_avatar_for_gender(base_payload.get("gender", 2))
    profile.display_name = chat_user_name(school, user_id)
    profile.nickname = str(data.get("nickname", "")).strip()[:50]
    profile.age = age_value
    profile.hobbies = str(data.get("hobbies", "")).strip()[:300]
    profile.message = str(data.get("message", "")).strip()[:300]
    profile.avatar_key = str(data.get("avatar_key", default_avatar)).strip()[:50] or default_avatar
    profile.save()
    return JsonResponse({"profile": _profile_user_payload(school, user_id)})


def profile_search(request):
    school, user_id, _school_code = chat_context(request)
    if school is None:
        return JsonResponse({"profiles": []}, status=401)
    query = request.GET.get("q", "").strip()
    if query == "":
        return JsonResponse({"profiles": []})

    profiles = UserProfile.objects.filter(school=school).exclude(user_id=user_id)
    filters = (
        Q(display_name__icontains=query) |
        Q(nickname__icontains=query) |
        Q(hobbies__icontains=query) |
        Q(message__icontains=query)
    )
    if query.isdigit():
        filters |= Q(user_id=int(query))
    matched_ids = set(profiles.filter(filters).values_list("user_id", flat=True))

    base_name_ids = set()
    teacher_ids = TeacherUser.objects.filter(school=school, user_name__icontains=query).exclude(user_id=user_id).values_list("user_id", flat=True)
    student_ids = StudentUser.objects.filter(school=school, user_name__icontains=query).exclude(user_id=user_id).values_list("user_id", flat=True)
    base_name_ids.update(teacher_ids)
    base_name_ids.update(student_ids)

    user_ids = sorted(matched_ids | base_name_ids)[:30]
    return JsonResponse({"profiles": [_profile_user_payload(school, target_id) for target_id in user_ids]})
