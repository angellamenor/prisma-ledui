// Tipos del paquete de contenido (lo que devuelve GET /content/{versión})
// y de los resultados del motor. Solo lo que el motor necesita.

export type DimNum = 1 | 2 | 3 | 4 | 5 | 6;
export type Level = 1 | 2 | 3 | 4;
export type StageCode = 'infantil' | 'primaria' | 'secundaria' | 'fp';

export interface ScoringConfig {
  threshold_level2: number;   // puntuación 0..1 a partir de la cual es nivel 2
  threshold_level3: number;   // … nivel 3
  possible_l4_min: number;    // ambas fuentes ≥ → «posible nivel 4»
  discrepancy_levels: number; // diferencia de niveles que impide promediar
  min_answered_ratio: number; // proporción mínima de ítems respondidos para usar una fuente
  /** Qué nivel provisional se muestra cuando hay discrepancia (pendiente de decidir) */
  discrepancy_policy?: 'max' | 'teacher' | 'student';
  /** ¿Puede marcarse «posible nivel 4» solo con la lectura del tutor? */
  l4_teacher_only?: boolean;
}

export interface Stage {
  code: StageCode;
  student_test: 'none' | 'visual' | 'full';
  weight_student: number; // peso del tutor = 1 − weight_student
}

export interface Dimension {
  num: DimNum;
  code: string;
  name: string;
  short_name: string;
  kind: 'support' | 'enhancer';
}

export interface TestOption { score: number | null; sort: number }
export interface TestItem {
  key: string;
  dimension_num: DimNum;
  stages: StageCode[];
  options: TestOption[];
}

export interface ObservationItem {
  key: string;
  dimension_num: DimNum;
  stages: StageCode[];
  reversed: boolean;
}

export interface CoexistenceRule {
  key: string;
  condition: { all: { dim: DimNum; min_level: Level }[] };
  effect: string;
  applies_to: DimNum[];
}

export interface PriorityBand { min_ratio: number; label: string }

export interface ContentPack {
  version: string;
  scoring: ScoringConfig;
  stages: Stage[];
  dimensions: Dimension[];
  test_items: TestItem[];
  observation_items: ObservationItem[];
  coexistence: CoexistenceRule[] | null;
  priority_bands: PriorityBand[];
}

// ---------------------------------------------------------------- entradas

/** Respuestas del alumno: clave del ítem → posición de la opción elegida (sort), o null si no respondió */
export type StudentAnswers = Record<string, number | null>;
/** Respuestas del tutor: clave del ítem → 0 nunca · 1 a veces · 2 con frecuencia · 3 casi siempre */
export type TeacherAnswers = Record<string, 0 | 1 | 2 | 3>;

export type Modality = 'full' | 'teacher_only';

// --------------------------------------------------------------- resultados

export interface SourceReading {
  score: number;          // 0..1
  level: 1 | 2 | 3;
  answered: number;
  total: number;
}

export interface DimensionResult {
  dim: DimNum;
  student: SourceReading | null;  // null si no hay test o no hay respuestas suficientes
  teacher: SourceReading | null;
  combinedScore: number | null;   // null si hay discrepancia (no se promedia)
  measured: 1 | 2 | 3;            // nivel que propone la herramienta
  discrepancy: boolean;           // alumno y tutor difieren: el nivel es provisional (el más alto)
  possibleL4: boolean;
}

export type ReviewReason = 'level3' | 'discrepancy' | 'possible_l4';

export interface Profile {
  contentVersion: string;
  stage: StageCode;
  modality: Modality;
  dims: DimensionResult[];
  /** Nivel final por dimensión: el medido, salvo ajuste del tutor (o nivel 4 con orientación) */
  adjusted: Record<DimNum, Level>;
  /** Motivos pendientes de revisar con orientación (solo dimensiones de apoyo) */
  review: { reason: ReviewReason; dim: DimNum }[];
  /** Dimensiones ya revisadas por tutor y orientación: dejan de generar avisos */
  reviewed: DimNum[];
}
