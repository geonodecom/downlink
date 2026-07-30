import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:downlink/src/ui/widgets/youtube_format_dialog.dart';
import 'package:downlink/src/ytdlp/ytdlp_models.dart';

void main() {
  testWidgets('youtube format dialog renders selectable formats', (tester) async {
    final info = YtdlpVideoInfo.fromJson({
      'id': 'abc123',
      'title': 'Sample Video',
      'duration': 90,
      'formats': [
        {
          'format_id': '22',
          'ext': 'mp4',
          'width': 1280,
          'height': 720,
          'format_note': '720p',
          'filesize': 1048576,
          'vcodec': 'avc1',
          'acodec': 'mp4a',
          'format': '720p mp4',
        },
      ],
    });

    YoutubeFormatSelection? selection;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                selection = await showYoutubeFormatDialog(
                  context,
                  info: info,
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Choose YouTube format'), findsOneWidget);
    expect(find.text('Sample Video'), findsOneWidget);

    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();

    expect(selection, isNotNull);
    expect(selection!.formatId, '22');
    expect(selection!.fileName, endsWith('.mp4'));
  });
}
