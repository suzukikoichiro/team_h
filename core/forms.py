from django import forms
from .models import School, User


class SchoolLoginForm(forms.Form):
    school_id = forms.CharField(label="学校ID")
    school_password = forms.CharField(label="パスワード", widget=forms.PasswordInput)

class UserLoginForm(forms.Form):
    user_id = forms.CharField(label="ユーザーID")
    user_password = forms.CharField(label="パスワード", widget=forms.PasswordInput)

class SchoolRegisterForm(forms.ModelForm): #学校新規登録
    class Meta:
        model = School
        fields = ['school_name', 'school_id', 'school_password']
        widgets = {
            'school_password': forms.PasswordInput(),
        }


class UserRegisterForm(forms.ModelForm):# ユーザー新規登録
    class Meta:
        model = User
        fields = ['school', 'user_id', 'user_password', 'user_name']
        widgets = {
            'user_password': forms.PasswordInput(),
        }
