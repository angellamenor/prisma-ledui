"""Aplica en orden las migraciones SQL de ./migrations.

- Cada archivo se aplica una sola vez, dentro de una transacción.
- Se guarda su checksum: si alguien modifica una migración ya aplicada,
  el despliegue se detiene. Los cambios van siempre en un archivo nuevo.

Uso:  DATABASE_URL=postgresql://... python migrate.py
Railway lo ejecuta antes de cada despliegue (preDeployCommand).
"""
import asyncio
import hashlib
import os
import pathlib
import sys

import asyncpg

MIGRATIONS = pathlib.Path(__file__).parent / "migrations"


async def main() -> None:
    conn = await asyncpg.connect(os.environ["DATABASE_URL"])
    try:
        await conn.execute(
            """CREATE TABLE IF NOT EXISTS schema_migrations (
                   filename   text PRIMARY KEY,
                   checksum   text NOT NULL,
                   applied_at timestamptz NOT NULL DEFAULT now())"""
        )
        # Evita que dos despliegues migren a la vez
        await conn.execute("SELECT pg_advisory_lock(727274)")
        applied = {r["filename"]: r["checksum"] for r in await conn.fetch("SELECT * FROM schema_migrations")}
        for f in sorted(MIGRATIONS.glob("*.sql")):
            sql = f.read_text(encoding="utf-8")
            digest = hashlib.sha256(sql.encode()).hexdigest()
            if f.name in applied:
                if applied[f.name] != digest:
                    sys.exit(f"✗ {f.name} ha cambiado después de aplicarse. Crea una migración nueva.")
                continue
            async with conn.transaction():
                await conn.execute(sql)
                await conn.execute("INSERT INTO schema_migrations(filename, checksum) VALUES($1, $2)", f.name, digest)
            print(f"✓ {f.name}")
        print("Migraciones al día.")
    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(main())
