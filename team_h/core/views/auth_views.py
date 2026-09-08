from django.contrib import messages
from django.contrib.auth.hashers import check_password
from django.db import transaction
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
from django.http import JsonResponse
from django.utils import timezone
from ..forms import EmailChangeForm, EmailOtpForm, UserLoginForm, account_email_exists
from ..decorators import admin_required
from ..models import AdministratorUser, TeacherUser, StudentUser, School, UserProfile
from ..email_otp import clear_otp, issue_otp, mask_email, normalize_email, verify_otp
from ..growth_points import award_growth_points
from django.shortcuts import render, get_object_or_404, redirect
import json

#認証
def authenticate_user(user_id, password, school_id):
    for model in [AdministratorUser, TeacherUser, StudentUser]:
        try:
            user = model.objects.get(user_id=user_id, school_id=school_id)
            if _password_matches(password, user.user_password):
                return user
        except model.DoesNotExist:
            continue
    return None


def _password_matches(raw_password, stored_password):
    return check_password(raw_password, stored_password)


def _authenticate_school_user(school, user_id, password):
    for model, role in [(TeacherUser, "teacher"), (StudentUser, "student")]:
        try:
            user = model.objects.get(user_id=user_id, school=school)
            if _password_matches(password, user.user_password):
                return user, role
        except model.DoesNotExist:
            continue
    return None, ""


def _default_avatar_for_gender(gender):
    try:
        return "skin_02" if int(gender) == 1 else "skin_01"
    except (TypeError, ValueError):
        return "skin_01"


def _set_authenticated_session(request, school, user):
    request.session["school_id"] = school.id
    request.session["school_code"] = school.school_id
    request.session["login_user_id"] = user.user_id
    request.session["user_position"] = user.user_position
    if hasattr(user, "gender"):
        request.session["gender"] = user.gender


def _api_login_data(school, user, role):
    profile = UserProfile.objects.filter(school=school, user_id=user.user_id).first()
    avatar_key = profile.avatar_key if profile and profile.avatar_key and profile.avatar_key != "default" else _default_avatar_for_gender(user.gender)
    if role == "student":
        award_growth_points(school, user.user_id, "login", f"login:{timezone.localdate().isoformat()}")
    return {
        "logged_in": True,
        "school_id": int(school.school_id) if school.school_id.isdigit() else school.school_id,
        "school_pk": school.id,
        "user_id": user.user_id,
        "user_position": user.user_position,
        "username": user.user_name,
        "role": role,
        "gender": user.gender,
        "avatar_key": avatar_key,
    }


def _pending_user(request, key):
    pending = request.session.get(key) or {}
    model = {"administrator": AdministratorUser, "teacher": TeacherUser}.get(pending.get("model"))
    if model is None:
        return None
    return model.objects.filter(pk=pending.get("pk"), school_id=pending.get("school_pk")).first()


@csrf_exempt
@require_POST
def api_login(request):
    try:
        data = json.loads(request.body.decode("utf-8"))
    except json.JSONDecodeError:
        return JsonResponse({"error": "invalid_json"}, status=400)

    school_code = str(data.get("school_id", "")).strip()
    user_id = str(data.get("user_id", "")).strip()
    password = str(data.get("password", ""))

    if not school_code or not user_id or not password:
        return JsonResponse({"error": "missing_credentials"}, status=400)

    try:
        school = School.objects.get(school_id=school_code)
    except School.DoesNotExist:
        return JsonResponse({"error": "invalid_credentials"}, status=401)

    try:
        user_id_int = int(user_id)
    except ValueError:
        return JsonResponse({"error": "invalid_credentials"}, status=401)

    user, role = _authenticate_school_user(school, user_id_int, password)
    if user is None:
        return JsonResponse({"error": "invalid_credentials"}, status=401)

    if role == "teacher":
        request.session["api_login_pending"] = {
            "model": "teacher", "pk": user.pk, "school_pk": school.pk, "role": role,
        }
        if not user.email:
            return JsonResponse({
                "email_registration_required": True,
                "message": "初回ログインのため、認証に使用するメールアドレスを登録してください。",
            }, status=428)
        sent, message = issue_otp(request, "api_login", user.email)
        if not sent:
            return JsonResponse({"error": "otp_send_failed", "message": message}, status=429)
        return JsonResponse({
            "otp_required": True,
            "masked_email": mask_email(user.email),
            "message": message,
        }, status=202)

    _set_authenticated_session(request, school, user)
    return JsonResponse(_api_login_data(school, user, role))


@csrf_exempt
@require_POST
def api_login_otp(request):
    try:
        data = json.loads(request.body.decode("utf-8"))
    except json.JSONDecodeError:
        return JsonResponse({"error": "invalid_json"}, status=400)
    user = _pending_user(request, "api_login_pending")
    if user is None:
        return JsonResponse({"error": "otp_challenge_not_found"}, status=400)
    action = data.get("action", "verify")
    if action == "register_email":
        form = EmailChangeForm({"email": data.get("email", "")}, current_user=user)
        if not form.is_valid():
            return JsonResponse({"error": "invalid_email", "message": "メールアドレスを確認してください。"}, status=400)
        pending_email = form.cleaned_data["email"]
        sent, message = issue_otp(request, "api_login_enrollment", pending_email)
        if not sent:
            return JsonResponse({"error": "otp_send_failed", "message": message}, status=429)
        request.session["api_login_enrollment_email"] = pending_email
        return JsonResponse({
            "otp_required": True, "email_enrollment": True,
            "masked_email": mask_email(pending_email), "message": message,
        }, status=202)
    if action in ("verify_enrollment", "resend_enrollment"):
        pending_email = request.session.get("api_login_enrollment_email", "")
        if not pending_email:
            return JsonResponse({"error": "otp_challenge_not_found"}, status=400)
        if action == "resend_enrollment":
            sent, message = issue_otp(request, "api_login_enrollment", pending_email)
            return JsonResponse({"otp_required": True, "email_enrollment": True, "message": message}, status=200 if sent else 429)
        ok, message = verify_otp(request, "api_login_enrollment", str(data.get("otp_code", "")), pending_email)
        if not ok:
            return JsonResponse({"error": "invalid_otp", "message": message}, status=400)
        if account_email_exists(pending_email, exclude_user=user):
            return JsonResponse({"error": "email_in_use", "message": "このメールアドレスはすでに登録されています。"}, status=409)
        user.email = normalize_email(pending_email)
        user.save(update_fields=["email"])
        request.session.pop("api_login_enrollment_email", None)
    elif data.get("resend"):
        sent, message = issue_otp(request, "api_login", user.email)
        return JsonResponse({"otp_required": True, "message": message}, status=200 if sent else 429)
    else:
        ok, message = verify_otp(request, "api_login", str(data.get("otp_code", "")), user.email)
        if not ok:
            return JsonResponse({"error": "invalid_otp", "message": message}, status=400)
    school = user.school
    request.session.pop("api_login_pending", None)
    _set_authenticated_session(request, school, user)
    return JsonResponse(_api_login_data(school, user, "teacher"))


#ユーザーログイン
def user_login(request):
    school_id = request.session.get('school_id')
    if not school_id:
        return redirect('school_login')

    message = ""
    otp_pending = _pending_user(request, "web_login_pending")
    if request.method == "POST":
        action = request.POST.get("action", "login")
        if action in ("enroll_email", "verify_enrollment", "resend_enrollment"):
            if otp_pending is None:
                return redirect("user_login")
            if action == "enroll_email":
                enrollment_form = EmailChangeForm(request.POST, current_user=otp_pending)
                if enrollment_form.is_valid():
                    pending_email = enrollment_form.cleaned_data["email"]
                    sent, message = issue_otp(request, "web_login_enrollment", pending_email)
                    if sent:
                        request.session["web_login_enrollment_email"] = pending_email
                        return render(request, "core/user_login.html", {
                            "otp_form": EmailOtpForm(), "otp_pending": True,
                            "otp_action": "verify_enrollment", "resend_action": "resend_enrollment",
                            "masked_email": mask_email(pending_email), "message": message,
                        })
                return render(request, "core/user_login.html", {
                    "email_enrollment": True, "enrollment_form": enrollment_form, "message": message,
                })
            pending_email = request.session.get("web_login_enrollment_email", "")
            if not pending_email:
                return redirect("user_login")
            if action == "resend_enrollment":
                _, message = issue_otp(request, "web_login_enrollment", pending_email)
                return render(request, "core/user_login.html", {
                    "otp_form": EmailOtpForm(), "otp_pending": True,
                    "otp_action": "verify_enrollment", "resend_action": "resend_enrollment",
                    "masked_email": mask_email(pending_email), "message": message,
                })
            otp_form = EmailOtpForm(request.POST)
            if otp_form.is_valid():
                ok, message = verify_otp(request, "web_login_enrollment", otp_form.cleaned_data["otp_code"], pending_email)
                if ok and not account_email_exists(pending_email, exclude_user=otp_pending):
                    otp_pending.email = normalize_email(pending_email)
                    otp_pending.save(update_fields=["email"])
                    request.session.pop("web_login_enrollment_email", None)
                    request.session.pop("web_login_pending", None)
                    _set_authenticated_session(request, otp_pending.school, otp_pending)
                    return redirect("home" if otp_pending.user_position == 0 else "godot")
            return render(request, "core/user_login.html", {
                "otp_form": otp_form, "otp_pending": True,
                "otp_action": "verify_enrollment", "resend_action": "resend_enrollment",
                "masked_email": mask_email(pending_email), "message": message,
            })
        if action in ("verify_otp", "resend_otp"):
            if otp_pending is None:
                clear_otp(request, "web_login")
                return redirect("user_login")
            if action == "resend_otp":
                sent, message = issue_otp(request, "web_login", otp_pending.email)
                return render(request, "core/user_login.html", {
                    "otp_form": EmailOtpForm(), "otp_pending": True,
                    "masked_email": mask_email(otp_pending.email), "message": message,
                })
            otp_form = EmailOtpForm(request.POST)
            if otp_form.is_valid():
                ok, message = verify_otp(request, "web_login", otp_form.cleaned_data["otp_code"], otp_pending.email)
                if ok:
                    request.session.pop("web_login_pending", None)
                    _set_authenticated_session(request, otp_pending.school, otp_pending)
                    return redirect("home" if otp_pending.user_position == 0 else "godot")
            return render(request, "core/user_login.html", {
                "otp_form": otp_form, "otp_pending": True,
                "masked_email": mask_email(otp_pending.email), "message": message,
            })

        form = UserLoginForm(request.POST)
        if form.is_valid():
            user_id = form.cleaned_data['user_id']
            password = form.cleaned_data['user_password']

            user = authenticate_user(user_id, password, school_id)
            if user:
                if user.user_position in (0, 1):
                    if not user.email:
                        request.session["web_login_pending"] = {
                            "model": "administrator" if user.user_position == 0 else "teacher",
                            "pk": user.pk, "school_pk": user.school_id,
                        }
                        return render(request, "core/user_login.html", {
                            "email_enrollment": True,
                            "enrollment_form": EmailChangeForm(current_user=user),
                            "message": "初回ログインのため、認証に使用するメールアドレスを登録してください。",
                        })
                    else:
                        request.session["web_login_pending"] = {
                            "model": "administrator" if user.user_position == 0 else "teacher",
                            "pk": user.pk, "school_pk": user.school_id,
                        }
                        sent, message = issue_otp(request, "web_login", user.email)
                        if sent:
                            return render(request, "core/user_login.html", {
                                "otp_form": EmailOtpForm(), "otp_pending": True,
                                "masked_email": mask_email(user.email), "message": message,
                            })
                else:
                    _set_authenticated_session(request, user.school, user)
                    return redirect('test')
            else:
                message = "IDまたはパスワードが間違っています"
    else:
        form = UserLoginForm()

    return render(request, 'core/user_login.html', {'form': form, 'message': message})


def _current_privileged_user(request):
    model = {0: AdministratorUser, 1: TeacherUser}.get(request.session.get("user_position"))
    if model is None:
        return None
    return model.objects.filter(
        school_id=request.session.get("school_id"), user_id=request.session.get("login_user_id")
    ).first()


def account_email(request):
    user = _current_privileged_user(request)
    if user is None:
        return redirect("user_login")
    message = ""
    pending_email = request.session.get("web_email_change_pending", "")
    if request.method == "POST":
        action = request.POST.get("action", "request_change")
        if action in ("verify_otp", "resend_otp") and pending_email:
            if action == "resend_otp":
                _, message = issue_otp(request, "web_email_change", pending_email)
            else:
                otp_form = EmailOtpForm(request.POST)
                if otp_form.is_valid():
                    ok, message = verify_otp(request, "web_email_change", otp_form.cleaned_data["otp_code"], pending_email)
                    if ok:
                        if account_email_exists(pending_email, exclude_user=user):
                            message = "このメールアドレスはすでに別のアカウントに登録されています。"
                        else:
                            user.email = normalize_email(pending_email)
                            user.save(update_fields=["email"])
                            request.session.pop("web_email_change_pending", None)
                            messages.success(request, "メールアドレスを変更しました。")
                            return redirect("account_email")
                return render(request, "core/account_email.html", {
                    "current_email": user.email, "pending_email": mask_email(pending_email),
                    "otp_form": otp_form, "message": message,
                })
            return render(request, "core/account_email.html", {
                "current_email": user.email, "pending_email": mask_email(pending_email),
                "otp_form": EmailOtpForm(), "message": message,
            })
        form = EmailChangeForm(request.POST, current_user=user)
        if form.is_valid():
            pending_email = form.cleaned_data["email"]
            sent, message = issue_otp(request, "web_email_change", pending_email)
            if sent:
                request.session["web_email_change_pending"] = pending_email
                return render(request, "core/account_email.html", {
                    "current_email": user.email, "pending_email": mask_email(pending_email),
                    "otp_form": EmailOtpForm(), "message": message,
                })
    else:
        form = EmailChangeForm(current_user=user)
    return render(request, "core/account_email.html", {"current_email": user.email, "form": form, "message": message})


@csrf_exempt
def api_account_email(request):
    user = _current_privileged_user(request)
    if user is None:
        return JsonResponse({"error": "not_authenticated"}, status=401)
    if request.method == "GET":
        return JsonResponse({"email": user.email or "", "masked_email": mask_email(user.email)})
    if request.method != "POST":
        return JsonResponse({"error": "method_not_allowed"}, status=405)
    try:
        data = json.loads(request.body.decode("utf-8"))
    except json.JSONDecodeError:
        return JsonResponse({"error": "invalid_json"}, status=400)
    action = data.get("action", "request")
    pending_email = request.session.get("api_email_change_pending", "")
    if action == "request":
        form = EmailChangeForm({"email": data.get("email", "")}, current_user=user)
        if not form.is_valid():
            return JsonResponse({"error": "invalid_email", "errors": form.errors.get_json_data()}, status=400)
        pending_email = form.cleaned_data["email"]
        sent, message = issue_otp(request, "api_email_change", pending_email)
        if not sent:
            return JsonResponse({"error": "rate_limited", "message": message}, status=429)
        request.session["api_email_change_pending"] = pending_email
        return JsonResponse({"otp_required": True, "masked_email": mask_email(pending_email), "message": message})
    if not pending_email:
        return JsonResponse({"error": "otp_challenge_not_found"}, status=400)
    if action == "resend":
        sent, message = issue_otp(request, "api_email_change", pending_email)
        return JsonResponse({"otp_required": True, "message": message}, status=200 if sent else 429)
    if action != "verify":
        return JsonResponse({"error": "invalid_action"}, status=400)
    ok, message = verify_otp(request, "api_email_change", str(data.get("otp_code", "")), pending_email)
    if not ok:
        return JsonResponse({"error": "invalid_otp", "message": message}, status=400)
    with transaction.atomic():
        if account_email_exists(pending_email, exclude_user=user):
            return JsonResponse({"error": "email_in_use", "message": "このメールアドレスはすでに登録されています。"}, status=409)
        user.email = normalize_email(pending_email)
        user.save(update_fields=["email"])
    request.session.pop("api_email_change_pending", None)
    return JsonResponse({"email": user.email, "masked_email": mask_email(user.email), "message": "メールアドレスを変更しました。"})


#ユーザーログアウト
def user_logout(request):
    request.session.flush()
    return redirect('school_login')


#管理者はログイン後こちらに遷移
@admin_required
def home(request):
    return render(request, 'core/home.html')

#教職員はログイン後こちらに遷移
def godot(request):
    if not request.session.get("login_user_id"):
        return redirect("user_login")
    return render(request, 'godot/2Dmetaverse.html')


#学生登録
def student_create(request):
    if request.method == "POST":
        # 仮：保存処理（あとでformに置き換えOK）
        # Student.objects.create(...)
        return redirect("student_create")

    return render(request, "godot/2Dmetaverse.html", {
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

    return render(request, "godot/2Dmetaverse.html", {
        "mode": "edit",
        "student": student,
    })

#学生削除
def student_delete(request, student_id):
    student = get_object_or_404(StudentUser, id=student_id)

    if request.method == "POST":
        student.delete()
        return redirect("student_create")

    return render(request, "godot/2Dmetaverse.html", {
        "mode": "delete",
        "student": student,
    })

#学生はログイン後こちらに遷移
def test(request):
    return render(request, 'godot/2Dmetaverse.html', {"student_id": 4})
