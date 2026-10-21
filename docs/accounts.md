# Employee accounts: development checkpoint

Updated 2026-10-21. Standalone app passwords; no Google integration. Private files checkpoint 193c50d was pushed by the user. The signed-in password-change slice passed full build and core browser checks; local changes await commit/push.

## Implemented slice

My account is linked in the app footer. Every active role may change its own password at /account. Anonymous/inactive page requests are redirected to sign-in; the Server Action separately verifies Auth and live app membership. The form accepts only current/new/confirmation password fields, never a target email, actor ID or role.

Current credentials are checked by an isolated non-persistent Supabase client against the Auth-verified account email. This verification does not depend on the optional project setting requiring a current password. The returned identity must match the original actor. Membership is read again before updating through the fresh session. The app's profile read and the separate Auth update cannot be one atomic database transaction; operational reads still enforce live membership independently.

New passwords must differ, match confirmation, have at least 12 UTF-16 code units and fit 72 UTF-8 bytes (bcrypt's input bound). Spaces are retained. Supabase's configured strength policy may add requirements. No app password hashing/storage, password logging, administrative key or email change is introduced. Tokens/passwords are not returned in action state.

The temporary session is signed out on completion/failure where possible. A confirmed change clears this browser's project cookies, including chunked cookies, and redirects to sign-in with a success notice. Other cookies are preserved. This is not a claim that every previously issued access token is immediately revoked. An uncertain Auth update tells the user to check sign-in with the new password before retrying; automatic password-write retries are not added by the app. Closing the form discards its values; no password draft is persisted.

## Verification

All 46 Node tests pass and TypeScript passes. The six new account tests exercise the installed Auth SDK with mocked transport: all four roles, current-password verification, own-identity binding, live deactivation/revocation, weak-password rejection, ambiguous server failure, temporary-session cleanup and byte limits. Real Server Action tests cover expired sessions, response secrecy, cookie cleanup despite failed logout and successful redirect outside error handling. These do not prove real Auth password changes.

User reported successful full production build including /account. Helper browser checks passed: mismatched confirmation and wrong current password rejected; correct change returned to sign-in with success notice; old password rejected; new password signed in; after logout, /account redirected to sign-in. No password was shared in chat. Cancel, phone, live deactivation and interrupted-update acceptance remain unverified. Next commit/push this checkpoint.

## Following work

Forgotten-password email requests, callback/reset handling, account invitations, role/deactivation administration and last-admin protection are not implemented by this slice. Production invite/recovery delivery needs verified company SMTP and an approved app URL/redirect allowlist. The default Supabase test mail service is not a production delivery solution. No provider account or paid provisioning was created and no test email was sent.

Sources checked 2026-10-21: https://supabase.com/docs/guides/auth/password-security and https://supabase.com/docs/guides/auth/passwords; installed @supabase/auth-js types/transport and installed Next Server Action docs. Current-password reauthentication is explicit so it remains effective regardless of the optional Auth setting.
