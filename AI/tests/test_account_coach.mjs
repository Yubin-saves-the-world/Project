import test from 'node:test';
import assert from 'node:assert/strict';
import {ApiError, createCoachClient, loadWorkspace, mergeSavedTurn} from '../static/account-coach.mjs';

const response = (data, status = 200) => ({status, ok: status >= 200 && status < 300, json: async () => data});
const pair = {
  user_message: {role: 'user', content: '질문'},
  assistant_message: {role: 'assistant', content: '저장된 답변', model: 'qwen3:4b'},
};

test('photo list failure leaves authenticated conversations usable', async () => {
  const messages = [pair.user_message, pair.assistant_message];
  const workspace = await loadWorkspace({
    history: async () => messages,
    analyses: async () => { throw new ApiError('분석 목록 연결 실패', 503); },
  });
  assert.deepEqual(workspace.messages, messages);
  assert.deepEqual(workspace.analyses, []);
  assert.match(workspace.warning, /대화는 사용할 수/);
});

test('an expired session is never treated as an optional photo failure', async () => {
  await assert.rejects(loadWorkspace({
    history: async () => [],
    analyses: async () => { throw new ApiError('expired', 401); },
  }), error => error.status === 401);
});

test('failed history loading cannot silently become an empty conversation', async () => {
  await assert.rejects(loadWorkspace({
    history: async () => { throw new ApiError('기록 실패', 503); },
    analyses: async () => [],
  }), /기록 실패/);
});

test('confirmed POST is enough to display the saved turn without a second GET', async () => {
  const requests = [];
  const client = createCoachClient({fetchImpl: async (path, options) => {
    requests.push([path, options.method]);
    if (options.method !== 'POST') throw new Error('follow-up read is unavailable');
    return response(pair);
  }});
  const result = await client.send('질문', {minutes: 10}, null);
  assert.deepEqual(mergeSavedTurn([], result), [pair.user_message, pair.assistant_message]);
  assert.deepEqual(requests, [['/api/ai-coach/messages', 'POST']]);
  assert.equal(mergeSavedTurn(Array(20).fill(pair.assistant_message), result).length, 20);
});

test('malformed successful responses are not displayed as saved or deleted', async () => {
  assert.throws(() => mergeSavedTurn([], {user_message: pair.user_message}), ApiError);
  const client = createCoachClient({fetchImpl: async () => response({})});
  await assert.rejects(client.history(), /대화 응답/);
  await assert.rejects(client.deleteHistory(), /삭제 결과/);
});

test('401 clears the token even when its body is not JSON', async () => {
  const headers = [];
  let request = 0;
  let invalidated = 0;
  const client = createCoachClient({onUnauthorized: () => invalidated++, fetchImpl: async (_path, options) => {
    headers.push(options.headers);
    request++;
    if (request === 1) return response({access_token: 'test-only-token'});
    if (request === 2) return {status: 401, ok: false, json: async () => { throw new Error('not JSON'); }};
    return response({messages: []});
  }});
  await client.login('test@example.invalid', 'test-only-password');
  await assert.rejects(client.history(), error => error.status === 401);
  await client.history();
  assert.equal(invalidated, 1);
  assert.equal(headers[1].Authorization, 'Bearer test-only-token');
  assert.equal(headers[2].Authorization, undefined);
});

test('a timeout does not automatically retry a potentially stored question', async () => {
  let calls = 0;
  const client = createCoachClient({timeoutMs: 5, fetchImpl: async (_path, options) => {
    calls++;
    return new Promise((_resolve, reject) => options.signal.addEventListener('abort', () => {
      const error = new Error('aborted'); error.name = 'AbortError'; reject(error);
    }));
  }});
  await assert.rejects(client.send('질문', {}, null), /저장 여부를 먼저 확인/);
  assert.equal(calls, 1);
});

test('only completed analyses with valid IDs are offered for selection', async () => {
  const client = createCoachClient({fetchImpl: async () => response({items: [
    {analysis_id: 1, status: 'done'}, {analysis_id: 2, status: 'pending'},
    {analysis_id: '3', status: 'done'}, {analysis_id: -1, status: 'done'},
  ]})});
  assert.deepEqual(await client.analyses(), [{analysis_id: 1, status: 'done'}]);
});
