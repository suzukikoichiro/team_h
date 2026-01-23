from django.views.decorators.csrf import csrf_exempt
from django.http import JsonResponse
from ..models import School, StudentUser, Class
from ..forms import StudentRegisterForm
from django.contrib.auth.hashers import make_password
import datetime
import json
from ..decorators import teacher_required
from ..models import  StudentUser, TeacherUser
from django.views.decorators.http import require_http_methods
from django.shortcuts import get_object_or_404
from django.contrib.auth.hashers import check_password




#クラスチェックボックスのためにクラスを渡すメン
@teacher_required
def get_classes(request):
    school_id = request.session.get("school_id")
    print("school_id:", request.session.get("school_id"))


    if not school_id:
        return JsonResponse({"classes": []}, status=401)

    classes = Class.objects.filter(school_id=school_id).order_by("grade", "class_id")

    return JsonResponse({
        "classes": [
            {
                "id": c.class_id,
                "label": f"{c.grade}年 {c.class_name}",
            }
            for c in classes
        ]
    })



#生徒情報取得
@teacher_required
def get_student(request):
    student_id = request.GET.get("student_id")

    teacher = request.teacher
    school = teacher.school

    if not student_id:
        return JsonResponse({"student": None}, status=200)

    try:
        student = StudentUser.objects.get(
            user_id=int(student_id),
            school=school
        )
    except StudentUser.DoesNotExist:
        return JsonResponse({"error": "対象の学生が見つかりません"}, status=404)

    return JsonResponse({
        "student": {
            "user_id": student.user_id,
            "user_name": student.user_name,
            "user_spell": student.user_spell,
            "gender": student.gender,
            "birthdate": student.birthdate.strftime("%Y-%m-%d"),
            "class_ids": list(student.classes.values_list("class_id", flat=True)),
        }
    })



@csrf_exempt
def receive_form(request):
    if request.method != "POST":
        return JsonResponse(
            {"error": "POST メソッドで送信してください"},
            status=405
        )

    # =========================
    # ログイン必須
    # =========================
    school_id = request.session.get("school_id")
    if not school_id:
        return JsonResponse(
            {"error": "ログインしていません"},
            status=401
        )

    try:
        school = School.objects.get(id=school_id)
    except School.DoesNotExist:
        return JsonResponse(
            {"error": "学校情報が無効です"},
            status=400
        )

    # =========================
    # JSON 読み取り
    # =========================
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse(
            {"error": "JSON データが不正です"},
            status=400
        )

    # =========================
    # 生年月日
    # =========================
    try:
        birthdate_str = data.get("birthdate", "")
        birthdate = datetime.datetime.strptime(
            birthdate_str, "%Y-%m-%d"
        ).date()
    except ValueError:
        return JsonResponse({
            "status": "error",
            "errors": {
                "birthdate": ["生年月日は YYYY-MM-DD 形式で入力してください"]
            }
        }, status=400)

    # =========================
    # user_id（手動 or 自動）
    # =========================
    user_id = data.get("user_id")
    if user_id in ("", None):
        user_id = None  # ← 自動採番

    # =========================
    # フォーム
    # =========================
    form_data = {
        "user_id": user_id,
        "user_name": data.get("user_name"),
        "user_spell": data.get("user_spell"),
        "gender": int(data.get("gender", 2)),
        "birthdate": birthdate,
        "user_password": data.get("user_password"),
        "user_position": 2,  # 学生固定
    }

    form = StudentRegisterForm(form_data)
    form.school_id = school.id

    if not form.is_valid():
        print("REGISTER ERROR:", form.errors)
        return JsonResponse({
            "status": "error",
            "errors": form.errors
        }, status=400)

    # =========================
    # 保存
    # =========================
    student = form.save(commit=False)
    student.school = school
    student.user_password = make_password(
        form.cleaned_data["user_password"]
    )
    student.save()

    # =========================
    # クラス紐付け
    # =========================
    class_ids = data.get("class_ids", [])
    class_ids = [int(i) for i in class_ids]

    class_qs = Class.objects.filter(
        class_id__in=class_ids,
        school=school
    )
    student.classes.set(class_qs)

    return JsonResponse({
        "status": "ok",
        "message": "登録完了"
    })



# 学生更新
@teacher_required
def update_student(request, student_id):
    if request.method != "PUT":
        return JsonResponse({"error": "PUT only"}, status=405)

    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "JSONが不正です"}, status=400)

    teacher = request.teacher
    school = teacher.school

    try:
        student = StudentUser.objects.get(
            user_id=student_id,
            school=school
        )
    except StudentUser.DoesNotExist:
        return JsonResponse({"error": "対象の学生が見つかりません"}, status=404)

    # 基本情報更新
    if "user_name" in data:
        student.user_name = data["user_name"]

    if "user_spell" in data:
        student.user_spell = data["user_spell"]

    if "gender" in data:
        student.gender = int(data["gender"])

    if "birthdate" in data and data["birthdate"]:
        student.birthdate = datetime.datetime.strptime(
            data["birthdate"], "%Y-%m-%d"
        ).date()

    if data.get("user_password"):
        student.user_password = make_password(data["user_password"])

    student.save()

    # ★ 重要：class_ids が送られてきた時だけ更新する
    if "class_ids" in data:
        class_ids = [int(c) for c in data["class_ids"]]
        class_qs = Class.objects.filter(
            class_id__in=class_ids,
            school=school
        )
        student.classes.set(class_qs)

    return JsonResponse({"message": "更新完了"})






@teacher_required
@csrf_exempt
def delete_student(request, student_id):
    if request.method != "POST":
        return JsonResponse({"error": "POST only"}, status=405)

    teacher = request.teacher
    school = teacher.school

    try:
        student = StudentUser.objects.get(
            user_id=student_id,
            school=school
        )
    except StudentUser.DoesNotExist:
        return JsonResponse({"error": "student not found"}, status=404)

    student.delete()
    return JsonResponse({"status": "ok", "message": "削除完了"})


@teacher_required
def get_students(request):
    teacher = request.teacher
    school = teacher.school

    students = (
        StudentUser.objects
        .filter(school=school)
        .prefetch_related("classes")
        .order_by("user_id")
    )

    return JsonResponse({
        "students": [
            {
                "id": s.id,
                "user_id": s.user_id,
                "user_name": s.user_name,
                "classes": [
                    {
                        "id": c.class_id,
                        "name": c.class_name,
                        "grade": c.grade,
                    }
                    for c in s.classes.all()
                ]
            }
            for s in students
        ]
    })


#登録
@require_http_methods(["POST"])
def api_student_create(request):
    data = json.loads(request.body)

    student = StudentUser.objects.create(
        user_id=data["user_id"],
        user_name=data["user_name"],
        school=request.teacher.school,
    )

    return JsonResponse({
        "id": student.id,
        "result": "ok",
    })


#更新
@require_http_methods(["PUT"])
def api_student_edit(request, student_id):
    student = get_object_or_404(StudentUser, id=student_id)
    data = json.loads(request.body)

    student.user_name = data["user_name"]
    student.save()

    return JsonResponse({"result": "ok"})


#削除
@require_http_methods(["DELETE"])
def api_student_delete(request, student_id):
    student = get_object_or_404(StudentUser, id=student_id)
    student.delete()

    return JsonResponse({"result": "ok"})


#Godotログインマン
def godot_auto_login(request):
    school_id = request.session.get("school_id")
    user_id = request.session.get("login_user_id")
    user_position = request.session.get("user_position")

    if not school_id or not user_id:
        return JsonResponse(
            {"logged_in": False},
            status=401
        )

    return JsonResponse({
        "logged_in": True,
        "school_id": school_id,
        "user_id": user_id,
        "user_position": user_position,
    })
