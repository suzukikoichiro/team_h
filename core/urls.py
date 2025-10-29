from django.urls import path
from . import views

urlpatterns = [
    path('', views.school_login, name='school_login'),
    
    # ログイン／ログアウト
    path('school/login/', views.school_login, name='school_login'),
    path('school/logout/', views.school_logout, name='school_logout'),
    path('user/login/', views.user_login, name='user_login'),
    path('user/logout/', views.user_logout, name='user_logout'),

    # 新規登録
    path('school/register/', views.school_register, name='school_register'),
    path('school/register/done/', views.school_register_done, name='school_register_done'),
    
    path('home', views.home, name='home'),
]