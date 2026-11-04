/** Account coach UI. Credentials remain in this page's memory only. */
import {initializePhotoPanel} from './account-photo.mjs';
export class ApiError extends Error {
  constructor(message, status = 0) {
    super(message);
    this.status = status;
  }
}

function messagesFrom(value) {
  if (!Array.isArray(value) || value.some(message => !message ||
      !['user', 'assistant'].includes(message.role) || typeof message.content !== 'string')) {
    throw new ApiError('대화 응답을 읽지 못했습니다. 기록을 다시 불러와 주세요.', 502);
  }
  return value;
}

export function mergeSavedTurn(history, pair) {
  const messages = messagesFrom([pair?.user_message, pair?.assistant_message]);
  if (messages[0].role !== 'user' || messages[1].role !== 'assistant') {
    throw new ApiError('저장 결과를 확인하지 못했습니다. 재전송 전에 기록을 새로고침해 주세요.', 502);
  }
  return [...history, ...messages].slice(-20);
}

export function createCoachClient({fetchImpl = globalThis.fetch, onUnauthorized = () => {}, timeoutMs = 90000} = {}) {
  let token = null;

  async function request(path, method = 'GET', body, waitMs = timeoutMs) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), waitMs);
    const multipart = body instanceof FormData;
    try {
      const response = await fetchImpl(path, {
        method, cache: 'no-store', credentials: 'omit', signal: controller.signal,
        headers: {
          ...(token ? {Authorization: `Bearer ${token}`} : {}),
          ...(body && !multipart ? {'Content-Type': 'application/json'} : {}),
        },
        ...(body ? {body: multipart ? body : JSON.stringify(body)} : {}),
      });
      // An expired session must be cleared even if the error body is unreadable.
      if (response.status === 401) {
        token = null;
        onUnauthorized();
        throw new ApiError('로그인 정보가 만료됐거나 올바르지 않습니다. 다시 로그인하세요.', 401);
      }
      if (response.status === 204 && response.ok) return null;
      let data;
      try {
        data = await response.json();
      } catch (error) {
        if (error.name === 'AbortError') throw error;
        throw new ApiError('응답을 읽지 못했습니다. AI 호환 서버 주소를 확인하세요.', response.status);
      }
      if (!response.ok) {
        const message = data?.message || data?.detail?.message ||
          (response.status === 404 ? '요청한 기능 또는 기록을 찾지 못했습니다.' : '요청을 처리하지 못했습니다.');
        throw new ApiError(message, response.status);
      }
      return data;
    } catch (error) {
      if (error.name === 'AbortError') {
        throw new ApiError('응답 대기 시간이 지났습니다. 기록을 새로고침해 저장 여부를 먼저 확인하세요.');
      }
      if (error instanceof ApiError) throw error;
      throw new ApiError('서버에 연결하지 못했습니다. 실행 상태를 확인하고 다시 시도하세요.');
    } finally {
      clearTimeout(timer);
    }
  }

  return {
    clearToken() { token = null; },
    async login(email, password) {
      token = null;
      const data = await request('/api/auth/login', 'POST', {email, password});
      if (typeof data?.access_token !== 'string' || !data.access_token.trim()) {
        throw new ApiError('인증 토큰이 없는 응답입니다.', 502);
      }
      token = data.access_token;
    },
    async history() {
      const data = await request('/api/ai-coach/messages');
      return messagesFrom(data?.messages);
    },
    async analyses() {
      const data = await request('/api/body-analyses?page_size=100');
      if (!Array.isArray(data?.items)) throw new ApiError('사진 분석 목록을 읽지 못했습니다.', 502);
      return data.items.filter(item => item?.status === 'done' &&
        Number.isInteger(item.analysis_id) && item.analysis_id > 0);
    },
    send(content, profile, analysisId) {
      return request('/api/ai-coach/messages', 'POST', {content, profile, analysis_id: analysisId});
    },
    async photos() {
      const data = await request('/api/photos?page_size=100');
      if (!Array.isArray(data?.items)) throw new ApiError('사진 목록을 읽지 못했습니다.', 502);
      return data.items;
    },
    uploadPhoto(file, side) {
      const form = new FormData();
      form.set('image', file);
      form.set('type', 'current');
      form.set('side', side);
      return request('/api/photos', 'POST', form);
    },
    deletePhoto(id) { return request(`/api/photos/${id}`, 'DELETE'); },
    startAnalysis(frontId, sideId = null) {
      return request('/api/body-analyses/photo', 'POST', {photo_id: frontId, side_photo_id: sideId});
    },
    analysis(id) { return request(`/api/body-analyses/${id}`, 'GET', undefined, 10000); },
    async deleteHistory() {
      const data = await request('/api/ai-coach/messages', 'DELETE');
      if (!Number.isInteger(data?.deleted) || data.deleted < 0) {
        throw new ApiError('삭제 결과를 확인하지 못했습니다. 기록을 새로고침해 주세요.', 502);
      }
      return data;
    },
  };
}

export async function loadWorkspace(client) {
  const [history, analyses] = await Promise.allSettled([client.history(), client.analyses()]);
  if (history.status === 'rejected') throw history.reason;
  if (analyses.status === 'rejected' && analyses.reason.status === 401) throw analyses.reason;
  return {
    messages: history.value,
    analyses: analyses.status === 'fulfilled' ? analyses.value : [],
    warning: analyses.status === 'rejected' ?
      '사진 분석 목록을 불러오지 못했지만 대화는 사용할 수 있습니다. 잠시 후 새로고침해 주세요.' : '',
  };
}

export function initializeCoach(doc) {
  const find = selector => doc.querySelector(selector);
  let busy = false;
  let history = [];
  let analyses = [];
  const client = createCoachClient({onUnauthorized: resetSession});
  let photoPanel;

  function setStatus(text, error = false) {
    find('#status').textContent = text;
    find('#status').classList.toggle('error', error);
  }

  function setBusy(value) {
    busy = value;
    doc.querySelectorAll('button,input,textarea,select').forEach(element => element.disabled = value);
    find('#analysis').disabled = value || analyses.length === 0;
    find('#chat-panel').setAttribute('aria-busy', String(value));
  }

  function resetSession() {
    client.clearToken();
    history = [];
    analyses = [];
    find('#password').value = '';
    find('#messages').replaceChildren();
    find('#question').value = '';
    find('#preferences').reset();
    find('#analysis').replaceChildren(new Option('참고하지 않음', ''));
    photoPanel?.reset();
    find('#chat-panel').hidden = true;
    find('#login-panel').hidden = false;
    updateCount();
  }

  function renderMessages() {
    const container = find('#messages');
    container.replaceChildren();
    if (!history.length) {
      const empty = doc.createElement('p');
      empty.className = 'empty';
      empty.textContent = '아직 대화가 없습니다. 오늘 궁금한 것을 물어보세요.';
      container.append(empty);
      return;
    }
    for (const message of history) {
      const turn = doc.createElement('div');
      turn.className = `turn ${message.role}`;
      const label = doc.createElement('small');
      label.textContent = message.role === 'user' ? '나' : `코치 · ${message.model || '규칙 기반 안내'}`;
      const content = doc.createElement('div');
      content.textContent = message.content;
      turn.append(label, content);
      container.append(turn);
    }
    container.scrollTop = container.scrollHeight;
  }

  function applyWorkspace(workspace) {
    const selected = find('#analysis').value;
    history = workspace.messages;
    analyses = workspace.analyses;
    renderMessages();
    find('#analysis').replaceChildren(new Option('참고하지 않음', ''));
    for (const item of analyses) {
      const date = new Date(item.created_at);
      const label = Number.isNaN(date.getTime()) ? '시각 정보 없음' : date.toLocaleString('ko-KR');
      find('#analysis').append(new Option(`분석 #${item.analysis_id} · ${label}`, String(item.analysis_id)));
    }
    if (analyses.some(item => String(item.analysis_id) === selected)) find('#analysis').value = selected;
    find('#analysis-note').textContent = workspace.warning || (analyses.length ?
      '선택한 분석의 각도·비율만 참고합니다. 사진이나 건강 점수는 전달하지 않습니다.' :
      '계정에 저장된 완료 분석이 없습니다. 위에서 사진을 분석하거나 수치 없이 대화할 수 있습니다.');
  }

  async function run(action, {focusQuestion = true} = {}) {
    if (busy) return;
    setBusy(true);
    try { await action(); }
    catch (error) { setStatus(error.message || '서버 연결을 확인하세요.', true); }
    finally {
      setBusy(false);
      if (focusQuestion && !find('#chat-panel').hidden) find('#question').focus();
    }
  }

  function updateCount() {
    find('#count').textContent = `${find('#question').value.length}/500`;
  }

  photoPanel = initializePhotoPanel({doc, client, run: action => run(action, {focusQuestion: false}), setStatus, onCompleted: async result => {
    try {
      const workspace = await loadWorkspace(client);
      applyWorkspace(workspace);
      if (workspace.analyses.some(item => item.analysis_id === result.analysis_id)) {
        find('#analysis').value = String(result.analysis_id);
        setStatus(`분석 #${result.analysis_id}을 완료했습니다. 다음 질문에 측정값을 참고합니다.`);
      } else {
        setStatus('분석을 완료했습니다. 목록 새로고침 후 참고할 분석을 선택해 주세요.');
      }
    } catch (error) {
      if (error.status === 401) throw error;
      setStatus('분석 결과는 저장됐습니다. 코치에 연결하려면 목록을 다시 불러와 주세요.');
    }
  }});

  find('#login').onsubmit = event => {
    event.preventDefault();
    run(async () => {
      setStatus('로그인하고 대화를 불러오는 중입니다…');
      try {
        await client.login(find('#email').value.trim(), find('#password').value);
        find('#password').value = '';
        const workspace = await loadWorkspace(client);
        applyWorkspace(workspace);
        find('#login-panel').hidden = true;
        find('#chat-panel').hidden = false;
        setStatus(workspace.warning || '로그인했습니다. 이전 대화를 이어갈 수 있습니다.');
      } catch (error) {
        resetSession();
        throw error;
      }
    });
  };

  find('#chat').onsubmit = event => {
    event.preventDefault();
    const content = find('#question').value.trim();
    if (!content) return;
    run(async () => {
      setStatus('코치가 답변을 준비하고 있습니다…');
      const result = await client.send(content, {
        goal: find('#goal').value,
        experience: find('#experience').value,
        weekly_days: Number(find('#days').value),
        minutes: Number(find('#minutes').value),
      }, find('#analysis').value ? Number(find('#analysis').value) : null);
      // POST already confirms storage. A second GET must not turn it into a failed send.
      history = mergeSavedTurn(history, result);
      renderMessages();
      find('#question').value = '';
      updateCount();
      let message = '답변과 대화를 저장했습니다.';
      if (result.context?.measurements_provided) message += result.context.context_used ?
        ' 선택한 측정값을 참고했습니다.' : ' 측정값을 전달했지만 이번 안내에는 사용하지 않았습니다.';
      setStatus(message);
    });
  };

  find('#reload').onclick = () => run(async () => {
    const workspace = await loadWorkspace(client);
    applyWorkspace(workspace);
    setStatus(workspace.warning || '대화와 사진 분석 목록을 새로 불러왔습니다.');
  });
  find('#clear').onclick = () => {
    if (busy || !globalThis.confirm('이 계정의 서버 대화 기록을 모두 삭제할까요? 복구할 수 없습니다.')) return;
    run(async () => {
      const result = await client.deleteHistory();
      history = [];
      renderMessages();
      setStatus(`${result.deleted}개 메시지를 삭제했습니다.`);
    });
  };
  find('#logout').onclick = () => {
    if (busy) return;
    resetSession();
    setStatus('로그아웃했습니다. 서버 대화 기록은 유지됩니다.');
  };
  find('#preferences').onsubmit = event => event.preventDefault();
  find('#question').oninput = updateCount;
  updateCount();
}

if (typeof document !== 'undefined') initializeCoach(document);
