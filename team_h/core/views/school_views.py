from django.shortcuts import render, redirect
from django.contrib import messages
from django.contrib.auth.hashers import check_password, make_password
from django.db import transaction
from ..email_otp import issue_otp, mask_email, verify_otp
from ..forms import EmailOtpForm, SchoolLoginForm, SchoolRegisterForm, AdministratorRegisterForm, account_email_exists
from ..models import AdministratorUser, School


def landing(request):
    """公開用のシステム紹介ページ。学校管理者向け画面とは分離する。"""
    return render(request, "core/landing.html")


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
        action = request.POST.get("action", "start")
        pending = request.session.get("school_registration_pending") or {}
        if action in ("verify_otp", "resend_otp") and pending:
            email = pending.get("administrator", {}).get("email", "")
            if action == "resend_otp":
                _, message = issue_otp(request, "school_registration", email)
                return render(request, "core/email_otp.html", {
                    "title": "管理者メール認証", "masked_email": mask_email(email),
                    "otp_form": EmailOtpForm(), "message": message,
                    "cancel_url": "school_register",
                })
            otp_form = EmailOtpForm(request.POST)
            message = ""
            if otp_form.is_valid():
                ok, message = verify_otp(request, "school_registration", otp_form.cleaned_data["otp_code"], email)
                if ok:
                    school_data = pending["school"]
                    admin_data = pending["administrator"]
                    if School.objects.filter(school_id=school_data["school_id"]).exists() or account_email_exists(email):
                        request.session.pop("school_registration_pending", None)
                        messages.error(request, "学校IDまたはメールアドレスがすでに登録されています。")
                        return redirect("school_register")
                    with transaction.atomic():
                        school = School.objects.create(**school_data)
                        AdministratorUser.objects.create(school=school, **admin_data)
                    request.session.pop("school_registration_pending", None)
                    messages.success(request, '学校登録が完了しました。')
                    return redirect('school_login')
            return render(request, "core/email_otp.html", {
                "title": "管理者メール認証", "masked_email": mask_email(email),
                "otp_form": otp_form, "message": message, "cancel_url": "school_register",
            })

        school_form = SchoolRegisterForm(request.POST)
        user_form = AdministratorRegisterForm(request.POST)

        if school_form.is_valid() and user_form.is_valid():
            request.session["school_registration_pending"] = {
                "school": {
                    "school_id": school_form.cleaned_data["school_id"],
                    "school_name": school_form.cleaned_data["school_name"],
                    "school_password": make_password(school_form.cleaned_data["school_password"]),
                },
                "administrator": {
                    "user_id": user_form.cleaned_data["user_id"],
                    "email": user_form.cleaned_data["email"],
                    "user_password": user_form.cleaned_data["user_password"],
                    "user_position": 0,
                },
            }
            sent, message = issue_otp(request, "school_registration", user_form.cleaned_data["email"])
            if sent:
                return render(request, "core/email_otp.html", {
                    "title": "管理者メール認証", "masked_email": mask_email(user_form.cleaned_data["email"]),
                    "otp_form": EmailOtpForm(), "message": message, "cancel_url": "school_register",
                })
            user_form.add_error("email", message)
    else:
        school_form = SchoolRegisterForm()
        user_form = AdministratorRegisterForm()

    return render(request, 'core/school_register.html', {
        'school_form': school_form,
        'user_form': user_form,
    })
