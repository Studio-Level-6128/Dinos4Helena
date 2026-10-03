#!/usr/bin/env python3
"""Check a running Dinos4Helena server from this machine (Python standard library only)."""

from __future__ import annotations

import argparse
import asyncio
import base64
import hashlib
import json
import os
import ssl
import struct
import sys
from urllib.parse import urlsplit


WEBSOCKET_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
DINOSAURS = (
    "trex", "spinosaurus", "triceratops", "stegosaurus",
    "velociraptor", "parasaurolophus", "apatosaurus",
)


class CheckError(Exception):
    """The remote service did not complete the expected game protocol."""


def parse_url(url: str) -> tuple[str, int, str, bool]:
    try:
        parsed = urlsplit(url)
    except ValueError as error:
        raise CheckError(f"Invalid server URL: {error}") from error
    if (parsed.scheme not in ("ws", "wss") or not parsed.hostname
            or parsed.username or parsed.password or parsed.path not in ("", "/")
            or parsed.query or parsed.fragment):
        raise CheckError("Use a ws:// or wss:// server URL ending in /, without credentials or query")
    try:
        port = parsed.port if parsed.port is not None else (443 if parsed.scheme == "wss" else 80)
    except ValueError as error:
        raise CheckError(f"Invalid port: {error}") from error
    if not 1 <= port <= 65535:
        raise CheckError("Port must be between 1 and 65535")
    host_header = parsed.hostname if ":" not in parsed.hostname else f"[{parsed.hostname}]"
    return parsed.hostname, port, f"{host_header}:{port}", parsed.scheme == "wss"


async def send_text(writer: asyncio.StreamWriter, message: dict) -> None:
    payload = json.dumps(message, separators=(",", ":")).encode("utf-8")
    mask = os.urandom(4)
    if len(payload) < 126:
        header = bytes((0x81, 0x80 | len(payload)))
    elif len(payload) < 65536:
        header = bytes((0x81, 0xFE)) + struct.pack("!H", len(payload))
    else:
        raise CheckError("Outgoing message is too large")
    writer.write(header + mask + bytes(value ^ mask[index % 4] for index, value in enumerate(payload)))
    await writer.drain()


async def receive_text(reader: asyncio.StreamReader) -> dict:
    header = await reader.readexactly(2)
    opcode = header[0] & 0x0F
    if header[0] & 0x80 == 0 or opcode != 1 or header[1] & 0x80:
        raise CheckError("Expected one unmasked WebSocket text frame")
    size = header[1] & 0x7F
    if size == 126:
        size = struct.unpack("!H", await reader.readexactly(2))[0]
    elif size == 127:
        size = struct.unpack("!Q", await reader.readexactly(8))[0]
    if size > 1024 * 1024:
        raise CheckError("Server response is unexpectedly large")
    try:
        message = json.loads((await reader.readexactly(size)).decode("utf-8"))
    except (UnicodeError, json.JSONDecodeError) as error:
        raise CheckError("Server returned invalid JSON") from error
    if not isinstance(message, dict):
        raise CheckError("Server returned a non-object JSON message")
    return message


async def check_server(url: str, dino: str, allow_self_signed: bool = False,
                       ca_cert: str | None = None, timeout: float = 5.0) -> dict:
    host, port, host_header, secure = parse_url(url)
    if allow_self_signed and ca_cert:
        raise CheckError("Choose either --allow-self-signed or --ca-cert, not both")
    if not secure and (allow_self_signed or ca_cert):
        raise CheckError("TLS options require a wss:// URL")

    async def probe() -> dict:
        context = None
        if secure:
            context = ssl.create_default_context(cafile=ca_cert)
            if allow_self_signed:
                context.check_hostname = False
                context.verify_mode = ssl.CERT_NONE
        reader, writer = await asyncio.open_connection(host, port, ssl=context,
                                                        server_hostname=host if secure else None)
        try:
            key = base64.b64encode(os.urandom(16)).decode("ascii")
            writer.write((
                "GET / HTTP/1.1\r\n"
                f"Host: {host_header}\r\n"
                "Upgrade: websocket\r\nConnection: Upgrade\r\n"
                f"Sec-WebSocket-Key: {key}\r\n"
                "Sec-WebSocket-Version: 13\r\n\r\n"
            ).encode("ascii"))
            await writer.drain()
            response = await reader.readuntil(b"\r\n\r\n")
            if len(response) > 8192:
                raise CheckError("WebSocket handshake response is too large")
            lines = response.decode("latin-1").split("\r\n")
            if not lines[0].startswith("HTTP/1.1 101 "):
                raise CheckError(f"WebSocket upgrade failed: {lines[0]}")
            headers = {}
            for line in lines[1:]:
                if ":" in line:
                    name, value = line.split(":", 1)
                    headers[name.lower()] = value.strip()
            expected = base64.b64encode(hashlib.sha1((key + WEBSOCKET_GUID).encode()).digest()).decode("ascii")
            if (headers.get("sec-websocket-accept") != expected
                    or headers.get("upgrade", "").lower() != "websocket"):
                raise CheckError("WebSocket upgrade response is invalid")
            await send_text(writer, {"type": "hello", "dino": dino})
            message = await receive_text(reader)
            if message.get("type") == "rejected":
                raise CheckError(f"Game server rejected the join: {message.get('reason', 'unknown reason')}")
            if message.get("type") != "welcome":
                raise CheckError(f"Expected a welcome message, got {message.get('type')!r}")
            if (not isinstance(message.get("id"), int)
                    or not isinstance(message.get("seed"), int)
                    or message.get("map") != "grassland"
                    or not isinstance(message.get("players"), list)
                    or not isinstance(message.get("spawn"), dict)
                    or message["spawn"].get("dino") != dino):
                raise CheckError("Welcome message is missing expected world or player data")
            return message
        finally:
            writer.close()
            try:
                await writer.wait_closed()
            except OSError:
                pass

    try:
        return await asyncio.wait_for(probe(), timeout)
    except asyncio.TimeoutError as error:
        raise CheckError(f"Timed out after {timeout:g}s; check the address, firewall, and server") from error
    except ssl.SSLCertVerificationError as error:
        raise CheckError(f"TLS certificate verification failed: {error}. For the generated certificate, use --allow-self-signed") from error
    except (OSError, asyncio.IncompleteReadError, asyncio.LimitOverrunError) as error:
        raise CheckError(f"Connection failed: {error}") from error


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url", nargs="?", default="wss://127.0.0.1:8765/",
                        help="server URL, e.g. wss://192.168.1.50:8765/")
    parser.add_argument("--dino", choices=DINOSAURS, default="triceratops")
    parser.add_argument("--allow-self-signed", action="store_true",
                        help="disable certificate and hostname verification for this check")
    parser.add_argument("--ca-cert", help="CA or self-signed certificate file to trust while verifying the host name")
    parser.add_argument("--timeout", type=float, default=5.0, help="total connection timeout in seconds")
    args = parser.parse_args()
    if not 0 < args.timeout <= 120:
        parser.error("--timeout must be between 0 and 120 seconds")
    try:
        result = asyncio.run(check_server(args.url, args.dino, args.allow_self_signed,
                                          args.ca_cert, args.timeout))
    except CheckError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print(f"PASS: Joined {args.url} as {args.dino}")
    print(f"  Map: {result['map']}  Seed: {result['seed']}  Player ID: {result['id']}")
    print(f"  Other players: {len(result['players'])}  Capacity: {result.get('limit', 'unknown')}")
    if args.allow_self_signed:
        print("  TLS: encrypted, but server identity was not verified")
    elif args.url.startswith("wss://"):
        print("  TLS: certificate and host name verified")
    else:
        print("  TLS: disabled")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
