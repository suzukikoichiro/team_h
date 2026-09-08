const API_BASE = "http://127.0.0.1:7350";
const WS_BASE = "ws://127.0.0.1:7350/ws";
const SERVER_KEY = "defaultkey";
const ROOM_NAME = "school-1-lobby";
const DM_ROOM_NAME = "school-1-dm-900001-900002";

function basicAuth() {
  return "Basic " + Buffer.from(`${SERVER_KEY}:`).toString("base64");
}

async function authenticate(customId, username) {
  const response = await fetch(
    `${API_BASE}/v2/account/authenticate/custom?create=true&username=${encodeURIComponent(username)}`,
    {
      method: "POST",
      headers: {
        Authorization: basicAuth(),
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        id: customId,
        vars: {
          role: "user",
          school_id: "1",
          user_id: customId,
        },
      }),
    },
  );

  if (!response.ok) {
    throw new Error(`auth failed: ${response.status} ${await response.text()}`);
  }

  return response.json();
}

function openSocket(token) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(`${WS_BASE}?lang=en&status=true&token=${encodeURIComponent(token)}`);
    const timeout = setTimeout(() => reject(new Error("socket open timeout")), 8000);
    socket.addEventListener("open", () => {
      clearTimeout(timeout);
      resolve(socket);
    });
    socket.addEventListener("error", (event) => {
      clearTimeout(timeout);
      reject(new Error(`socket error: ${event.message || "unknown"}`));
    });
  });
}

function waitFor(socket, predicate, label, timeoutMs = 8000) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      socket.removeEventListener("message", onMessage);
      reject(new Error(`${label} timeout`));
    }, timeoutMs);

    function onMessage(event) {
      const packet = JSON.parse(event.data);
      if (predicate(packet)) {
        clearTimeout(timeout);
        socket.removeEventListener("message", onMessage);
        resolve(packet);
      }
    }

    socket.addEventListener("message", onMessage);
  });
}

async function joinRoom(socket, cid, roomName = ROOM_NAME) {
  const waiter = waitFor(socket, (packet) => packet.cid === cid && packet.channel, `join ${cid}`);
  socket.send(JSON.stringify({
    cid,
    channel_join: {
      target: roomName,
      type: 1,
      persistence: false,
      hidden: false,
    },
  }));
  const response = await waiter;
  return response.channel.id;
}

async function main() {
  const suffix = Date.now();
  const [a, b] = await Promise.all([
    authenticate(`codex-a-${suffix}`, `CodexA${suffix}`),
    authenticate(`codex-b-${suffix}`, `CodexB${suffix}`),
  ]);

  const [socketA, socketB] = await Promise.all([
    openSocket(a.token),
    openSocket(b.token),
  ]);

  try {
    const [channelA, channelB] = await Promise.all([
      joinRoom(socketA, "1"),
      joinRoom(socketB, "1"),
    ]);

    if (channelA !== channelB) {
      throw new Error(`different channel ids: ${channelA} / ${channelB}`);
    }

    const expectedText = `hello-from-codex-${suffix}`;
    const receivedByB = waitFor(
      socketB,
      (packet) => {
        if (!packet.channel_message) return false;
        const content = JSON.parse(packet.channel_message.content);
        return content?.data?.message === expectedText;
      },
      "message from A to B",
    );

    socketA.send(JSON.stringify({
      cid: "2",
      channel_message_send: {
        channel_id: channelA,
        content: JSON.stringify({
          event: "chat_message",
          data: {
            id: `codex-${suffix}`,
            user_id: 900001,
            user_name: "CodexA",
            message: expectedText,
            time: Math.floor(Date.now() / 1000),
          },
        }),
      },
    }));

    await receivedByB;
    const [dmChannelA, dmChannelB] = await Promise.all([
      joinRoom(socketA, "4", DM_ROOM_NAME),
      joinRoom(socketB, "4", DM_ROOM_NAME),
    ]);

    if (dmChannelA !== dmChannelB) {
      throw new Error(`different dm channel ids: ${dmChannelA} / ${dmChannelB}`);
    }

    const expectedDmText = `private-from-codex-${suffix}`;
    const dmReceivedByB = waitFor(
      socketB,
      (packet) => {
        if (!packet.channel_message) return false;
        const content = JSON.parse(packet.channel_message.content);
        return content?.data?.message === expectedDmText &&
          content?.data?.chat_room === DM_ROOM_NAME;
      },
      "private message from A to B",
    );

    socketA.send(JSON.stringify({
      cid: "5",
      channel_message_send: {
        channel_id: dmChannelA,
        content: JSON.stringify({
          event: "chat_message",
          data: {
            id: `codex-dm-${suffix}`,
            user_id: 900001,
            user_name: "CodexA",
            message: expectedDmText,
            chat_room: DM_ROOM_NAME,
            time: Math.floor(Date.now() / 1000),
          },
        }),
      },
    }));

    await dmReceivedByB;
    const expectedStampIndex = 2;
    const stampReceivedByB = waitFor(
      socketB,
      (packet) => {
        if (!packet.channel_message) return false;
        const content = JSON.parse(packet.channel_message.content);
        return content?.event === "stamp" &&
          content?.data?.user_id === 900001 &&
          content?.data?.stamp_index === expectedStampIndex;
      },
      "stamp from A to B",
    );

    socketA.send(JSON.stringify({
      cid: "6",
      channel_message_send: {
        channel_id: channelA,
        content: JSON.stringify({
          event: "stamp",
          data: {
            type: "stamp",
            user_id: 900001,
            school_id: "1",
            stamp_index: expectedStampIndex,
          },
        }),
      },
    }));

    await stampReceivedByB;
    const expectedX = 321;
    const expectedY = 123;
    const moveReceivedByB = waitFor(
      socketB,
      (packet) => {
        if (!packet.channel_message) return false;
        const content = JSON.parse(packet.channel_message.content);
        return content?.event === "move" &&
          content?.data?.user_id === 900001 &&
          content?.data?.x === expectedX &&
          content?.data?.y === expectedY;
      },
      "move from A to B",
    );

    socketA.send(JSON.stringify({
      cid: "3",
      channel_message_send: {
        channel_id: channelA,
        content: JSON.stringify({
          event: "move",
          data: {
            type: "move",
            user_id: 900001,
            school_id: "1",
            x: expectedX,
            y: expectedY,
            flip: false,
          },
        }),
      },
    }));

    await moveReceivedByB;
    console.log("Nakama realtime chat/move OK.");
  } finally {
    socketA.close();
    socketB.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
