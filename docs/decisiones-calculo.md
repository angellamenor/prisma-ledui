# Decisiones sobre el cálculo de niveles y las fichas

Acordadas el 26-11-2026. Las marcadas con ⚙ son parámetros del contenido
(se cambian sin tocar código y se revisarán tras el pilotaje).

## Cómo se calcula el nivel

**D1 · Discrepancia alumno/tutor.** Si las dos lecturas difieren en 2 niveles o más, no se
promedian: se muestra el nivel **más alto** como **provisional**, con las dos lecturas al lado,
y el caso queda resaltado hasta que tutor y orientación lo marcan como revisado.
⚙ `discrepancy_policy = 'max'`

**D2 · «Solo docente».** Nunca se avisa de «posible nivel 4»: el aviso exige que coincidan
alumno y tutor. El tutor puede llevar el caso a orientación por su cuenta.
⚙ `l4_teacher_only = false`

**D3 · Pesos alumno / tutor.** ⚙
| Etapa | Alumno | Tutor |
|---|---|---|
| Infantil | — | 100 % |
| Primaria | 35 % | 65 % |
| Secundaria y FP | 50 % | 50 % |

**D4 · Umbrales.** ⚙ Nivel 2 desde 0,35 · nivel 3 desde 0,65 · posible nivel 4 desde 0,85
(ambas fuentes). Orientativamente: «a veces» en todo → nivel 1; «con frecuencia» en todo → nivel 3.

## Qué recibe cada nivel

**D5 · Nivel 1.** Sin ficha individual. En la ficha del alumno solo aparecen las dimensiones
de nivel 2 y 3. El nivel 1 lo cubre el plan de aula y se ve en el hexágono.

**D6 · Niveles 2 y 3: fichas distintas.**
- Nivel 2: *cuándo intervenir*, en momentos concretos y cuando hace falta.
- Nivel 3: apoyo sistemático y planificado, en todas las sesiones.
Hay que redactar 10 fichas de apoyo (5 dimensiones × 2 niveles) más las 2 de Pensamiento crítico.

**D7 · Pensamiento crítico (dimensión potenciadora).**
- Nivel 2: profundidad puntual (preguntas abiertas y dilemas breves, opcionales, en algunas tareas).
- Nivel 3: ampliación en cada tarea + autonomía (elegir enfoque o formato, o proponer su propia pregunta).
- Si Regulación está alta: el reto es siempre opcional y sin respuesta correcta (regla de convivencia).

**D8 · Nivel 4: resumen funcional para orientación.** Incluye:
1. Dimensiones afectadas y hexágono completo.
2. Las dos lecturas (alumno y tutor) con las respuestas concretas a cada ítem.
3. Observaciones del tutor (texto libre, opcional), con el aviso «No incluyas diagnósticos ni datos clínicos».
4. Al pie: «Resumen funcional de necesidades en el aula. No es un diagnóstico ni una evaluación psicopedagógica.»

No se incluyen historia de ajustes ni medidas probadas: se comentan en la reunión con orientación.
El resumen se queda en el equipo del tutor.

## El test

**D9 · Número de ítems por dimensión.** ⚙
| | Primaria | Secundaria y FP | Infantil |
|---|---|---|---|
| Test del alumno | 3 (18 ítems, ~12 min) | 4 (24 ítems, ~15 min) | — |
| Cuestionario del tutor | 5 (30 ítems) | 5 (30 ítems) | 5 (30 ítems) |

**D10 · Puntuación de las opciones.** ⚙ Pauta común: 0 la respuesta esperada, 1 la que muestra
la dificultad típica de la dimensión y 0,5 por defecto para otras respuestas incorrectas.
Orientación revisa cada ítem y puede cambiarla. «No lo sé» no puntúa.
El test se afinará de forma continua.

## Pendiente derivado de estas decisiones
- Actualizar el documento técnico: «entre 3 y 4 ítems» → D9 (y que el cuestionario del tutor
  tiene 5); resumen del nivel 4 según D8.
- Contenido 0.2: «Va a empezar a llover» pasa de 0,7 a 0,5 (D10); redactar fichas de nivel 2
  (D6) y de Pensamiento crítico (D7); ítems del tutor hasta 5 por dimensión (D9).
