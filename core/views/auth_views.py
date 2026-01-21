from django.contrib import messages
from django.contrib.auth.hashers import check_password
from ..forms import UserLoginForm
from ..models import AdministratorUser, TeacherUser, StudentUser
from django.shortcuts import render, get_object_or_404, redirect

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
                request.session['school_id'] = school_id

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


def godot(request):
    if not request.session.get("login_user_id"):
        return redirect("user_login")
    return render(request, 'godot/godot.html')


#教職員はログイン後こちらに遷移
#学生登録
def student_create(request):
    if request.method == "POST":
        # 仮：保存処理（あとでformに置き換えOK）
        # Student.objects.create(...)
        return redirect("student_create")

    return render(request, "godot/godot.html", {
        "mode": "create",
    })

#学生更新
def student_edit(request, student_id):
    student = get_object_or_404(StudentUser, id=student_id)

    if request.method == "POST":
        # 仮：更新処理
        # student.name = request.POST["name"]
        # student.save()
        return redirect("student_edit", student_id=student.id)

    return render(request, "godot/godot.html", {
        "mode": "edit",
        "student": student,
    })

#学生削除
def student_delete(request, student_id):
    student = get_object_or_404(StudentUser, id=student_id)

    if request.method == "POST":
        student.delete()
        return redirect("student_create")

    return render(request, "godot/godot.html", {
        "mode": "delete",
        "student": student,
    })

#学生はログイン後こちらに遷移
def test(request):
    return render(request, 'godot/godot.html', {"student_id": 4})