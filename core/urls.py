from django.urls import path
from . import views

urlpatterns = [
    path('', views.school_login, name='school_login'),
    path('home', views.home, name='home'),
    path('test', views.test, name='test'),
    path('godot', views.godot, name='godot'),

    path('school/register/', views.school_register, name='school_register'),
    path('school/login/', views.school_login, name='school_login'),
    path('school/logout/', views.school_logout, name='school_logout'),
    
    path('user/login/', views.user_login, name='user_login'),
    path('user/logout/', views.user_logout, name='user_logout'),

    path('class/create/', views.class_create, name='class_create'),
    path('class/list/', views.class_list, name='class_list'),
    path('classes/<int:class_id>/edit/', views.class_edit, name='class_edit'),
    path('classes/<int:class_id>/delete/', views.class_delete, name='class_delete'),

    path('teacher/register/', views.teacher_register, name='teacher_register'),
    path('teacher/list/', views.teacher_list, name='teacher_list'),
    path('teachers/<int:teacher_id>/edit/', views.teacher_edit, name='teacher_edit'),
    path('teachers/<int:teacher_id>/delete/', views.teacher_delete, name='teacher_delete'),

    path('student/list/', views.student_list, name='student_list'), 
    path("api/receive_form/", views.receive_form, name="receive_form"),
    path("api/get_classes/", views.get_classes, name="get_classes"),
]