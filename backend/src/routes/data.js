import { Router } from 'express';
import { config } from '../config.js';
import { buildAlertHtml, notifyAdmin } from '../alerts.js';

const RESERVED_QUERY_KEYS = new Set(['limit', 'offset', 'order', 'ascending', 'select']);
const MAX_LIMIT = 1000;

function parseInteger(value, fallback, min, max) {
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed)) return fallback;
  return Math.min(Math.max(parsed, min), max);
}

function fail(req, res, error) {
  const status = error.code === 'PGRST116' ? 404 : 502;

  // 502 = Supabase/PostgREST itself failed (network, RLS, schema). A 404 is
  // just an unknown row, so only real database failures are worth an email.
  if (status === 502) {
    const at = new Date().toISOString();
    const entity = req.params.entity ?? 'unknown';
    notifyAdmin({
      subject: `[MarkFlow] ERROR · ${req.method} ${entity} failed`,
      text: [
        error.message,
        '',
        `Operation: ${req.method} /api/${entity}`,
        `Code     : ${error.code ?? 'n/a'}`,
        `Time     : ${at}`,
      ].join('\n'),
      html: buildAlertHtml({
        severity: 'error',
        event: `Database operation failed`,
        message: error.message,
        source: 'backend',
        details: { operation: `${req.method} /api/${entity}`, code: error.code ?? 'n/a' },
        at,
      }),
      dedupeKey: `db:${req.method}:${entity}`,
    });
  }

  return res.status(status).json({ error: error.message, code: error.code ?? null });
}

export function createDataRouter(supabase) {
  const router = Router({ mergeParams: true });
  const allowedEntities = new Set(config.tables);

  router.param('entity', (req, res, next, entity) => {
    if (!allowedEntities.has(entity)) {
      return res.status(404).json({ error: `Unknown entity '${entity}'` });
    }
    return next();
  });

  router.get('/:entity', async (req, res, next) => {
    try {
      const limit = parseInteger(req.query.limit, 100, 1, MAX_LIMIT);
      const offset = parseInteger(req.query.offset, 0, 0, Number.MAX_SAFE_INTEGER);
      const order = typeof req.query.order === 'string' ? req.query.order : 'id';
      const ascending = req.query.ascending !== 'false';
      const columns = typeof req.query.select === 'string' ? req.query.select : '*';

      let query = supabase
        .from(req.params.entity)
        .select(columns, { count: 'exact' })
        .range(offset, offset + limit - 1)
        .order(order, { ascending });

      for (const [key, value] of Object.entries(req.query)) {
        if (!RESERVED_QUERY_KEYS.has(key) && typeof value === 'string') {
          query = query.eq(key, value);
        }
      }

      const { data, error, count } = await query;
      if (error) return fail(req, res, error);
      return res.json({ data, count, limit, offset });
    } catch (error) {
      return next(error);
    }
  });

  router.get('/:entity/:id', async (req, res, next) => {
    try {
      const { data, error } = await supabase
        .from(req.params.entity)
        .select('*')
        .eq('id', req.params.id)
        .maybeSingle();

      if (error) return fail(req, res, error);
      if (!data) return res.status(404).json({ error: 'Not found' });
      return res.json({ data });
    } catch (error) {
      return next(error);
    }
  });

  router.post('/:entity', async (req, res, next) => {
    try {
      const { data, error } = await supabase
        .from(req.params.entity)
        .insert(req.body)
        .select('*')
        .single();

      if (error) return fail(req, res, error);
      return res.status(201).json({ data });
    } catch (error) {
      return next(error);
    }
  });

  router.patch('/:entity/:id', async (req, res, next) => {
    try {
      const { data, error } = await supabase
        .from(req.params.entity)
        .update(req.body)
        .eq('id', req.params.id)
        .select('*')
        .maybeSingle();

      if (error) return fail(req, res, error);
      if (!data) return res.status(404).json({ error: 'Not found' });
      return res.json({ data });
    } catch (error) {
      return next(error);
    }
  });

  router.delete('/:entity/:id', async (req, res, next) => {
    try {
      const { data, error } = await supabase
        .from(req.params.entity)
        .delete()
        .eq('id', req.params.id)
        .select('id')
        .maybeSingle();

      if (error) return fail(req, res, error);
      if (!data) return res.status(404).json({ error: 'Not found' });
      return res.status(204).send();
    } catch (error) {
      return next(error);
    }
  });

  return router;
}
