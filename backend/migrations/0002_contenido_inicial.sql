-- =====================================================================
-- Prisma LEdui · Contenido de ejemplo (release 0.1, borrador)
-- Tomado de la demo interactiva y del documento técnico (nov. 2026).
-- Los umbrales son provisionales: se ajustan tras el pilotaje.
-- =====================================================================

INSERT INTO release (id, version, notes) VALUES (1, '0.1', 'Contenido inicial a partir de la demo');

INSERT INTO stage VALUES
 (1,'infantil',  'Infantil',   'none',   0.00,'Solo cuestionario del tutor. La familia puede ser fuente complementaria.',1),
 (1,'primaria',  'Primaria',   'visual', 0.35,'Test visual y breve, con pictogramas de ARASAAC y lectura en voz alta.',2),
 (1,'secundaria','Secundaria', 'full',   0.50,'Versión completa del test. Alumno y tutor tienen el mismo peso.',3),
 (1,'fp',        'FP',         'full',   0.50,'Versión completa del test. Alumno y tutor tienen el mismo peso.',4);

INSERT INTO dimension VALUES
 (1,1,'linguistica','Lingüística','Lingüística','support','¿Entiende palabras, frases y textos? ¿Interpreta el lenguaje al pie de la letra?'),
 (1,2,'estructura','Estructura y autonomía','Estructura','support','¿Sabe por dónde empezar y qué se espera de él? ¿Necesita anticipación?'),
 (1,3,'regulacion','Regulación emocional y sensorial','Regulación','support','¿Se bloquea o se frustra? ¿Le afectan el ruido, la luz o los estímulos?'),
 (1,4,'multimodal','Multimodal y visual','Multimodal','support','¿Comprende mejor con apoyos visuales? ¿Se expresa mejor por otro canal?'),
 (1,5,'social','Social y comunicativa','Social','support','¿Necesita apoyo para interactuar, trabajar con otros o leer situaciones sociales?'),
 (1,6,'critico','Pensamiento crítico','P. crítico','enhancer','¿Necesita más reto y profundidad para implicarse?');

INSERT INTO ledui_rule VALUES
 (1,1,'Claridad lingüística','Frases cortas, voz activa, vocabulario cotidiano; tecnicismos siempre explicados.','representacion',1),
 (1,2,'Estructura guiada','Pasos numerados, anticipación de lo que viene, sin sobrecarga simultánea.','accion_expresion',2),
 (1,3,'Coherencia expositiva','Introducción, desarrollo y cierre, con conectores que orientan.','representacion',1),
 (1,4,'Tono y regulación emocional','Tono cercano; valida el esfuerzo y presenta el error como parte del proceso.','implicacion',3),
 (1,5,'Aprendizaje autónomo','Redactado como si no hubiera tutor: aclaraciones, ejemplos, mensajes guía.','accion_expresion',2),
 (1,6,'Intención pedagógica','Objetivo, criterios de entrega y tiempo estimado explícitos.','accion_expresion',2),
 (1,7,'Aprendizaje colaborativo','Cooperación y trabajo entre iguales.','implicacion',5),
 (1,8,'Pensamiento crítico','Preguntas abiertas y dilemas breves.','implicacion',6),
 (1,9,'Conexión con el entorno','Situaciones reales del entorno cotidiano y profesional.','implicacion',3),
 (1,10,'Recursos multimodales','Pictogramas, esquemas, agendas visuales, audio y formatos alternativos.','representacion',4);

INSERT INTO level_def VALUES
 (1,1,'Base: DUA y reglas LEdui para todo el grupo.','Medidas a nivel de aula.'),
 (1,2,'Apoyo puntual en momentos concretos.','Medidas a nivel de aula, con ajustes.'),
 (1,3,'Apoyo sistemático y planificado para este alumno.','Medidas individualizadas.'),
 (1,4,'Coordinar con orientación: el aula no es suficiente.','Paso previo a valorar otras medidas.');

INSERT INTO scoring_config VALUES (1, 0.35, 0.65, 0.85, 2, 0.5);

INSERT INTO frequency_option VALUES
 (1,0,'Nunca'),(1,1,'A veces'),(1,2,'Con frecuencia'),(1,3,'Casi siempre');

INSERT INTO priority_band VALUES
 (1,0.00,'Prioridad baja'),(1,0.20,'Prioridad media'),(1,0.40,'Prioridad alta');

-- Ítems del test (los cuatro de la demo) ---------------------------------
INSERT INTO test_item (id, release_id, key, dimension_num, item_type, stages, category_label, prompt, context, sort) VALUES
 (1,1,'EST-01',2,'choose_version','{primaria,secundaria,fp}','Elige la que te ayuda más',
    '¿Con cuál de estas dos tareas sabrías empezar ya?', NULL, 1),
 (2,1,'LIN-01',1,'micro_task','{primaria,secundaria,fp}','Lenguaje · ¿Qué quiere decir?',
    'La profe dice: «¡Venga, que se nos echa el tiempo encima!» ¿Qué quiere decir?', NULL, 2),
 (3,1,'REG-01',3,'situation','{primaria,secundaria,fp}','Situación · ¿Qué te ayuda?',
    'Hay mucho ruido en clase y tienes que terminar tu tarea. ¿Qué te ayudaría más?', NULL, 3),
 (4,1,'EST-02',2,'preference','{primaria,secundaria,fp}','Cambios · ¿Cómo te sientes?',
    'Hoy no hay Educación Física. Hay Música. ¿Cómo te sientes?',
    '{"change":{"from":"Educación Física","to":"Música"}}', 4);

INSERT INTO test_option (item_id, label, text, steps, score, sort) VALUES
 (1,'Tarea A','Échale un ojo a la página 12 y haz lo que pone.', NULL, 0.00, 1),
 (1,'Tarea B','Sigue estos pasos.',
    '[{"text":"Abre el libro."},{"text":"Busca la página 12."},{"text":"Escribe las respuestas."}]', 1.00, 2),
 (1,NULL,'No lo sé', NULL, NULL, 3),
 (2,NULL,'Tenemos que darnos prisa.', NULL, 0.00, 1),
 (2,NULL,'Un reloj se nos va a caer encima.', NULL, 1.00, 2),
 (2,NULL,'Va a empezar a llover.', NULL, 0.70, 3),
 (3,NULL,'Ponerme unos cascos.', NULL, 1.00, 1),
 (3,NULL,'Ir a un rincón tranquilo.', NULL, 1.00, 2),
 (3,NULL,'Nada. Sigo trabajando igual.', NULL, 0.00, 3),
 (3,NULL,'Pedir ayuda a la profe.', NULL, 0.50, 4),
 (4,NULL,'Tranquilo o tranquila.', NULL, 0.00, 1),
 (4,NULL,'Un poco nervioso o nerviosa.', NULL, 0.50, 2),
 (4,NULL,'Muy nervioso o nerviosa.', NULL, 1.00, 3),
 (4,NULL,'Enfadado o enfadada.', NULL, 1.00, 4);

INSERT INTO observation_item (release_id, key, dimension_num, stages, text, sort) VALUES
 (1,'OBS-EST-01',2,'{infantil,primaria,secundaria,fp}','No inicia la tarea sin apoyo directo.',1);

-- Prompts «Con IA» --------------------------------------------------------
INSERT INTO ai_prompt (id, release_id, key, title, text, rule_nums) VALUES
 (1,1,'P-LIN-LITERAL','Enunciado literal','Reescribe este enunciado siguiendo las reglas 1 y 3 del estándar LEdui: frases cortas, voz activa y vocabulario cotidiano. Cambia cualquier expresión figurada o de doble sentido por una instrucción literal. Explica entre paréntesis cada tecnicismo. Enunciado: [pega aquí el texto]','{1,3}'),
 (2,1,'P-LIN-FIGURADO','Detectar lenguaje figurado','Revisa este texto y señala las metáforas, ironías y frases hechas. Para cada una, propón una alternativa literal y breve. Texto: [pega aquí el texto]','{1}'),
 (3,1,'P-EST-PASOS','Tarea en pasos','Divide esta actividad en pasos numerados, uno por línea, según la regla 2 del estándar LEdui. Al principio indica el objetivo, el tiempo estimado y cómo sabrá el alumnado que ha terminado (regla 6). Actividad: [pega aquí la actividad]','{2,6}'),
 (4,1,'P-REG-TONO','Tono que anticipa','Redacta esta tarea con un tono cercano que anticipe las dificultades y presente el error como parte del proceso (regla 4 de LEdui). Tarea: [pega aquí]','{4}');

INSERT INTO action_sheet (id, release_id, dimension_num, level, rule_nums) VALUES
 (1,1,1,3,'{1,3}'),
 (2,1,2,3,'{2,5,6}');

INSERT INTO sheet_guideline (sheet_id, text, sort) VALUES
 (1,'Da instrucciones literales. Evita frases hechas como «échale un ojo» o «ponte las pilas»: di exactamente qué hacer.',1),
 (1,'Explica cada palabra técnica la primera vez que aparece, con un ejemplo cotidiano.',2),
 (1,'Usa frases cortas y en voz activa en enunciados y exámenes.',3),
 (1,'Comprueba que ha entendido: pídele que te cuente la tarea con sus palabras.',4),
 (2,'Empieza cada sesión con una agenda visual: qué haremos, en qué orden y cuándo acaba.',1),
 (2,'Numera los pasos de cada tarea y muestra uno cada vez para no sobrecargar.',2),
 (2,'Dile de forma explícita por dónde empezar: «Primero, escribe tu nombre».',3),
 (2,'Anticipa los cambios de rutina con tiempo y con apoyo visual.',4);

INSERT INTO sheet_prompt VALUES (1,1,1),(1,2,2),(2,3,1);

INSERT INTO class_measure (release_id, key, dimension_num, classroom_text, prompt_id) VALUES
 (1,'M-LIN',1,'Enunciados literales, sin frases hechas ni dobles sentidos. Glosario visual del tema siempre a la vista.',1),
 (1,'M-EST',2,'Agenda visual de la sesión en la pizarra y pasos numerados en cada tarea. Indicar siempre por dónde empezar.',3),
 (1,'M-REG',3,'Avisar con antelación de los cambios de actividad. Rincón tranquilo y cascos para quien los pida.',4);

INSERT INTO coexistence_rule (release_id, key, condition, effect, applies_to) VALUES
 (1,'C-REG-CRIT','{"all":[{"dim":3,"min_level":3},{"dim":6,"min_level":2}]}',
    'La reflexión se plantea sin respuesta correcta y como opcional.','{6}'),
 (1,'C-SOCIAL','{"all":[{"dim":5,"min_level":3}]}',
    'El trabajo con otros se plantea primero en pareja, con roles anticipados y siempre con una alternativa individual.','{5}'),
 (1,'C-SENSORIAL','{"all":[{"dim":3,"min_level":3}]}',
    'Las propuestas de trabajo en grupo se sitúan en espacios con pocos estímulos.','{3,5}');

SELECT setval(pg_get_serial_sequence('release','id'), (SELECT max(id) FROM release));
SELECT setval(pg_get_serial_sequence('test_item','id'), (SELECT max(id) FROM test_item));
SELECT setval(pg_get_serial_sequence('ai_prompt','id'), (SELECT max(id) FROM ai_prompt));
SELECT setval(pg_get_serial_sequence('action_sheet','id'), (SELECT max(id) FROM action_sheet));
