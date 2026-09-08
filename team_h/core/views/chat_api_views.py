import json
import uuid

from django.db.models import Max, Q
from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

from ..growth_points import award_growth_points
from ..models import ChatHiddenState, ChatMessage, ChatReadState, StudentUser, TeacherUser
from .api_common import chat_context, chat_user_name, chat_user_payload


def chat_users(request):
    school_id = request.session.get("school_id")
    login_user_id = request.session.get("login_user_id")

    if not school_id or not login_user_id:
        return JsonResponse({"users": []}, status=401)

    query = request.GET.get("q", "").strip()
    filters = Q(school_id=school_id)
    if query:
        query_filter = Q(user_name__icontains=query)
        if query.isdigit():
            query_filter |= Q(user_id=int(query))
        filters &= query_filter

    teachers = TeacherUser.objects.filter(filters).order_by("user_id")
    students = StudentUser.objects.filter(filters).order_by("user_id")

    users = []
    for teacher in teachers:
        if teacher.user_id == int(login_user_id):
            continue
        users.append({
            "user_id": teacher.user_id,
            "user_name": teacher.user_name,
            "role": "teacher",
            "role_label": "教職員",
        })

    for student in students:
        if student.user_id == int(login_user_id):
            continue
        users.append({
            "user_id": student.user_id,
            "user_name": student.user_name,
            "role": "student",
            "role_label": "学生",
        })

    return JsonResponse({"users": users})


def _validate_chat_room(room_name, school_code, user_id):
    lobby = f"school-{school_code}-lobby"
    if room_name == lobby:
        return True

    prefix = f"school-{school_code}-dm-"
    if not room_name.startswith(prefix):
        return False
    parts = room_name[len(prefix):].split("-")
    if len(parts) != 2 or not all(part.isdigit() for part in parts):
        return False
    a, b = sorted([int(parts[0]), int(parts[1])])
    expected = f"{prefix}{a}-{b}"
    return room_name == expected and user_id in (a, b)


def _serialize_chat_message(message):
    created_ts = message.created_at.timestamp()
    return {
        "id": message.client_message_id or str(message.id),
        "server_id": message.id,
        "user_id": message.sender_user_id,
        "user_name": message.sender_user_name,
        "message": message.message,
        "time": created_ts,
        "created_at": message.created_at.isoformat(),
        "chat_room": message.room_name,
    }


def _room_title_for_user(school, room_name, school_code, user_id):
    lobby = f"school-{school_code}-lobby"
    if room_name == lobby:
        return "全体チャット", "学校全体", None
    prefix = f"school-{school_code}-dm-"
    ids = room_name[len(prefix):].split("-")
    if len(ids) != 2:
        return "個人チャット", "会話済み", None
    other_id = int(ids[0]) if int(ids[1]) == user_id else int(ids[1])
    user = chat_user_payload(school, other_id)
    return f'{user["user_name"]}  ID:{other_id}', user["role_label"] or "会話済み", user


def chat_rooms(request):
    school, user_id, school_code = chat_context(request)
    if school is None:
        return JsonResponse({"rooms": []}, status=401)

    lobby = f"school-{school_code}-lobby"
    dm_prefix = f"school-{school_code}-dm-"
    dm_contains = [
        f"{dm_prefix}{user_id}-",
        f"-{user_id}",
    ]

    room_names = {lobby}
    for room_name in ChatMessage.objects.filter(school=school).values_list("room_name", flat=True).distinct():
        if room_name == lobby or any(piece in room_name for piece in dm_contains):
            if _validate_chat_room(room_name, school_code, user_id):
                room_names.add(room_name)

    last_by_room = {
        item["room_name"]: item["last_at"]
        for item in ChatMessage.objects.filter(school=school, room_name__in=room_names)
        .values("room_name")
        .annotate(last_at=Max("created_at"))
    }
    read_states = {
        state.room_name: state.last_read_at
        for state in ChatReadState.objects.filter(school=school, user_id=user_id, room_name__in=room_names)
    }
    hidden_states = {
        state.room_name: state.hidden_before_at
        for state in ChatHiddenState.objects.filter(school=school, user_id=user_id, room_name__in=room_names)
    }

    rooms = []
    for room_name in sorted(room_names):
        title, sub_label, contact = _room_title_for_user(school, room_name, school_code, user_id)
        last_read_at = read_states.get(room_name)
        hidden_before_at = hidden_states.get(room_name)
        unread_qs = ChatMessage.objects.filter(school=school, room_name=room_name).exclude(sender_user_id=user_id)
        if hidden_before_at:
            unread_qs = unread_qs.filter(created_at__gt=hidden_before_at)
        if last_read_at:
            unread_qs = unread_qs.filter(created_at__gt=last_read_at)
        unread_count = unread_qs.count()
        visible_qs = ChatMessage.objects.filter(school=school, room_name=room_name)
        if hidden_before_at:
            visible_qs = visible_qs.filter(created_at__gt=hidden_before_at)
        last_message = visible_qs.order_by("-created_at").first()
        rooms.append({
            "room": room_name,
            "title": title,
            "sub_label": sub_label,
            "contact": contact,
            "unread_count": unread_count,
            "last_at": last_by_room.get(room_name).isoformat() if last_by_room.get(room_name) else "",
            "last_message": _serialize_chat_message(last_message) if last_message else None,
        })

    rooms.sort(key=lambda item: item["last_at"], reverse=True)
    return JsonResponse({"rooms": rooms})


def chat_messages(request):
    school, user_id, school_code = chat_context(request)
    if school is None:
        return JsonResponse({"messages": []}, status=401)
    room_name = request.GET.get("room", "")
    if not _validate_chat_room(room_name, school_code, user_id):
        return JsonResponse({"error": "invalid_room"}, status=403)

    limit = min(max(int(request.GET.get("limit", 100)), 1), 200)
    read_state = ChatReadState.objects.filter(school=school, user_id=user_id, room_name=room_name).first()
    last_read_at = read_state.last_read_at if read_state else None
    hidden_state = ChatHiddenState.objects.filter(school=school, user_id=user_id, room_name=room_name).first()
    hidden_before_at = hidden_state.hidden_before_at if hidden_state else None

    qs = ChatMessage.objects.filter(school=school, room_name=room_name)
    if hidden_before_at:
        qs = qs.filter(created_at__gt=hidden_before_at)
    qs = qs.order_by("-created_at")[:limit]
    messages = list(reversed(list(qs)))
    unread_start_id = ""
    for message in messages:
        if message.sender_user_id == user_id:
            continue
        if last_read_at is None or message.created_at > last_read_at:
            unread_start_id = message.client_message_id or str(message.id)
            break

    return JsonResponse({
        "room": room_name,
        "messages": [_serialize_chat_message(message) for message in messages],
        "unread_start_id": unread_start_id,
    })


@csrf_exempt
@require_POST
def chat_clear_history(request):
    school, user_id, school_code = chat_context(request)
    if school is None:
        return JsonResponse({"error": "not_logged_in"}, status=401)
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "invalid_json"}, status=400)

    scope = str(data.get("scope", "")).strip()
    now = timezone.now()
    if scope == "all":
        lobby = f"school-{school_code}-lobby"
        dm_prefix = f"school-{school_code}-dm-"
        room_names = {lobby}
        for candidate in ChatMessage.objects.filter(school=school).values_list("room_name", flat=True).distinct():
            if candidate == lobby or candidate.startswith(dm_prefix):
                if _validate_chat_room(candidate, school_code, user_id):
                    room_names.add(candidate)
        for room_name in room_names:
            ChatHiddenState.objects.update_or_create(
                school=school,
                user_id=user_id,
                room_name=room_name,
                defaults={"hidden_before_at": now},
            )
            ChatReadState.objects.update_or_create(
                school=school,
                user_id=user_id,
                room_name=room_name,
                defaults={"last_read_at": now},
            )
        return JsonResponse({"success": True, "scope": "all", "rooms": sorted(room_names)})

    room_name = str(data.get("room", ""))
    if not _validate_chat_room(room_name, school_code, user_id):
        return JsonResponse({"error": "invalid_room"}, status=403)
    ChatHiddenState.objects.update_or_create(
        school=school,
        user_id=user_id,
        room_name=room_name,
        defaults={"hidden_before_at": now},
    )
    ChatReadState.objects.update_or_create(
        school=school,
        user_id=user_id,
        room_name=room_name,
        defaults={"last_read_at": now},
    )
    return JsonResponse({"success": True, "room": room_name})


@csrf_exempt
@require_POST
def chat_messages_post(request):
    school, user_id, school_code = chat_context(request)
    if school is None:
        return JsonResponse({"error": "not_logged_in"}, status=401)
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "invalid_json"}, status=400)

    room_name = str(data.get("chat_room", ""))
    if not _validate_chat_room(room_name, school_code, user_id):
        return JsonResponse({"error": "invalid_room"}, status=403)
    text = str(data.get("message", "")).strip()
    if not text:
        return JsonResponse({"error": "empty_message"}, status=400)
    client_message_id = str(data.get("id", "")).strip()[:64] or uuid.uuid4().hex

    message, _created = ChatMessage.objects.get_or_create(
        school=school,
        room_name=room_name,
        client_message_id=client_message_id,
        defaults={
            "sender_user_id": user_id,
            "sender_user_name": chat_user_name(school, user_id),
            "message": text[:1000],
        },
    )
    ChatReadState.objects.update_or_create(
        school=school,
        user_id=user_id,
        room_name=room_name,
        defaults={"last_read_at": timezone.now()},
    )
    other_user_id = _other_user_id_from_dm_room(room_name, school_code, user_id)
    if other_user_id:
        award_growth_points(
            school,
            user_id,
            "chat_person",
            f"chat:{timezone.localdate().isoformat()}:{other_user_id}",
        )
    return JsonResponse({"message": _serialize_chat_message(message)})


@csrf_exempt
@require_POST
def chat_mark_read(request):
    school, user_id, school_code = chat_context(request)
    if school is None:
        return JsonResponse({"error": "not_logged_in"}, status=401)
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "invalid_json"}, status=400)
    room_name = str(data.get("room", ""))
    if not _validate_chat_room(room_name, school_code, user_id):
        return JsonResponse({"error": "invalid_room"}, status=403)
    latest = ChatMessage.objects.filter(school=school, room_name=room_name).order_by("-created_at").first()
    ChatReadState.objects.update_or_create(
        school=school,
        user_id=user_id,
        room_name=room_name,
        defaults={"last_read_at": latest.created_at if latest else timezone.now()},
    )
    return JsonResponse({"success": True})


def _other_user_id_from_dm_room(room_name, school_code, user_id):
    prefix = f"school-{school_code}-dm-"
    if not room_name.startswith(prefix):
        return None
    pieces = room_name.replace(prefix, "", 1).split("-")
    if len(pieces) != 2:
        return None
    try:
        ids = [int(pieces[0]), int(pieces[1])]
    except ValueError:
        return None
    if user_id not in ids:
        return None
    return ids[1] if ids[0] == user_id else ids[0]
