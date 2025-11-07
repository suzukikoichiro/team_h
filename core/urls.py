from django.urls import path
from . import views

urlpatterns = [
    path('', views.school_login, name='school_login'),
    
    path('school/login/', views.school_login, name='school_login'),
    path('school/logout/', views.school_logout, name='school_logout'),
    path('user/login/', views.user_login, name='user_login'),
    path('user/logout/', views.user_logout, name='user_logout'),

    path('school/register/', views.school_register, name='school_register'),
    
    path('home', views.home, name='home'),

    path("api/receive_form/", views.receive_form, name="receive_form"),

    path('class/create/', views.class_create, name='class_create'),
    path('class/list/', views.class_list, name='class_list'),

    path('teacher/register/', views.teacher_register, name='teacher_register'),
    path('teacher/done/', views.teacher_register_done, name='teacher_done'),
    path('teacher/list/', views.teacher_list, name='teacher_list'),
]