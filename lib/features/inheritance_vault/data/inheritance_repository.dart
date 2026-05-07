import 'package:drift/drift.dart';

import '../db/inheritance_db.dart';

class InheritanceRepository {
  final InheritanceDatabase db;
  InheritanceRepository(this.db);

  Stream<List<InheritanceCase>> watchCases() {
    return (db.select(db.inheritanceCases)
          ..orderBy([
            (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<int> createCase({required String title, required bool deceasedIsMale}) {
    return db.into(db.inheritanceCases).insert(
          InheritanceCasesCompanion.insert(
            title: title,
            deceasedIsMale: Value(deceasedIsMale),
          ),
        );
  }

  Future<void> renameCase(int id, String title) {
    return (db.update(db.inheritanceCases)..where((t) => t.id.equals(id))).write(
      InheritanceCasesCompanion(
        title: Value(title),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteCase(int id) async {
    await (db.delete(db.attachments)..where((t) => t.caseId.equals(id))).go();
    await (db.delete(db.estateItems)..where((t) => t.caseId.equals(id))).go();
    await (db.delete(db.debtItems)..where((t) => t.caseId.equals(id))).go();
    await (db.delete(db.bequestItems)..where((t) => t.caseId.equals(id))).go();
    await (db.delete(db.heirs)..where((t) => t.caseId.equals(id))).go();
    await (db.delete(db.inheritanceCases)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<EstateItem>> watchEstateItems(int caseId) {
    return (db.select(db.estateItems)
          ..where((t) => t.caseId.equals(caseId))
          ..orderBy([(t) => OrderingTerm(expression: t.id)]))
        .watch();
  }

  Future<int> addEstateItem({
    required int caseId,
    required String category,
    required String description,
    required double value,
  }) {
    return db.into(db.estateItems).insert(
          EstateItemsCompanion.insert(
            caseId: caseId,
            category: category,
            description: Value(description),
            value: Value(value),
          ),
        );
  }

  Future<void> deleteEstateItem(int id) {
    return (db.delete(db.estateItems)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<DebtItem>> watchDebtItems(int caseId) {
    return (db.select(db.debtItems)
          ..where((t) => t.caseId.equals(caseId))
          ..orderBy([(t) => OrderingTerm(expression: t.id)]))
        .watch();
  }

  Future<int> addDebtItem({
    required int caseId,
    required String creditor,
    required String description,
    required double amount,
  }) {
    return db.into(db.debtItems).insert(
          DebtItemsCompanion.insert(
            caseId: caseId,
            creditor: Value(creditor),
            description: Value(description),
            amount: Value(amount),
          ),
        );
  }

  Future<void> deleteDebtItem(int id) {
    return (db.delete(db.debtItems)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<BequestItem>> watchBequestItems(int caseId) {
    return (db.select(db.bequestItems)
          ..where((t) => t.caseId.equals(caseId))
          ..orderBy([(t) => OrderingTerm(expression: t.id)]))
        .watch();
  }

  Future<int> addBequestItem({
    required int caseId,
    required String beneficiary,
    required String description,
    required double amount,
  }) {
    return db.into(db.bequestItems).insert(
          BequestItemsCompanion.insert(
            caseId: caseId,
            beneficiary: Value(beneficiary),
            description: Value(description),
            amount: Value(amount),
          ),
        );
  }

  Future<void> deleteBequestItem(int id) {
    return (db.delete(db.bequestItems)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<Heir>> watchHeirs(int caseId) {
    return (db.select(db.heirs)
          ..where((t) => t.caseId.equals(caseId))
          ..orderBy([(t) => OrderingTerm(expression: t.id)]))
        .watch();
  }

  Future<int> addHeir({required int caseId, required String type, required int count}) {
    return db.into(db.heirs).insert(
          HeirsCompanion.insert(
            caseId: caseId,
            type: type,
            count: Value(count),
          ),
        );
  }

  Future<void> deleteHeir(int id) {
    return (db.delete(db.heirs)..where((t) => t.id.equals(id))).go();
  }
}
