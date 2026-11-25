"""Relé del test: reenvía en directo las respuestas del alumnado al tutor.

NO guarda nada: ni en disco ni en la base de datos. Las salas viven en memoria
mientras el tutor tiene la clase abierta. Si el tutor no está conectado, el
alumno recibe «teacher_offline» y su dispositivo reintenta más tarde.

Mensajes (JSON):
  alumno → servidor  {"type":"result","id":"<uuid>","payload":"<cifrado>"}
  servidor → tutor   {"type":"result","id":"<uuid>","payload":"<cifrado>"}
  tutor → servidor   {"type":"ack","id":"<uuid>"}
  servidor → alumno  {"type":"ack","id":"<uuid>"}
El servidor nunca interpreta «payload»: va cifrado con la clave del tutor.
"""
import re

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

router = APIRouter()

ROOM_RE = re.compile(r"^[A-Z0-9]{8}$")
MAX_PAYLOAD = 64_000  # un test cifrado ocupa unos pocos KB

teachers: dict[str, WebSocket] = {}
pending: dict[str, WebSocket] = {}  # id de mensaje → alumno que espera confirmación


@router.websocket("/ws/{room}/{role}")
async def relay(ws: WebSocket, room: str, role: str):
    if not ROOM_RE.match(room) or role not in ("teacher", "student"):
        await ws.close(code=4400)
        return
    await ws.accept()

    if role == "teacher":
        old = teachers.get(room)
        if old:
            await old.close(code=4409)  # la clase se ha abierto en otro equipo
        teachers[room] = ws
        try:
            while True:
                msg = await ws.receive_json()
                if msg.get("type") == "ack":
                    student = pending.pop(str(msg.get("id")), None)
                    if student:
                        await student.send_json({"type": "ack", "id": msg["id"]})
        except WebSocketDisconnect:
            pass
        finally:
            if teachers.get(room) is ws:
                del teachers[room]
        return

    # alumno
    my_ids: set[str] = set()
    try:
        while True:
            msg = await ws.receive_json()
            if msg.get("type") != "result" or len(str(msg.get("payload", ""))) > MAX_PAYLOAD:
                await ws.send_json({"type": "error", "reason": "invalid"})
                continue
            teacher = teachers.get(room)
            if not teacher:
                await ws.send_json({"type": "teacher_offline", "id": msg.get("id")})
                continue
            mid = str(msg["id"])
            pending[mid] = ws
            my_ids.add(mid)
            await teacher.send_json({"type": "result", "id": mid, "payload": msg["payload"]})
    except WebSocketDisconnect:
        pass
    finally:
        for mid in my_ids:
            if pending.get(mid) is ws:
                del pending[mid]
