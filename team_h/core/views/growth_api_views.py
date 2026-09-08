import json

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

from ..growth_points import award_growth_points, growth_summary_for_school
from ..models import School


def _growth_context(request):
    school_pk = request.session.get("school_id")
    user_id = request.session.get("login_user_id")
    if not school_pk or not user_id:
        return None, None
    try:
        school = School.objects.get(id=school_pk)
    except School.DoesNotExist:
        return None, None
    return school, int(user_id)


def growth_summary(request):
    school, _user_id = _growth_context(request)
    if school is None:
        return JsonResponse({"error": "not_logged_in"}, status=401)
    return JsonResponse({"growth": growth_summary_for_school(school)})


@csrf_exempt
@require_POST
def growth_event(request):
    school, user_id = _growth_context(request)
    if school is None:
        return JsonResponse({"error": "not_logged_in"}, status=401)
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "invalid_json"}, status=400)

    event_type = str(data.get("event_type", "")).strip()
    target_id = int(data.get("target_id", 0) or 0)
    if event_type == "lesson_recording_view":
        event_key = f"recording:{target_id}"
    elif event_type == "lesson_live_join":
        event_key = f"live:{target_id}"
    else:
        return JsonResponse({"error": "unsupported_event"}, status=400)

    _event, created = award_growth_points(school, user_id, event_type, event_key)
    return JsonResponse({
        "created": created,
        "growth": growth_summary_for_school(school),
    })
