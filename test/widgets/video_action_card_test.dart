import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/video_action.dart';
import 'package:ai_rally_search/widgets/video_action_card.dart';

void main() {
  testWidgets('VideoActionCard renders action details and triggers callback', (tester) async {
    const action = VideoAction(
      id: 101,
      videoId: 501,
      streamId: 201,
      actionType: 'jump',
      title: 'Big Jump',
      startTime: 62.0,
      endTime: 68.0,
      duration: 6.0,
      stageName: 'Molina Stage',
      stageNumber: '4',
      eventName: 'Rally Sweden',
      videoUrl: 'https://example.com/video.m3u8',
    );

    VideoAction? playedAction;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoActionCard(
            action: action,
            onPlay: (act) {
              playedAction = act;
            },
          ),
        ),
      ),
    );

    expect(find.text('Big Jump'), findsOneWidget);
    expect(find.text('01:02 → 01:08'), findsOneWidget);
    expect(find.text('6.0s'), findsOneWidget);
    expect(find.text('Rally Sweden • SS4: Molina Stage'), findsOneWidget);

    await tester.tap(find.byType(VideoActionCard));
    await tester.pump();

    expect(playedAction, isNotNull);
    expect(playedAction!.id, 101);
    expect(playedAction!.title, 'Big Jump');
  });
}
