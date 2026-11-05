import { Router } from 'express';
import { config } from '../config.js';
import { sendEmail } from '../mailer.js';

export const adminRouter = Router();

adminRouter.use((req, res, next) => {
  if (!config.admin.apiToken) {
    return res.status(503).json({ error: 'ADMIN_API_TOKEN is not configured' });
  }

  const token = (req.get('authorization') || '').replace(/^Bearer\s+/i, '').trim();
  if (token !== config.admin.apiToken) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  return next();
});

adminRouter.post('/email', async (req, res, next) => {
  try {
    const { to, subject, html, text } = req.body ?? {};
    const recipients = to || config.admin.email;

    if (!subject || (!html && !text)) {
      return res.status(400).json({ error: 'subject and either html or text are required' });
    }
    if (!recipients) {
      return res.status(400).json({ error: 'to (or ADMIN_EMAIL) is required' });
    }

    const result = await sendEmail({ to: recipients, subject, html, text });
    return res.status(202).json({ id: result.id ?? null });
  } catch (error) {
    return next(error);
  }
});
