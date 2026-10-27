import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fe/features/routines/data/models/routine.dart';

/// Stateful HTTP contract fixture, not a live backend or AI implementation.
class MvpContractServer {
  MvpContractServer({this.email = 'qa@example.com'});
  final String email;
  final requests = <(String, String)>[];
  final now = DateTime.now().toUtc();
  late final today = routineDate(now.add(const Duration(hours: 9)));
  bool registered = false,
      profileSaved = false,
      analyzed = false,
      generated = false,
      removed = false;
  bool photoConsent = true, aiConsent = true, loseNextSet = false;
  String name = 'QA 회원';
  Map<String, dynamic>? goal, log;
  String routineStatus = 'planned';
  final sets = <Map<String, dynamic>>[];
  int setPosts = 0, completePosts = 0;
  Map<String, dynamic> get exercise => {
    'exercise_id': 7,
    'name': '바벨 스쿼트',
    'target_part': 'leg',
    'equipment': 'barbell',
    'difficulty': 2,
    'min_sets': 3,
    'max_sets': 4,
    'description': '테스트 종목',
    'media_url': null,
  };
  Map<String, dynamic> get profile => {
    'height_cm': 174,
    'weight_kg': 68,
    'age': 20,
    'gender': 'male',
    'goal_type': 'muscle',
    'weekly_frequency': 3,
    'experience_level': 'under3m',
  };
  Map<String, dynamic> get me => {
    'user_id': 7,
    'email': email,
    'nickname': name,
    'role': 'user',
    'onboarding_completed': profileSaved,
    'consent_completed': photoConsent && aiConsent,
    'body_photo_agreed': photoConsent,
    'ai_processing_agreed': aiConsent,
    'created_at': now.toIso8601String(),
  };
  Map<String, dynamic> get routine => {
    'routine_id': 44,
    'analysis_id': 31,
    'scheduled_date': routineDateKey(today),
    'title': 'QA 하체 루틴',
    'target_part': 'leg',
    'estimated_minutes': 30,
    'status': routineStatus,
    'items': [
      {
        'item_id': 201,
        'order_no': 1,
        'target_sets': 3,
        'target_reps': 10,
        'target_weight_kg': null,
        'rest_sec': 90,
        'done': log?['status'] == 'completed',
        'exercise': exercise,
      },
    ],
  };
  Map<String, dynamic> get detail => {
    ...log!,
    'exercise': exercise,
    'sets': sets,
    'set_count': sets.where((s) => s['is_done'] == true).length,
    'total_volume_kg': sets
        .where((s) => s['is_done'] == true)
        .fold<num>(
          0,
          (v, s) => v + (s['weight_kg'] as num) * (s['reps'] as int),
        ),
  };
  http.Response json(Object data, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(data)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  http.Response error(String code, int status) => json({
    'code': code,
    'message': code,
    'status': status,
    'fields': null,
  }, status);
  late final client = MockClient((q) async {
    final path = q.url.path, method = q.method;
    requests.add((method, path));
    final body =
        q.headers['content-type']?.startsWith('multipart/') == true ||
            q.body.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(q.body) as Map);
    final public = [
      '/api/auth/email-verifications',
      '/api/auth/email-verifications/confirm',
      '/api/users',
      '/api/auth/login',
    ].contains(path);
    if (!public &&
        (removed || q.headers['Authorization'] != 'Bearer qa-token')) {
      return error('UNAUTHORIZED', 401);
    }
    switch ((method, path)) {
      case ('POST', '/api/auth/email-verifications'):
        return http.Response('', 204);
      case ('POST', '/api/auth/email-verifications/confirm'):
        return body['code'] == '123456'
            ? json({'verification_token': 'verified', 'expires_in': 1800})
            : error('EMAIL_CODE_INVALID', 400);
      case ('POST', '/api/users'):
        if (body['email_verification_token'] != 'verified') {
          return error('VALIDATION_FAILED', 400);
        }
        registered = true;
        name = body['nickname'] as String;
        return json({'user_id': 7}, 201);
      case ('POST', '/api/auth/login'):
        if (!registered) return error('UNAUTHORIZED', 401);
        return json({
          'access_token': 'qa-token',
          'token_type': 'Bearer',
          'expires_in': 604800,
          'onboarding_completed': profileSaved,
        });
      case ('GET', '/api/users/me'):
        return json(me);
      case ('PATCH', '/api/users/me'):
        name = body['nickname'] as String? ?? name;
        photoConsent = body['body_photo_agreed'] as bool? ?? photoConsent;
        aiConsent = body['ai_processing_agreed'] as bool? ?? aiConsent;
        return json(me);
      case ('DELETE', '/api/users/me'):
        removed = true;
        return http.Response('', 204);
      case ('POST', '/api/users/me/profile'):
      case ('PATCH', '/api/users/me/profile'):
        profileSaved = true;
        return json(profile);
      case ('GET', '/api/users/me/profile'):
        return profileSaved ? json(profile) : error('PROFILE_NOT_FOUND', 404);
      case ('POST', '/api/photos'):
        return json({
          'photo_id': 11,
          'type': 'current',
          'side': 'front',
          'url': 'https://example.test/photo',
          'url_expires_at': now.add(const Duration(hours: 1)).toIso8601String(),
          'created_at': now.toIso8601String(),
        }, 201);
      case ('GET', '/api/goal-bodies'):
        return goal == null ? error('GOAL_NOT_FOUND', 404) : json(goal!);
      case ('POST', '/api/goal-bodies'):
        goal = {
          'goal_body_id': 5,
          'status': 'done',
          'description': body['description'],
          'summary': 'QA 목표',
          'created_at': now.toIso8601String(),
        };
        return json(goal!, 201);
      case ('GET', '/api/body-analyses/usage'):
        return json({
          'used': analyzed ? 1 : 0,
          'limit': 3,
          'remaining': analyzed ? 2 : 3,
          'reset_at': now.add(const Duration(days: 1)).toIso8601String(),
        });
      case ('POST', '/api/body-analyses/photo'):
        analyzed = true;
        return json({'analysis_id': 31, 'status': 'pending'}, 202);
      case ('GET', '/api/body-analyses/31'):
        return json({
          'analysis_id': 31,
          'status': 'done',
          'balance_score': 80,
          'body_type': '균형형',
          'created_at': now.toIso8601String(),
          'measures': {'neck_forward_deg': null},
        });
      case ('GET', '/api/body-analyses'):
        return json({
          'items': analyzed
              ? [
                  {
                    'analysis_id': 31,
                    'status': 'done',
                    'created_at': now.toIso8601String(),
                  },
                ]
              : [],
          'page': 1,
          'total': analyzed ? 1 : 0,
        });
      case ('GET', '/api/exercises'):
        return json({
          'items': [exercise],
          'page': 1,
          'total': 1,
        });
      case ('GET', '/api/exercises/7'):
        return json(exercise);
      case ('POST', '/api/routines'):
        generated = true;
        return json({
          'analysis_id': 31,
          'routines': [routine],
        });
      case ('GET', '/api/routines/44'):
        return generated ? json(routine) : error('NOT_FOUND', 404);
      case ('PATCH', '/api/routines/44'):
        routineStatus = body['status'] as String;
        return json(routine);
      case ('GET', '/api/routines/today'):
        return json({
          'is_rest_day': !generated,
          'routine': generated ? routine : null,
        });
      case ('GET', '/api/routines/weekly'):
        final start = DateTime.parse(q.url.queryParameters['week_start']!);
        return json({
          'week_start': routineDateKey(start),
          'days': [
            for (var n = 0; n < 7; n++)
              {
                'date': routineDateKey(start.add(Duration(days: n))),
                'is_rest_day':
                    !generated ||
                    routineDate(start.add(Duration(days: n))) != today,
                'routine':
                    generated &&
                        routineDate(start.add(Duration(days: n))) == today
                    ? {
                        'routine_id': 44,
                        'title': 'QA 하체 루틴',
                        'target_part': 'leg',
                        'estimated_minutes': 30,
                        'status': routineStatus,
                        'item_count': 1,
                        'done_count': routineStatus == 'done' ? 1 : 0,
                      }
                    : null,
              },
          ],
        });
      case ('POST', '/api/workout-logs'):
        final resumed = log?['status'] == 'in_progress';
        log ??= {
          'log_id': 87,
          'exercise_id': 7,
          'routine_id': body['routine_id'],
          'started_at': now.toIso8601String(),
          'workout_date': routineDateKey(today),
          'status': 'in_progress',
          'duration_sec': null,
          'completed_at': null,
          'memo': null,
        };
        return json({...log!, 'resumed': resumed}, resumed ? 200 : 201);
      case ('GET', '/api/workout-logs/87'):
        return log == null ? error('NOT_FOUND', 404) : json(detail);
      case ('POST', '/api/workout-logs/87/sets'):
        setPosts++;
        final existing = sets
            .where((s) => s['client_set_id'] == body['client_set_id'])
            .firstOrNull;
        if (existing != null) return json(existing);
        final set = {
          ...body,
          'set_id': sets.length + 1,
          'version': 1,
          'rest_sec': body['rest_sec'],
        };
        sets.add(set);
        if (loseNextSet) {
          loseNextSet = false;
          throw http.ClientException('response lost');
        }
        return json(set, 201);
      case ('PATCH', '/api/workout-logs/87/sets/1'):
        final set = sets.first;
        if (body['version'] != set['version']) {
          return error('VERSION_CONFLICT', 409);
        }
        sets[0] = {...set, ...body, 'version': (set['version'] as int) + 1};
        return json(sets[0]);
      case ('PATCH', '/api/workout-logs/87/complete'):
        completePosts++;
        log!.addAll({
          'status': 'completed',
          'duration_sec': 600,
          'completed_at': now
              .add(const Duration(minutes: 10))
              .toIso8601String(),
          'memo': body['memo'],
        });
        routineStatus = 'done';
        return json({
          'log_id': 87,
          'completed_at': log!['completed_at'],
          'duration_sec': 600,
          'set_count': detail['set_count'],
          'total_volume_kg': detail['total_volume_kg'],
          'routine_progress': {'done': 1, 'total': 1},
          'routine_status': 'done',
        });
      case ('DELETE', '/api/workout-logs/87'):
        log = null;
        sets.clear();
        routineStatus = 'planned';
        return http.Response('', 204);
      case ('GET', '/api/workout-logs'):
        final start = routineDate(
              DateTime.parse(q.url.queryParameters['start_date']!),
            ),
            end = routineDate(
              DateTime.parse(q.url.queryParameters['end_date']!),
            );
        final inRange =
            log != null && !today.isBefore(start) && !today.isAfter(end);
        final completed = inRange && log!['status'] == 'completed';
        final status = q.url.queryParameters['status'];
        return json({
          'items': inRange && (status == null || status == log!['status'])
              ? [detail]
              : [],
          'page': 1,
          'total': inRange && (status == null || status == log!['status'])
              ? 1
              : 0,
          'summary': {
            'log_count': completed ? 1 : 0,
            'total_sets': completed ? detail['set_count'] : 0,
            'total_volume_kg': completed ? detail['total_volume_kg'] : 0,
            'total_duration_sec': completed ? 600 : 0,
            'workout_days': completed ? 1 : 0,
            'workout_dates': completed ? [routineDateKey(today)] : [],
          },
        });
      default:
        throw StateError('Unhandled contract request: $method $path');
    }
  });
}
