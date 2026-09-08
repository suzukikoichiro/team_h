from ..models import School, StudentUser, TeacherUser, UserProfile


def chat_context(request):
    school_pk = request.session.get("school_id")
    user_id = request.session.get("login_user_id")
    if not school_pk or not user_id:
        return None, None, None
    try:
        school = School.objects.get(id=school_pk)
    except School.DoesNotExist:
        return None, None, None
    return school, int(user_id), str(school.school_id)


def chat_user_name(school, user_id):
    for model in (TeacherUser, StudentUser):
        user = model.objects.filter(school=school, user_id=user_id).first()
        if user:
            return user.user_name
    return "ユーザー"


def chat_user_payload(school, user_id):
    teacher = TeacherUser.objects.filter(school=school, user_id=user_id).first()
    if teacher:
        profile = UserProfile.objects.filter(school=school, user_id=user_id).first()
        return {
            "user_id": teacher.user_id,
            "user_name": teacher.user_name,
            "role": "teacher",
            "role_label": "教職員",
            "gender": teacher.gender,
            "avatar_key": profile.avatar_key if profile and profile.avatar_key and profile.avatar_key != "default" else default_avatar_for_gender(teacher.gender),
        }
    student = StudentUser.objects.filter(school=school, user_id=user_id).first()
    if student:
        profile = UserProfile.objects.filter(school=school, user_id=user_id).first()
        return {
            "user_id": student.user_id,
            "user_name": student.user_name,
            "role": "student",
            "role_label": "学生",
            "gender": student.gender,
            "avatar_key": profile.avatar_key if profile and profile.avatar_key and profile.avatar_key != "default" else default_avatar_for_gender(student.gender),
        }
    return {
        "user_id": user_id,
        "user_name": "ユーザー",
        "role": "",
        "role_label": "会話済み",
        "gender": 2,
        "avatar_key": "skin_01",
    }


def default_avatar_for_gender(gender):
    try:
        return "skin_02" if int(gender) == 1 else "skin_01"
    except (TypeError, ValueError):
        return "skin_01"


def session_user_position(request):
    try:
        return int(request.session.get("user_position", -1))
    except (TypeError, ValueError):
        return -1
