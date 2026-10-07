import 'package:availchat/core/utils/geohash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes the reference point', () {
    expect(Geohash.encode(57.64911, 10.40744, precision: 11), 'u4pruydqqvj');
    expect(Geohash.encode(57.64911, 10.40744), 'u4pru');
  });

  test('decodes to the cell centre', () {
    final c = Geohash.decode('ezs42')!;
    expect(c.lat, closeTo(42.605, 0.03));
    expect(c.lng, closeTo(-5.603, 0.03));
    expect(Geohash.decode('ezs4a'), isNull);
  });

  test('precision 5 cells are about 4.9 km', () {
    final s = Geohash.cellSize(5);
    expect(s.lat * 111, closeTo(4.9, .1));
    expect(s.lng * 111, closeTo(4.9, .1));
  });

  test('neighbours of a known cell', () {
    expect(
      Geohash.withNeighbors('ezs42').toSet(),
      {
        'ezs42',
        'ezs48',
        'ezs40',
        'ezs43',
        'ezefr',
        'ezs49',
        'ezefx',
        'ezs41',
        'ezefp'
      },
    );
  });

  test('distance buckets never go below 5 km', () {
    final here = Geohash.decode('tdr1y')!;
    expect(Geohash.approxDistanceKm(here.lat, here.lng, 'tdr1y'), 5);
    expect(Geohash.approxDistanceKm(here.lat, here.lng, 'bad!'), -1);
    final far = Geohash.approxDistanceKm(here.lat, here.lng, 'tdr4p');
    expect(far % 5, 0);
    expect(far, greaterThan(5));
  });
}
