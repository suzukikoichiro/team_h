from django import forms
from .models import School, AdministratorUser,TeacherUser, Class


class SchoolRegisterForm(forms.ModelForm):
    class Meta:
        model = School
        fields = ['school_id', 'school_name', 'address', 'school_password']
        widgets = {
            'school_password': forms.PasswordInput(),
            'school_id': forms.NumberInput(attrs={'min': '1'}),
        }
        labels = {
            'school_id': '学校ID',
            'school_name': '学校名',
            'address': '住所',
            'school_password': '学校パスワード',
        }


class SchoolLoginForm(forms.Form):
    school_id = forms.IntegerField(
        label="学校ID",
        widget=forms.NumberInput(attrs={'min': '1'}),
    )
    school_password = forms.CharField(
        label="パスワード",
        widget=forms.PasswordInput
    )


class UserLoginForm(forms.Form):
    user_id = forms.IntegerField(
        label="ユーザーID",
        widget=forms.NumberInput(attrs={'min': '1'})
    )
    user_password = forms.CharField(
        label="パスワード",
        widget=forms.PasswordInput
    )


class AdministratorRegisterForm(forms.ModelForm):
    class Meta:
        model = AdministratorUser
        fields = ['user_id', 'user_name', 'user_spell', 'gendar', 'birthdate', 'user_password']
        widgets = {
            'user_password': forms.PasswordInput(),
            'birthdate': forms.DateInput(attrs={'type': 'date'}),
        }
        labels = {
            'user_id': 'ユーザーID',
            'user_name': '氏名',
            'user_spell': '氏名（ふりがな）',
            'gendar': '性別',
            'birthdate': '生年月日',
            'user_password': '管理者パスワード',
        }

    def save(self, commit=True, school=None):
        user = super().save(commit=False)
        user.user_position = 0  # 管理者
        if school:
            user.school = school
        user.class_id = None
        if commit:
            user.save()
        return user


class TeacherRegisterForm(forms.ModelForm):
    classes = forms.ModelMultipleChoiceField(
        queryset=Class.objects.none(),
        widget=forms.CheckboxSelectMultiple,
        required=False,
        label="所属クラス"
    )

    class Meta:
        model = TeacherUser
        fields = ['user_id', 'user_name', 'user_spell', 'gendar', 'birthdate', 'user_password']
        widgets = {
            'user_password': forms.PasswordInput(),
            'birthdate': forms.DateInput(attrs={'type': 'date'}),
        }
        labels = {
            'user_id': 'ユーザーID',
            'user_name': '氏名',
            'user_spell': '氏名（ふりがな）',
            'gendar': '性別',
            'birthdate': '生年月日',
            'user_password': '職員パスワード',
        }

    def __init__(self, *args, **kwargs):
        school_id = kwargs.pop('school_id', None)
        super().__init__(*args, **kwargs)

        if school_id:
            self.fields['classes'].queryset = Class.objects.filter(school_id=school_id)
        else:
            self.fields['classes'].queryset = Class.objects.none()

    def save(self, commit=True, school=None):
        user = super().save(commit=False)
        user.user_position = 1  # 教職員
        if school:
            user.school = school
        if commit:
            user.save()
            self.save_m2m()
        return user


class ClassForm(forms.ModelForm):
    class Meta:
        model = Class
        fields = ['class_name', 'grade']
