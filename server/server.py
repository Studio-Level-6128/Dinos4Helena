#!/usr/bin/env python3
"""Standalone asyncio WebSocket server for Dinos4Helena multiplayer sessions.

Uses the Python standard library at runtime and OpenSSL to create a TLS
certificate on first launch. See README.md for protocol and hosting.
"""

from __future__ import annotations

import argparse
import asyncio
import base64
import binascii
import hashlib
import ipaddress
import json
import math
import os
import secrets
import shutil
import ssl
import struct
import subprocess
import tempfile
import time
from dataclasses import dataclass, field
from pathlib import Path


SPECIES = {
    "trex": (150, 8.0, 15), "spinosaurus": (200, 8.2, 20),
    "triceratops": (180, 6.0, 8), "stegosaurus": (200, 4.8, 8),
    "velociraptor": (80, 9.0, 10), "parasaurolophus": (125, 7.0, 6),
    "apatosaurus": (300, 4.5, 10),
}
MAX_PLAYERS = 10
MAX_MESSAGE_BYTES = 32768
MAX_SESSIONS = 16
MAP_THEMES = frozenset(("grassland", "desert", "winter", "volcano"))
PLAYER_COLORS = frozenset((
    "#ff6b6b", "#ffd166", "#7bd389", "#4ecdc4",
    "#6ea8fe", "#c792ea", "#ff9f68", "#f47ac2",
))
DEFAULT_PLAYER_COLOR = "#6ea8fe"
WORLD_LIMIT = 194.0
NPC_WORLD_LIMIT = 210.0
RESPAWN_DELAY_SECONDS = 5.0
GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
DEFAULT_CERT_DIR = Path(__file__).resolve().parent / "certs"


class ProtocolError(Exception):
    pass


def ensure_tls_certificates(cert_dir: Path, certificate_host: str = "localhost") -> tuple[Path, Path]:
    """Create a persistent self-signed keypair on first run; never overwrite it."""
    cert_dir = Path(cert_dir)
    certificate = cert_dir / "server.crt"
    key = cert_dir / "server.key"
    if certificate.exists() != key.exists():
        raise ValueError(f"Incomplete TLS keypair in {cert_dir}; restore the missing file")
    if certificate.exists():
        return certificate, key
    if not certificate_host or any(char not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-:" for char in certificate_host):
        raise ValueError("--cert-host must be an IP address or DNS name")
    try:
        ipaddress.ip_address(certificate_host)
        subject_name = f"IP:{certificate_host}"
    except ValueError:
        if ":" in certificate_host:
            raise ValueError("--cert-host must be an IP address or DNS name") from None
        subject_name = f"DNS:{certificate_host}"
    openssl = shutil.which("openssl")
    if openssl is None:
        raise RuntimeError("OpenSSL is required once to generate a self-signed certificate; install it or pass --cert and --key")
    cert_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    # Temporary files prevent a failed OpenSSL run from leaving a partial pair.
    with tempfile.TemporaryDirectory(dir=cert_dir) as temporary:
        temp_cert = Path(temporary) / "server.crt"
        temp_key = Path(temporary) / "server.key"
        subprocess.run([
            openssl, "req", "-x509", "-newkey", "rsa:3072", "-sha256",
            "-nodes", "-days", "365", "-keyout", str(temp_key),
            "-out", str(temp_cert), "-subj", f"/CN={certificate_host}",
            "-addext", f"subjectAltName=DNS:localhost,IP:127.0.0.1,{subject_name}",
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        os.chmod(temp_key, 0o600)
        os.chmod(temp_cert, 0o644)
        temp_key.replace(key)
        temp_cert.replace(certificate)
    print(f"Created self-signed TLS certificate: {certificate}", flush=True)
    return certificate, key


async def read_frame(reader: asyncio.StreamReader) -> tuple[int, bytes]:
    head = await reader.readexactly(2)
    opcode = head[0] & 0x0F
    if not head[0] & 0x80 or not head[1] & 0x80:
        raise ProtocolError("Only complete masked client frames are supported")
    size = head[1] & 0x7F
    if size == 126:
        size = struct.unpack("!H", await reader.readexactly(2))[0]
    elif size == 127:
        size = struct.unpack("!Q", await reader.readexactly(8))[0]
    if size > MAX_MESSAGE_BYTES:
        raise ProtocolError("Message is too large")
    mask = await reader.readexactly(4)
    payload = await reader.readexactly(size)
    return opcode, bytes(value ^ mask[index % 4] for index, value in enumerate(payload))


def make_frame(payload: bytes, opcode: int = 1) -> bytes:
    size = len(payload)
    if size < 126:
        header = bytes((0x80 | opcode, size))
    elif size < 65536:
        header = bytes((0x80 | opcode, 126)) + struct.pack("!H", size)
    else:
        header = bytes((0x80 | opcode, 127)) + struct.pack("!Q", size)
    return header + payload


@dataclass
class Player:
    identifier: int
    writer: asyncio.StreamWriter
    dino: str
    name: str
    color: str
    session_id: int
    x: float
    y: float
    z: float
    yaw: float = 0.0
    animation: str = "idle"
    health: int = 100
    last_state: float = field(default_factory=time.monotonic)
    last_attack: float = 0.0
    last_npc_attack: float = 0.0
    speed_bonus_until: float = 0.0
    strength_bonus_until: float = 0.0
    death_count: int = 0
    respawning: bool = False
    respawn_task: asyncio.Task | None = field(default=None, repr=False)

    def public(self) -> dict:
        return {
            "id": self.identifier, "dino": self.dino,
            "name": self.name, "color": self.color,
            "x": round(self.x, 3), "y": round(self.y, 3), "z": round(self.z, 3),
            "yaw": round(self.yaw, 4), "animation": self.animation,
            "health": self.health,
        }


@dataclass
class Session:
    identifier: int
    name: str
    map_theme: str
    seed: int
    players: dict[int, Player] = field(default_factory=dict)
    host_id: int = 0
    npcs: list[dict] = field(default_factory=list)

    def public(self, limit: int) -> dict:
        return {"id": self.identifier, "name": self.name, "map": self.map_theme,
                "players": len(self.players), "limit": limit}


class GameServer:
    def __init__(self, seed: int = 424242, limit: int = MAX_PLAYERS):
        self.seed = seed
        self.limit = limit
        self.players: dict[int, Player] = {}
        self.sessions: dict[int, Session] = {}
        self.next_session_id = 1
        self.legacy_session_id = 0
        self.respawn_delay = RESPAWN_DELAY_SECONDS
        self.lock = asyncio.Lock()

    async def send(self, writer: asyncio.StreamWriter, message: dict) -> None:
        writer.write(make_frame(json.dumps(message, separators=(",", ":")).encode()))
        await writer.drain()

    async def broadcast(self, session: Session, message: dict, exclude: int | None = None) -> None:
        data = make_frame(json.dumps(message, separators=(",", ":")).encode())
        for player in tuple(session.players.values()):
            if player.identifier != exclude and not player.writer.is_closing():
                player.writer.write(data)
        await asyncio.gather(
            *(player.writer.drain() for player in tuple(session.players.values())
              if player.identifier != exclude and not player.writer.is_closing()),
            return_exceptions=True,
        )

    def session_list(self) -> list[dict]:
        return [session.public(self.limit) for session in self.sessions.values()]

    def create_session(self, name: str, map_theme: str, legacy: bool = False) -> Session:
        identifier = self.next_session_id
        self.next_session_id += 1
        seed = self.seed if legacy else secrets.randbelow(900000) + 100000
        session = Session(identifier, name, map_theme, seed)
        self.sessions[identifier] = session
        if legacy:
            self.legacy_session_id = identifier
        return session

    def spawn(self, slot: int) -> tuple[float, float, float]:
        angle = slot * math.tau / self.limit
        return round(math.cos(angle) * 12, 3), 0.1, round(math.sin(angle) * 12, 3)

    def respawn_position(self, session: Session, player: Player) -> tuple[float, float, float]:
        previous = (player.x, player.z)
        for _ in range(40):
            angle = secrets.randbelow(3600) * math.tau / 3600.0
            radius = 72.0 + secrets.randbelow(9800) / 100.0
            candidate = (math.cos(angle) * radius, math.sin(angle) * radius)
            if math.dist(previous, candidate) < 65.0:
                continue
            if any(member.identifier != player.identifier
                   and math.dist((member.x, member.z), candidate) < 18.0
                   for member in session.players.values()):
                continue
            return round(candidate[0], 3), 0.1, round(candidate[1], 3)
        # A half-turn is always a meaningfully different in-bounds fallback.
        if math.hypot(player.x, player.z) < 32.0:
            return 150.0, 0.1, 0.0
        return round(-player.x, 3), 0.1, round(-player.z, 3)

    async def handshake(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        request = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), 5)
        if len(request) > 8192:
            raise ProtocolError("HTTP request is too large")
        lines = request.decode("latin-1").split("\r\n")
        if lines[0] != "GET / HTTP/1.1":
            raise ProtocolError("Expected a WebSocket GET on /")
        headers = {}
        for line in lines[1:]:
            if ":" in line:
                key, value = line.split(":", 1)
                headers[key.lower()] = value.strip()
        key = headers.get("sec-websocket-key", "")
        if (headers.get("upgrade", "").lower() != "websocket"
                or "upgrade" not in headers.get("connection", "").lower()
                or len(base64.b64decode(key, validate=True)) != 16):
            raise ProtocolError("Invalid WebSocket upgrade")
        accept = base64.b64encode(hashlib.sha1((key + GUID).encode()).digest()).decode()
        writer.write((
            "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n"
            f"Connection: Upgrade\r\nSec-WebSocket-Accept: {accept}\r\n\r\n"
        ).encode())
        await writer.drain()

    async def handle(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        player: Player | None = None
        session: Session | None = None
        try:
            await self.handshake(reader, writer)
            while player is None:
                opcode, payload = await asyncio.wait_for(read_frame(reader), 60)
                if opcode == 8:
                    return
                if opcode != 1:
                    raise ProtocolError("Expected a lobby request")
                request = json.loads(payload)
                if not isinstance(request, dict):
                    continue
                kind = request.get("type")
                if kind == "list":
                    await self.send(writer, {"type": "sessions", "sessions": self.session_list()})
                    continue
                if kind not in ("hello", "create", "join"):
                    await self.send(writer, {"type": "rejected", "reason": "invalid_request"})
                    continue
                if not isinstance(request.get("dino"), str) or request["dino"] not in SPECIES:
                    await self.send(writer, {"type": "rejected", "reason": "invalid_dinosaur"})
                    continue
                raw_name = request.get("name")
                name = raw_name.strip() if isinstance(raw_name, str) else None
                color = request.get("color", DEFAULT_PLAYER_COLOR)
                if ((raw_name is not None and (not name or len(name) > 20 or not name.isprintable()))
                        or not isinstance(color, str) or color not in PLAYER_COLORS):
                    await self.send(writer, {"type": "rejected", "reason": "invalid_identity"})
                    continue
                if kind == "create" and request.get("map") not in MAP_THEMES:
                    await self.send(writer, {"type": "rejected", "reason": "invalid_map"})
                    continue
                async with self.lock:
                    if kind == "create":
                        if len(self.sessions) >= MAX_SESSIONS:
                            await self.send(writer, {"type": "rejected", "reason": "sessions_full"})
                            continue
                        session = self.create_session(f"{name or 'Player'}'s {request['map'].title()}", request["map"])
                    elif kind == "hello":
                        session = self.sessions.get(self.legacy_session_id)
                        if session is None:
                            if len(self.sessions) >= MAX_SESSIONS:
                                await self.send(writer, {"type": "rejected", "reason": "sessions_full"})
                                continue
                            session = self.create_session("Grassland", "grassland", legacy=True)
                    else:
                        session_id = request.get("session")
                        session = self.sessions.get(session_id) if type(session_id) is int else None
                        if session is None:
                            await self.send(writer, {"type": "rejected", "reason": "missing_session"})
                            continue
                    if len(session.players) >= self.limit:
                        await self.send(writer, {"type": "rejected", "reason": "full"})
                        continue
                    occupied = {getattr(member, "slot", -1) for member in session.players.values()}
                    slot = next(index for index in range(self.limit) if index not in occupied)
                    x, y, z = self.spawn(slot)
                    identifier = secrets.randbits(53)
                    while identifier in self.players:
                        identifier = secrets.randbits(53)
                    player = Player(identifier, writer, request["dino"],
                                    name or f"Player {slot + 1}", color, session.identifier, x, y, z,
                                    health=SPECIES[request["dino"]][0])
                    player.slot = slot
                    roster = [member.public() for member in session.players.values()]
                    session.players[identifier] = player
                    self.players[identifier] = player
                    if session.host_id == 0:
                        session.host_id = identifier
                    await self.send(writer, {
                        "type": "welcome", "id": identifier, "session": session.identifier,
                        "seed": session.seed, "map": session.map_theme, "limit": self.limit,
                        "host": session.host_id, "npcs": session.npcs,
                        "spawn": player.public(), "players": roster,
                    })
                    await self.broadcast(session, {"type": "joined", "player": player.public()}, identifier)
            while True:
                opcode, payload = await asyncio.wait_for(read_frame(reader), 30)
                if opcode == 8:
                    break
                if opcode == 9:
                    writer.write(make_frame(payload, 10))
                    await writer.drain()
                    continue
                if opcode != 1:
                    raise ProtocolError("Only text messages are accepted")
                message = json.loads(payload)
                if not isinstance(message, dict):
                    continue
                kind = message.get("type")
                if kind == "state":
                    await self.update_state(session, player, message)
                elif kind == "attack":
                    await self.attack(session, player)
                elif kind == "scream":
                    await self.broadcast(session, {"type": "scream", "id": player.identifier}, player.identifier)
                elif kind == "npcs":
                    await self.update_npcs(session, player, message)
                elif kind == "npc_attack":
                    await self.attack_npc(session, player, message)
                elif kind == "npc_hit":
                    await self.npc_hit(session, player, message)
                elif kind == "health":
                    await self.update_health(session, player, message)
                elif kind == "powerup":
                    await self.apply_powerup(player, message)
        except (asyncio.IncompleteReadError, ConnectionError, TimeoutError):
            pass
        except (ProtocolError, ValueError, UnicodeError, TypeError, binascii.Error) as error:
            print(f"Client rejected: {error}")
        finally:
            if player is not None and session is not None:
                async with self.lock:
                    if player.respawn_task is not None:
                        player.respawn_task.cancel()
                    self.players.pop(player.identifier, None)
                    session.players.pop(player.identifier, None)
                    await self.broadcast(session, {"type": "left", "id": player.identifier})
                    if not session.players:
                        self.sessions.pop(session.identifier, None)
                        if self.legacy_session_id == session.identifier:
                            self.legacy_session_id = 0
                    elif session.host_id == player.identifier:
                        session.host_id = next(iter(session.players))
                        await self.broadcast(session, {"type": "ai_host", "host": session.host_id,
                                                       "npcs": session.npcs})
            writer.close()
            try:
                await writer.wait_closed()
            except ConnectionError:
                pass

    async def update_state(self, session: Session, player: Player, message: dict) -> None:
        if player.health <= 0:
            return
        try:
            x, y, z, yaw = (float(message[key]) for key in ("x", "y", "z", "yaw"))
        except (KeyError, ValueError, TypeError):
            return
        if not all(map(math.isfinite, (x, y, z, yaw))):
            return
        if abs(x) > WORLD_LIMIT or abs(z) > WORLD_LIMIT or y < -5 or y > 35:
            return
        now = time.monotonic()
        elapsed = min(now - player.last_state, 1.0)
        speed_multiplier = 2.0 if player.speed_bonus_until > now else 1.0
        max_distance = SPECIES[player.dino][1] * speed_multiplier * elapsed * 1.7 + 3.0
        if math.dist((x, z), (player.x, player.z)) > max_distance:
            return
        player.x, player.y, player.z, player.yaw = x, y, z, yaw
        player.last_state = now
        animation = message.get("animation", "idle")
        player.animation = animation if animation in ("idle", "walk", "run", "attack", "eat", "scream") else "idle"
        await self.broadcast(session, {"type": "state", "player": player.public()}, player.identifier)

    async def attack(self, session: Session, attacker: Player) -> None:
        now = time.monotonic()
        if now - attacker.last_attack < 1.0 or attacker.health <= 0:
            return
        attacker.last_attack = now
        forward = (-math.sin(attacker.yaw), -math.cos(attacker.yaw))
        target = None
        nearest = 5.0
        for candidate in session.players.values():
            if candidate.identifier == attacker.identifier or candidate.dino == attacker.dino or candidate.health <= 0:
                continue
            dx, dz = candidate.x - attacker.x, candidate.z - attacker.z
            distance = math.hypot(dx, dz)
            if 0.01 < distance < nearest and (forward[0] * dx + forward[1] * dz) / distance > 0.2:
                target, nearest = candidate, distance
        if target is None:
            return
        strength_multiplier = 2 if attacker.strength_bonus_until > now else 1
        target.health = max(0, target.health - SPECIES[attacker.dino][2] * 3 * strength_multiplier)
        await self.broadcast(session, {"type": "hit", "attacker": attacker.identifier,
                              "target": target.identifier, "health": target.health})
        if target.health <= 0:
            await self.player_died(session, target)

    async def update_npcs(self, session: Session, sender: Player, message: dict) -> None:
        if sender.identifier != session.host_id:
            return
        entries = message.get("npcs")
        if not isinstance(entries, list) or len(entries) > 80:
            return
        validated = []
        seen = set()
        for entry in entries:
            if not isinstance(entry, dict) or type(entry.get("id")) is not int:
                return
            npc_id, species = entry["id"], entry.get("dino")
            if npc_id < 0 or npc_id >= 80 or npc_id in seen or species not in SPECIES:
                return
            try:
                x, y, z, yaw = (float(entry[key]) for key in ("x", "y", "z", "yaw"))
                health = int(entry["health"])
            except (KeyError, ValueError, TypeError):
                return
            if (not all(map(math.isfinite, (x, y, z, yaw)))
                    or abs(x) > NPC_WORLD_LIMIT or abs(z) > NPC_WORLD_LIMIT
                    or y < -5 or y > 35 or not 0 <= health <= SPECIES[species][0]):
                return
            animation = entry.get("animation", "idle")
            if animation not in ("idle", "walk", "run", "attack", "eat", "scream", "death"):
                animation = "idle"
            validated.append({"id": npc_id, "dino": species, "x": round(x, 3),
                              "y": round(y, 3), "z": round(z, 3), "yaw": round(yaw, 4),
                              "health": health, "dead": bool(entry.get("dead", False)),
                              "animation": animation})
            seen.add(npc_id)
        session.npcs = validated
        await self.broadcast(session, {"type": "npcs", "npcs": validated}, sender.identifier)

    async def attack_npc(self, session: Session, attacker: Player, message: dict) -> None:
        npc_id = message.get("npc")
        if type(npc_id) is not int or time.monotonic() - attacker.last_npc_attack < 0.7:
            return
        npc = next((entry for entry in session.npcs if entry["id"] == npc_id), None)
        if (npc is None or npc["dead"] or npc["health"] <= 0 or npc["dino"] == attacker.dino
                or math.dist((attacker.x, attacker.z), (npc["x"], npc["z"])) > 6.0):
            return
        attacker.last_npc_attack = time.monotonic()
        host = session.players.get(session.host_id)
        if host is not None and host.identifier != attacker.identifier:
            await self.send(host.writer, {"type": "npc_attack", "player": attacker.identifier,
                                          "npc": npc_id, "damage": SPECIES[attacker.dino][2] * 4})

    async def npc_hit(self, session: Session, sender: Player, message: dict) -> None:
        if sender.identifier != session.host_id:
            return
        target_id, npc_id = message.get("target"), message.get("npc")
        amount = message.get("damage")
        if type(target_id) is not int or type(npc_id) is not int or type(amount) is not int:
            return
        target = session.players.get(target_id)
        npc = next((entry for entry in session.npcs if entry["id"] == npc_id), None)
        if (target is None or npc is None or npc["dead"] or amount < 1
                or amount > SPECIES[npc["dino"]][2] * 3
                or math.dist((target.x, target.z), (npc["x"], npc["z"])) > 7.0):
            return
        target.health = max(0, target.health - amount)
        await self.broadcast(session, {"type": "hit", "attacker": -npc_id - 1,
                                       "target": target_id, "health": target.health})
        if target.health <= 0:
            await self.player_died(session, target)

    async def update_health(self, session: Session, player: Player, message: dict) -> None:
        health = message.get("health")
        if type(health) is not int or not 0 <= health <= SPECIES[player.dino][0]:
            return
        if player.health <= 0 and health > 0:
            return
        player.health = health
        await self.broadcast(session, {"type": "health", "target": player.identifier,
                                       "health": health}, player.identifier)
        if health <= 0:
            await self.player_died(session, player)

    async def apply_powerup(self, player: Player, message: dict) -> None:
        if player.health <= 0:
            return
        token_type = message.get("token")
        now = time.monotonic()
        if token_type == "speed":
            player.speed_bonus_until = now + 30.0
        elif token_type == "strength":
            player.strength_bonus_until = now + 30.0

    async def player_died(self, session: Session, player: Player) -> None:
        if player.respawning:
            return
        player.respawning = True
        player.death_count += 1
        player.animation = "death"
        player.speed_bonus_until = 0.0
        player.strength_bonus_until = 0.0
        await self.broadcast(session, {
            "type": "death", "id": player.identifier, "dino": player.dino,
            "x": round(player.x, 3), "y": round(player.y, 3), "z": round(player.z, 3),
            "death": player.death_count, "respawn_delay": self.respawn_delay,
        })
        player.respawn_task = asyncio.create_task(self.respawn_player(session, player))

    async def respawn_player(self, session: Session, player: Player) -> None:
        try:
            await asyncio.sleep(self.respawn_delay)
            if session.players.get(player.identifier) is not player:
                return
            player.x, player.y, player.z = self.respawn_position(session, player)
            player.yaw = secrets.randbelow(3600) * math.tau / 3600.0
            player.health = SPECIES[player.dino][0]
            player.animation = "idle"
            player.last_state = time.monotonic()
            await self.broadcast(session, {"type": "respawn", "player": player.public()})
        finally:
            player.respawning = False
            player.respawn_task = None


async def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--seed", type=int, default=424242)
    parser.add_argument("--cert", help="TLS certificate for wss://")
    parser.add_argument("--key", help="TLS private key for wss://")
    parser.add_argument("--cert-dir", type=Path, default=DEFAULT_CERT_DIR,
                        help="directory for the automatically generated TLS keypair")
    parser.add_argument("--cert-host", default="localhost",
                        help="IP address or DNS name to include in a new certificate")
    parser.add_argument("--no-tls", action="store_true", help="serve unencrypted ws:// instead of wss://")
    args = parser.parse_args()
    if not 100000 <= args.seed <= 999999:
        parser.error("--seed must be a six-digit world seed")
    if bool(args.cert) != bool(args.key):
        parser.error("--cert and --key must be supplied together")
    if args.no_tls and args.cert:
        parser.error("--no-tls cannot be used with --cert and --key")
    context = None
    if not args.no_tls:
        cert_path, key_path = (Path(args.cert), Path(args.key)) if args.cert else ensure_tls_certificates(args.cert_dir, args.cert_host)
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        context.load_cert_chain(cert_path, key_path)
    game = GameServer(args.seed)
    server = await asyncio.start_server(game.handle, args.host, args.port, ssl=context)
    print(f"Dinos4Helena server listening on {'wss' if context else 'ws'}://{args.host}:{args.port}/; seed {args.seed}; max {MAX_PLAYERS}", flush=True)
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
