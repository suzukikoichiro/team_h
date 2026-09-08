from django import forms
from django.contrib.auth.hashers import identify_hasher, make_password
from django.core.exceptions import ValidationError
from .models import School, AdministratorUser, TeacherUser, StudentUser, Class


def normalize_account_email(value):
    return (value or "").strip().lower()


def account_email_exists(email, *, exclude_user=None):
    normalized = normalize_account_email(email)
    if not normalized:
        return False
    for model in (AdministratorUser, TeacherUser):
        queryset = model.objects.filter(email__iexact=normalized)
        if exclude_user is not None and isinstance(exclude_user, model):
            queryset = queryset.exclude(pk=exclude_user.pk)
        if queryset.exists():
            return True
    return False


class EmailOtpForm(forms.Form):
    otp_code = forms.CharField(
        label="認証コード",
        min_length=6,
        max_length=6,
        widget=forms.TextInput(attrs={"inputmode": "numeric", "autocomplete": "one-time-code"}),
    )

    def clean_otp_code(self):
        code = self.cleaned_data["otp_code"].strip()
        if not code.isdigit():
            raise ValidationError("認証コードは6桁の数字で入力してください。")
        return code


class EmailChangeForm(forms.Form):
    email = forms.EmailField(label="新しいメールアドレス", max_length=254)

    def __init__(self, *args, current_user=None, **kwargs):
        self.current_user = current_user
        super().__init__(*args, **kwargs)

    def clean_email(self):
        email = normalize_account_email(self.cleaned_data["email"])
        if account_email_exists(email, exclude_user=self.current_user):
            raise ValidationError("このメールアドレスはすでに別のアカウントに登録されています。")
        if self.current_user is not None and normalize_account_email(self.current_user.email) == email:
            raise ValidationError("現在と異なるメールアドレスを入力してください。")
        return email


class SecurePasswordField(forms.CharField):
    def __init__(self, *args, **kwargs):
        kwargs.setdefault("min_length", 8)
        kwargs.setdefault("max_length", 128)
        kwargs.setdefault("help_text", "8文字以上128文字以下で入力してください。")
        kwargs.setdefault("widget", PasswordInputWidget())
        super().__init__(*args, **kwargs)


class PasswordInputWidget(forms.PasswordInput):
    def __init__(self, *args, **kwargs):
        kwargs.setdefault("render_value", False)
        kwargs.setdefault("attrs", {}).setdefault("autocomplete", "new-password")
        super().__init__(*args, **kwargs)

class PositiveNumberInput(forms.NumberInput):
    def __init__(self, *args, **kwargs):
        kwargs.setdefault('attrs', {}).update({'min': '1'})
        super().__init__(*args, **kwargs)


#学校登録
class SchoolRegisterForm(forms.ModelForm):
    school_password = SecurePasswordField(label="学校パスワード")
    class Meta:
        model = School
        fields = ['school_id', 'school_name', 'school_password']
        widgets = {
            'school_password': PasswordInputWidget(),
            'school_id': PositiveNumberInput(),
        }
        labels = {
            'school_id': '学校ID',
            'school_name': '学校名',
            'school_password': '学校パスワード',
        }


#学校ログイン
class SchoolLoginForm(forms.Form):
    school_id = forms.IntegerField(label="学校ID", widget=PositiveNumberInput())
    school_password = forms.CharField(label="パスワード", widget=PasswordInputWidget())


#ユーザーログイン
class UserLoginForm(forms.Form):
    user_id = forms.IntegerField(label="ユーザーID", widget=PositiveNumberInput())
    user_password = forms.CharField(label="パスワード", widget=PasswordInputWidget())


#共通ユーザー当ロック
class BaseUserRegisterForm(forms.ModelForm):
    user_password = SecurePasswordField(label="パスワード")

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._original_password = self.instance.user_password if self.instance and self.instance.pk else ""
        if self.instance and self.instance.pk:
            self.fields["user_password"].required = False
            self.fields["user_password"].help_text = "変更する場合のみ8文字以上で入力してください。"

    def clean_user_password(self):
        password = self.cleaned_data.get("user_password", "")
        if not password and self._original_password:
            return self._original_password
        try:
            identify_hasher(password)
            return password
        except ValueError:
            return make_password(password)

    def clean_email(self):
        if self.instance.pk and self.fields.get("email") and self.fields["email"].disabled:
            return self.instance.email
        email = normalize_account_email(self.cleaned_data.get("email"))
        if account_email_exists(email, exclude_user=self.instance if self.instance.pk else None):
            raise ValidationError("このメールアドレスはすでに別のアカウントに登録されています。")
        return email

    def save(self, commit=True, school=None):
        user = super().save(commit=False)
        if hasattr(self, 'user_position'):
            user.user_position = self.user_position
        if school:
            user.school = school
        if commit:
            user.save()
            if hasattr(self, 'save_m2m'):
                self.save_m2m()
        return user


#管理者
class AdministratorRegisterForm(BaseUserRegisterForm):
    class Meta:
        model = AdministratorUser
        fields = ['user_id', 'email', 'user_password']
        labels = {'user_id': 'ユーザーID', 'email': 'メールアドレス', 'user_password': '管理者パスワード'}

    user_position = 0  #管理者

    def save(self, commit=True, school=None):
        user = super().save(commit)
        user.class_id = None
        if commit:
            user.save()
        return user


#教師
class TeacherRegisterForm(BaseUserRegisterForm):
    classes = forms.ModelMultipleChoiceField(
        queryset=Class.objects.none(),
        widget=forms.CheckboxSelectMultiple,
        required=False,
        label="所属クラス"
    )

    class Meta:
        model = TeacherUser
        fields = ['user_id','user_name','user_spell','gender','birthdate','email','user_password','classes']
        widgets = {'birthdate': forms.DateInput(attrs={'type': 'date'})}
        labels = {
            'user_id': 'ユーザーID',
            'user_name': '氏名',
            'user_spell': '氏名（ふりがな）',
            'gender': '性別',
            'birthdate': '生年月日',
            'email': 'メールアドレス',
            'user_password': '職員パスワード',
            'classes': '所属クラス',
        }

    user_position = 1  #教職員

    def __init__(self, *args, **kwargs):
        self.school_id = kwargs.pop('school_id', None)
        super().__init__(*args, **kwargs)
        if self.school_id:
            self.fields['classes'].queryset = Class.objects.filter(school_id=self.school_id)
        if self.instance and self.instance.pk:
            self.fields['user_id'].disabled = True
            self.fields['email'].disabled = True
            self.fields['email'].required = False
            self.fields['email'].help_text = "本人がメタバースのオプション画面から変更します。"

    def clean_user_id(self):
        user_id = self.cleaned_data.get('user_id')
        if self.instance and self.instance.pk:
            return self.instance.user_id
        if not user_id:
            return user_id
        if self.school_id and TeacherUser.objects.filter(user_id=user_id, school_id=self.school_id).exclude(pk=getattr(self.instance, 'pk', None)).exists():
            raise ValidationError("このユーザーIDはすでに登録されています。")
        if AdministratorUser.objects.filter(user_id=user_id).exists():
            raise ValidationError("このユーザーIDはすでに登録されています。")
        return user_id


#学生
class StudentRegisterForm(BaseUserRegisterForm):
    classes = forms.ModelMultipleChoiceField(
        queryset=Class.objects.none(),
        widget=forms.CheckboxSelectMultiple,
        required=False,
        label="所属クラス"
    )

    class Meta:
        model = StudentUser
        fields = ['user_id', 'user_name', 'user_spell', 'gender', 'birthdate', 'user_password', 'classes']
        widgets = {'birthdate': forms.DateInput(attrs={'type': 'date'})}
        labels = {
            'user_id': 'ユーザーID',
            'user_name': '氏名',
            'user_spell': '氏名（ふりがな）',
            'gender': '性別',
            'birthdate': '生年月日',
            'user_password': '生徒パスワード',
            'classes': '所属クラス',
        }

    user_position = 2  #学英

    def __init__(self, *args, **kwargs):
        self.school_id = kwargs.pop('school_id', None)
        super().__init__(*args, **kwargs)
        if self.school_id:
            self.fields['classes'].queryset = Class.objects.filter(school_id=self.school_id)
        if self.instance and self.instance.pk:
            self.fields['user_id'].disabled = True
            
    def clean_user_id(self):
        user_id = self.cleaned_data.get('user_id')

        if self.instance and self.instance.pk:
            return self.instance.user_id

        if not user_id:
            raise ValidationError("ユーザーIDを入力してください。")

        if self.school_id and StudentUser.objects.filter(user_id=user_id, school_id=self.school_id).exists():
            raise ValidationError("このユーザーIDはすでに登録されています。")

        if TeacherUser.objects.filter(user_id=user_id).exists() or AdministratorUser.objects.filter(user_id=user_id).exists():
            raise ValidationError("このユーザーIDはすでに登録されています。")

        return user_id






#クラス
class ClassForm(forms.ModelForm):
    class Meta:
        model = Class
        fields = ['class_name', 'grade']
