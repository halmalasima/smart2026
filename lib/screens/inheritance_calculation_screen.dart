import 'package:flutter/material.dart';

import '../features/inheritance_vault/ui/inheritance_vault_screen.dart';

/// Inheritance Calculation Screen - حساب المواريث
class InheritanceCalculationScreen extends StatefulWidget {
  const InheritanceCalculationScreen({super.key});

  @override
  State<InheritanceCalculationScreen> createState() =>
      _InheritanceCalculationScreenState();
}

class _InheritanceCalculationScreenState
    extends State<InheritanceCalculationScreen> {
  @override
  Widget build(BuildContext context) {
    return const InheritanceVaultScreen();
  }
}

class _EstateItemRow {
  static const Map<String, String> categories = {
    'cash': 'نقود',
    'real_estate': 'عقار/أرض',
    'vehicle': 'مركبة',
    'jewelry': 'ذهب/مجوهرات',
    'business': 'مشروع/تجارة',
    'other': 'أخرى',
  };

  String category;
  final TextEditingController descriptionController;
  final TextEditingController valueController;

  _EstateItemRow({
    this.category = 'cash',
    TextEditingController? descriptionController,
    TextEditingController? valueController,
  })  : descriptionController = descriptionController ?? TextEditingController(),
        valueController = valueController ?? TextEditingController();

  void dispose() {
    descriptionController.dispose();
    valueController.dispose();
  }
}

class _DebtItemRow {
  final TextEditingController creditorController;
  final TextEditingController descriptionController;
  final TextEditingController amountController;

  _DebtItemRow({
    TextEditingController? creditorController,
    TextEditingController? descriptionController,
    TextEditingController? amountController,
  })  : creditorController = creditorController ?? TextEditingController(),
        descriptionController = descriptionController ?? TextEditingController(),
        amountController = amountController ?? TextEditingController();

  void dispose() {
    creditorController.dispose();
    descriptionController.dispose();
    amountController.dispose();
  }
}

class _BequestItemRow {
  final TextEditingController beneficiaryController;
  final TextEditingController descriptionController;
  final TextEditingController amountController;

  _BequestItemRow({
    TextEditingController? beneficiaryController,
    TextEditingController? descriptionController,
    TextEditingController? amountController,
  })  : beneficiaryController = beneficiaryController ?? TextEditingController(),
        descriptionController = descriptionController ?? TextEditingController(),
        amountController = amountController ?? TextEditingController();

  void dispose() {
    beneficiaryController.dispose();
    descriptionController.dispose();
    amountController.dispose();
  }
}
