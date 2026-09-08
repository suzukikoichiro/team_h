from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0004_alter_studentuser_options_and_more"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="school",
            name="address",
        ),
    ]
