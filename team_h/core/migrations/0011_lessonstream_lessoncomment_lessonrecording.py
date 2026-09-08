from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0010_alter_usermemo_status"),
    ]

    operations = [
        migrations.CreateModel(
            name="LessonStream",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("teacher_user_id", models.IntegerField()),
                ("teacher_user_name", models.CharField(max_length=50)),
                ("title", models.CharField(max_length=120)),
                ("description", models.TextField(blank=True, default="", max_length=1000)),
                ("source_type", models.CharField(choices=[("screen", "画面共有"), ("camera", "カメラ"), ("external", "外部URL")], default="external", max_length=20)),
                ("stream_url", models.URLField(blank=True, default="", max_length=500)),
                ("recording_url", models.URLField(blank=True, default="", max_length=500)),
                ("status", models.CharField(choices=[("scheduled", "準備中"), ("live", "配信中"), ("ended", "終了")], default="scheduled", max_length=20)),
                ("started_at", models.DateTimeField(blank=True, null=True)),
                ("ended_at", models.DateTimeField(blank=True, null=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("school", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to="core.school")),
            ],
        ),
        migrations.CreateModel(
            name="LessonRecording",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("teacher_user_id", models.IntegerField()),
                ("teacher_user_name", models.CharField(max_length=50)),
                ("title", models.CharField(max_length=120)),
                ("description", models.TextField(blank=True, default="", max_length=1000)),
                ("video_url", models.URLField(max_length=500)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("lesson", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="recordings", to="core.lessonstream")),
                ("school", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to="core.school")),
            ],
        ),
        migrations.CreateModel(
            name="LessonComment",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("sender_user_id", models.IntegerField()),
                ("sender_user_name", models.CharField(max_length=50)),
                ("sender_position", models.IntegerField()),
                ("message", models.TextField(max_length=500)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("lesson", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="comments", to="core.lessonstream")),
                ("school", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to="core.school")),
            ],
        ),
        migrations.AddIndex(
            model_name="lessonstream",
            index=models.Index(fields=["school", "status", "-updated_at"], name="core_lesson_school__b16440_idx"),
        ),
        migrations.AddIndex(
            model_name="lessonstream",
            index=models.Index(fields=["school", "-created_at"], name="core_lesson_school__147193_idx"),
        ),
        migrations.AddIndex(
            model_name="lessonrecording",
            index=models.Index(fields=["school", "-created_at"], name="core_lesson_school__502676_idx"),
        ),
        migrations.AddIndex(
            model_name="lessonrecording",
            index=models.Index(fields=["school", "teacher_user_id"], name="core_lesson_school__13fe51_idx"),
        ),
        migrations.AddIndex(
            model_name="lessoncomment",
            index=models.Index(fields=["lesson", "created_at"], name="core_lesson_lesson__2aa29e_idx"),
        ),
        migrations.AddIndex(
            model_name="lessoncomment",
            index=models.Index(fields=["school", "sender_user_id"], name="core_lesson_school__9ae93e_idx"),
        ),
    ]
