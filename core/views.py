from django.shortcuts import render, redirect
from .forms import SchoolLoginForm, SchoolRegisterForm, UserRegisterForm, UserLoginForm
from .models import School
from .models import School, User
from django.http import HttpResponse

def home(request):
    if 'school_id' in request.session:
        return render(request, 'core/home.html')
    else:
        return redirect('school_login')


def school_login(request): # ログイン
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
                return redirect('home')
            except School.DoesNotExist:
                message = "学校IDまたはパスワードが間違っています。"
    else:
        form = SchoolLoginForm()
    return render(request, 'core/school_login.html', {'form': form, 'message': message})


def school_logout(request): # ログアウト
    request.session.flush()  # セッション全消去
    return redirect('school_login')



def user_login(request):
    # 学校ログイン必須
    if 'school_id' not in request.session:
        return redirect('school_login')

    message = None
    school_id = request.session['school_id']
    school_name = request.session['school_name']

    if request.method == "POST":
        form = UserLoginForm(request.POST)
        if form.is_valid():
            user_id = form.cleaned_data['user_id']
            user_password = form.cleaned_data['user_password']

            try:
                # 学校ID + ユーザーID + パスワードで検索
                user = User.objects.get(
                    school_id=school_id,
                    user_id=user_id,
                    user_password=user_password
                )
                # 成功時：セッションに保存
                request.session['user_id'] = user.id
                request.session['user_name'] = user.user_name
                request.session['login_user_id'] = user.user_id
                return redirect('home')
            except User.DoesNotExist:
                message = "ユーザーID または パスワードが間違っています。"
    else:
        form = UserLoginForm()

    return render(request, 'core/user_login.html', {
        'form': form,
        'message': message,
        'school_name': school_name,
    })


def user_logout(request):
    request.session.pop('user_id', None)
    request.session.pop('user_name', None)
    request.session.pop('login_user_id', None)
    request.session.flush()  # セッション全消去
    return redirect('school_login')

def school_register(request): # 学校新規登録
    if request.method == "POST":
        form = SchoolRegisterForm(request.POST)
        if form.is_valid():
            form.save()
            return redirect('school_register_done')
    else:
        form = SchoolRegisterForm()
    return render(request, 'core/school_register.html', {'form': form})


def user_register(request): # ユーザー新規登録
    if request.method == "POST":
        form = UserRegisterForm(request.POST)
        if form.is_valid():
            form.save()
            return redirect('user_register_done')
    else:
        form = UserRegisterForm()
    return render(request, 'core/user_register.html', {'form': form})


def school_register_done(request): # 学校新規登録完了
    return render(request, 'core/school_register_done.html')


def user_register_done(request): # ユーザー新規登録完了
    return render(request, 'core/user_register_done.html')
