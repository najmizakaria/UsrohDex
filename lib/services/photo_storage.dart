import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class PhotoStorage {
  Future<Directory> get directory async => Directory(
    p.join((await getApplicationDocumentsDirectory()).path, 'usrohdex_photos'),
  )..createSync(recursive: true);
  Future<String> save(File source) async {
    final target = p.join(
      (await directory).path,
      '${const Uuid().v4()}${p.extension(source.path)}',
    );
    return (await source.copy(target)).path;
  }

  Future<String> saveBytes(List<int> bytes) async {
    final path = p.join((await directory).path, '${const Uuid().v4()}.jpg');
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<void> remove(String? path) async {
    if (path == null) return;
    // Never delete files outside the app's own photo directory.
    try {
      if (!p.isWithin((await directory).path, path)) return;
      final f = File(path);
      if (await f.exists()) await f.delete();
    } on FileSystemException {
      /* Cleanup may be retried later. */
    }
  }
}
