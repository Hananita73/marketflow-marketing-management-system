import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marketing_management_system/models/opportunity.dart';
import 'package:marketing_management_system/services/entity_remote_stores.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final requests = <http.Request>[];
  String? failingTable;

  late MockClient client;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    client = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      final table = path.split('/').last;
      http.Response response(
        String body,
        int statusCode, {
        Map<String, String> headers = const {},
      }) => http.Response(body, statusCode, headers: headers, request: request);

      if (failingTable == table) {
        return response(
          jsonEncode({'message': 'mock database failure'}),
          403,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/rpc/list_opportunity_users')) {
        return response(
          jsonEncode([
            {
              'id': 'user-1',
              'full_name': 'Test User',
              'email': 'test@example.com',
              'role': 'sales',
              'department': 'Marketing',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (table == 'opportunities' && request.method == 'GET') {
        return response(
          jsonEncode([
            {
              'id': 42,
              'name': 'Test opportunity',
              'company': 'Example Co',
              'value': 12000,
              'owner': 'Test User',
              'probability': 70,
              'stage': 'Proposal',
              'created_at': '2026-10-01T10:00:00Z',
              'lead_id': '5',
              'customer_id': '8',
              'created_by': 'user-1',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (table == 'opportunity_followers' && request.method == 'GET') {
        return response(
          jsonEncode([
            {
              'opportunity_id': 42,
              'user_id': 'user-1',
              'user_name': 'Test User',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (table == 'opportunity_progress' && request.method == 'GET') {
        return response(
          jsonEncode([
            {
              'id': 5,
              'opportunity_id': 42,
              'note': 'Proposal sent',
              'stage': 'Proposal',
              'value': 12000,
              'probability': 70,
              'changed_by_name': 'Test User',
              'created_at': '2026-10-02T10:30:00Z',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.method == 'DELETE' && table == 'opportunities') {
        if (request.url.queryParameters['id'] == 'eq.99') {
          return response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return response(
          jsonEncode([
            {'id': 42},
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return response('', 204);
    });

    await Supabase.initialize(
      url: 'https://test-project.supabase.co',
      publishableKey: 'test-publishable-key',
      httpClient: client,
      debug: false,
    );
  });

  setUp(() {
    requests.clear();
    failingTable = null;
  });

  tearDownAll(() async {
    client.close();
  });

  test('GET opportunities includes follower details', () async {
    final opportunities = await OpportunityRemoteStore.fetchAll();

    expect(opportunities, hasLength(1));
    expect(opportunities!.single.id, 42);
    expect(opportunities.single.leadId, '5');
    expect(opportunities.single.customerId, '8');
    expect(opportunities.single.followerIds, ['user-1']);
    expect(opportunities.single.followerNames, ['Test User']);
    expect(
      requests.map((request) => request.url.path),
      containsAll(['/rest/v1/opportunities', '/rest/v1/opportunity_followers']),
    );
  });

  test('GET assignable users calls the opportunity-user RPC', () async {
    final users = await OpportunityRemoteStore.fetchAssignableUsers();

    expect(users, hasLength(1));
    expect(users.single['id'], 'user-1');
    expect(users.single['full_name'], 'Test User');
    expect(requests.single.url.path, '/rest/v1/rpc/list_opportunity_users');
    expect(requests.single.method, 'POST');
  });

  test('GET progress history maps note and opportunity snapshot', () async {
    final history = await OpportunityRemoteStore.fetchProgress(42);

    expect(history, hasLength(1));
    expect(history.single.opportunityId, 42);
    expect(history.single.note, 'Proposal sent');
    expect(history.single.stage, 'Proposal');
    expect(history.single.value, 12000);
    expect(history.single.probability, 70);
    expect(history.single.changedByName, 'Test User');
    expect(requests.single.url.queryParameters['opportunity_id'], 'eq.42');
    expect(requests.single.url.queryParameters['limit'], '50');
  });

  test(
    'save upserts opportunity, syncs followers, and appends progress',
    () async {
      final saved = await OpportunityRemoteStore.save(
        _opportunity(),
        progressNote: 'Proposal sent',
        followers: const [
          {'id': 'user-1', 'name': 'Test User'},
        ],
      );

      expect(saved, isTrue);
      expect(
        requests.map((request) => '${request.method} ${request.url.path}'),
        [
          'POST /rest/v1/opportunities',
          'DELETE /rest/v1/opportunity_followers',
          'POST /rest/v1/opportunity_followers',
          'POST /rest/v1/opportunity_progress',
        ],
      );

      final opportunityBody = jsonDecode(requests[0].body) as Map;
      expect(opportunityBody['name'], 'Test opportunity');
      expect(opportunityBody['lead_id'], '5');
      expect(opportunityBody['customer_id'], '8');

      final followerBody = jsonDecode(requests[2].body) as List;
      expect(followerBody.single['opportunity_id'], 42);
      expect(followerBody.single['user_id'], 'user-1');

      final progressBody = jsonDecode(requests[3].body) as Map;
      expect(progressBody['note'], 'Proposal sent');
      expect(progressBody['stage'], 'Proposal');
      expect(progressBody['probability'], 70);
    },
  );

  test('save omits progress insert when there is no progress note', () async {
    final saved = await OpportunityRemoteStore.save(_opportunity());

    expect(saved, isTrue);
    expect(requests.map((request) => request.url.path), [
      '/rest/v1/opportunities',
      '/rest/v1/opportunity_followers',
    ]);
  });

  test('save reports failure when opportunity write is rejected', () async {
    failingTable = 'opportunities';

    final saved = await OpportunityRemoteStore.save(_opportunity());

    expect(saved, isFalse);
    expect(requests, hasLength(1));
  });

  test('save reports failure when progress insert is rejected', () async {
    failingTable = 'opportunity_progress';

    final saved = await OpportunityRemoteStore.save(
      _opportunity(),
      progressNote: 'Proposal sent',
    );

    expect(saved, isFalse);
    expect(
      requests.map((request) => request.url.path),
      contains('/rest/v1/opportunity_progress'),
    );
  });

  test('GET progress history propagates API errors', () async {
    failingTable = 'opportunity_progress';

    await expectLater(
      OpportunityRemoteStore.fetchProgress(42),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('DELETE opportunity confirms a matching row was deleted', () async {
    final deleted = await OpportunityRemoteStore.delete(42);

    expect(deleted, isTrue);
    expect(requests.single.method, 'DELETE');
    expect(requests.single.url.path, '/rest/v1/opportunities');
    expect(requests.single.url.queryParameters['id'], 'eq.42');
  });

  test('DELETE opportunity reports failure when no row matches', () async {
    final deleted = await OpportunityRemoteStore.delete(99);

    expect(deleted, isFalse);
  });
}

Opportunity _opportunity() => Opportunity(
  id: 42,
  name: 'Test opportunity',
  company: 'Example Co',
  value: 12000,
  owner: 'Test User',
  probability: 70,
  stage: 'Proposal',
  leadId: '5',
  customerId: '8',
  createdAt: DateTime.utc(2026, 10, 1),
  createdBy: 'user-1',
  lastProgress: 'Proposal sent',
  lastProgressBy: 'Test User',
);
