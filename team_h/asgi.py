"""
ASGI config for team_h project.
 
It exposes the ASGI callable as a module-level variable named ``application``.
 
For more information on this file, see
https://docs.djangoproject.com/en/5.2/howto/deployment/asgi/
"""
 
import os
from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack
import core.routing  # routing.py のあるアプリ名に合わせる
 
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "team_h.settings")
 
application = ProtocolTypeRouter({
    "http": get_asgi_application(),  # 既存の HTTP ルート
    "websocket": AuthMiddlewareStack(  # WebSocket 用
        URLRouter(
            core.routing.websocket_urlpatterns
        )
    ),
})