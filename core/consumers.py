import asyncio
from channels.generic.websocket import AsyncWebsocketConsumer
import json

CHAT_HISTORY = {}
MAX_HISTORY = 50
WORLD_STATE = {}  

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


class WorldConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        print("WORLD CONNECT TRY",
            "path_school=", self.scope["url_route"]["kwargs"]["school_id"],
            "user=", self.scope.get("user"))

        self.school_id = int(self.scope["url_route"]["kwargs"]["school_id"])
        self.group_name = f"world_{self.school_id}"

        # ★ これを必ず入れる
        self.user = self.scope.get("user")

        await self.channel_layer.group_add(
            self.group_name,
            self.channel_name
        )
        await self.accept()

        self.heartbeat_task = asyncio.create_task(self.send_heartbeat())




    async def disconnect(self, close_code):
        uid = self.user.id if self.user and self.user.is_authenticated else None
        print(f"WORLD DISCONNECT user={uid} code={close_code}")

        await self.channel_layer.group_discard(
            self.group_name,
            self.channel_name
        )

        if uid is not None:
            await self.channel_layer.group_send(
                self.group_name,
                {
                    "type": "player_leave",
                    "user_id": uid,
                }
            )

        if hasattr(self, "heartbeat_task"):
            self.heartbeat_task.cancel()


    async def send_heartbeat(self):
        try:
            while True:
                await asyncio.sleep(10)  # 10秒ごとに ping
                await self.send(text_data=json.dumps({"type": "ping"}))
        except asyncio.CancelledError:
            return

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
        except Exception as e:
            print("WS JSON ERROR:", e, text_data)
            return

        msg_type = data.get("type")
        print("WS RECEIVE:", data)

        if msg_type == "ping":
            return

        if msg_type == "move":
            user_id = data.get("user_id")
            x = data.get("x")
            y = data.get("y")
            flip = data.get("flip", False)

            if user_id is None or x is None or y is None:
                print("INVALID MOVE PACKET:", data)
                return

            room = WORLD_STATE.setdefault(self.school_id, {})
            player = room.setdefault(user_id, {"x": 0, "y": 0, "flip": False})

            player["x"] = x
            player["y"] = y
            player["flip"] = flip

            await self.channel_layer.group_send(
                self.group_name,
                {
                    "type": "player_move",
                    "user_id": user_id,
                    "x": x,
                    "y": y,
                    "flip": flip,
                }
            )



    async def player_join(self, event):
        if event.get("sender") == self.channel_name:
            return
        await self.send(text_data=json.dumps({
            "type": "join",
            "user_id": event["user_id"],
            "data": event["data"],
        }))

    async def player_leave(self, event):
        await self.send(text_data=json.dumps({
            "type": "leave",
            "user_id": event["user_id"],
        }))

    async def player_move(self, event):
        await self.send(text_data=json.dumps({
            "type": "move",
            "user_id": event["user_id"],
            "x": event["x"],
            "y": event["y"],
            "flip": event.get("flip", False),
        }))




