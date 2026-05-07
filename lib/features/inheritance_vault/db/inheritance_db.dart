import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'inheritance_db.g.dart';

class InheritanceCases extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get deceasedIsMale => boolean().withDefault(const Constant(true))();

  TextColumn get notes => text().nullable()();
}

class EstateItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get caseId => integer().references(InheritanceCases, #id)();

  TextColumn get category => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  RealColumn get value => real().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class DebtItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get caseId => integer().references(InheritanceCases, #id)();

  TextColumn get creditor => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  RealColumn get amount => real().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class BequestItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get caseId => integer().references(InheritanceCases, #id)();

  TextColumn get beneficiary => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  RealColumn get amount => real().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Heirs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get caseId => integer().references(InheritanceCases, #id)();

  TextColumn get type => text()();
  IntColumn get count => integer().withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get caseId => integer().references(InheritanceCases, #id)();

  TextColumn get targetTable => text()();
  IntColumn get targetId => integer()();

  TextColumn get localPath => text()();
  TextColumn get originalName => text().nullable()();
  TextColumn get mimeType => text().nullable()();
  IntColumn get sizeBytes => integer().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(
  tables: [InheritanceCases, EstateItems, DebtItems, BequestItems, Heirs, Attachments],
)
class InheritanceDatabase extends _$InheritanceDatabase {
  InheritanceDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

DatabaseConnection _openConnection() {
  return driftDatabase(
    name: 'inheritance_vault.sqlite',
    native: const DriftNativeOptions(
      databaseDirectory: DriftNativeDatabaseDirectory.documents,
    ),
  );
}

extension InheritanceDbUtils on InheritanceDatabase {
  Future<void> vacuum() async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
      return;
    }
    await customStatement('VACUUM');
  }
}
