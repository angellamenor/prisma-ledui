-- =====================================================================
-- Prisma LEdui · Esquema del servidor (PostgreSQL 16)
-- Versión 0.1 · 25-11-2026
--
-- El servidor guarda SOLO dos cosas:
--   A) El CONTENIDO de la herramienta (ítems, fichas, prompts, umbrales…),
--      versionado por publicaciones.
--   B) ESTADÍSTICAS DE USO agregadas por día (contadores).
-- Nunca guarda respuestas, perfiles ni evaluaciones del alumnado.
-- El relé del test (WebSocket) no toca la base de datos.
-- =====================================================================

-- ---------------------------------------------------------------------
-- A) CONTENIDO VERSIONADO
-- ---------------------------------------------------------------------
-- Cómo funciona el versionado:
--   * Todo el contenido cuelga de una "release".
--   * Solo hay una release en estado 'draft' a la vez: es la que se edita.
--   * Al publicar, la release queda congelada (trigger) y la app descarga
--     un paquete JSON con todo su contenido (vista v_content_pack).
--   * Para seguir editando se clona la última publicada en un nuevo draft.
--   * Cada evaluación guarda en el equipo del tutor la versión usada, así
--     los perfiles de septiembre y enero siguen siendo comparables.

CREATE TYPE release_status AS ENUM ('draft', 'review', 'published', 'retired');

CREATE TABLE release (
    id            serial PRIMARY KEY,
    version       text NOT NULL UNIQUE,              -- '1.0', '1.1'…
    locale        text NOT NULL DEFAULT 'es',        -- una release por idioma
    status        release_status NOT NULL DEFAULT 'draft',
    notes         text,                              -- qué cambia en esta versión
    based_on      int REFERENCES release(id),
    created_at    timestamptz NOT NULL DEFAULT now(),
    published_at  timestamptz
);
CREATE UNIQUE INDEX one_draft_per_locale ON release(locale) WHERE status = 'draft';

-- Etapas educativas y su configuración de cálculo -----------------------
CREATE TABLE stage (
    release_id      int  NOT NULL REFERENCES release(id) ON DELETE CASCADE,
    code            text NOT NULL,                   -- 'infantil','primaria','secundaria','fp'
    name            text NOT NULL,
    student_test    text NOT NULL CHECK (student_test IN ('none','visual','full')),
    weight_student  numeric(3,2) NOT NULL CHECK (weight_student BETWEEN 0 AND 1),
    -- peso del tutor = 1 - weight_student
    note            text,                            -- texto que ve el tutor al elegir etapa
    sort            int NOT NULL,
    PRIMARY KEY (release_id, code)
);

-- Reglas LEdui y dimensiones ---------------------------------------------
CREATE TABLE dimension (
    release_id  int  NOT NULL REFERENCES release(id) ON DELETE CASCADE,
    num         int  NOT NULL CHECK (num BETWEEN 1 AND 6),
    code        text NOT NULL,                       -- 'linguistica','estructura'…
    name        text NOT NULL,
    short_name  text NOT NULL,
    kind        text NOT NULL CHECK (kind IN ('support','enhancer')),
    question    text NOT NULL,                       -- «¿Qué necesidad mide?»
    PRIMARY KEY (release_id, num),
    UNIQUE (release_id, code)
);

CREATE TABLE ledui_rule (
    release_id     int  NOT NULL REFERENCES release(id) ON DELETE CASCADE,
    num            int  NOT NULL CHECK (num BETWEEN 1 AND 10),
    name           text NOT NULL,
    description    text NOT NULL,
    dua_principle  text NOT NULL CHECK (dua_principle IN ('representacion','accion_expresion','implicacion')),
    dimension_num  int  NOT NULL,                    -- cada regla pertenece a una sola dimensión
    PRIMARY KEY (release_id, num),
    FOREIGN KEY (release_id, dimension_num) REFERENCES dimension(release_id, num)
);

-- Niveles y equivalencia normativa (configurable si cambia el decreto) --
CREATE TABLE level_def (
    release_id   int  NOT NULL REFERENCES release(id) ON DELETE CASCADE,
    level        int  NOT NULL CHECK (level BETWEEN 1 AND 4),
    meaning      text NOT NULL,
    decree_equiv text NOT NULL,                      -- equivalencia Decreto 85/2018
    PRIMARY KEY (release_id, level)
);

-- Umbrales y reglas de cálculo --------------------------------------------
-- Las puntuaciones se normalizan a 0..1 por dimensión y fuente.
CREATE TABLE scoring_config (
    release_id          int PRIMARY KEY REFERENCES release(id) ON DELETE CASCADE,
    threshold_level2    numeric(3,2) NOT NULL,       -- >= → nivel 2
    threshold_level3    numeric(3,2) NOT NULL,       -- >= → nivel 3
    possible_l4_min     numeric(3,2) NOT NULL,       -- ambas fuentes >= → «posible nivel 4»
    discrepancy_levels  int NOT NULL DEFAULT 2,      -- diferencia que impide promediar
    min_answered_ratio  numeric(3,2) NOT NULL DEFAULT 0.5, -- si hay menos respuestas válidas, se ignora la fuente
    CHECK (threshold_level2 < threshold_level3 AND threshold_level3 <= possible_l4_min)
);

-- Pictogramas (ARASAAC) ---------------------------------------------------
CREATE TABLE pictogram (
    arasaac_id  int PRIMARY KEY,
    keyword     text NOT NULL,
    bundled     boolean NOT NULL DEFAULT false       -- incluido en la app para funcionar sin conexión
);

-- Test del alumnado --------------------------------------------------------
CREATE TABLE test_item (
    id             serial PRIMARY KEY,
    release_id     int  NOT NULL REFERENCES release(id) ON DELETE CASCADE,
    key            text NOT NULL,                    -- clave estable entre versiones: 'EST-01'
    dimension_num  int  NOT NULL,
    item_type      text NOT NULL CHECK (item_type IN ('choose_version','micro_task','situation','preference')),
    stages         text[] NOT NULL,                  -- {'primaria'} / {'secundaria','fp'}
    category_label text NOT NULL,                    -- «Lenguaje · ¿Qué quiere decir?»
    prompt         text NOT NULL,                    -- enunciado en pantalla
    audio_text     text,                             -- lo que lee la voz (si difiere del enunciado)
    context        jsonb,                            -- apoyo extra (p. ej. «Educación Física → Música»)
    sort           int  NOT NULL,
    UNIQUE (release_id, key),
    FOREIGN KEY (release_id, dimension_num) REFERENCES dimension(release_id, num)
);

CREATE TABLE test_option (
    id          serial PRIMARY KEY,
    item_id     int  NOT NULL REFERENCES test_item(id) ON DELETE CASCADE,
    label       text,                                -- «Tarea A»
    text        text NOT NULL,
    steps       jsonb,                               -- para versiones en pasos: [{"text":"Abre el libro","picto":2475}]
    pictograms  int[] NOT NULL DEFAULT '{}',
    score       numeric(3,2),                        -- 0..1 necesidad que indica; NULL = «No lo sé» (no puntúa)
    sort        int  NOT NULL
);

-- Cuestionario de observación del tutor ----------------------------------
CREATE TABLE observation_item (
    id             serial PRIMARY KEY,
    release_id     int  NOT NULL REFERENCES release(id) ON DELETE CASCADE,
    key            text NOT NULL,                    -- 'OBS-EST-01'
    dimension_num  int  NOT NULL,
    stages         text[] NOT NULL,
    text           text NOT NULL,                    -- «No inicia la tarea sin apoyo directo.»
    reversed       boolean NOT NULL DEFAULT false,   -- si la conducta indica menos necesidad
    sort           int  NOT NULL,
    UNIQUE (release_id, key),
    FOREIGN KEY (release_id, dimension_num) REFERENCES dimension(release_id, num)
);

CREATE TABLE frequency_option (
    release_id  int  NOT NULL REFERENCES release(id) ON DELETE CASCADE,
    value       int  NOT NULL CHECK (value BETWEEN 0 AND 3),
    label       text NOT NULL,                       -- nunca / a veces / con frecuencia / casi siempre
    PRIMARY KEY (release_id, value)
);

-- Fichas de actuación individuales (dimensión × nivel 1..3) -------------
CREATE TABLE action_sheet (
    id             serial PRIMARY KEY,
    release_id     int  NOT NULL REFERENCES release(id) ON DELETE CASCADE,
    dimension_num  int  NOT NULL,
    level          int  NOT NULL CHECK (level BETWEEN 1 AND 3),   -- el nivel 4 no tiene ficha: genera resumen funcional
    rule_nums      int[] NOT NULL,                   -- reglas LEdui en que se basa
    UNIQUE (release_id, dimension_num, level),
    FOREIGN KEY (release_id, dimension_num) REFERENCES dimension(release_id, num)
);

CREATE TABLE sheet_guideline (                       -- bloque «En el aula»
    id        serial PRIMARY KEY,
    sheet_id  int  NOT NULL REFERENCES action_sheet(id) ON DELETE CASCADE,
    text      text NOT NULL,
    sort      int  NOT NULL
);

-- Prompts «Con IA» (compartidos por fichas individuales y plan de aula) --
CREATE TABLE ai_prompt (
    id          serial PRIMARY KEY,
    release_id  int  NOT NULL REFERENCES release(id) ON DELETE CASCADE,
    key         text NOT NULL,                       -- 'P-EST-PASOS' (estable: es lo que cuenta la estadística)
    title       text NOT NULL,
    text        text NOT NULL,                       -- con marcadores [pega aquí…]; nunca datos del alumno
    rule_nums   int[] NOT NULL,
    UNIQUE (release_id, key)
);

CREATE TABLE sheet_prompt (
    sheet_id   int NOT NULL REFERENCES action_sheet(id) ON DELETE CASCADE,
    prompt_id  int NOT NULL REFERENCES ai_prompt(id) ON DELETE CASCADE,
    sort       int NOT NULL,
    PRIMARY KEY (sheet_id, prompt_id)
);

-- Medidas para toda la clase (una por dimensión) ------------------------
CREATE TABLE class_measure (
    id             serial PRIMARY KEY,
    release_id     int  NOT NULL REFERENCES release(id) ON DELETE CASCADE,
    key            text NOT NULL,                    -- 'M-EST'
    dimension_num  int  NOT NULL,
    classroom_text text NOT NULL,                    -- «En el aula»
    prompt_id      int  REFERENCES ai_prompt(id),    -- «Con IA»
    UNIQUE (release_id, key),
    FOREIGN KEY (release_id, dimension_num) REFERENCES dimension(release_id, num)
);

CREATE TABLE priority_band (                         -- % de la clase → etiqueta de prioridad
    release_id  int  NOT NULL REFERENCES release(id) ON DELETE CASCADE,
    min_ratio   numeric(3,2) NOT NULL,
    label       text NOT NULL,                       -- 'Prioridad alta'…
    PRIMARY KEY (release_id, min_ratio)
);

-- Reglas de convivencia entre dimensiones --------------------------------
-- Condición declarativa que evalúa la app, p. ej.:
--   {"all":[{"dim":3,"min_level":3},{"dim":6,"min_level":2}]}
CREATE TABLE coexistence_rule (
    id          serial PRIMARY KEY,
    release_id  int  NOT NULL REFERENCES release(id) ON DELETE CASCADE,
    key         text NOT NULL,
    condition   jsonb NOT NULL,
    effect      text NOT NULL,                       -- texto que se añade a las fichas afectadas
    applies_to  int[] NOT NULL,                      -- dimensiones cuyas fichas reciben el aviso
    UNIQUE (release_id, key)
);

-- Textos de la interfaz (para cambiar redacción sin desplegar) -----------
CREATE TABLE ui_text (
    release_id  int  NOT NULL REFERENCES release(id) ON DELETE CASCADE,
    key         text NOT NULL,                       -- 'grupo.como_funciona.1'
    text        text NOT NULL,
    PRIMARY KEY (release_id, key)
);

-- Una release publicada no se puede modificar -----------------------------
CREATE FUNCTION forbid_published_edit() RETURNS trigger AS $$
DECLARE rid int; st release_status;
BEGIN
  rid := COALESCE(
    CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END ->> 'release_id', NULL)::int;
  IF rid IS NULL THEN RETURN COALESCE(NEW, OLD); END IF;   -- tablas hijas sin release_id
  SELECT status INTO st FROM release WHERE id = rid;
  IF st IN ('published','retired') THEN
    RAISE EXCEPTION 'La release % está publicada: clónala para editar', rid;
  END IF;
  RETURN COALESCE(NEW, OLD);
END $$ LANGUAGE plpgsql;

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['stage','dimension','ledui_rule','level_def','scoring_config',
    'test_item','observation_item','frequency_option','action_sheet','ai_prompt',
    'class_measure','priority_band','coexistence_rule','ui_text'] LOOP
    EXECUTE format('CREATE TRIGGER %I_frozen BEFORE INSERT OR UPDATE OR DELETE ON %I
                    FOR EACH ROW EXECUTE FUNCTION forbid_published_edit()', t, t);
  END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- B) ESTADÍSTICAS DE USO (solo contadores agregados por día)
-- ---------------------------------------------------------------------
-- Sin hora, sin identificadores de alumno ni de grupo, sin texto libre.
-- La app envía incrementos; el servidor suma con UPSERT.

CREATE TABLE usage_event_type (
    code         text PRIMARY KEY,
    description  text NOT NULL,
    needs_ref    boolean NOT NULL DEFAULT false      -- si lleva referencia a contenido (prompt, medida, dimensión)
);

CREATE TABLE usage_daily (
    day          date NOT NULL,
    center_code  text NOT NULL CHECK (center_code ~ '^[0-9]{8}$'),  -- código de centro CLM
    stage        text NOT NULL DEFAULT '-',
    version      text NOT NULL,                      -- versión de contenido en uso
    event        text NOT NULL REFERENCES usage_event_type(code),
    ref          text NOT NULL DEFAULT '-',          -- 'P-EST-PASOS', 'M-REG', 'dim:2'…
    count        int  NOT NULL DEFAULT 0 CHECK (count >= 0),
    PRIMARY KEY (day, center_code, stage, version, event, ref)
);

CREATE INDEX usage_daily_event ON usage_daily(event, day);

INSERT INTO usage_event_type (code, description, needs_ref) VALUES
  ('app_opened',           'Se abre la aplicación',                                false),
  ('class_created',        'Se crea un grupo',                                     false),
  ('test_session_started', 'El tutor abre una sesión de test',                     false),
  ('test_received',        'Llega al tutor un test completado',                    false),
  ('observation_done',     'El tutor completa una observación',                    false),
  ('level_adjusted_up',    'El tutor sube un nivel medido',                        true),
  ('level_adjusted_down',  'El tutor baja un nivel medido',                        true),
  ('sheet_viewed',         'Se consulta una ficha de actuación',                   true),
  ('prompt_copied',        'Se copia un prompt «Con IA»',                          true),
  ('measure_added',        'Se añade una medida al plan de aula',                  true),
  ('export_pdf',           'Se exportan fichas en PDF',                            false),
  ('shared_team',          'Se comparte con el equipo docente',                    false);

-- Vista para el panel de estadísticas: oculta celdas con menos de 5 eventos
-- en informes por centro, para no permitir inferencias sobre grupos pequeños.
CREATE VIEW v_usage_by_center AS
SELECT date_trunc('month', day)::date AS month, center_code, event, ref,
       sum(count) AS total
FROM usage_daily
GROUP BY 1, 2, 3, 4
HAVING sum(count) >= 5;

-- ---------------------------------------------------------------------
-- Congelación de tablas hijas (sin release_id propio)
-- ---------------------------------------------------------------------
CREATE FUNCTION forbid_published_child_edit() RETURNS trigger AS $$
DECLARE r jsonb; rid int; st release_status;
BEGIN
  r := CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
  IF TG_TABLE_NAME = 'test_option' THEN
    SELECT release_id INTO rid FROM test_item WHERE id = (r->>'item_id')::int;
  ELSE
    SELECT release_id INTO rid FROM action_sheet WHERE id = (r->>'sheet_id')::int;
  END IF;
  SELECT status INTO st FROM release WHERE id = rid;
  IF st IN ('published','retired') THEN
    RAISE EXCEPTION 'La release % está publicada: clónala para editar', rid;
  END IF;
  RETURN COALESCE(NEW, OLD);
END $$ LANGUAGE plpgsql;

CREATE TRIGGER test_option_frozen     BEFORE INSERT OR UPDATE OR DELETE ON test_option     FOR EACH ROW EXECUTE FUNCTION forbid_published_child_edit();
CREATE TRIGGER sheet_guideline_frozen BEFORE INSERT OR UPDATE OR DELETE ON sheet_guideline FOR EACH ROW EXECUTE FUNCTION forbid_published_child_edit();
CREATE TRIGGER sheet_prompt_frozen    BEFORE INSERT OR UPDATE OR DELETE ON sheet_prompt    FOR EACH ROW EXECUTE FUNCTION forbid_published_child_edit();

-- ---------------------------------------------------------------------
-- Publicar una release
-- ---------------------------------------------------------------------
CREATE FUNCTION publish_release(rid int) RETURNS void AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM scoring_config WHERE release_id = rid) THEN
    RAISE EXCEPTION 'Falta la configuración de cálculo';
  END IF;
  IF (SELECT count(*) FROM dimension WHERE release_id = rid) <> 6 THEN
    RAISE EXCEPTION 'Deben existir las 6 dimensiones';
  END IF;
  UPDATE release SET status = 'retired'
   WHERE locale = (SELECT locale FROM release WHERE id = rid) AND status = 'published';
  UPDATE release SET status = 'published', published_at = now() WHERE id = rid;
END $$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
-- Paquete de contenido que descarga la app: GET /content/{version}
-- ---------------------------------------------------------------------
CREATE FUNCTION content_pack(rid int) RETURNS jsonb AS $$
SELECT jsonb_build_object(
  'version', r.version, 'locale', r.locale, 'published_at', r.published_at,
  'stages', (SELECT jsonb_agg(to_jsonb(s) - 'release_id' ORDER BY s.sort) FROM stage s WHERE s.release_id = rid),
  'dimensions', (SELECT jsonb_agg(to_jsonb(d) - 'release_id' ORDER BY d.num) FROM dimension d WHERE d.release_id = rid),
  'rules', (SELECT jsonb_agg(to_jsonb(x) - 'release_id' ORDER BY x.num) FROM ledui_rule x WHERE x.release_id = rid),
  'levels', (SELECT jsonb_agg(to_jsonb(l) - 'release_id' ORDER BY l.level) FROM level_def l WHERE l.release_id = rid),
  'scoring', (SELECT to_jsonb(c) - 'release_id' FROM scoring_config c WHERE c.release_id = rid),
  'frequency', (SELECT jsonb_agg(to_jsonb(f) - 'release_id' ORDER BY f.value) FROM frequency_option f WHERE f.release_id = rid),
  'priority_bands', (SELECT jsonb_agg(to_jsonb(p) - 'release_id' ORDER BY p.min_ratio) FROM priority_band p WHERE p.release_id = rid),
  'test_items', (SELECT jsonb_agg(to_jsonb(i) - 'release_id' - 'id' || jsonb_build_object('options',
        (SELECT jsonb_agg(to_jsonb(o) - 'id' - 'item_id' ORDER BY o.sort) FROM test_option o WHERE o.item_id = i.id))
        ORDER BY i.sort) FROM test_item i WHERE i.release_id = rid),
  'observation_items', (SELECT jsonb_agg(to_jsonb(o) - 'release_id' - 'id' ORDER BY o.dimension_num, o.sort) FROM observation_item o WHERE o.release_id = rid),
  'prompts', (SELECT jsonb_agg(to_jsonb(p) - 'release_id' - 'id' ORDER BY p.key) FROM ai_prompt p WHERE p.release_id = rid),
  'sheets', (SELECT jsonb_agg(jsonb_build_object('dimension', a.dimension_num, 'level', a.level, 'rules', a.rule_nums,
        'classroom', (SELECT jsonb_agg(g.text ORDER BY g.sort) FROM sheet_guideline g WHERE g.sheet_id = a.id),
        'prompts', (SELECT jsonb_agg(p.key ORDER BY sp.sort) FROM sheet_prompt sp JOIN ai_prompt p ON p.id = sp.prompt_id WHERE sp.sheet_id = a.id))
        ORDER BY a.dimension_num, a.level) FROM action_sheet a WHERE a.release_id = rid),
  'class_measures', (SELECT jsonb_agg(jsonb_build_object('key', m.key, 'dimension', m.dimension_num,
        'classroom', m.classroom_text, 'prompt', p.key) ORDER BY m.dimension_num)
        FROM class_measure m LEFT JOIN ai_prompt p ON p.id = m.prompt_id WHERE m.release_id = rid),
  'coexistence', (SELECT jsonb_agg(to_jsonb(c) - 'release_id' - 'id' ORDER BY c.key) FROM coexistence_rule c WHERE c.release_id = rid),
  'ui', (SELECT jsonb_object_agg(u.key, u.text) FROM ui_text u WHERE u.release_id = rid)
)
FROM release r WHERE r.id = rid;
$$ LANGUAGE sql STABLE;
