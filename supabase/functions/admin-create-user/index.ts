import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const authorization = request.headers.get('Authorization');
  if (!supabaseUrl || !serviceRoleKey || !authorization) {
    return json({ error: 'The server is not configured for user administration.' }, 500);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);
  const caller = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY') ?? serviceRoleKey, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: callerData, error: callerError } = await caller.auth.getUser();
  if (callerError || !callerData.user) return json({ error: 'Authentication required.' }, 401);

  const { data: actor, error: actorError } = await admin
    .from('users')
    .select('role, status')
    .eq('id', callerData.user.id)
    .maybeSingle();
  if (actorError || actor?.role !== 'admin' || actor?.status !== 'active') {
    return json({ error: 'Only an active Administrator can invite users.' }, 403);
  }

  const body = await request.json().catch(() => ({}));
  const email = String(body.email ?? '').trim().toLowerCase();
  const fullName = String(body.full_name ?? '').trim();
  const phone = String(body.phone ?? '').trim();
  const department = String(body.department ?? 'General').trim() || 'General';
  const role = String(body.role ?? 'viewer').trim();
  const status = String(body.status ?? 'pending_assignment').trim();

  if (!email || !email.includes('@') || !fullName) return json({ error: 'Name and a valid email are required.' }, 400);
  if (!['pending_assignment', 'active', 'deactivated'].includes(status)) return json({ error: 'Invalid account status.' }, 400);

  const { data: roleRow } = await admin.from('app_roles').select('role_key').eq('role_key', role).maybeSingle();
  if (!roleRow) return json({ error: 'Invalid role.' }, 400);

  const { data: invite, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, {
    data: { full_name: fullName, phone, department },
  });
  if (inviteError || !invite.user) return json({ error: inviteError?.message ?? 'Could not create Auth user.' }, 400);

  const { error: profileError } = await admin
    .from('users')
    .update({ full_name: fullName, phone, department, role, status })
    .eq('id', invite.user.id);
  if (profileError) return json({ error: profileError.message }, 500);

  return json({ user_id: invite.user.id, email, status });
});
