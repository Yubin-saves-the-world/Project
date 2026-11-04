import test from 'node:test';
import assert from 'node:assert/strict';
import {createCoachClient} from '../static/account-coach.mjs';
import {validatePhoto, waitForAnalysis, measurementRows} from '../static/account-photo.mjs';

const response = (data, status = 200) => ({status, ok: status >= 200 && status < 300, json: async () => data});

test('front photo is checked before uploading; HEIC and oversized files explain the problem', () => {
  assert.throws(() => validatePhoto(), /정면 사진/);
  assert.throws(() => validatePhoto({name: 'a.heic', type: 'image/heic', size: 100}), /HEIC/);
  assert.throws(() => validatePhoto({name: 'a.jpg', type: 'image/jpeg', size: 10 * 1024 * 1024 + 1}), /10MB/);
  assert.throws(() => validatePhoto({name: 'a.jpg', type: 'text/plain', size: 100}), /JPG/);
  assert.doesNotThrow(() => validatePhoto({name: 'front.JPG', type: '', size: 100}));
});

test('multipart upload keeps the authorization and lets the browser choose its boundary', async () => {
  const calls = [];
  const client = createCoachClient({fetchImpl: async (path, options) => {
    calls.push({path, ...options});
    return response(path === '/api/auth/login' ? {access_token: 'test-token'} : {photo_id: 12}, 200);
  }});
  await client.login('test@example.invalid', 'test-only-password');
  await client.uploadPhoto(new Blob(['test'], {type: 'image/png'}), 'side');
  const request = calls[1];
  assert.equal(request.path, '/api/photos');
  assert.equal(request.headers.Authorization, 'Bearer test-token');
  assert.equal(request.headers['Content-Type'], undefined);
  assert.ok(request.body instanceof FormData);
  assert.equal(request.body.get('type'), 'current');
  assert.equal(request.body.get('side'), 'side');
  assert.equal(request.body.get('image').type, 'image/png');
});

test('photo delete accepts a successful empty 204 response', async () => {
  const client = createCoachClient({fetchImpl: async (path, options) => {
    assert.equal(path, '/api/photos/12'); assert.equal(options.method, 'DELETE');
    return {status: 204, ok: true, json: async () => { throw new Error('no body'); }};
  }});
  assert.equal(await client.deletePhoto(12), null);
});

test('analysis polling preserves unavailable values and makes no extra analysis request', async () => {
  let reads = 0;
  let elapsed = 0;
  const done = {analysis_id: 3, status: 'done', measures: {neck_forward_deg: null}};
  const actual = await waitForAnalysis({analysis: async id => {
    assert.equal(id, 3); reads++;
    return reads === 1 ? {analysis_id: 3, status: 'pending'} : done;
  }}, {analysis_id: 3}, {clock: () => elapsed, sleep: async ms => { elapsed += ms; }});
  assert.deepEqual(actual, done);
  assert.equal(reads, 2);
  assert.equal(actual.measures.neck_forward_deg, null);
});

test('failed measurement surfaces its reason code instead of presenting zero measurements', async () => {
  await assert.rejects(waitForAnalysis({analysis: async () => ({analysis_id: 3,
    status: 'failed', error_code: 'IMAGE_BLURRY', error_message: '사진이 흐려요.'})},
  {analysis_id: 3}), /사진이 흐려요.*IMAGE_BLURRY/);
});

test('bounded polling can resume the same ticket without submitting the photo again', async () => {
  let elapsed = 0;
  let reads = 0;
  const client = {analysis: async () => { reads++; return {analysis_id: 3, status: 'pending'}; }};
  await assert.rejects(waitForAnalysis(client, {analysis_id: 3}, {
    timeoutMs: 4500, clock: () => elapsed, sleep: async ms => { elapsed += ms; },
  }), /마지막 분석 결과 확인/);
  assert.equal(elapsed, 4500);
  assert.equal(reads, 3);
  client.analysis = async () => ({analysis_id: 3, status: 'done'});
  assert.equal((await waitForAnalysis(client, {analysis_id: 3})).status, 'done');
});

test('invalid IDs, unknown statuses and mismatched responses never become completed analyses', async () => {
  let called = false;
  const client = {analysis: async () => { called = true; return {}; }};
  for (const id of [null, -1, true, '3']) {
    await assert.rejects(waitForAnalysis(client, {analysis_id: id}), /접수 응답/);
  }
  assert.equal(called, false);
  await assert.rejects(waitForAnalysis({analysis: async () => ({analysis_id: 4, status: 'done'})},
    {analysis_id: 3}), /번호가 다른/);
  await assert.rejects(waitForAnalysis({analysis: async () => ({analysis_id: 3, status: 'unknown'})},
    {analysis_id: 3}), /상태를 확인/);
});

test('transport errors during polling propagate and do not erase the caller ticket', async () => {
  const ticket = {analysis_id: 3};
  await assert.rejects(waitForAnalysis({analysis: async () => { throw new Error('offline'); }}, ticket), /offline/);
  assert.deepEqual(ticket, {analysis_id: 3});
});

test('rendered measurements distinguish actual zero, missing side photo and low confidence', () => {
  const result = {measures: {unavailable: [
    {key: 'neck_forward_deg', reason: 'SIDE_PHOTO_MISSING'},
    {key: 'other', reason: 'LOW_CONFIDENCE'},
  ]}, measurement_report: {items: [
    {key: 'shoulder_tilt_deg', status: 'measured', value: 0, display_value: '0.00°'},
    {key: 'neck_forward_deg', status: 'unavailable', value: null},
    {key: 'other', status: 'unavailable', value: null},
  ]}};
  const rows = measurementRows(result);
  assert.equal(rows[0].display_value, '0.00°');
  assert.equal(rows[0].measured, true);
  assert.match(rows[1].description, /측면 사진.*SIDE_PHOTO_MISSING/);
  assert.match(rows[2].description, /귀와 어깨.*LOW_CONFIDENCE/);
  assert.equal(rows[1].value, null);
  assert.deepEqual(measurementRows({}), []);
});
