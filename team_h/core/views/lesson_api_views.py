import json

from django.core.validators import URLValidator
from django.core.exceptions import ValidationError
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

from ..models import LessonRecording
from .api_common import chat_context, chat_user_name, session_user_position


def _is_teacher_session(request):
    return session_user_position(request) == 1


def _serialize_lesson_link(link):
    return {
        "id": link.id,
        "teacher_user_id": link.teacher_user_id,
        "teacher_user_name": link.teacher_user_name,
        "title": link.title,
        "description": link.description,
        "link_url": link.video_url,
        "created_at": link.created_at.isoformat(),
    }


def lesson_recordings(request):
    """Return shared lesson links.  The legacy model name is retained for DB compatibility."""
    school, _user_id, _school_code = chat_context(request)
    if school is None:
        return JsonResponse({"links": []}, status=401)
    links = LessonRecording.objects.filter(school=school).order_by("-created_at")[:100]
    return JsonResponse({"links": [_serialize_lesson_link(link) for link in links]})


@csrf_exempt
@require_POST
def lesson_recording_post(request):
    """Create a link share; file uploads and video-specific payloads are not accepted."""
    school, user_id, _school_code = chat_context(request)
    if school is None:
        return JsonResponse({"error": "not_logged_in"}, status=401)
    if not _is_teacher_session(request):
        return JsonResponse({"error": "teacher_only"}, status=403)
    if request.content_type and request.content_type.startswith("multipart/form-data"):
        return JsonResponse({"errors": {"link_url": ["ファイルは投稿できません。URLを入力してください"]}}, status=400)
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "invalid_json"}, status=400)

    title = str(data.get("title", "")).strip()
    link_url = str(data.get("link_url", "")).strip()
    if not title or not link_url:
        return JsonResponse({"errors": {"link": ["タイトルと共有URLを入力してください"]}}, status=400)
    try:
        URLValidator(schemes=["http", "https"])(link_url)
    except ValidationError:
        return JsonResponse({"errors": {"link_url": ["http:// または https:// で始まるURLを入力してください"]}}, status=400)

    link = LessonRecording.objects.create(
        school=school,
        teacher_user_id=user_id,
        teacher_user_name=chat_user_name(school, user_id),
        title=title[:120],
        description=str(data.get("description", "")).strip()[:1000],
        video_url=link_url[:500],
    )
    return JsonResponse({"link": _serialize_lesson_link(link)})
