// Persist only explicitly selected numeric observations, never images or review tokens.
export const KEY = 'movid.numeric-history.v1';
const keys = ['shoulder_tilt_deg','pelvis_tilt_deg','shoulder_hip_ratio','torso_leg_ratio',
  'neck_forward_deg','body_axis_tilt_deg','arm_projected_length_difference_pct','leg_projected_length_difference_pct'];
export function clean(data) {
  if (!data || data.status !== 'done') throw Error('완료된 분석 결과만 저장할 수 있습니다.');
  const measures = {};
  for (const k of keys) { const v=data.measures?.[k]; measures[k]=typeof v==='number' && Number.isFinite(v)?v:null; }
  if (!Object.values(measures).some(v=>v!==null)) throw Error('저장할 측정값이 없습니다.');
  return {status:'done',measures,measurement_version:String(data.measurement_version||'unknown').slice(0,50)};
}
export function load(storage=localStorage) {
  try {
    const rows=JSON.parse(storage.getItem(KEY)||'[]');
    if(!Array.isArray(rows))return [];
    return rows.slice(0,30).flatMap(r=>{
      try {if(!r||typeof r.id!=='string'||!/^[-\w]{1,64}$/.test(r.id)||!Number.isFinite(Date.parse(r.saved_at)))return [];
        return [{id:r.id,saved_at:r.saved_at,...clean(r)}];}catch{return [];}
    });
  } catch{return [];}
}
export function save(data,storage=localStorage) {
  const row={id:crypto.randomUUID(),saved_at:new Date().toISOString(),...clean(data)};
  const rows=[row,...load(storage)].slice(0,30);
  storage.setItem(KEY,JSON.stringify(rows)); return row;
}
export function remove(id,storage=localStorage) {
  storage.setItem(KEY,JSON.stringify(load(storage).filter(r=>r.id!==id)));
}
