// Vista «Plan para toda la clase»: suma los perfiles del grupo (apartado 10.5 del documento técnico).

import type { ContentPack, DimNum, Profile } from './types';

const DIMS: DimNum[] = [1, 2, 3, 4, 5, 6];

export interface GroupDimension {
  dim: DimNum;
  need: number;                          // alumnos con nivel ≥ 2
  ratio: number;                         // need / total
  distribution: { 1: number; 2: number; 3: number; 4: number };
  priority: string;                      // etiqueta según las bandas del contenido
}

export function groupSummary(pack: ContentPack, profiles: Profile[]): GroupDimension[] {
  const total = profiles.length;
  const bands = [...pack.priority_bands].sort((a, b) => b.min_ratio - a.min_ratio);
  const enhancer = new Set(pack.dimensions.filter(d => d.kind === 'enhancer').map(d => d.num));
  return DIMS.map(dim => {
    const distribution = { 1: 0, 2: 0, 3: 0, 4: 0 };
    for (const p of profiles) distribution[p.adjusted[dim]]++;
    const need = total - distribution[1];
    const ratio = total ? need / total : 0;
    const priority = enhancer.has(dim) ? 'Reto' : (bands.find(b => ratio >= b.min_ratio)?.label ?? '');
    return { dim, need, ratio, distribution, priority };
  });
}

/** Medidas de aula ordenadas por número de alumnos que las necesitan. */
export function rankMeasures(summary: GroupDimension[]): GroupDimension[] {
  return [...summary].sort((a, b) => b.need - a.need || a.dim - b.dim);
}

/**
 * Efecto de un plan de aula con las dimensiones elegidas:
 *  - covered: alumnos con al menos una necesidad atendida por el plan
 *  - savedAdaptations: adaptaciones individuales que no hace falta preparar por separado
 */
export function planCoverage(profiles: Profile[], chosen: DimNum[]) {
  const covered = profiles.filter(p => chosen.some(d => p.adjusted[d] >= 2)).length;
  const savedAdaptations = chosen.reduce((s, d) => s + profiles.filter(p => p.adjusted[d] >= 2).length, 0);
  return { covered, savedAdaptations };
}
