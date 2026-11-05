import express from 'express';
import cors from 'cors';
import { config } from './config.js';
import { supabase } from './supabase.js';
import { healthRouter } from './routes/health.js';
import { createDataRouter } from './routes/data.js';
import { adminRouter } from './routes/admin.js';
import { alertsRouter } from './routes/alerts.js';
import { buildAlertHtml, notifyAdmin } from './alerts.js';

const app = express();
app.disable('x-powered-by');
app.use(
  cors({
    origin: config.corsOrigin === '*' ? true : config.corsOrigin.split(',').map((item) => item.trim()),
  }),
);
app.use(express.json({ limit: '1mb' }));

app.use(healthRouter);
// Mounted before the generic /api data router so `/api/alerts` is not
// mistaken for an entity named "alerts".
app.use('/api/alerts', alertsRouter);
app.use('/api', createDataRouter(supabase));
app.use('/api/admin', adminRouter);

app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

app.use((error, req, res, next) => {
  console.error(error);
  const status = error.status ?? 500;

  // Unexpected server-side failures are worth an email to the admin.
  if (status >= 500) {
    const at = new Date().toISOString();
    notifyAdmin({
      subject: `[MarkFlow] ERROR · ${req.method} ${req.originalUrl} failed`,
      text: [
        error.message || 'Unhandled server error',
        '',
        `Route : ${req.method} ${req.originalUrl}`,
        `Status: ${status}`,
        `Time  : ${at}`,
      ].join('\n'),
      html: buildAlertHtml({
        severity: 'error',
        event: 'Unhandled server error',
        message: error.message || String(error),
        source: 'backend',
        details: { route: `${req.method} ${req.originalUrl}`, status },
        at,
      }),
      dedupeKey: `srv5xx:${req.method}:${req.originalUrl}`,
    });
  }

  res.status(status).json({ error: error.message ?? 'Internal server error' });
});

const server = app.listen(config.port, () => {
  console.log(`MarkFlow backend listening on http://localhost:${config.port}`);
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    server.close(() => process.exit(0));
  });
}
