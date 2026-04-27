import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class LegalDraftingScreen extends StatefulWidget {
  final String? initialTemplate;
  const LegalDraftingScreen({super.key, this.initialTemplate});

  @override
  State<LegalDraftingScreen> createState() => _LegalDraftingScreenState();
}

class _LegalDraftingScreenState extends State<LegalDraftingScreen> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  
  String _selectedTemplate = 'دعوى مدنية عامة';
  
  final Map<String, String> _templates = {
    'دعوى مدنية عامة': 'باسم الشعب:\nإلى محكمة [اسم_المحكمة] الموقرة\n\nالمدعي: [اسم_المدعي]\nالمدعى عليه: [اسم_المدعى_عليه]\n\nالموضوع: [موضوع_الدعوى]\n\nالوقائع:\nنورد لعدالتكم الوقائع التالية...\n\nالطلبات:\nبناءً على ما تقدم نطلب من عدالة المحكمة الموقرة:\n1- ....\n2- ....\n\nوتقبلوا خالص التحية،\nمقدمه: [اسم_المحامى]',
    'عريضة طعن بالاستئناف': 'إلى محكمة استئناف محافظة [المحافظة]\nالشعبة [نوع_الشعبة]\n\nالطاعن: [اسم_الطاعن]\nالمطعون ضده: [اسم_المطعون_ضده]\n\nالموضوع: طعن بالاستئناف في الحكم الصادر من محكمة [المحكمة_الابتدائية] رقم [رقم_الحكم] وتاريخ [تاريخ_الحكم]\n\nأسباب الطعن:\nأولاً: ....\nثانياً: ....\n\nالطلبات:\n1- قبول الطعن شكلاً.\n2- وفي الموضوع: إلغاء الحكم المطعون فيه والحكم بـ ....\n\nوالله ولي التوفيق،',
    'طلب أمر أداء': 'إلى السيد الأستاذ/ رئيس محكمة [المحكمة] الموقر\nبصفته قاضياً للأمور المستعجلة\n\nمقدمه لسيادتكم: [اسم_الدائن]\nضد: [اسم_المدين]\n\nالموضوع: طلب استصدار أمر أداء بمبلغ [المبلغ] ريال يمني.\n\nالوقائع:\nحيث أن الطالب يداين المطلوب ضده بمبلغ وقدره [المبلغ] بموجب سند [نوع_السند]...\n\nلذلك:\nنلتمس إصدار أمركم الكريم بإلزام المطلوب ضده بدفع المبلغ المذكور.\n\nوتفضلوا بقبول التقدير،',
  };

  @override
  void initState() {
    super.initState();
    _selectedTemplate = widget.initialTemplate ?? _templates.keys.first;
    _contentController.text = _templates[_selectedTemplate]!;
    _titleController.text = 'مسودة $_selectedTemplate';
  }

  void _updateTemplate(String templateName) {
    setState(() {
      _selectedTemplate = templateName;
      _contentController.text = _templates[templateName]!;
      _titleController.text = 'مسودة $templateName';
    });
  }

  Future<void> _shareDocument() async {
    if (_contentController.text.isEmpty) return;
    await Share.share(_contentController.text, subject: _titleController.text);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('المحرر القانوني الذكي'),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareDocument,
            tooltip: 'مشاركة المسودة',
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جاري تجهيز المستند للطباعة...')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Toolbar for Template Selection
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('اختر قالب المستند:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    children: _templates.keys.map((name) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(name, style: const TextStyle(fontSize: 12)),
                        selected: _selectedTemplate == name,
                        onSelected: (val) => val ? _updateTemplate(name) : null,
                        selectedColor: AppColors.brand.withOpacity(0.2),
                        checkmarkColor: AppColors.brand,
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          // Editor Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _titleController,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.brand),
              decoration: const InputDecoration(
                hintText: 'عنوان المستند',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.edit_note, color: AppColors.brand),
              ),
            ),
          ),
          
          // Main Editor
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
                ],
                border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
              ),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 16, height: 1.8, fontFamily: 'Cairo'),
                decoration: const InputDecoration(
                  hintText: 'ابدأ كتابة النص القانوني هنا...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          
          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? AppColors.darkSurface : Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم حفظ المسودة بنجاح')),
                      );
                    },
                    icon: const Icon(Icons.save_rounded, color: Colors.white),
                    label: const Text('حفظ المسودة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.brand.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.auto_fix_high, color: AppColors.brand),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('الذكاء الاصطناعي يقوم بمراجعة الصياغة...')),
                      );
                    },
                    tooltip: 'تحسين الصياغة بالذكاء الاصطناعي',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
