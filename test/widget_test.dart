import 'package:ai_wallpaper_gallery/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses remote feed item into a wallpaper', () {
    final item = Wallpaper.fromJson({
      'id': 33101,
      'title': 'Pokemon Crimson Red',
      'region': 'USA',
    }, 0);

    expect(item.id, '33101');
    expect(item.category, 'USA');
    expect(item.thumbUrl, 'https://engfordev.top/gbagame/thumbs/33101.webp');
  });
}
