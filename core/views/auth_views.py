from django.shortcuts import render, redirect
from django.contrib import messages
from django.contrib.auth.hashers import check_password
from ..forms import UserLoginForm
from ..models import AdministratorUser, TeacherUser, StudentUser

#認証
def authenticate_user(user_id, password, school_id):
    for model in [AdministratorUser, TeacherUser, StudentUser]:
        try:
            user = model.objects.get(user_id=user_id, school_id=school_id)
            if check_password(password, user.user_password):
                return user
        except model.DoesNotExist:
            continue
    return None


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

                if user.user_position == 0:
                    return redirect('home')
                elif user.user_position == 1:
                    return redirect('godot')
                elif user.user_position == 2:
                    return redirect('test')
            else:
                message = "IDまたはパスワードが間違っています"
    else:
        form = UserLoginForm()

    return render(request, 'core/user_login.html', {'form': form, 'message': message})


#ユーザーログアウト
def user_logout(request):
    request.session.flush()
    return redirect('school_login')


#管理者はログイン後こちらに遷移
def home(request):
    return render(request, 'core/home.html')


#管理者以外はログイン後こちらに遷移
def test(request):
    return render(request, 'core/test.html')


#管理者以外は仮godot君へ
def godot(request):
    return render(request, 'godot/godot.html')
