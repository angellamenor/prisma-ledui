"""Pruebas de la API contra un PostgreSQL real (DATABASE_URL), ya migrado."""
import datetime as dt

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture(scope="module")
def client():
    with TestClient(app) as c:
        yield c


def test_health(client):
    assert client.get("/health").json() == {"ok": True}


def test_content_pack(client):
    v = client.get("/content/latest").json()["version"]
    pack = client.get(f"/content/{v}").json()
    assert len(pack["dimensions"]) == 6
    assert len(pack["rules"]) == 10
    assert {i["key"] for i in pack["test_items"]} >= {"EST-01", "LIN-01"}


def test_unknown_version(client):
    assert client.get("/content/9.9").status_code == 404


def test_usage_accumulates(client):
    today = dt.date.today().isoformat()
    row = {"day": today, "center_code": "13000001", "stage": "primaria",
           "version": "0.1", "event": "prompt_copied", "ref": "P-EST-PASOS", "count": 2}
    assert client.post("/usage", json={"counts": [row, row]}).status_code == 204


@pytest.mark.parametrize("change", [
    {"center_code": "Lucía"},              # nada que no sea un código de centro
    {"ref": "Lucía Fernández Gil"},        # ni texto libre en la referencia
    {"event": "evento_inventado"},
    {"day": "2020-01-01"},
    {"count": 9999},
])
def test_usage_rejects_bad_data(client, change):
    row = {"day": dt.date.today().isoformat(), "center_code": "13000001",
           "version": "0.1", "event": "test_received", "count": 1} | change
    assert client.post("/usage", json={"counts": [row]}).status_code == 422


def test_relay_forwards_and_acks(client):
    with client.websocket_connect("/ws/PRZ5A7K0/teacher") as teacher, \
         client.websocket_connect("/ws/PRZ5A7K0/student") as student:
        student.send_json({"type": "result", "id": "m1", "payload": "cifrado..."})
        got = teacher.receive_json()
        assert got == {"type": "result", "id": "m1", "payload": "cifrado..."}
        teacher.send_json({"type": "ack", "id": "m1"})
        assert student.receive_json() == {"type": "ack", "id": "m1"}


def test_relay_teacher_offline(client):
    with client.websocket_connect("/ws/NADIE000/student") as student:
        student.send_json({"type": "result", "id": "m2", "payload": "x"})
        assert student.receive_json()["type"] == "teacher_offline"


def test_relay_stores_nothing(client):
    """El relé no debe dejar rastro en la base de datos."""
    import asyncio, asyncpg, os
    async def tables():
        c = await asyncpg.connect(os.environ["DATABASE_URL"])
        rows = await c.fetch("SELECT tablename FROM pg_tables WHERE schemaname='public'")
        await c.close()
        return {r["tablename"] for r in rows}
    names = asyncio.run(tables())
    assert not any(n in names for n in ("result", "results", "responses", "students", "alumnos"))
