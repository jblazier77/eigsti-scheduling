// Only fixed messages may leave operator diagnostics. Never echo native stderr.
const messages={
 AUTH_FAILED:'The database rejected the supplied password.',
 POOLER_PROJECT_MISMATCH:'The pooler could not find this project/user. Check the copied Session pooler host and project reference.',
 PASSWORD_MISSING:'PostgreSQL did not receive a database password.',
 CERTIFICATE_MISSING:'PostgreSQL could not find or read its root certificate.',
 TLS_VERIFY_FAILED:'The secure database certificate could not be verified.',
 TLS_HOST_MISMATCH:'The database certificate does not match the connection host.',
 DATABASE_PERMISSION_DENIED:'The database account cannot read an object required by this export.',
 DNS_FAILED:'The database hostname could not be resolved.',
 CONNECTION_FAILED:'The database connection could not be established.',
 CONNECTION_TIMEOUT:'The database connection timed out.',
 CONNECTION_CLOSED:'The database connection closed unexpectedly.',
 SNAPSHOT_TIMEOUT:'The snapshot query did not return a complete result within 30 seconds.',
 SNAPSHOT_FORMAT:'The snapshot query returned an unexpected result format.',
 SQL_INPUT_INVALID:'The database rejected a value in the operator query; no source changes were made.',
 DATABASE_SCHEMA_MISMATCH:'The operator query references a database object that is missing or has changed.',
 SNAPSHOT_FAILED:'The database snapshot could not be shared with the export.',
 POSTGRES_FAILED:'PostgreSQL reported an unclassified failure; raw output was suppressed.',
 TOOL_UNAVAILABLE:'A PostgreSQL executable could not be started.',
 OPERATION_TIMEOUT:'The PostgreSQL operation exceeded its time limit.',
 FILE_ACCESS_DENIED:'Windows denied access to a required backup file or folder.',
 BACKUP_FAILED:'The operation did not complete; private error details were suppressed.'
};
export function postgresFailure(text=''){
 if(/Tenant or user not found/i.test(text))return 'POOLER_PROJECT_MISMATCH';
 if(/no password supplied/i.test(text))return 'PASSWORD_MISSING';
 if(/password authentication failed|28P01/i.test(text))return 'AUTH_FAILED';
 if(/root certificate file.*does not exist|could not (?:open|read).*certificate/i.test(text))return 'CERTIFICATE_MISSING';
 if(/server certificate.*does not match|hostname mismatch/i.test(text))return 'TLS_HOST_MISMATCH';
 if(/certificate verify failed|unable to get local issuer|self.signed certificate|SSL error.*certificate/i.test(text))return 'TLS_VERIFY_FAILED';
 if(/invalid input syntax/i.test(text))return 'SQL_INPUT_INVALID';
 if(/(?:relation|column|function).*does not exist/i.test(text))return 'DATABASE_SCHEMA_MISMATCH';
 if(/permission denied|must be (?:owner|superuser)/i.test(text))return 'DATABASE_PERMISSION_DENIED';
 if(/could not translate host|name or service not known|getaddrinfo/i.test(text))return 'DNS_FAILED';
 if(/timeout expired|connection timed out/i.test(text))return 'CONNECTION_TIMEOUT';
 if(/connection refused|network is unreachable|could not connect/i.test(text))return 'CONNECTION_FAILED';
 if(/server closed the connection|terminating connection/i.test(text))return 'CONNECTION_CLOSED';
 if(/snapshot.*does not exist|invalid snapshot identifier|cannot import.*snapshot/i.test(text))return 'SNAPSHOT_FAILED';
 return 'POSTGRES_FAILED';
}
export function operationError(code){const error=new Error(messages[code]??messages.BACKUP_FAILED);error.code=Object.hasOwn(messages,code)?code:'BACKUP_FAILED';return error;}
export function safeFailure(error){const code=Object.hasOwn(messages,error?.code)?error.code:['EPERM','EACCES'].includes(error?.code)?'FILE_ACCESS_DENIED':'BACKUP_FAILED';return '['+code+'] '+messages[code];}
