import { describe, expect, it } from 'vitest';
import {
  activeCoexistence, adjustLevel, computeProfile, groupSummary, isProvisional, level4Dims,
  markReviewed, planCoverage, rankMeasures, sheetsFor,
} from '../src/engine';
import type { ContentPack, DimNum, StudentAnswers, TeacherAnswers } from '../src/engine';

// ---------------------------------------------------------------- paquete de prueba
// 3 ítems del alumno y 3 del tutor por dimensión. Opciones: 1 → 0 · 2 → 0,5 · 3 → 1 · 4 → «No lo sé».
const DIMS: DimNum[] = [1, 2, 3, 4, 5, 6];
const ALL = ['infantil', 'primaria', 'secundaria', 'fp'] as const;

const pack: ContentPack = {
  version: 'test',
  scoring: { threshold_level2: 0.35, threshold_level3: 0.65, possible_l4_min: 0.85,
             discrepancy_levels: 2, min_answered_ratio: 0.5, discrepancy_policy: 'max', l4_teacher_only: false },
  stages: [
    { code: 'infantil', student_test: 'none', weight_student: 0 },
    { code: 'primaria', student_test: 'visual', weight_student: 0.35 },
    { code: 'secundaria', student_test: 'full', weight_student: 0.5 },
    { code: 'fp', student_test: 'full', weight_student: 0.5 },
  ],
  dimensions: DIMS.map(n => ({ num: n, code: `d${n}`, name: `D${n}`, short_name: `D${n}`,
                               kind: n === 6 ? 'enhancer' : 'support' })),
  test_items: DIMS.flatMap(d => [1, 2, 3].map(i => ({
    key: `S${d}-${i}`, dimension_num: d, stages: ['primaria', 'secundaria', 'fp'],
    options: [{ sort: 1, score: 0 }, { sort: 2, score: 0.5 }, { sort: 3, score: 1 }, { sort: 4, score: null }],
  }))),
  observation_items: DIMS.flatMap(d => [1, 2, 3].map(i => ({
    key: `T${d}-${i}`, dimension_num: d, stages: [...ALL], reversed: false,
  }))),
  coexistence: [
    { key: 'C-REG-CRIT', condition: { all: [{ dim: 3, min_level: 3 }, { dim: 6, min_level: 2 }] },
      effect: 'La reflexión se plantea sin respuesta correcta y como opcional.', applies_to: [6] },
  ],
  priority_bands: [{ min_ratio: 0, label: 'baja' }, { min_ratio: 0.2, label: 'media' }, { min_ratio: 0.4, label: 'alta' }],
};

/** Respuestas del alumno: para cada dimensión, la opción que elige en sus 3 ítems. */
const student = (picks: Partial<Record<DimNum, number>>): StudentAnswers =>
  Object.fromEntries(DIMS.flatMap(d => [1, 2, 3].map(i => [`S${d}-${i}`, picks[d] ?? 1])));
/** Respuestas del tutor: para cada dimensión, la frecuencia que marca en sus 3 ítems. */
const teacher = (freq: Partial<Record<DimNum, 0 | 1 | 2 | 3>>): TeacherAnswers =>
  Object.fromEntries(DIMS.flatMap(d => [1, 2, 3].map(i => [`T${d}-${i}`, freq[d] ?? 0])));

const levels = (p: { adjusted: Record<DimNum, number> }) => DIMS.map(d => p.adjusted[d]);

// ---------------------------------------------------------------- perfiles de la demo
const lucia = computeProfile(pack, 'primaria', 'full',
  student({ 1: 3, 2: 3, 4: 2 }), teacher({ 1: 2, 2: 2, 4: 1 }));
const hugo = computeProfile(pack, 'primaria', 'full',
  student({ 3: 3, 5: 3, 6: 2 }), teacher({ 3: 3, 5: 2, 6: 1 }));
const adrian = computeProfile(pack, 'primaria', 'full',
  student({}), teacher({ 1: 3 }));

describe('Perfiles individuales', () => {
  it('Lucía: apoyo en Lingüística y Estructura (nivel 3), Multimodal (nivel 2)', () => {
    expect(levels(lucia)).toEqual([3, 3, 1, 2, 1, 1]);
    expect(lucia.review).toEqual([{ reason: 'level3', dim: 1 }, { reason: 'level3', dim: 2 }]);
  });

  it('Hugo: Regulación y Social en nivel 3, posible nivel 4 en Regulación, reto en P. crítico', () => {
    expect(levels(hugo)).toEqual([1, 1, 3, 1, 3, 2]);
    const reg = hugo.dims[2]!;
    expect(reg.possibleL4).toBe(true);
    expect(hugo.review).toContainEqual({ reason: 'possible_l4', dim: 3 });
  });

  it('Adrián: alumno y tutor difieren 2 niveles → no se promedia y se marca discrepancia', () => {
    const ling = adrian.dims[0]!;
    expect(ling.student?.level).toBe(1);
    expect(ling.teacher?.level).toBe(3);
    expect(ling.discrepancy).toBe(true);
    expect(ling.combinedScore).toBeNull();
    expect(ling.measured).toBe(3); // política 'max'
    expect(adrian.review).toContainEqual({ reason: 'discrepancy', dim: 1 });
  });

  it('Todos parten del nivel 1', () => {
    const p = computeProfile(pack, 'secundaria', 'full', student({}), teacher({}));
    expect(levels(p)).toEqual([1, 1, 1, 1, 1, 1]);
    expect(p.review).toEqual([]);
  });
});

describe('Fuentes y modalidades', () => {
  it('«Solo docente» ignora el test del alumno', () => {
    const p = computeProfile(pack, 'primaria', 'teacher_only', student({ 1: 3 }), teacher({}));
    expect(p.dims[0]!.student).toBeNull();
    expect(p.adjusted[1]).toBe(1);
  });

  it('En Infantil no hay test del alumno aunque llegue', () => {
    const p = computeProfile(pack, 'infantil', 'full', student({ 1: 3 }), teacher({ 1: 2 }));
    expect(p.dims[0]!.student).toBeNull();
    expect(p.adjusted[1]).toBe(3);
  });

  it('El peso depende de la etapa', () => {
    const s = student({ 1: 2 }), t = teacher({ 1: 1 }); // alumno 0,5 · tutor 0,333
    expect(computeProfile(pack, 'primaria', 'full', s, t).dims[0]!.combinedScore).toBeCloseTo(0.392, 2);
    expect(computeProfile(pack, 'secundaria', 'full', s, t).dims[0]!.combinedScore).toBeCloseTo(0.417, 2);
  });

  it('«No lo sé» no puntúa, y con pocas respuestas válidas se ignora la fuente', () => {
    const s = student({ 1: 4 }); s['S1-1'] = 3; // solo 1 de 3 respuestas válidas (< 50 %)
    const p = computeProfile(pack, 'primaria', 'full', s, teacher({ 1: 2 }));
    expect(p.dims[0]!.student).toBeNull();
    expect(p.dims[0]!.measured).toBe(3); // solo cuenta el tutor
  });

  it('Sin lectura del alumno, el posible nivel 4 depende de la configuración', () => {
    const t = teacher({ 3: 3 });
    expect(computeProfile(pack, 'primaria', 'teacher_only', {}, t).dims[2]!.possibleL4).toBe(false);
    const p2 = { ...pack, scoring: { ...pack.scoring, l4_teacher_only: true } };
    expect(computeProfile(p2, 'primaria', 'teacher_only', {}, t).dims[2]!.possibleL4).toBe(true);
  });
});

describe('Ajustes del tutor', () => {
  it('Se guardan el nivel medido y el ajustado', () => {
    const p = adjustLevel(pack, lucia, 4, 3);
    expect(p.dims[3]!.measured).toBe(2);
    expect(p.adjusted[4]).toBe(3);
    expect(p.review).toContainEqual({ reason: 'level3', dim: 4 });
  });

  it('El nivel 4 exige orientación y no existe en la dimensión potenciadora', () => {
    expect(() => adjustLevel(pack, hugo, 3, 4)).toThrow();
    const p = adjustLevel(pack, hugo, 3, 4, { withOrientation: true });
    expect(p.adjusted[3]).toBe(4);
    expect(p.review).not.toContainEqual({ reason: 'possible_l4', dim: 3 }); // ya resuelto
    expect(() => adjustLevel(pack, hugo, 6, 4, { withOrientation: true })).toThrow();
  });

  it('La dimensión potenciadora en nivel 3 no genera caso a revisar', () => {
    const p = adjustLevel(pack, lucia, 6, 3);
    expect(p.review.some(r => r.dim === 6)).toBe(false);
  });

  it('Reglas de convivencia: Regulación alta + reto → reflexión opcional', () => {
    expect(activeCoexistence(pack, lucia)).toEqual([]);
    expect(activeCoexistence(pack, hugo).map(r => r.key)).toEqual(['C-REG-CRIT']);
  });
});

describe('Decisiones del 26-11-2026', () => {
  it('D1 · Discrepancia: nivel más alto, provisional, hasta que se revisa', () => {
    expect(isProvisional(adrian, 1)).toBe(true);
    const r = markReviewed(pack, adjustLevel(pack, adrian, 1, 2), 1);
    expect(isProvisional(r, 1)).toBe(false);
    expect(r.review.some(x => x.dim === 1)).toBe(false);
    expect(r.dims[0]!.measured).toBe(3); // se conserva lo medido
    expect(r.adjusted[1]).toBe(2);       // y lo decidido
  });

  it('D2 · «Solo docente» nunca avisa de posible nivel 4', () => {
    const p = computeProfile(pack, 'primaria', 'teacher_only', {}, teacher({ 3: 3 }));
    expect(p.dims[2]!.possibleL4).toBe(false);
  });

  it('D5 · Solo hay fichas para los niveles 2 y 3', () => {
    expect(sheetsFor(lucia)).toEqual([{ dim: 1, level: 3 }, { dim: 2, level: 3 }, { dim: 4, level: 2 }]);
  });

  it('D8 · El nivel 4 genera resumen funcional, no ficha', () => {
    const p = adjustLevel(pack, hugo, 3, 4, { withOrientation: true });
    expect(level4Dims(p)).toEqual([3]);
    expect(sheetsFor(p).some(s => s.dim === 3)).toBe(false);
  });
});

describe('Plan para toda la clase', () => {
  const clase = [lucia, hugo, adrian];

  it('Cuenta cuántos alumnos necesitan apoyo y asigna prioridad', () => {
    const g = groupSummary(pack, clase);
    expect(g[0]).toMatchObject({ dim: 1, need: 2, distribution: { 1: 1, 2: 0, 3: 2, 4: 0 }, priority: 'alta' });
    expect(g[5]!.priority).toBe('Reto');
    expect(rankMeasures(g)[0]!.dim).toBe(1);
  });

  it('Calcula alumnos atendidos y adaptaciones ahorradas', () => {
    expect(planCoverage(clase, [1, 3])).toEqual({ covered: 3, savedAdaptations: 3 });
  });
});
