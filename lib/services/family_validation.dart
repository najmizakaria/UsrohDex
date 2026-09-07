import '../models/relative.dart';

/// Shared by editing and restore: never trust UI-only relationship constraints.
void validateFamily(List<Relative> people) {
  final byId = {for (final r in people) r.id: r};
  if (byId.length != people.length) {
    throw const FormatException('Duplicate person IDs.');
  }
  for (final r in people) {
    if (r.birthDate != null &&
        (r.birthDate!.year < 1000 || r.birthDate!.isAfter(DateTime.now()))) {
      throw const FormatException(
        'Birthdays must be in the past and after year 999.',
      );
    }
    if (r.id.isEmpty || r.givenName.trim().isEmpty) {
      throw const FormatException('Every relative needs a name and ID.');
    }
    if (r.generation < -50 || r.generation > 50) {
      throw const FormatException('Generations must be between -50 and 50.');
    }
    if (r.fatherId != null && r.fatherId == r.motherId) {
      throw const FormatException(
        'Father and mother must be different people.',
      );
    }
    for (final id in [r.fatherId, r.motherId].whereType<String>()) {
      final parent = byId[id];
      if (parent == null) {
        throw const FormatException('A selected parent no longer exists.');
      }
      if (id == r.id) {
        throw const FormatException('A person cannot be their own parent.');
      }
      if (parent.generation <= r.generation) {
        throw const FormatException(
          'Parents must be in an older generation than their children.',
        );
      }
    }
    if (r.partnerIds.toSet().length != r.partnerIds.length) {
      throw const FormatException('Duplicate partner relationships.');
    }
    for (final id in r.partnerIds) {
      if (id == r.id || !byId.containsKey(id)) {
        throw const FormatException(
          'Choose an existing, different person as partner.',
        );
      }
      if (!byId[id]!.partnerIds.contains(r.id)) {
        throw const FormatException('Partner relationships must be mutual.');
      }
    }
  }
  final visiting = <String>{}, visited = <String>{};
  void visit(String id) {
    if (visiting.contains(id)) {
      throw const FormatException(
        'This relationship creates an ancestry cycle.',
      );
    }
    if (!visited.add(id)) return;
    visiting.add(id);
    final r = byId[id]!;
    for (final parent in [r.fatherId, r.motherId].whereType<String>()) {
      visit(parent);
    }
    visiting.remove(id);
  }

  for (final id in byId.keys) {
    visit(id);
  }
}
