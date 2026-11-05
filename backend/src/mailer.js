import { config } from './config.js';

function httpError(message, status) {
  const error = new Error(message);
  error.status = status;
  return error;
}

export async function sendEmail({ to, subject, html, text }) {
  if (!config.resend.apiKey) {
    throw httpError('RESEND_API_KEY is not configured', 503);
  }

  const recipients = (Array.isArray(to) ? to : String(to ?? '').split(','))
    .map((value) => String(value).trim())
    .filter(Boolean);

  if (recipients.length === 0) {
    throw httpError('At least one recipient email is required', 400);
  }

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.resend.apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: config.resend.from,
      to: recipients,
      subject,
      ...(html ? { html } : {}),
      ...(text ? { text } : {}),
    }),
  });

  const payload = await response.json().catch(() => ({}));

  if (!response.ok) {
    const message =
      payload.message || payload.error || `Resend request failed with status ${response.status}`;
    throw httpError(message, 502);
  }

  return payload;
}
