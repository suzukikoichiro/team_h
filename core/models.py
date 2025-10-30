from django.db import models

class School(models.Model):
    school_id = models.CharField(max_length=20, unique=True)
    school_name = models.CharField(max_length=100)
    address = models.CharField(max_length=200, blank=True)
    school_password = models.CharField(max_length=50)

    def __str__(self):
        return self.school_name


class User(models.Model):
    GENDER_CHOICES = [
        (0, '男性'),
        (1, '女性'),
        (2, 'その他'),
    ]
    user_id = models.IntegerField()
    user_name = models.CharField(max_length=50)
    user_spell = models.CharField(max_length=50, default="")
    gendar = models.IntegerField(choices=GENDER_CHOICES, default=0)
    birthdate = models.DateField()
    user_password = models.CharField(max_length=20)
    user_position = models.IntegerField(default=0)
    school = models.ForeignKey(School, on_delete=models.CASCADE)
    class_id = models.IntegerField(null=True)

    class Meta:
        unique_together = ('user_id', 'school')

    def __str__(self):
        return f"{self.user_name} ({self.user_id}) - {self.school.school_name}"

