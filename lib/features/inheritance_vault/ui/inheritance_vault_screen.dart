import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/inheritance_provider.dart';
import '../../data/inheritance_repository.dart';
import '../../db/inheritance_db.dart';

class InheritanceVaultScreen extends StatefulWidget {
  const InheritanceVaultScreen({super.key});

  @override
  State<InheritanceVaultScreen> createState() => _InheritanceVaultScreenState();
}

class _InheritanceVaultScreenState extends State<InheritanceVaultScreen> {
  late final InheritanceDatabase _db;
  late final InheritanceRepository _repo;

  @override
  void initState() {
    super.initState();
    _db = InheritanceDatabase();
    _repo = InheritanceRepository(_db);
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }

  Future<void> _createCase() async {
    final titleController = TextEditingController();
    bool deceasedIsMale = true;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('ملف مواريث جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'عنوان الملف (مثال: تركة/ورثة فلان)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: deceasedIsMale,
                onChanged: (v) => setLocal(() => deceasedIsMale = v),
                title: const Text('المتوفى ذكر'),
                subtitle: const Text('إذا كانت المتوفاة أنثى أوقف الخيار'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                await _repo.createCase(title: title, deceasedIsMale: deceasedIsMale);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء ملف المواريث')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Provider<InheritanceRepository>.value(
      value: _repo,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مستودع المواريث'),
          actions: [
            IconButton(
              tooltip: 'ملف جديد',
              onPressed: _createCase,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: StreamBuilder<List<InheritanceCase>>(
          stream: _repo.watchCases(),
          builder: (ctx, snap) {
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('ابدأ بإنشاء ملف مواريث لحصر التركة والورثة', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _createCase,
                        icon: const Icon(Icons.add),
                        label: const Text('إنشاء ملف جديد'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final c = items[i];
                return Card(
                  child: ListTile(
                    title: Text(c.title),
                    subtitle: Text('آخر تحديث: ${c.updatedAt.toLocal()}'),
                    leading: const Icon(Icons.folder_open),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'delete') {
                          await _repo.deleteCase(c.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم حذف الملف')),
                          );
                        }
                        if (v == 'calculate') {
                          // Keep the current remote calculation flow for now to avoid breaking.
                          // The advanced local engine will be introduced next.
                          final provider = context.read<InheritanceProvider>();
                          provider.clear();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('سيتم إضافة حساب متقدم محلياً في الخطوة القادمة')), 
                          );
                        }
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(value: 'calculate', child: Text('احسب (قريباً محلياً)')),
                        PopupMenuItem(value: 'delete', child: Text('حذف')),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => InheritanceCaseDetailsScreen(caseId: c.id, title: c.title),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class InheritanceCaseDetailsScreen extends StatefulWidget {
  final int caseId;
  final String title;
  const InheritanceCaseDetailsScreen({super.key, required this.caseId, required this.title});

  @override
  State<InheritanceCaseDetailsScreen> createState() => _InheritanceCaseDetailsScreenState();
}

class _InheritanceCaseDetailsScreenState extends State<InheritanceCaseDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<InheritanceRepository>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'التركة'),
            Tab(text: 'الديون'),
            Tab(text: 'الوصايا'),
            Tab(text: 'الورثة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _SimpleItemsTab(
            stream: repo.watchEstateItems(widget.caseId),
            emptyText: 'لا توجد عناصر تركة',
            onAdd: () => _addEstateItem(context, repo),
            onDelete: (id) => repo.deleteEstateItem(id),
            titleFor: (row) => '${row.category} - ${row.value.toStringAsFixed(2)}',
            subtitleFor: (row) => row.description,
            idOf: (row) => row.id,
          ),
          _SimpleItemsTab(
            stream: repo.watchDebtItems(widget.caseId),
            emptyText: 'لا توجد ديون',
            onAdd: () => _addDebtItem(context, repo),
            onDelete: (id) => repo.deleteDebtItem(id),
            titleFor: (row) => '${row.creditor} - ${row.amount.toStringAsFixed(2)}',
            subtitleFor: (row) => row.description,
            idOf: (row) => row.id,
          ),
          _SimpleItemsTab(
            stream: repo.watchBequestItems(widget.caseId),
            emptyText: 'لا توجد وصايا',
            onAdd: () => _addBequestItem(context, repo),
            onDelete: (id) => repo.deleteBequestItem(id),
            titleFor: (row) => '${row.beneficiary} - ${row.amount.toStringAsFixed(2)}',
            subtitleFor: (row) => row.description,
            idOf: (row) => row.id,
          ),
          _SimpleItemsTab(
            stream: repo.watchHeirs(widget.caseId),
            emptyText: 'لا يوجد ورثة',
            onAdd: () => _addHeir(context, repo),
            onDelete: (id) => repo.deleteHeir(id),
            titleFor: (row) => '${row.type} × ${row.count}',
            subtitleFor: (_) => '',
            idOf: (row) => row.id,
          ),
        ],
      ),
    );
  }

  Future<void> _addEstateItem(BuildContext context, InheritanceRepository repo) async {
    final cat = TextEditingController(text: 'real_estate');
    final desc = TextEditingController();
    final value = TextEditingController();

    final ok = await _showAddDialog(context, title: 'إضافة عنصر تركة', fields: [
      _DialogField(label: 'التصنيف', controller: cat),
      _DialogField(label: 'الوصف', controller: desc),
      _DialogField(label: 'القيمة', controller: value, keyboard: TextInputType.number),
    ]);

    if (ok == true) {
      final v = double.tryParse(value.text.trim().replaceAll(',', '')) ?? 0;
      await repo.addEstateItem(
        caseId: widget.caseId,
        category: cat.text.trim(),
        description: desc.text.trim(),
        value: v,
      );
    }

    cat.dispose();
    desc.dispose();
    value.dispose();
  }

  Future<void> _addDebtItem(BuildContext context, InheritanceRepository repo) async {
    final creditor = TextEditingController();
    final desc = TextEditingController();
    final amount = TextEditingController();

    final ok = await _showAddDialog(context, title: 'إضافة دين', fields: [
      _DialogField(label: 'الدائن', controller: creditor),
      _DialogField(label: 'الوصف', controller: desc),
      _DialogField(label: 'المبلغ', controller: amount, keyboard: TextInputType.number),
    ]);

    if (ok == true) {
      final v = double.tryParse(amount.text.trim().replaceAll(',', '')) ?? 0;
      await repo.addDebtItem(
        caseId: widget.caseId,
        creditor: creditor.text.trim(),
        description: desc.text.trim(),
        amount: v,
      );
    }

    creditor.dispose();
    desc.dispose();
    amount.dispose();
  }

  Future<void> _addBequestItem(BuildContext context, InheritanceRepository repo) async {
    final beneficiary = TextEditingController();
    final desc = TextEditingController();
    final amount = TextEditingController();

    final ok = await _showAddDialog(context, title: 'إضافة وصية', fields: [
      _DialogField(label: 'الموصى له', controller: beneficiary),
      _DialogField(label: 'الوصف', controller: desc),
      _DialogField(label: 'المبلغ', controller: amount, keyboard: TextInputType.number),
    ]);

    if (ok == true) {
      final v = double.tryParse(amount.text.trim().replaceAll(',', '')) ?? 0;
      await repo.addBequestItem(
        caseId: widget.caseId,
        beneficiary: beneficiary.text.trim(),
        description: desc.text.trim(),
        amount: v,
      );
    }

    beneficiary.dispose();
    desc.dispose();
    amount.dispose();
  }

  Future<void> _addHeir(BuildContext context, InheritanceRepository repo) async {
    final type = TextEditingController(text: 'wife');
    final count = TextEditingController(text: '1');

    final ok = await _showAddDialog(context, title: 'إضافة وارث', fields: [
      _DialogField(label: 'النوع (مثال: father/mother/wife/son)', controller: type),
      _DialogField(label: 'العدد', controller: count, keyboard: TextInputType.number),
    ]);

    if (ok == true) {
      final c = int.tryParse(count.text.trim()) ?? 1;
      await repo.addHeir(caseId: widget.caseId, type: type.text.trim(), count: c <= 0 ? 1 : c);
    }

    type.dispose();
    count.dispose();
  }

  Future<bool?> _showAddDialog(
    BuildContext context, {
    required String title,
    required List<_DialogField> fields,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in fields) ...[
                TextField(
                  controller: f.controller,
                  keyboardType: f.keyboard,
                  decoration: InputDecoration(
                    labelText: f.label,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
  }
}

class _DialogField {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboard;
  _DialogField({required this.label, required this.controller, this.keyboard});
}

class _SimpleItemsTab<T> extends StatelessWidget {
  final Stream<List<T>> stream;
  final String emptyText;
  final VoidCallback onAdd;
  final Future<void> Function(int id) onDelete;

  final String Function(T row) titleFor;
  final String Function(T row) subtitleFor;
  final int Function(T row) idOf;

  const _SimpleItemsTab({
    required this.stream,
    required this.emptyText,
    required this.onAdd,
    required this.onDelete,
    required this.titleFor,
    required this.subtitleFor,
    required this.idOf,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (ctx, snap) {
        final items = snap.data ?? const [];
        return Column(
          children: [
            Expanded(
              child: items.isEmpty
                  ? Center(child: Text(emptyText))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        final row = items[i];
                        final sub = subtitleFor(row);
                        return Card(
                          child: ListTile(
                            title: Text(titleFor(row)),
                            subtitle: sub.isEmpty ? null : Text(sub),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => onDelete(idOf(row)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
