from django.shortcuts import render, get_object_or_404, redirect
from django.http import JsonResponse
from django.contrib import messages
from ..forms import TeacherRegisterForm
from ..models import TeacherUser, School
from django.contrib.auth.hashers import make_password
from django.views.decorators.http import require_POST


#教職員登録
def teacher_register(request):
    school_id = request.session.get('school_id')
    if request.method == 'POST':
        form = TeacherRegisterForm(request.POST, school_id=school_id)
        if form.is_valid():
            school = School.objects.filter(id=school_id).first()
            if not school:
                return render(request, 'core/teacher_register.html', {
                    'form': form,
                    'error': '学校情報が見つかりません。',
                })
            teacher = form.save(commit=False)
            teacher.school = school
            teacher.user_password = make_password(form.cleaned_data['user_password'])
            teacher.save()
            form.save_m2m()
            messages.success(request, '教職員を登録しました。')
            return redirect('teacher_list')
    else:
        form = TeacherRegisterForm(school_id=school_id)
    return render(request, 'core/teacher_register.html', {'form': form})


#教職員一覧
def teacher_list(request):
    school_id = request.session.get('school_id')
    teachers = TeacherUser.objects.select_related('school').prefetch_related('classes').filter(school_id=school_id)
    return render(request, 'core/teacher_list.html', {'teachers': teachers})


#教職員編集
def teacher_edit(request, teacher_id):
    school_id = request.session.get('school_id')
    teacher = get_object_or_404(TeacherUser, id=teacher_id, school_id=school_id)

    if request.method == 'POST':
        form = TeacherRegisterForm(request.POST, instance=teacher, school_id=school_id)
        if form.is_valid():
            teacher.user_password = make_password(form.cleaned_data['user_password'])
            form.save(commit=True)
            messages.success(request, '教職員情報を更新しました。')
            return redirect('teacher_list')
    else:
        form = TeacherRegisterForm(instance=teacher, school_id=school_id)

    return render(request, 'core/teacher_edit.html', {'form': form, 'teacher': teacher})


#教職員削除
@require_POST
def teacher_delete(request, teacher_id):
    teacher = get_object_or_404(TeacherUser, id=teacher_id)
    teacher.delete()
    return JsonResponse({'success': True, 'message': f'{teacher.user_name} を削除しました。'})
