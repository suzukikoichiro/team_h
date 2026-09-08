import hashlib
import json
import re
from unittest.mock import patch
from datetime import date

from django.contrib.auth.hashers import check_password, make_password
from django.core import mail
from django.core.files.base import ContentFile
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import Client, TestCase, override_settings
from django.urls import reverse

from .backup_service import BackupValidationError, create_backup, restore_backup
from .models import (
    AdministratorUser,
    BackupArchive,
    ChatMessage,
    Class,
    School,
    StudentUser,
    TeacherUser,
    UserProfile,
    UserMemo,
)


class ProjectTestCase(TestCase):
    password = "SafePass123!"

    def setUp(self):
        self.school = School.objects.create(
            school_id="1001", school_name="テスト学校", school_password=make_password(self.password)
        )
        self.other_school = School.objects.create(
            school_id="2002", school_name="別の学校", school_password=make_password(self.password)
        )
        self.admin = AdministratorUser.objects.create(
            school=self.school, user_id=1, user_position=0, user_password=make_password(self.password)
        )
        self.classroom = Class.objects.create(school=self.school, class_name="1組", grade=1)
        self.teacher = TeacherUser.objects.create(
            school=self.school, user_id=10, user_name="先生", user_spell="せんせい", gender=0,
            birthdate=date(1990, 1, 1), user_position=1, user_password=make_password(self.password),
        )
        self.teacher.classes.add(self.classroom)
        self.student = StudentUser.objects.create(
            school=self.school, user_id=20, user_name="生徒", user_spell="せいと", gender=1,
            birthdate=date(2010, 1, 1), user_position=2, user_password=make_password(self.password),
        )
        self.student.classes.add(self.classroom)

    def admin_client(self):
        client = Client()
        session = client.session
        session.update({
            "school_id": self.school.id,
            "school_name": self.school.school_name,
            "login_user_id": self.admin.user_id,
            "user_position": 0,
        })
        session.save()
        return client

    def teacher_client(self):
        client = Client()
        session = client.session
        session.update({"school_id": self.school.id, "login_user_id": self.teacher.user_id, "user_position": 1})
        session.save()
        return client

    def student_client(self):
        client = Client()
        session = client.session
        session.update({"school_id": self.school.id, "login_user_id": self.student.user_id, "user_position": 2})
        session.save()
        return client


class AuthenticationSecurityTests(ProjectTestCase):
    def test_api_login_accepts_hashed_password_and_sets_session(self):
        response = self.client.post(
            reverse("api_login"),
            data=json.dumps({"school_id": "1001", "user_id": "20", "password": self.password}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["logged_in"])
        self.assertEqual(self.client.session["school_id"], self.school.id)

    def test_api_login_rejects_incorrect_password(self):
        response = self.client.post(
            reverse("api_login"),
            data=json.dumps({"school_id": "1001", "user_id": "20", "password": "wrong-password"}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 401)

    def test_plaintext_password_is_not_accepted(self):
        self.student.user_password = self.password
        self.student.save(update_fields=["user_password"])
        response = self.client.post(
            reverse("api_login"),
            data=json.dumps({"school_id": "1001", "user_id": "20", "password": self.password}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 401)

    @override_settings(EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend")
    def test_teacher_api_login_requires_valid_email_otp_before_session(self):
        self.teacher.email = "teacher@example.com"
        self.teacher.save(update_fields=["email"])
        response = self.client.post(
            reverse("api_login"),
            data=json.dumps({"school_id": "1001", "user_id": "10", "password": self.password}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 202)
        self.assertTrue(response.json()["otp_required"])
        self.assertNotIn("login_user_id", self.client.session)

        wrong = self.client.post(
            reverse("api_login_otp"), data=json.dumps({"otp_code": "000000"}), content_type="application/json"
        )
        self.assertEqual(wrong.status_code, 400)
        self.assertNotIn("login_user_id", self.client.session)

        code = re.search(r"(\d{6})", mail.outbox[-1].body).group(1)
        verified = self.client.post(
            reverse("api_login_otp"), data=json.dumps({"otp_code": code}), content_type="application/json"
        )
        self.assertEqual(verified.status_code, 200)
        self.assertTrue(verified.json()["logged_in"])
        self.assertEqual(self.client.session["login_user_id"], self.teacher.user_id)

    @override_settings(EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend")
    def test_teacher_api_login_requests_email_enrollment_when_not_registered(self):
        response = self.client.post(
            reverse("api_login"),
            data=json.dumps({"school_id": "1001", "user_id": "10", "password": self.password}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 428)
        self.assertTrue(response.json()["email_registration_required"])
        requested = self.client.post(
            reverse("api_login_otp"),
            data=json.dumps({"action": "register_email", "email": "legacy-teacher@example.com"}),
            content_type="application/json",
        )
        self.assertEqual(requested.status_code, 202)
        self.assertFalse(TeacherUser.objects.get(pk=self.teacher.pk).email)
        code = re.search(r"(\d{6})", mail.outbox[-1].body).group(1)
        verified = self.client.post(
            reverse("api_login_otp"),
            data=json.dumps({"action": "verify_enrollment", "otp_code": code}),
            content_type="application/json",
        )
        self.assertEqual(verified.status_code, 200)
        self.teacher.refresh_from_db()
        self.assertEqual(self.teacher.email, "legacy-teacher@example.com")
        self.assertEqual(self.client.session["login_user_id"], self.teacher.user_id)

    @override_settings(EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend")
    def test_administrator_web_login_requires_otp(self):
        self.admin.email = "admin@example.com"
        self.admin.save(update_fields=["email"])
        client = Client()
        session = client.session
        session["school_id"] = self.school.id
        session.save()
        # Django 5.2.7's test template-context copier is not Python 3.14 compatible.
        with patch("django.test.client.copy", side_effect=lambda value: value):
            response = client.post(reverse("user_login"), {"user_id": 1, "user_password": self.password})
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "6桁の認証コード")
        self.assertNotIn("login_user_id", client.session)
        code = re.search(r"(\d{6})", mail.outbox[-1].body).group(1)
        verified = client.post(reverse("user_login"), {"action": "verify_otp", "otp_code": code})
        self.assertRedirects(verified, reverse("home"), fetch_redirect_response=False)
        self.assertEqual(client.session["user_position"], 0)

    @override_settings(EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend")
    def test_school_and_administrator_are_created_only_after_email_verification(self):
        with patch("django.test.client.copy", side_effect=lambda value: value):
            response = self.client.post(reverse("school_register"), {
                "school_id": 3003,
                "school_name": "新しい学校",
                "school_password": "SchoolPass123!",
                "user_id": 99,
                "email": "new-admin@example.com",
                "user_password": "AdminPass123!",
            })
        self.assertEqual(response.status_code, 200)
        self.assertFalse(School.objects.filter(school_id="3003").exists())
        code = re.search(r"(\d{6})", mail.outbox[-1].body).group(1)
        verified = self.client.post(reverse("school_register"), {"action": "verify_otp", "otp_code": code})
        self.assertRedirects(verified, reverse("school_login"), fetch_redirect_response=False)
        school = School.objects.get(school_id="3003")
        admin = AdministratorUser.objects.get(school=school, user_id=99)
        self.assertEqual(admin.email, "new-admin@example.com")
        self.assertTrue(check_password("AdminPass123!", admin.user_password))

    @override_settings(EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend")
    def test_teacher_registration_and_email_change_require_verification(self):
        admin_client = self.admin_client()
        with patch("django.test.client.copy", side_effect=lambda value: value):
            response = admin_client.post(reverse("teacher_register"), {
                "user_id": 11, "user_name": "追加先生", "user_spell": "ついかせんせい",
                "gender": 0, "birthdate": "1991-02-03", "email": "teacher2@example.com",
                "user_password": "TeacherPass123!", "classes": [self.classroom.pk],
            })
        self.assertEqual(response.status_code, 200)
        self.assertFalse(TeacherUser.objects.filter(school=self.school, user_id=11).exists())
        code = re.search(r"(\d{6})", mail.outbox[-1].body).group(1)
        verified = admin_client.post(reverse("teacher_register"), {"action": "verify_otp", "otp_code": code})
        self.assertRedirects(verified, reverse("teacher_list"), fetch_redirect_response=False)
        created = TeacherUser.objects.get(school=self.school, user_id=11)
        self.assertEqual(created.email, "teacher2@example.com")

        teacher_client = self.teacher_client()
        requested = teacher_client.post(
            reverse("api_account_email"),
            data=json.dumps({"action": "request", "email": "changed@example.com"}),
            content_type="application/json",
        )
        self.assertEqual(requested.status_code, 200)
        created.refresh_from_db()
        self.assertEqual(created.email, "teacher2@example.com")

        # The authenticated test client belongs to self.teacher, so verify its own change.
        code = re.search(r"(\d{6})", mail.outbox[-1].body).group(1)
        changed = teacher_client.post(
            reverse("api_account_email"),
            data=json.dumps({"action": "verify", "otp_code": code}),
            content_type="application/json",
        )
        self.assertEqual(changed.status_code, 200)
        self.teacher.refresh_from_db()
        self.assertEqual(self.teacher.email, "changed@example.com")

    def test_management_routes_require_administrator_role(self):
        response = self.teacher_client().get(reverse("teacher_list"))
        self.assertEqual(response.status_code, 302)
        self.assertEqual(response.url, reverse("godot"))

    def test_password_columns_can_store_a_django_hash(self):
        self.assertLessEqual(len(self.student.user_password), StudentUser._meta.get_field("user_password").max_length)
        self.assertTrue(check_password(self.password, self.student.user_password))

    def test_student_cannot_use_teacher_student_registration_api(self):
        response = self.student_client().post(
            reverse("receive_form"),
            data=json.dumps({
                "user_id": 21,
                "user_name": "不正登録",
                "user_spell": "ふせいとうろく",
                "gender": 0,
                "birthdate": "2011-01-01",
                "user_password": "SafePass456!",
                "class_ids": [self.classroom.pk],
            }),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 401)
        self.assertFalse(StudentUser.objects.filter(school=self.school, user_id=21).exists())

    def test_teacher_student_registration_hashes_password(self):
        response = self.teacher_client().post(
            reverse("receive_form"),
            data=json.dumps({
                "user_id": 21,
                "user_name": "追加生徒",
                "user_spell": "ついかせいと",
                "gender": 0,
                "birthdate": "2011-01-01",
                "user_password": "SafePass456!",
                "class_ids": [self.classroom.pk],
            }),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 200)
        created = StudentUser.objects.get(school=self.school, user_id=21)
        self.assertTrue(check_password("SafePass456!", created.user_password))

    def test_admin_edit_without_password_preserves_existing_hash(self):
        original_hash = self.student.user_password
        response = self.admin_client().post(
            reverse("student_edit", args=[self.student.pk]),
            data={
                "user_id": self.student.user_id,
                "user_name": "変更後",
                "user_spell": self.student.user_spell,
                "gender": self.student.gender,
                "birthdate": self.student.birthdate.isoformat(),
                "user_password": "",
                "classes": [self.classroom.pk],
            },
        )
        self.assertEqual(response.status_code, 302)
        self.student.refresh_from_db()
        self.assertEqual(self.student.user_password, original_hash)
        self.assertEqual(self.student.user_name, "変更後")

    def test_assignment_upload_requires_login_and_rejects_executable(self):
        upload = SimpleUploadedFile("answer.txt", b"answer", content_type="text/plain")
        self.assertEqual(self.client.post(reverse("submit_assignment"), {"file": upload}).status_code, 401)

        executable = SimpleUploadedFile("answer.exe", b"MZ", content_type="application/octet-stream")
        response = self.student_client().post(reverse("submit_assignment"), {"file": executable})
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()["error"], "unsupported_file_type")


class BackupTests(ProjectTestCase):
    def setUp(self):
        super().setUp()
        UserMemo.objects.create(school=self.school, user_id=self.student.user_id, text="もとのメモ", status="planned")
        ChatMessage.objects.create(
            school=self.school,
            room_name="school-1001-dm-10-20",
            sender_user_id=self.teacher.user_id,
            sender_user_name=self.teacher.user_name,
            client_message_id="message-1",
            message="復元対象の会話",
        )

    def test_backup_and_restore_replaces_school_scoped_data(self):
        archive = create_backup(school=self.school, created_by_user_id=self.admin.user_id)
        self.assertTrue(archive.file.storage.exists(archive.file.name))
        self.assertGreaterEqual(archive.record_count, 5)
        UserMemo.objects.filter(school=self.school).delete()
        self.student.user_name = "変更後の名前"
        self.student.save(update_fields=["user_name"])

        result = restore_backup(archive=archive, school=self.school)

        self.assertEqual(result.restored_records, archive.record_count)
        self.assertEqual(UserMemo.objects.get(school=self.school).text, "もとのメモ")
        self.assertEqual(StudentUser.objects.get(school=self.school, user_id=20).user_name, "生徒")
        self.assertTrue(ChatMessage.objects.filter(school=self.school, client_message_id="message-1").exists())

    def test_backup_restore_rejects_tampered_file(self):
        archive = create_backup(school=self.school, created_by_user_id=self.admin.user_id)
        archive.file.save("tampered.json", ContentFile(b'{"changed":true}'), save=True)
        with self.assertRaises(BackupValidationError):
            restore_backup(archive=archive, school=self.school)

    def test_backup_restore_rejects_another_school(self):
        archive = create_backup(school=self.school, created_by_user_id=self.admin.user_id)
        with self.assertRaises(BackupValidationError):
            restore_backup(archive=archive, school=self.other_school)

    def test_backup_views_are_admin_only_and_confirmation_is_required(self):
        client = self.admin_client()
        create_response = client.post(reverse("backup_create"))
        self.assertEqual(create_response.status_code, 302)
        archive = BackupArchive.objects.get(school=self.school)
        no_confirmation = client.post(reverse("backup_restore", args=[archive.id]), {"confirmation": "no"})
        self.assertEqual(no_confirmation.status_code, 302)
        self.assertEqual(archive.record_count, BackupArchive.objects.get(pk=archive.pk).record_count)
        self.assertEqual(self.teacher_client().get(reverse("backup_list")).status_code, 302)

    def test_restore_view_creates_a_safety_backup_before_overwriting(self):
        client = self.admin_client()
        archive = create_backup(school=self.school, created_by_user_id=self.admin.user_id)
        UserMemo.objects.filter(school=self.school).update(text="復元前に変更")

        response = client.post(reverse("backup_restore", args=[archive.id]), {"confirmation": "復元する"})

        self.assertEqual(response.status_code, 302)
        self.assertEqual(BackupArchive.objects.filter(school=self.school).count(), 2)
        self.assertEqual(UserMemo.objects.get(school=self.school).text, "もとのメモ")

    def test_backup_download_is_school_scoped(self):
        archive = create_backup(school=self.school, created_by_user_id=self.admin.user_id)
        other_admin = AdministratorUser.objects.create(
            school=self.other_school, user_id=2, user_position=0, user_password=make_password(self.password)
        )
        client = Client()
        session = client.session
        session.update({"school_id": self.other_school.id, "login_user_id": other_admin.user_id, "user_position": 0})
        session.save()
        with self.settings(DEBUG=False):
            self.assertEqual(client.get(reverse("backup_download", args=[archive.id])).status_code, 404)


class DataIsolationTests(ProjectTestCase):
    def test_chat_api_rejects_a_room_from_another_school(self):
        client = self.teacher_client()
        response = client.get(reverse("chat_messages"), {"room": "school-2002-dm-10-20"})
        self.assertEqual(response.status_code, 403)

    def test_student_delete_by_teacher_is_limited_to_their_school(self):
        other_student = StudentUser.objects.create(
            school=self.other_school, user_id=20, user_name="他校生徒", user_spell="たこう", gender=0,
            birthdate=date(2010, 1, 1), user_position=2, user_password=make_password(self.password),
        )
        with self.settings(DEBUG=False):
            response = self.teacher_client().post(reverse("student_delete_by_teacher", args=[other_student.id]))
        self.assertEqual(response.status_code, 404)
        self.assertTrue(StudentUser.objects.filter(pk=other_student.pk).exists())


class ProfileAgeTests(ProjectTestCase):
    def test_profile_save_accepts_an_integer_age(self):
        response = self.student_client().post(
            reverse("profile_save"),
            data=json.dumps({"age": "20"}),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(UserProfile.objects.get(school=self.school, user_id=self.student.user_id).age, 20)

    def test_profile_save_rejects_decimal_age(self):
        response = self.student_client().post(
            reverse("profile_save"),
            data=json.dumps({"age": 20.0}),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()["errors"]["age"], ["年齢は整数で入力してください"])
