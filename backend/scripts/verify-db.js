import { verifyDatabase } from '../src/db.js';

const report = await verifyDatabase();
console.log(JSON.stringify(report, null, 2));
process.exit(report.ok ? 0 : 1);
