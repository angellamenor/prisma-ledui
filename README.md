# Prisma LEdui

Respuesta educativa inclusiva para el alumnado con TEA, basada en el estándar LEdui.

## Principio de diseño

**El servidor nunca guarda datos del alumnado.** Las evaluaciones, los perfiles
y los nombres viven solo en el navegador del tutor. El servidor tiene tres
funciones:

| Función | Ruta | Qué guarda |
|---|---|---|
| Contenido versionado (ítems, fichas, prompts, umbrales) | `GET /content/latest`, `GET /content/{versión}` | El catálogo de contenido |
| Estadísticas de uso | `POST /usage` | Contadores por día y código de centro |
| Relé del test | `WS /ws/{sala}/{rol}` | Nada: reenvía en directo y olvida |

## Estructura

```
backend/
  app/            API FastAPI (main.py, relay.py, db.py)
  migrations/     SQL numerado; se aplica en orden y una sola vez
  migrate.py      aplica las migraciones (Railway lo lanza antes de cada despliegue)
  tests/          pruebas contra PostgreSQL real
  railway.json    configuración de despliegue
frontend/         PWA (pendiente)
docs/             arquitectura y decisiones
```

## Trabajar en local

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
export DATABASE_URL=postgresql://postgres:postgres@localhost:5432/prisma
python migrate.py
uvicorn app.main:app --reload
pytest
```

## Flujo de trabajo

1. Se trabaja en ramas a partir de `develop` y se integra por *pull request*.
2. GitHub Actions ejecuta migraciones y pruebas en cada *push* y PR.
3. `develop` → Railway, entorno **staging**. `main` → Railway, entorno **production**.
4. Railway espera a que la CI pase («Wait for CI») antes de desplegar.
5. Antes de arrancar la nueva versión, Railway ejecuta `python migrate.py`.
   Si la migración falla, el despliegue se cancela y sigue la versión anterior.

## Reglas para las migraciones

- Nunca se edita una migración ya aplicada: `migrate.py` compara checksums y detiene el despliegue.
- Cada cambio de esquema es un archivo nuevo: `0004_lo_que_sea.sql`.
- El **contenido** (ítems, fichas…) no se cambia con migraciones salvo la carga inicial:
  se edita desde el panel de administración y se publica como nueva versión.
