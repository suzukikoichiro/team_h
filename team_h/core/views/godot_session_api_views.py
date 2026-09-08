from django.conf import settings
from django.contrib.auth import logout
from django.db.models import Q
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

from ..models import School, StudentUser, TeacherUser, UserProfile
from .api_common import default_avatar_for_gender as _default_avatar_for_gender


def godot_auto_login(request):
    school_id = request.session.get("school_id")
    user_id = request.session.get("login_user_id")
    user_position = request.session.get("user_position")

    if not school_id or not user_id:
        return JsonResponse({"logged_in": False}, status=401)

    username = "ユーザー"
    gender = 2
    avatar_key = "skin_01"

    try:
        student = StudentUser.objects.get(user_id=user_id, school__school_id=str(school_id))
        username = student.user_name
        gender = student.gender
    except StudentUser.DoesNotExist:
        try:
            teacher = TeacherUser.objects.get(user_id=user_id, school__school_id=str(school_id))
            username = teacher.user_name
            gender = teacher.gender
        except TeacherUser.DoesNotExist:
            pass

    try:
        school = School.objects.get(id=school_id)
        profile = UserProfile.objects.filter(school=school, user_id=user_id).first()
        avatar_key = (
            profile.avatar_key
            if profile and profile.avatar_key and profile.avatar_key != "default"
            else _default_avatar_for_gender(gender)
        )
    except School.DoesNotExist:
        avatar_key = _default_avatar_for_gender(gender)

    return JsonResponse({
        "logged_in": True,
        "school_id": school_id,
        "user_id": user_id,
        "user_position": user_position,
        "username": username,
        "gender": gender,
        "avatar_key": avatar_key,
    })


def nakama_session(request):
    school_id = request.session.get("school_id")
    user_id = request.session.get("login_user_id")
    user_position = request.session.get("user_position")

    if not school_id or not user_id:
        return JsonResponse({"logged_in": False}, status=401)

    user = None
    role = "unknown"

    try:
        user = StudentUser.objects.prefetch_related("classes").get(
            Q(school_id=school_id) | Q(school__school_id=str(school_id)),
            user_id=user_id,
        )
        role = "student"
    except StudentUser.DoesNotExist:
        try:
            user = TeacherUser.objects.prefetch_related("classes").get(
                Q(school_id=school_id) | Q(school__school_id=str(school_id)),
                user_id=user_id,
            )
            role = "teacher"
        except TeacherUser.DoesNotExist:
            return JsonResponse({"logged_in": False}, status=404)

    school_code = user.school.school_id
    class_ids = [str(class_id) for class_id in user.classes.values_list("class_id", flat=True)]
    custom_id = f"school:{school_code}:user:{user_id}"
    room_name = f"school-{school_code}-lobby"

    return JsonResponse({
        "logged_in": True,
        "nakama": {
            "scheme": settings.NAKAMA_SCHEME,
            "host": settings.NAKAMA_HOST,
            "port": settings.NAKAMA_PORT,
            "server_key": settings.NAKAMA_SERVER_KEY,
            "custom_id": custom_id,
            "username": user.user_name,
            "create": True,
            "vars": {
                "school_id": str(school_code),
                "school_code": str(school_code),
                "user_id": str(user_id),
                "role": role,
                "user_position": str(user_position),
                "class_ids": ",".join(class_ids),
            },
            "room_name": room_name,
        },
    })


@csrf_exempt
@require_POST
def api_logout(request):
    logout(request)
    request.session.flush()

    return JsonResponse({"success": True})
