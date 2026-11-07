import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

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
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'WIM-Z'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageKorean.
  ///
  /// In en, this message translates to:
  /// **'한국어 (Korean)'**
  String get languageKorean;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the app display language'**
  String get languageSubtitle;

  /// No description provided for @appRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many commands, slow down'**
  String get appRateLimited;

  /// No description provided for @appReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get appReconnecting;

  /// No description provided for @appTapToRetry.
  ///
  /// In en, this message translates to:
  /// **'Tap to retry'**
  String get appTapToRetry;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navDogs.
  ///
  /// In en, this message translates to:
  /// **'Dogs'**
  String get navDogs;

  /// No description provided for @navMissions.
  ///
  /// In en, this message translates to:
  /// **'Missions'**
  String get navMissions;

  /// No description provided for @navPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get navPhotos;

  /// No description provided for @navActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get navActivity;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @quickActionsSongFallback.
  ///
  /// In en, this message translates to:
  /// **'song'**
  String get quickActionsSongFallback;

  /// No description provided for @quickActionsFileFallback.
  ///
  /// In en, this message translates to:
  /// **'file'**
  String get quickActionsFileFallback;

  /// No description provided for @quickActionsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{filename}\"'**
  String quickActionsDeleted(String filename);

  /// No description provided for @quickActionsDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String quickActionsDeleteFailed(String error);

  /// No description provided for @quickActionsUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded \"{filename}\" successfully'**
  String quickActionsUploaded(String filename);

  /// No description provided for @quickActionsUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String quickActionsUploadFailed(String error);

  /// No description provided for @quickActionsTreat.
  ///
  /// In en, this message translates to:
  /// **'Treat'**
  String get quickActionsTreat;

  /// No description provided for @quickActionsGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get quickActionsGood;

  /// No description provided for @quickActionsCallDog.
  ///
  /// In en, this message translates to:
  /// **'Call Dog'**
  String get quickActionsCallDog;

  /// No description provided for @quickActionsWant.
  ///
  /// In en, this message translates to:
  /// **'Want?'**
  String get quickActionsWant;

  /// No description provided for @quickActionsNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get quickActionsNo;

  /// No description provided for @quickActionsQuiet.
  ///
  /// In en, this message translates to:
  /// **'Quiet'**
  String get quickActionsQuiet;

  /// No description provided for @quickActionsSit.
  ///
  /// In en, this message translates to:
  /// **'Sit'**
  String get quickActionsSit;

  /// No description provided for @quickActionsLedPattern.
  ///
  /// In en, this message translates to:
  /// **'LED: {pattern}'**
  String quickActionsLedPattern(String pattern);

  /// No description provided for @quickActionsLedNotSent.
  ///
  /// In en, this message translates to:
  /// **'Not connected — LED not sent'**
  String get quickActionsLedNotSent;

  /// No description provided for @quickActionsSelectMp3.
  ///
  /// In en, this message translates to:
  /// **'Please select an MP3 file'**
  String get quickActionsSelectMp3;

  /// No description provided for @quickActionsFileAccessFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not access file'**
  String get quickActionsFileAccessFailed;

  /// No description provided for @quickActionsFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File too large (max 20MB)'**
  String get quickActionsFileTooLarge;

  /// No description provided for @quickActionsUploadLocalUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Music upload not available in local mode'**
  String get quickActionsUploadLocalUnavailable;

  /// No description provided for @quickActionsNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Not authenticated - please login'**
  String get quickActionsNotAuthenticated;

  /// No description provided for @quickActionsUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading \"{filename}\"...'**
  String quickActionsUploading(String filename);

  /// No description provided for @quickActionsFilePickerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open file picker: {error}'**
  String quickActionsFilePickerFailed(String error);

  /// No description provided for @quickActionsSelectDogFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a dog first'**
  String get quickActionsSelectDogFirst;

  /// No description provided for @quickActionsDeleteSongTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Song'**
  String get quickActionsDeleteSongTitle;

  /// No description provided for @quickActionsDeleteSongConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" from the playlist?'**
  String quickActionsDeleteSongConfirm(String name);

  /// No description provided for @quickActionsDeletingSong.
  ///
  /// In en, this message translates to:
  /// **'Deleting \"{name}\"...'**
  String quickActionsDeletingSong(String name);

  /// No description provided for @ledPatternRainbow.
  ///
  /// In en, this message translates to:
  /// **'Rainbow'**
  String get ledPatternRainbow;

  /// No description provided for @ledPatternFire.
  ///
  /// In en, this message translates to:
  /// **'Fire'**
  String get ledPatternFire;

  /// No description provided for @ledPatternBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get ledPatternBlue;

  /// No description provided for @ledPatternChase.
  ///
  /// In en, this message translates to:
  /// **'Chase'**
  String get ledPatternChase;

  /// No description provided for @ledPatternAmbient.
  ///
  /// In en, this message translates to:
  /// **'Ambient'**
  String get ledPatternAmbient;

  /// No description provided for @quickActionsLighting.
  ///
  /// In en, this message translates to:
  /// **'Lighting'**
  String get quickActionsLighting;

  /// No description provided for @quickActionsBluLight.
  ///
  /// In en, this message translates to:
  /// **'BluLight'**
  String get quickActionsBluLight;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @pttTalk.
  ///
  /// In en, this message translates to:
  /// **'Talk'**
  String get pttTalk;

  /// No description provided for @pttRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get pttRecording;

  /// No description provided for @pttSent.
  ///
  /// In en, this message translates to:
  /// **'Sent ✓'**
  String get pttSent;

  /// No description provided for @pttSeconds.
  ///
  /// In en, this message translates to:
  /// **'{sec}s'**
  String pttSeconds(int sec);

  /// No description provided for @pttSending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get pttSending;

  /// No description provided for @pttPlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing...'**
  String get pttPlaying;

  /// No description provided for @pttListening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get pttListening;

  /// No description provided for @pttTapToListen.
  ///
  /// In en, this message translates to:
  /// **'Tap to listen'**
  String get pttTapToListen;

  /// No description provided for @panTiltPan.
  ///
  /// In en, this message translates to:
  /// **'P:{value}'**
  String panTiltPan(String value);

  /// No description provided for @panTiltTilt.
  ///
  /// In en, this message translates to:
  /// **'T:{value}'**
  String panTiltTilt(String value);

  /// No description provided for @panTiltCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get panTiltCenter;

  /// No description provided for @audioMuteListening.
  ///
  /// In en, this message translates to:
  /// **'Listening to robot...'**
  String get audioMuteListening;

  /// No description provided for @audioMuteUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute audio'**
  String get audioMuteUnmute;

  /// No description provided for @audioMuteMute.
  ///
  /// In en, this message translates to:
  /// **'Mute audio'**
  String get audioMuteMute;

  /// No description provided for @mjpegUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Video unavailable'**
  String get mjpegUnavailable;

  /// No description provided for @mjpegConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to camera...'**
  String get mjpegConnecting;

  /// No description provided for @videoHudFps.
  ///
  /// In en, this message translates to:
  /// **'FPS'**
  String get videoHudFps;

  /// No description provided for @videoHudBattery.
  ///
  /// In en, this message translates to:
  /// **'BAT'**
  String get videoHudBattery;

  /// No description provided for @videoHudPan.
  ///
  /// In en, this message translates to:
  /// **'PAN'**
  String get videoHudPan;

  /// No description provided for @videoHudRec.
  ///
  /// In en, this message translates to:
  /// **'REC'**
  String get videoHudRec;

  /// No description provided for @videoSavedNotWired.
  ///
  /// In en, this message translates to:
  /// **'Available once the robot ships recording download (Chain REC)'**
  String get videoSavedNotWired;

  /// No description provided for @videoSavedSampleData.
  ///
  /// In en, this message translates to:
  /// **'SAMPLE DATA — not live'**
  String get videoSavedSampleData;

  /// No description provided for @videoSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Video saved'**
  String get videoSavedTitle;

  /// No description provided for @videoSavedOnRobotAt.
  ///
  /// In en, this message translates to:
  /// **'SAVED ON ROBOT AT'**
  String get videoSavedOnRobotAt;

  /// No description provided for @videoSavedPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied'**
  String get videoSavedPathCopied;

  /// No description provided for @videoSavedRetention.
  ///
  /// In en, this message translates to:
  /// **'retention: {retentionClass}'**
  String videoSavedRetention(String retentionClass);

  /// No description provided for @videoSavedSaveToPhone.
  ///
  /// In en, this message translates to:
  /// **'Save to Phone'**
  String get videoSavedSaveToPhone;

  /// No description provided for @videoSavedShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get videoSavedShare;

  /// No description provided for @webrtcWaitingForConnection.
  ///
  /// In en, this message translates to:
  /// **'Waiting for connection...'**
  String get webrtcWaitingForConnection;

  /// No description provided for @webrtcTapToConnect.
  ///
  /// In en, this message translates to:
  /// **'Tap to connect'**
  String get webrtcTapToConnect;

  /// No description provided for @webrtcConnectingVideo.
  ///
  /// In en, this message translates to:
  /// **'Connecting video...'**
  String get webrtcConnectingVideo;

  /// No description provided for @webrtcConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Video connection failed'**
  String get webrtcConnectionFailed;

  /// No description provided for @webrtcInitializingRenderer.
  ///
  /// In en, this message translates to:
  /// **'Initializing renderer...'**
  String get webrtcInitializingRenderer;

  /// No description provided for @webrtcWaitingForStream.
  ///
  /// In en, this message translates to:
  /// **'Waiting for video stream...'**
  String get webrtcWaitingForStream;

  /// No description provided for @webrtcReceivingVideo.
  ///
  /// In en, this message translates to:
  /// **'Receiving video...'**
  String get webrtcReceivingVideo;

  /// No description provided for @videoSavedToGallery.
  ///
  /// In en, this message translates to:
  /// **'Video saved to gallery!'**
  String get videoSavedToGallery;

  /// No description provided for @videoSavedShort.
  ///
  /// In en, this message translates to:
  /// **'Video saved!'**
  String get videoSavedShort;

  /// No description provided for @photoSavedToGallery.
  ///
  /// In en, this message translates to:
  /// **'Photo saved to gallery!'**
  String get photoSavedToGallery;

  /// No description provided for @photoSavedShort.
  ///
  /// In en, this message translates to:
  /// **'Photo saved!'**
  String get photoSavedShort;

  /// No description provided for @gaugeCharging.
  ///
  /// In en, this message translates to:
  /// **'CHARGING'**
  String get gaugeCharging;

  /// No description provided for @gaugeBattery.
  ///
  /// In en, this message translates to:
  /// **'BATTERY'**
  String get gaugeBattery;

  /// No description provided for @gaugeLeft.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get gaugeLeft;

  /// No description provided for @gaugeRight.
  ///
  /// In en, this message translates to:
  /// **'R'**
  String get gaugeRight;

  /// No description provided for @schedulerTitle.
  ///
  /// In en, this message translates to:
  /// **'Training Scheduler'**
  String get schedulerTitle;

  /// No description provided for @schedulerAddSchedule.
  ///
  /// In en, this message translates to:
  /// **'Add Schedule'**
  String get schedulerAddSchedule;

  /// No description provided for @schedulerAutoScheduler.
  ///
  /// In en, this message translates to:
  /// **'Auto-Scheduler'**
  String get schedulerAutoScheduler;

  /// No description provided for @schedulerRunsAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Training runs automatically'**
  String get schedulerRunsAutomatically;

  /// No description provided for @schedulerPaused.
  ///
  /// In en, this message translates to:
  /// **'Schedules paused'**
  String get schedulerPaused;

  /// No description provided for @schedulerEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Scheduled Training'**
  String get schedulerEmptyTitle;

  /// No description provided for @schedulerEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Schedule automatic training sessions\nfor your dog at specific times'**
  String get schedulerEmptyBody;

  /// No description provided for @schedulerDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Schedule'**
  String get schedulerDeleteTitle;

  /// No description provided for @schedulerDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this schedule?'**
  String get schedulerDeleteConfirm;

  /// No description provided for @schedulerUnknownDog.
  ///
  /// In en, this message translates to:
  /// **'Unknown Dog'**
  String get schedulerUnknownDog;

  /// No description provided for @schedulerPausedBadge.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get schedulerPausedBadge;

  /// No description provided for @schedulerNextRun.
  ///
  /// In en, this message translates to:
  /// **'Next: {next}'**
  String schedulerNextRun(String next);

  /// No description provided for @scheduleEditSelectDogAndMission.
  ///
  /// In en, this message translates to:
  /// **'Please select a dog and mission'**
  String get scheduleEditSelectDogAndMission;

  /// No description provided for @scheduleEditSelectOneDay.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one day'**
  String get scheduleEditSelectOneDay;

  /// No description provided for @scheduleEditMissionNotFound.
  ///
  /// In en, this message translates to:
  /// **'Selected mission not found'**
  String get scheduleEditMissionNotFound;

  /// No description provided for @scheduleEditUpdated.
  ///
  /// In en, this message translates to:
  /// **'Schedule updated'**
  String get scheduleEditUpdated;

  /// No description provided for @scheduleEditCreated.
  ///
  /// In en, this message translates to:
  /// **'Schedule created'**
  String get scheduleEditCreated;

  /// No description provided for @scheduleEditUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update schedule'**
  String get scheduleEditUpdateFailed;

  /// No description provided for @scheduleEditCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create schedule'**
  String get scheduleEditCreateFailed;

  /// No description provided for @scheduleEditTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Schedule'**
  String get scheduleEditTitleEdit;

  /// No description provided for @scheduleEditTitleNew.
  ///
  /// In en, this message translates to:
  /// **'New Schedule'**
  String get scheduleEditTitleNew;

  /// No description provided for @scheduleEditSectionDog.
  ///
  /// In en, this message translates to:
  /// **'Dog'**
  String get scheduleEditSectionDog;

  /// No description provided for @scheduleEditSelectDog.
  ///
  /// In en, this message translates to:
  /// **'Select a dog'**
  String get scheduleEditSelectDog;

  /// No description provided for @scheduleEditSectionMission.
  ///
  /// In en, this message translates to:
  /// **'Training Mission'**
  String get scheduleEditSectionMission;

  /// No description provided for @scheduleEditSelectMission.
  ///
  /// In en, this message translates to:
  /// **'Select a mission'**
  String get scheduleEditSelectMission;

  /// No description provided for @scheduleEditSectionTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get scheduleEditSectionTime;

  /// No description provided for @scheduleEditSectionRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get scheduleEditSectionRepeat;

  /// No description provided for @scheduleEditOnce.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get scheduleEditOnce;

  /// No description provided for @scheduleEditDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get scheduleEditDaily;

  /// No description provided for @scheduleEditWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get scheduleEditWeekly;

  /// No description provided for @scheduleEditWeekdayLetters.
  ///
  /// In en, this message translates to:
  /// **'S,M,T,W,T,F,S'**
  String get scheduleEditWeekdayLetters;

  /// No description provided for @missionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get missionsTitle;

  /// No description provided for @missionsProgramsHeader.
  ///
  /// In en, this message translates to:
  /// **'Training Programs'**
  String get missionsProgramsHeader;

  /// No description provided for @missionsProgramsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-mission sequences with rest periods'**
  String get missionsProgramsSubtitle;

  /// No description provided for @missionsIndividualHeader.
  ///
  /// In en, this message translates to:
  /// **'Individual Missions'**
  String get missionsIndividualHeader;

  /// No description provided for @missionsIndividualSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Single training sessions'**
  String get missionsIndividualSubtitle;

  /// No description provided for @missionsNoneConfigured.
  ///
  /// In en, this message translates to:
  /// **'No missions configured'**
  String get missionsNoneConfigured;

  /// No description provided for @missionsActiveBadge.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get missionsActiveBadge;

  /// No description provided for @missionsDriveButton.
  ///
  /// In en, this message translates to:
  /// **'DRIVE'**
  String get missionsDriveButton;

  /// No description provided for @missionsStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get missionsStop;

  /// No description provided for @missionsPercentComplete.
  ///
  /// In en, this message translates to:
  /// **'{percent}% complete'**
  String missionsPercentComplete(int percent);

  /// No description provided for @missionsCountChip.
  ///
  /// In en, this message translates to:
  /// **'{count} missions'**
  String missionsCountChip(int count);

  /// No description provided for @missionsRestChip.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s rest'**
  String missionsRestChip(int seconds);

  /// No description provided for @missionsProgramBadge.
  ///
  /// In en, this message translates to:
  /// **'PROGRAM'**
  String get missionsProgramBadge;

  /// No description provided for @missionsRestBreak.
  ///
  /// In en, this message translates to:
  /// **'Rest break: {seconds}s'**
  String missionsRestBreak(int seconds);

  /// No description provided for @missionsMissionOf.
  ///
  /// In en, this message translates to:
  /// **'Mission {current} of {total}'**
  String missionsMissionOf(int current, int total);

  /// No description provided for @missionsCoachMode.
  ///
  /// In en, this message translates to:
  /// **'Coach Mode'**
  String get missionsCoachMode;

  /// No description provided for @missionsCoachWatching.
  ///
  /// In en, this message translates to:
  /// **'Watching for good behaviors...'**
  String get missionsCoachWatching;

  /// No description provided for @missionsCoachSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-reward when your dog performs tricks'**
  String get missionsCoachSubtitle;

  /// No description provided for @missionDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Mission'**
  String get missionDetailTitle;

  /// No description provided for @missionDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Mission not found'**
  String get missionDetailNotFound;

  /// No description provided for @missionDetailSectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Mission Details'**
  String get missionDetailSectionDetails;

  /// No description provided for @missionDetailTargetBehavior.
  ///
  /// In en, this message translates to:
  /// **'Target Behavior'**
  String get missionDetailTargetBehavior;

  /// No description provided for @missionDetailHoldDuration.
  ///
  /// In en, this message translates to:
  /// **'Hold Duration'**
  String get missionDetailHoldDuration;

  /// No description provided for @missionDetailSecondsShort.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String missionDetailSecondsShort(String seconds);

  /// No description provided for @missionDetailCooldown.
  ///
  /// In en, this message translates to:
  /// **'Cooldown'**
  String get missionDetailCooldown;

  /// No description provided for @missionDetailCooldownValue.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s between rewards'**
  String missionDetailCooldownValue(int seconds);

  /// No description provided for @missionDetailDailyLimit.
  ///
  /// In en, this message translates to:
  /// **'Daily Limit'**
  String get missionDetailDailyLimit;

  /// No description provided for @missionDetailTreatsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} treats'**
  String missionDetailTreatsCount(int count);

  /// No description provided for @missionDetailProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get missionDetailProgress;

  /// No description provided for @missionDetailTreatsGiven.
  ///
  /// In en, this message translates to:
  /// **'{given}/{limit} treats given'**
  String missionDetailTreatsGiven(int given, int limit);

  /// No description provided for @missionDetailHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'How It Works'**
  String get missionDetailHowItWorks;

  /// No description provided for @missionDetailBulletWatches.
  ///
  /// In en, this message translates to:
  /// **'WIM-Z watches for the \"{behavior}\" behavior'**
  String missionDetailBulletWatches(String behavior);

  /// No description provided for @missionDetailBulletHold.
  ///
  /// In en, this message translates to:
  /// **'Dog must hold for {seconds} seconds'**
  String missionDetailBulletHold(String seconds);

  /// No description provided for @missionDetailBulletTreat.
  ///
  /// In en, this message translates to:
  /// **'Treat is dispensed automatically on success'**
  String get missionDetailBulletTreat;

  /// No description provided for @missionDetailBulletCooldown.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s cooldown between rewards'**
  String missionDetailBulletCooldown(int seconds);

  /// No description provided for @missionDetailBulletLimit.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} treats per session'**
  String missionDetailBulletLimit(int count);

  /// No description provided for @missionDetailStopMission.
  ///
  /// In en, this message translates to:
  /// **'Stop Mission'**
  String get missionDetailStopMission;

  /// No description provided for @missionDetailRobotNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Robot Not Connected'**
  String get missionDetailRobotNotConnected;

  /// No description provided for @missionDetailAnotherActive.
  ///
  /// In en, this message translates to:
  /// **'Another Mission Active'**
  String get missionDetailAnotherActive;

  /// No description provided for @missionDetailStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting...'**
  String get missionDetailStarting;

  /// No description provided for @missionDetailStartMission.
  ///
  /// In en, this message translates to:
  /// **'Start Mission'**
  String get missionDetailStartMission;

  /// No description provided for @programTitle.
  ///
  /// In en, this message translates to:
  /// **'Program'**
  String get programTitle;

  /// No description provided for @programNotFound.
  ///
  /// In en, this message translates to:
  /// **'Program not found'**
  String get programNotFound;

  /// No description provided for @programStop.
  ///
  /// In en, this message translates to:
  /// **'Stop Program'**
  String get programStop;

  /// No description provided for @programMissionSequence.
  ///
  /// In en, this message translates to:
  /// **'Mission Sequence'**
  String get programMissionSequence;

  /// No description provided for @programRunningBadge.
  ///
  /// In en, this message translates to:
  /// **'RUNNING'**
  String get programRunningBadge;

  /// No description provided for @programRestBreak.
  ///
  /// In en, this message translates to:
  /// **'Rest Break'**
  String get programRestBreak;

  /// No description provided for @programSecondsUntilNext.
  ///
  /// In en, this message translates to:
  /// **'{seconds} seconds until next mission'**
  String programSecondsUntilNext(int seconds);

  /// No description provided for @programPercentThrough.
  ///
  /// In en, this message translates to:
  /// **'{percent}% through program'**
  String programPercentThrough(int percent);

  /// No description provided for @programNowBadge.
  ///
  /// In en, this message translates to:
  /// **'NOW'**
  String get programNowBadge;

  /// No description provided for @programDetails.
  ///
  /// In en, this message translates to:
  /// **'Program Details'**
  String get programDetails;

  /// No description provided for @programTotalMissions.
  ///
  /// In en, this message translates to:
  /// **'Total Missions'**
  String get programTotalMissions;

  /// No description provided for @programRestBetween.
  ///
  /// In en, this message translates to:
  /// **'Rest Between Missions'**
  String get programRestBetween;

  /// No description provided for @programSecondsValue.
  ///
  /// In en, this message translates to:
  /// **'{seconds} seconds'**
  String programSecondsValue(int seconds);

  /// No description provided for @programEstimatedTime.
  ///
  /// In en, this message translates to:
  /// **'Estimated Time'**
  String get programEstimatedTime;

  /// No description provided for @programMinutesRange.
  ///
  /// In en, this message translates to:
  /// **'{min}-{max} minutes'**
  String programMinutesRange(int min, int max);

  /// No description provided for @programStartWith.
  ///
  /// In en, this message translates to:
  /// **'Start with {dog}'**
  String programStartWith(String dog);

  /// No description provided for @programStart.
  ///
  /// In en, this message translates to:
  /// **'Start Program'**
  String get programStart;

  /// No description provided for @programConnectToStart.
  ///
  /// In en, this message translates to:
  /// **'Connect to robot to start'**
  String get programConnectToStart;

  /// No description provided for @programStopCurrentFirst.
  ///
  /// In en, this message translates to:
  /// **'Stop current training first'**
  String get programStopCurrentFirst;

  /// No description provided for @coachCoachingBadge.
  ///
  /// In en, this message translates to:
  /// **'COACHING'**
  String get coachCoachingBadge;

  /// No description provided for @coachStoppedBadge.
  ///
  /// In en, this message translates to:
  /// **'STOPPED'**
  String get coachStoppedBadge;

  /// No description provided for @coachDogDetected.
  ///
  /// In en, this message translates to:
  /// **'Dog Detected'**
  String get coachDogDetected;

  /// No description provided for @coachWhenDogVisible.
  ///
  /// In en, this message translates to:
  /// **'When dog visible:'**
  String get coachWhenDogVisible;

  /// No description provided for @coachSelectDogHint.
  ///
  /// In en, this message translates to:
  /// **'Select a dog or wait for the camera to identify one.'**
  String get coachSelectDogHint;

  /// No description provided for @coachExit.
  ///
  /// In en, this message translates to:
  /// **'Exit Coach Mode'**
  String get coachExit;

  /// No description provided for @coachGoodBang.
  ///
  /// In en, this message translates to:
  /// **'GOOD!'**
  String get coachGoodBang;

  /// No description provided for @coachBehaviorBang.
  ///
  /// In en, this message translates to:
  /// **'{behavior}!'**
  String coachBehaviorBang(String behavior);

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Training History'**
  String get historyTitle;

  /// No description provided for @historyTimeRange.
  ///
  /// In en, this message translates to:
  /// **'Time Range'**
  String get historyTimeRange;

  /// No description provided for @historyLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get historyLast7Days;

  /// No description provided for @historyLast2Weeks.
  ///
  /// In en, this message translates to:
  /// **'Last 2 weeks'**
  String get historyLast2Weeks;

  /// No description provided for @historyLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get historyLastMonth;

  /// No description provided for @historyDogFilter.
  ///
  /// In en, this message translates to:
  /// **'Dog'**
  String get historyDogFilter;

  /// No description provided for @historyAllDogs.
  ///
  /// In en, this message translates to:
  /// **'All Dogs'**
  String get historyAllDogs;

  /// No description provided for @historyStatSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get historyStatSessions;

  /// No description provided for @historyStatCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get historyStatCompleted;

  /// No description provided for @historyStatTreats.
  ///
  /// In en, this message translates to:
  /// **'Treats'**
  String get historyStatTreats;

  /// No description provided for @historyStatSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get historyStatSuccess;

  /// No description provided for @historyInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get historyInProgress;

  /// No description provided for @historyStages.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total} stages'**
  String historyStages(int done, int total);

  /// No description provided for @historyDurationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{n}s'**
  String historyDurationSeconds(int n);

  /// No description provided for @historyDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n}m'**
  String historyDurationMinutes(int n);

  /// No description provided for @historyDurationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{h}h {m}m'**
  String historyDurationHoursMinutes(int h, int m);

  /// No description provided for @historyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No training history'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Complete some training sessions to see your progress'**
  String get historyEmptyBody;

  /// No description provided for @signOutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out? You will need to log in again.'**
  String get signOutConfirmBody;

  /// No description provided for @settingsSectionConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get settingsSectionConnection;

  /// No description provided for @settingsSectionMyRobots.
  ///
  /// In en, this message translates to:
  /// **'My Robots'**
  String get settingsSectionMyRobots;

  /// No description provided for @settingsSectionController.
  ///
  /// In en, this message translates to:
  /// **'Controller'**
  String get settingsSectionController;

  /// No description provided for @settingsSectionRobotStatus.
  ///
  /// In en, this message translates to:
  /// **'Robot Status'**
  String get settingsSectionRobotStatus;

  /// No description provided for @settingsSectionCalibration.
  ///
  /// In en, this message translates to:
  /// **'Calibration'**
  String get settingsSectionCalibration;

  /// No description provided for @settingsSectionCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get settingsSectionCamera;

  /// No description provided for @settingsSectionNightVision.
  ///
  /// In en, this message translates to:
  /// **'Night Vision'**
  String get settingsSectionNightVision;

  /// No description provided for @settingsSectionVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get settingsSectionVideo;

  /// No description provided for @settingsSectionAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get settingsSectionAudio;

  /// No description provided for @settingsSectionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsSectionNotifications;

  /// No description provided for @settingsSectionSilentGuardian.
  ///
  /// In en, this message translates to:
  /// **'Silent Guardian'**
  String get settingsSectionSilentGuardian;

  /// No description provided for @settingsSectionTraining.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get settingsSectionTraining;

  /// No description provided for @settingsSectionDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get settingsSectionDiagnostics;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsGameController.
  ///
  /// In en, this message translates to:
  /// **'Game Controller'**
  String get settingsGameController;

  /// No description provided for @settingsGameControllerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pair a game controller to the robot'**
  String get settingsGameControllerSubtitle;

  /// No description provided for @settingsBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get settingsBattery;

  /// No description provided for @settingsTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get settingsTemperature;

  /// No description provided for @settingsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get settingsNotAvailable;

  /// No description provided for @settingsCurrentMode.
  ///
  /// In en, this message translates to:
  /// **'Current Mode'**
  String get settingsCurrentMode;

  /// No description provided for @settingsTrainingScheduler.
  ///
  /// In en, this message translates to:
  /// **'Training Scheduler'**
  String get settingsTrainingScheduler;

  /// No description provided for @settingsTrainingSchedulerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule automatic training sessions'**
  String get settingsTrainingSchedulerSubtitle;

  /// No description provided for @settingsVoiceCommands.
  ///
  /// In en, this message translates to:
  /// **'Voice Commands'**
  String get settingsVoiceCommands;

  /// No description provided for @settingsVoiceCommandsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Record custom voice commands for your dog'**
  String get settingsVoiceCommandsSubtitle;

  /// No description provided for @settingsTestRecording.
  ///
  /// In en, this message translates to:
  /// **'Test Recording'**
  String get settingsTestRecording;

  /// No description provided for @settingsTestRecordingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Run recording diagnostics'**
  String get settingsTestRecordingSubtitle;

  /// No description provided for @settingsConnectionDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Connection Diagnostics'**
  String get settingsConnectionDiagnostics;

  /// No description provided for @settingsConnectionDiagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'WebRTC signaling trace (video connect)'**
  String get settingsConnectionDiagnosticsSubtitle;

  /// No description provided for @settingsUiPreviews.
  ///
  /// In en, this message translates to:
  /// **'UI Previews'**
  String get settingsUiPreviews;

  /// No description provided for @settingsUiPreviewsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Spec-shaped views on sample data (dev)'**
  String get settingsUiPreviewsSubtitle;

  /// No description provided for @settingsAppName.
  ///
  /// In en, this message translates to:
  /// **'WIM-Z App'**
  String get settingsAppName;

  /// No description provided for @settingsAppVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsAppVersion(String version);

  /// No description provided for @settingsApiVersion.
  ///
  /// In en, this message translates to:
  /// **'API Version'**
  String get settingsApiVersion;

  /// No description provided for @settingsConnectedToRobot.
  ///
  /// In en, this message translates to:
  /// **'Connected to Robot ({ip})'**
  String settingsConnectedToRobot(String ip);

  /// No description provided for @settingsLocalNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Local mode — not connected'**
  String get settingsLocalNotConnected;

  /// No description provided for @settingsDirectViaWifi.
  ///
  /// In en, this message translates to:
  /// **'Direct connection via WIMZ WiFi'**
  String get settingsDirectViaWifi;

  /// No description provided for @settingsConnectedViaCloud.
  ///
  /// In en, this message translates to:
  /// **'Connected via Cloud'**
  String get settingsConnectedViaCloud;

  /// No description provided for @settingsRelayHost.
  ///
  /// In en, this message translates to:
  /// **'Relay: {host}'**
  String settingsRelayHost(String host);

  /// No description provided for @settingsLocalRobotDirect.
  ///
  /// In en, this message translates to:
  /// **'Local Robot · direct connection (192.168.4.1)'**
  String get settingsLocalRobotDirect;

  /// No description provided for @settingsNoRobotsPaired.
  ///
  /// In en, this message translates to:
  /// **'No robots paired — tap to add one'**
  String get settingsNoRobotsPaired;

  /// No description provided for @settingsRobotsPairedActive.
  ///
  /// In en, this message translates to:
  /// **'{name} · {count, plural, =1{1 robot} other{{count} robots}} paired'**
  String settingsRobotsPairedActive(String name, int count);

  /// No description provided for @settingsRobotsPairedSelect.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 robot} other{{count} robots}} paired — tap to select'**
  String settingsRobotsPairedSelect(int count);

  /// No description provided for @settingsManageRobots.
  ///
  /// In en, this message translates to:
  /// **'Manage Robots'**
  String get settingsManageRobots;

  /// No description provided for @settingsOtaUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating to {version}: {state}{pct}'**
  String settingsOtaUpdating(String version, String state, String pct);

  /// No description provided for @settingsOtaUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated to {version} ✓'**
  String settingsOtaUpdated(String version);

  /// No description provided for @settingsOtaRolledBack.
  ///
  /// In en, this message translates to:
  /// **'Update failed — rolled back safely{detail}'**
  String settingsOtaRolledBack(String detail);

  /// No description provided for @settingsOtaFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed{detail}'**
  String settingsOtaFailed(String detail);

  /// No description provided for @settingsOtaNotReported.
  ///
  /// In en, this message translates to:
  /// **'Version not reported — robot updater not installed yet'**
  String get settingsOtaNotReported;

  /// No description provided for @settingsOtaUpToDateNoRelease.
  ///
  /// In en, this message translates to:
  /// **'Up to date — no newer release on server'**
  String get settingsOtaUpToDateNoRelease;

  /// No description provided for @settingsOtaAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available: {version}'**
  String settingsOtaAvailable(String version);

  /// No description provided for @settingsOtaUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get settingsOtaUpToDate;

  /// No description provided for @settingsRobotSoftware.
  ///
  /// In en, this message translates to:
  /// **'Robot Software'**
  String get settingsRobotSoftware;

  /// No description provided for @settingsUpdateCaps.
  ///
  /// In en, this message translates to:
  /// **'UPDATE'**
  String get settingsUpdateCaps;

  /// No description provided for @settingsUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get settingsUpdate;

  /// No description provided for @settingsUpdateRobotSoftware.
  ///
  /// In en, this message translates to:
  /// **'Update Robot Software'**
  String get settingsUpdateRobotSoftware;

  /// No description provided for @settingsUpdateConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Update robot from {from} to {to}?\n\nThe robot must be idle with battery above 30%. It will restart during the update and roll back automatically if anything goes wrong.'**
  String settingsUpdateConfirmBody(String from, String to);

  /// No description provided for @settingsTreats.
  ///
  /// In en, this message translates to:
  /// **'Treats'**
  String get settingsTreats;

  /// No description provided for @settingsTreatsOfCapacity.
  ///
  /// In en, this message translates to:
  /// **'{remaining} of {capacity}'**
  String settingsTreatsOfCapacity(int remaining, int capacity);

  /// No description provided for @settingsTreatsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty — refill needed'**
  String get settingsTreatsEmpty;

  /// No description provided for @settingsTreatsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{remaining} remaining'**
  String settingsTreatsRemaining(int remaining);

  /// No description provided for @settingsTreatsRemainingLow.
  ///
  /// In en, this message translates to:
  /// **'{remaining} remaining — running low'**
  String settingsTreatsRemainingLow(int remaining);

  /// No description provided for @settingsDailyTreatLimit.
  ///
  /// In en, this message translates to:
  /// **'Daily Treat Limit'**
  String get settingsDailyTreatLimit;

  /// No description provided for @settingsDailyLimitMax.
  ///
  /// In en, this message translates to:
  /// **'Max {count} auto-treats per day'**
  String settingsDailyLimitMax(int count);

  /// No description provided for @settingsDailyLimitNone.
  ///
  /// In en, this message translates to:
  /// **'No daily limit — unlimited auto-treats'**
  String get settingsDailyLimitNone;

  /// No description provided for @settingsCameraTrackDog.
  ///
  /// In en, this message translates to:
  /// **'Camera Track Dog'**
  String get settingsCameraTrackDog;

  /// No description provided for @settingsCameraTrackOn.
  ///
  /// In en, this message translates to:
  /// **'Camera follows dog during coach/mission mode'**
  String get settingsCameraTrackOn;

  /// No description provided for @settingsCameraTrackOff.
  ///
  /// In en, this message translates to:
  /// **'Camera stays centered'**
  String get settingsCameraTrackOff;

  /// No description provided for @settingsVideoQuality.
  ///
  /// In en, this message translates to:
  /// **'Video Quality'**
  String get settingsVideoQuality;

  /// No description provided for @settingsQualityAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get settingsQualityAuto;

  /// No description provided for @settingsQualityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get settingsQualityLow;

  /// No description provided for @settingsQualityMed.
  ///
  /// In en, this message translates to:
  /// **'Med'**
  String get settingsQualityMed;

  /// No description provided for @settingsQualityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get settingsQualityHigh;

  /// No description provided for @settingsStreamingNotConnected.
  ///
  /// In en, this message translates to:
  /// **'not connected'**
  String get settingsStreamingNotConnected;

  /// No description provided for @settingsCurrentlyStreaming.
  ///
  /// In en, this message translates to:
  /// **'Currently streaming: {label}'**
  String settingsCurrentlyStreaming(String label);

  /// No description provided for @settingsBackgroundAudio.
  ///
  /// In en, this message translates to:
  /// **'Background Audio'**
  String get settingsBackgroundAudio;

  /// No description provided for @settingsBackgroundAudioOn.
  ///
  /// In en, this message translates to:
  /// **'Keep listening when app is in background'**
  String get settingsBackgroundAudioOn;

  /// No description provided for @settingsBackgroundAudioOff.
  ///
  /// In en, this message translates to:
  /// **'Audio stops when app is backgrounded'**
  String get settingsBackgroundAudioOff;

  /// No description provided for @settingsActivityNotifications.
  ///
  /// In en, this message translates to:
  /// **'Activity Notifications'**
  String get settingsActivityNotifications;

  /// No description provided for @settingsNotificationsOn.
  ///
  /// In en, this message translates to:
  /// **'Show alerts on lock screen & Apple Watch'**
  String get settingsNotificationsOn;

  /// No description provided for @settingsNotificationsOff.
  ///
  /// In en, this message translates to:
  /// **'Notifications disabled'**
  String get settingsNotificationsOff;

  /// No description provided for @settingsPerEventPrefs.
  ///
  /// In en, this message translates to:
  /// **'Per-event preferences'**
  String get settingsPerEventPrefs;

  /// No description provided for @settingsPerEventPrefsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose which events push to the lock screen vs in-app only'**
  String get settingsPerEventPrefsSubtitle;

  /// No description provided for @settingsMotorTrim.
  ///
  /// In en, this message translates to:
  /// **'Motor Trim (Right)'**
  String get settingsMotorTrim;

  /// No description provided for @settingsMotorTrimNone.
  ///
  /// In en, this message translates to:
  /// **'No adjustment'**
  String get settingsMotorTrimNone;

  /// No description provided for @settingsMotorTrimSlowing.
  ///
  /// In en, this message translates to:
  /// **'Slowing right motor by {pct}%'**
  String settingsMotorTrimSlowing(int pct);

  /// No description provided for @settingsMotorTrimSpeeding.
  ///
  /// In en, this message translates to:
  /// **'Speeding right motor by {pct}%'**
  String settingsMotorTrimSpeeding(int pct);

  /// No description provided for @settingsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsReset;

  /// No description provided for @settingsMotorTrimHint.
  ///
  /// In en, this message translates to:
  /// **'If robot drifts LEFT, increase trim. If it drifts RIGHT, decrease trim.'**
  String get settingsMotorTrimHint;

  /// No description provided for @settingsWifiHelp.
  ///
  /// In en, this message translates to:
  /// **'WiFi Setup Help'**
  String get settingsWifiHelp;

  /// No description provided for @settingsWifiHelpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How to connect your robot'**
  String get settingsWifiHelpSubtitle;

  /// No description provided for @settingsWifiHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Connecting Your WIM-Z to WiFi'**
  String get settingsWifiHelpTitle;

  /// No description provided for @settingsWifiStep1.
  ///
  /// In en, this message translates to:
  /// **'Power on your WIM-Z robot'**
  String get settingsWifiStep1;

  /// No description provided for @settingsWifiStep2.
  ///
  /// In en, this message translates to:
  /// **'If not connected to WiFi, it creates a hotspot called \"WIMZ-XXXX\"'**
  String get settingsWifiStep2;

  /// No description provided for @settingsWifiStep3.
  ///
  /// In en, this message translates to:
  /// **'On your phone, go to Settings → WiFi'**
  String get settingsWifiStep3;

  /// No description provided for @settingsWifiStep4.
  ///
  /// In en, this message translates to:
  /// **'Connect to \"WIMZ-XXXX\"'**
  String get settingsWifiStep4;

  /// No description provided for @settingsWifiStep4Detail.
  ///
  /// In en, this message translates to:
  /// **'Password: wimzsetup'**
  String get settingsWifiStep4Detail;

  /// No description provided for @settingsWifiStep5.
  ///
  /// In en, this message translates to:
  /// **'Open your browser and go to:'**
  String get settingsWifiStep5;

  /// No description provided for @settingsWifiStep6.
  ///
  /// In en, this message translates to:
  /// **'Select your home WiFi network and enter the password'**
  String get settingsWifiStep6;

  /// No description provided for @settingsWifiStep7.
  ///
  /// In en, this message translates to:
  /// **'Robot will reboot and connect to your network'**
  String get settingsWifiStep7;

  /// No description provided for @settingsWifiStep8.
  ///
  /// In en, this message translates to:
  /// **'Return to this app and pair with your robot'**
  String get settingsWifiStep8;

  /// No description provided for @settingsLedGuide.
  ///
  /// In en, this message translates to:
  /// **'LED Status Guide'**
  String get settingsLedGuide;

  /// No description provided for @settingsLedSpinningCyan.
  ///
  /// In en, this message translates to:
  /// **'Spinning cyan'**
  String get settingsLedSpinningCyan;

  /// No description provided for @settingsLedSearchingWifi.
  ///
  /// In en, this message translates to:
  /// **'Searching for WiFi'**
  String get settingsLedSearchingWifi;

  /// No description provided for @settingsLedPulsingBlue.
  ///
  /// In en, this message translates to:
  /// **'Pulsing blue'**
  String get settingsLedPulsingBlue;

  /// No description provided for @settingsLedSetupMode.
  ///
  /// In en, this message translates to:
  /// **'Setup mode (connect to WIMZ hotspot)'**
  String get settingsLedSetupMode;

  /// No description provided for @settingsLedSolidGreen.
  ///
  /// In en, this message translates to:
  /// **'Solid green'**
  String get settingsLedSolidGreen;

  /// No description provided for @settingsLedConnectedWifi.
  ///
  /// In en, this message translates to:
  /// **'Connected to WiFi'**
  String get settingsLedConnectedWifi;

  /// No description provided for @settingsLedPulsingRed.
  ///
  /// In en, this message translates to:
  /// **'Pulsing red'**
  String get settingsLedPulsingRed;

  /// No description provided for @settingsRobotNetwork.
  ///
  /// In en, this message translates to:
  /// **'Robot Network'**
  String get settingsRobotNetwork;

  /// No description provided for @settingsNetHotspot.
  ///
  /// In en, this message translates to:
  /// **'Hotspot (AP)'**
  String get settingsNetHotspot;

  /// No description provided for @settingsNetWifi.
  ///
  /// In en, this message translates to:
  /// **'WiFi'**
  String get settingsNetWifi;

  /// No description provided for @settingsNetMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get settingsNetMode;

  /// No description provided for @settingsNetNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get settingsNetNetwork;

  /// No description provided for @settingsNetIp.
  ///
  /// In en, this message translates to:
  /// **'IP'**
  String get settingsNetIp;

  /// No description provided for @settingsConfigureRobotWifi.
  ///
  /// In en, this message translates to:
  /// **'Configure Robot WiFi'**
  String get settingsConfigureRobotWifi;

  /// No description provided for @settingsWifiScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed'**
  String get settingsWifiScanFailed;

  /// No description provided for @settingsWifiScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning for WiFi networks...'**
  String get settingsWifiScanning;

  /// No description provided for @settingsWifiNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No WiFi networks found'**
  String get settingsWifiNoneFound;

  /// No description provided for @settingsWifiScanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan Again'**
  String get settingsWifiScanAgain;

  /// No description provided for @settingsWifiPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get settingsWifiPassword;

  /// No description provided for @settingsWifiPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter WiFi password'**
  String get settingsWifiPasswordHint;

  /// No description provided for @settingsWifiConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get settingsWifiConnect;

  /// No description provided for @settingsTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get settingsTryAgain;

  /// No description provided for @settingsWifiRobotConnecting.
  ///
  /// In en, this message translates to:
  /// **'Robot is connecting to WiFi...'**
  String get settingsWifiRobotConnecting;

  /// No description provided for @settingsWifiMayTakeMoment.
  ///
  /// In en, this message translates to:
  /// **'This may take a moment.'**
  String get settingsWifiMayTakeMoment;

  /// No description provided for @settingsWifiRobotSwitching.
  ///
  /// In en, this message translates to:
  /// **'Robot is switching to WiFi...'**
  String get settingsWifiRobotSwitching;

  /// No description provided for @settingsWifiHotspotShutdown.
  ///
  /// In en, this message translates to:
  /// **'The local hotspot will shut down.\nYour connection may drop shortly.'**
  String get settingsWifiHotspotShutdown;

  /// No description provided for @settingsWifiCommandSent.
  ///
  /// In en, this message translates to:
  /// **'WiFi command sent!'**
  String get settingsWifiCommandSent;

  /// No description provided for @settingsWifiCommandSentBody.
  ///
  /// In en, this message translates to:
  /// **'Robot is switching to WiFi. Connect your phone to the same WiFi network, then disable Local Mode to use relay connection.'**
  String get settingsWifiCommandSentBody;

  /// No description provided for @settingsGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get settingsGotIt;

  /// No description provided for @settingsSignalExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get settingsSignalExcellent;

  /// No description provided for @settingsSignalGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get settingsSignalGood;

  /// No description provided for @settingsSignalFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get settingsSignalFair;

  /// No description provided for @settingsSignalWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get settingsSignalWeak;

  /// No description provided for @settingsDiagRunning.
  ///
  /// In en, this message translates to:
  /// **'Running diagnostics...'**
  String get settingsDiagRunning;

  /// No description provided for @settingsDiagError.
  ///
  /// In en, this message translates to:
  /// **'DIAGNOSTICS ERROR: {error}\n\nStack: {stack}'**
  String settingsDiagError(String error, String stack);

  /// No description provided for @settingsRecordingDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Recording Diagnostics'**
  String get settingsRecordingDiagnostics;

  /// No description provided for @settingsRunningTests.
  ///
  /// In en, this message translates to:
  /// **'Running tests...'**
  String get settingsRunningTests;

  /// No description provided for @settingsRunAgain.
  ///
  /// In en, this message translates to:
  /// **'Run Again'**
  String get settingsRunAgain;

  /// No description provided for @notifPrefsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Preferences'**
  String get notifPrefsTitle;

  /// No description provided for @notifPrefsResetDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get notifPrefsResetDefaults;

  /// No description provided for @notifPrefsEnableLockScreen.
  ///
  /// In en, this message translates to:
  /// **'Enable lock-screen notifications'**
  String get notifPrefsEnableLockScreen;

  /// No description provided for @notifPrefsMasterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Master switch. When off, nothing pushes to the lock screen or Apple Watch — events still appear in the in-app feed.'**
  String get notifPrefsMasterSubtitle;

  /// No description provided for @notifPrefsPerEventType.
  ///
  /// In en, this message translates to:
  /// **'Per event type'**
  String get notifPrefsPerEventType;

  /// No description provided for @notifPrefsLegend.
  ///
  /// In en, this message translates to:
  /// **'Off — never recorded.\nIn-app — appears in the activity feed only.\nIn-app + Push — also wakes lock screen and Apple Watch.'**
  String get notifPrefsLegend;

  /// No description provided for @notifPrefsBarking.
  ///
  /// In en, this message translates to:
  /// **'Barking'**
  String get notifPrefsBarking;

  /// No description provided for @notifPrefsSitDetected.
  ///
  /// In en, this message translates to:
  /// **'Sit detected'**
  String get notifPrefsSitDetected;

  /// No description provided for @notifPrefsLayDownDetected.
  ///
  /// In en, this message translates to:
  /// **'Lay down detected'**
  String get notifPrefsLayDownDetected;

  /// No description provided for @notifPrefsComeStandDetected.
  ///
  /// In en, this message translates to:
  /// **'Come / stand detected'**
  String get notifPrefsComeStandDetected;

  /// No description provided for @notifPrefsTreatDispensed.
  ///
  /// In en, this message translates to:
  /// **'Treat dispensed'**
  String get notifPrefsTreatDispensed;

  /// No description provided for @notifPrefsMissionStarted.
  ///
  /// In en, this message translates to:
  /// **'Mission started'**
  String get notifPrefsMissionStarted;

  /// No description provided for @notifPrefsMissionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mission completed'**
  String get notifPrefsMissionCompleted;

  /// No description provided for @notifPrefsMissionFailed.
  ///
  /// In en, this message translates to:
  /// **'Mission failed'**
  String get notifPrefsMissionFailed;

  /// No description provided for @notifPrefsLowBattery.
  ///
  /// In en, this message translates to:
  /// **'Low battery'**
  String get notifPrefsLowBattery;

  /// No description provided for @notifPrefsGuardianAlert.
  ///
  /// In en, this message translates to:
  /// **'Guardian alert'**
  String get notifPrefsGuardianAlert;

  /// No description provided for @notifPrefsHappyDog.
  ///
  /// In en, this message translates to:
  /// **'Happy dog'**
  String get notifPrefsHappyDog;

  /// No description provided for @notifPrefsRobotConnected.
  ///
  /// In en, this message translates to:
  /// **'Robot connected'**
  String get notifPrefsRobotConnected;

  /// No description provided for @notifPrefsRobotDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Robot disconnected'**
  String get notifPrefsRobotDisconnected;

  /// No description provided for @notifPrefsCoachReward.
  ///
  /// In en, this message translates to:
  /// **'Coach reward'**
  String get notifPrefsCoachReward;

  /// No description provided for @notifPrefsPanicAlert.
  ///
  /// In en, this message translates to:
  /// **'Panic alert'**
  String get notifPrefsPanicAlert;

  /// No description provided for @notifPrefsSgSummary.
  ///
  /// In en, this message translates to:
  /// **'Guardian session summary'**
  String get notifPrefsSgSummary;

  /// No description provided for @notifPrefsInApp.
  ///
  /// In en, this message translates to:
  /// **'In-app'**
  String get notifPrefsInApp;

  /// No description provided for @notifPrefsPlusPush.
  ///
  /// In en, this message translates to:
  /// **'+ Push'**
  String get notifPrefsPlusPush;

  /// No description provided for @controllerPairingTitle.
  ///
  /// In en, this message translates to:
  /// **'Game Controller'**
  String get controllerPairingTitle;

  /// No description provided for @controllerPairingRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get controllerPairingRefresh;

  /// No description provided for @controllerPairingRobotNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Robot not connected'**
  String get controllerPairingRobotNotConnected;

  /// No description provided for @controllerPairingRobotNotConnectedBody.
  ///
  /// In en, this message translates to:
  /// **'Connect to your robot first, then come back to pair a controller.'**
  String get controllerPairingRobotNotConnectedBody;

  /// No description provided for @controllerPairingChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking robot…'**
  String get controllerPairingChecking;

  /// No description provided for @controllerPairingCheckingBody.
  ///
  /// In en, this message translates to:
  /// **'Asking the robot about its controllers.'**
  String get controllerPairingCheckingBody;

  /// No description provided for @controllerPairingNoResponse.
  ///
  /// In en, this message translates to:
  /// **'No response from robot'**
  String get controllerPairingNoResponse;

  /// No description provided for @controllerPairingNoResponseBody.
  ///
  /// In en, this message translates to:
  /// **'The robot didn\'t answer the controller check. It may still be starting up, or its firmware may not support controller pairing yet. Try again in a moment.'**
  String get controllerPairingNoResponseBody;

  /// No description provided for @controllerPairingSavedControllers.
  ///
  /// In en, this message translates to:
  /// **'Saved Controllers'**
  String get controllerPairingSavedControllers;

  /// No description provided for @controllerPairingNoSaved.
  ///
  /// In en, this message translates to:
  /// **'No saved controllers yet. Scan and pair one below — then trust it so the robot reconnects it automatically.'**
  String get controllerPairingNoSaved;

  /// No description provided for @controllerPairingAddController.
  ///
  /// In en, this message translates to:
  /// **'Add a Controller'**
  String get controllerPairingAddController;

  /// No description provided for @controllerPairingForgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Forget controller?'**
  String get controllerPairingForgetTitle;

  /// No description provided for @controllerPairingForgetBody.
  ///
  /// In en, this message translates to:
  /// **'The robot will unpair \"{name}\" and stop auto-reconnecting it. You can pair it again later.'**
  String controllerPairingForgetBody(String name);

  /// No description provided for @controllerPairingForget.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get controllerPairingForget;

  /// No description provided for @controllerPairingController.
  ///
  /// In en, this message translates to:
  /// **'Controller'**
  String get controllerPairingController;

  /// No description provided for @controllerPairingNoneConnected.
  ///
  /// In en, this message translates to:
  /// **'No controller connected'**
  String get controllerPairingNoneConnected;

  /// No description provided for @controllerPairingTrusted.
  ///
  /// In en, this message translates to:
  /// **'Trusted'**
  String get controllerPairingTrusted;

  /// No description provided for @controllerPairingSavedNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Saved · not connected'**
  String get controllerPairingSavedNotConnected;

  /// No description provided for @controllerPairingReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get controllerPairingReconnect;

  /// No description provided for @controllerPairingAutoReconnect.
  ///
  /// In en, this message translates to:
  /// **'Auto-reconnect (trusted)'**
  String get controllerPairingAutoReconnect;

  /// No description provided for @controllerPairingPair.
  ///
  /// In en, this message translates to:
  /// **'Pair'**
  String get controllerPairingPair;

  /// No description provided for @controllerPairingScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning for controllers…'**
  String get controllerPairingScanning;

  /// No description provided for @controllerPairingScan.
  ///
  /// In en, this message translates to:
  /// **'Scan for controllers'**
  String get controllerPairingScan;

  /// No description provided for @controllerPairingScanningHint.
  ///
  /// In en, this message translates to:
  /// **'Put your controller in pairing mode'**
  String get controllerPairingScanningHint;

  /// No description provided for @controllerPairingScanHint.
  ///
  /// In en, this message translates to:
  /// **'Robot will look for nearby controllers'**
  String get controllerPairingScanHint;

  /// No description provided for @devicePairingEnterId.
  ///
  /// In en, this message translates to:
  /// **'Please enter a device ID'**
  String get devicePairingEnterId;

  /// No description provided for @devicePairingInvalidId.
  ///
  /// In en, this message translates to:
  /// **'Device ID must be 3–50 characters: letters, numbers, _ or -'**
  String get devicePairingInvalidId;

  /// No description provided for @devicePairingPaired.
  ///
  /// In en, this message translates to:
  /// **'Successfully paired {deviceId}'**
  String devicePairingPaired(String deviceId);

  /// No description provided for @devicePairingUnpairTitle.
  ///
  /// In en, this message translates to:
  /// **'Unpair Device'**
  String get devicePairingUnpairTitle;

  /// No description provided for @devicePairingUnpairBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to unpair {deviceId}?'**
  String devicePairingUnpairBody(String deviceId);

  /// No description provided for @devicePairingUnpair.
  ///
  /// In en, this message translates to:
  /// **'Unpair'**
  String get devicePairingUnpair;

  /// No description provided for @devicePairingUnpaired.
  ///
  /// In en, this message translates to:
  /// **'Unpaired {deviceId}'**
  String devicePairingUnpaired(String deviceId);

  /// No description provided for @devicePairingNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Robot Not Found'**
  String get devicePairingNotFoundTitle;

  /// No description provided for @devicePairingNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'The relay has no record of \"{deviceId}\". This entry is orphaned and can\'t be cleanly removed. Hide it from your list anyway?'**
  String devicePairingNotFoundBody(String deviceId);

  /// No description provided for @devicePairingKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get devicePairingKeep;

  /// No description provided for @devicePairingHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get devicePairingHide;

  /// No description provided for @devicePairingHidden.
  ///
  /// In en, this message translates to:
  /// **'Hid {deviceId} from your list'**
  String devicePairingHidden(String deviceId);

  /// No description provided for @devicePairingConnectingTo.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {label}…'**
  String devicePairingConnectingTo(String label);

  /// No description provided for @devicePairingTitle.
  ///
  /// In en, this message translates to:
  /// **'My Robots'**
  String get devicePairingTitle;

  /// No description provided for @devicePairingPairNew.
  ///
  /// In en, this message translates to:
  /// **'PAIR NEW DEVICE'**
  String get devicePairingPairNew;

  /// No description provided for @devicePairingIdHint.
  ///
  /// In en, this message translates to:
  /// **'Enter device ID (e.g., wimz_robot_01)'**
  String get devicePairingIdHint;

  /// No description provided for @devicePairingPair.
  ///
  /// In en, this message translates to:
  /// **'Pair'**
  String get devicePairingPair;

  /// No description provided for @devicePairingNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No Paired Devices'**
  String get devicePairingNoDevices;

  /// No description provided for @devicePairingNoDevicesBody.
  ///
  /// In en, this message translates to:
  /// **'Enter a device ID above to pair your WIM-Z'**
  String get devicePairingNoDevicesBody;

  /// No description provided for @devicePairingActive.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get devicePairingActive;

  /// No description provided for @devicePairingOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get devicePairingOnline;

  /// No description provided for @devicePairingOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get devicePairingOffline;

  /// No description provided for @devicePairingLastSeen.
  ///
  /// In en, this message translates to:
  /// **' - Last seen {when}'**
  String devicePairingLastSeen(String when);

  /// No description provided for @devicePairingUnpairTooltip.
  ///
  /// In en, this message translates to:
  /// **'Unpair device'**
  String get devicePairingUnpairTooltip;

  /// No description provided for @devicePairingJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get devicePairingJustNow;

  /// No description provided for @devicePairingMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}m ago'**
  String devicePairingMinutesAgo(int n);

  /// No description provided for @devicePairingHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}h ago'**
  String devicePairingHoursAgo(int n);

  /// No description provided for @devicePairingDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}d ago'**
  String devicePairingDaysAgo(int n);

  /// No description provided for @connDiagCopied.
  ///
  /// In en, this message translates to:
  /// **'Trace copied to clipboard'**
  String get connDiagCopied;

  /// No description provided for @connDiagShareSubject.
  ///
  /// In en, this message translates to:
  /// **'WIM-Z connection trace'**
  String get connDiagShareSubject;

  /// No description provided for @connDiagCleared.
  ///
  /// In en, this message translates to:
  /// **'Trace cleared'**
  String get connDiagCleared;

  /// No description provided for @connDiagNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected — connect to the robot first'**
  String get connDiagNotConnected;

  /// No description provided for @connDiagLedAcked.
  ///
  /// In en, this message translates to:
  /// **'LED acknowledged in {ms}ms — if nothing lit, the fault is on the robot'**
  String connDiagLedAcked(int ms);

  /// No description provided for @connDiagLedTimeout.
  ///
  /// In en, this message translates to:
  /// **'LED sent but not acknowledged in 3s — command path broken'**
  String get connDiagLedTimeout;

  /// No description provided for @connDiagLedFailed.
  ///
  /// In en, this message translates to:
  /// **'LED ping failed: {error}'**
  String connDiagLedFailed(String error);

  /// No description provided for @connDiagTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection Diagnostics'**
  String get connDiagTitle;

  /// No description provided for @connDiagLedPing.
  ///
  /// In en, this message translates to:
  /// **'LED ping'**
  String get connDiagLedPing;

  /// No description provided for @connDiagCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get connDiagCopy;

  /// No description provided for @connDiagShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get connDiagShare;

  /// No description provided for @connDiagClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get connDiagClear;

  /// No description provided for @connDiagHeader.
  ///
  /// In en, this message translates to:
  /// **'WebRTC signaling trace — {count, plural, =1{1 event} other{{count} events}} captured.\nReproduce the slow video, then Share this trace.'**
  String connDiagHeader(int count);

  /// No description provided for @connDiagEmpty.
  ///
  /// In en, this message translates to:
  /// **'No events captured yet.\n\nLog in and open the video feed, then return here.'**
  String get connDiagEmpty;

  /// No description provided for @nightVisionTitle.
  ///
  /// In en, this message translates to:
  /// **'Night Vision'**
  String get nightVisionTitle;

  /// No description provided for @nightVisionWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for robot…'**
  String get nightVisionWaiting;

  /// No description provided for @nightVisionNightMode.
  ///
  /// In en, this message translates to:
  /// **'Night vision'**
  String get nightVisionNightMode;

  /// No description provided for @nightVisionDayMode.
  ///
  /// In en, this message translates to:
  /// **'Day mode'**
  String get nightVisionDayMode;

  /// No description provided for @nightVisionStaleTooltip.
  ///
  /// In en, this message translates to:
  /// **'No update from robot in 90+ seconds'**
  String get nightVisionStaleTooltip;

  /// No description provided for @nightVisionAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get nightVisionAuto;

  /// No description provided for @nightVisionDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get nightVisionDay;

  /// No description provided for @nightVisionNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get nightVisionNight;

  /// No description provided for @nightVisionAutoHint.
  ///
  /// In en, this message translates to:
  /// **'Switches automatically based on lighting.'**
  String get nightVisionAutoHint;

  /// No description provided for @nightVisionOverrideHint.
  ///
  /// In en, this message translates to:
  /// **'Manual override active. Tap Auto to resume automatic detection.'**
  String get nightVisionOverrideHint;

  /// No description provided for @nightVisionOfflineHint.
  ///
  /// In en, this message translates to:
  /// **'Robot offline — change will apply when reconnected.'**
  String get nightVisionOfflineHint;

  /// No description provided for @nightVisionLighting.
  ///
  /// In en, this message translates to:
  /// **'Lighting: {label}'**
  String nightVisionLighting(String label);

  /// No description provided for @nightVisionLux.
  ///
  /// In en, this message translates to:
  /// **'{lux} lux — {label}'**
  String nightVisionLux(String lux, String label);

  /// No description provided for @nightVisionModeWordNight.
  ///
  /// In en, this message translates to:
  /// **'night vision'**
  String get nightVisionModeWordNight;

  /// No description provided for @nightVisionModeWordDay.
  ///
  /// In en, this message translates to:
  /// **'day mode'**
  String get nightVisionModeWordDay;

  /// No description provided for @nightVisionSwitchedSecondsAgo.
  ///
  /// In en, this message translates to:
  /// **'Switched to {mode} {n}s ago'**
  String nightVisionSwitchedSecondsAgo(String mode, int n);

  /// No description provided for @nightVisionSwitchedMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'Switched to {mode} {n}m ago'**
  String nightVisionSwitchedMinutesAgo(String mode, int n);

  /// No description provided for @nightVisionSwitchedHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'Switched to {mode} {n}h ago'**
  String nightVisionSwitchedHoursAgo(String mode, int n);

  /// No description provided for @nightVisionSwitchedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'Switched to {mode} {n}d ago'**
  String nightVisionSwitchedDaysAgo(String mode, int n);

  /// No description provided for @nightVisionBadgeNight.
  ///
  /// In en, this message translates to:
  /// **'IR night view'**
  String get nightVisionBadgeNight;

  /// No description provided for @nightVisionBadgeDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get nightVisionBadgeDay;

  /// No description provided for @sgError.
  ///
  /// In en, this message translates to:
  /// **'Silent Guardian: {error}'**
  String sgError(String error);

  /// No description provided for @sgInterventionLevel.
  ///
  /// In en, this message translates to:
  /// **'Intervention level'**
  String get sgInterventionLevel;

  /// No description provided for @sgInterventionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How fast the robot jumps to calming music for sustained barking.'**
  String get sgInterventionSubtitle;

  /// No description provided for @sgBpm.
  ///
  /// In en, this message translates to:
  /// **'{bpm} BPM'**
  String sgBpm(int bpm);

  /// No description provided for @sgAggressive.
  ///
  /// In en, this message translates to:
  /// **'Aggressive'**
  String get sgAggressive;

  /// No description provided for @sgTolerant.
  ///
  /// In en, this message translates to:
  /// **'Tolerant'**
  String get sgTolerant;

  /// No description provided for @sgHelperOff.
  ///
  /// In en, this message translates to:
  /// **'Disabled — Silent Guardian climbs the normal L1→L4 ladder only.'**
  String get sgHelperOff;

  /// No description provided for @sgHelperLow.
  ///
  /// In en, this message translates to:
  /// **'Even modest sustained barking will jump straight to calming music.'**
  String get sgHelperLow;

  /// No description provided for @sgHelperMid.
  ///
  /// In en, this message translates to:
  /// **'A typical noisy outburst will trigger calming music.'**
  String get sgHelperMid;

  /// No description provided for @sgHelperHigh.
  ///
  /// In en, this message translates to:
  /// **'Only extreme nonstop barking will trigger calming music.'**
  String get sgHelperHigh;

  /// No description provided for @sgSessionSummary.
  ///
  /// In en, this message translates to:
  /// **'Session Summary'**
  String get sgSessionSummary;

  /// No description provided for @sgTapRefresh.
  ///
  /// In en, this message translates to:
  /// **'Tap refresh for a live status report'**
  String get sgTapRefresh;

  /// No description provided for @sgStatBarks.
  ///
  /// In en, this message translates to:
  /// **'Barks'**
  String get sgStatBarks;

  /// No description provided for @sgStatTreats.
  ///
  /// In en, this message translates to:
  /// **'Treats'**
  String get sgStatTreats;

  /// No description provided for @sgStatInterventions.
  ///
  /// In en, this message translates to:
  /// **'Interventions'**
  String get sgStatInterventions;

  /// No description provided for @sgStatLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get sgStatLevel;

  /// No description provided for @sgStatTrend.
  ///
  /// In en, this message translates to:
  /// **'Trend'**
  String get sgStatTrend;

  /// No description provided for @sgBarkTimeline.
  ///
  /// In en, this message translates to:
  /// **'BARK TIMELINE'**
  String get sgBarkTimeline;

  /// No description provided for @sgRateLine.
  ///
  /// In en, this message translates to:
  /// **'now {recent}/min · session {session}/min'**
  String sgRateLine(String recent, String session);

  /// No description provided for @sgPanicActive.
  ///
  /// In en, this message translates to:
  /// **'PANIC ACTIVE'**
  String get sgPanicActive;

  /// No description provided for @sgPanicEpisodes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 panic episode} other{{count} panic episodes}}'**
  String sgPanicEpisodes(int count);

  /// No description provided for @sgAggressiveBehavior.
  ///
  /// In en, this message translates to:
  /// **'Aggressive behavior'**
  String get sgAggressiveBehavior;

  /// No description provided for @dogProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Dog Profile'**
  String get dogProfileTitle;

  /// No description provided for @dogProfileNotFound.
  ///
  /// In en, this message translates to:
  /// **'No dog profile found'**
  String get dogProfileNotFound;

  /// No description provided for @dogProfileEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit dog'**
  String get dogProfileEditTooltip;

  /// No description provided for @dogProfileMissionStarted.
  ///
  /// In en, this message translates to:
  /// **'Mission started'**
  String get dogProfileMissionStarted;

  /// No description provided for @dogProfileMissionActive.
  ///
  /// In en, this message translates to:
  /// **'MISSION ACTIVE'**
  String get dogProfileMissionActive;

  /// No description provided for @dogProfileLaunchLastMission.
  ///
  /// In en, this message translates to:
  /// **'LAUNCH LAST MISSION'**
  String get dogProfileLaunchLastMission;

  /// No description provided for @dogProfileStartAMission.
  ///
  /// In en, this message translates to:
  /// **'START A MISSION'**
  String get dogProfileStartAMission;

  /// No description provided for @dogProfileTodaySummary.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Summary'**
  String get dogProfileTodaySummary;

  /// No description provided for @dogProfileStatTreats.
  ///
  /// In en, this message translates to:
  /// **'Treats'**
  String get dogProfileStatTreats;

  /// No description provided for @dogProfileStatSits.
  ///
  /// In en, this message translates to:
  /// **'Sits'**
  String get dogProfileStatSits;

  /// No description provided for @dogProfileStatBarks.
  ///
  /// In en, this message translates to:
  /// **'Barks'**
  String get dogProfileStatBarks;

  /// No description provided for @dogProfileStatGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get dogProfileStatGoal;

  /// No description provided for @dogProfileMetrics.
  ///
  /// In en, this message translates to:
  /// **'Metrics'**
  String get dogProfileMetrics;

  /// No description provided for @dogProfileRangeDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get dogProfileRangeDay;

  /// No description provided for @dogProfileRangeWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get dogProfileRangeWeek;

  /// No description provided for @dogProfileRangeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get dogProfileRangeAll;

  /// No description provided for @dogProfileStatDetections.
  ///
  /// In en, this message translates to:
  /// **'Detections'**
  String get dogProfileStatDetections;

  /// No description provided for @dogProfileStatMissions.
  ///
  /// In en, this message translates to:
  /// **'Missions'**
  String get dogProfileStatMissions;

  /// No description provided for @dogProfileStatSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get dogProfileStatSuccess;

  /// No description provided for @dogProfileStatActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get dogProfileStatActive;

  /// No description provided for @dogProfileStatCoach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get dogProfileStatCoach;

  /// No description provided for @dogProfileActiveMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String dogProfileActiveMinutes(int minutes);

  /// No description provided for @dogProfileViewDashboard.
  ///
  /// In en, this message translates to:
  /// **'View Dashboard'**
  String get dogProfileViewDashboard;

  /// No description provided for @dogProfileQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get dogProfileQuickActions;

  /// No description provided for @dogProfileActionVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get dogProfileActionVoice;

  /// No description provided for @dogProfileActionStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get dogProfileActionStats;

  /// No description provided for @dogProfileMetricsHint.
  ///
  /// In en, this message translates to:
  /// **'Metrics are shown above — use Day/Week/All toggle'**
  String get dogProfileMetricsHint;

  /// No description provided for @dogProfileRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get dogProfileRecentActivity;

  /// No description provided for @dogProfileSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get dogProfileSeeAll;

  /// No description provided for @dogProfileNoRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'No recent activity'**
  String get dogProfileNoRecentActivity;

  /// No description provided for @dogProfileRelMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n}m'**
  String dogProfileRelMinutes(int n);

  /// No description provided for @dogProfileRelHours.
  ///
  /// In en, this message translates to:
  /// **'{n}h'**
  String dogProfileRelHours(int n);

  /// No description provided for @dogProfileRelDays.
  ///
  /// In en, this message translates to:
  /// **'{n}d'**
  String dogProfileRelDays(int n);

  /// No description provided for @dogsListTitle.
  ///
  /// In en, this message translates to:
  /// **'Dogs'**
  String get dogsListTitle;

  /// No description provided for @dogsListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No dogs added yet'**
  String get dogsListEmpty;

  /// No description provided for @dogsListNoDetails.
  ///
  /// In en, this message translates to:
  /// **'No details'**
  String get dogsListNoDetails;

  /// No description provided for @dogNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get dogNameLabel;

  /// No description provided for @dogBreedLabel.
  ///
  /// In en, this message translates to:
  /// **'Breed'**
  String get dogBreedLabel;

  /// No description provided for @dogPhotoTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get dogPhotoTakePhoto;

  /// No description provided for @dogPhotoChooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get dogPhotoChooseFromGallery;

  /// No description provided for @dogPhotoRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove Photo'**
  String get dogPhotoRemovePhoto;

  /// No description provided for @arucoPrintMarker.
  ///
  /// In en, this message translates to:
  /// **'Print marker'**
  String get arucoPrintMarker;

  /// No description provided for @editDogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Dog'**
  String get editDogTitle;

  /// No description provided for @editDogNotFound.
  ///
  /// In en, this message translates to:
  /// **'Dog not found'**
  String get editDogNotFound;

  /// No description provided for @editDogBreedHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Golden Retriever'**
  String get editDogBreedHint;

  /// No description provided for @editDogCoatColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Coat color'**
  String get editDogCoatColorLabel;

  /// No description provided for @editDogDeleteDog.
  ///
  /// In en, this message translates to:
  /// **'Delete Dog'**
  String get editDogDeleteDog;

  /// No description provided for @editDogNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Name cannot be empty'**
  String get editDogNameEmpty;

  /// No description provided for @editDogSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get editDogSaved;

  /// No description provided for @editDogSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String editDogSaveFailed(String error);

  /// No description provided for @editDogDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Dog?'**
  String get editDogDeleteConfirmTitle;

  /// No description provided for @editDogDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name}? This will remove all their data and cannot be undone.'**
  String editDogDeleteConfirmBody(String name);

  /// No description provided for @editDogDeleted.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted'**
  String editDogDeleted(String name);

  /// No description provided for @editDogChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get editDogChangePhoto;

  /// No description provided for @editDogChoosePhotoSource.
  ///
  /// In en, this message translates to:
  /// **'Choose Photo Source'**
  String get editDogChoosePhotoSource;

  /// No description provided for @editDogPhotoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Photo updated'**
  String get editDogPhotoUpdated;

  /// No description provided for @editDogPhotoSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save photo: {error}'**
  String editDogPhotoSaveFailed(String error);

  /// No description provided for @editDogTreatsPerReward.
  ///
  /// In en, this message translates to:
  /// **'Treats per reward'**
  String get editDogTreatsPerReward;

  /// No description provided for @editDogTreatsHelper1.
  ///
  /// In en, this message translates to:
  /// **'Default — one treat per reward.'**
  String get editDogTreatsHelper1;

  /// No description provided for @editDogTreatsHelper2.
  ///
  /// In en, this message translates to:
  /// **'Medium dogs may benefit from two.'**
  String get editDogTreatsHelper2;

  /// No description provided for @editDogTreatsHelper3.
  ///
  /// In en, this message translates to:
  /// **'Big dogs need more to feel rewarded.'**
  String get editDogTreatsHelper3;

  /// No description provided for @editDogTreatsHelper4.
  ///
  /// In en, this message translates to:
  /// **'Very large dogs / high-energy training.'**
  String get editDogTreatsHelper4;

  /// No description provided for @editDogArucoMarker.
  ///
  /// In en, this message translates to:
  /// **'ArUco Marker'**
  String get editDogArucoMarker;

  /// No description provided for @editDogNoMarker.
  ///
  /// In en, this message translates to:
  /// **'No marker assigned. Re-create this dog to assign one.'**
  String get editDogNoMarker;

  /// No description provided for @editDogMarkerId.
  ///
  /// In en, this message translates to:
  /// **'DICT_4X4_1000 — ID {id}'**
  String editDogMarkerId(int id);

  /// No description provided for @editDogPrintFailed.
  ///
  /// In en, this message translates to:
  /// **'Print failed: {error}'**
  String editDogPrintFailed(String error);

  /// No description provided for @addDogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Dog'**
  String get addDogTitle;

  /// No description provided for @addDogSaveDog.
  ///
  /// In en, this message translates to:
  /// **'Save Dog'**
  String get addDogSaveDog;

  /// No description provided for @addDogContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get addDogContinue;

  /// No description provided for @addDogStepColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get addDogStepColor;

  /// No description provided for @addDogStepPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get addDogStepPhoto;

  /// No description provided for @addDogPhotoSelected.
  ///
  /// In en, this message translates to:
  /// **'Photo selected'**
  String get addDogPhotoSelected;

  /// No description provided for @addDogOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get addDogOptional;

  /// No description provided for @addDogStepAruco.
  ///
  /// In en, this message translates to:
  /// **'ARUCO Tag'**
  String get addDogStepAruco;

  /// No description provided for @addDogNameQuestion.
  ///
  /// In en, this message translates to:
  /// **'What\'s your dog\'s name?'**
  String get addDogNameQuestion;

  /// No description provided for @addDogNameFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Dog Name'**
  String get addDogNameFieldLabel;

  /// No description provided for @addDogNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Max, Luna, Buddy'**
  String get addDogNameHint;

  /// No description provided for @addDogNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get addDogNameRequired;

  /// No description provided for @addDogBreedQuestion.
  ///
  /// In en, this message translates to:
  /// **'What breed is your dog?'**
  String get addDogBreedQuestion;

  /// No description provided for @addDogBreedHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Golden Retriever, Mixed, Unknown'**
  String get addDogBreedHint;

  /// No description provided for @addDogColorQuestion.
  ///
  /// In en, this message translates to:
  /// **'What\'s your dog\'s primary coat color?'**
  String get addDogColorQuestion;

  /// No description provided for @addDogPhotoPrompt.
  ///
  /// In en, this message translates to:
  /// **'Add a profile photo for your dog'**
  String get addDogPhotoPrompt;

  /// No description provided for @addDogTapToAdd.
  ///
  /// In en, this message translates to:
  /// **'Tap to add'**
  String get addDogTapToAdd;

  /// No description provided for @addDogCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get addDogCamera;

  /// No description provided for @addDogGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get addDogGallery;

  /// No description provided for @addDogRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get addDogRemovePhoto;

  /// No description provided for @addDogArucoIntro.
  ///
  /// In en, this message translates to:
  /// **'WIM-Z uses an ARUCO marker on your dog\'s collar to tell them apart.'**
  String get addDogArucoIntro;

  /// No description provided for @addDogArucoAutoPicked.
  ///
  /// In en, this message translates to:
  /// **'We picked the next free ID for you. Print this marker and attach it to the collar.'**
  String get addDogArucoAutoPicked;

  /// No description provided for @addDogArucoIdLabel.
  ///
  /// In en, this message translates to:
  /// **'ARUCO Marker ID'**
  String get addDogArucoIdLabel;

  /// No description provided for @addDogArucoIdHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 42'**
  String get addDogArucoIdHint;

  /// No description provided for @addDogArucoSkipHint.
  ///
  /// In en, this message translates to:
  /// **'You can clear this field to skip ArUco — useful if you only have one dog or prefer appearance-based ID.'**
  String get addDogArucoSkipHint;

  /// No description provided for @addDogMarkerBundleMissing.
  ///
  /// In en, this message translates to:
  /// **'Marker bundle not generated yet — run scripts/generate_aruco_markers.py'**
  String get addDogMarkerBundleMissing;

  /// No description provided for @addDogPickImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick image: {error}'**
  String addDogPickImageFailed(String error);

  /// No description provided for @addDogDuplicateName.
  ///
  /// In en, this message translates to:
  /// **'A dog named \"{name}\" already exists'**
  String addDogDuplicateName(String name);

  /// No description provided for @addDogRobotWillRecognize.
  ///
  /// In en, this message translates to:
  /// **'Robot will now recognize {name}'**
  String addDogRobotWillRecognize(String name);

  /// No description provided for @weeklySummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly Summary'**
  String get weeklySummaryTitle;

  /// No description provided for @weeklyTapRefresh.
  ///
  /// In en, this message translates to:
  /// **'Tap refresh for this week\'s report'**
  String get weeklyTapRefresh;

  /// No description provided for @weeklyVsLastWeek.
  ///
  /// In en, this message translates to:
  /// **'vs last wk'**
  String get weeklyVsLastWeek;

  /// No description provided for @weeklyQuiets.
  ///
  /// In en, this message translates to:
  /// **'Quiets'**
  String get weeklyQuiets;

  /// No description provided for @weeklyTricks.
  ///
  /// In en, this message translates to:
  /// **'Tricks: {completed}/{attempts} completed'**
  String weeklyTricks(int completed, int attempts);

  /// No description provided for @weeklyTricksWithRate.
  ///
  /// In en, this message translates to:
  /// **'Tricks: {completed}/{attempts} completed ({rate}%)'**
  String weeklyTricksWithRate(int completed, int attempts, String rate);

  /// No description provided for @weeklyGuardian.
  ///
  /// In en, this message translates to:
  /// **'Guardian: {interventions} interventions across {sessions} sessions'**
  String weeklyGuardian(int interventions, int sessions);

  /// No description provided for @weeklyDataSince.
  ///
  /// In en, this message translates to:
  /// **'Data since: {parts}'**
  String weeklyDataSince(String parts);

  /// No description provided for @weeklyCoverageBarks.
  ///
  /// In en, this message translates to:
  /// **'barks'**
  String get weeklyCoverageBarks;

  /// No description provided for @weeklyCoverageBarkTypes.
  ///
  /// In en, this message translates to:
  /// **'bark types'**
  String get weeklyCoverageBarkTypes;

  /// No description provided for @weeklyCoverageTreats.
  ///
  /// In en, this message translates to:
  /// **'treats'**
  String get weeklyCoverageTreats;

  /// No description provided for @weeklyCoverageCoaching.
  ///
  /// In en, this message translates to:
  /// **'coaching'**
  String get weeklyCoverageCoaching;

  /// No description provided for @voiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice Commands'**
  String get voiceTitle;

  /// No description provided for @voiceNoDogSelected.
  ///
  /// In en, this message translates to:
  /// **'No dog selected'**
  String get voiceNoDogSelected;

  /// No description provided for @voiceResetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset to default voice'**
  String get voiceResetTooltip;

  /// No description provided for @voiceSyncAll.
  ///
  /// In en, this message translates to:
  /// **'Sync All'**
  String get voiceSyncAll;

  /// No description provided for @voiceIntro.
  ///
  /// In en, this message translates to:
  /// **'Record your voice for each command. {dogName} will learn to respond to YOUR voice.'**
  String voiceIntro(String dogName);

  /// No description provided for @voiceMobileOnlyBanner.
  ///
  /// In en, this message translates to:
  /// **'Recording requires the iOS/Android app. Use mobile to record commands.'**
  String get voiceMobileOnlyBanner;

  /// No description provided for @voiceRecordedProgress.
  ///
  /// In en, this message translates to:
  /// **'{recorded} of {total} recorded'**
  String voiceRecordedProgress(int recorded, int total);

  /// No description provided for @voiceSyncedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} synced'**
  String voiceSyncedCount(int count);

  /// No description provided for @voiceMobileRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Mobile Required'**
  String get voiceMobileRequiredTitle;

  /// No description provided for @voiceMobileRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'Voice recording requires the iOS or Android app. Please use your mobile device to record voice commands.'**
  String get voiceMobileRequiredBody;

  /// No description provided for @voiceDeleteRecordingTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Recording?'**
  String get voiceDeleteRecordingTitle;

  /// No description provided for @voiceDeleteRecordingBody.
  ///
  /// In en, this message translates to:
  /// **'This will delete the recorded voice command.'**
  String get voiceDeleteRecordingBody;

  /// No description provided for @voiceCommandSynced.
  ///
  /// In en, this message translates to:
  /// **'Command synced!'**
  String get voiceCommandSynced;

  /// No description provided for @voiceSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get voiceSyncFailed;

  /// No description provided for @voiceResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default Voice?'**
  String get voiceResetTitle;

  /// No description provided for @voiceResetBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes {count, plural, =1{1 recording} other{{count} recordings}} for {dogName}. WIM-Z will use its built-in voice instead.'**
  String voiceResetBody(int count, String dogName);

  /// No description provided for @voiceResetAction.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get voiceResetAction;

  /// No description provided for @voiceResetDone.
  ///
  /// In en, this message translates to:
  /// **'Reset — WIM-Z will use its default voice'**
  String get voiceResetDone;

  /// No description provided for @voiceSyncedToRobot.
  ///
  /// In en, this message translates to:
  /// **'{count} commands synced to robot'**
  String voiceSyncedToRobot(int count);

  /// No description provided for @voiceRecordedSynced.
  ///
  /// In en, this message translates to:
  /// **'Recorded & Synced'**
  String get voiceRecordedSynced;

  /// No description provided for @voiceRecordedTapToSync.
  ///
  /// In en, this message translates to:
  /// **'Recorded - tap to sync'**
  String get voiceRecordedTapToSync;

  /// No description provided for @voiceNotRecorded.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get voiceNotRecorded;

  /// No description provided for @voiceSyncToRobotTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sync to robot'**
  String get voiceSyncToRobotTooltip;

  /// No description provided for @voiceReRecord.
  ///
  /// In en, this message translates to:
  /// **'Re-record'**
  String get voiceReRecord;

  /// No description provided for @voiceRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get voiceRecord;

  /// No description provided for @voiceStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start recording. Check microphone permission.'**
  String get voiceStartFailed;

  /// No description provided for @voiceRecordingFailed.
  ///
  /// In en, this message translates to:
  /// **'Recording failed. Try again.'**
  String get voiceRecordingFailed;

  /// No description provided for @voiceSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved!'**
  String get voiceSavedTitle;

  /// No description provided for @voiceRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Record: {label}'**
  String voiceRecordTitle(String label);

  /// No description provided for @voiceRecordedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Voice command recorded successfully!'**
  String get voiceRecordedSuccess;

  /// No description provided for @voiceSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String voiceSeconds(String seconds);

  /// No description provided for @voiceSayClearly.
  ///
  /// In en, this message translates to:
  /// **'Say the command clearly...'**
  String get voiceSayClearly;

  /// No description provided for @voicePreparingMic.
  ///
  /// In en, this message translates to:
  /// **'Preparing microphone...'**
  String get voicePreparingMic;

  /// No description provided for @voiceStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get voiceStop;

  /// No description provided for @arucoIdLabel.
  ///
  /// In en, this message translates to:
  /// **'ID {id}'**
  String arucoIdLabel(int id);

  /// No description provided for @arucoBundleMissing.
  ///
  /// In en, this message translates to:
  /// **'Marker bundle not generated.\nSee scripts/generate_aruco_markers.py'**
  String get arucoBundleMissing;

  /// No description provided for @loginTagline.
  ///
  /// In en, this message translates to:
  /// **'Watchful Intelligent Mobile Zen'**
  String get loginTagline;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @loginCloudHint.
  ///
  /// In en, this message translates to:
  /// **'Cloud connection (requires internet)'**
  String get loginCloudHint;

  /// No description provided for @loginConnectToRobot.
  ///
  /// In en, this message translates to:
  /// **'Connect to Robot'**
  String get loginConnectToRobot;

  /// No description provided for @loginDirectHint.
  ///
  /// In en, this message translates to:
  /// **'Direct connection via WIMZ WiFi hotspot'**
  String get loginDirectHint;

  /// No description provided for @loginLocalConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to robot.\nMake sure you\'re on the same WiFi as your robot\nor connected to the WIMZ hotspot.'**
  String get loginLocalConnectFailed;

  /// No description provided for @loginConnectionFailedCheckWifi.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Check WiFi and try again.'**
  String get loginConnectionFailedCheckWifi;

  /// No description provided for @loginDemoMode.
  ///
  /// In en, this message translates to:
  /// **'Demo Mode'**
  String get loginDemoMode;

  /// No description provided for @loginSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginSignIn;

  /// No description provided for @loginCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get loginCreateAccount;

  /// No description provided for @loginEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmailLabel;

  /// No description provided for @loginEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter email'**
  String get loginEnterEmail;

  /// No description provided for @loginInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get loginInvalidEmail;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordLabel;

  /// No description provided for @loginEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter password'**
  String get loginEnterPassword;

  /// No description provided for @loginMin6Chars.
  ///
  /// In en, this message translates to:
  /// **'Min 6 characters'**
  String get loginMin6Chars;

  /// No description provided for @loginSavePassword.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get loginSavePassword;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @loginNoAccountSignUp.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get loginNoAccountSignUp;

  /// No description provided for @loginHaveAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get loginHaveAccountSignIn;

  /// No description provided for @forgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get forgotTitle;

  /// No description provided for @forgotHeading.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotHeading;

  /// No description provided for @forgotIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter the email on your account and we\'ll send you a 6-digit code to reset your password.'**
  String get forgotIntro;

  /// No description provided for @forgotSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get forgotSendCode;

  /// No description provided for @forgotCodeSentBanner.
  ///
  /// In en, this message translates to:
  /// **'If that email is registered, a 6-digit code is on the way. It expires in 15 minutes.'**
  String get forgotCodeSentBanner;

  /// No description provided for @forgotEnterCodeHeading.
  ///
  /// In en, this message translates to:
  /// **'Enter Code & New Password'**
  String get forgotEnterCodeHeading;

  /// No description provided for @forgotCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get forgotCodeLabel;

  /// No description provided for @forgotEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get forgotEnterCode;

  /// No description provided for @forgotCodeIs6Digits.
  ///
  /// In en, this message translates to:
  /// **'Code is 6 digits'**
  String get forgotCodeIs6Digits;

  /// No description provided for @forgotNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get forgotNewPasswordLabel;

  /// No description provided for @forgotEnterNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password'**
  String get forgotEnterNewPassword;

  /// No description provided for @forgotMin8Chars.
  ///
  /// In en, this message translates to:
  /// **'Min 8 characters'**
  String get forgotMin8Chars;

  /// No description provided for @forgotConfirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get forgotConfirmPasswordLabel;

  /// No description provided for @forgotConfirmYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password'**
  String get forgotConfirmYourPassword;

  /// No description provided for @forgotPasswordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get forgotPasswordsDontMatch;

  /// No description provided for @forgotResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get forgotResendCode;

  /// No description provided for @homeLocalRobot.
  ///
  /// In en, this message translates to:
  /// **'Local Robot'**
  String get homeLocalRobot;

  /// No description provided for @homeFindYourRobot.
  ///
  /// In en, this message translates to:
  /// **'Find your robot →'**
  String get homeFindYourRobot;

  /// No description provided for @homeNewDog.
  ///
  /// In en, this message translates to:
  /// **'New dog #{arucoId}'**
  String homeNewDog(int arucoId);

  /// No description provided for @homeDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get homeDismiss;

  /// No description provided for @homeExit.
  ///
  /// In en, this message translates to:
  /// **'EXIT'**
  String get homeExit;

  /// No description provided for @homeModeIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get homeModeIdle;

  /// No description provided for @homeModeGuard.
  ///
  /// In en, this message translates to:
  /// **'Guard'**
  String get homeModeGuard;

  /// No description provided for @homeModeCoach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get homeModeCoach;

  /// No description provided for @homeSelectDog.
  ///
  /// In en, this message translates to:
  /// **'Select Dog'**
  String get homeSelectDog;

  /// No description provided for @driveLabel.
  ///
  /// In en, this message translates to:
  /// **'DRIVE'**
  String get driveLabel;

  /// No description provided for @driveEmergencyStop.
  ///
  /// In en, this message translates to:
  /// **'Emergency Stop'**
  String get driveEmergencyStop;

  /// No description provided for @driveCall.
  ///
  /// In en, this message translates to:
  /// **'CALL'**
  String get driveCall;

  /// No description provided for @driveTreat.
  ///
  /// In en, this message translates to:
  /// **'TREAT'**
  String get driveTreat;

  /// No description provided for @driveCenter.
  ///
  /// In en, this message translates to:
  /// **'CENTER'**
  String get driveCenter;

  /// No description provided for @driveSwitchingMode.
  ///
  /// In en, this message translates to:
  /// **'Switching mode...'**
  String get driveSwitchingMode;

  /// No description provided for @driveCamera.
  ///
  /// In en, this message translates to:
  /// **'CAMERA'**
  String get driveCamera;

  /// No description provided for @driveCoach.
  ///
  /// In en, this message translates to:
  /// **'COACH'**
  String get driveCoach;

  /// No description provided for @driveSelectDogFirst.
  ///
  /// In en, this message translates to:
  /// **'Select a dog or wait for the camera to identify one.'**
  String get driveSelectDogFirst;

  /// No description provided for @driveMissionFallback.
  ///
  /// In en, this message translates to:
  /// **'Mission'**
  String get driveMissionFallback;

  /// No description provided for @driveMissionStage.
  ///
  /// In en, this message translates to:
  /// **'{name} — {stage}'**
  String driveMissionStage(String name, String stage);

  /// No description provided for @driveStop.
  ///
  /// In en, this message translates to:
  /// **'STOP'**
  String get driveStop;

  /// No description provided for @galleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo Gallery'**
  String get galleryTitle;

  /// No description provided for @galleryRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get galleryRefresh;

  /// No description provided for @galleryNoPhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos yet'**
  String get galleryNoPhotos;

  /// No description provided for @galleryTakePhotosHint.
  ///
  /// In en, this message translates to:
  /// **'Take photos from the video view'**
  String get galleryTakePhotosHint;

  /// No description provided for @galleryShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get galleryShare;

  /// No description provided for @galleryFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get galleryFailedToLoad;

  /// No description provided for @galleryShareText.
  ///
  /// In en, this message translates to:
  /// **'WIM-Z Photo - {date}'**
  String galleryShareText(String date);

  /// No description provided for @galleryShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to share: {error}'**
  String galleryShareFailed(String error);

  /// No description provided for @galleryDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Photo'**
  String get galleryDeleteTitle;

  /// No description provided for @galleryDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this photo?'**
  String get galleryDeleteConfirm;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get notificationsTitle;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notificationsFilterAll;

  /// No description provided for @notificationsFilterBehaviors.
  ///
  /// In en, this message translates to:
  /// **'Behaviors'**
  String get notificationsFilterBehaviors;

  /// No description provided for @notificationsFilterMissions.
  ///
  /// In en, this message translates to:
  /// **'Missions'**
  String get notificationsFilterMissions;

  /// No description provided for @notificationsFilterAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get notificationsFilterAlerts;

  /// No description provided for @notificationsFilterTreats.
  ///
  /// In en, this message translates to:
  /// **'Treats'**
  String get notificationsFilterTreats;

  /// No description provided for @notificationsFilterCoach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get notificationsFilterCoach;

  /// No description provided for @notificationsClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get notificationsClearAll;

  /// No description provided for @notificationsTabDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get notificationsTabDashboard;

  /// No description provided for @notificationsTabEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get notificationsTabEvents;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsEmpty;

  /// No description provided for @notificationsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Events from WIM-Z will appear here'**
  String get notificationsEmptyHint;

  /// No description provided for @notificationsGroupToday.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get notificationsGroupToday;

  /// No description provided for @notificationsGroupYesterday.
  ///
  /// In en, this message translates to:
  /// **'YESTERDAY'**
  String get notificationsGroupYesterday;

  /// No description provided for @notificationsGroupThisWeek.
  ///
  /// In en, this message translates to:
  /// **'THIS WEEK'**
  String get notificationsGroupThisWeek;

  /// No description provided for @notificationsGroupEarlier.
  ///
  /// In en, this message translates to:
  /// **'EARLIER'**
  String get notificationsGroupEarlier;

  /// No description provided for @activityNoDogSelected.
  ///
  /// In en, this message translates to:
  /// **'No dog selected'**
  String get activityNoDogSelected;

  /// No description provided for @activityStatTreats.
  ///
  /// In en, this message translates to:
  /// **'Treats'**
  String get activityStatTreats;

  /// No description provided for @activityStatDetections.
  ///
  /// In en, this message translates to:
  /// **'Detections'**
  String get activityStatDetections;

  /// No description provided for @activityStatMissions.
  ///
  /// In en, this message translates to:
  /// **'Missions'**
  String get activityStatMissions;

  /// No description provided for @activityStatCoach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get activityStatCoach;

  /// No description provided for @activitySeriesTreats.
  ///
  /// In en, this message translates to:
  /// **'Treats'**
  String get activitySeriesTreats;

  /// No description provided for @activitySeriesBarks.
  ///
  /// In en, this message translates to:
  /// **'Barks'**
  String get activitySeriesBarks;

  /// No description provided for @activitySeriesBehaviors.
  ///
  /// In en, this message translates to:
  /// **'Behaviors'**
  String get activitySeriesBehaviors;

  /// No description provided for @activitySeriesMissions.
  ///
  /// In en, this message translates to:
  /// **'Missions'**
  String get activitySeriesMissions;

  /// No description provided for @activitySeriesAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get activitySeriesAlerts;

  /// No description provided for @activityChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity (7 days)'**
  String get activityChartTitle;

  /// No description provided for @activityNoSeriesSelected.
  ///
  /// In en, this message translates to:
  /// **'No series selected'**
  String get activityNoSeriesSelected;

  /// No description provided for @activitySeriesCount.
  ///
  /// In en, this message translates to:
  /// **'{label}: {count}'**
  String activitySeriesCount(String label, int count);

  /// No description provided for @activityRecentEvents.
  ///
  /// In en, this message translates to:
  /// **'Recent Events'**
  String get activityRecentEvents;

  /// No description provided for @activityNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No events yet'**
  String get activityNoEvents;

  /// No description provided for @connBadgeNoRobot.
  ///
  /// In en, this message translates to:
  /// **'No Robot'**
  String get connBadgeNoRobot;

  /// No description provided for @connBadgeOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get connBadgeOffline;

  /// No description provided for @connBadgeNotPaired.
  ///
  /// In en, this message translates to:
  /// **'Not Paired'**
  String get connBadgeNotPaired;

  /// No description provided for @connBadgeWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting...'**
  String get connBadgeWaiting;

  /// No description provided for @connBadgeRobotOnline.
  ///
  /// In en, this message translates to:
  /// **'Robot Online'**
  String get connBadgeRobotOnline;

  /// No description provided for @connBadgeOtherDeviceActive.
  ///
  /// In en, this message translates to:
  /// **'Other Device Active'**
  String get connBadgeOtherDeviceActive;

  /// No description provided for @connBadgeDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get connBadgeDemo;

  /// No description provided for @localApCouldntReach.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the robot. Join \"{ssid}\" (password {password}) in WiFi settings first, then try again.'**
  String localApCouldntReach(String ssid, String password);

  /// No description provided for @localApNoHotspotInfo.
  ///
  /// In en, this message translates to:
  /// **'Robot didn\'t confirm hotspot start and no cached hotspot info is available. Update the robot and try again.'**
  String get localApNoHotspotInfo;

  /// No description provided for @localApJoinHotspotTitle.
  ///
  /// In en, this message translates to:
  /// **'Join the robot\'s hotspot'**
  String get localApJoinHotspotTitle;

  /// No description provided for @localApJoinHotspotBody.
  ///
  /// In en, this message translates to:
  /// **'The robot is starting its hotspot.\n\n1. Open WiFi settings on this phone\n2. Join \"{ssid}\"\n    password: {password}\n3. Come back and tap Connect\n\nThe robot stays on its hotspot until you switch back to cloud mode (or 10 minutes with no phone attached).'**
  String localApJoinHotspotBody(String ssid, String password);

  /// No description provided for @localApConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get localApConnect;

  /// No description provided for @localApSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to Local Mode'**
  String get localApSwitchTitle;

  /// No description provided for @localApSwitchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Robot starts its hotspot; phone connects directly'**
  String get localApSwitchSubtitle;

  /// No description provided for @treatCounterOf.
  ///
  /// In en, this message translates to:
  /// **'{remaining} of {capacity}'**
  String treatCounterOf(int remaining, int capacity);

  /// No description provided for @treatCounterTitle.
  ///
  /// In en, this message translates to:
  /// **'Treats: {headline}'**
  String treatCounterTitle(String headline);

  /// No description provided for @treatCounterEmptyRefill.
  ///
  /// In en, this message translates to:
  /// **'Empty — refill needed'**
  String get treatCounterEmptyRefill;

  /// No description provided for @treatCounterRemainingLabel.
  ///
  /// In en, this message translates to:
  /// **'treats remaining'**
  String get treatCounterRemainingLabel;

  /// No description provided for @treatCounterRefilledReset.
  ///
  /// In en, this message translates to:
  /// **'Refilled — Reset Counter'**
  String get treatCounterRefilledReset;

  /// No description provided for @treatCounterClearing.
  ///
  /// In en, this message translates to:
  /// **'Clearing...'**
  String get treatCounterClearing;

  /// No description provided for @treatCounterClearJam.
  ///
  /// In en, this message translates to:
  /// **'Clear Jam'**
  String get treatCounterClearJam;

  /// No description provided for @treatCounterLoadedHint.
  ///
  /// In en, this message translates to:
  /// **'Treats loaded (max {capacity})'**
  String treatCounterLoadedHint(int capacity);

  /// No description provided for @treatCounterSet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get treatCounterSet;

  /// No description provided for @eventFeedSgActive.
  ///
  /// In en, this message translates to:
  /// **'Silent Guardian Active'**
  String get eventFeedSgActive;

  /// No description provided for @eventFeedWatching.
  ///
  /// In en, this message translates to:
  /// **'Watching for activity...'**
  String get eventFeedWatching;

  /// No description provided for @eventFeedRecentEvents.
  ///
  /// In en, this message translates to:
  /// **'Recent Events ({count})'**
  String eventFeedRecentEvents(int count);

  /// No description provided for @eventFeedClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get eventFeedClear;

  /// No description provided for @notifBarkingDetected.
  ///
  /// In en, this message translates to:
  /// **'Barking Detected'**
  String get notifBarkingDetected;

  /// No description provided for @notifPanicEpisodeEnded.
  ///
  /// In en, this message translates to:
  /// **'Panic Episode Ended'**
  String get notifPanicEpisodeEnded;

  /// No description provided for @notifPanicAlert.
  ///
  /// In en, this message translates to:
  /// **'Panic Alert'**
  String get notifPanicAlert;

  /// No description provided for @notifSgLevel4.
  ///
  /// In en, this message translates to:
  /// **'Silent Guardian: Level 4'**
  String get notifSgLevel4;

  /// No description provided for @notifSgLevel4Body.
  ///
  /// In en, this message translates to:
  /// **'Escalation reached the highest level'**
  String get notifSgLevel4Body;

  /// No description provided for @notifTreatDispensed.
  ///
  /// In en, this message translates to:
  /// **'Treat Dispensed'**
  String get notifTreatDispensed;

  /// No description provided for @notifTreatFor.
  ///
  /// In en, this message translates to:
  /// **'For {dogName}'**
  String notifTreatFor(String dogName);

  /// No description provided for @notifGoodJob.
  ///
  /// In en, this message translates to:
  /// **'Good job!'**
  String get notifGoodJob;

  /// No description provided for @notifTreatsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 treat remaining} other{{count} treats remaining}}'**
  String notifTreatsRemaining(int count);

  /// No description provided for @notifTreatsRunningLow.
  ///
  /// In en, this message translates to:
  /// **'Treats Running Low'**
  String get notifTreatsRunningLow;

  /// No description provided for @notifTreatsLowBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 treat remaining — time to refill!} other{{count} treats remaining — time to refill!}}'**
  String notifTreatsLowBody(int count);

  /// No description provided for @notifTreatsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Treats Empty'**
  String get notifTreatsEmpty;

  /// No description provided for @notifTreatsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Refill the carousel to keep dispensing'**
  String get notifTreatsEmptyBody;

  /// No description provided for @notifMissionStarted.
  ///
  /// In en, this message translates to:
  /// **'Mission Started'**
  String get notifMissionStarted;

  /// No description provided for @notifMissionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mission Completed'**
  String get notifMissionCompleted;

  /// No description provided for @notifMissionFailed.
  ///
  /// In en, this message translates to:
  /// **'Mission Failed'**
  String get notifMissionFailed;

  /// No description provided for @notifCoachRewardedFor.
  ///
  /// In en, this message translates to:
  /// **'{dogName}: {behavior} rewarded'**
  String notifCoachRewardedFor(String dogName, String behavior);

  /// No description provided for @notifCoachRewarded.
  ///
  /// In en, this message translates to:
  /// **'{behavior} rewarded'**
  String notifCoachRewarded(String behavior);

  /// No description provided for @notifCoachAttempt.
  ///
  /// In en, this message translates to:
  /// **'{behavior} attempt'**
  String notifCoachAttempt(String behavior);

  /// No description provided for @notifCoachMode.
  ///
  /// In en, this message translates to:
  /// **'Coach mode'**
  String get notifCoachMode;

  /// No description provided for @notifTrick.
  ///
  /// In en, this message translates to:
  /// **'trick'**
  String get notifTrick;

  /// No description provided for @notifLowBattery.
  ///
  /// In en, this message translates to:
  /// **'Low Battery'**
  String get notifLowBattery;

  /// No description provided for @notifBatteryRemaining.
  ///
  /// In en, this message translates to:
  /// **'{percent}% remaining'**
  String notifBatteryRemaining(int percent);

  /// No description provided for @notifSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Session ended'**
  String get notifSessionEnded;

  /// No description provided for @notifAggressiveToday.
  ///
  /// In en, this message translates to:
  /// **'Your dog was aggressive today'**
  String get notifAggressiveToday;

  /// No description provided for @notifPanicEpisodes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 panic episode} other{{count} panic episodes}}'**
  String notifPanicEpisodes(int count);

  /// No description provided for @notifGuardianSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Guardian Session Ended'**
  String get notifGuardianSessionEnded;

  /// No description provided for @notifGuardianAlert.
  ///
  /// In en, this message translates to:
  /// **'Guardian Alert'**
  String get notifGuardianAlert;

  /// No description provided for @notifIntervention.
  ///
  /// In en, this message translates to:
  /// **'Intervention'**
  String get notifIntervention;

  /// No description provided for @notifGuardianReason.
  ///
  /// In en, this message translates to:
  /// **'Guardian: {reason}'**
  String notifGuardianReason(String reason);

  /// No description provided for @notifSittingDetected.
  ///
  /// In en, this message translates to:
  /// **'Sitting Detected'**
  String get notifSittingDetected;

  /// No description provided for @notifLayDown.
  ///
  /// In en, this message translates to:
  /// **'Lay Down'**
  String get notifLayDown;

  /// No description provided for @notifCome.
  ///
  /// In en, this message translates to:
  /// **'Come'**
  String get notifCome;

  /// No description provided for @notifAlert.
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get notifAlert;

  /// No description provided for @notifHappyDog.
  ///
  /// In en, this message translates to:
  /// **'Happy Dog'**
  String get notifHappyDog;

  /// No description provided for @notifCoachReward.
  ///
  /// In en, this message translates to:
  /// **'Coach Reward'**
  String get notifCoachReward;

  /// No description provided for @notifGuardianSummary.
  ///
  /// In en, this message translates to:
  /// **'Guardian Summary'**
  String get notifGuardianSummary;

  /// No description provided for @notifBehaviorDetected.
  ///
  /// In en, this message translates to:
  /// **'Behavior Detected'**
  String get notifBehaviorDetected;

  /// No description provided for @notifBehaviorNamedDetected.
  ///
  /// In en, this message translates to:
  /// **'{behavior} Detected'**
  String notifBehaviorNamedDetected(String behavior);

  /// No description provided for @notifConfidence.
  ///
  /// In en, this message translates to:
  /// **'{percent}% confidence'**
  String notifConfidence(int percent);

  /// No description provided for @notifBarkType.
  ///
  /// In en, this message translates to:
  /// **'{type} bark'**
  String notifBarkType(String type);

  /// No description provided for @channelActivityName.
  ///
  /// In en, this message translates to:
  /// **'WIM-Z Activity'**
  String get channelActivityName;

  /// No description provided for @channelActivityDescription.
  ///
  /// In en, this message translates to:
  /// **'Dog training activity notifications'**
  String get channelActivityDescription;

  /// No description provided for @authErrRegistrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get authErrRegistrationFailed;

  /// No description provided for @authErrEmailRegistered.
  ///
  /// In en, this message translates to:
  /// **'Email already registered'**
  String get authErrEmailRegistered;

  /// No description provided for @authErrInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get authErrInvalidCredentials;

  /// No description provided for @authErrLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get authErrLoginFailed;

  /// No description provided for @authErrAccountNotFound.
  ///
  /// In en, this message translates to:
  /// **'Account not found'**
  String get authErrAccountNotFound;

  /// No description provided for @authErrResetCodeSend.
  ///
  /// In en, this message translates to:
  /// **'Could not send reset code. Check your connection.'**
  String get authErrResetCodeSend;

  /// No description provided for @authErrResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Reset failed'**
  String get authErrResetFailed;

  /// No description provided for @authErrInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired code'**
  String get authErrInvalidCode;

  /// No description provided for @authErrTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts — try again later'**
  String get authErrTooManyAttempts;

  /// No description provided for @authNoticeSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session expired — please sign in again.'**
  String get authNoticeSessionExpired;

  /// No description provided for @connStatusConnectingServer.
  ///
  /// In en, this message translates to:
  /// **'Connecting to server...'**
  String get connStatusConnectingServer;

  /// No description provided for @connStatusNotPaired.
  ///
  /// In en, this message translates to:
  /// **'Device not paired'**
  String get connStatusNotPaired;

  /// No description provided for @connStatusWaitingRobot.
  ///
  /// In en, this message translates to:
  /// **'Server connected. Waiting for robot...'**
  String get connStatusWaitingRobot;

  /// No description provided for @connStatusRobotOnline.
  ///
  /// In en, this message translates to:
  /// **'Robot online'**
  String get connStatusRobotOnline;

  /// No description provided for @connStatusError.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get connStatusError;

  /// No description provided for @connStatusSuperseded.
  ///
  /// In en, this message translates to:
  /// **'Signed in on another device'**
  String get connStatusSuperseded;

  /// No description provided for @connErrServerNotResponding.
  ///
  /// In en, this message translates to:
  /// **'Server not responding'**
  String get connErrServerNotResponding;

  /// No description provided for @connErrLiveConnection.
  ///
  /// In en, this message translates to:
  /// **'Could not open live connection to server'**
  String get connErrLiveConnection;

  /// No description provided for @connErrLostConnection.
  ///
  /// In en, this message translates to:
  /// **'Lost connection to server'**
  String get connErrLostConnection;

  /// No description provided for @connErrHandshake.
  ///
  /// In en, this message translates to:
  /// **'Connection handshake failed. Please update the app.'**
  String get connErrHandshake;

  /// No description provided for @connErrSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired — please sign in again.'**
  String get connErrSessionExpired;

  /// No description provided for @connErrNotPairedGoSettings.
  ///
  /// In en, this message translates to:
  /// **'Device not paired. Go to Settings to pair.'**
  String get connErrNotPairedGoSettings;

  /// No description provided for @connErrRobotOffline.
  ///
  /// In en, this message translates to:
  /// **'Robot is offline'**
  String get connErrRobotOffline;

  /// No description provided for @errNotAuthorizedLogin.
  ///
  /// In en, this message translates to:
  /// **'Not authorized. Please log in again.'**
  String get errNotAuthorizedLogin;

  /// No description provided for @connErrSuperseded.
  ///
  /// In en, this message translates to:
  /// **'This account is now active on another device. Tap to take control back.'**
  String get connErrSuperseded;

  /// No description provided for @errNotConnectedToRobot.
  ///
  /// In en, this message translates to:
  /// **'Not connected to robot'**
  String get errNotConnectedToRobot;

  /// No description provided for @errNoResponseUpdate.
  ///
  /// In en, this message translates to:
  /// **'No response — robot may need an update'**
  String get errNoResponseUpdate;

  /// No description provided for @pttErrPlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to play audio'**
  String get pttErrPlayFailed;

  /// No description provided for @pttErrMobileOnly.
  ///
  /// In en, this message translates to:
  /// **'Recording only available on iOS/Android'**
  String get pttErrMobileOnly;

  /// No description provided for @pttErrNotConnectedSend.
  ///
  /// In en, this message translates to:
  /// **'Not connected — cannot send voice'**
  String get pttErrNotConnectedSend;

  /// No description provided for @pttErrMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission denied'**
  String get pttErrMicDenied;

  /// No description provided for @pttErrStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Recording failed to start'**
  String get pttErrStartFailed;

  /// No description provided for @pttErrStartFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'Failed to start recording: {error}'**
  String pttErrStartFailedDetail(String error);

  /// No description provided for @pttErrRecordingFailed.
  ///
  /// In en, this message translates to:
  /// **'Recording failed'**
  String get pttErrRecordingFailed;

  /// No description provided for @pttErrFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Recording file not found'**
  String get pttErrFileNotFound;

  /// No description provided for @pttErrEmpty.
  ///
  /// In en, this message translates to:
  /// **'Recording was empty - no audio captured'**
  String get pttErrEmpty;

  /// No description provided for @pttErrNotConnectedNotSent.
  ///
  /// In en, this message translates to:
  /// **'Not connected — voice message not sent'**
  String get pttErrNotConnectedNotSent;

  /// No description provided for @pttErrSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send audio: {error}'**
  String pttErrSendFailed(String error);

  /// No description provided for @pttErrNoAudio.
  ///
  /// In en, this message translates to:
  /// **'No audio received'**
  String get pttErrNoAudio;

  /// No description provided for @pairErrPairFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to pair device'**
  String get pairErrPairFailed;

  /// No description provided for @pairErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your connection.'**
  String get pairErrNetwork;

  /// No description provided for @pairErrUnpairFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to unpair device (status {code})'**
  String pairErrUnpairFailed(int code);

  /// No description provided for @pairErrDeviceNotFound.
  ///
  /// In en, this message translates to:
  /// **'Device not found. Check the device ID.'**
  String get pairErrDeviceNotFound;

  /// No description provided for @pairErrAlreadyPaired.
  ///
  /// In en, this message translates to:
  /// **'Device already paired to your account.'**
  String get pairErrAlreadyPaired;

  /// No description provided for @pairErrRobotUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Robot unavailable. Make sure it is powered on and connected.'**
  String get pairErrRobotUnavailable;

  /// No description provided for @pairErrTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out. Robot may be unavailable.'**
  String get pairErrTimeout;

  /// No description provided for @pairErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again.'**
  String get pairErrGeneric;

  /// No description provided for @ctrlPairPairing.
  ///
  /// In en, this message translates to:
  /// **'Pairing…'**
  String get ctrlPairPairing;

  /// No description provided for @ctrlPairSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get ctrlPairSaving;

  /// No description provided for @ctrlPairRemovingTrust.
  ///
  /// In en, this message translates to:
  /// **'Removing trust…'**
  String get ctrlPairRemovingTrust;

  /// No description provided for @ctrlPairForgetting.
  ///
  /// In en, this message translates to:
  /// **'Forgetting…'**
  String get ctrlPairForgetting;

  /// No description provided for @ctrlPairReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get ctrlPairReconnecting;

  /// No description provided for @ctrlPairConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get ctrlPairConnecting;

  /// No description provided for @ctrlPairError.
  ///
  /// In en, this message translates to:
  /// **'Controller error'**
  String get ctrlPairError;

  /// No description provided for @schedErrDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete schedule'**
  String get schedErrDeleteFailed;

  /// No description provided for @schedErrTimeout.
  ///
  /// In en, this message translates to:
  /// **'Timeout waiting for schedules from robot'**
  String get schedErrTimeout;

  /// No description provided for @modeErrMissionActive.
  ///
  /// In en, this message translates to:
  /// **'Cannot change mode while mission is active'**
  String get modeErrMissionActive;

  /// No description provided for @videoErrRobotRecordFailed.
  ///
  /// In en, this message translates to:
  /// **'Robot could not record the video'**
  String get videoErrRobotRecordFailed;

  /// No description provided for @videoErrNoDownloadUrl.
  ///
  /// In en, this message translates to:
  /// **'No download URL received from robot'**
  String get videoErrNoDownloadUrl;

  /// No description provided for @videoErrNotFound.
  ///
  /// In en, this message translates to:
  /// **'Video file not found on server — robot may need a direct connection for downloads'**
  String get videoErrNotFound;

  /// No description provided for @videoErrUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach robot for video download'**
  String get videoErrUnreachable;

  /// No description provided for @videoErrDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Video download failed'**
  String get videoErrDownloadFailed;

  /// No description provided for @videoErrEncodingTimeout.
  ///
  /// In en, this message translates to:
  /// **'Video encoding timed out — no response after {seconds}s'**
  String videoErrEncodingTimeout(int seconds);

  /// No description provided for @photoErrEmpty.
  ///
  /// In en, this message translates to:
  /// **'Received empty photo data'**
  String get photoErrEmpty;

  /// No description provided for @photoErrTimeout.
  ///
  /// In en, this message translates to:
  /// **'Photo capture timed out - no response from robot'**
  String get photoErrTimeout;

  /// No description provided for @webrtcErrTimeoutRetry.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out — tap to retry'**
  String get webrtcErrTimeoutRetry;

  /// No description provided for @webrtcErrFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get webrtcErrFailed;

  /// No description provided for @webrtcErrLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get webrtcErrLost;

  /// No description provided for @webrtcErrFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Connection failed - tap to retry'**
  String get webrtcErrFailedRetry;

  /// No description provided for @wifiErrScanFailed.
  ///
  /// In en, this message translates to:
  /// **'WiFi scan failed: {error}'**
  String wifiErrScanFailed(String error);

  /// No description provided for @wifiErrConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect: {error}'**
  String wifiErrConnectFailed(String error);

  /// No description provided for @missionsErrIncompleteData.
  ///
  /// In en, this message translates to:
  /// **'Robot sent incomplete mission data - check robot logs'**
  String get missionsErrIncompleteData;

  /// No description provided for @missionsErrAlreadyActive.
  ///
  /// In en, this message translates to:
  /// **'A mission is already active'**
  String get missionsErrAlreadyActive;

  /// No description provided for @missionsErrAlreadyActiveNamed.
  ///
  /// In en, this message translates to:
  /// **'A mission is already active ({name})'**
  String missionsErrAlreadyActiveNamed(String name);

  /// No description provided for @missionsErrStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Mission failed to start'**
  String get missionsErrStartFailed;

  /// No description provided for @missionsErrStopFirst.
  ///
  /// In en, this message translates to:
  /// **'Stop current mission first ({name})'**
  String missionsErrStopFirst(String name);

  /// No description provided for @missionsErrStartFailedRobot.
  ///
  /// In en, this message translates to:
  /// **'Mission failed to start on robot'**
  String get missionsErrStartFailedRobot;

  /// No description provided for @sgErrNotRunning.
  ///
  /// In en, this message translates to:
  /// **'Silent Guardian is not running'**
  String get sgErrNotRunning;

  /// No description provided for @weeklyErrUnknownDog.
  ///
  /// In en, this message translates to:
  /// **'Robot doesn\'t know this dog yet'**
  String get weeklyErrUnknownDog;

  /// No description provided for @historyErrLocalMode.
  ///
  /// In en, this message translates to:
  /// **'History not available in local mode'**
  String get historyErrLocalMode;

  /// No description provided for @historyErrNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get historyErrNotLoggedIn;

  /// No description provided for @historyErrLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load history: {error}'**
  String historyErrLoadFailed(String error);

  /// No description provided for @uploadErrFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Upload failed ({status})'**
  String uploadErrFailedStatus(String status);

  /// No description provided for @uploadErrTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File too large for server'**
  String get uploadErrTooLarge;

  /// No description provided for @uploadErrInvalidType.
  ///
  /// In en, this message translates to:
  /// **'Invalid file type - MP3 only'**
  String get uploadErrInvalidType;

  /// No description provided for @uploadErrNotAuthorized.
  ///
  /// In en, this message translates to:
  /// **'Not authorized to upload'**
  String get uploadErrNotAuthorized;

  /// No description provided for @uploadErrRobotOffline.
  ///
  /// In en, this message translates to:
  /// **'Robot offline'**
  String get uploadErrRobotOffline;

  /// No description provided for @uploadErrTimeout.
  ///
  /// In en, this message translates to:
  /// **'Upload timed out - try a smaller file'**
  String get uploadErrTimeout;

  /// No description provided for @uploadErrConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection error - check network'**
  String get uploadErrConnection;

  /// No description provided for @uploadErrFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get uploadErrFailed;

  /// No description provided for @uploadErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Upload error: {error}'**
  String uploadErrGeneric(String error);

  /// No description provided for @modelBehaviorDog.
  ///
  /// In en, this message translates to:
  /// **'Dog'**
  String get modelBehaviorDog;

  /// No description provided for @modelBehaviorSit.
  ///
  /// In en, this message translates to:
  /// **'Sit'**
  String get modelBehaviorSit;

  /// No description provided for @modelBehaviorLayDown.
  ///
  /// In en, this message translates to:
  /// **'Lay Down'**
  String get modelBehaviorLayDown;

  /// No description provided for @modelBehaviorCome.
  ///
  /// In en, this message translates to:
  /// **'Come'**
  String get modelBehaviorCome;

  /// No description provided for @modelBehaviorStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get modelBehaviorStay;

  /// No description provided for @modelBehaviorSpin.
  ///
  /// In en, this message translates to:
  /// **'Spin'**
  String get modelBehaviorSpin;

  /// No description provided for @modelBehaviorSpeak.
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get modelBehaviorSpeak;

  /// No description provided for @modelBehaviorBark.
  ///
  /// In en, this message translates to:
  /// **'Bark'**
  String get modelBehaviorBark;

  /// No description provided for @modelBehaviorQuiet.
  ///
  /// In en, this message translates to:
  /// **'Quiet'**
  String get modelBehaviorQuiet;

  /// No description provided for @modelRobotModeIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get modelRobotModeIdle;

  /// No description provided for @modelRobotModeManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get modelRobotModeManual;

  /// No description provided for @modelRobotModeSilentGuardian.
  ///
  /// In en, this message translates to:
  /// **'Silent Guardian'**
  String get modelRobotModeSilentGuardian;

  /// No description provided for @modelRobotModeCoach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get modelRobotModeCoach;

  /// No description provided for @modelRobotModeMission.
  ///
  /// In en, this message translates to:
  /// **'Mission'**
  String get modelRobotModeMission;

  /// No description provided for @modelRobotModeDocking.
  ///
  /// In en, this message translates to:
  /// **'Docking'**
  String get modelRobotModeDocking;

  /// No description provided for @modelDogColorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get modelDogColorBlack;

  /// No description provided for @modelDogColorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow/Golden'**
  String get modelDogColorYellow;

  /// No description provided for @modelDogColorBrown.
  ///
  /// In en, this message translates to:
  /// **'Brown/Chocolate'**
  String get modelDogColorBrown;

  /// No description provided for @modelDogColorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get modelDogColorWhite;

  /// No description provided for @modelDogColorMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed/Multi'**
  String get modelDogColorMixed;

  /// No description provided for @modelAgeYears.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year} other{{count} years}}'**
  String modelAgeYears(int count);

  /// No description provided for @modelAgeMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String modelAgeMonths(int count);

  /// No description provided for @modelVoiceCmdName.
  ///
  /// In en, this message translates to:
  /// **'Dog\'s Name'**
  String get modelVoiceCmdName;

  /// No description provided for @modelVoiceCmdPromptName.
  ///
  /// In en, this message translates to:
  /// **'Say your dog\'s name clearly'**
  String get modelVoiceCmdPromptName;

  /// No description provided for @modelVoiceCmdSit.
  ///
  /// In en, this message translates to:
  /// **'Sit'**
  String get modelVoiceCmdSit;

  /// No description provided for @modelVoiceCmdPromptSit.
  ///
  /// In en, this message translates to:
  /// **'Say \"Sit\" firmly'**
  String get modelVoiceCmdPromptSit;

  /// No description provided for @modelVoiceCmdStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get modelVoiceCmdStay;

  /// No description provided for @modelVoiceCmdPromptStay.
  ///
  /// In en, this message translates to:
  /// **'Say \"Stay\" with a steady tone'**
  String get modelVoiceCmdPromptStay;

  /// No description provided for @modelVoiceCmdLieDown.
  ///
  /// In en, this message translates to:
  /// **'Lay Down'**
  String get modelVoiceCmdLieDown;

  /// No description provided for @modelVoiceCmdPromptLieDown.
  ///
  /// In en, this message translates to:
  /// **'Say \"Lay Down\" or \"Down\"'**
  String get modelVoiceCmdPromptLieDown;

  /// No description provided for @modelVoiceCmdSpin.
  ///
  /// In en, this message translates to:
  /// **'Spin'**
  String get modelVoiceCmdSpin;

  /// No description provided for @modelVoiceCmdPromptSpin.
  ///
  /// In en, this message translates to:
  /// **'Say \"Spin\" enthusiastically'**
  String get modelVoiceCmdPromptSpin;

  /// No description provided for @modelVoiceCmdSpeak.
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get modelVoiceCmdSpeak;

  /// No description provided for @modelVoiceCmdPromptSpeak.
  ///
  /// In en, this message translates to:
  /// **'Say \"Speak\" enthusiastically'**
  String get modelVoiceCmdPromptSpeak;

  /// No description provided for @modelVoiceCmdCome.
  ///
  /// In en, this message translates to:
  /// **'Come'**
  String get modelVoiceCmdCome;

  /// No description provided for @modelVoiceCmdPromptCome.
  ///
  /// In en, this message translates to:
  /// **'Say \"Come\" or \"Come here\"'**
  String get modelVoiceCmdPromptCome;

  /// No description provided for @modelVoiceCmdTreat.
  ///
  /// In en, this message translates to:
  /// **'Want a treat?'**
  String get modelVoiceCmdTreat;

  /// No description provided for @modelVoiceCmdPromptTreat.
  ///
  /// In en, this message translates to:
  /// **'Say \"Want a treat?\" playfully'**
  String get modelVoiceCmdPromptTreat;

  /// No description provided for @modelVoiceCmdGoodDog.
  ///
  /// In en, this message translates to:
  /// **'Good dog!'**
  String get modelVoiceCmdGoodDog;

  /// No description provided for @modelVoiceCmdPromptGoodDog.
  ///
  /// In en, this message translates to:
  /// **'Say \"Good dog!\" with praise'**
  String get modelVoiceCmdPromptGoodDog;

  /// No description provided for @modelVoiceCmdNo.
  ///
  /// In en, this message translates to:
  /// **'No / Bad'**
  String get modelVoiceCmdNo;

  /// No description provided for @modelVoiceCmdPromptNo.
  ///
  /// In en, this message translates to:
  /// **'Say \"No\" or \"Bad\" firmly'**
  String get modelVoiceCmdPromptNo;

  /// No description provided for @modelVoiceCmdQuiet.
  ///
  /// In en, this message translates to:
  /// **'Quiet'**
  String get modelVoiceCmdQuiet;

  /// No description provided for @modelVoiceCmdPromptQuiet.
  ///
  /// In en, this message translates to:
  /// **'Say \"Quiet\" calmly but firmly'**
  String get modelVoiceCmdPromptQuiet;

  /// No description provided for @modelMissionStatusWaitingForDog.
  ///
  /// In en, this message translates to:
  /// **'Waiting for dog...'**
  String get modelMissionStatusWaitingForDog;

  /// No description provided for @modelMissionStatusGreeting.
  ///
  /// In en, this message translates to:
  /// **'Greeting...'**
  String get modelMissionStatusGreeting;

  /// No description provided for @modelMissionStatusCommand.
  ///
  /// In en, this message translates to:
  /// **'Commanding'**
  String get modelMissionStatusCommand;

  /// No description provided for @modelMissionStatusWatching.
  ///
  /// In en, this message translates to:
  /// **'Hold it...'**
  String get modelMissionStatusWatching;

  /// No description provided for @modelMissionStatusSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success!'**
  String get modelMissionStatusSuccess;

  /// No description provided for @modelMissionStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get modelMissionStatusFailed;

  /// No description provided for @modelMissionStatusRetry.
  ///
  /// In en, this message translates to:
  /// **'Trying again...'**
  String get modelMissionStatusRetry;

  /// No description provided for @modelMissionStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Complete!'**
  String get modelMissionStatusCompleted;

  /// No description provided for @modelMissionStatusStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get modelMissionStatusStopped;

  /// No description provided for @modelMissionWaitingForDog.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {dogName}...'**
  String modelMissionWaitingForDog(String dogName);

  /// No description provided for @modelMissionGreetingDog.
  ///
  /// In en, this message translates to:
  /// **'Greeting {dogName}...'**
  String modelMissionGreetingDog(String dogName);

  /// No description provided for @modelMissionStageOf.
  ///
  /// In en, this message translates to:
  /// **'Stage {stage} of {total}'**
  String modelMissionStageOf(int stage, int total);

  /// No description provided for @modelGuardianEventDogDetected.
  ///
  /// In en, this message translates to:
  /// **'Dog detected'**
  String get modelGuardianEventDogDetected;

  /// No description provided for @modelGuardianEventDogLeft.
  ///
  /// In en, this message translates to:
  /// **'Dog left frame'**
  String get modelGuardianEventDogLeft;

  /// No description provided for @modelGuardianEventBarking.
  ///
  /// In en, this message translates to:
  /// **'Barking detected'**
  String get modelGuardianEventBarking;

  /// No description provided for @modelGuardianEventTreatDispensed.
  ///
  /// In en, this message translates to:
  /// **'Treat dispensed'**
  String get modelGuardianEventTreatDispensed;

  /// No description provided for @modelGuardianEventBehaviorChange.
  ///
  /// In en, this message translates to:
  /// **'Behavior change'**
  String get modelGuardianEventBehaviorChange;

  /// No description provided for @modelGuardianEventMotionDetected.
  ///
  /// In en, this message translates to:
  /// **'Motion detected'**
  String get modelGuardianEventMotionDetected;

  /// No description provided for @modelGuardianEventQuietReward.
  ///
  /// In en, this message translates to:
  /// **'Quiet reward'**
  String get modelGuardianEventQuietReward;

  /// No description provided for @modelGuardianEventAlertTriggered.
  ///
  /// In en, this message translates to:
  /// **'Alert triggered'**
  String get modelGuardianEventAlertTriggered;

  /// No description provided for @modelGuardianEventUnknown.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get modelGuardianEventUnknown;

  /// No description provided for @modelGuardianEventWithDetails.
  ///
  /// In en, this message translates to:
  /// **'{label} - {details}'**
  String modelGuardianEventWithDetails(String label, String details);

  /// No description provided for @modelNotifTitleBark.
  ///
  /// In en, this message translates to:
  /// **'Barking Detected'**
  String get modelNotifTitleBark;

  /// No description provided for @modelNotifTitleSit.
  ///
  /// In en, this message translates to:
  /// **'Sitting Detected'**
  String get modelNotifTitleSit;

  /// No description provided for @modelNotifTitleLieDown.
  ///
  /// In en, this message translates to:
  /// **'Lay Down'**
  String get modelNotifTitleLieDown;

  /// No description provided for @modelNotifTitleStand.
  ///
  /// In en, this message translates to:
  /// **'Come'**
  String get modelNotifTitleStand;

  /// No description provided for @modelNotifTitleTreatDispensed.
  ///
  /// In en, this message translates to:
  /// **'Treat Dispensed'**
  String get modelNotifTitleTreatDispensed;

  /// No description provided for @modelNotifTitleMissionStarted.
  ///
  /// In en, this message translates to:
  /// **'Mission Started'**
  String get modelNotifTitleMissionStarted;

  /// No description provided for @modelNotifTitleMissionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mission Completed'**
  String get modelNotifTitleMissionCompleted;

  /// No description provided for @modelNotifTitleMissionFailed.
  ///
  /// In en, this message translates to:
  /// **'Mission Failed'**
  String get modelNotifTitleMissionFailed;

  /// No description provided for @modelNotifTitleLowBattery.
  ///
  /// In en, this message translates to:
  /// **'Low Battery'**
  String get modelNotifTitleLowBattery;

  /// No description provided for @modelNotifTitleAlert.
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get modelNotifTitleAlert;

  /// No description provided for @modelNotifTitleHappy.
  ///
  /// In en, this message translates to:
  /// **'Happy Dog'**
  String get modelNotifTitleHappy;

  /// No description provided for @modelNotifTitleConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get modelNotifTitleConnected;

  /// No description provided for @modelNotifTitleDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get modelNotifTitleDisconnected;

  /// No description provided for @modelNotifTitleCoachReward.
  ///
  /// In en, this message translates to:
  /// **'Coach Reward'**
  String get modelNotifTitleCoachReward;

  /// No description provided for @modelNotifTitlePanicAlert.
  ///
  /// In en, this message translates to:
  /// **'Panic Alert'**
  String get modelNotifTitlePanicAlert;

  /// No description provided for @modelNotifTitleSgSummary.
  ///
  /// In en, this message translates to:
  /// **'Guardian Summary'**
  String get modelNotifTitleSgSummary;

  /// No description provided for @modelNightOverrideAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get modelNightOverrideAuto;

  /// No description provided for @modelNightOverrideDay.
  ///
  /// In en, this message translates to:
  /// **'Day mode'**
  String get modelNightOverrideDay;

  /// No description provided for @modelNightOverrideNight.
  ///
  /// In en, this message translates to:
  /// **'Night mode'**
  String get modelNightOverrideNight;

  /// No description provided for @modelLuxDetecting.
  ///
  /// In en, this message translates to:
  /// **'detecting…'**
  String get modelLuxDetecting;

  /// No description provided for @modelLuxDark.
  ///
  /// In en, this message translates to:
  /// **'dark'**
  String get modelLuxDark;

  /// No description provided for @modelLuxDim.
  ///
  /// In en, this message translates to:
  /// **'dim'**
  String get modelLuxDim;

  /// No description provided for @modelLuxIndoor.
  ///
  /// In en, this message translates to:
  /// **'indoor lighting'**
  String get modelLuxIndoor;

  /// No description provided for @modelLuxWellLit.
  ///
  /// In en, this message translates to:
  /// **'well lit'**
  String get modelLuxWellLit;

  /// No description provided for @modelLuxBright.
  ///
  /// In en, this message translates to:
  /// **'bright'**
  String get modelLuxBright;

  /// No description provided for @modelControllerKindXbox.
  ///
  /// In en, this message translates to:
  /// **'Xbox'**
  String get modelControllerKindXbox;

  /// No description provided for @modelControllerKindPlaystation.
  ///
  /// In en, this message translates to:
  /// **'PlayStation'**
  String get modelControllerKindPlaystation;

  /// No description provided for @modelControllerKindEightBitDo.
  ///
  /// In en, this message translates to:
  /// **'8BitDo'**
  String get modelControllerKindEightBitDo;

  /// No description provided for @modelControllerKindGeneric.
  ///
  /// In en, this message translates to:
  /// **'Controller'**
  String get modelControllerKindGeneric;

  /// No description provided for @modelControllerHintXbox.
  ///
  /// In en, this message translates to:
  /// **'Hold the Xbox button, then hold the small Pair button on top until the light flashes quickly.'**
  String get modelControllerHintXbox;

  /// No description provided for @modelControllerHintPlaystation.
  ///
  /// In en, this message translates to:
  /// **'Hold the PS button + Share (or Create) button together until the light bar flashes.'**
  String get modelControllerHintPlaystation;

  /// No description provided for @modelControllerHintEightBitDo.
  ///
  /// In en, this message translates to:
  /// **'Set the controller to its Bluetooth mode, then hold Start (or the Pair button) until the LEDs flash.'**
  String get modelControllerHintEightBitDo;

  /// No description provided for @modelControllerHintGeneric.
  ///
  /// In en, this message translates to:
  /// **'Put the controller into Bluetooth pairing mode (usually a dedicated Pair button or a button-combo held until the light flashes), then wait for it to appear here.'**
  String get modelControllerHintGeneric;

  /// No description provided for @modelDetectionDogDetected.
  ///
  /// In en, this message translates to:
  /// **'Dog Detected'**
  String get modelDetectionDogDetected;

  /// No description provided for @modelVideoTierLow.
  ///
  /// In en, this message translates to:
  /// **'SD 480p'**
  String get modelVideoTierLow;

  /// No description provided for @modelVideoTierMedium.
  ///
  /// In en, this message translates to:
  /// **'540p'**
  String get modelVideoTierMedium;

  /// No description provided for @modelVideoTierHigh.
  ///
  /// In en, this message translates to:
  /// **'HD 720p'**
  String get modelVideoTierHigh;

  /// No description provided for @modelVideoQualityAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get modelVideoQualityAuto;

  /// No description provided for @modelVideoQualityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get modelVideoQualityLow;

  /// No description provided for @modelVideoQualityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get modelVideoQualityMedium;

  /// No description provided for @modelVideoQualityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get modelVideoQualityHigh;

  /// No description provided for @modelDaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get modelDaySun;

  /// No description provided for @modelDayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get modelDayMon;

  /// No description provided for @modelDayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get modelDayTue;

  /// No description provided for @modelDayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get modelDayWed;

  /// No description provided for @modelDayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get modelDayThu;

  /// No description provided for @modelDayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get modelDayFri;

  /// No description provided for @modelDaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get modelDaySat;

  /// No description provided for @modelScheduleOnceAt.
  ///
  /// In en, this message translates to:
  /// **'Once at {time}'**
  String modelScheduleOnceAt(String time);

  /// No description provided for @modelScheduleDailyAt.
  ///
  /// In en, this message translates to:
  /// **'Daily at {time}'**
  String modelScheduleDailyAt(String time);

  /// No description provided for @modelScheduleWeeklyAt.
  ///
  /// In en, this message translates to:
  /// **'Weekly at {time}'**
  String modelScheduleWeeklyAt(String time);

  /// No description provided for @modelScheduleEveryDayAt.
  ///
  /// In en, this message translates to:
  /// **'Every day at {time}'**
  String modelScheduleEveryDayAt(String time);

  /// No description provided for @modelScheduleDaysAt.
  ///
  /// In en, this message translates to:
  /// **'{days} at {time}'**
  String modelScheduleDaysAt(String days, String time);

  /// No description provided for @catalogMissionSit.
  ///
  /// In en, this message translates to:
  /// **'Sit'**
  String get catalogMissionSit;

  /// No description provided for @catalogMissionSitDesc.
  ///
  /// In en, this message translates to:
  /// **'Quick sit mission - wait for dog, then reward sit'**
  String get catalogMissionSitDesc;

  /// No description provided for @catalogMissionSitTraining.
  ///
  /// In en, this message translates to:
  /// **'Sit Training'**
  String get catalogMissionSitTraining;

  /// No description provided for @catalogMissionSitTrainingDesc.
  ///
  /// In en, this message translates to:
  /// **'Basic sit training - rewards dog for sitting behavior'**
  String get catalogMissionSitTrainingDesc;

  /// No description provided for @catalogMissionSitSustained.
  ///
  /// In en, this message translates to:
  /// **'Sit Sustained'**
  String get catalogMissionSitSustained;

  /// No description provided for @catalogMissionSitSustainedDesc.
  ///
  /// In en, this message translates to:
  /// **'Dog holds sit position for extended duration (30 seconds)'**
  String get catalogMissionSitSustainedDesc;

  /// No description provided for @catalogMissionDownSustained.
  ///
  /// In en, this message translates to:
  /// **'Lay Down Sustained'**
  String get catalogMissionDownSustained;

  /// No description provided for @catalogMissionDownSustainedDesc.
  ///
  /// In en, this message translates to:
  /// **'Dog holds lay down position for extended duration (30 seconds)'**
  String get catalogMissionDownSustainedDesc;

  /// No description provided for @catalogMissionComeAndSit.
  ///
  /// In en, this message translates to:
  /// **'Come and Sit'**
  String get catalogMissionComeAndSit;

  /// No description provided for @catalogMissionComeAndSitDesc.
  ///
  /// In en, this message translates to:
  /// **'Call the dog over, then ask for a sit'**
  String get catalogMissionComeAndSitDesc;

  /// No description provided for @catalogMissionTrainSitDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily Sit Training'**
  String get catalogMissionTrainSitDaily;

  /// No description provided for @catalogMissionTrainSitDailyDesc.
  ///
  /// In en, this message translates to:
  /// **'Daily sit training with progressive difficulty and limits'**
  String get catalogMissionTrainSitDailyDesc;

  /// No description provided for @catalogMissionLaydown.
  ///
  /// In en, this message translates to:
  /// **'Lay Down'**
  String get catalogMissionLaydown;

  /// No description provided for @catalogMissionLaydownDesc.
  ///
  /// In en, this message translates to:
  /// **'Quick lay down mission - wait for dog, then reward lay down'**
  String get catalogMissionLaydownDesc;

  /// No description provided for @catalogMissionComeTraining.
  ///
  /// In en, this message translates to:
  /// **'Come Training'**
  String get catalogMissionComeTraining;

  /// No description provided for @catalogMissionComeTrainingDesc.
  ///
  /// In en, this message translates to:
  /// **'Recall training - rewards dog for coming when called'**
  String get catalogMissionComeTrainingDesc;

  /// No description provided for @catalogMissionSpinTraining.
  ///
  /// In en, this message translates to:
  /// **'Spin Training'**
  String get catalogMissionSpinTraining;

  /// No description provided for @catalogMissionSpinTrainingDesc.
  ///
  /// In en, this message translates to:
  /// **'Spin trick training - rewards dog for spinning in a circle'**
  String get catalogMissionSpinTrainingDesc;

  /// No description provided for @catalogMissionSitAndSpeak.
  ///
  /// In en, this message translates to:
  /// **'Sit and Speak'**
  String get catalogMissionSitAndSpeak;

  /// No description provided for @catalogMissionSitAndSpeakDesc.
  ///
  /// In en, this message translates to:
  /// **'Train dog to sit and bark on command for treat'**
  String get catalogMissionSitAndSpeakDesc;

  /// No description provided for @catalogMissionSpeakMorning.
  ///
  /// In en, this message translates to:
  /// **'Speak Morning'**
  String get catalogMissionSpeakMorning;

  /// No description provided for @catalogMissionSpeakMorningDesc.
  ///
  /// In en, this message translates to:
  /// **'Dog barks on cue twice during morning (8am-12pm)'**
  String get catalogMissionSpeakMorningDesc;

  /// No description provided for @catalogMissionSpeakAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Speak Afternoon'**
  String get catalogMissionSpeakAfternoon;

  /// No description provided for @catalogMissionSpeakAfternoonDesc.
  ///
  /// In en, this message translates to:
  /// **'Dog barks on cue twice during afternoon (2pm-6pm)'**
  String get catalogMissionSpeakAfternoonDesc;

  /// No description provided for @catalogMissionAlertTraining.
  ///
  /// In en, this message translates to:
  /// **'Alert Training'**
  String get catalogMissionAlertTraining;

  /// No description provided for @catalogMissionAlertTrainingDesc.
  ///
  /// In en, this message translates to:
  /// **'Guard dog training - rewards dog for sitting and giving alert barks'**
  String get catalogMissionAlertTrainingDesc;

  /// No description provided for @catalogMissionBarkPrevention.
  ///
  /// In en, this message translates to:
  /// **'Bark Prevention'**
  String get catalogMissionBarkPrevention;

  /// No description provided for @catalogMissionBarkPreventionDesc.
  ///
  /// In en, this message translates to:
  /// **'Quiet training - reduces excessive barking behavior'**
  String get catalogMissionBarkPreventionDesc;

  /// No description provided for @catalogMissionStopBarking.
  ///
  /// In en, this message translates to:
  /// **'Stop Barking'**
  String get catalogMissionStopBarking;

  /// No description provided for @catalogMissionStopBarkingDesc.
  ///
  /// In en, this message translates to:
  /// **'Quiet training - reduces excessive barking with escalation'**
  String get catalogMissionStopBarkingDesc;

  /// No description provided for @catalogMissionQuietProgressive.
  ///
  /// In en, this message translates to:
  /// **'Quiet Progressive'**
  String get catalogMissionQuietProgressive;

  /// No description provided for @catalogMissionQuietProgressiveDesc.
  ///
  /// In en, this message translates to:
  /// **'Progressive quiet training - increasing quiet duration requirements'**
  String get catalogMissionQuietProgressiveDesc;

  /// No description provided for @catalogMissionComfortScared.
  ///
  /// In en, this message translates to:
  /// **'Comfort Scared'**
  String get catalogMissionComfortScared;

  /// No description provided for @catalogMissionComfortScaredDesc.
  ///
  /// In en, this message translates to:
  /// **'Comfort dog when scared or anxious barking detected'**
  String get catalogMissionComfortScaredDesc;

  /// No description provided for @catalogMissionMorningChill.
  ///
  /// In en, this message translates to:
  /// **'Morning Chill'**
  String get catalogMissionMorningChill;

  /// No description provided for @catalogMissionMorningChillDesc.
  ///
  /// In en, this message translates to:
  /// **'Dog maintains calm behavior during morning (8am-12pm)'**
  String get catalogMissionMorningChillDesc;

  /// No description provided for @catalogMissionMorningQuiet2hr.
  ///
  /// In en, this message translates to:
  /// **'Morning Quiet 2hr'**
  String get catalogMissionMorningQuiet2hr;

  /// No description provided for @catalogMissionMorningQuiet2hrDesc.
  ///
  /// In en, this message translates to:
  /// **'Dog maintains quiet for 2 hours during morning period (7am-1pm)'**
  String get catalogMissionMorningQuiet2hrDesc;

  /// No description provided for @catalogMissionAfternoonSit5.
  ///
  /// In en, this message translates to:
  /// **'Afternoon Sit 5'**
  String get catalogMissionAfternoonSit5;

  /// No description provided for @catalogMissionAfternoonSit5Desc.
  ///
  /// In en, this message translates to:
  /// **'Dog performs 5 sits during afternoon (12pm-7pm)'**
  String get catalogMissionAfternoonSit5Desc;

  /// No description provided for @catalogMissionAfternoonDown3.
  ///
  /// In en, this message translates to:
  /// **'Afternoon Lay Down 3'**
  String get catalogMissionAfternoonDown3;

  /// No description provided for @catalogMissionAfternoonDown3Desc.
  ///
  /// In en, this message translates to:
  /// **'Dog performs 3 lay downs during afternoon (12pm-6pm)'**
  String get catalogMissionAfternoonDown3Desc;

  /// No description provided for @catalogMissionEveningCalmTransition.
  ///
  /// In en, this message translates to:
  /// **'Evening Calm Transition'**
  String get catalogMissionEveningCalmTransition;

  /// No description provided for @catalogMissionEveningCalmTransitionDesc.
  ///
  /// In en, this message translates to:
  /// **'Help dog transition to quiet evening behavior (6pm-9pm)'**
  String get catalogMissionEveningCalmTransitionDesc;

  /// No description provided for @catalogMissionEveningSettle.
  ///
  /// In en, this message translates to:
  /// **'Evening Settle'**
  String get catalogMissionEveningSettle;

  /// No description provided for @catalogMissionEveningSettleDesc.
  ///
  /// In en, this message translates to:
  /// **'Dog settles down after dinner (5pm-9pm)'**
  String get catalogMissionEveningSettleDesc;

  /// No description provided for @catalogMissionNightQuiet90pct.
  ///
  /// In en, this message translates to:
  /// **'Night Quiet 90%'**
  String get catalogMissionNightQuiet90pct;

  /// No description provided for @catalogMissionNightQuiet90pctDesc.
  ///
  /// In en, this message translates to:
  /// **'Dog maintains 90% quiet overnight (7pm-4am)'**
  String get catalogMissionNightQuiet90pctDesc;

  /// No description provided for @catalogMissionDownTraining.
  ///
  /// In en, this message translates to:
  /// **'Down Training'**
  String get catalogMissionDownTraining;

  /// No description provided for @catalogMissionQuietTraining.
  ///
  /// In en, this message translates to:
  /// **'Quiet Training'**
  String get catalogMissionQuietTraining;

  /// No description provided for @catalogMissionStayTraining.
  ///
  /// In en, this message translates to:
  /// **'Stay Training'**
  String get catalogMissionStayTraining;

  /// No description provided for @catalogMissionStandTraining.
  ///
  /// In en, this message translates to:
  /// **'Stand Training'**
  String get catalogMissionStandTraining;

  /// No description provided for @catalogProgramPuppyBasics.
  ///
  /// In en, this message translates to:
  /// **'Puppy Basics'**
  String get catalogProgramPuppyBasics;

  /// No description provided for @catalogProgramPuppyBasicsDesc.
  ///
  /// In en, this message translates to:
  /// **'Foundation training: sit, down, and quiet behaviors'**
  String get catalogProgramPuppyBasicsDesc;

  /// No description provided for @catalogProgramObedience101.
  ///
  /// In en, this message translates to:
  /// **'Obedience 101'**
  String get catalogProgramObedience101;

  /// No description provided for @catalogProgramObedience101Desc.
  ///
  /// In en, this message translates to:
  /// **'Core commands every dog should know'**
  String get catalogProgramObedience101Desc;

  /// No description provided for @catalogProgramCalmDog.
  ///
  /// In en, this message translates to:
  /// **'Calm Dog'**
  String get catalogProgramCalmDog;

  /// No description provided for @catalogProgramCalmDogDesc.
  ///
  /// In en, this message translates to:
  /// **'Build patience and self-control'**
  String get catalogProgramCalmDogDesc;

  /// No description provided for @aiAssistantFallback.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get aiAssistantFallback;

  /// No description provided for @draftTranscriptProposed.
  ///
  /// In en, this message translates to:
  /// **'Proposed mission: {title}'**
  String draftTranscriptProposed(String title);

  /// No description provided for @draftTranscriptYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get draftTranscriptYou;

  /// No description provided for @draftTranscriptApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved \"{title}\"'**
  String draftTranscriptApproved(String title);

  /// No description provided for @draftTranscriptDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined \"{title}\"'**
  String draftTranscriptDeclined(String title);

  /// No description provided for @aiErrSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage connected assistants'**
  String get aiErrSignedOut;

  /// No description provided for @aiErrLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load connected assistants'**
  String get aiErrLoadFailed;

  /// No description provided for @aiErrRevokeFailed.
  ///
  /// In en, this message translates to:
  /// **'Revoke failed'**
  String get aiErrRevokeFailed;

  /// No description provided for @notifMissionDraft.
  ///
  /// In en, this message translates to:
  /// **'Mission approval'**
  String get notifMissionDraft;

  /// No description provided for @notifMissionDraftFrom.
  ///
  /// In en, this message translates to:
  /// **'{name} proposed a mission'**
  String notifMissionDraftFrom(String name);

  /// No description provided for @notifPrefsMissionDraft.
  ///
  /// In en, this message translates to:
  /// **'Mission approval requests'**
  String get notifPrefsMissionDraft;

  /// No description provided for @modelNotifTitleMissionDraft.
  ///
  /// In en, this message translates to:
  /// **'Mission Approval'**
  String get modelNotifTitleMissionDraft;

  /// No description provided for @draftApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get draftApprove;

  /// No description provided for @draftDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get draftDecline;

  /// No description provided for @draftStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get draftStatusApproved;

  /// No description provided for @draftStatusDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get draftStatusDeclined;

  /// No description provided for @draftStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get draftStatusExpired;

  /// No description provided for @attachmentOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load media'**
  String get attachmentOpenFailed;

  /// No description provided for @todayCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayCardTitle;

  /// No description provided for @todayCardLocalCounts.
  ///
  /// In en, this message translates to:
  /// **'Counts from this phone\'s activity feed'**
  String get todayCardLocalCounts;

  /// No description provided for @todayCardError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the summary service'**
  String get todayCardError;

  /// No description provided for @todayStatBarks.
  ///
  /// In en, this message translates to:
  /// **'Barks'**
  String get todayStatBarks;

  /// No description provided for @todayStatTreats.
  ///
  /// In en, this message translates to:
  /// **'Treats'**
  String get todayStatTreats;

  /// No description provided for @todayStatCoaching.
  ///
  /// In en, this message translates to:
  /// **'Coaching'**
  String get todayStatCoaching;

  /// No description provided for @todayStatQuiet.
  ///
  /// In en, this message translates to:
  /// **'Quiet'**
  String get todayStatQuiet;

  /// No description provided for @todayStatGuardian.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get todayStatGuardian;

  /// No description provided for @todayPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get todayPlanTitle;

  /// No description provided for @todayPlanBy.
  ///
  /// In en, this message translates to:
  /// **'Plan by {source}'**
  String todayPlanBy(String source);

  /// No description provided for @todayHighlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get todayHighlights;

  /// No description provided for @connectedAiTitle.
  ///
  /// In en, this message translates to:
  /// **'Connected AI'**
  String get connectedAiTitle;

  /// No description provided for @connectedAiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Assistants, connector URL, kill switch, audit log'**
  String get connectedAiSubtitle;

  /// No description provided for @aiConnectorUrl.
  ///
  /// In en, this message translates to:
  /// **'Connector URL'**
  String get aiConnectorUrl;

  /// No description provided for @aiConnectorUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'Connector URL copied'**
  String get aiConnectorUrlCopied;

  /// No description provided for @aiConnectorUrlMissing.
  ///
  /// In en, this message translates to:
  /// **'Not issued yet'**
  String get aiConnectorUrlMissing;

  /// No description provided for @aiCopyUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get aiCopyUrl;

  /// No description provided for @aiAssistantsHeader.
  ///
  /// In en, this message translates to:
  /// **'Connected assistants'**
  String get aiAssistantsHeader;

  /// No description provided for @aiNoAssistants.
  ///
  /// In en, this message translates to:
  /// **'No assistant connected yet'**
  String get aiNoAssistants;

  /// No description provided for @aiRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get aiRevoke;

  /// No description provided for @aiRevokeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Revoke {name}? It loses access immediately.'**
  String aiRevokeConfirm(String name);

  /// No description provided for @aiLastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last used {when}'**
  String aiLastUsed(String when);

  /// No description provided for @aiNeverUsed.
  ///
  /// In en, this message translates to:
  /// **'Never used'**
  String get aiNeverUsed;

  /// No description provided for @aiScopesNone.
  ///
  /// In en, this message translates to:
  /// **'no scopes'**
  String get aiScopesNone;

  /// No description provided for @aiAuditHeader.
  ///
  /// In en, this message translates to:
  /// **'Audit log'**
  String get aiAuditHeader;

  /// No description provided for @aiAuditEmpty.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get aiAuditEmpty;

  /// No description provided for @aiSetupGuides.
  ///
  /// In en, this message translates to:
  /// **'Setup guides'**
  String get aiSetupGuides;

  /// No description provided for @aiUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Connected AI isn\'t available on this server yet'**
  String get aiUnsupported;

  /// No description provided for @aiGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect {name}'**
  String aiGuideTitle(String name);

  /// No description provided for @aiGuideStep1.
  ///
  /// In en, this message translates to:
  /// **'Open {name} and go to Settings → Connectors (or Tools).'**
  String aiGuideStep1(String name);

  /// No description provided for @aiGuideStep2.
  ///
  /// In en, this message translates to:
  /// **'Choose Add custom connector / MCP server.'**
  String get aiGuideStep2;

  /// No description provided for @aiGuideStep3.
  ///
  /// In en, this message translates to:
  /// **'Paste the WIM-Z connector URL below.'**
  String get aiGuideStep3;

  /// No description provided for @aiGuideStep4.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your WIM-Z account and allow the scopes you want.'**
  String get aiGuideStep4;

  /// No description provided for @aiGuideStep5.
  ///
  /// In en, this message translates to:
  /// **'Ask {name}: \"How was my dog today?\" It appears in the list once connected.'**
  String aiGuideStep5(String name);

  /// No description provided for @aiGuideNoteChatgpt.
  ///
  /// In en, this message translates to:
  /// **'ChatGPT: turn on Developer mode under Settings → Connectors → Advanced first.'**
  String get aiGuideNoteChatgpt;

  /// No description provided for @aiGuideNoteClaude.
  ///
  /// In en, this message translates to:
  /// **'Claude: Settings → Connectors → Add custom connector (claude.ai, Pro/Max/Team).'**
  String get aiGuideNoteClaude;

  /// No description provided for @aiGuideNoteGrok.
  ///
  /// In en, this message translates to:
  /// **'Grok: Settings → Connectors → Add MCP server (grok.com).'**
  String get aiGuideNoteGrok;

  /// No description provided for @aiGuideNotePerplexity.
  ///
  /// In en, this message translates to:
  /// **'Perplexity: Settings → Connectors → Add connector (Pro/Max).'**
  String get aiGuideNotePerplexity;

  /// No description provided for @settingsSectionAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsSectionAdvanced;

  /// No description provided for @settingsAdvancedMode.
  ///
  /// In en, this message translates to:
  /// **'Advanced mode'**
  String get settingsAdvancedMode;

  /// No description provided for @settingsAdvancedModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show every sound id with replace-from-phone'**
  String get settingsAdvancedModeSubtitle;

  /// No description provided for @settingsSoundsAll.
  ///
  /// In en, this message translates to:
  /// **'All sounds'**
  String get settingsSoundsAll;

  /// No description provided for @settingsSoundsAllSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replace any robot sound from this phone'**
  String get settingsSoundsAllSubtitle;

  /// No description provided for @settingsResetSounds.
  ///
  /// In en, this message translates to:
  /// **'Reset sounds to factory default'**
  String get settingsResetSounds;

  /// No description provided for @settingsResetSoundsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restores every greeting, cue, alert and music sound'**
  String get settingsResetSoundsSubtitle;

  /// No description provided for @settingsResetSoundsConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset all sounds?'**
  String get settingsResetSoundsConfirmTitle;

  /// No description provided for @settingsResetSoundsConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Every custom sound on the robot is replaced by the factory file. This can\'t be undone.'**
  String get settingsResetSoundsConfirmBody;

  /// No description provided for @settingsResetSoundsDone.
  ///
  /// In en, this message translates to:
  /// **'Sounds reset to factory default'**
  String get settingsResetSoundsDone;

  /// No description provided for @settingsResetSoundsFailed.
  ///
  /// In en, this message translates to:
  /// **'Reset failed: {error}'**
  String settingsResetSoundsFailed(String error);

  /// No description provided for @soundsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sounds'**
  String get soundsTitle;

  /// No description provided for @soundsReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get soundsReplace;

  /// No description provided for @soundsFactory.
  ///
  /// In en, this message translates to:
  /// **'Factory'**
  String get soundsFactory;

  /// No description provided for @soundsCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get soundsCustom;

  /// No description provided for @soundsReplaced.
  ///
  /// In en, this message translates to:
  /// **'Replaced {id}'**
  String soundsReplaced(String id);

  /// No description provided for @soundsReplaceFailed.
  ///
  /// In en, this message translates to:
  /// **'Replace failed: {error}'**
  String soundsReplaceFailed(String error);

  /// No description provided for @soundsRestoreOne.
  ///
  /// In en, this message translates to:
  /// **'Restore factory sound'**
  String get soundsRestoreOne;

  /// No description provided for @soundsCatalogFromRobot.
  ///
  /// In en, this message translates to:
  /// **'Sound library from the server'**
  String get soundsCatalogFromRobot;

  /// No description provided for @soundsCatalogDefault.
  ///
  /// In en, this message translates to:
  /// **'Default library (server didn\'t answer)'**
  String get soundsCatalogDefault;

  /// No description provided for @soundGroupGreeting.
  ///
  /// In en, this message translates to:
  /// **'Greeting'**
  String get soundGroupGreeting;

  /// No description provided for @soundGroupTreat.
  ///
  /// In en, this message translates to:
  /// **'Treat'**
  String get soundGroupTreat;

  /// No description provided for @soundGroupCue.
  ///
  /// In en, this message translates to:
  /// **'Cues'**
  String get soundGroupCue;

  /// No description provided for @soundGroupAlert.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get soundGroupAlert;

  /// No description provided for @soundGroupSgLevel.
  ///
  /// In en, this message translates to:
  /// **'Silent Guardian levels'**
  String get soundGroupSgLevel;

  /// No description provided for @soundGroupMusic.
  ///
  /// In en, this message translates to:
  /// **'Music classes'**
  String get soundGroupMusic;

  /// No description provided for @songUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload song'**
  String get songUploadTitle;

  /// No description provided for @settingsSongUploadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send a public-domain recording to the robot'**
  String get settingsSongUploadSubtitle;

  /// No description provided for @songUploadPdNotice.
  ///
  /// In en, this message translates to:
  /// **'Only upload recordings you have the right to use — public domain or your own.'**
  String get songUploadPdNotice;

  /// No description provided for @songUploadPdCheckbox.
  ///
  /// In en, this message translates to:
  /// **'This recording is public domain or mine'**
  String get songUploadPdCheckbox;

  /// No description provided for @songUploadChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose song'**
  String get songUploadChoose;

  /// No description provided for @songUploadFormats.
  ///
  /// In en, this message translates to:
  /// **'MP3 or WAV · up to 5 MB'**
  String get songUploadFormats;

  /// No description provided for @songUploadUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading {name}…'**
  String songUploadUploading(String name);

  /// No description provided for @songUploadDone.
  ///
  /// In en, this message translates to:
  /// **'Uploaded {name}'**
  String songUploadDone(String name);

  /// No description provided for @songUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String songUploadFailed(String error);

  /// No description provided for @songUploadTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File is over 5 MB'**
  String get songUploadTooLarge;

  /// No description provided for @songUploadNoDog.
  ///
  /// In en, this message translates to:
  /// **'Select a dog first'**
  String get songUploadNoDog;

  /// No description provided for @songUploadNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to upload'**
  String get songUploadNotSignedIn;

  /// No description provided for @songUploadPlayHint.
  ///
  /// In en, this message translates to:
  /// **'Play it from the Music button on Home.'**
  String get songUploadPlayHint;

  /// No description provided for @settingsSectionDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get settingsSectionDemo;

  /// No description provided for @demoViewTitle.
  ///
  /// In en, this message translates to:
  /// **'Demo view'**
  String get demoViewTitle;

  /// No description provided for @demoViewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Screen-mirror layout: today, guardian, agent transcript'**
  String get demoViewSubtitle;

  /// No description provided for @demoPanelGuardian.
  ///
  /// In en, this message translates to:
  /// **'Silent Guardian'**
  String get demoPanelGuardian;

  /// No description provided for @demoPanelTranscript.
  ///
  /// In en, this message translates to:
  /// **'Agent transcript'**
  String get demoPanelTranscript;

  /// No description provided for @demoTranscriptEmpty.
  ///
  /// In en, this message translates to:
  /// **'Waiting for an assistant…'**
  String get demoTranscriptEmpty;

  /// No description provided for @demoNoDog.
  ///
  /// In en, this message translates to:
  /// **'Select a dog on Home first'**
  String get demoNoDog;

  /// No description provided for @demoSgIdle.
  ///
  /// In en, this message translates to:
  /// **'Guardian not running'**
  String get demoSgIdle;

  /// No description provided for @aiErrNoDog.
  ///
  /// In en, this message translates to:
  /// **'Select a dog first'**
  String get aiErrNoDog;

  /// No description provided for @aiErrRevokeAllFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t disconnect assistants'**
  String get aiErrRevokeAllFailed;

  /// No description provided for @aiDisconnectAll.
  ///
  /// In en, this message translates to:
  /// **'Disconnect all assistants'**
  String get aiDisconnectAll;

  /// No description provided for @aiDisconnectAllSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Kill switch: every assistant loses access now and must be re-authorized'**
  String get aiDisconnectAllSubtitle;

  /// No description provided for @aiDisconnectAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Disconnect every assistant? They lose access immediately and have to be connected again.'**
  String get aiDisconnectAllConfirm;

  /// No description provided for @aiDisconnectAllDone.
  ///
  /// In en, this message translates to:
  /// **'{count} tokens revoked'**
  String aiDisconnectAllDone(int count);

  /// No description provided for @draftActorVoiceAgent.
  ///
  /// In en, this message translates to:
  /// **'WIM-Z voice agent'**
  String get draftActorVoiceAgent;

  /// No description provided for @draftTriggerDeparture.
  ///
  /// In en, this message translates to:
  /// **'Starts after you leave'**
  String get draftTriggerDeparture;

  /// No description provided for @draftTriggerSchedule.
  ///
  /// In en, this message translates to:
  /// **'Daily at {time}'**
  String draftTriggerSchedule(String time);

  /// No description provided for @draftTriggerManual.
  ///
  /// In en, this message translates to:
  /// **'Started manually'**
  String get draftTriggerManual;

  /// No description provided for @draftDurationReward.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min · {treats} treats'**
  String draftDurationReward(int minutes, int treats);

  /// No description provided for @todayStatSettle.
  ///
  /// In en, this message translates to:
  /// **'Settle'**
  String get todayStatSettle;

  /// No description provided for @todayStatPacing.
  ///
  /// In en, this message translates to:
  /// **'Pacing'**
  String get todayStatPacing;

  /// No description provided for @todayStatMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get todayStatMusic;

  /// No description provided for @todayStatAlone.
  ///
  /// In en, this message translates to:
  /// **'Alone'**
  String get todayStatAlone;

  /// No description provided for @todayStatMissions.
  ///
  /// In en, this message translates to:
  /// **'Missions'**
  String get todayStatMissions;

  /// No description provided for @todayEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Top bark episodes'**
  String get todayEpisodes;

  /// No description provided for @todayEpisodeLine.
  ///
  /// In en, this message translates to:
  /// **'{barks} barks · {duration}'**
  String todayEpisodeLine(int barks, String duration);

  /// No description provided for @todayEpisodeSettled.
  ///
  /// In en, this message translates to:
  /// **'settled in {duration}'**
  String todayEpisodeSettled(String duration);

  /// No description provided for @todayCardEmptyRelay.
  ///
  /// In en, this message translates to:
  /// **'No events on the relay yet today — counts from this phone'**
  String get todayCardEmptyRelay;

  /// No description provided for @soundsFormats.
  ///
  /// In en, this message translates to:
  /// **'MP3 or WAV · up to 5 MB'**
  String get soundsFormats;

  /// No description provided for @soundGroupSong.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get soundGroupSong;

  /// No description provided for @robotCardLocal.
  ///
  /// In en, this message translates to:
  /// **'Connected directly to the robot'**
  String get robotCardLocal;

  /// No description provided for @robotCardNonePaired.
  ///
  /// In en, this message translates to:
  /// **'No robot paired'**
  String get robotCardNonePaired;

  /// No description provided for @robotCardNoneBody.
  ///
  /// In en, this message translates to:
  /// **'Pairing is optional — pair a robot whenever you\'re ready.'**
  String get robotCardNoneBody;

  /// No description provided for @robotCardPair.
  ///
  /// In en, this message translates to:
  /// **'Pair a robot'**
  String get robotCardPair;

  /// No description provided for @robotCardManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get robotCardManage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
