# UsrohDex

A private, on-device family tree and directory built with Flutter. Explore your family, save their stories, and reveal undiscovered relatives as your connections grow.

## Run

Use a Flutter SDK that includes Dart 3.13 or newer (see `pubspec.yaml`).

```sh
flutter pub get
flutter run
```

Android is the primary development target. iOS has camera and photo-library permission descriptions but must be built and tested on macOS. Generated desktop and web folders are not a claim of support: production persistence currently uses mobile SQLite and local files. SQLite FFI is a test-only dependency.

## Features

- Tree, Family, and Settings tabs preserve their state while switching.
- Warm Material 3 design with system, light, and dark themes.
- Search and filter the directory by family side and discovery status.
- Profiles include preferred/full names, birthdays, phone numbers, notes, photos, parents, partners, siblings, and children.
- Dedicated editor with searchable relationship selection, editable generations, optional-field removal, and duplicate-name prompts.
- Contextual creation of parents, children, siblings, and partners.
- Discovery hides identities throughout browsing; discovery can be reversed without deleting the record.
- Relationship-aware tree rows, solid parent links, dashed partner links, zoom, fit, search, and family focus.
- Complete export and replace-from-backup restoration, including photos and a pre-restore safety copy.

## Data and architecture

`Screens -> RelativesProvider -> DatabaseHelper / services`

- `lib/models/relative.dart`: immutable records and serialization. Partner IDs represent explicit, mutual relationships, including couples without children.
- `lib/providers/relatives_provider.dart`: shared family state, serialized mutations, recovery, and reciprocal relationship updates.
- `lib/data/database_helper.dart`: SQLite schema version 3; upgrades versions 1 and 2 without deleting existing data. Related changes commit in one transaction.
- `lib/services/family_validation.dart`: shared rules for editing and restoration. Rejects missing/self parents, duplicate parental roles, invalid generations, ancestry cycles, and invalid partner references.
- `lib/services/photo_storage.dart`: uniquely named app-owned images and cleanup.
- `lib/services/backup_service.dart`: versioned backup encoding, validation, and export.
- `lib/providers/app_preferences.dart`: local appearance, export date, and reminder preferences.
- `lib/utils/tree_layout.dart`: generation rows with sibling/partner grouping and parent alignment. Dense trees may still have crossing connectors.
- `lib/widgets/common.dart`: shared person avatars, pickers, feedback, and empty/loading/error states.

Generation 0 is the user's generation, positive values are older, and negative values are younger. The editor supports -50 through 50. Parents must have a larger generation than their children. Siblings are inferred from shared parents.

## Backups

An `.usrohdex` file contains UTF-8 JSON with a format marker, version, timestamp, relative records, and base64-encoded photos keyed by person ID. Device-specific photo paths are stripped. Maximum backup size is 100 MB. Files are not encrypted; users choose their own trusted storage destination.

Restore validates the file and shows its date, person count, and photo count before replacement. A safety backup of the current family is written in the app's documents directory first and is accessible from Settings. New photos are staged before the database transaction. Failed writes leave the current family intact and remove staged photos.

Export uses the native share sheet. The app asks whether the file was saved before updating the last confirmed export date, because a share-sheet result does not guarantee delivery. Backup reminders are in-app reminders in Settings, not background notifications.

Old database-only exports cannot be imported through this new format. Merge imports, cloud sync, shared editing, accounts, and genealogy exchange formats are outside this release.

## Verification

```sh
flutter analyze
flutter test
flutter build apk --debug
```

Tests cover legacy schema migration, real SQLite transaction rollback, complete photo backup/restore, failed restore cleanup, provider failure recovery, relationship rules, expanded generation layouts, privacy in the directory, navigation, and narrow-screen/large-text behavior.

Before a production release, verify camera/gallery cancellation and permissions, photo replacement, file selection, share destinations, backup restore, and accessibility on physical Android and iOS devices. Configure release signing; the existing Android release configuration still uses the debug key.