from django.db import models
from django.utils import timezone


#学校
class School(models.Model):
    school_id = models.CharField(max_length=20, unique=True)
    school_name = models.CharField(max_length=100)
    school_password = models.CharField(max_length=128)

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
    user_password = models.CharField(max_length=128)
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
        email = models.EmailField(max_length=254, null=True, unique=True)
        user_password = models.CharField(max_length=128)
        user_position = models.IntegerField()
        school = models.ForeignKey(School, on_delete=models.CASCADE)

        class Meta:
            unique_together = ('user_id', 'school')

        def __str__(self):
            return f"{self.user_id} - {self.school.school_name}"



#教職員
class TeacherUser(BaseUser):
    email = models.EmailField(max_length=254, null=True, unique=True)
    classes = models.ManyToManyField(Class, blank=True, related_name='teachers')


#学生
class StudentUser(BaseUser):
    classes = models.ManyToManyField(Class, blank=True, related_name='students')


class UserProfile(models.Model):
    school = models.ForeignKey(School, on_delete=models.CASCADE)
    user_id = models.IntegerField()
    display_name = models.CharField(max_length=50, blank=True, default="")
    nickname = models.CharField(max_length=50, blank=True, default="")
    age = models.PositiveSmallIntegerField(null=True, blank=True)
    hobbies = models.TextField(max_length=300, blank=True, default="")
    message = models.TextField(max_length=300, blank=True, default="")
    avatar_key = models.CharField(max_length=50, blank=True, default="default")
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("school", "user_id")
        indexes = [
            models.Index(fields=["school", "user_id"]),
            models.Index(fields=["school", "display_name"]),
        ]

    def __str__(self):
        return f"{self.display_name or self.user_id} - {self.school.school_name}"


class ChatMessage(models.Model):
    school = models.ForeignKey(School, on_delete=models.CASCADE)
    room_name = models.CharField(max_length=100)
    sender_user_id = models.IntegerField()
    sender_user_name = models.CharField(max_length=50)
    message = models.TextField(max_length=1000)
    client_message_id = models.CharField(max_length=64, blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["school", "room_name", "created_at"]),
            models.Index(fields=["school", "sender_user_id"]),
        ]
        unique_together = ("school", "room_name", "client_message_id")

    def __str__(self):
        return f"{self.room_name} {self.sender_user_name}: {self.message[:20]}"


class ChatReadState(models.Model):
    school = models.ForeignKey(School, on_delete=models.CASCADE)
    user_id = models.IntegerField()
    room_name = models.CharField(max_length=100)
    last_read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        unique_together = ("school", "user_id", "room_name")
        indexes = [
            models.Index(fields=["school", "user_id", "room_name"]),
        ]


class ChatHiddenState(models.Model):
    school = models.ForeignKey(School, on_delete=models.CASCADE)
    user_id = models.IntegerField()
    room_name = models.CharField(max_length=100)
    hidden_before_at = models.DateTimeField()

    class Meta:
        unique_together = ("school", "user_id", "room_name")
        indexes = [
            models.Index(fields=["school", "user_id", "room_name"]),
        ]


class UserMemo(models.Model):
    STATUS_CHOICES = [
        ("none", "未分類"),
        ("planned", "予定"),
        ("important", "重要"),
        ("done", "完了"),
    ]

    school = models.ForeignKey(School, on_delete=models.CASCADE)
    user_id = models.IntegerField()
    text = models.TextField(max_length=1000)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="none")
    scheduled_at = models.DateTimeField(null=True, blank=True)
    source = models.CharField(max_length=20, default="personal")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=["school", "user_id", "status", "-updated_at"]),
            models.Index(fields=["school", "user_id", "scheduled_at"], name="core_userme_school__ac3d51_idx"),
        ]

    def __str__(self):
        return f"{self.user_id} {self.status}: {self.text[:20]}"


class LessonStream(models.Model):
    STATUS_CHOICES = [
        ("scheduled", "準備中"),
        ("live", "配信中"),
        ("ended", "終了"),
    ]
    SOURCE_CHOICES = [
        ("screen", "画面共有"),
        ("camera", "カメラ"),
        ("external", "外部URL"),
    ]

    school = models.ForeignKey(School, on_delete=models.CASCADE)
    teacher_user_id = models.IntegerField()
    teacher_user_name = models.CharField(max_length=50)
    title = models.CharField(max_length=120)
    description = models.TextField(max_length=1000, blank=True, default="")
    source_type = models.CharField(max_length=20, choices=SOURCE_CHOICES, default="external")
    stream_url = models.URLField(max_length=500, blank=True, default="")
    recording_url = models.URLField(max_length=500, blank=True, default="")
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="scheduled")
    started_at = models.DateTimeField(null=True, blank=True)
    ended_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=["school", "status", "-updated_at"]),
            models.Index(fields=["school", "-created_at"]),
        ]

    def __str__(self):
        return f"{self.title} ({self.status}) - {self.school.school_name}"


class LessonComment(models.Model):
    lesson = models.ForeignKey(LessonStream, on_delete=models.CASCADE, related_name="comments")
    school = models.ForeignKey(School, on_delete=models.CASCADE)
    sender_user_id = models.IntegerField()
    sender_user_name = models.CharField(max_length=50)
    sender_position = models.IntegerField()
    message = models.TextField(max_length=500)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["lesson", "created_at"]),
            models.Index(fields=["school", "sender_user_id"]),
        ]


class LessonRecording(models.Model):
    school = models.ForeignKey(School, on_delete=models.CASCADE)
    lesson = models.ForeignKey(LessonStream, on_delete=models.SET_NULL, null=True, blank=True, related_name="recordings")
    teacher_user_id = models.IntegerField()
    teacher_user_name = models.CharField(max_length=50)
    title = models.CharField(max_length=120)
    description = models.TextField(max_length=1000, blank=True, default="")
    video_url = models.URLField(max_length=500)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["school", "-created_at"]),
            models.Index(fields=["school", "teacher_user_id"]),
        ]

    def __str__(self):
        return f"{self.title} - {self.school.school_name}"


class GrowthPointEvent(models.Model):
    EVENT_CHOICES = [
        ("login", "ログイン"),
        ("chat_person", "チャットした相手"),
        ("lesson_recording_view", "授業映像の閲覧"),
        ("lesson_live_join", "授業ライブへの参加"),
    ]

    school = models.ForeignKey(School, on_delete=models.CASCADE)
    user_id = models.IntegerField()
    event_type = models.CharField(max_length=40, choices=EVENT_CHOICES)
    event_key = models.CharField(max_length=120)
    points = models.PositiveIntegerField(default=0)
    season_key = models.CharField(max_length=20)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("school", "user_id", "event_type", "event_key")
        indexes = [
            models.Index(fields=["school", "season_key", "event_type"]),
            models.Index(fields=["school", "user_id", "season_key"]),
        ]

    def __str__(self):
        return f"{self.school.school_name} {self.user_id} {self.event_type} +{self.points}"


class BackupArchive(models.Model):
    """管理者が作成した、学校単位の復元可能な業務データの保管記録。"""

    school = models.ForeignKey(School, on_delete=models.CASCADE, related_name="backup_archives")
    created_by_user_id = models.IntegerField()
    file = models.FileField(upload_to="backups/%Y/%m/%d")
    checksum = models.CharField(max_length=64)
    record_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [models.Index(fields=["school", "-created_at"])]

    def __str__(self):
        return f"{self.school.school_name} backup {self.created_at:%Y-%m-%d %H:%M}"
