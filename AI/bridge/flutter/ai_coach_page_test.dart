import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ai_coach_page.dart';

void main() {
  testWidgets('loads saved messages and displays a confirmed Qwen turn', (
    tester,
  ) async {
    final calls = <String>[];
    Future<Map<String, dynamic>?> request(
      String method,
      String path,
      Map<String, dynamic>? body,
    ) async {
      calls.add('$method $path');
      if (method == 'GET') return {'messages': <Object>[]};
      return {
        'user_message': {'role': 'user', 'content': body!['content']},
        'assistant_message': {
          'role': 'assistant',
          'content': '꾸준히 조금씩 시작해 보세요.',
          'model': 'qwen3:4b',
        },
      };
    }

    await tester.pumpWidget(MaterialApp(home: AiCoachPage(request: request)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '꾸준히 운동하는 팁');
    await tester.tap(find.text('보내기'));
    await tester.pumpAndSettle();
    expect(find.text('꾸준히 조금씩 시작해 보세요.'), findsOneWidget);
    expect(find.text('코치 · qwen3:4b'), findsOneWidget);
    expect(calls, [
      'GET /api/ai-coach/messages',
      'POST /api/ai-coach/messages',
    ]);
  });

  testWidgets(
    'failed send is never retried until history is explicitly reloaded',
    (tester) async {
      var posts = 0;
      Future<Map<String, dynamic>?> request(
        String method,
        String path,
        Map<String, dynamic>? body,
      ) async {
        if (method == 'GET') return {'messages': <Object>[]};
        posts++;
        throw Exception('network response lost');
      }

      await tester.pumpWidget(MaterialApp(home: AiCoachPage(request: request)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '질문');
      await tester.tap(find.text('보내기'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(find.textContaining('저장 여부'), findsOneWidget);
      await tester.tap(find.byTooltip('대화 불러오기'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(posts, 1);
    },
  );

  testWidgets(
    'unreadable history does not enable sending into unknown history',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AiCoachPage(
            request: (method, path, body) async => {'messages': 'bad'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('대화를 불러오지 못했어요'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );
}
