// Bound remote logout. The caller uses a read-only cookie adapter, so a late
// SDK response cannot mutate cookies after the action has redirected.
export async function signOutWithDeadline(logout: (signal: AbortSignal) => Promise<unknown>, timeoutMs = 8000): Promise<boolean> {
  const controller = new AbortController();
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      Promise.resolve().then(() => logout(controller.signal)).then(() => true),
      new Promise<boolean>(resolve => { timer = setTimeout(() => { controller.abort(); resolve(false); }, timeoutMs); })
    ]);
  } catch { return false; }
  finally { if (timer !== undefined) clearTimeout(timer); controller.abort(); }
}
