from django.shortcuts import render, get_object_or_404, redirect
from django.http import JsonResponse
from django.contrib import messages
from django.views.decorators.http import require_POST
from ..forms import ClassForm
from ..models import Class
from ..decorators import admin_required


#クラス取得メン
def get_school_class(school_id, class_id):
    return get_object_or_404(Class, class_id=class_id, school_id=school_id)


#クラス登録
@admin_required
def class_create(request):
    if request.method == 'POST':
        form = ClassForm(request.POST)
        if form.is_valid():
            new_class = form.save(commit=False)
            new_class.school_id = request.session.get('school_id')
            new_class.save()
            messages.success(request, 'クラスを登録しました。')
            return redirect('class_list')
    else:
        form = ClassForm()
    return render(request, 'core/class_create.html', {'form': form})


#クラス一覧
@admin_required
def class_list(request):
    school_id = request.session.get('school_id')
    classes = Class.objects.filter(school_id=school_id).order_by('class_id')
    return render(request, 'core/class_list.html', {'classes': classes})


#クラス編集
@admin_required
def class_edit(request, class_id):
    school_id = request.session.get('school_id')
    c = get_school_class(school_id, class_id)
    if request.method == 'POST':
        form = ClassForm(request.POST, instance=c)
        if form.is_valid():
            form.save()
            messages.success(request, 'クラス情報を更新しました。')
            return redirect('class_list')
    else:
        form = ClassForm(instance=c)
    return render(request, 'core/class_edit.html', {'form': form, 'class_obj': c})


#クラス削除
@admin_required
@require_POST
def class_delete(request, class_id):
    school_id = request.session.get('school_id')
    c = get_school_class(school_id, class_id)
    c.delete()
    return JsonResponse({'success': True, 'message': f'{c.class_name} を削除しました。'})
