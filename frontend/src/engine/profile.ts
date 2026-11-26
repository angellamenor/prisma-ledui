// Motor de cálculo: de las respuestas del alumno y del tutor a un perfil por dimensiones.
// Sigue el apartado 10.3 del documento técnico. Todo umbral o peso viene del paquete de contenido.

import type {
  ContentPack, DimNum, DimensionResult, Level, Modality, Profile, ReviewReason,
  SourceReading, StageCode, StudentAnswers, TeacherAnswers,
} from './types';

const DIMS: DimNum[] = [1, 2, 3, 4, 5, 6];
const round = (x: number) => Math.round(x * 1000) / 1000;

export function scoreToLevel(score: number, pack: ContentPack): 1 | 2 | 3 {
  const s = pack.scoring;
  if (score >= s.threshold_level3) return 3;
  if (score >= s.threshold_level2) return 2;
  return 1;
}

/** Lectura del alumno en una dimensión: media de las puntuaciones de las opciones elegidas. */
export function studentReading(
  pack: ContentPack, stage: StageCode, dim: DimNum, answers: StudentAnswers,
): SourceReading | null {
  const items = pack.test_items.filter(i => i.dimension_num === dim && i.stages.includes(stage));
  if (items.length === 0) return null;
  const scores: number[] = [];
  for (const it of items) {
    const pick = answers[it.key];
    if (pick == null) continue;
    const opt = it.options.find(o => o.sort === pick);
    if (opt && opt.score != null) scores.push(opt.score); // «No lo sé» no puntúa
  }
  if (scores.length / items.length < pack.scoring.min_answered_ratio) return null;
  const score = round(scores.reduce((a, b) => a + b, 0) / scores.length);
  return { score, level: scoreToLevel(score, pack), answered: scores.length, total: items.length };
}

/** Lectura del tutor en una dimensión: media de frecuencias normalizada a 0..1. */
export function teacherReading(
  pack: ContentPack, stage: StageCode, dim: DimNum, answers: TeacherAnswers,
): SourceReading | null {
  const items = pack.observation_items.filter(i => i.dimension_num === dim && i.stages.includes(stage));
  if (items.length === 0) return null;
  const scores: number[] = [];
  for (const it of items) {
    const v = answers[it.key];
    if (v == null) continue;
    const n = v / 3;
    scores.push(it.reversed ? 1 - n : n);
  }
  if (scores.length / items.length < pack.scoring.min_answered_ratio) return null;
  const score = round(scores.reduce((a, b) => a + b, 0) / scores.length);
  return { score, level: scoreToLevel(score, pack), answered: scores.length, total: items.length };
}

export function computeDimension(
  pack: ContentPack, stage: StageCode, modality: Modality, dim: DimNum,
  student: StudentAnswers, teacher: TeacherAnswers,
): DimensionResult {
  const st = pack.stages.find(s => s.code === stage);
  if (!st) throw new Error(`Etapa desconocida: ${stage}`);
  const cfg = pack.scoring;

  const useStudent = modality === 'full' && st.student_test !== 'none';
  const s = useStudent ? studentReading(pack, stage, dim, student) : null;
  const t = teacherReading(pack, stage, dim, teacher);

  // Sin ninguna lectura válida: nivel base
  if (!s && !t) {
    return { dim, student: null, teacher: null, combinedScore: null, measured: 1, discrepancy: false, possibleL4: false };
  }

  // Solo una fuente: se usa esa
  if (!s || !t) {
    const only = (s ?? t)!;
    const possibleL4 = !s && !!t && !!cfg.l4_teacher_only && t.score >= cfg.possible_l4_min;
    return { dim, student: s, teacher: t, combinedScore: only.score, measured: only.level, discrepancy: false, possibleL4 };
  }

  // Dos fuentes
  const possibleL4 = s.score >= cfg.possible_l4_min && t.score >= cfg.possible_l4_min;
  if (Math.abs(s.level - t.level) >= cfg.discrepancy_levels) {
    // No se promedia: se muestran las dos lecturas y un nivel provisional según la política
    const policy = cfg.discrepancy_policy ?? 'max';
    const measured = policy === 'teacher' ? t.level : policy === 'student' ? s.level : (Math.max(s.level, t.level) as 1 | 2 | 3);
    return { dim, student: s, teacher: t, combinedScore: null, measured, discrepancy: true, possibleL4 };
  }
  const w = st.weight_student;
  const combined = round(w * s.score + (1 - w) * t.score);
  return { dim, student: s, teacher: t, combinedScore: combined, measured: scoreToLevel(combined, pack), discrepancy: false, possibleL4 };
}

export function reviewReasons(
  pack: ContentPack, dims: DimensionResult[], adjusted: Record<DimNum, Level>, reviewed: DimNum[] = [],
) {
  const support = new Set(pack.dimensions.filter(d => d.kind === 'support').map(d => d.num));
  const out: { reason: ReviewReason; dim: DimNum }[] = [];
  for (const d of dims) {
    if (!support.has(d.dim)) continue; // la dimensión potenciadora no genera casos a revisar
    if (reviewed.includes(d.dim)) continue; // ya revisada con orientación
    if (adjusted[d.dim] === 3) out.push({ reason: 'level3', dim: d.dim });
    if (d.discrepancy) out.push({ reason: 'discrepancy', dim: d.dim });
    if (d.possibleL4 && adjusted[d.dim] !== 4) out.push({ reason: 'possible_l4', dim: d.dim });
  }
  return out;
}

export function computeProfile(
  pack: ContentPack, stage: StageCode, modality: Modality,
  student: StudentAnswers, teacher: TeacherAnswers,
): Profile {
  const dims = DIMS.map(d => computeDimension(pack, stage, modality, d, student, teacher));
  const adjusted = Object.fromEntries(dims.map(d => [d.dim, d.measured])) as Record<DimNum, Level>;
  return { contentVersion: pack.version, stage, modality, dims, adjusted, reviewed: [],
           review: reviewReasons(pack, dims, adjusted) };
}

/**
 * El tutor sube o baja un nivel. Se conserva el medido (en dims) y cambia el ajustado.
 * El nivel 4 solo puede activarse con orientación, y nunca en la dimensión potenciadora.
 */
export function adjustLevel(
  pack: ContentPack, profile: Profile, dim: DimNum, level: Level,
  opts: { withOrientation?: boolean } = {},
): Profile {
  if (level === 4) {
    if (!opts.withOrientation) throw new Error('El nivel 4 solo lo activan tutor y orientador conjuntamente');
    if (pack.dimensions.find(d => d.num === dim)?.kind === 'enhancer') throw new Error('La dimensión potenciadora no tiene nivel 4');
  }
  const adjusted = { ...profile.adjusted, [dim]: level };
  return { ...profile, adjusted, review: reviewReasons(pack, profile.dims, adjusted, profile.reviewed) };
}

/**
 * Tutor y orientación han revisado una dimensión (y, si procede, ajustado su nivel).
 * El aviso desaparece; el nivel deja de ser provisional.
 */
export function markReviewed(pack: ContentPack, profile: Profile, dim: DimNum): Profile {
  const reviewed = profile.reviewed.includes(dim) ? profile.reviewed : [...profile.reviewed, dim];
  return { ...profile, reviewed, review: reviewReasons(pack, profile.dims, profile.adjusted, reviewed) };
}

/** ¿El nivel de esta dimensión es provisional? (discrepancia aún sin revisar) */
export function isProvisional(profile: Profile, dim: DimNum): boolean {
  return !!profile.dims.find(d => d.dim === dim)?.discrepancy && !profile.reviewed.includes(dim);
}

/**
 * Fichas que ve el tutor para este alumno: solo dimensiones en nivel 2 o 3
 * (el nivel 1 lo cubre el plan de aula; el nivel 4 genera el resumen funcional).
 */
export function sheetsFor(profile: Profile): { dim: DimNum; level: 2 | 3 }[] {
  return ([1, 2, 3, 4, 5, 6] as DimNum[])
    .filter(d => profile.adjusted[d] === 2 || profile.adjusted[d] === 3)
    .map(d => ({ dim: d, level: profile.adjusted[d] as 2 | 3 }));
}

/** Dimensiones en nivel 4: generan resumen funcional para orientación, no fichas. */
export function level4Dims(profile: Profile): DimNum[] {
  return ([1, 2, 3, 4, 5, 6] as DimNum[]).filter(d => profile.adjusted[d] === 4);
}

/** Reglas de convivencia que se cumplen para un perfil (avisos para las fichas). */
export function activeCoexistence(pack: ContentPack, profile: Profile) {
  return (pack.coexistence ?? []).filter(r =>
    r.condition.all.every(c => profile.adjusted[c.dim] >= c.min_level));
}
