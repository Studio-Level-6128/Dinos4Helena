"""Wire-level tests using only the Python standard library."""

import asyncio
import base64
import json
import os
import struct
import unittest

from server import GameServer


async def connect(port, dino):
    reader, writer = await asyncio.open_connection("127.0.0.1", port)
    key = base64.b64encode(os.urandom(16)).decode()
    writer.write((
        f"GET / HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nUpgrade: websocket\r\n"
        f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\n"
        "Sec-WebSocket-Version: 13\r\n\r\n"
    ).encode())
    await writer.drain()
    assert b"101 Switching Protocols" in await reader.readuntil(b"\r\n\r\n")
    await send(writer, {"type": "hello", "dino": dino})
    return reader, writer, await receive(reader)


async def send(writer, message):
    payload = json.dumps(message).encode()
    mask = os.urandom(4)
    header = bytes((0x81, 0x80 | len(payload))) if len(payload) < 126 else bytes((0x81, 0xFE)) + struct.pack("!H", len(payload))
    writer.write(header + mask + bytes(value ^ mask[index % 4] for index, value in enumerate(payload)))
    await writer.drain()


async def receive(reader):
    head = await asyncio.wait_for(reader.readexactly(2), 2)
    size = head[1] & 0x7F
    if size == 126:
        size = struct.unpack("!H", await reader.readexactly(2))[0]
    elif size == 127:
        size = struct.unpack("!Q", await reader.readexactly(8))[0]
    return json.loads(await reader.readexactly(size))


class ServerTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.game = GameServer(seed=654321)
        self.server = await asyncio.start_server(self.game.handle, "127.0.0.1", 0)
        self.port = self.server.sockets[0].getsockname()[1]
        self.writers = []

    async def asyncTearDown(self):
        for writer in self.writers:
            writer.close()
            await writer.wait_closed()
        self.server.close()
        await self.server.wait_closed()

    async def join(self, dino):
        reader, writer, welcome = await connect(self.port, dino)
        self.writers.append(writer)
        return reader, writer, welcome

    async def test_roster_movement_and_attack(self):
        first_reader, first_writer, first = await self.join("trex")
        self.assertEqual((first["type"], first["seed"], first["map"]), ("welcome", 654321, "grassland"))
        second_reader, second_writer, second = await self.join("triceratops")
        self.assertEqual(second["players"][0]["id"], first["id"])
        self.assertEqual((await receive(first_reader))["type"], "joined")
        # Move both players near each other and put the T-Rex facing its target.
        self.game.players[first["id"]].x = 0
        self.game.players[first["id"]].z = 0
        self.game.players[second["id"]].x = 0
        self.game.players[second["id"]].z = -3
        await send(first_writer, {"type": "state", "x": 0.5, "y": 0.1, "z": 0, "yaw": 0, "animation": "walk"})
        await send(second_writer, {"type": "state", "x": 0.5, "y": 0.1, "z": -3, "yaw": 0, "animation": "idle"})
        self.assertEqual((await receive(second_reader))["type"], "state")
        self.assertEqual((await receive(first_reader))["type"], "state")
        await send(first_writer, {"type": "attack"})
        hit = await receive(second_reader)
        self.assertEqual(hit["type"], "hit")
        self.assertEqual(hit["target"], second["id"])
        self.assertLess(hit["health"], second["spawn"]["health"])
        await receive(first_reader)
        second_writer.close()
        await second_writer.wait_closed()
        self.assertEqual((await receive(first_reader))["type"], "left")

    async def test_cap_rejects_eleventh_player(self):
        for _ in range(10):
            _, _, response = await self.join("triceratops")
            self.assertEqual(response["type"], "welcome")
        _, writer, response = await self.join("trex")
        self.assertEqual(response, {"type": "rejected", "reason": "full"})
        writer.close()
        self.assertEqual(len(self.game.players), 10)


if __name__ == "__main__":
    unittest.main()
