# Arquitectura · decisiones (25-11-2026)

1. **Versión web instalable (PWA).** La app del tutor se instala desde el navegador
   y funciona sin conexión con el último paquete de contenido descargado.
2. **Datos del alumnado solo en el equipo del tutor** (IndexedDB). El alumno entra
   con código de clase y número de lista; nunca escribe su nombre.
3. **Relé en directo para el test.** El navegador del alumno cifra sus respuestas con
   la clave pública del tutor y las envía por WebSocket. El servidor las reenvía sin
   guardarlas. Si el tutor no está conectado, el dispositivo del alumno reintenta.
4. **Contenido en base de datos, versionado.** Una versión publicada no se puede
   modificar. Cada evaluación registra la versión usada.
5. **Estadísticas solo de uso.** Contadores diarios por código de centro, etapa,
   versión, evento y referencia de contenido. Sin hora, sin identificadores de
   alumno o grupo, sin texto libre. Informes por centro con mínimo de 5.
6. **GitHub → Railway.** CI en GitHub Actions; staging desde `develop`, producción
   desde `main`; migraciones automáticas antes de cada despliegue.

## Pendiente
- Clonar una versión publicada en un nuevo borrador (endpoint de administración).
- Motor de cálculo de niveles en la app.
- Panel de edición de contenido (con autenticación).
- Umbrales y pesos definitivos (tras revisión con orientación y pilotaje).
