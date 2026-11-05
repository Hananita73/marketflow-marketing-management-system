import { Router } from 'express';
import { verifyDatabase } from '../db.js';

export const healthRouter = Router();

healthRouter.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    uptimeSeconds: Math.round(process.uptime()),
    timestamp: new Date().toISOString(),
  });
});

healthRouter.get('/db/verify', async (req, res, next) => {
  try {
    const report = await verifyDatabase();
    res.status(report.ok ? 200 : 503).json(report);
  } catch (error) {
    next(error);
  }
});
