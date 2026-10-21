import test from 'node:test';
import assert from 'node:assert/strict';
import { AppError } from '../src/domain/access.ts';
import { validateFile, beginFile, finishFile, archiveFile, filePath, MAX_FILE_BYTES } from '../src/domain/files.ts';
import { FileSession, prepareFileUpload } from '../src/server/files.ts';

const jobId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const fileId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const requestId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const pm = { id: jobId, active: true, roles: ['pm'] };
const input = { name: 'Site photo.HEIC', size: 234, mime: '' };
const file = { id: fileId, job_id: jobId, object_path: filePath(jobId, fileId), status: 'pending', filename: input.name, mime_type: 'image/heic', byte_size: 234, created_by: pm.id, created_at: '2026-10-21' };

test('photo and PDF metadata validates iPhone blank MIME, size boundary and unsafe names/types', () => {
  assert.deepEqual(validateFile(input), { ...input, mime: 'image/heic' });
  for (const [extension, mime] of Object.entries({ pdf: 'application/pdf', jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp', heif: 'image/heif' })) assert.equal(validateFile({ name: 'test.' + extension, size: 1, mime: '' }).mime, mime);
  assert.equal(validateFile({ name: 'plan.pdf', size: MAX_FILE_BYTES, mime: 'application/pdf' }).size, MAX_FILE_BYTES);
  for (const patch of [{ name: '../photo.jpg' }, { name: 'folder\\photo.jpg' }, { name: 'bad\nphoto.jpg' }, { name: '.hidden.pdf' }, { name: 'script.svg' }, { name: 'index.html' }, { size: 0 }, { size: -1 }, { size: 1.2 }, { size: MAX_FILE_BYTES + 1 }, { mime: 'text/html' }, { mime: 'image/jpeg' }, { object_path: 'forged' }]) {
    assert.throws(() => validateFile({ ...input, ...patch }), { code: 'invalid_input' });
  }
});

test('file commands reject helper/admin-only/inactive/anonymous before transport; active leads can reach DB enforcement', async () => {
  let writes = 0;
  const gateway = { beginFile: async () => { writes++; return { id: fileId }; }, finishFile: async () => { writes++; return { id: fileId }; }, archiveFile: async () => { writes++; return { id: fileId }; } };
  for (const actor of [null, { ...pm, active: false }, { ...pm, roles: ['helper'] }, { ...pm, roles: ['admin'] }]) {
    await assert.rejects(beginFile(actor, jobId, requestId, input, gateway));
    await assert.rejects(finishFile(actor, jobId, fileId, gateway));
    await assert.rejects(archiveFile(actor, jobId, fileId, gateway));
  }
  assert.equal(writes, 0);
  await beginFile({ ...pm, roles: ['lead'] }, jobId, requestId, input, gateway);
  assert.equal(writes, 1); // SQL must additionally enforce the lead's job assignment.
  await assert.rejects(beginFile(pm, 'bad', requestId, input, gateway), { code: 'invalid_input' });
});

function preparationGateway({ status = 'pending', stored = false, path = file.object_path, failure = null } = {}) {
  const calls = [];
  return { calls,
    beginFile: async (...args) => { calls.push(['begin', ...args]); return { id: fileId }; },
    getFile: async () => ({ ...file, status, object_path: path }),
    finishFile: async () => { calls.push(['finish']); if (failure) throw failure; if (!stored) throw new AppError('upload_pending', 409, 'Pending'); return { id: fileId }; },
    archiveFile: async () => ({ id: fileId }),
    signUpload: async path => { calls.push(['sign', path]); return 'https://scoped.invalid/upload'; }
  };
}
test('first upload obtains a path-scoped capability, retry confirms an already-stored file without overwriting', async () => {
  const first = preparationGateway();
  assert.deepEqual(await prepareFileUpload(pm, jobId, requestId, input, first), { fileId, complete: false, signedUrl: 'https://scoped.invalid/upload', mime: 'image/heic' });
  assert.equal(first.calls[0][2], requestId);
  const retry = preparationGateway({ stored: true });
  assert.deepEqual(await prepareFileUpload(pm, jobId, requestId, input, retry), { fileId, complete: true });
  assert(!retry.calls.some(call => call[0] === 'sign'));
  const ready = preparationGateway({ status: 'ready' });
  assert.equal((await prepareFileUpload(pm, jobId, requestId, input, ready)).complete, true);
});

test('upload preparation refuses archived/forged paths and does not treat permission or validation errors as absent bytes', async () => {
  for (const gateway of [preparationGateway({ status: 'archived' }), preparationGateway({ path: 'other/job' })]) await assert.rejects(prepareFileUpload(pm, jobId, requestId, input, gateway), { code: 'file_unavailable' });
  for (const code of ['not_allowed', 'invalid_input', 'connection_failed']) {
    const gateway = preparationGateway({ failure: new AppError(code, 403, 'Denied') });
    await assert.rejects(prepareFileUpload(pm, jobId, requestId, input, gateway), { code });
    assert(!gateway.calls.some(call => call[0] === 'sign'));
  }
});

test('file transport preserves employee identity; signed upload cannot overwrite and download is forced with 60-second expiry', async () => {
  const calls = [];
  const origin = 'https://synthetic-project.supabase.co';
  const gateway = new FileSession({ url: origin, publishableKey: 'sb_publishable_test', environment: 'test' }, 'employee-token', async (url, init) => {
    calls.push({ url: String(url), init });
    if (String(url).includes('/object/upload/sign/')) return Response.json({ url: '/object/upload/sign/eigsti-job-files/' + file.object_path + '?token=upload-test' });
    if (String(url).includes('/object/sign/')) return Response.json({ signedURL: '/object/sign/eigsti-job-files/' + file.object_path + '?token=download-test' });
    return Response.json({ id: fileId });
  });
  await gateway.beginFile(jobId, requestId, { ...input, mime: 'image/heic' });
  assert.deepEqual(JSON.parse(calls[0].init.body), { p_job_id: jobId, p_request_id: requestId, p_filename: input.name, p_mime: 'image/heic', p_size: 234 });
  const upload = await gateway.signUpload(file.object_path);
  assert(upload.startsWith(origin + '/storage/v1/object/upload/sign/eigsti-job-files/'));
  assert.notEqual(new Headers(calls[1].init.headers).get('x-upsert'), 'true');
  const download = await gateway.signDownload({ ...file, status: 'ready' });
  assert.equal(new URL(download).searchParams.get('download'), input.name);
  assert.equal(JSON.parse(calls[2].init.body).expiresIn, 60);
  for (const call of calls) assert.equal(new Headers(call.init.headers).get('authorization'), 'Bearer employee-token');
});

test('download signing rejects a storage response that points outside the project or file path', async () => {
  const gateway = new FileSession({ url: 'https://synthetic-project.supabase.co', publishableKey: 'sb_publishable_test', environment: 'test' }, 'employee-token', async () => Response.json({ signedURL: 'https://evil.invalid/elsewhere' }));
  await assert.rejects(gateway.signDownload({ ...file, status: 'ready' }));
});
