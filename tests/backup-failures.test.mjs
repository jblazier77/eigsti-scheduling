import test from 'node:test';
import assert from 'node:assert/strict';
import {postgresFailure,safeFailure,operationError} from '../scripts/ops/failures.mjs';
test('native database failures map to useful fixed messages without echoing private diagnostics',()=>{
 for(const [text,code] of [['invalid input syntax for type json PRIVATE','SQL_INPUT_INVALID'],['column PRIVATE does not exist','DATABASE_SCHEMA_MISMATCH'],['Tenant or user not found PRIVATE','POOLER_PROJECT_MISMATCH'],['no password supplied PRIVATE','PASSWORD_MISSING'],['password authentication failed for user PRIVATE','AUTH_FAILED'],['root certificate file PRIVATE does not exist','CERTIFICATE_MISSING'],['SSL error: certificate verify failed PRIVATE','TLS_VERIFY_FAILED'],['server certificate does not match PRIVATE','TLS_HOST_MISMATCH'],['permission denied for table PRIVATE','DATABASE_PERMISSION_DENIED'],['could not translate host PRIVATE','DNS_FAILED'],['connection refused PRIVATE','CONNECTION_FAILED'],['snapshot PRIVATE does not exist','SNAPSHOT_FAILED']]){assert.equal(postgresFailure(text),code);const message=safeFailure(operationError(code));assert(!message.includes('PRIVATE'));assert(message.includes(code));}
 assert(!safeFailure(Error('sb_secret_PRIVATE password=PRIVATE')).includes('PRIVATE'));
 assert(safeFailure({code:'EPERM',message:'PRIVATE'}).includes('FILE_ACCESS_DENIED'));
});
