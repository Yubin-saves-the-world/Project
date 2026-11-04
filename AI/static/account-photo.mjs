/** The account photo flow shares the coach's in-memory authentication client. */
export function validatePhoto(file) {
  if (!file || file.size === 0) throw new Error('정면 사진을 선택해 주세요.');
  if (file.size > 10 * 1024 * 1024) throw new Error('사진 한 장은 10MB 이하여야 합니다.');
  if (!/\.(jpe?g|png)$/i.test(file.name) ||
      (file.type && !['image/jpeg', 'image/png'].includes(file.type))) {
    throw new Error('JPG 또는 PNG 사진을 선택해 주세요. HEIC는 JPG로 변환해 주세요.');
  }
}

function validId(value) { return Number.isInteger(value) && value > 0; }

export function measurementRows(result) {
  const unavailable = Array.isArray(result?.measures?.unavailable) ? result.measures.unavailable : [];
  return (Array.isArray(result?.measurement_report?.items) ? result.measurement_report.items : []).map(item => {
    const measured = item.status === 'measured' && Number.isFinite(item.value);
    const reason = unavailable.find(entry => entry.key === item.key)?.reason;
    const guidance = reason === 'SIDE_PHOTO_MISSING' ? '측면 사진을 함께 선택하면 측정할 수 있습니다.' :
      reason === 'LOW_CONFIDENCE' ? '측면의 귀와 어깨가 선명하게 보이도록 다시 촬영해 주세요.' :
      '촬영 조건 또는 관절 검출 상태를 확인해 주세요.';
    return {...item, measured, reason: measured ? null : reason || null,
      display_value: measured ? item.display_value || String(item.value) : '이번 사진에서 측정되지 않음',
      description: measured ? item.description || item.meaning || '' : `${guidance}${reason ? ` (${reason})` : ''}`};
  });
}

export async function waitForAnalysis(client, ticket, {
  timeoutMs = 100000, clock = () => Date.now(),
  sleep = ms => new Promise(resolve => setTimeout(resolve, ms)), onProgress = () => {},
} = {}) {
  if (!validId(ticket?.analysis_id)) throw new Error('분석 접수 응답을 확인하지 못했습니다. 목록을 새로고침하세요.');
  const deadline = clock() + timeoutMs;
  while (clock() < deadline) {
    const result = await client.analysis(ticket.analysis_id);
    if (result?.analysis_id !== ticket.analysis_id) throw new Error('분석 번호가 다른 응답입니다. 다시 확인해 주세요.');
    if (result.status === 'done') return result;
    if (result.status === 'failed') {
      throw new Error(`${result.error_message || '사진을 측정하지 못했습니다.'} (${result.error_code || 'AI_FAILED'})`);
    }
    if (result.status !== 'pending') throw new Error('분석 상태를 확인하지 못했습니다. 기록을 다시 확인하세요.');
    onProgress(ticket.analysis_id);
    await sleep(Math.min(2000, Math.max(0, deadline - clock())));
  }
  throw new Error('결과 대기 시간이 지났습니다. 재분석 전에 ‘마지막 분석 결과 확인’을 눌러 주세요.');
}

export function initializePhotoPanel({doc, client, run, setStatus, onCompleted}) {
  const find = selector => doc.querySelector(selector);
  let lastTicket = null;
  let lastResult = null;

  function renderResult(result) {
    lastResult = result;
    const container = find('#photo-result');
    container.replaceChildren();
    const heading = doc.createElement('h3');
    heading.textContent = `사진 분석 #${result.analysis_id} · 측정 완료`;
    container.append(heading);
    const report = result.measurement_report;
    const summary = doc.createElement('p');
    summary.textContent = report?.summary || '저장된 결과를 아래 JSON 파일로 확인할 수 있습니다.';
    container.append(summary);
    const grid = doc.createElement('div');
    grid.className = 'measurement-grid';
    for (const item of measurementRows(result)) {
      const card = doc.createElement('article');
      card.className = 'measurement';
      const title = doc.createElement('h4');
      title.textContent = item.title || item.key || '사진 측정';
      const value = doc.createElement('strong');
      value.textContent = item.display_value;
      const description = doc.createElement('p');
      description.textContent = item.description || item.reason || '측정 조건을 확인해 주세요.';
      const limitation = doc.createElement('small');
      limitation.textContent = item.limitation || '';
      card.append(title, value, description, limitation);
      grid.append(card);
    }
    container.append(grid);
    const note = doc.createElement('p');
    note.className = 'help';
    note.textContent = report?.interpretation || '사진의 기울기·비율 참고 수치입니다. 건강·근육 발달 점수는 제공하지 않습니다.';
    container.append(note);
    const quality = result.photo_quality;
    if (quality && typeof quality === 'object') {
      const details = doc.createElement('details');
      const label = doc.createElement('summary');
      label.textContent = '사진 검사와 측정 조건';
      const text = doc.createElement('p');
      text.className = 'help';
      const count = Number.isInteger(quality.required_landmarks_visible) && Number.isInteger(quality.required_landmarks_total) ?
        `필수 관절 ${quality.required_landmarks_visible}/${quality.required_landmarks_total}개 확인. ` : '';
      const size = Number.isInteger(quality.width_px) && Number.isInteger(quality.height_px) ?
        `처리 영상 ${quality.width_px}×${quality.height_px}px. ` : '';
      text.textContent = count + size + '관절 인식 점수는 측정 정확도나 건강 점수가 아닙니다. 정면 여부·의복·가림은 직접 확인해 주세요.';
      details.append(label, text);
      container.append(details);
    }
    find('#download-analysis').hidden = false;
    find('#photo-results-panel').hidden = false;
  }

  async function checkLast() {
    const result = await waitForAnalysis(client, lastTicket, {
      onProgress: id => setStatus(`분석 #${id} 측정 중입니다. 사진은 서버에서 처리하고 있습니다…`),
    });
    renderResult(result);
    await onCompleted(result);
    find('#photo-results-panel').scrollIntoView({block: 'start'});
  }

  find('#photo-upload').onsubmit = event => {
    event.preventDefault();
    run(async () => {
      const front = find('#front-photo').files[0];
      const side = find('#side-photo').files[0];
      validatePhoto(front);
      if (side) validatePhoto(side);
      setStatus('정면 사진을 저장하는 중입니다…');
      const uploadedFront = await client.uploadPhoto(front, 'front');
      if (!validId(uploadedFront?.photo_id)) throw new Error('정면 사진 저장 응답을 확인하지 못했습니다. 보관 사진 목록을 확인하세요.');
      let sideId = null;
      if (side) {
        setStatus('측면 사진을 저장하는 중입니다…');
        const uploadedSide = await client.uploadPhoto(side, 'side');
        if (!validId(uploadedSide?.photo_id)) throw new Error('측면 사진 저장 응답을 확인하지 못했습니다. 보관 사진 목록을 확인하세요.');
        sideId = uploadedSide.photo_id;
      }
      setStatus('사진 분석을 접수하고 있습니다…');
      const ticket = await client.startAnalysis(uploadedFront.photo_id, sideId);
      if (!validId(ticket?.analysis_id)) throw new Error('분석 접수 결과를 확인하지 못했습니다. 재시도 전에 기록을 새로고침하세요.');
      lastTicket = ticket;
      lastResult = null;
      find('#photo-results-panel').hidden = true;
      find('#check-analysis').hidden = false;
      find('#photo-upload').reset();
      await checkLast();
    });
  };

  find('#check-analysis').onclick = () => run(async () => {
    if (lastTicket) await checkLast();
  });

  async function loadPhotos() {
    const photos = await client.photos();
    const container = find('#saved-photos');
    container.replaceChildren();
    if (!photos.length) {
      container.textContent = '보관 중인 현재 사진이 없습니다.';
      return;
    }
    for (const photo of photos) {
      if (!validId(photo?.photo_id)) continue;
      const row = doc.createElement('div');
      row.className = 'saved-photo';
      const label = doc.createElement('span');
      label.textContent = `사진 #${photo.photo_id} · ${{front: '정면', side: '측면', back: '후면'}[photo.side] || '기타'}`;
      const remove = doc.createElement('button');
      remove.className = 'secondary danger';
      remove.type = 'button';
      remove.textContent = '사진 삭제';
      remove.setAttribute('aria-label', `사진 #${photo.photo_id} 삭제`);
      remove.onclick = () => {
        if (!globalThis.confirm(`사진 #${photo.photo_id} 원본을 삭제할까요? 저장된 측정 기록은 유지됩니다.`)) return;
        run(async () => {
          await client.deletePhoto(photo.photo_id);
          // The DELETE success is independent of a later list refresh.
          row.remove();
          setStatus(`사진 #${photo.photo_id} 원본을 삭제했습니다. 저장된 측정 기록은 유지됩니다.`);
        });
      };
      row.append(label, remove);
      container.append(row);
    }
  }
  find('#load-photos').onclick = () => run(async () => {
    await loadPhotos();
    setStatus('보관 사진 목록을 불러왔습니다. 불필요한 원본을 삭제할 수 있습니다.');
  });
  find('#download-analysis').onclick = () => {
    if (!lastResult) return;
    const url = URL.createObjectURL(new Blob([JSON.stringify(lastResult, null, 2)], {type: 'application/json'}));
    const link = doc.createElement('a');
    link.href = url;
    link.download = `movid-analysis-${lastResult.analysis_id}.json`;
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  };
  return {reset() {
    lastTicket = null;
    lastResult = null;
    find('#photo-upload').reset();
    find('#photo-result').replaceChildren();
    find('#saved-photos').replaceChildren();
    find('#photo-results-panel').hidden = true;
    find('#check-analysis').hidden = true;
    find('#download-analysis').hidden = true;
  }};
}
