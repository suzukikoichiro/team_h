from django.contrib import messages
from django.http import FileResponse, HttpResponseNotFound
from django.shortcuts import get_object_or_404, redirect, render
from django.views.decorators.http import require_POST

from ..backup_service import BackupValidationError, create_backup, restore_backup
from ..decorators import admin_required
from ..models import BackupArchive, School


def _current_school(request):
    school_id = request.session.get("school_id")
    return get_object_or_404(School, id=school_id)


@admin_required
def backup_list(request):
    school = _current_school(request)
    archives = BackupArchive.objects.filter(school=school).order_by("-created_at")
    return render(request, "core/backup_list.html", {"archives": archives})


@admin_required
@require_POST
def backup_create(request):
    school = _current_school(request)
    archive = create_backup(
        school=school,
        created_by_user_id=request.session["login_user_id"],
    )
    messages.success(request, f"バックアップを作成しました（{archive.record_count}件）。")
    return redirect("backup_list")


@admin_required
def backup_download(request, archive_id):
    school = _current_school(request)
    archive = BackupArchive.objects.filter(id=archive_id, school=school).first()
    if archive is None:
        return HttpResponseNotFound("バックアップが見つかりません。")
    archive.file.open("rb")
    return FileResponse(archive.file, as_attachment=True, filename=archive.file.name.rsplit("/", 1)[-1])


@admin_required
@require_POST
def backup_restore(request, archive_id):
    school = _current_school(request)
    archive = BackupArchive.objects.filter(id=archive_id, school=school).first()
    if archive is None:
        return HttpResponseNotFound("バックアップが見つかりません。")
    if request.POST.get("confirmation") != "復元する":
        messages.error(request, "確認文言が一致しないため、復元は実行されませんでした。")
        return redirect("backup_list")
    try:
        # 復元は現在の状態を置き換えるため、直前の状態を必ず退避する。
        safety_archive = create_backup(
            school=school,
            created_by_user_id=request.session["login_user_id"],
        )
        result = restore_backup(archive=archive, school=school)
    except BackupValidationError as exc:
        messages.error(request, str(exc))
    else:
        messages.success(
            request,
            f"バックアップを復元しました（{result.restored_records}件）。復元前の状態も保存済みです（ID: {safety_archive.id}）。",
        )
    return redirect("backup_list")
