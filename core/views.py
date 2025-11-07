from django.shortcuts import render, redirect
from .forms import SchoolLoginForm, SchoolRegisterForm, AdministratorRegisterForm, UserLoginForm, ClassForm, TeacherRegisterForm
from .models import School, AdministratorUser, Class, TeacherUser
from django.http import HttpResponse
from django.contrib.auth import authenticate, login
from django.contrib import messages
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
import json

def home(request):
    return render(request, 'core/home.html')


def school_login(request): # 学校ログイン
    message = None
    if request.method == "POST":
        form = SchoolLoginForm(request.POST)
        if form.is_valid():
            school_id = form.cleaned_data['school_id']
            school_password = form.cleaned_data['school_password']
            try:
                school = School.objects.get(school_id=school_id, school_password=school_password)
                # ログイン成功 → セッションに保存
                request.session['school_id'] = school.id
                request.session['school_name'] = school.school_name
                return redirect('user_login')
            except School.DoesNotExist:
                message = "学校IDまたはパスワードが間違っています。"
    else:
        form = SchoolLoginForm()
    return render(request, 'core/school_login.html', {'form': form, 'message': message})


def school_logout(request): # ログアウト
    request.session.flush()  # セッション全消去
    return redirect('school_login')


def user_login(request):
    message = ""
    school_id = request.session.get('school_id')
    if not school_id:
        # 学校がログインされていなければ学校ログイン画面へリダイレクト
        return redirect('school_login')
    
    if request.method == "POST":
        form = UserLoginForm(request.POST)
        if form.is_valid():
            user_id = form.cleaned_data['user_id']
            password = form.cleaned_data['user_password']
            try:
                user = AdministratorUser.objects.get(user_id=user_id, school_id=school_id)
                if user.user_password == password:  # ハッシュ化していなければ平文比較
                    # ログイン成功処理
                    request.session['login_user_id'] = user.user_id
                    request.session['user_name'] = user.user_name
                    request.session['user_position'] = user.user_position
                    return redirect('home')
                else:
                    message = "IDまたはパスワードが間違っています"
            except AdministratorUser.DoesNotExist:
                message = "IDまたはパスワードが間違っています"
    else:
        form = UserLoginForm()
    return render(request, 'core/user_login.html', {'form': form, 'message': message})


def user_logout(request):
    request.session.pop('user_id', None)
    request.session.pop('user_name', None)
    request.session.pop('login_user_id', None)
    request.session.flush()  # セッション全消去
    return redirect('school_login')


def school_register(request):
    if request.method == 'POST':
        school_form = SchoolRegisterForm(request.POST)
        user_form = AdministratorRegisterForm(request.POST)

        if school_form.is_valid() and user_form.is_valid():
            # 学校を保存
            school = school_form.save()

            # 管理者ユーザーを保存（学校に紐づけ）
            user = user_form.save(commit=False)
            user.school = school
            user.save()

            return render(request, 'core/school_register.html', {
                'school_form': SchoolRegisterForm(),
                'user_form': AdministratorRegisterForm(),
                'register_success': True,
            })
    else:
        school_form = SchoolRegisterForm()
        user_form = AdministratorRegisterForm()

    return render(request, 'core/school_register.html', {
        'school_form': school_form,
        'user_form': user_form,
    })


def class_create(request):
    if request.session.get('user_position') != 0:
        messages.error(request, 'このページには管理者のみアクセスできます。')
        return redirect('home')

    if request.method == 'POST':
        form = ClassForm(request.POST)
        if form.is_valid():
            new_class = form.save(commit=False)
            # ログイン中ユーザーの学校IDを設定
            new_class.school_id = request.session.get('school_id')
            new_class.save()
            messages.success(request, 'クラスを登録しました。')
            return redirect('class_list')
    else:
        form = ClassForm()

    return render(request, 'core/class_create.html', {'form': form})


def class_list(request):
    # 管理者チェック
    if request.session.get('user_position') != 0:
        messages.error(request, 'このページには管理者のみアクセスできます。')
        return redirect('home')

    school_id = request.session.get('school_id')
    classes = Class.objects.filter(school_id=school_id).order_by('class_id')
    return render(request, 'core/class_list.html', {'classes': classes})


def teacher_register(request):
    if request.method == 'POST':
        school_id = request.session.get('school_id')
        form = TeacherRegisterForm(request.POST, school_id=school_id)
        if form.is_valid():
            school = School.objects.filter(id=school_id).first()
            if school is None:
                return render(request, 'core/teacher_register.html', {
                    'form': form,
                    'error': '学校情報が見つかりません（ログイン情報を確認してください）。',
                })

            teacher = form.save(commit=False)
            teacher.school = school
            teacher.save()
            form.save_m2m()
            return redirect('teacher_list')
    else:
        school_id = request.session.get('school_id')
        form = TeacherRegisterForm(school_id=school_id)

    return render(request, 'core/teacher_register.html', {'form': form})




def teacher_register_done(request):
    return render(request, 'core/teacher_done.html')


def teacher_list(request):
    school_id = school_id = request.session.get('school_id')
    teachers = TeacherUser.objects.select_related('school').prefetch_related('classes').filter(school_id=school_id)
    return render(request, 'core/teacher_list.html', {'teachers': teachers})


@csrf_exempt  # CSRFチェックを無効化（API用途）
def receive_form(request):
    if request.method == "POST":
        data = json.loads(request.body)
        print("受信データ:", data)
        return JsonResponse({"status": "ok", "received": data})
    return JsonResponse({"error": "invalid method"}, status=405)