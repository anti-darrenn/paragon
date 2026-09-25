import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/learn/youtube_id.dart';

void main() {
  const id = 'M7lc1UVf-VE';

  test('accepts every link form an author is likely to paste', () {
    for (final input in [
      id,
      '  $id  ',
      'https://www.youtube.com/watch?v=$id',
      'https://youtube.com/watch?v=$id&t=42s',
      'https://m.youtube.com/watch?v=$id',
      'youtube.com/watch?v=$id',
      'https://youtu.be/$id',
      'https://youtu.be/$id?si=abc123',
      'https://www.youtube.com/embed/$id',
      'https://www.youtube-nocookie.com/embed/$id',
      'https://www.youtube.com/shorts/$id',
      'https://www.youtube.com/live/$id',
    ]) {
      expect(parseYouTubeId(input), id, reason: input);
    }
  });

  test('control: rejects links that name no video', () {
    for (final input in [
      '',
      'hello',
      'M7lc1UVf-V', // 10 characters
      'M7lc1UVf-VEX', // 12 characters
      'https://www.youtube.com/@channel',
      'https://www.youtube.com/playlist?list=PL123',
      'https://www.youtube.com/watch?v=short',
      'https://vimeo.com/$id',
      'https://evil.example/embed/$id',
      'https://youtube.com.evil.example/watch?v=$id',
    ]) {
      expect(parseYouTubeId(input), isNull, reason: input);
    }
  });
}
