from channels.auth import AuthMiddlewareStack
from channels.routing import ProtocolTypeRouter, URLRouter
from django.urls import re_path
from .consumers import ChatConsumer, WorldConsumer

# 認証付き WebSocket ルーティング
websocket_urlpatterns = [
    re_path(r"ws/chat/(?P<room_name>\w+)/", ChatConsumer.as_asgi()),
    re_path(r"ws/world/(?P<school_id>\w+)/", WorldConsumer.as_asgi()),
]

application = ProtocolTypeRouter({
    "websocket": AuthMiddlewareStack(
        URLRouter(
            websocket_urlpatterns
        )
    ),
})
