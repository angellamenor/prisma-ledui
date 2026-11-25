import os

import asyncpg

pool: asyncpg.Pool | None = None


async def connect() -> None:
    global pool
    pool = await asyncpg.create_pool(os.environ["DATABASE_URL"], min_size=1, max_size=5)


async def disconnect() -> None:
    if pool:
        await pool.close()
