import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/relative.dart';
import 'family_validation.dart';

class BackupPreview {
  final List<Relative> relatives;
  final Map<String, Uint8List> photos;
  final DateTime created;
  const BackupPreview(this.relatives, this.photos, this.created);
}

class BackupService {
  static const maxBytes = 100 * 1024 * 1024;
  Future<File> export(List<Relative> relatives, {bool safety = false}) async {
    final photos = <String, String>{};
    for (final r in relatives) {
      if (r.photoPath != null) {
        final photo = File(r.photoPath!);
        if (!await photo.exists()) {
          throw FileSystemException(
            'Photo missing for ${r.visibleName}. Remove or replace it before backing up.',
          );
        }
        photos[r.id] = base64Encode(await photo.readAsBytes());
      }
    }
    final content = jsonEncode({
      'format': 'usrohdex',
      'version': 1,
      'created': DateTime.now().toUtc().toIso8601String(),
      'relatives': relatives
          .map((r) => r.copyWith(photoPath: null).toMap())
          .toList(),
      'photos': photos,
    });
    if (utf8.encode(content).length > maxBytes) {
      throw const FormatException(
        'This backup exceeds the 100 MB limit. Use smaller photos.',
      );
    }
    final root = safety
        ? await getApplicationDocumentsDirectory()
        : await getTemporaryDirectory();
    final dir = Directory('${root.path}/backups');
    await dir.create(recursive: true);
    return File(
      '${dir.path}/${safety ? 'safety' : 'usrohdex'}-${DateTime.now().microsecondsSinceEpoch}.usrohdex',
    ).writeAsString(content, flush: true);
  }

  BackupPreview decode(List<int> bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('Backup exceeds 100 MB.');
    }
    try {
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (data['format'] != 'usrohdex' || data['version'] != 1) {
        throw const FormatException('Unsupported backup format or version.');
      }
      final people = (data['relatives'] as List).map((item) {
        final map = Map<String, Object?>.from(item as Map);
        if (map['isDiscovered'] != 0 && map['isDiscovered'] != 1) {
          throw const FormatException('Invalid discovery status.');
        }
        return Relative.fromMap(map).copyWith(photoPath: null);
      }).toList();
      validateFamily(people);
      final ids = people.map((r) => r.id).toSet();
      final photos = <String, Uint8List>{};
      for (final e in (data['photos'] as Map<String, dynamic>).entries) {
        if (!ids.contains(e.key)) {
          throw const FormatException('Photo has no matching relative.');
        }
        final photo = base64Decode(e.value as String);
        if (photo.isEmpty) {
          throw const FormatException('Empty photo in backup.');
        }
        photos[e.key] = photo;
      }
      return BackupPreview(
        people,
        photos,
        DateTime.parse(data['created'] as String),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('This file is not a valid UsrohDex backup.');
    }
  }
}
