from django.views.decorators.csrf import csrf_exempt
from django.shortcuts import get_object_or_404
from django.http import JsonResponse
from ..models import School, StudentUser, Class
from ..forms import StudentRegisterForm
from django.contrib.auth.hashers import make_password
import datetime
import json


#クラスチェックボックスのためにクラスを渡すメン
@csrf_exempt
def get_classes(request):
    school_id = request.GET.get("school_id")

    if not school_id:
        return JsonResponse({"classes": []})

    classes = Class.objects.filter(school_id=school_id).order_by("grade", "class_id")

    class_data = []
    for c in classes:
        class_data.append({
            "id": c.class_id,
            "label": f"{c.grade}年 {c.class_name}",
        })

    return JsonResponse({"classes": class_data})


#生徒情報取得
@csrf_exempt
def get_student(request):
    student_id = request.GET.get("student_id")
    school_id = request.GET.get("school_id")

    if not school_id:
        return JsonResponse({"error": "school_id が必要です"}, status=400)

    try:
        school = School.objects.get(school_id=school_id)
    except School.DoesNotExist:
        return JsonResponse({"error": "対象の学校が見つかりません"}, status=404)

    if not student_id or student_id.lower() in ["null", "none", ""]:
        return JsonResponse({"student": None}, status=200)

    try:
        student_id_int = int(student_id)
    except ValueError:
        return JsonResponse({"error": "student_id が不正です"}, status=400)

    try:
        student = StudentUser.objects.get(user_id=student_id_int, school=school)
    except StudentUser.DoesNotExist:
        return JsonResponse({"error": "対象の学生が見つかりません"}, status=404)

    return JsonResponse({
        "user_id": student.user_id,
        "user_name": student.user_name,
        "user_spell": student.user_spell,
        "gender": student.gender,
        "birthdate": student.birthdate.strftime("%Y-%m-%d"),
        "user_password": "",
        "class_ids": list(student.classes.values_list("class_id", flat=True)),
    }, status=200)





#教職員による学生登録
@csrf_exempt
def receive_form(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST メソッドで送信してください"}, status=405)

    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "JSON データが不正です"}, status=400)

    school_id = data.get("school_id")
    if not school_id:
        return JsonResponse({"error": "学校IDが送信されていません"}, status=400)

    try:
        school = School.objects.get(school_id=school_id)
    except School.DoesNotExist:
        return JsonResponse({"error": "存在しない学校IDです"}, status=400)

    gender_map = {"男性": 0, "女性": 1, "その他": 2}

    try:
        birthdate_str = data.get("birthdate", "")
        birthdate = datetime.datetime.strptime(birthdate_str, "%Y-%m-%d").date()
    except ValueError:
        return JsonResponse({
            "status": "error",
            "errors": {"birthdate": ["生年月日は YYYY-MM-DD 形式で入力してください"]}
        }, status=400)
    
    form_data = {
        "user_id": data.get("user_id"),
        "user_name": data.get("user_name"),
        "user_spell": data.get("user_spell"),
        "gender": int(data.get("gender", 2)),
        "birthdate": birthdate,
        "user_password": data.get("user_password"),
        "user_position": 2,
    }

    form = StudentRegisterForm(form_data)
    form.school_id = school.id

    if not form.is_valid():
        return JsonResponse({
            "status": "error",
            "errors": form.errors
        }, status=400)

    student = form.save(commit=False)
    student.school = school
    student.user_password = make_password(form.cleaned_data['user_password'])
    student.save()

    class_ids = data.get("class_ids", [])
    class_ids = [int(i) for i in class_ids]
    class_qs = Class.objects.filter(class_id__in=class_ids, school=school)
    student.classes.set(class_qs)

    return JsonResponse({"status": "ok", "message": "登録完了"})


#学生更新
@csrf_exempt
def update_student(request, student_id):
    if request.method != "PUT":
        return JsonResponse({"error": "PUT メソッドで送信してください"}, status=405)

    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "JSON データが不正です"}, status=400)

    school_id = data.get("school_id")
    if not school_id:
        return JsonResponse({"error": "school_id が必要です"}, status=400)

    try:
        school = School.objects.get(school_id=school_id)
        student = StudentUser.objects.get(user_id=student_id, school=school)
    except (School.DoesNotExist, StudentUser.DoesNotExist):
        return JsonResponse({"error": "対象の学生が見つかりません"}, status=404)

    #入力値反映
    student.user_name = data.get("user_name", student.user_name)
    student.user_spell = data.get("user_spell", student.user_spell)
    student.gender = int(data.get("gender", student.gender))
    student.birthdate = datetime.datetime.strptime(data.get("birthdate"), "%Y-%m-%d").date()

    if data.get("user_password"):
        student.user_password = make_password(data.get("user_password"))

    student.save()

    class_ids = [int(c) for c in data.get("class_ids", [])]
    class_qs = Class.objects.filter(class_id__in=class_ids, school=school)
    student.classes.set(class_qs)

    return JsonResponse({"message": "更新完了"}, status=200)


