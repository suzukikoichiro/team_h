from functools import wraps
from django.shortcuts import redirect
from django.contrib import messages


#管理者認証
def admin_required(view_func):
    @wraps(view_func)
    def wrapper(request, *args, **kwargs):
        if request.session.get('user_position') != 0:
            messages.error(request, 'このページには管理者のみアクセスできます。')
            return redirect('home')
        return view_func(request, *args, **kwargs)
    return wrapper
