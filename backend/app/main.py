"""Prisma LEdui · API

Tres funciones y nada más:
  1. Contenido versionado  → GET  /content/latest, /content/{version}
  2. Estadísticas de uso   → POST /usage   (solo contadores agregados)
  3. Relé del test         → WS   /ws/{sala}/{rol}  (no guarda nada)
"""
import datetime as dt
import json
import os
import re
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, field_validator

from . import db
from .relay import router as relay_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    await db.connect()
    yield
    await db.disconnect()


app = FastAPI(title="Prisma LEdui API", version="0.1.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.environ.get("CORS_ORIGINS", "*").split(","),
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)
app.include_router(relay_router)


@app.get("/health")
async def health():
    async with db.pool.acquire() as c:
        await c.fetchval("SELECT 1")
    return {"ok": True}


# ---------------------------------------------------------------- contenido
@app.get("/content/latest")
async def content_latest(locale: str = "es"):
    async with db.pool.acquire() as c:
        row = await c.fetchrow(
            "SELECT version FROM release WHERE status='published' AND locale=$1", locale
        )
    if not row:
        raise HTTPException(404, "No hay contenido publicado")
    return {"version": row["version"]}


@app.get("/content/{version}")
async def content(version: str):
    async with db.pool.acquire() as c:
        pack = await c.fetchval(
            """SELECT content_pack(id) FROM release
               WHERE version=$1 AND status IN ('published','retired')""",
            version,
        )
    if pack is None:
        raise HTTPException(404, "Versión no encontrada")
    return json.loads(pack)


# ------------------------------------------------------------- estadísticas
REF_RE = re.compile(r"^(-|dim:[1-6]|[A-Z]-[A-Z0-9-]{2,40})$")


class UsageCount(BaseModel):
    day: dt.date
    center_code: str = Field(pattern=r"^[0-9]{8}$")
    stage: str = Field(default="-", pattern=r"^(-|infantil|primaria|secundaria|fp)$")
    version: str = Field(pattern=r"^[0-9]+\.[0-9]+$")
    event: str = Field(pattern=r"^[a-z_]{3,40}$")
    ref: str = "-"
    count: int = Field(ge=1, le=500)

    @field_validator("day")
    @classmethod
    def recent(cls, v: dt.date) -> dt.date:
        today = dt.date.today()
        if v > today or v < today - dt.timedelta(days=30):
            raise ValueError("fecha fuera de rango")
        return v

    @field_validator("ref")
    @classmethod
    def ref_ok(cls, v: str) -> str:
        if not REF_RE.match(v):
            raise ValueError("referencia no válida")
        return v


class UsageBatch(BaseModel):
    counts: list[UsageCount] = Field(max_length=200)


@app.post("/usage", status_code=204)
async def usage(batch: UsageBatch):
    async with db.pool.acquire() as c:
        known = {r["code"] for r in await c.fetch("SELECT code FROM usage_event_type")}
        bad = {u.event for u in batch.counts} - known
        if bad:
            raise HTTPException(422, f"Eventos desconocidos: {sorted(bad)}")
        await c.executemany(
            """INSERT INTO usage_daily (day, center_code, stage, version, event, ref, count)
               VALUES ($1,$2,$3,$4,$5,$6,$7)
               ON CONFLICT (day, center_code, stage, version, event, ref)
               DO UPDATE SET count = usage_daily.count + EXCLUDED.count""",
            [(u.day, u.center_code, u.stage, u.version, u.event, u.ref, u.count) for u in batch.counts],
        )
