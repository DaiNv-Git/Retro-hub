import 'package:ai_wallpaper_gallery/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses licensed catalog item into a wallpaper', () {
    final item = Wallpaper.fromJson({
      'id': 'demo-1',
      'title': 'Open Runner',
      'platform': 'Game Boy Advance',
      'downloadUrl': 'https://example.com/open-runner.gba',
      'thumbnail': 'https://example.com/open-runner.webp',
      'licenseName': 'CC0',
      'licenseUrl': 'https://example.com/license',
      'contentOwner': 'Example Studio',
      'downloadSizeBytes': 1048576,
      'distributionRightsConfirmed': true,
    }, 0);

    expect(item.id, 'demo-1');
    expect(item.category, 'Game Boy Advance');
    expect(item.thumbUrl, 'https://example.com/open-runner.webp');
    expect(item.canDistribute, isTrue);
  });
}
