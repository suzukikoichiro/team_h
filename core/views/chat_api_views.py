# views.py
import json
from channels.generic.websocket import WebsocketConsumer
from asgiref.sync import async_to_sync

class ChatConsumer(WebsocketConsumer):
    def connect(self):
        self.room_group_name = "global_chat"  # 全員が同じルームに参加
        # グループに追加
        async_to_sync(self.channel_layer.group_add)(
            self.room_group_name,
            self.channel_name
        )
        self.accept()
        print(f"WebSocket 接続成功: {self.channel_name}")

    def disconnect(self, close_code):
        # グループから削除
        async_to_sync(self.channel_layer.group_discard)(
            self.room_group_name,
            self.channel_name
        )
        print(f"WebSocket 切断: {self.channel_name}")

    def receive(self, text_data):
        data = json.loads(text_data)
        message = data.get("message", "")
        sender = data.get("sender", "名無し")

        # グループ内の全員に送信
        async_to_sync(self.channel_layer.group_send)(
            self.room_group_name,
            {
                "type": "chat_message",
                "message": message,
                "sender": sender
            }
        )

    # グループからメッセージを受け取ったらクライアントに送信
    def chat_message(self, event):
        message = event["message"]
        sender = event.get("sender", "名無し")
        self.send(text_data=json.dumps({
            "message": message,
            "sender": sender
        }))
