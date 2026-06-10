import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/responsive_helper.dart';
import 'package:prepskul/features/payment/utils/payment_provider_helper.dart';

/// Order metadata shown in checkout (recurring booking or trial).
class PaymentCheckoutOrder {
  const PaymentCheckoutOrder({
    required this.title,
    required this.subtitle,
    required this.paymentPlan,
    this.description,
    this.metadata,
    this.detailRows = const [],
    this.footerNote,
  });

  final String title;
  final String subtitle;
  final String paymentPlan;
  final String? description;
  final Map<String, dynamic>? metadata;
  final List<(String label, String value)> detailRows;
  final String? footerNote;
}

class _CheckoutMetrics {
  _CheckoutMetrics(BuildContext context)
      : size = ResponsiveHelper.getScreenSize(context),
        isWide = MediaQuery.sizeOf(context).width >=
            ResponsiveHelper.mobileBreakpoint,
        hPad = ResponsiveHelper.responsiveHorizontalPadding(context),
        vPad = ResponsiveHelper.responsiveVerticalPadding(context),
        maxWidth = ResponsiveHelper.isDesktop(context) ? 960.0 : 720.0,
        amountSize = ResponsiveHelper.isMobile(context) ? 32.0 : 36.0;

  final ScreenSize size;
  final bool isWide;
  final double hPad;
  final double vPad;
  final double maxWidth;
  final double amountSize;
}

/// Responsive Stripe-style checkout shell (mobile card + wide two-column).
class PaymentCheckoutUi {
  PaymentCheckoutUi._();

  static String planLabel(String plan) {
    switch (plan.toLowerCase()) {
      case 'weekly':
        return 'Weekly';
      case 'biweekly':
        return 'Bi-weekly';
      case 'monthly':
        return 'Monthly';
      default:
        return plan.isEmpty ? 'Installment' : plan;
    }
  }

  static Widget planChip(IconData icon, String label, {Color? accent, bool compact = false}) {
    final color = accent ?? AppTheme.primaryColor;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 11 : 14, color: color),
          SizedBox(width: compact ? 4 : 6),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'T';
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  static String? _avatarUrl(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    for (final key in [
      'tutor_avatar_url',
      'avatar_url',
      'profile_photo_url',
    ]) {
      final raw = metadata[key] as String?;
      if (raw != null && raw.trim().isNotEmpty) {
        return raw.trim();
      }
    }
    return null;
  }

  static Widget _tutorIdentityRow({
    required String name,
    String? avatarUrl,
    bool compact = false,
    bool showRole = true,
  }) {
    final size = compact ? 40.0 : 52.0;
    return Row(
      children: [
        _avatarCircle(name: name, url: avatarUrl, size: size),
        SizedBox(width: compact ? 10 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: compact ? 15 : 17,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                  height: 1.2,
                ),
              ),
              if (showRole) ...[
                const SizedBox(height: 2),
                Text(
                  'Your tutor',
                  style: GoogleFonts.poppins(
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static Widget _avatarCircle({
    required String name,
    String? url,
    required double size,
  }) {
    final initials = _initials(name);
    if (url != null) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _avatarFallback(initials, size),
          errorWidget: (_, __, ___) => _avatarFallback(initials, size),
        ),
      );
    }
    return _avatarFallback(initials, size);
  }

  static Widget _avatarFallback(String initials, double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
        ),
      ),
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  /// Full checkout page body: responsive layout + sticky pay on narrow screens.
  static Widget checkoutShell({
    required BuildContext context,
    required PaymentCheckoutOrder order,
    required double subtotal,
    required double charges,
    required double total,
    required Widget phoneField,
    Widget? errorBanner,
    required bool payEnabled,
    required bool isProcessing,
    required String payLabel,
    required VoidCallback? onPay,
  }) {
    final m = _CheckoutMetrics(context);

    if (m.isWide) {
      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: m.hPad,
            vertical: m.vPad,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: m.maxWidth),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _surfaceCard(
                    child: _orderDetailsBody(context, order, expanded: true),
                  ),
                ),
                SizedBox(width: m.size == ScreenSize.desktop ? 28 : 20),
                Expanded(
                  child: _surfaceCard(
                    child: _paymentFormBody(
                      context: context,
                      total: total,
                      subtotal: subtotal,
                      charges: charges,
                      phoneField: phoneField,
                      errorBanner: errorBanner,
                      payEnabled: payEnabled,
                      isProcessing: isProcessing,
                      payLabel: payLabel,
                      onPay: onPay,
                      embedPayButton: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(m.hPad, 12, m.hPad, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: m.maxWidth),
                child: _surfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _amountBlock(context, total, centered: true),
                      const SizedBox(height: 14),
                      _divider(),
                      const SizedBox(height: 12),
                      _orderSummaryRow(
                        context: context,
                        order: order,
                        onTap: () => _openOrderDetails(context, order),
                      ),
                      const SizedBox(height: 14),
                      _divider(),
                      const SizedBox(height: 12),
                      sectionLabel('Mobile money number'),
                      phoneField,
                      const SizedBox(height: 16),
                      feeBreakdown(
                        subtotal: subtotal,
                        charges: charges,
                      ),
                      if (errorBanner != null) ...[
                        const SizedBox(height: 16),
                        errorBanner,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        _stickyPayBarShell(
          context: context,
          enabled: payEnabled,
          isProcessing: isProcessing,
          label: payLabel,
          onPressed: onPay,
        ),
      ],
    );
  }

  static Widget _surfaceCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.softBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  static Widget _amountBlock(
    BuildContext context,
    double total, {
    bool centered = false,
  }) {
    final m = _CheckoutMetrics(context);
    final align = centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.start;

    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          'Total due',
          textAlign: textAlign,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textMedium,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          PricingService.formatPrice(total),
          textAlign: textAlign,
          style: GoogleFonts.poppins(
            fontSize: m.amountSize,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
            height: 1.1,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            Icon(Icons.lock_outline, size: 14, color: AppTheme.textMedium),
            Text(
              'Secure Mobile Money',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textMedium,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text('·', style: TextStyle(color: AppTheme.textMedium)),
            ...providerTrustStrip(inline: true),
          ],
        ),
      ],
    );
  }

  static Widget _paymentFormBody({
    required BuildContext context,
    required double total,
    required double subtotal,
    required double charges,
    required Widget phoneField,
    Widget? errorBanner,
    required bool payEnabled,
    required bool isProcessing,
    required String payLabel,
    required VoidCallback? onPay,
    required bool embedPayButton,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _amountBlock(context, total),
        const SizedBox(height: 24),
        sectionLabel('Mobile money number'),
        phoneField,
        const SizedBox(height: 20),
        feeBreakdown(subtotal: subtotal, charges: charges),
        if (errorBanner != null) ...[
          const SizedBox(height: 16),
          errorBanner,
        ],
        if (embedPayButton) ...[
          const SizedBox(height: 24),
          _payButton(
            enabled: payEnabled,
            isProcessing: isProcessing,
            label: payLabel,
            onPressed: onPay,
          ),
        ],
      ],
    );
  }

  static Widget _orderDetailsBody(
    BuildContext context,
    PaymentCheckoutOrder order, {
    required bool expanded,
  }) {
    final planLabelText = planLabel(order.paymentPlan);
    final metadata = order.metadata ?? {};
    final location = (metadata['location'] as String?)?.trim().toLowerCase() ?? '';
    final frequency = metadata['frequency'] as int? ??
        (metadata['frequency'] as num?)?.toInt();
    final paymentIndex = metadata['payment_number'] as int? ??
        (metadata['payment_number'] as num?)?.toInt();
    final paymentTotal = metadata['total_payments'] as int? ??
        (metadata['total_payments'] as num?)?.toInt();
    final avatarUrl = _avatarUrl(metadata);
    final isTrial = order.paymentPlan.toLowerCase() == 'trial';

    if (!expanded) {
      return _tutorIdentityRow(
        name: order.title,
        avatarUrl: isTrial ? null : avatarUrl,
        compact: true,
        showRole: false,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isTrial && order.detailRows.isNotEmpty)
          Text(
            order.title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          )
        else
          _tutorIdentityRow(
            name: order.title,
            avatarUrl: avatarUrl,
            compact: false,
          ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (planLabelText.isNotEmpty && planLabelText != 'Installment')
              planChip(Icons.calendar_month, planLabelText),
            if (paymentIndex != null && paymentTotal != null)
              planChip(
                Icons.payments_outlined,
                '$paymentIndex of $paymentTotal',
              ),
            if (location == 'onsite' || location == 'hybrid')
              planChip(
                Icons.location_on_outlined,
                location.toUpperCase(),
                accent: Colors.orange.shade700,
              ),
            if (location == 'online')
              planChip(
                Icons.videocam_outlined,
                'Online',
                accent: AppTheme.skyBlue,
              ),
            if (frequency != null && frequency > 0)
              planChip(Icons.event_repeat, '$frequency×/wk'),
          ],
        ),
        if (order.detailRows.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...order.detailRows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      row.$1,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (order.description != null && order.description!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            order.description!,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textMedium,
              height: 1.45,
            ),
          ),
        ],
        const SizedBox(height: 12),
        _infoNote(
          order.footerNote ??
              'After payment, sessions for this $planLabelText period are scheduled. '
                  'You\'ll be prompted for the next installment when it\'s due.',
        ),
      ],
    );
  }

  static Widget _infoNote(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.softBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppTheme.primaryColor.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textDark,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _sheetHeader({
    required String title,
    required VoidCallback onClose,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            visualDensity: VisualDensity.compact,
            color: AppTheme.textMedium,
          ),
        ],
      ),
    );
  }

  static Widget _orderSummaryRow({
    required BuildContext context,
    required PaymentCheckoutOrder order,
    required VoidCallback onTap,
  }) {
    final metadata = order.metadata ?? {};
    final avatarUrl = _avatarUrl(metadata);
    final isTrial = order.paymentPlan.toLowerCase() == 'trial';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              if (!isTrial)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _avatarCircle(
                    name: order.title,
                    url: avatarUrl,
                    size: 36,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textMedium,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Details',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _divider() => Divider(height: 1, color: AppTheme.softBorder);

  static Widget sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textDark,
        ),
      ),
    );
  }

  static Widget feeBreakdown({
    required double subtotal,
    required double charges,
    double chargeRateLabel = 0.02,
  }) {
    if (charges <= 0) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        _feeRow('Subtotal', PricingService.formatPrice(subtotal)),
        const SizedBox(height: 8),
        _feeRow(
          'Processing fee (${(chargeRateLabel * 100).round()}%)',
          PricingService.formatPrice(charges),
          muted: true,
        ),
      ],
    );
  }

  static Widget _feeRow(String label, String value, {bool muted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: muted ? AppTheme.textMedium : AppTheme.textDark,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: muted ? AppTheme.textMedium : AppTheme.textDark,
          ),
        ),
      ],
    );
  }

  static Widget _stickyPayBarShell({
    required BuildContext context,
    required bool enabled,
    required bool isProcessing,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final m = _CheckoutMetrics(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.softBorder)),
      ),
      padding: EdgeInsets.fromLTRB(m.hPad, 12, m.hPad, 12),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: m.maxWidth),
            child: _payButton(
              enabled: enabled,
              isProcessing: isProcessing,
              label: label,
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
  }

  static Widget _payButton({
    required bool enabled,
    required bool isProcessing,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          disabledBackgroundColor: AppTheme.softBorder,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isProcessing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  static void _openOrderDetails(BuildContext context, PaymentCheckoutOrder order) {
    if (MediaQuery.sizeOf(context).width >= ResponsiveHelper.mobileBreakpoint) {
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sheetHeader(
                  title: 'What you\'re paying for',
                  onClose: () => Navigator.pop(ctx),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: _orderDetailsBody(context, order, expanded: true),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.44,
          minChildSize: 0.3,
          maxChildSize: 0.88,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 32,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppTheme.softBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  _sheetHeader(
                    title: 'What you\'re paying for',
                    onClose: () => Navigator.pop(ctx),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        4,
                        16,
                        16 + MediaQuery.paddingOf(ctx).bottom,
                      ),
                      child: _orderDetailsBody(context, order, expanded: true),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Legacy helpers — delegate to unified order API
  static Future<void> showPlanDetailsSheet(
    BuildContext context, {
    required String tutorName,
    required String paymentPlan,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    _openOrderDetails(
      context,
      PaymentCheckoutOrder(
        title: tutorName,
        subtitle: planLabel(paymentPlan),
        paymentPlan: paymentPlan,
        description: description,
        metadata: metadata,
      ),
    );
  }

  static Future<void> showTrialDetailsSheet(
    BuildContext context, {
    required String title,
    required List<(String label, String value)> rows,
    String? footerNote,
  }) async {
    _openOrderDetails(
      context,
      PaymentCheckoutOrder(
        title: rows.isNotEmpty ? rows.first.$2 : title,
        subtitle: title,
        paymentPlan: 'trial',
        detailRows: rows,
        footerNote: footerNote,
      ),
    );
  }

  static List<Widget> providerTrustStrip({bool inline = false}) {
    return [
      _providerPill('mtn'),
      if (!inline) const SizedBox(width: 8),
      _providerPill('orange'),
    ];
  }

  static Widget _providerPill(String provider) {
    final color = PaymentProviderHelper.getProviderColor(provider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        PaymentProviderHelper.getProviderName(provider),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // Deprecated aliases kept for any external callers
  static Widget amountHero({required double total, String methodLine = ''}) =>
      Builder(builder: (ctx) => _amountBlock(ctx, total));

  static Widget orderSummaryTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String actionLabel = 'Details',
  }) =>
      Builder(
        builder: (ctx) => _orderSummaryRow(
          context: ctx,
          order: PaymentCheckoutOrder(
            title: title,
            subtitle: subtitle,
            paymentPlan: '',
          ),
          onTap: onTap,
        ),
      );

  static Widget stickyPayBar({
    required bool enabled,
    required bool isProcessing,
    required String label,
    required VoidCallback? onPressed,
  }) =>
      Builder(
        builder: (ctx) => _stickyPayBarShell(
          context: ctx,
          enabled: enabled,
          isProcessing: isProcessing,
          label: label,
          onPressed: onPressed,
        ),
      );
}

/// MoMo number field — clearly editable even when pre-filled from the account.
class PaymentMobileMoneyPhoneField extends StatefulWidget {
  final TextEditingController controller;
  final String? detectedProvider;
  final String? errorText;
  final String? validationHint;
  final ValueChanged<String>? onChanged;

  const PaymentMobileMoneyPhoneField({
    super.key,
    required this.controller,
    this.detectedProvider,
    this.errorText,
    this.validationHint,
    this.onChanged,
  });

  @override
  State<PaymentMobileMoneyPhoneField> createState() =>
      _PaymentMobileMoneyPhoneFieldState();
}

class _PaymentMobileMoneyPhoneFieldState
    extends State<PaymentMobileMoneyPhoneField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.controller.text.trim().isNotEmpty;
    final provider = widget.detectedProvider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          keyboardType: TextInputType.phone,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: widget.onChanged,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
            letterSpacing: 0.2,
          ),
          decoration: InputDecoration(
            hintText: '67XXXXXXX or 69XXXXXXX',
            hintStyle: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppTheme.textMedium,
            ),
            prefixIcon: Icon(
              Icons.phone_outlined,
              color: AppTheme.primaryColor.withValues(alpha: 0.85),
              size: 20,
            ),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: AppTheme.textMedium.withValues(alpha: 0.9),
                  ),
                  if (provider != null) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: PaymentProviderHelper.getProviderColor(provider)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: PaymentProviderHelper.getProviderColor(provider)
                              .withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PaymentProviderHelper.getProviderIcon(provider),
                            size: 14,
                            color:
                                PaymentProviderHelper.getProviderColor(provider),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            PaymentProviderHelper.getProviderName(provider),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: PaymentProviderHelper.getProviderColor(
                                provider,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            suffixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.primaryColor.withValues(alpha: 0.22),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.primaryColor.withValues(alpha: 0.22),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: AppTheme.neutral50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            errorText: widget.errorText,
          ),
        ),
        if (hasValue) ...[
          const SizedBox(height: 6),
          Text(
            'Saved from your account — tap to pay with a different number',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: AppTheme.textMedium,
              height: 1.35,
            ),
          ),
        ],
        if (widget.validationHint != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.validationHint!,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.accentOrange,
            ),
          ),
        ],
      ],
    );
  }
}
