import 'package:flutter_test/flutter_test.dart';
import 'package:swara/services/metadata_service.dart';

// Unit tests for the pure filename parser in MetadataService.
// parseFromFilename does not touch platform channels, so it is safe to test
// on any host without mocking sqflite, path_provider, or http.
void main() {
  group('MetadataService.instance.parseFromFilename', () {
    test('parses Artist - Title pattern with mp3 extension', () {
      final result =
          MetadataService.instance.parseFromFilename('Artist - Title.mp3');
      expect(result['artist'], 'Artist');
      expect(result['title'], 'Title');
    });

    test('ignores parent folders and parses only the file name', () {
      final result = MetadataService.instance
          .parseFromFilename('/storage/music/Artist - Title.mp3');
      expect(result['artist'], 'Artist');
      expect(result['title'], 'Title');
    });

    test('drops a leading track number with dash separator', () {
      final result = MetadataService.instance
          .parseFromFilename('/music/01 - Artist - Title.mp3');
      expect(result['artist'], 'Artist');
      expect(result['title'], 'Title');
    });

    test('drops a leading track number with dot separator', () {
      final result =
          MetadataService.instance.parseFromFilename('03. My Song.mp3');
      expect(result['artist'], '');
      expect(result['title'], 'My Song');
    });

    test('converts underscores to spaces', () {
      final result =
          MetadataService.instance.parseFromFilename('My_Song_Title.mp3');
      expect(result['artist'], '');
      expect(result['title'], 'My Song Title');
    });

    test('parses underscore joined Artist - Title pattern', () {
      // Underscores become spaces first, so Artist_-_Title becomes Artist - Title.
      final result =
          MetadataService.instance.parseFromFilename('Artist_-_Title.mp3');
      expect(result['artist'], 'Artist');
      expect(result['title'], 'Title');
    });

    test('returns empty artist when there is no Artist - Title pattern', () {
      final result =
          MetadataService.instance.parseFromFilename('JustATitle.mp3');
      expect(result['artist'], '');
      expect(result['title'], 'JustATitle');
    });

    test('strips uppercase MP3 extension', () {
      final result =
          MetadataService.instance.parseFromFilename('Artist - Title.MP3');
      expect(result['artist'], 'Artist');
      expect(result['title'], 'Title');
    });

    test('keeps opus suffix because only mp3 flac wav m4a ogg are stripped', () {
      // This documents current behavior: the extension regex does not
      // include opus, so the suffix stays attached to the title.
      final result = MetadataService.instance
          .parseFromFilename('/music/Artist - Title.opus');
      expect(result['artist'], 'Artist');
      expect(result['title'], 'Title.opus');
    });
  });
}
