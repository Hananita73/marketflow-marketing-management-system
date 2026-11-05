// ─────────────────────────────────────────────────────────────────────────────
// Admin alerts
//
// Sends notification emails to the admin mailbox when something notable
// happens: server errors, failed database operations, or events reported by
// the Flutter app through POST /api/alerts.
//
// Safety rails — a failing dependency must never flood the admin inbox:
//   * alerts are disabled unless BOTH ADMIN_EMAIL and RESEND_API_KEY are set
//   * at most one email per `dedupeKey` per DEDUPE_WINDOW_MS
//   * a global cooldown of MIN_INTERVAL_MS between any two alert emails
//
// Nothing in this module ever throws: reporting a problem must never break
// the request that triggered it.
// ─────────────────────────────────────────────────────────────────────────────

import { config } from './config.js';
import { sendEmail } from './mailer.js';

const MIN_INTERVAL_MS = 60_000; // global cooldown between alert emails
const DEDUPE_WINDOW_MS = 15 * 60_000; // per dedupeKey window
const MAX_TRACKED_KEYS = 500;

let lastSentAt = 0;
const recent = new Map(); // dedupeKey -> epoch ms when it was last sent

/** Returns whether email alerting is usable with the current environment. */
export function alertingStatus() {
  return {
    enabled: Boolean(config.admin.email && config.resend.apiKey),
    hasAdminEmail: Boolean(config.admin.email),
    hasResendKey: Boolean(config.resend.apiKey),
    cooldownMs: MIN_INTERVAL_MS,
    dedupeWindowMs: DEDUPE_WINDOW_MS,
  };
}

export function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function prune() {
  if (recent.size <= MAX_TRACKED_KEYS) return;
  const cutoff = Date.now() - DEDUPE_WINDOW_MS;
  for (const [key, at] of recent) {
    if (at < cutoff) recent.delete(key);
  }
}

/**
 * Emails the admin. Never throws.
 *
 * @param {object} options
 * @param {string} options.subject   Email subject line.
 * @param {string} [options.text]    Plain-text body.
 * @param {string} [options.html]    HTML body (defaults to escaped text).
 * @param {string} [options.dedupeKey] Identical alerts inside the dedupe
 *                                     window collapse into one email.
 * @returns {Promise<{sent: boolean, reason?: string, id?: string|null}>}
 */
export async function notifyAdmin({ subject, text, html, dedupeKey }) {
  try {
    if (!config.admin.email) {
      return { sent: false, reason: 'not_configured:ADMIN_EMAIL' };
    }
    if (!config.resend.apiKey) {
      return { sent: false, reason: 'not_configured:RESEND_API_KEY' };
    }

    const now = Date.now();

    if (dedupeKey) {
      const seen = recent.get(dedupeKey);
      if (seen && now - seen < DEDUPE_WINDOW_MS) {
        return { sent: false, reason: 'duplicate' };
      }
    }

    if (now - lastSentAt < MIN_INTERVAL_MS) {
      return { sent: false, reason: 'rate_limited' };
    }

    if (dedupeKey) recent.set(dedupeKey, now);
    lastSentAt = now;
    prune();

    const body = text || subject;
    const result = await sendEmail({
      to: config.admin.email,
      subject: String(subject || '[MarkFlow] Alert').slice(0, 200),
      text: body,
      html: html || `<p>${escapeHtml(body)}</p>`,
    });

    console.log(`[alerts] admin notified: ${subject}`);
    return { sent: true, id: result?.id ?? null };
  } catch (error) {
    console.error(`[alerts] could not notify admin: ${error.message}`);
    return { sent: false, reason: 'send_failed', error: error.message };
  }
}

const SEVERITY_COLORS = {
  info: '#22A06B',
  warning: '#F59E0B',
  error: '#E5484D',
};

/**
 * Renders the HTML body used by alert emails.
 *
 * @param {object} options
 * @param {string} options.severity  info | warning | error
 * @param {string} options.event     Short machine/human readable event name.
 * @param {string} options.message   What actually happened.
 * @param {string} [options.source]  Who reported it (app, backend, …).
 * @param {object} [options.details] Extra structured context.
 * @param {string} [options.at]      ISO timestamp.
 */
export function buildAlertHtml({
  severity = 'info',
  event,
  message,
  source = 'backend',
  details = null,
  at = new Date().toISOString(),
}) {
  const color = SEVERITY_COLORS[severity] || SEVERITY_COLORS.info;
  const detailRows = details
    ? Object.entries(details)
        .filter(([, value]) => value !== undefined && value !== null && value !== '')
        .map(
          ([key, value]) =>
            `<tr><td style="padding:6px 10px;border-bottom:1px solid #eee;color:#666;font-size:13px;">${escapeHtml(
              key,
            )}</td><td style="padding:6px 10px;border-bottom:1px solid #eee;font-size:13px;">${escapeHtml(
              typeof value === 'object' ? JSON.stringify(value) : value,
            )}</td></tr>`,
        )
        .join('')
    : '';

  return `<!doctype html>
<html>
  <body style="margin:0;background:#f5f5f7;font-family:Helvetica,Arial,sans-serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
      <tr><td align="center" style="padding:24px 12px;">
        <table role="presentation" width="100%" style="max-width:560px;background:#ffffff;border-radius:12px;border:1px solid #e6e6ea;overflow:hidden;">
          <tr>
            <td style="background:${color};padding:14px 20px;">
              <span style="color:#ffffff;font-size:13px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;">${escapeHtml(
                severity,
              )}</span>
            </td>
          </tr>
          <tr><td style="padding:22px 20px 6px;">
            <h2 style="margin:0;font-size:18px;color:#16161d;">${escapeHtml(event)}</h2>
          </td></tr>
          <tr><td style="padding:0 20px 16px;">
            <p style="margin:0;font-size:14px;line-height:1.6;color:#3c3c46;white-space:pre-wrap;">${escapeHtml(
              message,
            )}</p>
          </td></tr>
          ${
            detailRows
              ? `<tr><td style="padding:0 20px 16px;"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #eee;border-radius:8px;border-collapse:collapse;">${detailRows}</table></td></tr>`
              : ''
          }
          <tr><td style="padding:0 20px 22px;">
            <p style="margin:0;font-size:12px;color:#8a8a95;">Source: ${escapeHtml(
              source,
            )} &middot; ${escapeHtml(at)}</p>
          </td></tr>
        </table>
      </td></tr>
    </table>
  </body>
</html>`;
}
