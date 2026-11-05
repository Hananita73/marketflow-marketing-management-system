import { randomUUID } from 'node:crypto';
import { supabase } from '../src/supabase.js';

const date = new Date().toISOString().slice(0, 10);
const suffix = randomUUID().replaceAll('-', '');
const textId = (prefix) => `${prefix}${suffix.slice(0, 16)}`;
const numericId = -Math.floor(Date.now() % 1_000_000_000) -
  Math.floor(Math.random() * 1_000_000);
const campaignId = textId('SMK');
const budgetId = textId('SMK');
const supportCampaignId = textId('SUP');
const supportCustomerId = numericId - 1;
const supportRecords = [
  {
    table: 'campaigns',
    key: { id: supportCampaignId },
    row: { id: supportCampaignId, name: `Support ${suffix}` },
  },
  {
    table: 'customers',
    key: { id: supportCustomerId },
    row: {
      id: supportCustomerId,
      name: `Support ${suffix}`,
      email: `support-${suffix}@example.invalid`,
    },
  },
];
const records = [
  {
    table: 'campaigns',
    key: { id: campaignId },
    update: { name: `Updated smoke ${suffix}` },
    row: {
      id: campaignId,
      name: `Smoke ${suffix}`,
      description: '',
      target_audience: '',
      notes: '',
      objective: 'brandAwareness',
      channels: [],
      status: 'Draft',
      start_date: null,
      end_date: null,
      budget: 0,
      spent: 0,
      leads: 0,
      conversions: 0,
      impressions: 0,
      roi: 0,
      activities: [],
      coupons: [],
      approval_comments: '',
      approved_by: '',
      submitted_by: '',
    },
  },
  {
    table: 'customers',
    key: { id: numericId },
    update: { name: `Updated smoke ${suffix}` },
    row: {
      id: numericId,
      name: `Smoke ${suffix}`,
      email: `smoke-${suffix}@example.invalid`,
      phone: '0911234567',
      segment: 'Retail',
      status: 'Active',
      last_activity: date,
      joined_at: date,
      lead_id: null,
      opportunity_id: null,
      campaign_id: null,
    },
  },
  {
    table: 'leads',
    key: { id: numericId },
    update: { name: `Updated smoke ${suffix}` },
    row: {
      id: numericId,
      name: `Smoke ${suffix}`,
      company: '',
      email: `lead-${suffix}@example.invalid`,
      phone: '0711234567',
      source: 'Website',
      score: 50,
      assigned_to: '',
      assigned_campaign_id: null,
      status: 'New',
      priority: 'Medium',
      created_at: date,
    },
  },
  {
    table: 'opportunities',
    key: { id: numericId },
    update: { name: `Updated smoke ${suffix}` },
    row: {
      id: numericId,
      name: `Smoke ${suffix}`,
      company: '',
      value: 0,
      owner: '',
      probability: 0,
      stage: 'New',
      created_at: date,
      lead_id: null,
      customer_id: null,
    },
  },
  {
    table: 'budgets',
    key: { id: budgetId },
    update: { name: `Updated smoke ${suffix}` },
    row: {
      id: budgetId,
      name: `Smoke ${suffix}`,
      category: 'Other',
      allocated: 0,
      spent: 0,
      start_date: date,
      end_date: date,
      description: '',
      status: 'Draft',
      last_updated: date,
      campaign_id: null,
    },
  },
  {
    table: 'promotions',
    key: { id: textId('SMK') },
    update: { name: `Updated smoke ${suffix}` },
    row: {
      id: textId('SMK'),
      name: `Smoke ${suffix}`,
      type: 'Percentage',
      discount: '',
      discount_value: 0,
      start_date: date,
      end_date: date,
      usage_limit: 0,
      used_count: 0,
      status: 'Draft',
      campaign_name: '',
      coupon_codes: [],
    },
  },
  {
    table: 'influencers',
    key: { id: textId('SMK') },
    update: { name: `Updated smoke ${suffix}` },
    row: {
      id: textId('SMK'),
      name: `Smoke ${suffix}`,
      handle: '',
      platform: 'Instagram',
      followers: 0,
      engagement_rate: 0,
      category: 'General',
      status: 'Active',
      cost_per_post: 0,
      campaign_name: '',
      avatar_initials: 'SM',
    },
  },
  {
    table: 'content_items',
    key: { id: textId('SMK') },
    update: { title: `Updated smoke ${suffix}` },
    row: {
      id: textId('SMK'),
      title: `Smoke ${suffix}`,
      type: 'Blog Post',
      channel: 'Website',
      creator: '',
      status: 'Draft',
      scheduled_date: date,
      campaign_name: '',
      description: '',
      views: 0,
      clicks: 0,
    },
  },
  {
    table: 'campaign_customers',
    key: {
      campaign_id: supportCampaignId,
      customer_id: supportCustomerId,
    },
    update: { notes: `Updated smoke ${suffix}` },
    row: {
      campaign_id: supportCampaignId,
      customer_id: supportCustomerId,
      participation_status: 'Assigned',
      engagement_status: 'Pending',
      conversion_status: 'Not Converted',
      notes: `Smoke ${suffix}`,
    },
  },
  {
    table: 'expenses',
    key: { id: textId('SMK') },
    update: { name: `Updated smoke ${suffix}` },
    row: {
      id: textId('SMK'),
      campaign_id: supportCampaignId,
      budget_id: null,
      name: `Smoke ${suffix}`,
      description: '',
      category: 'Other',
      amount: 0,
      expense_date: date,
      vendor: '',
      payment_status: 'Pending',
      status: 'pending',
      recorded_by: '',
    },
  },
  {
    table: 'budget_requests',
    key: { id: textId('SMK') },
    update: { description: `Updated smoke ${suffix}` },
    row: {
      id: textId('SMK'),
      budget_id: null,
      campaign_id: supportCampaignId,
      requested_by: '',
      requested_amount: 0,
      category: 'Other',
      description: `Smoke ${suffix}`,
      status: 'Pending',
      reviewed_by: '',
      review_comments: '',
      reviewed_at: null,
    },
  },
  {
    table: 'sms_campaigns',
    key: { id: textId('SMK') },
    update: { name: `Updated smoke ${suffix}` },
    row: {
      id: textId('SMK'),
      name: `Smoke ${suffix}`,
      campaign_id: supportCampaignId,
      message: '',
      status: 'Draft',
      recipient_count: 0,
      sent_count: 0,
      failed_count: 0,
      scheduled_at: null,
      sent_at: null,
      created_by: '',
      provider_ref: '',
      recipients: [],
    },
  },
  {
    table: 'notifications',
    key: { id: textId('SMK') },
    update: { is_read: true },
    row: {
      id: textId('SMK'),
      user_id: null,
      title: `Smoke ${suffix}`,
      message: '',
      category: 'system',
      is_read: false,
    },
  },
  {
    table: 'automation_workflows',
    key: { id: textId('SMK') },
    update: { name: `Updated smoke ${suffix}` },
    row: {
      id: textId('SMK'),
      name: `Smoke ${suffix}`,
      description: '',
      trigger_type: 'Manual',
      trigger_config: {},
      status: 'Draft',
      steps: [],
      run_count: 0,
      last_run_at: null,
      created_by: '',
    },
  },
  {
    table: 'audit_logs',
    key: { id: numericId - 2 },
    update: { record_name: `Updated smoke ${suffix}` },
    row: {
      id: numericId - 2,
      user_id: null,
      user_name: '',
      action: 'create',
      module: 'SmokeTest',
      record_id: suffix,
      record_name: `Smoke ${suffix}`,
      details: { smokeTest: true },
    },
  },
  {
    table: 'crm_sync_log',
    key: { id: numericId - 3 },
    update: { records_imported: 1 },
    row: {
      id: numericId - 3,
      sync_type: 'customers',
      status: 'success',
      records_imported: 0,
      records_updated: 0,
      records_skipped: 0,
      error_message: `Smoke ${suffix}`,
      triggered_by: '',
    },
  },
];

const completed = [];
const createdSupport = [];
const cleanupErrors = [];

function filterByKey(query, key) {
  return Object.entries(key).reduce(
    (filtered, [column, value]) => filtered.eq(column, value),
    query,
  );
}

async function checked(query, operation) {
  const { data, error } = await query;
  if (error) throw new Error(`${operation} failed: ${error.message}`);
  return data;
}

try {
  for (const support of supportRecords) {
    await checked(
      supabase
        .from(support.table)
        .insert(support.row)
        .select(Object.keys(support.key).join(','))
        .single(),
      `POST support ${support.table}`,
    );
    createdSupport.push(support);
  }

  for (const record of records) {
    Object.assign(record.row, record.key);
    const keyColumns = Object.keys(record.key).join(',');
    const keyMatches = (row) =>
      Object.entries(record.key).every(
        ([column, value]) => String(row[column]) === String(value),
      );
    const inserted = await checked(
      supabase.from(record.table).insert(record.row).select(keyColumns).single(),
      `POST ${record.table}`,
    );
    completed.push(record);
    if (!keyMatches(inserted)) {
      throw new Error(`POST ${record.table} returned the wrong key`);
    }

    const fetched = await checked(
      filterByKey(supabase.from(record.table).select('*'), record.key).single(),
      `GET ${record.table}/${keyColumns}`,
    );
    if (!keyMatches(fetched)) {
      throw new Error(`GET ${record.table} returned the wrong id`);
    }

    const allRows = await checked(
      supabase.from(record.table).select(keyColumns).range(0, 999),
      `GET ${record.table} (fetch all)`,
    );
    if (!Array.isArray(allRows)) {
      throw new Error(`GET ${record.table} (fetch all) returned invalid data`);
    }

    const updated = await checked(
      filterByKey(
        supabase.from(record.table).update(record.update),
        record.key,
      )
        .select('*')
        .single(),
      `PATCH ${record.table}/${keyColumns}`,
    );
    const updatedField = Object.keys(record.update)[0];
    if (updated[updatedField] !== record.update[updatedField]) {
      throw new Error(`PATCH ${record.table} did not persist the updated field`);
    }

    const deleted = await checked(
      filterByKey(
        supabase.from(record.table).delete(),
        record.key,
      )
        .select(keyColumns)
        .single(),
      `DELETE ${record.table}/${keyColumns}`,
    );
    if (!keyMatches(deleted)) {
      throw new Error(`DELETE ${record.table} removed the wrong row`);
    }
    completed.pop();
    console.log(`PASS ${record.table}: POST, GET, fetch-all, PATCH, DELETE`);
  }
} finally {
  for (const record of completed.reverse()) {
    const { error } = await filterByKey(
      supabase.from(record.table).delete(),
      record.key,
    );
    if (error) {
      cleanupErrors.push(`${record.table}: ${error.message}`);
    }
  }
  for (const support of createdSupport.reverse()) {
    const { error } = await filterByKey(
      supabase.from(support.table).delete(),
      support.key,
    );
    if (error) {
      cleanupErrors.push(`support ${support.table}: ${error.message}`);
    }
  }
}

if (cleanupErrors.length > 0) {
  throw new Error(`Smoke row cleanup failed: ${cleanupErrors.join('; ')}`);
}

console.log(`CRUD smoke test passed for ${records.length} Flutter data tables.`);
