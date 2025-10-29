from django.shortcuts import render, redirect
from .forms import SchoolLoginForm, SchoolRegisterForm, UserRegisterForm, UserLoginForm
from .models import School
from .models import School, User
from django.http import HttpResponse
from django.contrib.auth import authenticate, login

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
                user = User.objects.get(user_id=user_id, school_id=school_id)
                if user.user_password == password:  # ハッシュ化していなければ平文比較
                    # ログイン成功処理
                    request.session['login_user_id'] = user.user_id
                    request.session['user_name'] = user.user_name  # Userモデルにuser_nameがある場合
                    return redirect('home')
                else:
                    message = "IDまたはパスワードが間違っています"
            except User.DoesNotExist:
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
        user_form = UserRegisterForm(request.POST)

        if school_form.is_valid() and user_form.is_valid():
            # 学校を保存
            school = school_form.save()

            # 管理者ユーザーを保存（学校に紐づけ）
            user = user_form.save(commit=False)
            user.school = school
            user.save()

            return redirect('school_register_done')  # 登録完了ページなどへ
    else:
        school_form = SchoolRegisterForm()
        user_form = UserRegisterForm()

    return render(request, 'core/school_register.html', {
        'school_form': school_form,
        'user_form': user_form,
    })

def school_register_done(request): # 学校新規登録完了
    return render(request, 'core/school_register_done.html')
