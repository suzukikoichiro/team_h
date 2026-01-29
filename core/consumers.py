from channels.generic.websocket import AsyncWebsocketConsumer
import json

CHAT_HISTORY = {}      # room_name -> [message]
MAX_HISTORY = 50

class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.room_name = self.scope["url_route"]["kwargs"]["room_name"]
        self.room_group_name = f"chat_{self.room_name}"

        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )

        await self.accept()

        history = CHAT_HISTORY.setdefault(self.room_name, [])

        await self.send(text_data=json.dumps({
            "type": "history",
            "data": history
        }))

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )

    async def receive(self, text_data):
        data = json.loads(text_data)
        msg_type = data.get("type")

        if msg_type == "message":
            message_data = data.get("data", {})
            message_data["user_id"] = self.scope.get("user", {}).id if self.scope.get("user") and self.scope["user"].is_authenticated else message_data.get("user_id", -1)
            message_data["user_name"] = self.scope.get("user", {}).username if self.scope.get("user") and self.scope["user"].is_authenticated else message_data.get("user_name", "ゲスト")

            CHAT_HISTORY.setdefault(self.room_name, []).append(message_data)


            if len(CHAT_HISTORY[self.room_name]) > MAX_HISTORY:
                CHAT_HISTORY[self.room_name].pop(0)

            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    "type": "chat_message",
                    "data": message_data,
                }
            )

        elif msg_type == "delete":
            msg_id = data.get("id", "")

            if self.room_name in CHAT_HISTORY:
                CHAT_HISTORY[self.room_name] = [
                    m for m in CHAT_HISTORY[self.room_name]
                    if m.get("id") != msg_id
                ]

            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    "type": "chat_delete",
                    "id": msg_id,
                }
            )



    async def chat_message(self, event):
        await self.send(text_data=json.dumps({
            "type": "message",
            "data": event["data"],
        }))

    async def chat_delete(self, event):
        await self.send(text_data=json.dumps({
            "type": "delete",
            "id": event["id"],
        }))
