from django.db import models


#学校
class School(models.Model):
    school_id = models.CharField(max_length=20, unique=True)
    school_name = models.CharField(max_length=100)
    address = models.CharField(max_length=200, blank=True)
    school_password = models.CharField(max_length=50)

    def __str__(self):
        return self.school_name


#クラス
class Class(models.Model):
    class_id = models.AutoField(primary_key=True, verbose_name='クラスID')
    school = models.ForeignKey(School, on_delete=models.CASCADE, verbose_name='学校')
    class_name = models.CharField(max_length=50, verbose_name='クラス名')  # 例: 1年2組
    grade = models.IntegerField(verbose_name='学年')

    def __str__(self):
        return f"{self.grade}年 {self.class_name}"

    class Meta:
        verbose_name = "クラス"
        verbose_name_plural = "クラス一覧"
        db_table = 'class'


#共通ユーザー
class BaseUser(models.Model):
    GENDAR_CHOICES = [
        (0, '男性'),
        (1, '女性'),
        (2, 'その他'),
    ]

    user_id = models.IntegerField()
    user_name = models.CharField(max_length=50)
    user_spell = models.CharField(max_length=50, default="")
    gender = models.IntegerField(choices=GENDAR_CHOICES, default=0)
    birthdate = models.DateField()
    user_password = models.CharField(max_length=20)
    user_position = models.IntegerField()
    school = models.ForeignKey(School, on_delete=models.CASCADE)

    class Meta:
        abstract = True
        unique_together = ('user_id', 'school')

    def __str__(self):
        return f"{self.user_name} ({self.user_id}) - {self.school.school_name}"


#管理者
class AdministratorUser(models.Model):
        user_id = models.IntegerField()
        user_password = models.CharField(max_length=20)
        user_position = models.IntegerField()
        school = models.ForeignKey(School, on_delete=models.CASCADE)

        class Meta:
            unique_together = ('user_id', 'school')

        def __str__(self):
            return f"{self.user_id} - {self.school.school_name}"



#教職員
class TeacherUser(BaseUser):
    classes = models.ManyToManyField(Class, blank=True, related_name='teachers')


#学生
class StudentUser(BaseUser):
    classes = models.ManyToManyField(Class, blank=True, related_name='students')