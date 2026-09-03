/// Which side of the family this person belongs to.
enum FamilySide { direct, paternal, maternal }

extension FamilySideX on FamilySide {
  String get label {
    switch (this) {
      case FamilySide.direct:
        return 'Direct';
      case FamilySide.paternal:
        return 'Paternal';
      case FamilySide.maternal:
        return 'Maternal';
    }
  }
}

/// One person in the tree.
class Relative {
  final String id;
  final String givenName;
  final bool isDiscovered;
  final DateTime? dateDiscovered;
  final String? photoPath;
  final String? phoneNumber;
  final DateTime? birthDate;
  final String? fatherId;
  final String? motherId;
  final FamilySide familySide;
  final int generation; // 0 = You, 1 = Parents, 2 = Grandparents, -1 = Children

  const Relative({
    required this.id,
    required this.givenName,
    required this.isDiscovered,
    required this.familySide,
    required this.generation,
    this.dateDiscovered,
    this.photoPath,
    this.phoneNumber,
    this.birthDate,
    this.fatherId,
    this.motherId,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'givenName': givenName,
      'isDiscovered': isDiscovered ? 1 : 0,
      'dateDiscovered': dateDiscovered?.millisecondsSinceEpoch,
      'photoPath': photoPath,
      'phoneNumber': phoneNumber,
      'birthDate': birthDate?.millisecondsSinceEpoch,
      'fatherId': fatherId,
      'motherId': motherId,
      'familySide': familySide.label,
      'generation': generation,
    };
  }

  factory Relative.fromMap(Map<String, Object?> map) {
    return Relative(
      id: map['id'] as String,
      givenName: map['givenName'] as String,
      isDiscovered: (map['isDiscovered'] as int) == 1,
      dateDiscovered: map['dateDiscovered'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['dateDiscovered'] as int),
      photoPath: map['photoPath'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      birthDate: map['birthDate'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['birthDate'] as int),
      fatherId: map['fatherId'] as String?,
      motherId: map['motherId'] as String?,
      familySide: FamilySide.values.firstWhere((e) => e.label == map['familySide']),
      generation: map['generation'] as int,
    );
  }
}