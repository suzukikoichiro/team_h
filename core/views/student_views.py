from django.shortcuts import render, get_object_or_404, redirect
from django.contrib import messages
from django.contrib.auth.hashers import make_password
from ..forms import StudentRegisterForm
from ..models import StudentUser, School
from ..decorators import admin_required,teacher_required
from django.views.decorators.http import require_POST
from django.http import JsonResponse


#管理者による学生登録
@admin_required
def student_register(request):
    school_id = request.session.get('school_id')
    if not school_id:
        return redirect('school_login')

    if request.method == 'POST':
        form = StudentRegisterForm(request.POST, school_id=school_id)
        if form.is_valid():
            student = form.save(commit=False)
            student.school_id = school_id
            student.user_password = make_password(form.cleaned_data['user_password'])
            student.user_position = 2  # 学生
            student.save()
            form.save_m2m()
            messages.success(request, '学生を登録しました。')
            return redirect('student_list')
    else:
        form = StudentRegisterForm(school_id=school_id)

    return render(request, 'core/student_register.html', {'form': form})


#管理者による学生編集
@admin_required
def student_edit(request, student_id):
    school_id = request.session.get('school_id')
    student = get_object_or_404(StudentUser, id=student_id, school_id=school_id)

    if request.method == 'POST':
        form = StudentRegisterForm(request.POST, instance=student, school_id=school_id)
        if form.is_valid():
            student.user_password = make_password(form.cleaned_data['user_password'])
            form.save(commit=True)
            messages.success(request, '学生情報を更新しました。')
            return redirect('student_list')
    else:
        form = StudentRegisterForm(instance=student, school_id=school_id)

    return render(request, 'core/student_edit.html', {'form': form, 'student': student})


#管理者による学生一覧
def student_list(request):
    school_id = request.session.get('school_id')
    if not school_id:
        return redirect('school_login')

    students = StudentUser.objects.select_related('school').prefetch_related('classes').filter(school_id=school_id)
    return render(request, 'core/student_list.html', {'students': students})


#管理者による学生削除
@admin_required
@require_POST
def student_delete_by_admin(request, student_id):
    student = get_object_or_404(StudentUser, id=student_id)
    student.delete()
    return JsonResponse({'success': True, 'message': f'{student.user_name} を削除しました。'})


#教職員による学生削除
@teacher_required
@require_POST
def student_delete_by_teacher(request, student_id):
    student = get_object_or_404(StudentUser, id=student_id)
    student.delete()
    return JsonResponse({'success': True, 'message': '学生を削除しました'})
