# Generated manually for the graduation project.

from django.db import migrations, models
import django.db.models.deletion


def hash_legacy_passwords(apps, schema_editor):
    from django.contrib.auth.hashers import identify_hasher, make_password

    for model_name in ("School", "AdministratorUser", "TeacherUser", "StudentUser"):
        model = apps.get_model("core", model_name)
        password_field = "school_password" if model_name == "School" else "user_password"
        for instance in model.objects.all().iterator():
            value = getattr(instance, password_field)
            try:
                identify_hasher(value)
            except ValueError:
                setattr(instance, password_field, make_password(value))
                instance.save(update_fields=[password_field])


class Migration(migrations.Migration):

    dependencies = [("core", "0012_growthpointevent")]

    operations = [
        migrations.AlterField(model_name="school", name="school_password", field=models.CharField(max_length=128)),
        migrations.AlterField(model_name="administratoruser", name="user_password", field=models.CharField(max_length=128)),
        migrations.AlterField(model_name="teacheruser", name="user_password", field=models.CharField(max_length=128)),
        migrations.AlterField(model_name="studentuser", name="user_password", field=models.CharField(max_length=128)),
        migrations.RunPython(hash_legacy_passwords, migrations.RunPython.noop),
        migrations.CreateModel(
            name="BackupArchive",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_by_user_id", models.IntegerField()),
                ("file", models.FileField(upload_to="backups/%Y/%m/%d")),
                ("checksum", models.CharField(max_length=64)),
                ("record_count", models.PositiveIntegerField(default=0)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("school", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="backup_archives", to="core.school")),
            ],
            options={"indexes": [models.Index(fields=["school", "-created_at"], name="core_backup_school__379ed3_idx")]},
        ),
    ]
