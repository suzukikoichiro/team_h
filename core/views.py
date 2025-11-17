from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages
from django.http import JsonResponse
from django.views.decorators.http import require_POST
from django.views.decorators.csrf import csrf_exempt
from functools import wraps
import json, datetime

from django.contrib.auth.hashers import make_password, check_password

from .forms import (
    SchoolLoginForm, SchoolRegisterForm, AdministratorRegisterForm,
    UserLoginForm, ClassForm, TeacherRegisterForm, StudentRegisterForm
)
from .models import (
    School, AdministratorUser, TeacherUser, StudentUser, Class
)


#デコレイト、真っすぐだね
def admin_required(view_func):
    @wraps(view_func)
    def wrapper(request, *args, **kwargs):
        if request.session.get('user_position') != 0:
            messages.error(request, 'このページには管理者のみアクセスできます。')
            return redirect('home')
        return view_func(request, *args, **kwargs)
    return wrapper


#認証するやつ
def authenticate_user(user_id, password, school_id):
    for model in [AdministratorUser, TeacherUser]:
        try:
            user = model.objects.get(user_id=user_id, school_id=school_id)
            if check_password(password, user.user_password):
                return user
        except model.DoesNotExist:
            continue
    return None


#クラス取得
def get_school_class(school_id, class_id):
    return get_object_or_404(Class, class_id=class_id, school_id=school_id)


#管理者はログイン後こちらに遷移
def home(request):
    return render(request, 'core/home.html')


#管理者以外はログイン後こちらに遷移
def test(request):
    return render(request, 'core/test.html')


#管理者以外は仮godot君へ
def godot(request):
    return render(request, 'godot/godot.html')


#学校ログイン
def school_login(request):
    message = None
    if request.method == "POST":
        form = SchoolLoginForm(request.POST)
        if form.is_valid():
            school_id = form.cleaned_data['school_id']
            school_password = form.cleaned_data['school_password']
            try:
                school = School.objects.get(school_id=school_id)
                if check_password(school_password, school.school_password):
                    request.session['school_id'] = school.id
                    request.session['school_name'] = school.school_name
                    return redirect('user_login')
                else:
                    message = "学校IDまたはパスワードが間違っています。"
            except School.DoesNotExist:
                message = "学校IDまたはパスワードが間違っています。"
    else:
        form = SchoolLoginForm()
    return render(request, 'core/school_login.html', {'form': form, 'message': message})


#学校ログアウト
def school_logout(request):
    request.session.flush()
    return redirect('school_login')


#ユーザーログイン
def user_login(request):
    school_id = request.session.get('school_id')
    if not school_id:
        return redirect('school_login')

    message = ""
    if request.method == "POST":
        form = UserLoginForm(request.POST)
        if form.is_valid():
            user_id = form.cleaned_data['user_id']
            password = form.cleaned_data['user_password']

            user = authenticate_user(user_id, password, school_id)
            if user:
                request.session['login_user_id'] = user.user_id
                request.session['user_position'] = user.user_position
                return redirect('home') if user.user_position == 0 else redirect('godot')
            else:
                message = "IDまたはパスワードが間違っています"
    else:
        form = UserLoginForm()

    return render(request, 'core/user_login.html', {'form': form, 'message': message})


#ユーザーログアウト
def user_logout(request):
    request.session.flush()
    return redirect('school_login')



#学校登録
def school_register(request):
    if request.method == 'POST':
        school_form = SchoolRegisterForm(request.POST)
        user_form = AdministratorRegisterForm(request.POST)

        if school_form.is_valid() and user_form.is_valid():
            school = school_form.save(commit=False)
            school.school_password = make_password(school_form.cleaned_data['school_password'])
            school.save()

            user = user_form.save(commit=False)
            user.school = school
            user.user_password = make_password(user_form.cleaned_data['user_password'])
            user.save()

            messages.success(request, '学校登録が完了しました。')
            return redirect('school_login')
    else:
        school_form = SchoolRegisterForm()
        user_form = AdministratorRegisterForm()

    return render(request, 'core/school_register.html', {
        'school_form': school_form,
        'user_form': user_form,
    })


#クラス登録
@admin_required
def class_create(request):
    if request.method == 'POST':
        form = ClassForm(request.POST)
        if form.is_valid():
            new_class = form.save(commit=False)
            new_class.school_id = request.session.get('school_id')
            new_class.save()
            messages.success(request, 'クラスを登録しました。')
            return redirect('class_list')
    else:
        form = ClassForm()
    return render(request, 'core/class_create.html', {'form': form})


#クラス一覧
@admin_required
def class_list(request):
    school_id = request.session.get('school_id')
    classes = Class.objects.filter(school_id=school_id).order_by('class_id')
    return render(request, 'core/class_list.html', {'classes': classes})


#クラス情報更新
@admin_required
def class_edit(request, class_id):
    school_id = request.session.get('school_id')
    c = get_school_class(school_id, class_id)
    if request.method == 'POST':
        form = ClassForm(request.POST, instance=c)
        if form.is_valid():
            form.save()
            messages.success(request, 'クラス情報を更新しました。')
            return redirect('class_list')
    else:
        form = ClassForm(instance=c)
    return render(request, 'core/class_edit.html', {'form': form, 'class_obj': c})


#クラス削除 *現在、class_edit.htmlの方で削除ボタンを無効化中
@admin_required
@require_POST
def class_delete(request, class_id):
    school_id = request.session.get('school_id')
    c = get_school_class(school_id, class_id)
    c.delete()
    return JsonResponse({'success': True, 'message': f'{c.class_name} を削除しました。'})


#教師登録
def teacher_register(request):
    school_id = request.session.get('school_id')
    if request.method == 'POST':
        form = TeacherRegisterForm(request.POST, school_id=school_id)
        if form.is_valid():
            school = School.objects.filter(id=school_id).first()
            if not school:
                return render(request, 'core/teacher_register.html', {
                    'form': form,
                    'error': '学校情報が見つかりません。',
                })
            teacher = form.save(commit=False)
            teacher.school = school
            teacher.user_password = make_password(form.cleaned_data['user_password'])
            teacher.save()
            form.save_m2m()
            messages.success(request, '教職員を登録しました。')
            return redirect('teacher_list')
    else:
        form = TeacherRegisterForm(school_id=school_id)
    return render(request, 'core/teacher_register.html', {'form': form})


#教師一覧
def teacher_list(request):
    school_id = request.session.get('school_id')
    teachers = TeacherUser.objects.select_related('school').prefetch_related('classes').filter(school_id=school_id)
    return render(request, 'core/teacher_list.html', {'teachers': teachers})


#教師情報更新
def teacher_edit(request, teacher_id):
    school_id = request.session.get('school_id')
    teacher = get_object_or_404(TeacherUser, id=teacher_id, school_id=school_id)

    if request.method == 'POST':
        form = TeacherRegisterForm(request.POST, instance=teacher, school_id=school_id)
        if form.is_valid():
            teacher.user_password = make_password(form.cleaned_data['user_password'])
            form.save(commit=True)
            messages.success(request, '教職員情報を更新しました。')
            return redirect('teacher_list')
    else:
        form = TeacherRegisterForm(instance=teacher, school_id=school_id)

    return render(request, 'core/teacher_edit.html', {'form': form, 'teacher': teacher})


#教師削除
@require_POST
def teacher_delete(request, teacher_id):
    teacher = get_object_or_404(TeacherUser, id=teacher_id)
    teacher.delete()
    return JsonResponse({'success': True, 'message': f'{teacher.user_name} を削除しました。'})


#学生登録
@csrf_exempt
def receive_form(request):
    if request.method != "POST":
        return JsonResponse({"error": "invalid method"}, status=405)

    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "JSON decode error"}, status=400)

    print("受信データ:", data)

    school_id = data.get("school_id")
    if not school_id:
        return JsonResponse({"error": "school_id missing"}, status=400)

    try:
        school = School.objects.get(id=school_id)
    except School.DoesNotExist:
        return JsonResponse({"error": "invalid school_id"}, status=400)

    # 性別変換
    gender_map = {"男性": 0, "女性": 1, "その他": 2}

    # 生年月日
    try:
        birthdate = datetime.datetime.strptime(data.get("birthdate", ""), "%Y-%m-%d").date()
    except Exception:
        birthdate = datetime.date(2000, 1, 1)

    form_data = {
        "user_id": data.get("user_id"),
        "user_name": data.get("user_name"),
        "user_spell": data.get("user_spell"),
        "gender": gender_map.get(data.get("gender"), 2),
        "birthdate": birthdate,
        "user_password": data.get("user_password"),  # ← フィールド名をフォームに合わせる
    }
    print("フォームデータ:", form_data)

    # クラス取得
    class_ids = data.get("class_ids", [])
    class_qs = Class.objects.filter(class_id__in=class_ids, school=school)

    form = StudentRegisterForm(form_data)

    if form.is_valid():
        student = form.save(commit=False)
        student.school = school
        student.save()
        student.classes.set(class_qs)
        form.save_m2m()
        return JsonResponse({"status": "ok", "message": "登録完了"})
    else:
        return JsonResponse({"status": "error", "errors": form.errors}, status=400)



#クラス渡すメン
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


#学生一覧
def student_list(request):
    students = StudentUser.objects.select_related('school').prefetch_related('classes').all()
    return render(request, 'core/student_list.html', {'students': students})


def godot_page(request):
    school_id = request.session.get("school_id")
    return render(request, "godot.html", {
        "school_id": school_id
    })