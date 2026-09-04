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

class Relative {
  final String id;
  final String givenName;
  final String? nickname;
  final bool isDiscovered;
  final DateTime? dateDiscovered;
  final String? photoPath;
  final String? phoneNumber;
  final DateTime? birthDate;
  final String? fatherId;
  final String? motherId;
  final FamilySide familySide;
  final int generation;

  const Relative({
    required this.id,
    required this.givenName,
    required this.isDiscovered,
    required this.familySide,
    required this.generation,
    this.nickname,
    this.dateDiscovered,
    this.photoPath,
    this.phoneNumber,
    this.birthDate,
    this.fatherId,
    this.motherId,
  });

  /// What to show on the tree canvas: nickname if set, otherwise the given name.
  String get displayName =>
      (nickname != null && nickname!.trim().isNotEmpty) ? nickname!.trim() : givenName;

  Relative copyWith({
    String? givenName,
    String? nickname,
    bool? isDiscovered,
    DateTime? dateDiscovered,
    String? photoPath,
    String? phoneNumber,
    DateTime? birthDate,
    String? fatherId,
    String? motherId,
    bool clearFatherId = false,
    bool clearMotherId = false,
    bool clearNickname = false,
  }) {
    return Relative(
      id: id,
      givenName: givenName ?? this.givenName,
      nickname: clearNickname ? null : (nickname ?? this.nickname),
      isDiscovered: isDiscovered ?? this.isDiscovered,
      dateDiscovered: dateDiscovered ?? this.dateDiscovered,
      photoPath: photoPath ?? this.photoPath,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      birthDate: birthDate ?? this.birthDate,
      fatherId: clearFatherId ? null : (fatherId ?? this.fatherId),
      motherId: clearMotherId ? null : (motherId ?? this.motherId),
      familySide: familySide,
      generation: generation,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'givenName': givenName,
      'nickname': nickname,
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
      nickname: map['nickname'] as String?,
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