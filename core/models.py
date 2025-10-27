# core/models.py
from django.db import models

class School(models.Model):
    school_name = models.CharField(max_length=100)
    school_id = models.CharField(max_length=20, unique=True)
    school_password = models.CharField(max_length=50)

    def __str__(self):
        return self.school_name


class User(models.Model):
    school = models.ForeignKey(School, on_delete=models.CASCADE)
    user_name = models.CharField(max_length=50)     # 表示名（任意）
    user_id = models.CharField(max_length=20, unique=True)  # ← ログイン用
    user_password = models.CharField(max_length=50)

    def __str__(self):
        return f"{self.user_name} ({self.user_id}) - {self.school.school_name}"
