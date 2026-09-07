import 'dart:convert';

enum FamilySide { direct, paternal, maternal }

extension FamilySideX on FamilySide {
  String get label => switch (this) {
    FamilySide.direct => 'Direct',
    FamilySide.paternal => 'Paternal',
    FamilySide.maternal => 'Maternal',
  };
}

const _unset = Object();

class Relative {
  final String id, givenName;
  final String? nickname, photoPath, phoneNumber, fatherId, motherId, notes;
  final bool isDiscovered;
  final DateTime? dateDiscovered, birthDate;
  final FamilySide familySide;
  final int generation;
  final List<String> partnerIds;
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
    this.notes,
    this.partnerIds = const [],
  });
  String get displayName =>
      nickname?.trim().isNotEmpty == true ? nickname!.trim() : givenName;
  String get visibleName =>
      isDiscovered ? displayName : 'Undiscovered relative';
  Relative copyWith({
    String? givenName,
    Object? nickname = _unset,
    bool? isDiscovered,
    Object? dateDiscovered = _unset,
    Object? photoPath = _unset,
    Object? phoneNumber = _unset,
    Object? birthDate = _unset,
    Object? fatherId = _unset,
    Object? motherId = _unset,
    Object? notes = _unset,
    FamilySide? familySide,
    int? generation,
    List<String>? partnerIds,
    bool clearFatherId = false,
    bool clearMotherId = false,
    bool clearNickname = false,
  }) => Relative(
    id: id,
    givenName: givenName ?? this.givenName,
    nickname: clearNickname
        ? null
        : identical(nickname, _unset)
        ? this.nickname
        : nickname as String?,
    isDiscovered: isDiscovered ?? this.isDiscovered,
    dateDiscovered: identical(dateDiscovered, _unset)
        ? this.dateDiscovered
        : dateDiscovered as DateTime?,
    photoPath: identical(photoPath, _unset)
        ? this.photoPath
        : photoPath as String?,
    phoneNumber: identical(phoneNumber, _unset)
        ? this.phoneNumber
        : phoneNumber as String?,
    birthDate: identical(birthDate, _unset)
        ? this.birthDate
        : birthDate as DateTime?,
    fatherId: clearFatherId
        ? null
        : identical(fatherId, _unset)
        ? this.fatherId
        : fatherId as String?,
    motherId: clearMotherId
        ? null
        : identical(motherId, _unset)
        ? this.motherId
        : motherId as String?,
    notes: identical(notes, _unset) ? this.notes : notes as String?,
    familySide: familySide ?? this.familySide,
    generation: generation ?? this.generation,
    partnerIds: List.unmodifiable(partnerIds ?? this.partnerIds),
  );
  Map<String, Object?> toMap() => {
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
    'notes': notes,
    'partnerIds': jsonEncode(partnerIds),
  };
  factory Relative.fromMap(Map<String, Object?> m) => Relative(
    id: m['id'] as String,
    givenName: m['givenName'] as String,
    nickname: m['nickname'] as String?,
    isDiscovered: m['isDiscovered'] == 1,
    dateDiscovered: m['dateDiscovered'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m['dateDiscovered'] as int),
    photoPath: m['photoPath'] as String?,
    phoneNumber: m['phoneNumber'] as String?,
    birthDate: m['birthDate'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m['birthDate'] as int),
    fatherId: m['fatherId'] as String?,
    motherId: m['motherId'] as String?,
    familySide: FamilySide.values.firstWhere((s) => s.label == m['familySide']),
    generation: m['generation'] as int,
    notes: m['notes'] as String?,
    partnerIds: List<String>.unmodifiable(
      jsonDecode(m['partnerIds'] as String? ?? '[]') as List,
    ),
  );
}
