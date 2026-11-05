const fs = require('fs');
const path = require('path');
const {
  AlignmentType,
  BorderStyle,
  Document,
  Footer,
  HeadingLevel,
  Packer,
  PageNumber,
  Paragraph,
  ShadingType,
  Table,
  TableCell,
  TableRow,
  TextRun,
  WidthType,
} = require('docx');

const out = path.join(__dirname, 'markflow_role_dashboards_database_backend.docx');
const navy = '17365D';
const lightBlue = 'EAF2F8';
const lightGray = 'F5F7FA';
const border = { style: BorderStyle.SINGLE, size: 4, color: 'D9D9D9' };

function cell(text, opts = {}) {
  return new TableCell({
    width: opts.width ? { size: opts.width, type: WidthType.PERCENTAGE } : undefined,
    shading: opts.header ? { fill: navy, type: ShadingType.CLEAR } : opts.shading ? { fill: opts.shading, type: ShadingType.CLEAR } : undefined,
    margins: { top: 110, bottom: 110, left: 130, right: 130 },
    verticalAlign: 'center',
    children: [new Paragraph({
      alignment: opts.align || AlignmentType.LEFT,
      children: [new TextRun({ text: String(text), bold: !!opts.header, color: opts.header ? 'FFFFFF' : '000000', size: opts.size || 20 })],
    })],
  });
}

function table(headers, rows, widths) {
  const header = new TableRow({ children: headers.map((h, i) => cell(h, { header: true, width: widths?.[i] })) });
  const body = rows.map((row, ri) => new TableRow({ children: row.map((v, i) => cell(v, { width: widths?.[i], shading: ri % 2 ? lightGray : 'FFFFFF' })) }));
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    borders: { top: border, bottom: border, left: border, right: border, insideHorizontal: border, insideVertical: border },
    rows: [header, ...body],
  });
}

function heading(text, level = HeadingLevel.HEADING_1) {
  return new Paragraph({ heading: level, spacing: { before: 240, after: 120 }, children: [new TextRun({ text, color: '000000' })] });
}

function para(text, opts = {}) {
  return new Paragraph({ spacing: { after: opts.after ?? 120, line: 276 }, children: [new TextRun({ text, bold: opts.bold, italic: opts.italic })] });
}

function bullet(text) {
  return new Paragraph({ bullet: { level: 0 }, spacing: { after: 60 }, children: [new TextRun({ text })] });
}

const roles = [
  ['Administrator', 'System control center', 'All modules, users, roles, settings, and data administration.', 'Users & Roles; Settings; Reports'],
  ['Marketing Manager', 'Growth command center', 'Campaign delivery, pipeline movement, budget and ROI decisions.', 'Campaigns; Leads; Budget; Reports'],
  ['Marketing Staff', 'Execution workspace', 'Content publishing, lead follow-up, and campaign execution.', 'Content; Leads; Campaigns'],
  ['Analyst', 'Analysis workspace', 'ROI, conversion quality, lead scoring, and performance analysis.', 'Reports; Campaigns; Leads; Budget'],
  ['Viewer', 'Read only overview', 'Approved campaign and customer progress without record changes.', 'Campaigns; Reports'],
];

const schema = [
  ['public', 'campaigns', 'text id; name; description; target_audience; notes; objective; channels[]; status; dates; budget; spent; leads; conversions; impressions; roi; activities jsonb; coupons jsonb; created_at; updated_at', 'CampaignRemoteService / CampaignRepository'],
  ['public', 'budgets', 'text id; name; category; allocated; spent; start_date; end_date; description; status; last_updated', 'BudgetRemoteStore / BudgetRepository'],
  ['public', 'content_items', 'text id; title; type; channel; creator; status; scheduled_date; campaign_name; description; views; clicks', 'ContentRemoteStore / ContentRepository'],
  ['public', 'customers', 'identity id; name; email; phone; segment; status; last_activity; joined_at', 'CustomerRemoteStore / CustomerRepository'],
  ['public', 'influencers', 'text id; name; handle; platform; followers; engagement_rate; category; status; cost_per_post; campaign_name; avatar_initials', 'InfluencerRemoteStore / InfluencerRepository'],
  ['public', 'leads', 'identity id; name; company; email; phone; source; score; assigned_to; status; priority; created_at', 'LeadRemoteStore / LeadRepository'],
  ['public', 'opportunities', 'identity id; name; company; value; owner; probability; stage; created_at', 'OpportunityRemoteStore / OpportunityRepository'],
  ['public', 'promotions', 'text id; name; type; discount; discount_value; dates; usage_limit; used_count; status; campaign_name; coupon_codes[]', 'PromotionRemoteStore / PromotionRepository'],
  ['public', 'users', 'uuid id linked to auth.users; full_name; email; role; department; status; created_at', 'AuthService list/update/admin create'],
];

const crud = [
  ['campaigns', 'fetchAll, seed, upsert, delete', 'Campaign list/create/edit/delete screens', 'Dashboard campaign KPIs, charts, activity, top campaigns'],
  ['budgets', 'fetchAll, seed, upsert, delete', 'Budget screen CRUD', 'Budget spend, remaining, utilization'],
  ['content_items', 'fetchAll, seed, upsert, delete', 'Content screen CRUD', 'Role staff workspace and activity context'],
  ['customers', 'fetchAll, seed, upsert, delete', 'Customers screen CRUD', 'Customer totals and conversion workflow'],
  ['influencers', 'fetchAll, seed, upsert, delete', 'Influencers screen CRUD', 'Campaign and promotion planning data'],
  ['leads', 'fetchAll, seed, upsert, delete', 'Leads screen CRUD and conversion', 'Lead totals, source chart, conversion rate, score'],
  ['opportunities', 'fetchAll, seed, upsert, delete', 'Opportunities screen CRUD and stage changes', 'Pipeline and manager workflow'],
  ['promotions', 'fetchAll, seed, upsert, delete', 'Promotions screen CRUD', 'Campaign execution and promotion planning'],
  ['users', 'listUsers, updateUserProfile, adminCreateUser', 'Users and Roles screen; delete is a status deactivation', 'Role and permission context; profile loading'],
];

const children = [
  new Paragraph({ style: 'Title', alignment: AlignmentType.CENTER, spacing: { after: 80 }, children: [new TextRun({ text: 'MarkFlow Marketing Management System', bold: true, size: 34, color: '000000' })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 260 }, children: [new TextRun({ text: 'Role based dashboards database synchronization and backend guide', size: 22, color: '404040' })] }),
  para('This document explains how the dashboard changes by role, how the nine public tables are used, and how create read update and delete operations reach Supabase. It also records the login reload behavior that makes the dashboard live after authentication.'),

  heading('Role based dashboard behavior'),
  para('The dashboard reads the authenticated role from public.users through AuthService. DashboardScreen then selects role-specific KPIs, actions, and a working surface. The common charts remain permission-filtered, while the first workspace card is different for each role.'),
  table(['Role', 'Dashboard workspace', 'Primary focus', 'Visible actions'], roles, [18, 24, 35, 23]),
  para('AccessService is the shared permission gate. It checks view, create, edit, and delete against the permission matrix before a module or CRUD action is shown. The dashboard also hides budget KPIs when the role cannot view Budget and hides quick actions when the role has no create permission.'),

  heading('Database schema'),
  para('The application uses Supabase Postgres in the public schema. Numeric identifiers are generated by Postgres for customers, leads, and opportunities. Text identifiers are generated by the Flutter repositories for campaigns, budgets, promotions, influencers, and content items. The users table is linked to Supabase Auth by UUID.'),
  table(['Schema', 'Table', 'Important columns', 'Application mapping'], schema, [10, 16, 49, 25]),
  para('Campaigns has an updated_at trigger. Customers enforce unique email. Numeric fields use check constraints for non-negative values and lead score and probability are constrained to 0 through 100. Arrays and JSON fields preserve channel, coupon, activity, and campaign detail without losing information between Flutter and Postgres.'),

  heading('CRUD and live database flow'),
  para('Every business repository follows the same flow: a screen updates the repository, the repository updates the in-memory list for responsive UI, and a remote store writes the same model to Supabase. On startup the repositories load remote rows; if a table is empty they seed the bundled rows. If the network is unavailable, the UI keeps the local fallback and reports the failure through AdminAlertService.'),
  table(['Table', 'CRUD methods', 'Screens and workflows', 'Dashboard consumers'], crud, [17, 28, 30, 25]),
  para('After a successful login or restored session, RepositorySync.reloadAll forces a fresh authenticated read for all eight business repositories. This is important because the first boot can occur before authentication, when RLS correctly blocks table reads. Without the post-login reload, the UI could continue showing fallback seed data even though records had already changed in Supabase.'),

  heading('Backend and API'),
  para('The Node backend is in backend/src. server.js configures Express, CORS, JSON parsing, health checks, alerts, the generic data router, and admin routes. routes/data.js exposes the same CRUD contract for every allow-listed table in config.js.'),
  table(['HTTP operation', 'Route', 'Database action', 'Response'], [
    ['GET', '/api/:entity', 'select with limit offset order and equality filters', '{ data, count, limit, offset }'],
    ['GET', '/api/:entity/:id', 'select one row by id', '{ data } or 404'],
    ['POST', '/api/:entity', 'insert request body and return inserted row', '201 { data }'],
    ['PATCH', '/api/:entity/:id', 'update by id and return updated row', '{ data } or 404'],
    ['DELETE', '/api/:entity/:id', 'delete by id', '204 or 404'],
  ], [18, 28, 34, 20]),
  para('The router allow-lists campaigns, customers, leads, opportunities, budgets, promotions, influencers, content_items, and users. Supabase is the persistence layer; the backend uses its configured key for server-side requests and emits an admin alert for database failures. Flutter currently uses the Supabase client directly for the repositories and AuthService, while the backend remains available for integrations and server-side operations.'),

  heading('Authentication and row level security'),
  para('AuthService signs in with Supabase Auth, loads the matching public.users profile, checks status, caches role permissions, and then reloads repositories. RLS policies in the production migration restrict table access to authenticated users. Authenticated users can read application data; inserts and updates are allowed for the shared workspace; deletes on business tables are restricted to the admin role. User profile updates are self-only unless the current application role is admin.'),
  bullet('Keep the publishable key in Flutter. Never put the Supabase service role key in the Flutter application.'),
  bullet('Apply supabase_schema.sql and the migrations in order before testing live CRUD.'),
  bullet('Deploy the admin-create-user Edge Function before using the invite action in Users and Roles.'),

  heading('Files changed for live role behavior'),
  table(['File', 'Purpose'], [
    ['lib/screens/dashboard/dashboard_screen.dart', 'Role-specific workspaces, KPI selection, and permission-filtered actions.'],
    ['lib/services/repository_sync.dart', 'Authenticated reload of all business repositories.'],
    ['lib/services/auth_service.dart', 'Reloads repositories after sign-in and session restore.'],
    ['lib/models/*.dart', 'Repository init methods accept force so post-login reload is possible.'],
    ['docx/markflow_role_dashboards_database_backend.docx', 'This implementation and operations guide.'],
  ], [35, 65]),

  heading('Operational checklist'),
  bullet('Apply the schema and RLS migrations in Supabase.'),
  bullet('Create or approve an authenticated user profile in public.users.'),
  bullet('Sign in and confirm the role-specific dashboard workspace appears.'),
  bullet('Create, edit, and delete a permitted record; verify it in the matching public table.'),
  bullet('Refresh or sign out and sign in again; confirm the repository reload shows the saved row.'),
  bullet('For users, verify role and status changes through the Users and Roles screen and remember that delete is implemented as deactivation.'),
];

const doc = new Document({
  creator: 'MarkFlow',
  title: 'MarkFlow Role Based Dashboards Database Backend Guide',
  description: 'Role dashboards, Supabase schema, CRUD synchronization, and backend operations.',
  sections: [{
    properties: { page: { margin: { top: 720, right: 720, bottom: 720, left: 720 } } },
    footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: 'MarkFlow implementation guide  |  ', size: 18 }), PageNumber.CURRENT] })] }) },
    children,
  }],
});

Packer.toBuffer(doc).then((buffer) => fs.writeFileSync(out, buffer));
