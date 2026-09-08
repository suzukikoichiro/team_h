from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("core", "0014_usermemo_schedule_fields")]

    operations = [
        migrations.AddField(
            model_name="administratoruser",
            name="email",
            field=models.EmailField(max_length=254, null=True, unique=True),
        ),
        migrations.AddField(
            model_name="teacheruser",
            name="email",
            field=models.EmailField(max_length=254, null=True, unique=True),
        ),
    ]
