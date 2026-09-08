"""学校データのバックアップ・復元処理。

ファイルは Django のストレージに保存し、復元時には学校IDとSHA-256を必ず照合する。
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from datetime import datetime, timezone

from django.core import serializers
from django.core.files.base import ContentFile
from django.db import transaction
from django.utils import timezone as django_timezone

from .models import (
    BackupArchive,
    ChatHiddenState,
    ChatMessage,
    ChatReadState,
    Class,
    GrowthPointEvent,
    LessonComment,
    LessonRecording,
    LessonStream,
    School,
    StudentUser,
    TeacherUser,
    UserMemo,
    UserProfile,
)

BACKUP_VERSION = 1
BACKUP_MODELS = (
    Class,
    TeacherUser,
    StudentUser,
    UserProfile,
    ChatMessage,
    ChatReadState,
    ChatHiddenState,
    UserMemo,
    LessonStream,
    LessonComment,
    LessonRecording,
    GrowthPointEvent,
)


class BackupValidationError(ValueError):
    """安全に復元できないアーカイブであることを示す例外。"""


@dataclass(frozen=True)
class RestoreResult:
    restored_records: int


def _serialized_records(school: School) -> list[dict]:
    records: list[dict] = []
    for model in BACKUP_MODELS:
        records.extend(json.loads(serializers.serialize("json", model.objects.filter(school=school))))
    return records


def create_backup(*, school: School, created_by_user_id: int) -> BackupArchive:
    records = _serialized_records(school)
    payload = {
        "format": "school-metaverse-backup",
        "version": BACKUP_VERSION,
        "school_pk": school.pk,
        "school_code": school.school_id,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "records": records,
    }
    raw = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    checksum = hashlib.sha256(raw).hexdigest()
    timestamp = django_timezone.localtime().strftime("%Y%m%d_%H%M%S")
    archive = BackupArchive(
        school=school,
        created_by_user_id=created_by_user_id,
        checksum=checksum,
        record_count=len(records),
    )
    archive.file.save(f"school_{school.pk}_{timestamp}.json", ContentFile(raw), save=False)
    archive.save()
    return archive


def _read_and_validate(archive: BackupArchive, school: School) -> list[dict]:
    with archive.file.open("rb") as backup_file:
        raw = backup_file.read()
    if hashlib.sha256(raw).hexdigest() != archive.checksum:
        raise BackupValidationError("バックアップファイルの整合性を確認できません。")
    try:
        payload = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise BackupValidationError("バックアップファイルの形式が正しくありません。") from exc
    if (
        payload.get("format") != "school-metaverse-backup"
        or payload.get("version") != BACKUP_VERSION
        or payload.get("school_pk") != school.pk
        or payload.get("school_code") != school.school_id
        or not isinstance(payload.get("records"), list)
    ):
        raise BackupValidationError("この学校には復元できないバックアップです。")
    allowed_models = {model._meta.label_lower for model in BACKUP_MODELS}
    if any(record.get("model") not in allowed_models for record in payload["records"]):
        raise BackupValidationError("許可されていないデータが含まれています。")
    return payload["records"]


def restore_backup(*, archive: BackupArchive, school: School) -> RestoreResult:
    """対象校の業務データをアーカイブ時点の状態へ安全に置換する。"""
    records = _read_and_validate(archive, school)
    with transaction.atomic():
        # すべて school に直接紐づくため、関連順序を意識せず安全に削除できる。
        for model in reversed(BACKUP_MODELS):
            model.objects.filter(school=school).delete()
        for deserialized in serializers.deserialize("json", json.dumps(records)):
            deserialized.save()
    return RestoreResult(restored_records=len(records))
