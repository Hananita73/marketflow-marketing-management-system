// ─────────────────────────────────────────────────────────────────────────────
// POST /api/alerts
//
// Called by the Flutter app when something notable happens (new campaign,
// new lead, budget threshold crossed, a failed database write, …). The
// server turns it into one email addressed to ADMIN_EMAIL.
//
// Auth: X-Alert-Token (or `Authorization: Bearer <token>`) must equal
// ALERTS_API_TOKEN. This token is deliberately separate from
// ADMIN_API_TOKEN: the client may embed it, so it can only trigger
// pre-templated alerts — never raw arbitrary email.
// ─────────────────────────────────────────────────────────────────────────────

import { Router } from 'express';
import { config } from '../config.js';
import { alertingStatus, buildAlertHtml, notifyAdmin } from '../alerts.js';

const SEVERITIES = new Set(['info', 'warning', 'error']);
const MAX_EVENT = 80;
const MAX_MESSAGE = 1000;

// Crude per-process guard against a runaway client loop.
const RATE_WINDOW_MS = 60_000;
const RATE_MAX = 20;
let windowStart = 0;
let windowCount = 0;

function rateLimited() {
  const now = Date.now();
  if (now - windowStart >= RATE_WINDOW_MS) {
    windowStart = now;
    windowCount = 0;
  }
  windowCount += 1;
  return windowCount > RATE_MAX;
}

export const alertsRouter = Router();

alertsRouter.use((req, res, next) => {
  if (!config.alerts.token) {
    return res.status(503).json({ error: 'ALERTS_API_TOKEN is not configured' });
  }

  const bearer = (req.get('authorization') || '').replace(/^Bearer\s+/i, '').trim();
  const token = (req.get('x-alert-token') || bearer).trim();

  if (token !== config.alerts.token) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  return next();
});

// Read-only status probe used to verify the wiring without sending mail.
alertsRouter.get('/', (req, res) => {
  res.json({ status: 'ok', alerting: alertingStatus() });
});

alertsRouter.post('/', async (req, res, next) => {
  try {
    const { event, message, severity = 'info', source = 'app', details } = req.body ?? {};

    if (typeof event !== 'string' || !event.trim()) {
      return res.status(400).json({ error: 'event is required' });
    }
    if (typeof message !== 'string' || !message.trim()) {
      return res.status(400).json({ error: 'message is required' });
    }
    if (!SEVERITIES.has(severity)) {
      return res.status(400).json({ error: 'severity must be one of: info, warning, error' });
    }
    if (rateLimited()) {
      return res.status(429).json({ error: 'Too many alerts, slow down' });
    }

    const cleanEvent = event.trim().slice(0, MAX_EVENT);
    const cleanMessage = message.trim().slice(0, MAX_MESSAGE);
    const at = new Date().toISOString();
    const label = severity === 'info' ? 'INFO' : severity === 'warning' ? 'WARNING' : 'ERROR';

    const result = await notifyAdmin({
      subject: `[MarkFlow] ${label} · ${cleanEvent}`,
      text: [
        `${cleanMessage}`,
        '',
        `Event : ${cleanEvent}`,
        `Source: ${typeof source === 'string' ? source : 'app'}`,
        `Time  : ${at}`,
        details ? `Details: ${JSON.stringify(details)}` : '',
      ]
        .filter(Boolean)
        .join('\n'),
      html: buildAlertHtml({
        severity,
        event: cleanEvent,
        message: cleanMessage,
        source: typeof source === 'string' ? source : 'app',
        details: typeof details === 'object' && details !== null ? details : null,
        at,
      }),
      dedupeKey: `app:${cleanEvent}:${cleanMessage}`.slice(0, 200),
    });

    if (result.reason && String(result.reason).startsWith('not_configured')) {
      return res.status(503).json({ error: 'Email alerts are not configured', reason: result.reason });
    }
    if (result.reason === 'send_failed') {
      return res.status(502).json({ error: 'Email delivery failed', reason: result.error ?? null });
    }

    // Sent, duplicated or rate-limited — from the caller's point of view the
    // alert was accepted, so keep the client fire-and-forget friendly.
    return res.status(202).json({ queued: result.sent, reason: result.reason ?? null });
  } catch (error) {
    return next(error);
  }
});
