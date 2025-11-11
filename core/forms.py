from django import forms
from django.core.exceptions import ValidationError
from .models import School, AdministratorUser, TeacherUser, Class


class PasswordInputWidget(forms.PasswordInput):
    pass

class PositiveNumberInput(forms.NumberInput):
    def __init__(self, *args, **kwargs):
        kwargs.setdefault('attrs', {}).update({'min': '1'})
        super().__init__(*args, **kwargs)


#学校登録
class SchoolRegisterForm(forms.ModelForm):
    class Meta:
        model = School
        fields = ['school_id', 'school_name', 'address', 'school_password']
        widgets = {
            'school_password': PasswordInputWidget(),
            'school_id': PositiveNumberInput(),
        }
        labels = {
            'school_id': '学校ID',
            'school_name': '学校名',
            'address': '住所',
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
    user_password = forms.CharField(label="パスワード", widget=PasswordInputWidget())

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


#管理者登録
class AdministratorRegisterForm(BaseUserRegisterForm):
    class Meta:
        model = AdministratorUser
        fields = ['user_id', 'user_password']
        labels = {'user_id': 'ユーザーID', 'user_password': '管理者パスワード'}

    user_position = 0  # 管理者

    def save(self, commit=True, school=None):
        user = super().save(commit)
        user.class_id = None
        if commit:
            user.save()
        return user


#教師登録
class TeacherRegisterForm(BaseUserRegisterForm):
    classes = forms.ModelMultipleChoiceField(
        queryset=Class.objects.none(),
        widget=forms.CheckboxSelectMultiple,
        required=False,
        label="所属クラス"
    )

    class Meta:
        model = TeacherUser
        fields = ['user_id','user_name','user_spell','gendar','birthdate','user_password','classes']
        widgets = {'birthdate': forms.DateInput(attrs={'type': 'date'})}
        labels = {
            'user_id': 'ユーザーID',
            'user_name': '氏名',
            'user_spell': '氏名（ふりがな）',
            'gendar': '性別',
            'birthdate': '生年月日',
            'user_password': '職員パスワード',
            'classes': '所属クラス',
        }

    user_position = 1  # 教職員

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
            return user_id
        if self.school_id and TeacherUser.objects.filter(user_id=user_id, school_id=self.school_id).exclude(pk=getattr(self.instance, 'pk', None)).exists():
            raise ValidationError("このユーザーIDはすでに登録されています。")
        if AdministratorUser.objects.filter(user_id=user_id).exists():
            raise ValidationError("このユーザーIDはすでに登録されています。")
        return user_id


#クラス
class ClassForm(forms.ModelForm):
    class Meta:
        model = Class
        fields = ['class_name', 'grade']
