import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/responsive_helper.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../skulmate/models/skulmate_revision_plan.dart';
import '../../skulmate/services/skulmate_pricing_service.dart';

/// Admin controls for SkulMate revision packages and daily free limits.
class AdminSkulmatePricingScreen extends StatefulWidget {
  const AdminSkulmatePricingScreen({super.key});

  @override
  State<AdminSkulmatePricingScreen> createState() =>
      _AdminSkulmatePricingScreenState();
}

class _AdminSkulmatePricingScreenState extends State<AdminSkulmatePricingScreen> {
  final _docLimitController = TextEditingController();
  final _imageLimitController = TextEditingController();
  final List<_PlanEditor> _planEditors = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _docLimitController.dispose();
    _imageLimitController.dispose();
    for (final editor in _planEditors) {
      editor.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final limits = await SkulmatePricingService.fetchFreeLimits();
      final plans = await SkulmatePricingService.fetchRevisionPlans(
        forceRefresh: true,
      );
      _docLimitController.text = '${limits['doc'] ?? 4}';
      _imageLimitController.text = '${limits['image'] ?? 2}';
      _planEditors
        ..clear()
        ..addAll(plans.map(_PlanEditor.fromPlan));
      setState(() => _loading = false);
    } catch (e) {
      LogService.error('AdminSkulmatePricing load failed: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final doc = int.tryParse(_docLimitController.text.trim()) ?? 4;
      final image = int.tryParse(_imageLimitController.text.trim()) ?? 2;
      await SkulmatePricingService.saveFreeLimits(
        docPerDay: doc,
        imagePerDay: image,
      );
      final packages = _planEditors.map((e) => e.toJson()).toList();
      await SkulmatePricingService.saveRevisionPackages(packages);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SkulMate pricing updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: PhosphorIcon(PhosphorIcons.arrowLeft(), color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SkulMate pricing',
          style: GoogleFonts.poppins(
            fontSize: ResponsiveHelper.responsiveHeadingSize(context),
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(
                ResponsiveHelper.responsiveHorizontalPadding(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Free daily limits',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(
                          controller: _docLimitController,
                          label: 'Documents & text / day',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _numberField(
                          controller: _imageLimitController,
                          label: 'Images / day',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Revision credit packages',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set sale price and original (strikethrough) price. Mark one plan as Popular.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textMedium,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._planEditors.map(_planCard),
                ],
              ),
            ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _planCard(_PlanEditor editor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            editor.titleController.text.isEmpty
                ? 'Package'
                : editor.titleController.text,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _field(editor.titleController, 'Title'),
          _field(editor.subtitleController, 'Subtitle'),
          Row(
            children: [
              Expanded(child: _field(editor.creditsController, 'Credits')),
              const SizedBox(width: 8),
              Expanded(
                child: _field(editor.salePriceController, 'Sale price (XAF)'),
              ),
            ],
          ),
          _field(editor.originalPriceController, 'Original price (XAF)'),
          _field(editor.ctaController, 'Button label'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Popular', style: GoogleFonts.poppins(fontSize: 14)),
            value: editor.isPopular,
            onChanged: (v) => setState(() => editor.isPopular = v),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: label.contains('XAF') || label == 'Credits'
            ? TextInputType.number
            : TextInputType.text,
        inputFormatters: label.contains('XAF') || label == 'Credits'
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

class _PlanEditor {
  final String id;
  final TextEditingController titleController;
  final TextEditingController subtitleController;
  final TextEditingController creditsController;
  final TextEditingController salePriceController;
  final TextEditingController originalPriceController;
  final TextEditingController ctaController;
  bool isPopular;
  final List<String> benefits;

  _PlanEditor({
    required this.id,
    required this.titleController,
    required this.subtitleController,
    required this.creditsController,
    required this.salePriceController,
    required this.originalPriceController,
    required this.ctaController,
    required this.isPopular,
    required this.benefits,
  });

  factory _PlanEditor.fromPlan(SkulmateRevisionPlan plan) {
    return _PlanEditor(
      id: plan.id,
      titleController: TextEditingController(text: plan.title),
      subtitleController: TextEditingController(text: plan.subtitle),
      creditsController: TextEditingController(text: '${plan.credits}'),
      salePriceController:
          TextEditingController(text: plan.amountXaf.toStringAsFixed(0)),
      originalPriceController:
          TextEditingController(text: plan.originalAmountXaf.toStringAsFixed(0)),
      ctaController: TextEditingController(text: plan.cta),
      isPopular: plan.isPopular,
      benefits: plan.benefits,
    );
  }

  void dispose() {
    titleController.dispose();
    subtitleController.dispose();
    creditsController.dispose();
    salePriceController.dispose();
    originalPriceController.dispose();
    ctaController.dispose();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': titleController.text.trim(),
        'subtitle': subtitleController.text.trim(),
        'credits': int.tryParse(creditsController.text.trim()) ?? 0,
        'amount_xaf': int.tryParse(salePriceController.text.trim()) ?? 0,
        'original_amount_xaf':
            int.tryParse(originalPriceController.text.trim()) ?? 0,
        'is_popular': isPopular,
        'cta': ctaController.text.trim(),
        'benefits': benefits,
        'sort_order': switch (id) {
          'starter' => 1,
          'pro' => 2,
          'elite' => 3,
          _ => 0,
        },
      };
}
