from django import forms
from .models import School, User


class SchoolLoginForm(forms.Form):
    school_id = forms.CharField(label="学校ID")
    school_password = forms.CharField(label="パスワード", widget=forms.PasswordInput)

class UserLoginForm(forms.Form):
    user_id = forms.CharField(label="ユーザーID")
    user_password = forms.CharField(label="パスワード", widget=forms.PasswordInput)

class SchoolRegisterForm(forms.ModelForm):
    class Meta:
        model = School
        fields = ['school_id', 'school_name', 'address', 'school_password']
        widgets = {
            'school_password': forms.PasswordInput(),
        }

class UserRegisterForm(forms.ModelForm):
    class Meta:
        model = User
        # ユーザーが入力する部分だけ
        fields = ['user_id', 'user_name', 'user_spell', 'gendar', 'birthdate', 'user_password']
        widgets = {
            'user_password': forms.PasswordInput(),
            'birthdate': forms.DateInput(attrs={'type': 'date'}),
        }

    def save(self, commit=True, school=None):
        user = super().save(commit=False)
        user.user_position = 0
        if school:
            user.school = school  # ForeignKey に合わせる
        user.class_id = None
        if commit:
            user.save()
        return user
