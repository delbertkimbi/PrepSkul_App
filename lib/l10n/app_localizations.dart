import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'PrepSkul'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Guiding Every Learner to their full potential'**
  String get tagline;

  /// No description provided for @onboardingLearnTitle.
  ///
  /// In en, this message translates to:
  /// **'Learn at Your Pace'**
  String get onboardingLearnTitle;

  /// No description provided for @onboardingLearnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Personalized lessons that adapt to your learning style and schedule.'**
  String get onboardingLearnSubtitle;

  /// No description provided for @onboardingAchieveTitle.
  ///
  /// In en, this message translates to:
  /// **'Achieve Your Goals'**
  String get onboardingAchieveTitle;

  /// No description provided for @onboardingAchieveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'From struggling students to confident achievers - your potential is limitless.'**
  String get onboardingAchieveSubtitle;

  /// No description provided for @onboardingConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect with Top Tutors'**
  String get onboardingConnectTitle;

  /// No description provided for @onboardingConnectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Book expert tutors for online or in-person sessions anytime.'**
  String get onboardingConnectSubtitle;

  /// No description provided for @buttonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get buttonNext;

  /// No description provided for @buttonSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get buttonSkip;

  /// No description provided for @buttonGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get buttonGetStarted;

  /// No description provided for @languageSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSettingsTitle;

  /// No description provided for @languageSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change app language'**
  String get languageSettingsSubtitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @languageChangedEnglish.
  ///
  /// In en, this message translates to:
  /// **'Language changed to English'**
  String get languageChangedEnglish;

  /// No description provided for @languageChangedFrench.
  ///
  /// In en, this message translates to:
  /// **'Language changed to French'**
  String get languageChangedFrench;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navFindTutors.
  ///
  /// In en, this message translates to:
  /// **'Find Tutors'**
  String get navFindTutors;

  /// No description provided for @navRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get navRequests;

  /// No description provided for @navSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get navSessions;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettings;

  /// No description provided for @profileEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEditProfile;

  /// No description provided for @profileEditProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your profile information'**
  String get profileEditProfileSubtitle;

  /// No description provided for @profileEditTutorInfo.
  ///
  /// In en, this message translates to:
  /// **'Edit Tutor Info'**
  String get profileEditTutorInfo;

  /// No description provided for @profileEditTutorInfoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your teaching profile'**
  String get profileEditTutorInfoSubtitle;

  /// No description provided for @profilePreviewProfile.
  ///
  /// In en, this message translates to:
  /// **'Preview Profile'**
  String get profilePreviewProfile;

  /// No description provided for @profilePreviewProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See how others view your profile'**
  String get profilePreviewProfileSubtitle;

  /// No description provided for @profileNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profileNotifications;

  /// No description provided for @profileNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage notification preferences'**
  String get profileNotificationsSubtitle;

  /// No description provided for @profileLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguage;

  /// No description provided for @profileLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change app language'**
  String get profileLanguageSubtitle;

  /// No description provided for @profileHelpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get profileHelpSupport;

  /// No description provided for @profileHelpSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get help and contact support'**
  String get profileHelpSupportSubtitle;

  /// No description provided for @profileLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get profileLogout;

  /// No description provided for @profileLearningInformation.
  ///
  /// In en, this message translates to:
  /// **'Learning Information'**
  String get profileLearningInformation;

  /// No description provided for @myRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Requests'**
  String get myRequestsTitle;

  /// No description provided for @myRequestsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get myRequestsFilterAll;

  /// No description provided for @myRequestsFilterPending.
  ///
  /// In en, this message translates to:
  /// **'Pending Approval Request'**
  String get myRequestsFilterPending;

  /// No description provided for @myRequestsFilterCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom Request'**
  String get myRequestsFilterCustom;

  /// No description provided for @myRequestsFilterTrial.
  ///
  /// In en, this message translates to:
  /// **'Trial Sessions'**
  String get myRequestsFilterTrial;

  /// No description provided for @myRequestsFilterBooking.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get myRequestsFilterBooking;

  /// No description provided for @myRequestsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Request a tutor of your choice'**
  String get myRequestsEmptyTitle;

  /// No description provided for @myRequestsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us what you\'re looking for and we\'ll find the perfect match for you'**
  String get myRequestsEmptySubtitle;

  /// No description provided for @myRequestsNoPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'No pending requests'**
  String get myRequestsNoPendingTitle;

  /// No description provided for @myRequestsNoPendingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up!'**
  String get myRequestsNoPendingSubtitle;

  /// No description provided for @myRequestsNoTrialsTitle.
  ///
  /// In en, this message translates to:
  /// **'No trial sessions yet'**
  String get myRequestsNoTrialsTitle;

  /// No description provided for @myRequestsNoTrialsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Request a trial session from a tutor\'s profile to get started'**
  String get myRequestsNoTrialsSubtitle;

  /// No description provided for @myRequestsNoBookingsTitle.
  ///
  /// In en, this message translates to:
  /// **'No booking requests yet'**
  String get myRequestsNoBookingsTitle;

  /// No description provided for @myRequestsNoBookingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Book a tutor from their profile to start regular sessions'**
  String get myRequestsNoBookingsSubtitle;

  /// No description provided for @myRequestsTrialSession.
  ///
  /// In en, this message translates to:
  /// **'Trial Session'**
  String get myRequestsTrialSession;

  /// No description provided for @myRequestsPayNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get myRequestsPayNow;

  /// No description provided for @myRequestsTrialDeleted.
  ///
  /// In en, this message translates to:
  /// **'Trial session deleted successfully'**
  String get myRequestsTrialDeleted;

  /// No description provided for @myRequestsTrialCancelled.
  ///
  /// In en, this message translates to:
  /// **'Trial session cancelled. Tutor has been notified.'**
  String get myRequestsTrialCancelled;

  /// No description provided for @myRequestsStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending Approval'**
  String get myRequestsStatusPending;

  /// No description provided for @myRequestsStatusAwaitingPayment.
  ///
  /// In en, this message translates to:
  /// **'Awaiting Payment'**
  String get myRequestsStatusAwaitingPayment;

  /// No description provided for @paymentHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get paymentHistoryTitle;

  /// No description provided for @paymentHistoryTabBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get paymentHistoryTabBookings;

  /// No description provided for @paymentHistoryTabTrials.
  ///
  /// In en, this message translates to:
  /// **'Trials'**
  String get paymentHistoryTabTrials;

  /// No description provided for @paymentHistoryTabSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get paymentHistoryTabSessions;

  /// No description provided for @paymentHistoryFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get paymentHistoryFilterAll;

  /// No description provided for @paymentHistoryFilterPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get paymentHistoryFilterPending;

  /// No description provided for @paymentHistoryFilterPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paymentHistoryFilterPaid;

  /// No description provided for @paymentHistoryFilterFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get paymentHistoryFilterFailed;

  /// No description provided for @paymentHistoryPaymentPlan.
  ///
  /// In en, this message translates to:
  /// **'Payment Plan'**
  String get paymentHistoryPaymentPlan;

  /// No description provided for @paymentHistoryRetryPayment.
  ///
  /// In en, this message translates to:
  /// **'Retry Payment'**
  String get paymentHistoryRetryPayment;

  /// No description provided for @paymentHistoryAwaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'Awaiting tutor approval'**
  String get paymentHistoryAwaitingApproval;

  /// No description provided for @paymentHistoryStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paymentHistoryStatusPaid;

  /// No description provided for @paymentHistoryStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get paymentHistoryStatusPending;

  /// No description provided for @paymentHistoryStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get paymentHistoryStatusFailed;

  /// No description provided for @mySessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Sessions'**
  String get mySessionsTitle;

  /// No description provided for @mySessionsTabUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get mySessionsTabUpcoming;

  /// No description provided for @mySessionsTabCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get mySessionsTabCompleted;

  /// No description provided for @commonEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get commonEmail;

  /// No description provided for @commonPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get commonPhone;

  /// No description provided for @commonAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get commonAmount;

  /// No description provided for @commonScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get commonScheduled;

  /// No description provided for @commonStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get commonStatus;

  /// No description provided for @roleStudent.
  ///
  /// In en, this message translates to:
  /// **'STUDENT'**
  String get roleStudent;

  /// No description provided for @roleParent.
  ///
  /// In en, this message translates to:
  /// **'PARENT'**
  String get roleParent;

  /// No description provided for @roleTutor.
  ///
  /// In en, this message translates to:
  /// **'TUTOR'**
  String get roleTutor;

  /// No description provided for @noPaymentRequestsFound.
  ///
  /// In en, this message translates to:
  /// **'No payment requests found'**
  String get noPaymentRequestsFound;

  /// No description provided for @tutorNeedsToApprove.
  ///
  /// In en, this message translates to:
  /// **'Your tutor needs to approve this trial before you can pay.'**
  String get tutorNeedsToApprove;

  /// No description provided for @awaitingTutorApproval.
  ///
  /// In en, this message translates to:
  /// **'Awaiting tutor approval'**
  String get awaitingTutorApproval;

  /// No description provided for @studentRequest.
  ///
  /// In en, this message translates to:
  /// **'STUDENT REQUEST'**
  String get studentRequest;

  /// No description provided for @parentRequest.
  ///
  /// In en, this message translates to:
  /// **'PARENT REQUEST'**
  String get parentRequest;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning 👋'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon 👋'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening 👋'**
  String get goodEvening;

  /// No description provided for @yourProgress.
  ///
  /// In en, this message translates to:
  /// **'Your Progress'**
  String get yourProgress;

  /// No description provided for @activeTutors.
  ///
  /// In en, this message translates to:
  /// **'Active Tutors'**
  String get activeTutors;

  /// No description provided for @sessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessions;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @findPerfectTutor.
  ///
  /// In en, this message translates to:
  /// **'Find Perfect Tutor'**
  String get findPerfectTutor;

  /// No description provided for @browseTutorsIn.
  ///
  /// In en, this message translates to:
  /// **'Browse tutors in {location}'**
  String browseTutorsIn(String location);

  /// No description provided for @myRequests.
  ///
  /// In en, this message translates to:
  /// **'My Requests'**
  String get myRequests;

  /// No description provided for @viewYourBookingRequests.
  ///
  /// In en, this message translates to:
  /// **'View your booking requests'**
  String get viewYourBookingRequests;

  /// No description provided for @mySessions.
  ///
  /// In en, this message translates to:
  /// **'My Sessions'**
  String get mySessions;

  /// No description provided for @viewUpcomingAndCompletedSessions.
  ///
  /// In en, this message translates to:
  /// **'View upcoming and completed sessions'**
  String get viewUpcomingAndCompletedSessions;

  /// No description provided for @paymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get paymentHistory;

  /// No description provided for @viewAndManageYourPayments.
  ///
  /// In en, this message translates to:
  /// **'View and manage your payments'**
  String get viewAndManageYourPayments;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search tutors...'**
  String get searchPlaceholder;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @filterBySubject.
  ///
  /// In en, this message translates to:
  /// **'Filter by subject'**
  String get filterBySubject;

  /// No description provided for @filterByLocation.
  ///
  /// In en, this message translates to:
  /// **'Filter by location'**
  String get filterByLocation;

  /// No description provided for @filterByPrice.
  ///
  /// In en, this message translates to:
  /// **'Filter by price'**
  String get filterByPrice;

  /// No description provided for @bookTrialSession.
  ///
  /// In en, this message translates to:
  /// **'Book Trial Session'**
  String get bookTrialSession;

  /// No description provided for @bookThisTutor.
  ///
  /// In en, this message translates to:
  /// **'Book This Tutor'**
  String get bookThisTutor;

  /// No description provided for @tutorProfile.
  ///
  /// In en, this message translates to:
  /// **'Tutor Profile'**
  String get tutorProfile;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @subjects.
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get subjects;

  /// No description provided for @pricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get pricing;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @filterMonthlyPriceRange.
  ///
  /// In en, this message translates to:
  /// **'Monthly Price Range'**
  String get filterMonthlyPriceRange;

  /// No description provided for @filterMinimumRating.
  ///
  /// In en, this message translates to:
  /// **'Minimum Rating'**
  String get filterMinimumRating;

  /// No description provided for @filterAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get filterAny;

  /// No description provided for @filterUnder20k.
  ///
  /// In en, this message translates to:
  /// **'Under 20k/mo'**
  String get filterUnder20k;

  /// No description provided for @filter20kTo30k.
  ///
  /// In en, this message translates to:
  /// **'20k - 30k/mo'**
  String get filter20kTo30k;

  /// No description provided for @filter30kTo40k.
  ///
  /// In en, this message translates to:
  /// **'30k - 40k/mo'**
  String get filter30kTo40k;

  /// No description provided for @filter40kTo50k.
  ///
  /// In en, this message translates to:
  /// **'40k - 50k/mo'**
  String get filter40kTo50k;

  /// No description provided for @filterAbove50k.
  ///
  /// In en, this message translates to:
  /// **'Above 50k/mo'**
  String get filterAbove50k;

  /// No description provided for @filterShowTutors.
  ///
  /// In en, this message translates to:
  /// **'Show {count} tutor'**
  String filterShowTutors(int count);

  /// No description provided for @filterShowTutorsPlural.
  ///
  /// In en, this message translates to:
  /// **'Show {count} tutors'**
  String filterShowTutorsPlural(int count);

  /// No description provided for @discoverTutorsNearYou.
  ///
  /// In en, this message translates to:
  /// **'Discover tutors near you'**
  String get discoverTutorsNearYou;

  /// No description provided for @requestTutorSubjectLevel.
  ///
  /// In en, this message translates to:
  /// **'Subject & Level'**
  String get requestTutorSubjectLevel;

  /// No description provided for @requestTutorEducationLevel.
  ///
  /// In en, this message translates to:
  /// **'Education Level'**
  String get requestTutorEducationLevel;

  /// No description provided for @requestTutorSpecificRequirements.
  ///
  /// In en, this message translates to:
  /// **'Specific Requirements (Optional)'**
  String get requestTutorSpecificRequirements;

  /// No description provided for @requestTutorSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all that apply'**
  String get requestTutorSelectAll;

  /// No description provided for @requestTutorTutorPreferences.
  ///
  /// In en, this message translates to:
  /// **'Tutor Preferences'**
  String get requestTutorTutorPreferences;

  /// No description provided for @requestTutorHelpFindMatch.
  ///
  /// In en, this message translates to:
  /// **'Help us find the perfect match for you'**
  String get requestTutorHelpFindMatch;

  /// No description provided for @requestTutorTeachingMode.
  ///
  /// In en, this message translates to:
  /// **'Teaching Mode *'**
  String get requestTutorTeachingMode;

  /// No description provided for @requestTutorBudgetRange.
  ///
  /// In en, this message translates to:
  /// **'Budget Range'**
  String get requestTutorBudgetRange;

  /// No description provided for @requestTutorPerMonth.
  ///
  /// In en, this message translates to:
  /// **'Per month'**
  String get requestTutorPerMonth;

  /// No description provided for @requestTutorGenderPreference.
  ///
  /// In en, this message translates to:
  /// **'Gender Preference (Optional)'**
  String get requestTutorGenderPreference;

  /// No description provided for @requestTutorQualification.
  ///
  /// In en, this message translates to:
  /// **'Tutor Qualification (Optional)'**
  String get requestTutorQualification;

  /// No description provided for @requestTutorScheduleLocation.
  ///
  /// In en, this message translates to:
  /// **'Schedule & Location'**
  String get requestTutorScheduleLocation;

  /// No description provided for @requestTutorWhenWhere.
  ///
  /// In en, this message translates to:
  /// **'When and where would you like the sessions?'**
  String get requestTutorWhenWhere;

  /// No description provided for @requestTutorPreferredDays.
  ///
  /// In en, this message translates to:
  /// **'Preferred Days *'**
  String get requestTutorPreferredDays;

  /// No description provided for @requestTutorPreferredTime.
  ///
  /// In en, this message translates to:
  /// **'Preferred Time *'**
  String get requestTutorPreferredTime;

  /// No description provided for @requestTutorLocation.
  ///
  /// In en, this message translates to:
  /// **'Location *'**
  String get requestTutorLocation;

  /// No description provided for @requestTutorLocationDescription.
  ///
  /// In en, this message translates to:
  /// **'Location Description (Optional)'**
  String get requestTutorLocationDescription;

  /// No description provided for @requestTutorAdditionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional Details'**
  String get requestTutorAdditionalDetails;

  /// No description provided for @requestTutorRequestReason.
  ///
  /// In en, this message translates to:
  /// **'Why are you requesting a tutor?'**
  String get requestTutorRequestReason;

  /// No description provided for @requestTutorUrgency.
  ///
  /// In en, this message translates to:
  /// **'How urgent is this request?'**
  String get requestTutorUrgency;

  /// No description provided for @requestTutorSubmitRequest.
  ///
  /// In en, this message translates to:
  /// **'Submit Request'**
  String get requestTutorSubmitRequest;

  /// No description provided for @requestTutorSendWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Send WhatsApp Message?'**
  String get requestTutorSendWhatsApp;

  /// No description provided for @requestTutorWhatsAppPrompt.
  ///
  /// In en, this message translates to:
  /// **'Would you like to send a WhatsApp message to PrepSkul team with your request details?'**
  String get requestTutorWhatsAppPrompt;

  /// No description provided for @requestTutorSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get requestTutorSkip;

  /// No description provided for @requestTutorSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get requestTutorSend;

  /// No description provided for @requestTutorRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request Sent!'**
  String get requestTutorRequestSent;

  /// No description provided for @requestTutorRequestSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Your tutor request has been submitted successfully. Our team will contact you soon!'**
  String get requestTutorRequestSubmitted;

  /// No description provided for @requestTutorDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get requestTutorDone;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'fr': return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
