from functools import wraps
from django.shortcuts import redirect
from django.contrib import messages
from django.http import JsonResponse
from .models import TeacherUser
from django.views.decorators.csrf import csrf_exempt
from functools import wraps


#管理者認証
def admin_required(view_func):
    @wraps(view_func)
    def wrapper(request, *args, **kwargs):
        if request.session.get('user_position') != 0:
            messages.error(request, 'このページには管理者のみアクセスできます。')
            return redirect('home')
        return view_func(request, *args, **kwargs)
    return wrapper



# 教職員認証
def teacher_required(view_func):
    @wraps(view_func)
    @csrf_exempt
    def wrapper(request, *args, **kwargs):
        if request.session.get("user_position") != 1:
            return JsonResponse({"error": "unauthorized"}, status=401)

        teacher_id = request.session.get("login_user_id")
        school_id = request.session.get("school_id")

        if not teacher_id or not school_id:
            return JsonResponse({"error": "unauthorized"}, status=401)

        try:
            teacher = TeacherUser.objects.get(
                user_id=teacher_id,
                school_id=school_id
            )
        except TeacherUser.DoesNotExist:
            return JsonResponse({"error": "teacher not found"}, status=404)

        request.teacher = teacher
        return view_func(request, *args, **kwargs)

    return wrapper