"""Wire-level tests using only the Python standard library."""

import asyncio
import base64
import json
import math
import os
import shutil
import ssl
import struct
import tempfile
import time
import unittest
from pathlib import Path

from check_server import CheckError, check_server, parse_url
from server import GameServer, SPECIES, ensure_tls_certificates


async def connect(port, dino, name=None, color=None):
    reader, writer = await asyncio.open_connection("127.0.0.1", port)
    key = base64.b64encode(os.urandom(16)).decode()
    writer.write((
        f"GET / HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nUpgrade: websocket\r\n"
        f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\n"
        "Sec-WebSocket-Version: 13\r\n\r\n"
    ).encode())
    await writer.drain()
    assert b"101 Switching Protocols" in await reader.readuntil(b"\r\n\r\n")
    hello = {"type": "hello", "dino": dino}
    if name is not None:
        hello["name"] = name
    if color is not None:
        hello["color"] = color
    await send(writer, hello)
    return reader, writer, await receive(reader)


async def lobby(port):
    reader, writer = await asyncio.open_connection("127.0.0.1", port)
    key = base64.b64encode(os.urandom(16)).decode()
    writer.write((
        f"GET / HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nUpgrade: websocket\r\n"
        f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\n"
        "Sec-WebSocket-Version: 13\r\n\r\n"
    ).encode())
    await writer.drain()
    assert b"101 Switching Protocols" in await reader.readuntil(b"\r\n\r\n")
    return reader, writer


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

    async def join(self, dino, name=None, color=None):
        reader, writer, welcome = await connect(self.port, dino, name, color)
        self.writers.append(writer)
        return reader, writer, welcome

    async def test_roster_movement_and_attack(self):
        first_reader, first_writer, first = await self.join("trex", "Helena", "#f47ac2")
        self.assertEqual((first["type"], first["seed"], first["map"]), ("welcome", 654321, "grassland"))
        self.assertEqual((first["spawn"]["name"], first["spawn"]["color"]), ("Helena", "#f47ac2"))
        second_reader, second_writer, second = await self.join("triceratops", "Dad", "#4ecdc4")
        self.assertEqual(second["players"][0]["id"], first["id"])
        self.assertEqual((second["players"][0]["name"], second["players"][0]["color"]), ("Helena", "#f47ac2"))
        joined = await receive(first_reader)
        self.assertEqual((joined["type"], joined["player"]["name"], joined["player"]["color"]),
                         ("joined", "Dad", "#4ecdc4"))
        # Move both players near each other and put the T-Rex facing its target.
        self.game.players[first["id"]].x = 0
        self.game.players[first["id"]].z = 0
        self.game.players[second["id"]].x = 0
        self.game.players[second["id"]].z = -3
        await send(first_writer, {"type": "state", "x": 0.5, "y": 0.1, "z": 0, "yaw": 0, "animation": "walk"})
        await send(second_writer, {"type": "state", "x": 0.5, "y": 0.1, "z": -3, "yaw": 0, "animation": "idle"})
        state = await receive(second_reader)
        self.assertEqual((state["type"], state["player"]["name"], state["player"]["color"]),
                         ("state", "Helena", "#f47ac2"))
        self.assertEqual((await receive(first_reader))["type"], "state")
        await send(first_writer, {"type": "scream"})
        scream = await receive(second_reader)
        self.assertEqual((scream["type"], scream["id"]), ("scream", first["id"]))
        await send(first_writer, {"type": "attack"})
        hit = await receive(second_reader)
        self.assertEqual(hit["type"], "hit")
        self.assertEqual(hit["target"], second["id"])
        self.assertLess(hit["health"], second["spawn"]["health"])
        await receive(first_reader)
        second_writer.close()
        await second_writer.wait_closed()
        self.assertEqual((await receive(first_reader))["type"], "left")

    async def test_death_leaves_meat_and_respawns_elsewhere(self):
        first_reader, first_writer, first = await self.join("trex")
        second_reader, _, second = await self.join("triceratops")
        await receive(first_reader)  # joined
        attacker = self.game.players[first["id"]]
        target = self.game.players[second["id"]]
        attacker.x, attacker.z, attacker.yaw = 0.0, 0.0, 0.0
        target.x, target.z, target.health = 0.0, -3.0, 1
        self.game.respawn_delay = 0.05
        await send(first_writer, {"type": "attack"})
        hit = await receive(second_reader)
        death = await receive(second_reader)
        self.assertEqual((hit["type"], death["type"], death["id"]),
                         ("hit", "death", second["id"]))
        self.assertEqual((death["x"], death["z"], death["respawn_delay"]),
                         (0.0, -3.0, 0.05))
        await receive(first_reader)  # hit
        await receive(first_reader)  # death
        respawn = await receive(second_reader)
        self.assertEqual(respawn["type"], "respawn")
        self.assertEqual(respawn["player"]["health"], SPECIES["triceratops"][0])
        self.assertGreater(math.dist((death["x"], death["z"]),
                                     (respawn["player"]["x"], respawn["player"]["z"])), 65.0)

    async def test_strength_powerup_doubles_server_damage(self):
        first_reader, first_writer, first = await self.join("trex")
        second_reader, _, second = await self.join("triceratops")
        await receive(first_reader)  # joined
        attacker = self.game.players[first["id"]]
        target = self.game.players[second["id"]]
        attacker.x, attacker.z, attacker.yaw = 0.0, 0.0, 0.0
        target.x, target.z = 0.0, -3.0
        await send(first_writer, {"type": "powerup", "token": "strength"})
        await send(first_writer, {"type": "attack"})
        hit = await receive(second_reader)
        self.assertEqual(hit["health"], target.health)
        self.assertEqual(hit["health"], 180 - 15 * 3 * 2)
        self.assertGreater(attacker.strength_bonus_until, time.monotonic())

    async def test_cap_rejects_eleventh_player(self):
        for _ in range(10):
            _, _, response = await self.join("triceratops")
            self.assertEqual(response["type"], "welcome")
        _, writer, response = await self.join("trex")
        self.assertEqual(response, {"type": "rejected", "reason": "full"})
        writer.close()
        self.assertEqual(len(self.game.players), 10)

    async def test_invalid_identity_is_rejected(self):
        for name, color in (("", "#6ea8fe"), ("A" * 21, "#6ea8fe"),
                            ("Bad\nName", "#6ea8fe"), ("Valid", "#000000")):
            _, writer, response = await self.join("trex", name, color)
            self.assertEqual(response, {"type": "rejected", "reason": "invalid_identity"})
            writer.close()
            await writer.wait_closed()
        _, _, response = await self.join("trex")
        self.assertTrue(response["spawn"]["name"].startswith("Player "))
        self.assertEqual(response["spawn"]["color"], "#6ea8fe")


class SessionTests(unittest.IsolatedAsyncioTestCase):
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

    async def connect(self):
        reader, writer = await lobby(self.port)
        self.writers.append(writer)
        return reader, writer

    async def test_list_join_and_session_isolation(self):
        first_reader, first_writer = await self.connect()
        await send(first_writer, {"type": "list"})
        self.assertEqual((await receive(first_reader))["sessions"], [])
        await send(first_writer, {"type": "create", "map": "desert", "dino": "trex",
                                  "name": "Hunter", "color": "#6ea8fe"})
        first = await receive(first_reader)
        self.assertEqual((first["map"], first["type"]), ("desert", "welcome"))
        second_reader, second_writer = await self.connect()
        await send(second_writer, {"type": "list"})
        sessions = (await receive(second_reader))["sessions"]
        self.assertEqual((sessions[0]["id"], sessions[0]["map"], sessions[0]["players"]),
                         (first["session"], "desert", 1))
        await send(second_writer, {"type": "join", "session": first["session"],
                                   "dino": "triceratops", "name": "Friend", "color": "#f47ac2"})
        second = await receive(second_reader)
        self.assertEqual((second["seed"], second["host"]), (first["seed"], first["id"]))
        self.assertEqual((await receive(first_reader))["type"], "joined")
        third_reader, third_writer = await self.connect()
        await send(third_writer, {"type": "create", "map": "winter", "dino": "apatosaurus",
                                  "name": "Other", "color": "#7bd389"})
        third = await receive(third_reader)
        self.assertNotEqual(third["session"], first["session"])
        self.assertEqual(third["map"], "winter")
        await send(third_writer, {"type": "state", "x": third["spawn"]["x"],
                                  "y": 0.1, "z": third["spawn"]["z"], "yaw": 0})
        with self.assertRaises(asyncio.TimeoutError):
            await asyncio.wait_for(receive(first_reader), 0.1)
        await send(first_writer, {"type": "npcs", "npcs": [{"id": 0, "dino": "trex",
            "x": 0, "y": 0.1, "z": 0, "yaw": 0, "health": 150, "dead": False}]})
        self.assertEqual((await receive(second_reader))["type"], "npcs")
        self.assertEqual(self.game.sessions[first["session"]].npcs[0]["dino"], "trex")
        self.assertEqual(self.game.sessions[third["session"]].npcs, [])
        await send(second_writer, {"type": "npcs", "npcs": []})
        await asyncio.sleep(0.05)
        self.assertEqual(len(self.game.sessions[first["session"]].npcs), 1)
        first_writer.close()
        await first_writer.wait_closed()
        host = await receive(second_reader)
        self.assertEqual(host["type"], "left")
        host = await receive(second_reader)
        self.assertEqual((host["type"], host["host"]), ("ai_host", second["id"]))


class CertificateTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required for automatic certificates")
    def test_self_signed_pair_is_created_and_reused(self):
        with tempfile.TemporaryDirectory() as directory:
            certificate, key = ensure_tls_certificates(Path(directory) / "certs", "127.0.0.1")
            self.assertTrue(certificate.is_file() and key.is_file())
            self.assertEqual(key.stat().st_mode & 0o777, 0o600)
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(certificate, key)
            original = (certificate.read_bytes(), key.read_bytes())
            self.assertEqual((certificate, key), ensure_tls_certificates(Path(directory) / "certs", "127.0.0.1"))
            self.assertEqual(original, (certificate.read_bytes(), key.read_bytes()))


class SetupCheckerTests(unittest.IsolatedAsyncioTestCase):
    async def test_plain_server_join_and_full_world(self):
        game = GameServer(seed=654321, limit=1)
        server = await asyncio.start_server(game.handle, "127.0.0.1", 0)
        port = server.sockets[0].getsockname()[1]
        try:
            result = await check_server(f"ws://127.0.0.1:{port}/", "triceratops")
            self.assertEqual((result["map"], result["seed"], result["spawn"]["dino"]),
                             ("grassland", 654321, "triceratops"))
            full_game = GameServer(limit=0)
            full_server = await asyncio.start_server(full_game.handle, "127.0.0.1", 0)
            try:
                full_port = full_server.sockets[0].getsockname()[1]
                with self.assertRaisesRegex(CheckError, "full"):
                    await check_server(f"ws://127.0.0.1:{full_port}/", "trex")
            finally:
                full_server.close()
                await full_server.wait_closed()
        finally:
            server.close()
            await server.wait_closed()

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required for automatic certificates")
    async def test_self_signed_requires_opt_in_or_trusted_certificate(self):
        with tempfile.TemporaryDirectory() as directory:
            certificate, key = ensure_tls_certificates(Path(directory) / "certs", "127.0.0.1")
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(certificate, key)
            server = await asyncio.start_server(GameServer().handle, "127.0.0.1", 0, ssl=context)
            port = server.sockets[0].getsockname()[1]
            url = f"wss://127.0.0.1:{port}/"
            try:
                # The server side can log an expected reset when verification fails.
                loop = asyncio.get_running_loop()
                previous_handler = loop.get_exception_handler()
                loop.set_exception_handler(lambda _loop, _context: None)
                try:
                    with self.assertRaisesRegex(CheckError, "certificate verification failed"):
                        await check_server(url, "trex")
                    await asyncio.sleep(0)
                finally:
                    loop.set_exception_handler(previous_handler)
                self.assertEqual((await check_server(url, "trex", allow_self_signed=True))["type"], "welcome")
                self.assertEqual((await check_server(url, "trex", ca_cert=str(certificate)))["type"], "welcome")
            finally:
                server.close()
                await server.wait_closed()

    def test_invalid_url_and_tls_options(self):
        with self.assertRaisesRegex(CheckError, "Port"):
            parse_url("ws://127.0.0.1:0/")
        with self.assertRaisesRegex(CheckError, "URL"):
            parse_url("https://127.0.0.1/")


if __name__ == "__main__":
    unittest.main()
