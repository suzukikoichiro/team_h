from django import forms
from .models import School, User

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

class UserRegisterForm(forms.ModelForm):
    class Meta:
        model = User
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
            'user_password': 'ユーザーパスワード',
        }

    def save(self, commit=True, school=None):
        user = super().save(commit=False)
        user.user_position = 0
        if school:
            user.school = school
        user.class_id = None
        if commit:
            user.save()
        return user
