import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return json({ error: 'Method not allowed.' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const authorization = request.headers.get('Authorization');
  if (!supabaseUrl || !serviceRoleKey || !authorization) {
    return json({ error: 'The server is not configured for user administration.' }, 500);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);
  const caller = createClient(
    supabaseUrl,
    Deno.env.get('SUPABASE_ANON_KEY') ?? serviceRoleKey,
    { global: { headers: { Authorization: authorization } } },
  );
  const { data: callerData, error: callerError } = await caller.auth.getUser();
  if (callerError || !callerData.user) {
    return json({ error: 'Authentication required.' }, 401);
  }

  const { data: actor, error: actorError } = await admin
    .from('users')
    .select('role, status')
    .eq('id', callerData.user.id)
    .maybeSingle();
  if (actorError || actor?.role !== 'admin' || actor?.status !== 'active') {
    return json({ error: 'Only an active Administrator can manage users.' }, 403);
  }

  let parsedBody: unknown;
  try {
    parsedBody = await request.json();
  } catch {
    return json({ error: 'Request body must be valid JSON.' }, 400);
  }
  if (
    parsedBody === null ||
    typeof parsedBody !== 'object' ||
    Array.isArray(parsedBody)
  ) {
    return json({ error: 'Request body must be a JSON object.' }, 400);
  }
  const body = parsedBody as Record<string, unknown>;

  const action = String(body.action ?? '');
  const userId = String(body.user_id ?? '').trim();
  if (!userId) return json({ error: 'A user ID is required.' }, 400);

  if (action === 'update_password') {
    const password = String(body.password ?? '');
    if (password.length < 8) {
      return json({ error: 'Password must be at least 8 characters long.' }, 400);
    }
    const { error } = await admin.auth.admin.updateUserById(userId, { password });
    if (error) return json({ error: error.message }, 400);
    return json({ user_id: userId, password_updated: true });
  }

  if (action === 'delete_user') {
    if (userId === callerData.user.id) {
      return json({ error: 'You cannot delete your own account.' }, 400);
    }
    const { error } = await admin.auth.admin.deleteUser(userId);
    if (error) return json({ error: error.message }, 400);
    return json({ user_id: userId, deleted: true });
  }

  return json({ error: 'Unsupported user management action.' }, 400);
});
