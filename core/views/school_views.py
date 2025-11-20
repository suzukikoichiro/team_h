from django.shortcuts import render, redirect
from django.contrib import messages
from django.contrib.auth.hashers import check_password, make_password
from ..forms import SchoolLoginForm, SchoolRegisterForm, AdministratorRegisterForm
from ..models import School


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
