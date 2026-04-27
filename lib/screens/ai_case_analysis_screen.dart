import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AICaseAnalysisScreen extends StatefulWidget {
  const AICaseAnalysisScreen({super.key});

  @override
  State<AICaseAnalysisScreen> createState() => _AICaseAnalysisScreenState();
}

class _AICaseAnalysisScreenState extends State<AICaseAnalysisScreen> {
  final _factsController = TextEditingController();
  final _claimsController = TextEditingController();
  final _subjectController = TextEditingController();
  final _positionController = TextEditingController();
  
  bool _isLoading = false;
  String? _analysisResult;

  Future<void> _startAnalysis() async {
    if (_factsController.text.isEmpty || _claimsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال وقائع القضية وادعاءات الخصم')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _analysisResult = null;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.post('/api/ai/analyze-case/', {
        'subject': _subjectController.text,
        'facts': _factsController.text,
        'opponent_claims': _claimsController.text,
        'client_position': _positionController.text,
      });

      if (response['analysis'] != null) {
        setState(() {
          _analysisResult = response['analysis'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في التحليل: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('المحلل الاستراتيجي الذكي', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_analysisResult != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() => _analysisResult = null),
            ),
        ],
      ),
      body: _analysisResult == null ? _buildInputForm() : _buildResultView(),
      bottomNavigationBar: _analysisResult == null ? Padding(
        padding: const EdgeInsets.all(20.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _isLoading ? null : _startAnalysis,
          child: _isLoading 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('ابدأ التحليل الاستراتيجي الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ) : null,
    );
  }

  Widget _buildInputForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBanner(),
          const SizedBox(height: 24),
          _buildTextField('موضوع القضية (اختياري)', _subjectController, 'مثلاً: نزاع عقاري على أرض زراعية', 1),
          const SizedBox(height: 16),
          _buildTextField('وقائع القضية (Facts)', _factsController, 'اشرح تفاصيل ما حدث بالتفصيل...', 5),
          const SizedBox(height: 16),
          _buildTextField('ادعاءات الخصم (Opponent Claims)', _claimsController, 'ماذا يدعي الطرف الآخر؟ ما هي حججه؟', 5),
          const SizedBox(height: 16),
          _buildTextField('موقف الموكل وردودنا الأولية', _positionController, 'ما هي الأدلة التي نملكها؟ وجهة نظرنا؟', 4),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.amber),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'كلما كانت الوقائع والادعاءات مفصلة، زادت دقة التحليل الاستراتيجي واقتراحات الرد القانوني.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, int lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: lines,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            filled: true,
            fillColor: context.isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('نتائج التحليل الاستراتيجي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.brand.withOpacity(0.2)),
            ),
            child: SelectableText(
              _analysisResult!,
              style: const TextStyle(height: 1.6, fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('نسخ التحليل'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('تصدير للملف'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
