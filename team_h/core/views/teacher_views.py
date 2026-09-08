from django.shortcuts import render, get_object_or_404, redirect
from django.http import JsonResponse
from django.contrib import messages
from django.db import transaction
from django.utils.dateparse import parse_date
from ..email_otp import issue_otp, mask_email, verify_otp
from ..forms import EmailOtpForm, TeacherRegisterForm, account_email_exists
from ..models import TeacherUser, School
from django.views.decorators.http import require_POST
from ..decorators import admin_required


 #教職員登録
@admin_required
def teacher_register(request):
    school_id = request.session.get('school_id')
    if request.method == 'POST':
        action = request.POST.get("action", "start")
        pending = request.session.get("teacher_registration_pending") or {}
        if action in ("verify_otp", "resend_otp") and pending:
            email = pending.get("email", "")
            if action == "resend_otp":
                _, message = issue_otp(request, "teacher_registration", email)
                return render(request, "core/email_otp.html", {
                    "title": "教職員メール認証", "masked_email": mask_email(email),
                    "otp_form": EmailOtpForm(), "message": message, "cancel_url": "teacher_register",
                })
            otp_form = EmailOtpForm(request.POST)
            message = ""
            if otp_form.is_valid():
                ok, message = verify_otp(request, "teacher_registration", otp_form.cleaned_data["otp_code"], email)
                if ok:
                    school = School.objects.filter(id=school_id).first()
                    if school is None or account_email_exists(email) or TeacherUser.objects.filter(school=school, user_id=pending.get("user_id")).exists():
                        request.session.pop("teacher_registration_pending", None)
                        messages.error(request, "ユーザーIDまたはメールアドレスがすでに登録されています。")
                        return redirect("teacher_register")
                    class_ids = pending.pop("class_ids", [])
                    pending["birthdate"] = parse_date(pending["birthdate"])
                    with transaction.atomic():
                        teacher = TeacherUser.objects.create(school=school, **pending)
                        teacher.classes.set(class_ids)
                    request.session.pop("teacher_registration_pending", None)
                    messages.success(request, '教職員を登録しました。')
                    return redirect('teacher_list')
            return render(request, "core/email_otp.html", {
                "title": "教職員メール認証", "masked_email": mask_email(email),
                "otp_form": otp_form, "message": message, "cancel_url": "teacher_register",
            })

        form = TeacherRegisterForm(request.POST, school_id=school_id)
        if form.is_valid():
            school = School.objects.filter(id=school_id).first()
            if not school:
                return render(request, 'core/teacher_register.html', {
                    'form': form,
                    'error': '学校情報が見つかりません。',
                })
            request.session["teacher_registration_pending"] = {
                "user_id": form.cleaned_data["user_id"],
                "user_name": form.cleaned_data["user_name"],
                "user_spell": form.cleaned_data["user_spell"],
                "gender": form.cleaned_data["gender"],
                "birthdate": form.cleaned_data["birthdate"].isoformat(),
                "email": form.cleaned_data["email"],
                "user_password": form.cleaned_data["user_password"],
                "user_position": 1,
                "class_ids": [item.pk for item in form.cleaned_data["classes"]],
            }
            sent, message = issue_otp(request, "teacher_registration", form.cleaned_data["email"])
            if sent:
                return render(request, "core/email_otp.html", {
                    "title": "教職員メール認証", "masked_email": mask_email(form.cleaned_data["email"]),
                    "otp_form": EmailOtpForm(), "message": message, "cancel_url": "teacher_register",
                })
            form.add_error("email", message)
    else:
        form = TeacherRegisterForm(school_id=school_id)
    return render(request, 'core/teacher_register.html', {'form': form})


 #教職員一覧
@admin_required
def teacher_list(request):
    school_id = request.session.get('school_id')
    teachers = TeacherUser.objects.select_related('school').prefetch_related('classes').filter(school_id=school_id)
    return render(request, 'core/teacher_list.html', {'teachers': teachers})


 #教職員編集
@admin_required
def teacher_edit(request, teacher_id):
    school_id = request.session.get('school_id')
    teacher = get_object_or_404(TeacherUser, id=teacher_id, school_id=school_id)

    if request.method == 'POST':
        form = TeacherRegisterForm(request.POST, instance=teacher, school_id=school_id)
        if form.is_valid():
            form.save(commit=True)
            messages.success(request, '教職員情報を更新しました。')
            return redirect('teacher_list')
    else:
        form = TeacherRegisterForm(instance=teacher, school_id=school_id)

    return render(request, 'core/teacher_edit.html', {'form': form, 'teacher': teacher})


#教職員削除
@admin_required
@require_POST
def teacher_delete(request, teacher_id):
    teacher = get_object_or_404(TeacherUser, id=teacher_id, school_id=request.session.get("school_id"))
    teacher.delete()
    return JsonResponse({'success': True, 'message': f'{teacher.user_name} を削除しました。'})
