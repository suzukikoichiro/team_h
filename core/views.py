from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages
from django.http import JsonResponse
from django.views.decorators.http import require_POST
from django.views.decorators.csrf import csrf_exempt
from functools import wraps
import json

from django.contrib.auth.hashers import make_password, check_password

from .forms import (
    SchoolLoginForm, SchoolRegisterForm, AdministratorRegisterForm,
    UserLoginForm, ClassForm, TeacherRegisterForm
)
from .models import School, AdministratorUser, TeacherUser, Class



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
                return redirect('home') if user.user_position == 0 else redirect('test')
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
    return JsonResponse({'success': True, 'message': f'{teacher.name} を削除しました。'})


# API 用
@csrf_exempt
def receive_form(request):
    if request.method == "POST":
        try:
            data = json.loads(request.body)
            return JsonResponse({"status": "ok", "received": data})
        except json.JSONDecodeError:
            return JsonResponse({"error": "JSON decode error"}, status=400)
    return JsonResponse({"error": "invalid method"}, status=405)
