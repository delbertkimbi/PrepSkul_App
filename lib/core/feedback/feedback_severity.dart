/// User-facing feedback level for toasts and lightweight banners.
///
/// Maps to brand colors in [AppFeedback] / [BrandedSnackBar]; use [error] for
/// failures that still use a non-blocking toast (blocking dialogs use
/// [showPrepSkulAlert] with explicit destructive styling when needed).
enum FeedbackSeverity {
  success,
  info,
  warning,
  error,
}
