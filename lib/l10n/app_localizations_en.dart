// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'WIM-Z';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get ok => 'OK';

  @override
  String get done => 'Done';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get back => 'Back';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get confirm => 'Confirm';

  @override
  String get remove => 'Remove';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get unknown => 'Unknown';

  @override
  String get on => 'On';

  @override
  String get off => 'Off';

  @override
  String get enabled => 'Enabled';

  @override
  String get disabled => 'Disabled';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get connecting => 'Connecting...';

  @override
  String get settings => 'Settings';

  @override
  String get signOut => 'Sign Out';

  @override
  String get none => 'None';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get language => 'Language';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKorean => '한국어 (Korean)';

  @override
  String get languageSubtitle => 'Choose the app display language';

  @override
  String get appRateLimited => 'Too many commands, slow down';

  @override
  String get appReconnecting => 'Reconnecting...';

  @override
  String get appTapToRetry => 'Tap to retry';

  @override
  String get navHome => 'Home';

  @override
  String get navDogs => 'Dogs';

  @override
  String get navMissions => 'Missions';

  @override
  String get navPhotos => 'Photos';

  @override
  String get navActivity => 'Activity';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get quickActionsSongFallback => 'song';

  @override
  String get quickActionsFileFallback => 'file';

  @override
  String quickActionsDeleted(String filename) {
    return 'Deleted \"$filename\"';
  }

  @override
  String quickActionsDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String quickActionsUploaded(String filename) {
    return 'Uploaded \"$filename\" successfully';
  }

  @override
  String quickActionsUploadFailed(String error) {
    return 'Upload failed: $error';
  }

  @override
  String get quickActionsTreat => 'Treat';

  @override
  String get quickActionsGood => 'Good';

  @override
  String get quickActionsCallDog => 'Call Dog';

  @override
  String get quickActionsWant => 'Want?';

  @override
  String get quickActionsNo => 'No';

  @override
  String get quickActionsQuiet => 'Quiet';

  @override
  String get quickActionsSit => 'Sit';

  @override
  String quickActionsLedPattern(String pattern) {
    return 'LED: $pattern';
  }

  @override
  String get quickActionsLedNotSent => 'Not connected — LED not sent';

  @override
  String get quickActionsSelectMp3 => 'Please select an MP3 file';

  @override
  String get quickActionsFileAccessFailed => 'Could not access file';

  @override
  String get quickActionsFileTooLarge => 'File too large (max 20MB)';

  @override
  String get quickActionsUploadLocalUnavailable =>
      'Music upload not available in local mode';

  @override
  String get quickActionsNotAuthenticated => 'Not authenticated - please login';

  @override
  String quickActionsUploading(String filename) {
    return 'Uploading \"$filename\"...';
  }

  @override
  String quickActionsFilePickerFailed(String error) {
    return 'Could not open file picker: $error';
  }

  @override
  String get quickActionsSelectDogFirst => 'Please select a dog first';

  @override
  String get quickActionsDeleteSongTitle => 'Delete Song';

  @override
  String quickActionsDeleteSongConfirm(String name) {
    return 'Delete \"$name\" from the playlist?';
  }

  @override
  String quickActionsDeletingSong(String name) {
    return 'Deleting \"$name\"...';
  }

  @override
  String get ledPatternRainbow => 'Rainbow';

  @override
  String get ledPatternFire => 'Fire';

  @override
  String get ledPatternBlue => 'Blue';

  @override
  String get ledPatternChase => 'Chase';

  @override
  String get ledPatternAmbient => 'Ambient';

  @override
  String get quickActionsLighting => 'Lighting';

  @override
  String get quickActionsBluLight => 'BluLight';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get pttTalk => 'Talk';

  @override
  String get pttRecording => 'Recording';

  @override
  String get pttSent => 'Sent ✓';

  @override
  String pttSeconds(int sec) {
    return '${sec}s';
  }

  @override
  String get pttSending => 'Sending...';

  @override
  String get pttPlaying => 'Playing...';

  @override
  String get pttListening => 'Listening...';

  @override
  String get pttTapToListen => 'Tap to listen';

  @override
  String panTiltPan(String value) {
    return 'P:$value';
  }

  @override
  String panTiltTilt(String value) {
    return 'T:$value';
  }

  @override
  String get panTiltCenter => 'Center';

  @override
  String get audioMuteListening => 'Listening to robot...';

  @override
  String get audioMuteUnmute => 'Unmute audio';

  @override
  String get audioMuteMute => 'Mute audio';

  @override
  String get mjpegUnavailable => 'Video unavailable';

  @override
  String get mjpegConnecting => 'Connecting to camera...';

  @override
  String get videoHudFps => 'FPS';

  @override
  String get videoHudBattery => 'BAT';

  @override
  String get videoHudPan => 'PAN';

  @override
  String get videoHudRec => 'REC';

  @override
  String get videoSavedNotWired =>
      'Available once the robot ships recording download (Chain REC)';

  @override
  String get videoSavedSampleData => 'SAMPLE DATA — not live';

  @override
  String get videoSavedTitle => 'Video saved';

  @override
  String get videoSavedOnRobotAt => 'SAVED ON ROBOT AT';

  @override
  String get videoSavedPathCopied => 'Path copied';

  @override
  String videoSavedRetention(String retentionClass) {
    return 'retention: $retentionClass';
  }

  @override
  String get videoSavedSaveToPhone => 'Save to Phone';

  @override
  String get videoSavedShare => 'Share';

  @override
  String get webrtcWaitingForConnection => 'Waiting for connection...';

  @override
  String get webrtcTapToConnect => 'Tap to connect';

  @override
  String get webrtcConnectingVideo => 'Connecting video...';

  @override
  String get webrtcConnectionFailed => 'Video connection failed';

  @override
  String get webrtcInitializingRenderer => 'Initializing renderer...';

  @override
  String get webrtcWaitingForStream => 'Waiting for video stream...';

  @override
  String get webrtcReceivingVideo => 'Receiving video...';

  @override
  String get videoSavedToGallery => 'Video saved to gallery!';

  @override
  String get videoSavedShort => 'Video saved!';

  @override
  String get photoSavedToGallery => 'Photo saved to gallery!';

  @override
  String get photoSavedShort => 'Photo saved!';

  @override
  String get gaugeCharging => 'CHARGING';

  @override
  String get gaugeBattery => 'BATTERY';

  @override
  String get gaugeLeft => 'L';

  @override
  String get gaugeRight => 'R';

  @override
  String get schedulerTitle => 'Training Scheduler';

  @override
  String get schedulerAddSchedule => 'Add Schedule';

  @override
  String get schedulerAutoScheduler => 'Auto-Scheduler';

  @override
  String get schedulerRunsAutomatically => 'Training runs automatically';

  @override
  String get schedulerPaused => 'Schedules paused';

  @override
  String get schedulerEmptyTitle => 'No Scheduled Training';

  @override
  String get schedulerEmptyBody =>
      'Schedule automatic training sessions\nfor your dog at specific times';

  @override
  String get schedulerDeleteTitle => 'Delete Schedule';

  @override
  String get schedulerDeleteConfirm =>
      'Are you sure you want to delete this schedule?';

  @override
  String get schedulerUnknownDog => 'Unknown Dog';

  @override
  String get schedulerPausedBadge => 'PAUSED';

  @override
  String schedulerNextRun(String next) {
    return 'Next: $next';
  }

  @override
  String get scheduleEditSelectDogAndMission =>
      'Please select a dog and mission';

  @override
  String get scheduleEditSelectOneDay => 'Please select at least one day';

  @override
  String get scheduleEditMissionNotFound => 'Selected mission not found';

  @override
  String get scheduleEditUpdated => 'Schedule updated';

  @override
  String get scheduleEditCreated => 'Schedule created';

  @override
  String get scheduleEditUpdateFailed => 'Failed to update schedule';

  @override
  String get scheduleEditCreateFailed => 'Failed to create schedule';

  @override
  String get scheduleEditTitleEdit => 'Edit Schedule';

  @override
  String get scheduleEditTitleNew => 'New Schedule';

  @override
  String get scheduleEditSectionDog => 'Dog';

  @override
  String get scheduleEditSelectDog => 'Select a dog';

  @override
  String get scheduleEditSectionMission => 'Training Mission';

  @override
  String get scheduleEditSelectMission => 'Select a mission';

  @override
  String get scheduleEditSectionTime => 'Time';

  @override
  String get scheduleEditSectionRepeat => 'Repeat';

  @override
  String get scheduleEditOnce => 'Once';

  @override
  String get scheduleEditDaily => 'Daily';

  @override
  String get scheduleEditWeekly => 'Weekly';

  @override
  String get scheduleEditWeekdayLetters => 'S,M,T,W,T,F,S';

  @override
  String get missionsTitle => 'Training';

  @override
  String get missionsProgramsHeader => 'Training Programs';

  @override
  String get missionsProgramsSubtitle =>
      'Multi-mission sequences with rest periods';

  @override
  String get missionsIndividualHeader => 'Individual Missions';

  @override
  String get missionsIndividualSubtitle => 'Single training sessions';

  @override
  String get missionsNoneConfigured => 'No missions configured';

  @override
  String get missionsActiveBadge => 'ACTIVE';

  @override
  String get missionsDriveButton => 'DRIVE';

  @override
  String get missionsStop => 'Stop';

  @override
  String missionsPercentComplete(int percent) {
    return '$percent% complete';
  }

  @override
  String missionsCountChip(int count) {
    return '$count missions';
  }

  @override
  String missionsRestChip(int seconds) {
    return '${seconds}s rest';
  }

  @override
  String get missionsProgramBadge => 'PROGRAM';

  @override
  String missionsRestBreak(int seconds) {
    return 'Rest break: ${seconds}s';
  }

  @override
  String missionsMissionOf(int current, int total) {
    return 'Mission $current of $total';
  }

  @override
  String get missionsCoachMode => 'Coach Mode';

  @override
  String get missionsCoachWatching => 'Watching for good behaviors...';

  @override
  String get missionsCoachSubtitle =>
      'Auto-reward when your dog performs tricks';

  @override
  String get missionDetailTitle => 'Mission';

  @override
  String get missionDetailNotFound => 'Mission not found';

  @override
  String get missionDetailSectionDetails => 'Mission Details';

  @override
  String get missionDetailTargetBehavior => 'Target Behavior';

  @override
  String get missionDetailHoldDuration => 'Hold Duration';

  @override
  String missionDetailSecondsShort(String seconds) {
    return '${seconds}s';
  }

  @override
  String get missionDetailCooldown => 'Cooldown';

  @override
  String missionDetailCooldownValue(int seconds) {
    return '${seconds}s between rewards';
  }

  @override
  String get missionDetailDailyLimit => 'Daily Limit';

  @override
  String missionDetailTreatsCount(int count) {
    return '$count treats';
  }

  @override
  String get missionDetailProgress => 'Progress';

  @override
  String missionDetailTreatsGiven(int given, int limit) {
    return '$given/$limit treats given';
  }

  @override
  String get missionDetailHowItWorks => 'How It Works';

  @override
  String missionDetailBulletWatches(String behavior) {
    return 'WIM-Z watches for the \"$behavior\" behavior';
  }

  @override
  String missionDetailBulletHold(String seconds) {
    return 'Dog must hold for $seconds seconds';
  }

  @override
  String get missionDetailBulletTreat =>
      'Treat is dispensed automatically on success';

  @override
  String missionDetailBulletCooldown(int seconds) {
    return '${seconds}s cooldown between rewards';
  }

  @override
  String missionDetailBulletLimit(int count) {
    return 'Up to $count treats per session';
  }

  @override
  String get missionDetailStopMission => 'Stop Mission';

  @override
  String get missionDetailRobotNotConnected => 'Robot Not Connected';

  @override
  String get missionDetailAnotherActive => 'Another Mission Active';

  @override
  String get missionDetailStarting => 'Starting...';

  @override
  String get missionDetailStartMission => 'Start Mission';

  @override
  String get programTitle => 'Program';

  @override
  String get programNotFound => 'Program not found';

  @override
  String get programStop => 'Stop Program';

  @override
  String get programMissionSequence => 'Mission Sequence';

  @override
  String get programRunningBadge => 'RUNNING';

  @override
  String get programRestBreak => 'Rest Break';

  @override
  String programSecondsUntilNext(int seconds) {
    return '$seconds seconds until next mission';
  }

  @override
  String programPercentThrough(int percent) {
    return '$percent% through program';
  }

  @override
  String get programNowBadge => 'NOW';

  @override
  String get programDetails => 'Program Details';

  @override
  String get programTotalMissions => 'Total Missions';

  @override
  String get programRestBetween => 'Rest Between Missions';

  @override
  String programSecondsValue(int seconds) {
    return '$seconds seconds';
  }

  @override
  String get programEstimatedTime => 'Estimated Time';

  @override
  String programMinutesRange(int min, int max) {
    return '$min-$max minutes';
  }

  @override
  String programStartWith(String dog) {
    return 'Start with $dog';
  }

  @override
  String get programStart => 'Start Program';

  @override
  String get programConnectToStart => 'Connect to robot to start';

  @override
  String get programStopCurrentFirst => 'Stop current training first';

  @override
  String get coachCoachingBadge => 'COACHING';

  @override
  String get coachStoppedBadge => 'STOPPED';

  @override
  String get coachDogDetected => 'Dog Detected';

  @override
  String get coachWhenDogVisible => 'When dog visible:';

  @override
  String get coachSelectDogHint =>
      'Select a dog or wait for the camera to identify one.';

  @override
  String get coachExit => 'Exit Coach Mode';

  @override
  String get coachGoodBang => 'GOOD!';

  @override
  String coachBehaviorBang(String behavior) {
    return '$behavior!';
  }

  @override
  String get historyTitle => 'Training History';

  @override
  String get historyTimeRange => 'Time Range';

  @override
  String get historyLast7Days => 'Last 7 days';

  @override
  String get historyLast2Weeks => 'Last 2 weeks';

  @override
  String get historyLastMonth => 'Last month';

  @override
  String get historyDogFilter => 'Dog';

  @override
  String get historyAllDogs => 'All Dogs';

  @override
  String get historyStatSessions => 'Sessions';

  @override
  String get historyStatCompleted => 'Completed';

  @override
  String get historyStatTreats => 'Treats';

  @override
  String get historyStatSuccess => 'Success';

  @override
  String get historyInProgress => 'In progress';

  @override
  String historyStages(int done, int total) {
    return '$done/$total stages';
  }

  @override
  String historyDurationSeconds(int n) {
    return '${n}s';
  }

  @override
  String historyDurationMinutes(int n) {
    return '${n}m';
  }

  @override
  String historyDurationHoursMinutes(int h, int m) {
    return '${h}h ${m}m';
  }

  @override
  String get historyEmptyTitle => 'No training history';

  @override
  String get historyEmptyBody =>
      'Complete some training sessions to see your progress';

  @override
  String get signOutConfirmBody =>
      'Are you sure you want to sign out? You will need to log in again.';

  @override
  String get settingsSectionConnection => 'Connection';

  @override
  String get settingsSectionMyRobots => 'My Robots';

  @override
  String get settingsSectionController => 'Controller';

  @override
  String get settingsSectionRobotStatus => 'Robot Status';

  @override
  String get settingsSectionCalibration => 'Calibration';

  @override
  String get settingsSectionCamera => 'Camera';

  @override
  String get settingsSectionNightVision => 'Night Vision';

  @override
  String get settingsSectionVideo => 'Video';

  @override
  String get settingsSectionAudio => 'Audio';

  @override
  String get settingsSectionNotifications => 'Notifications';

  @override
  String get settingsSectionSilentGuardian => 'Silent Guardian';

  @override
  String get settingsSectionTraining => 'Training';

  @override
  String get settingsSectionDiagnostics => 'Diagnostics';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsGameController => 'Game Controller';

  @override
  String get settingsGameControllerSubtitle =>
      'Pair a game controller to the robot';

  @override
  String get settingsBattery => 'Battery';

  @override
  String get settingsTemperature => 'Temperature';

  @override
  String get settingsNotAvailable => 'N/A';

  @override
  String get settingsCurrentMode => 'Current Mode';

  @override
  String get settingsTrainingScheduler => 'Training Scheduler';

  @override
  String get settingsTrainingSchedulerSubtitle =>
      'Schedule automatic training sessions';

  @override
  String get settingsVoiceCommands => 'Voice Commands';

  @override
  String get settingsVoiceCommandsSubtitle =>
      'Record custom voice commands for your dog';

  @override
  String get settingsTestRecording => 'Test Recording';

  @override
  String get settingsTestRecordingSubtitle => 'Run recording diagnostics';

  @override
  String get settingsConnectionDiagnostics => 'Connection Diagnostics';

  @override
  String get settingsConnectionDiagnosticsSubtitle =>
      'WebRTC signaling trace (video connect)';

  @override
  String get settingsUiPreviews => 'UI Previews';

  @override
  String get settingsUiPreviewsSubtitle =>
      'Spec-shaped views on sample data (dev)';

  @override
  String get settingsAppName => 'WIM-Z App';

  @override
  String settingsAppVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsApiVersion => 'API Version';

  @override
  String settingsConnectedToRobot(String ip) {
    return 'Connected to Robot ($ip)';
  }

  @override
  String get settingsLocalNotConnected => 'Local mode — not connected';

  @override
  String get settingsDirectViaWifi => 'Direct connection via WIMZ WiFi';

  @override
  String get settingsConnectedViaCloud => 'Connected via Cloud';

  @override
  String settingsRelayHost(String host) {
    return 'Relay: $host';
  }

  @override
  String get settingsLocalRobotDirect =>
      'Local Robot · direct connection (192.168.4.1)';

  @override
  String get settingsNoRobotsPaired => 'No robots paired — tap to add one';

  @override
  String settingsRobotsPairedActive(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count robots',
      one: '1 robot',
    );
    return '$name · $_temp0 paired';
  }

  @override
  String settingsRobotsPairedSelect(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count robots',
      one: '1 robot',
    );
    return '$_temp0 paired — tap to select';
  }

  @override
  String get settingsManageRobots => 'Manage Robots';

  @override
  String settingsOtaUpdating(String version, String state, String pct) {
    return 'Updating to $version: $state$pct';
  }

  @override
  String settingsOtaUpdated(String version) {
    return 'Updated to $version ✓';
  }

  @override
  String settingsOtaRolledBack(String detail) {
    return 'Update failed — rolled back safely$detail';
  }

  @override
  String settingsOtaFailed(String detail) {
    return 'Update failed$detail';
  }

  @override
  String get settingsOtaNotReported =>
      'Version not reported — robot updater not installed yet';

  @override
  String get settingsOtaUpToDateNoRelease =>
      'Up to date — no newer release on server';

  @override
  String settingsOtaAvailable(String version) {
    return 'Update available: $version';
  }

  @override
  String get settingsOtaUpToDate => 'Up to date';

  @override
  String get settingsRobotSoftware => 'Robot Software';

  @override
  String get settingsUpdateCaps => 'UPDATE';

  @override
  String get settingsUpdate => 'Update';

  @override
  String get settingsUpdateRobotSoftware => 'Update Robot Software';

  @override
  String settingsUpdateConfirmBody(String from, String to) {
    return 'Update robot from $from to $to?\n\nThe robot must be idle with battery above 30%. It will restart during the update and roll back automatically if anything goes wrong.';
  }

  @override
  String get settingsTreats => 'Treats';

  @override
  String settingsTreatsOfCapacity(int remaining, int capacity) {
    return '$remaining of $capacity';
  }

  @override
  String get settingsTreatsEmpty => 'Empty — refill needed';

  @override
  String settingsTreatsRemaining(int remaining) {
    return '$remaining remaining';
  }

  @override
  String settingsTreatsRemainingLow(int remaining) {
    return '$remaining remaining — running low';
  }

  @override
  String get settingsDailyTreatLimit => 'Daily Treat Limit';

  @override
  String settingsDailyLimitMax(int count) {
    return 'Max $count auto-treats per day';
  }

  @override
  String get settingsDailyLimitNone => 'No daily limit — unlimited auto-treats';

  @override
  String get settingsCameraTrackDog => 'Camera Track Dog';

  @override
  String get settingsCameraTrackOn =>
      'Camera follows dog during coach/mission mode';

  @override
  String get settingsCameraTrackOff => 'Camera stays centered';

  @override
  String get settingsVideoQuality => 'Video Quality';

  @override
  String get settingsQualityAuto => 'Auto';

  @override
  String get settingsQualityLow => 'Low';

  @override
  String get settingsQualityMed => 'Med';

  @override
  String get settingsQualityHigh => 'High';

  @override
  String get settingsStreamingNotConnected => 'not connected';

  @override
  String settingsCurrentlyStreaming(String label) {
    return 'Currently streaming: $label';
  }

  @override
  String get settingsBackgroundAudio => 'Background Audio';

  @override
  String get settingsBackgroundAudioOn =>
      'Keep listening when app is in background';

  @override
  String get settingsBackgroundAudioOff =>
      'Audio stops when app is backgrounded';

  @override
  String get settingsActivityNotifications => 'Activity Notifications';

  @override
  String get settingsNotificationsOn =>
      'Show alerts on lock screen & Apple Watch';

  @override
  String get settingsNotificationsOff => 'Notifications disabled';

  @override
  String get settingsPerEventPrefs => 'Per-event preferences';

  @override
  String get settingsPerEventPrefsSubtitle =>
      'Choose which events push to the lock screen vs in-app only';

  @override
  String get settingsMotorTrim => 'Motor Trim (Right)';

  @override
  String get settingsMotorTrimNone => 'No adjustment';

  @override
  String settingsMotorTrimSlowing(int pct) {
    return 'Slowing right motor by $pct%';
  }

  @override
  String settingsMotorTrimSpeeding(int pct) {
    return 'Speeding right motor by $pct%';
  }

  @override
  String get settingsReset => 'Reset';

  @override
  String get settingsMotorTrimHint =>
      'If robot drifts LEFT, increase trim. If it drifts RIGHT, decrease trim.';

  @override
  String get settingsWifiHelp => 'WiFi Setup Help';

  @override
  String get settingsWifiHelpSubtitle => 'How to connect your robot';

  @override
  String get settingsWifiHelpTitle => 'Connecting Your WIM-Z to WiFi';

  @override
  String get settingsWifiStep1 => 'Power on your WIM-Z robot';

  @override
  String get settingsWifiStep2 =>
      'If not connected to WiFi, it creates a hotspot called \"WIMZ-XXXX\"';

  @override
  String get settingsWifiStep3 => 'On your phone, go to Settings → WiFi';

  @override
  String get settingsWifiStep4 => 'Connect to \"WIMZ-XXXX\"';

  @override
  String get settingsWifiStep4Detail => 'Password: wimzsetup';

  @override
  String get settingsWifiStep5 => 'Open your browser and go to:';

  @override
  String get settingsWifiStep6 =>
      'Select your home WiFi network and enter the password';

  @override
  String get settingsWifiStep7 =>
      'Robot will reboot and connect to your network';

  @override
  String get settingsWifiStep8 => 'Return to this app and pair with your robot';

  @override
  String get settingsLedGuide => 'LED Status Guide';

  @override
  String get settingsLedSpinningCyan => 'Spinning cyan';

  @override
  String get settingsLedSearchingWifi => 'Searching for WiFi';

  @override
  String get settingsLedPulsingBlue => 'Pulsing blue';

  @override
  String get settingsLedSetupMode => 'Setup mode (connect to WIMZ hotspot)';

  @override
  String get settingsLedSolidGreen => 'Solid green';

  @override
  String get settingsLedConnectedWifi => 'Connected to WiFi';

  @override
  String get settingsLedPulsingRed => 'Pulsing red';

  @override
  String get settingsRobotNetwork => 'Robot Network';

  @override
  String get settingsNetHotspot => 'Hotspot (AP)';

  @override
  String get settingsNetWifi => 'WiFi';

  @override
  String get settingsNetMode => 'Mode';

  @override
  String get settingsNetNetwork => 'Network';

  @override
  String get settingsNetIp => 'IP';

  @override
  String get settingsConfigureRobotWifi => 'Configure Robot WiFi';

  @override
  String get settingsWifiScanFailed => 'Scan failed';

  @override
  String get settingsWifiScanning => 'Scanning for WiFi networks...';

  @override
  String get settingsWifiNoneFound => 'No WiFi networks found';

  @override
  String get settingsWifiScanAgain => 'Scan Again';

  @override
  String get settingsWifiPassword => 'Password';

  @override
  String get settingsWifiPasswordHint => 'Enter WiFi password';

  @override
  String get settingsWifiConnect => 'Connect';

  @override
  String get settingsTryAgain => 'Try Again';

  @override
  String get settingsWifiRobotConnecting => 'Robot is connecting to WiFi...';

  @override
  String get settingsWifiMayTakeMoment => 'This may take a moment.';

  @override
  String get settingsWifiRobotSwitching => 'Robot is switching to WiFi...';

  @override
  String get settingsWifiHotspotShutdown =>
      'The local hotspot will shut down.\nYour connection may drop shortly.';

  @override
  String get settingsWifiCommandSent => 'WiFi command sent!';

  @override
  String get settingsWifiCommandSentBody =>
      'Robot is switching to WiFi. Connect your phone to the same WiFi network, then disable Local Mode to use relay connection.';

  @override
  String get settingsGotIt => 'Got it';

  @override
  String get settingsSignalExcellent => 'Excellent';

  @override
  String get settingsSignalGood => 'Good';

  @override
  String get settingsSignalFair => 'Fair';

  @override
  String get settingsSignalWeak => 'Weak';

  @override
  String get settingsDiagRunning => 'Running diagnostics...';

  @override
  String settingsDiagError(String error, String stack) {
    return 'DIAGNOSTICS ERROR: $error\n\nStack: $stack';
  }

  @override
  String get settingsRecordingDiagnostics => 'Recording Diagnostics';

  @override
  String get settingsRunningTests => 'Running tests...';

  @override
  String get settingsRunAgain => 'Run Again';

  @override
  String get notifPrefsTitle => 'Notification Preferences';

  @override
  String get notifPrefsResetDefaults => 'Reset to defaults';

  @override
  String get notifPrefsEnableLockScreen => 'Enable lock-screen notifications';

  @override
  String get notifPrefsMasterSubtitle =>
      'Master switch. When off, nothing pushes to the lock screen or Apple Watch — events still appear in the in-app feed.';

  @override
  String get notifPrefsPerEventType => 'Per event type';

  @override
  String get notifPrefsLegend =>
      'Off — never recorded.\nIn-app — appears in the activity feed only.\nIn-app + Push — also wakes lock screen and Apple Watch.';

  @override
  String get notifPrefsBarking => 'Barking';

  @override
  String get notifPrefsSitDetected => 'Sit detected';

  @override
  String get notifPrefsLayDownDetected => 'Lay down detected';

  @override
  String get notifPrefsComeStandDetected => 'Come / stand detected';

  @override
  String get notifPrefsTreatDispensed => 'Treat dispensed';

  @override
  String get notifPrefsMissionStarted => 'Mission started';

  @override
  String get notifPrefsMissionCompleted => 'Mission completed';

  @override
  String get notifPrefsMissionFailed => 'Mission failed';

  @override
  String get notifPrefsLowBattery => 'Low battery';

  @override
  String get notifPrefsGuardianAlert => 'Guardian alert';

  @override
  String get notifPrefsHappyDog => 'Happy dog';

  @override
  String get notifPrefsRobotConnected => 'Robot connected';

  @override
  String get notifPrefsRobotDisconnected => 'Robot disconnected';

  @override
  String get notifPrefsCoachReward => 'Coach reward';

  @override
  String get notifPrefsPanicAlert => 'Panic alert';

  @override
  String get notifPrefsSgSummary => 'Guardian session summary';

  @override
  String get notifPrefsInApp => 'In-app';

  @override
  String get notifPrefsPlusPush => '+ Push';

  @override
  String get controllerPairingTitle => 'Game Controller';

  @override
  String get controllerPairingRefresh => 'Refresh';

  @override
  String get controllerPairingRobotNotConnected => 'Robot not connected';

  @override
  String get controllerPairingRobotNotConnectedBody =>
      'Connect to your robot first, then come back to pair a controller.';

  @override
  String get controllerPairingChecking => 'Checking robot…';

  @override
  String get controllerPairingCheckingBody =>
      'Asking the robot about its controllers.';

  @override
  String get controllerPairingNoResponse => 'No response from robot';

  @override
  String get controllerPairingNoResponseBody =>
      'The robot didn\'t answer the controller check. It may still be starting up, or its firmware may not support controller pairing yet. Try again in a moment.';

  @override
  String get controllerPairingSavedControllers => 'Saved Controllers';

  @override
  String get controllerPairingNoSaved =>
      'No saved controllers yet. Scan and pair one below — then trust it so the robot reconnects it automatically.';

  @override
  String get controllerPairingAddController => 'Add a Controller';

  @override
  String get controllerPairingForgetTitle => 'Forget controller?';

  @override
  String controllerPairingForgetBody(String name) {
    return 'The robot will unpair \"$name\" and stop auto-reconnecting it. You can pair it again later.';
  }

  @override
  String get controllerPairingForget => 'Forget';

  @override
  String get controllerPairingController => 'Controller';

  @override
  String get controllerPairingNoneConnected => 'No controller connected';

  @override
  String get controllerPairingTrusted => 'Trusted';

  @override
  String get controllerPairingSavedNotConnected => 'Saved · not connected';

  @override
  String get controllerPairingReconnect => 'Reconnect';

  @override
  String get controllerPairingAutoReconnect => 'Auto-reconnect (trusted)';

  @override
  String get controllerPairingPair => 'Pair';

  @override
  String get controllerPairingScanning => 'Scanning for controllers…';

  @override
  String get controllerPairingScan => 'Scan for controllers';

  @override
  String get controllerPairingScanningHint =>
      'Put your controller in pairing mode';

  @override
  String get controllerPairingScanHint =>
      'Robot will look for nearby controllers';

  @override
  String get devicePairingEnterId => 'Please enter a device ID';

  @override
  String get devicePairingInvalidId =>
      'Device ID must be 3–50 characters: letters, numbers, _ or -';

  @override
  String devicePairingPaired(String deviceId) {
    return 'Successfully paired $deviceId';
  }

  @override
  String get devicePairingUnpairTitle => 'Unpair Device';

  @override
  String devicePairingUnpairBody(String deviceId) {
    return 'Are you sure you want to unpair $deviceId?';
  }

  @override
  String get devicePairingUnpair => 'Unpair';

  @override
  String devicePairingUnpaired(String deviceId) {
    return 'Unpaired $deviceId';
  }

  @override
  String get devicePairingNotFoundTitle => 'Robot Not Found';

  @override
  String devicePairingNotFoundBody(String deviceId) {
    return 'The relay has no record of \"$deviceId\". This entry is orphaned and can\'t be cleanly removed. Hide it from your list anyway?';
  }

  @override
  String get devicePairingKeep => 'Keep';

  @override
  String get devicePairingHide => 'Hide';

  @override
  String devicePairingHidden(String deviceId) {
    return 'Hid $deviceId from your list';
  }

  @override
  String devicePairingConnectingTo(String label) {
    return 'Connecting to $label…';
  }

  @override
  String get devicePairingTitle => 'My Robots';

  @override
  String get devicePairingPairNew => 'PAIR NEW DEVICE';

  @override
  String get devicePairingIdHint => 'Enter device ID (e.g., wimz_robot_01)';

  @override
  String get devicePairingPair => 'Pair';

  @override
  String get devicePairingNoDevices => 'No Paired Devices';

  @override
  String get devicePairingNoDevicesBody =>
      'Enter a device ID above to pair your WIM-Z';

  @override
  String get devicePairingActive => 'ACTIVE';

  @override
  String get devicePairingOnline => 'Online';

  @override
  String get devicePairingOffline => 'Offline';

  @override
  String devicePairingLastSeen(String when) {
    return ' - Last seen $when';
  }

  @override
  String get devicePairingUnpairTooltip => 'Unpair device';

  @override
  String get devicePairingJustNow => 'just now';

  @override
  String devicePairingMinutesAgo(int n) {
    return '${n}m ago';
  }

  @override
  String devicePairingHoursAgo(int n) {
    return '${n}h ago';
  }

  @override
  String devicePairingDaysAgo(int n) {
    return '${n}d ago';
  }

  @override
  String get connDiagCopied => 'Trace copied to clipboard';

  @override
  String get connDiagShareSubject => 'WIM-Z connection trace';

  @override
  String get connDiagCleared => 'Trace cleared';

  @override
  String get connDiagNotConnected =>
      'Not connected — connect to the robot first';

  @override
  String connDiagLedAcked(int ms) {
    return 'LED acknowledged in ${ms}ms — if nothing lit, the fault is on the robot';
  }

  @override
  String get connDiagLedTimeout =>
      'LED sent but not acknowledged in 3s — command path broken';

  @override
  String connDiagLedFailed(String error) {
    return 'LED ping failed: $error';
  }

  @override
  String get connDiagTitle => 'Connection Diagnostics';

  @override
  String get connDiagLedPing => 'LED ping';

  @override
  String get connDiagCopy => 'Copy';

  @override
  String get connDiagShare => 'Share';

  @override
  String get connDiagClear => 'Clear';

  @override
  String connDiagHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
    );
    return 'WebRTC signaling trace — $_temp0 captured.\nReproduce the slow video, then Share this trace.';
  }

  @override
  String get connDiagEmpty =>
      'No events captured yet.\n\nLog in and open the video feed, then return here.';

  @override
  String get nightVisionTitle => 'Night Vision';

  @override
  String get nightVisionWaiting => 'Waiting for robot…';

  @override
  String get nightVisionNightMode => 'Night vision';

  @override
  String get nightVisionDayMode => 'Day mode';

  @override
  String get nightVisionStaleTooltip => 'No update from robot in 90+ seconds';

  @override
  String get nightVisionAuto => 'Auto';

  @override
  String get nightVisionDay => 'Day';

  @override
  String get nightVisionNight => 'Night';

  @override
  String get nightVisionAutoHint => 'Switches automatically based on lighting.';

  @override
  String get nightVisionOverrideHint =>
      'Manual override active. Tap Auto to resume automatic detection.';

  @override
  String get nightVisionOfflineHint =>
      'Robot offline — change will apply when reconnected.';

  @override
  String nightVisionLighting(String label) {
    return 'Lighting: $label';
  }

  @override
  String nightVisionLux(String lux, String label) {
    return '$lux lux — $label';
  }

  @override
  String get nightVisionModeWordNight => 'night vision';

  @override
  String get nightVisionModeWordDay => 'day mode';

  @override
  String nightVisionSwitchedSecondsAgo(String mode, int n) {
    return 'Switched to $mode ${n}s ago';
  }

  @override
  String nightVisionSwitchedMinutesAgo(String mode, int n) {
    return 'Switched to $mode ${n}m ago';
  }

  @override
  String nightVisionSwitchedHoursAgo(String mode, int n) {
    return 'Switched to $mode ${n}h ago';
  }

  @override
  String nightVisionSwitchedDaysAgo(String mode, int n) {
    return 'Switched to $mode ${n}d ago';
  }

  @override
  String get nightVisionBadgeNight => 'IR night view';

  @override
  String get nightVisionBadgeDay => 'Day';

  @override
  String sgError(String error) {
    return 'Silent Guardian: $error';
  }

  @override
  String get sgInterventionLevel => 'Intervention level';

  @override
  String get sgInterventionSubtitle =>
      'How fast the robot jumps to calming music for sustained barking.';

  @override
  String sgBpm(int bpm) {
    return '$bpm BPM';
  }

  @override
  String get sgAggressive => 'Aggressive';

  @override
  String get sgTolerant => 'Tolerant';

  @override
  String get sgHelperOff =>
      'Disabled — Silent Guardian climbs the normal L1→L4 ladder only.';

  @override
  String get sgHelperLow =>
      'Even modest sustained barking will jump straight to calming music.';

  @override
  String get sgHelperMid =>
      'A typical noisy outburst will trigger calming music.';

  @override
  String get sgHelperHigh =>
      'Only extreme nonstop barking will trigger calming music.';

  @override
  String get sgSessionSummary => 'Session Summary';

  @override
  String get sgTapRefresh => 'Tap refresh for a live status report';

  @override
  String get sgStatBarks => 'Barks';

  @override
  String get sgStatTreats => 'Treats';

  @override
  String get sgStatInterventions => 'Interventions';

  @override
  String get sgStatLevel => 'Level';

  @override
  String get sgStatTrend => 'Trend';

  @override
  String get sgBarkTimeline => 'BARK TIMELINE';

  @override
  String sgRateLine(String recent, String session) {
    return 'now $recent/min · session $session/min';
  }

  @override
  String get sgPanicActive => 'PANIC ACTIVE';

  @override
  String sgPanicEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count panic episodes',
      one: '1 panic episode',
    );
    return '$_temp0';
  }

  @override
  String get sgAggressiveBehavior => 'Aggressive behavior';

  @override
  String get dogProfileTitle => 'Dog Profile';

  @override
  String get dogProfileNotFound => 'No dog profile found';

  @override
  String get dogProfileEditTooltip => 'Edit dog';

  @override
  String get dogProfileMissionStarted => 'Mission started';

  @override
  String get dogProfileMissionActive => 'MISSION ACTIVE';

  @override
  String get dogProfileLaunchLastMission => 'LAUNCH LAST MISSION';

  @override
  String get dogProfileStartAMission => 'START A MISSION';

  @override
  String get dogProfileTodaySummary => 'Today\'s Summary';

  @override
  String get dogProfileStatTreats => 'Treats';

  @override
  String get dogProfileStatSits => 'Sits';

  @override
  String get dogProfileStatBarks => 'Barks';

  @override
  String get dogProfileStatGoal => 'Goal';

  @override
  String get dogProfileMetrics => 'Metrics';

  @override
  String get dogProfileRangeDay => 'Day';

  @override
  String get dogProfileRangeWeek => 'Week';

  @override
  String get dogProfileRangeAll => 'All';

  @override
  String get dogProfileStatDetections => 'Detections';

  @override
  String get dogProfileStatMissions => 'Missions';

  @override
  String get dogProfileStatSuccess => 'Success';

  @override
  String get dogProfileStatActive => 'Active';

  @override
  String get dogProfileStatCoach => 'Coach';

  @override
  String dogProfileActiveMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String get dogProfileViewDashboard => 'View Dashboard';

  @override
  String get dogProfileQuickActions => 'Quick Actions';

  @override
  String get dogProfileActionVoice => 'Voice';

  @override
  String get dogProfileActionStats => 'Stats';

  @override
  String get dogProfileMetricsHint =>
      'Metrics are shown above — use Day/Week/All toggle';

  @override
  String get dogProfileRecentActivity => 'Recent Activity';

  @override
  String get dogProfileSeeAll => 'See all';

  @override
  String get dogProfileNoRecentActivity => 'No recent activity';

  @override
  String dogProfileRelMinutes(int n) {
    return '${n}m';
  }

  @override
  String dogProfileRelHours(int n) {
    return '${n}h';
  }

  @override
  String dogProfileRelDays(int n) {
    return '${n}d';
  }

  @override
  String get dogsListTitle => 'Dogs';

  @override
  String get dogsListEmpty => 'No dogs added yet';

  @override
  String get dogsListNoDetails => 'No details';

  @override
  String get dogNameLabel => 'Name';

  @override
  String get dogBreedLabel => 'Breed';

  @override
  String get dogPhotoTakePhoto => 'Take Photo';

  @override
  String get dogPhotoChooseFromGallery => 'Choose from Gallery';

  @override
  String get dogPhotoRemovePhoto => 'Remove Photo';

  @override
  String get arucoPrintMarker => 'Print marker';

  @override
  String get editDogTitle => 'Edit Dog';

  @override
  String get editDogNotFound => 'Dog not found';

  @override
  String get editDogBreedHint => 'e.g. Golden Retriever';

  @override
  String get editDogCoatColorLabel => 'Coat color';

  @override
  String get editDogDeleteDog => 'Delete Dog';

  @override
  String get editDogNameEmpty => 'Name cannot be empty';

  @override
  String get editDogSaved => 'Saved';

  @override
  String editDogSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get editDogDeleteConfirmTitle => 'Delete Dog?';

  @override
  String editDogDeleteConfirmBody(String name) {
    return 'Are you sure you want to delete $name? This will remove all their data and cannot be undone.';
  }

  @override
  String editDogDeleted(String name) {
    return '$name deleted';
  }

  @override
  String get editDogChangePhoto => 'Change photo';

  @override
  String get editDogChoosePhotoSource => 'Choose Photo Source';

  @override
  String get editDogPhotoUpdated => 'Photo updated';

  @override
  String editDogPhotoSaveFailed(String error) {
    return 'Failed to save photo: $error';
  }

  @override
  String get editDogTreatsPerReward => 'Treats per reward';

  @override
  String get editDogTreatsHelper1 => 'Default — one treat per reward.';

  @override
  String get editDogTreatsHelper2 => 'Medium dogs may benefit from two.';

  @override
  String get editDogTreatsHelper3 => 'Big dogs need more to feel rewarded.';

  @override
  String get editDogTreatsHelper4 => 'Very large dogs / high-energy training.';

  @override
  String get editDogArucoMarker => 'ArUco Marker';

  @override
  String get editDogNoMarker =>
      'No marker assigned. Re-create this dog to assign one.';

  @override
  String editDogMarkerId(int id) {
    return 'DICT_4X4_1000 — ID $id';
  }

  @override
  String editDogPrintFailed(String error) {
    return 'Print failed: $error';
  }

  @override
  String get addDogTitle => 'Add Dog';

  @override
  String get addDogSaveDog => 'Save Dog';

  @override
  String get addDogContinue => 'Continue';

  @override
  String get addDogStepColor => 'Color';

  @override
  String get addDogStepPhoto => 'Photo';

  @override
  String get addDogPhotoSelected => 'Photo selected';

  @override
  String get addDogOptional => 'Optional';

  @override
  String get addDogStepAruco => 'ARUCO Tag';

  @override
  String get addDogNameQuestion => 'What\'s your dog\'s name?';

  @override
  String get addDogNameFieldLabel => 'Dog Name';

  @override
  String get addDogNameHint => 'e.g., Max, Luna, Buddy';

  @override
  String get addDogNameRequired => 'Please enter a name';

  @override
  String get addDogBreedQuestion => 'What breed is your dog?';

  @override
  String get addDogBreedHint => 'e.g., Golden Retriever, Mixed, Unknown';

  @override
  String get addDogColorQuestion => 'What\'s your dog\'s primary coat color?';

  @override
  String get addDogPhotoPrompt => 'Add a profile photo for your dog';

  @override
  String get addDogTapToAdd => 'Tap to add';

  @override
  String get addDogCamera => 'Camera';

  @override
  String get addDogGallery => 'Gallery';

  @override
  String get addDogRemovePhoto => 'Remove photo';

  @override
  String get addDogArucoIntro =>
      'WIM-Z uses an ARUCO marker on your dog\'s collar to tell them apart.';

  @override
  String get addDogArucoAutoPicked =>
      'We picked the next free ID for you. Print this marker and attach it to the collar.';

  @override
  String get addDogArucoIdLabel => 'ARUCO Marker ID';

  @override
  String get addDogArucoIdHint => 'e.g., 42';

  @override
  String get addDogArucoSkipHint =>
      'You can clear this field to skip ArUco — useful if you only have one dog or prefer appearance-based ID.';

  @override
  String get addDogMarkerBundleMissing =>
      'Marker bundle not generated yet — run scripts/generate_aruco_markers.py';

  @override
  String addDogPickImageFailed(String error) {
    return 'Failed to pick image: $error';
  }

  @override
  String addDogDuplicateName(String name) {
    return 'A dog named \"$name\" already exists';
  }

  @override
  String addDogRobotWillRecognize(String name) {
    return 'Robot will now recognize $name';
  }

  @override
  String get weeklySummaryTitle => 'Weekly Summary';

  @override
  String get weeklyTapRefresh => 'Tap refresh for this week\'s report';

  @override
  String get weeklyVsLastWeek => 'vs last wk';

  @override
  String get weeklyQuiets => 'Quiets';

  @override
  String weeklyTricks(int completed, int attempts) {
    return 'Tricks: $completed/$attempts completed';
  }

  @override
  String weeklyTricksWithRate(int completed, int attempts, String rate) {
    return 'Tricks: $completed/$attempts completed ($rate%)';
  }

  @override
  String weeklyGuardian(int interventions, int sessions) {
    return 'Guardian: $interventions interventions across $sessions sessions';
  }

  @override
  String weeklyDataSince(String parts) {
    return 'Data since: $parts';
  }

  @override
  String get weeklyCoverageBarks => 'barks';

  @override
  String get weeklyCoverageBarkTypes => 'bark types';

  @override
  String get weeklyCoverageTreats => 'treats';

  @override
  String get weeklyCoverageCoaching => 'coaching';

  @override
  String get voiceTitle => 'Voice Commands';

  @override
  String get voiceNoDogSelected => 'No dog selected';

  @override
  String get voiceResetTooltip => 'Reset to default voice';

  @override
  String get voiceSyncAll => 'Sync All';

  @override
  String voiceIntro(String dogName) {
    return 'Record your voice for each command. $dogName will learn to respond to YOUR voice.';
  }

  @override
  String get voiceMobileOnlyBanner =>
      'Recording requires the iOS/Android app. Use mobile to record commands.';

  @override
  String voiceRecordedProgress(int recorded, int total) {
    return '$recorded of $total recorded';
  }

  @override
  String voiceSyncedCount(int count) {
    return '$count synced';
  }

  @override
  String get voiceMobileRequiredTitle => 'Mobile Required';

  @override
  String get voiceMobileRequiredBody =>
      'Voice recording requires the iOS or Android app. Please use your mobile device to record voice commands.';

  @override
  String get voiceDeleteRecordingTitle => 'Delete Recording?';

  @override
  String get voiceDeleteRecordingBody =>
      'This will delete the recorded voice command.';

  @override
  String get voiceCommandSynced => 'Command synced!';

  @override
  String get voiceSyncFailed => 'Sync failed';

  @override
  String get voiceResetTitle => 'Reset to Default Voice?';

  @override
  String voiceResetBody(int count, String dogName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recordings',
      one: '1 recording',
    );
    return 'This deletes $_temp0 for $dogName. WIM-Z will use its built-in voice instead.';
  }

  @override
  String get voiceResetAction => 'Reset';

  @override
  String get voiceResetDone => 'Reset — WIM-Z will use its default voice';

  @override
  String voiceSyncedToRobot(int count) {
    return '$count commands synced to robot';
  }

  @override
  String get voiceRecordedSynced => 'Recorded & Synced';

  @override
  String get voiceRecordedTapToSync => 'Recorded - tap to sync';

  @override
  String get voiceNotRecorded => 'Not recorded';

  @override
  String get voiceSyncToRobotTooltip => 'Sync to robot';

  @override
  String get voiceReRecord => 'Re-record';

  @override
  String get voiceRecord => 'Record';

  @override
  String get voiceStartFailed =>
      'Failed to start recording. Check microphone permission.';

  @override
  String get voiceRecordingFailed => 'Recording failed. Try again.';

  @override
  String get voiceSavedTitle => 'Saved!';

  @override
  String voiceRecordTitle(String label) {
    return 'Record: $label';
  }

  @override
  String get voiceRecordedSuccess => 'Voice command recorded successfully!';

  @override
  String voiceSeconds(String seconds) {
    return '${seconds}s';
  }

  @override
  String get voiceSayClearly => 'Say the command clearly...';

  @override
  String get voicePreparingMic => 'Preparing microphone...';

  @override
  String get voiceStop => 'Stop';

  @override
  String arucoIdLabel(int id) {
    return 'ID $id';
  }

  @override
  String get arucoBundleMissing =>
      'Marker bundle not generated.\nSee scripts/generate_aruco_markers.py';

  @override
  String get loginTagline => 'Watchful Intelligent Mobile Zen';

  @override
  String get loginButton => 'Login';

  @override
  String get loginCloudHint => 'Cloud connection (requires internet)';

  @override
  String get loginConnectToRobot => 'Connect to Robot';

  @override
  String get loginDirectHint => 'Direct connection via WIMZ WiFi hotspot';

  @override
  String get loginLocalConnectFailed =>
      'Could not connect to robot.\nMake sure you\'re on the same WiFi as your robot\nor connected to the WIMZ hotspot.';

  @override
  String get loginConnectionFailedCheckWifi =>
      'Connection failed. Check WiFi and try again.';

  @override
  String get loginDemoMode => 'Demo Mode';

  @override
  String get loginSignIn => 'Sign In';

  @override
  String get loginCreateAccount => 'Create Account';

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginEnterEmail => 'Please enter email';

  @override
  String get loginInvalidEmail => 'Invalid email';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginEnterPassword => 'Please enter password';

  @override
  String get loginMin6Chars => 'Min 6 characters';

  @override
  String get loginSavePassword => 'Save password';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginNoAccountSignUp => 'Don\'t have an account? Sign up';

  @override
  String get loginHaveAccountSignIn => 'Already have an account? Sign in';

  @override
  String get forgotTitle => 'Reset Password';

  @override
  String get forgotHeading => 'Forgot your password?';

  @override
  String get forgotIntro =>
      'Enter the email on your account and we\'ll send you a 6-digit code to reset your password.';

  @override
  String get forgotSendCode => 'Send Code';

  @override
  String get forgotCodeSentBanner =>
      'If that email is registered, a 6-digit code is on the way. It expires in 15 minutes.';

  @override
  String get forgotEnterCodeHeading => 'Enter Code & New Password';

  @override
  String get forgotCodeLabel => '6-digit code';

  @override
  String get forgotEnterCode => 'Enter the code';

  @override
  String get forgotCodeIs6Digits => 'Code is 6 digits';

  @override
  String get forgotNewPasswordLabel => 'New password';

  @override
  String get forgotEnterNewPassword => 'Enter a new password';

  @override
  String get forgotMin8Chars => 'Min 8 characters';

  @override
  String get forgotConfirmPasswordLabel => 'Confirm new password';

  @override
  String get forgotConfirmYourPassword => 'Confirm your password';

  @override
  String get forgotPasswordsDontMatch => 'Passwords don\'t match';

  @override
  String get forgotResendCode => 'Resend code';

  @override
  String get homeLocalRobot => 'Local Robot';

  @override
  String get homeFindYourRobot => 'Find your robot →';

  @override
  String homeNewDog(int arucoId) {
    return 'New dog #$arucoId';
  }

  @override
  String get homeDismiss => 'Dismiss';

  @override
  String get homeExit => 'EXIT';

  @override
  String get homeModeIdle => 'Idle';

  @override
  String get homeModeGuard => 'Guard';

  @override
  String get homeModeCoach => 'Coach';

  @override
  String get homeSelectDog => 'Select Dog';

  @override
  String get driveLabel => 'DRIVE';

  @override
  String get driveEmergencyStop => 'Emergency Stop';

  @override
  String get driveCall => 'CALL';

  @override
  String get driveTreat => 'TREAT';

  @override
  String get driveCenter => 'CENTER';

  @override
  String get driveSwitchingMode => 'Switching mode...';

  @override
  String get driveCamera => 'CAMERA';

  @override
  String get driveCoach => 'COACH';

  @override
  String get driveSelectDogFirst =>
      'Select a dog or wait for the camera to identify one.';

  @override
  String get driveMissionFallback => 'Mission';

  @override
  String driveMissionStage(String name, String stage) {
    return '$name — $stage';
  }

  @override
  String get driveStop => 'STOP';

  @override
  String get galleryTitle => 'Photo Gallery';

  @override
  String get galleryRefresh => 'Refresh';

  @override
  String get galleryNoPhotos => 'No photos yet';

  @override
  String get galleryTakePhotosHint => 'Take photos from the video view';

  @override
  String get galleryShare => 'Share';

  @override
  String get galleryFailedToLoad => 'Failed to load image';

  @override
  String galleryShareText(String date) {
    return 'WIM-Z Photo - $date';
  }

  @override
  String galleryShareFailed(String error) {
    return 'Failed to share: $error';
  }

  @override
  String get galleryDeleteTitle => 'Delete Photo';

  @override
  String get galleryDeleteConfirm =>
      'Are you sure you want to delete this photo?';

  @override
  String get notificationsTitle => 'Activity';

  @override
  String get notificationsMarkAllRead => 'Mark all read';

  @override
  String get notificationsFilterAll => 'All';

  @override
  String get notificationsFilterBehaviors => 'Behaviors';

  @override
  String get notificationsFilterMissions => 'Missions';

  @override
  String get notificationsFilterAlerts => 'Alerts';

  @override
  String get notificationsFilterTreats => 'Treats';

  @override
  String get notificationsFilterCoach => 'Coach';

  @override
  String get notificationsClearAll => 'Clear all';

  @override
  String get notificationsTabDashboard => 'Dashboard';

  @override
  String get notificationsTabEvents => 'Events';

  @override
  String get notificationsEmpty => 'No notifications yet';

  @override
  String get notificationsEmptyHint => 'Events from WIM-Z will appear here';

  @override
  String get notificationsGroupToday => 'TODAY';

  @override
  String get notificationsGroupYesterday => 'YESTERDAY';

  @override
  String get notificationsGroupThisWeek => 'THIS WEEK';

  @override
  String get notificationsGroupEarlier => 'EARLIER';

  @override
  String get activityNoDogSelected => 'No dog selected';

  @override
  String get activityStatTreats => 'Treats';

  @override
  String get activityStatDetections => 'Detections';

  @override
  String get activityStatMissions => 'Missions';

  @override
  String get activityStatCoach => 'Coach';

  @override
  String get activitySeriesTreats => 'Treats';

  @override
  String get activitySeriesBarks => 'Barks';

  @override
  String get activitySeriesBehaviors => 'Behaviors';

  @override
  String get activitySeriesMissions => 'Missions';

  @override
  String get activitySeriesAlerts => 'Alerts';

  @override
  String get activityChartTitle => 'Activity (7 days)';

  @override
  String get activityNoSeriesSelected => 'No series selected';

  @override
  String activitySeriesCount(String label, int count) {
    return '$label: $count';
  }

  @override
  String get activityRecentEvents => 'Recent Events';

  @override
  String get activityNoEvents => 'No events yet';

  @override
  String get connBadgeNoRobot => 'No Robot';

  @override
  String get connBadgeOffline => 'Offline';

  @override
  String get connBadgeNotPaired => 'Not Paired';

  @override
  String get connBadgeWaiting => 'Waiting...';

  @override
  String get connBadgeRobotOnline => 'Robot Online';

  @override
  String get connBadgeOtherDeviceActive => 'Other Device Active';

  @override
  String get connBadgeDemo => 'Demo';

  @override
  String localApCouldntReach(String ssid, String password) {
    return 'Couldn\'t reach the robot. Join \"$ssid\" (password $password) in WiFi settings first, then try again.';
  }

  @override
  String get localApNoHotspotInfo =>
      'Robot didn\'t confirm hotspot start and no cached hotspot info is available. Update the robot and try again.';

  @override
  String get localApJoinHotspotTitle => 'Join the robot\'s hotspot';

  @override
  String localApJoinHotspotBody(String ssid, String password) {
    return 'The robot is starting its hotspot.\n\n1. Open WiFi settings on this phone\n2. Join \"$ssid\"\n    password: $password\n3. Come back and tap Connect\n\nThe robot stays on its hotspot until you switch back to cloud mode (or 10 minutes with no phone attached).';
  }

  @override
  String get localApConnect => 'Connect';

  @override
  String get localApSwitchTitle => 'Switch to Local Mode';

  @override
  String get localApSwitchSubtitle =>
      'Robot starts its hotspot; phone connects directly';

  @override
  String treatCounterOf(int remaining, int capacity) {
    return '$remaining of $capacity';
  }

  @override
  String treatCounterTitle(String headline) {
    return 'Treats: $headline';
  }

  @override
  String get treatCounterEmptyRefill => 'Empty — refill needed';

  @override
  String get treatCounterRemainingLabel => 'treats remaining';

  @override
  String get treatCounterRefilledReset => 'Refilled — Reset Counter';

  @override
  String get treatCounterClearing => 'Clearing...';

  @override
  String get treatCounterClearJam => 'Clear Jam';

  @override
  String treatCounterLoadedHint(int capacity) {
    return 'Treats loaded (max $capacity)';
  }

  @override
  String get treatCounterSet => 'Set';

  @override
  String get eventFeedSgActive => 'Silent Guardian Active';

  @override
  String get eventFeedWatching => 'Watching for activity...';

  @override
  String eventFeedRecentEvents(int count) {
    return 'Recent Events ($count)';
  }

  @override
  String get eventFeedClear => 'Clear';

  @override
  String get notifBarkingDetected => 'Barking Detected';

  @override
  String get notifPanicEpisodeEnded => 'Panic Episode Ended';

  @override
  String get notifPanicAlert => 'Panic Alert';

  @override
  String get notifSgLevel4 => 'Silent Guardian: Level 4';

  @override
  String get notifSgLevel4Body => 'Escalation reached the highest level';

  @override
  String get notifTreatDispensed => 'Treat Dispensed';

  @override
  String notifTreatFor(String dogName) {
    return 'For $dogName';
  }

  @override
  String get notifGoodJob => 'Good job!';

  @override
  String notifTreatsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count treats remaining',
      one: '1 treat remaining',
    );
    return '$_temp0';
  }

  @override
  String get notifTreatsRunningLow => 'Treats Running Low';

  @override
  String notifTreatsLowBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count treats remaining — time to refill!',
      one: '1 treat remaining — time to refill!',
    );
    return '$_temp0';
  }

  @override
  String get notifTreatsEmpty => 'Treats Empty';

  @override
  String get notifTreatsEmptyBody => 'Refill the carousel to keep dispensing';

  @override
  String get notifMissionStarted => 'Mission Started';

  @override
  String get notifMissionCompleted => 'Mission Completed';

  @override
  String get notifMissionFailed => 'Mission Failed';

  @override
  String notifCoachRewardedFor(String dogName, String behavior) {
    return '$dogName: $behavior rewarded';
  }

  @override
  String notifCoachRewarded(String behavior) {
    return '$behavior rewarded';
  }

  @override
  String notifCoachAttempt(String behavior) {
    return '$behavior attempt';
  }

  @override
  String get notifCoachMode => 'Coach mode';

  @override
  String get notifTrick => 'trick';

  @override
  String get notifLowBattery => 'Low Battery';

  @override
  String notifBatteryRemaining(int percent) {
    return '$percent% remaining';
  }

  @override
  String get notifSessionEnded => 'Session ended';

  @override
  String get notifAggressiveToday => 'Your dog was aggressive today';

  @override
  String notifPanicEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count panic episodes',
      one: '1 panic episode',
    );
    return '$_temp0';
  }

  @override
  String get notifGuardianSessionEnded => 'Guardian Session Ended';

  @override
  String get notifGuardianAlert => 'Guardian Alert';

  @override
  String get notifIntervention => 'Intervention';

  @override
  String notifGuardianReason(String reason) {
    return 'Guardian: $reason';
  }

  @override
  String get notifSittingDetected => 'Sitting Detected';

  @override
  String get notifLayDown => 'Lay Down';

  @override
  String get notifCome => 'Come';

  @override
  String get notifAlert => 'Alert';

  @override
  String get notifHappyDog => 'Happy Dog';

  @override
  String get notifCoachReward => 'Coach Reward';

  @override
  String get notifGuardianSummary => 'Guardian Summary';

  @override
  String get notifBehaviorDetected => 'Behavior Detected';

  @override
  String notifBehaviorNamedDetected(String behavior) {
    return '$behavior Detected';
  }

  @override
  String notifConfidence(int percent) {
    return '$percent% confidence';
  }

  @override
  String notifBarkType(String type) {
    return '$type bark';
  }

  @override
  String get channelActivityName => 'WIM-Z Activity';

  @override
  String get channelActivityDescription =>
      'Dog training activity notifications';

  @override
  String get authErrRegistrationFailed => 'Registration failed';

  @override
  String get authErrEmailRegistered => 'Email already registered';

  @override
  String get authErrInvalidCredentials => 'Invalid email or password';

  @override
  String get authErrLoginFailed => 'Login failed';

  @override
  String get authErrAccountNotFound => 'Account not found';

  @override
  String get authErrResetCodeSend =>
      'Could not send reset code. Check your connection.';

  @override
  String get authErrResetFailed => 'Reset failed';

  @override
  String get authErrInvalidCode => 'Invalid or expired code';

  @override
  String get authErrTooManyAttempts => 'Too many attempts — try again later';

  @override
  String get authNoticeSessionExpired =>
      'Your session expired — please sign in again.';

  @override
  String get connStatusConnectingServer => 'Connecting to server...';

  @override
  String get connStatusNotPaired => 'Device not paired';

  @override
  String get connStatusWaitingRobot => 'Server connected. Waiting for robot...';

  @override
  String get connStatusRobotOnline => 'Robot online';

  @override
  String get connStatusError => 'Connection error';

  @override
  String get connStatusSuperseded => 'Signed in on another device';

  @override
  String get connErrServerNotResponding => 'Server not responding';

  @override
  String get connErrLiveConnection =>
      'Could not open live connection to server';

  @override
  String get connErrLostConnection => 'Lost connection to server';

  @override
  String get connErrHandshake =>
      'Connection handshake failed. Please update the app.';

  @override
  String get connErrSessionExpired => 'Session expired — please sign in again.';

  @override
  String get connErrNotPairedGoSettings =>
      'Device not paired. Go to Settings to pair.';

  @override
  String get connErrRobotOffline => 'Robot is offline';

  @override
  String get errNotAuthorizedLogin => 'Not authorized. Please log in again.';

  @override
  String get connErrSuperseded =>
      'This account is now active on another device. Tap to take control back.';

  @override
  String get errNotConnectedToRobot => 'Not connected to robot';

  @override
  String get errNoResponseUpdate => 'No response — robot may need an update';

  @override
  String get pttErrPlayFailed => 'Failed to play audio';

  @override
  String get pttErrMobileOnly => 'Recording only available on iOS/Android';

  @override
  String get pttErrNotConnectedSend => 'Not connected — cannot send voice';

  @override
  String get pttErrMicDenied => 'Microphone permission denied';

  @override
  String get pttErrStartFailed => 'Recording failed to start';

  @override
  String pttErrStartFailedDetail(String error) {
    return 'Failed to start recording: $error';
  }

  @override
  String get pttErrRecordingFailed => 'Recording failed';

  @override
  String get pttErrFileNotFound => 'Recording file not found';

  @override
  String get pttErrEmpty => 'Recording was empty - no audio captured';

  @override
  String get pttErrNotConnectedNotSent =>
      'Not connected — voice message not sent';

  @override
  String pttErrSendFailed(String error) {
    return 'Failed to send audio: $error';
  }

  @override
  String get pttErrNoAudio => 'No audio received';

  @override
  String get pairErrPairFailed => 'Failed to pair device';

  @override
  String get pairErrNetwork => 'Network error. Check your connection.';

  @override
  String pairErrUnpairFailed(int code) {
    return 'Failed to unpair device (status $code)';
  }

  @override
  String get pairErrDeviceNotFound => 'Device not found. Check the device ID.';

  @override
  String get pairErrAlreadyPaired => 'Device already paired to your account.';

  @override
  String get pairErrRobotUnavailable =>
      'Robot unavailable. Make sure it is powered on and connected.';

  @override
  String get pairErrTimeout =>
      'Connection timed out. Robot may be unavailable.';

  @override
  String get pairErrGeneric => 'An error occurred. Please try again.';

  @override
  String get ctrlPairPairing => 'Pairing…';

  @override
  String get ctrlPairSaving => 'Saving…';

  @override
  String get ctrlPairRemovingTrust => 'Removing trust…';

  @override
  String get ctrlPairForgetting => 'Forgetting…';

  @override
  String get ctrlPairReconnecting => 'Reconnecting…';

  @override
  String get ctrlPairConnecting => 'Connecting…';

  @override
  String get ctrlPairError => 'Controller error';

  @override
  String get schedErrDeleteFailed => 'Failed to delete schedule';

  @override
  String get schedErrTimeout => 'Timeout waiting for schedules from robot';

  @override
  String get modeErrMissionActive =>
      'Cannot change mode while mission is active';

  @override
  String get videoErrRobotRecordFailed => 'Robot could not record the video';

  @override
  String get videoErrNoDownloadUrl => 'No download URL received from robot';

  @override
  String get videoErrNotFound =>
      'Video file not found on server — robot may need a direct connection for downloads';

  @override
  String get videoErrUnreachable => 'Could not reach robot for video download';

  @override
  String get videoErrDownloadFailed => 'Video download failed';

  @override
  String videoErrEncodingTimeout(int seconds) {
    return 'Video encoding timed out — no response after ${seconds}s';
  }

  @override
  String get photoErrEmpty => 'Received empty photo data';

  @override
  String get photoErrTimeout =>
      'Photo capture timed out - no response from robot';

  @override
  String get webrtcErrTimeoutRetry => 'Connection timed out — tap to retry';

  @override
  String get webrtcErrFailed => 'Connection failed';

  @override
  String get webrtcErrLost => 'Connection lost';

  @override
  String get webrtcErrFailedRetry => 'Connection failed - tap to retry';

  @override
  String wifiErrScanFailed(String error) {
    return 'WiFi scan failed: $error';
  }

  @override
  String wifiErrConnectFailed(String error) {
    return 'Failed to connect: $error';
  }

  @override
  String get missionsErrIncompleteData =>
      'Robot sent incomplete mission data - check robot logs';

  @override
  String get missionsErrAlreadyActive => 'A mission is already active';

  @override
  String missionsErrAlreadyActiveNamed(String name) {
    return 'A mission is already active ($name)';
  }

  @override
  String get missionsErrStartFailed => 'Mission failed to start';

  @override
  String missionsErrStopFirst(String name) {
    return 'Stop current mission first ($name)';
  }

  @override
  String get missionsErrStartFailedRobot => 'Mission failed to start on robot';

  @override
  String get sgErrNotRunning => 'Silent Guardian is not running';

  @override
  String get weeklyErrUnknownDog => 'Robot doesn\'t know this dog yet';

  @override
  String get historyErrLocalMode => 'History not available in local mode';

  @override
  String get historyErrNotLoggedIn => 'Not logged in';

  @override
  String historyErrLoadFailed(String error) {
    return 'Failed to load history: $error';
  }

  @override
  String uploadErrFailedStatus(String status) {
    return 'Upload failed ($status)';
  }

  @override
  String get uploadErrTooLarge => 'File too large for server';

  @override
  String get uploadErrInvalidType => 'Invalid file type - MP3 only';

  @override
  String get uploadErrNotAuthorized => 'Not authorized to upload';

  @override
  String get uploadErrRobotOffline => 'Robot offline';

  @override
  String get uploadErrTimeout => 'Upload timed out - try a smaller file';

  @override
  String get uploadErrConnection => 'Connection error - check network';

  @override
  String get uploadErrFailed => 'Upload failed';

  @override
  String uploadErrGeneric(String error) {
    return 'Upload error: $error';
  }

  @override
  String get modelBehaviorDog => 'Dog';

  @override
  String get modelBehaviorSit => 'Sit';

  @override
  String get modelBehaviorLayDown => 'Lay Down';

  @override
  String get modelBehaviorCome => 'Come';

  @override
  String get modelBehaviorStay => 'Stay';

  @override
  String get modelBehaviorSpin => 'Spin';

  @override
  String get modelBehaviorSpeak => 'Speak';

  @override
  String get modelBehaviorBark => 'Bark';

  @override
  String get modelBehaviorQuiet => 'Quiet';

  @override
  String get modelRobotModeIdle => 'Idle';

  @override
  String get modelRobotModeManual => 'Manual';

  @override
  String get modelRobotModeSilentGuardian => 'Silent Guardian';

  @override
  String get modelRobotModeCoach => 'Coach';

  @override
  String get modelRobotModeMission => 'Mission';

  @override
  String get modelRobotModeDocking => 'Docking';

  @override
  String get modelDogColorBlack => 'Black';

  @override
  String get modelDogColorYellow => 'Yellow/Golden';

  @override
  String get modelDogColorBrown => 'Brown/Chocolate';

  @override
  String get modelDogColorWhite => 'White';

  @override
  String get modelDogColorMixed => 'Mixed/Multi';

  @override
  String modelAgeYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String modelAgeMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get modelVoiceCmdName => 'Dog\'s Name';

  @override
  String get modelVoiceCmdPromptName => 'Say your dog\'s name clearly';

  @override
  String get modelVoiceCmdSit => 'Sit';

  @override
  String get modelVoiceCmdPromptSit => 'Say \"Sit\" firmly';

  @override
  String get modelVoiceCmdStay => 'Stay';

  @override
  String get modelVoiceCmdPromptStay => 'Say \"Stay\" with a steady tone';

  @override
  String get modelVoiceCmdLieDown => 'Lay Down';

  @override
  String get modelVoiceCmdPromptLieDown => 'Say \"Lay Down\" or \"Down\"';

  @override
  String get modelVoiceCmdSpin => 'Spin';

  @override
  String get modelVoiceCmdPromptSpin => 'Say \"Spin\" enthusiastically';

  @override
  String get modelVoiceCmdSpeak => 'Speak';

  @override
  String get modelVoiceCmdPromptSpeak => 'Say \"Speak\" enthusiastically';

  @override
  String get modelVoiceCmdCome => 'Come';

  @override
  String get modelVoiceCmdPromptCome => 'Say \"Come\" or \"Come here\"';

  @override
  String get modelVoiceCmdTreat => 'Want a treat?';

  @override
  String get modelVoiceCmdPromptTreat => 'Say \"Want a treat?\" playfully';

  @override
  String get modelVoiceCmdGoodDog => 'Good dog!';

  @override
  String get modelVoiceCmdPromptGoodDog => 'Say \"Good dog!\" with praise';

  @override
  String get modelVoiceCmdNo => 'No / Bad';

  @override
  String get modelVoiceCmdPromptNo => 'Say \"No\" or \"Bad\" firmly';

  @override
  String get modelVoiceCmdQuiet => 'Quiet';

  @override
  String get modelVoiceCmdPromptQuiet => 'Say \"Quiet\" calmly but firmly';

  @override
  String get modelMissionStatusWaitingForDog => 'Waiting for dog...';

  @override
  String get modelMissionStatusGreeting => 'Greeting...';

  @override
  String get modelMissionStatusCommand => 'Commanding';

  @override
  String get modelMissionStatusWatching => 'Hold it...';

  @override
  String get modelMissionStatusSuccess => 'Success!';

  @override
  String get modelMissionStatusFailed => 'Try again';

  @override
  String get modelMissionStatusRetry => 'Trying again...';

  @override
  String get modelMissionStatusCompleted => 'Complete!';

  @override
  String get modelMissionStatusStopped => 'Stopped';

  @override
  String modelMissionWaitingForDog(String dogName) {
    return 'Waiting for $dogName...';
  }

  @override
  String modelMissionGreetingDog(String dogName) {
    return 'Greeting $dogName...';
  }

  @override
  String modelMissionStageOf(int stage, int total) {
    return 'Stage $stage of $total';
  }

  @override
  String get modelGuardianEventDogDetected => 'Dog detected';

  @override
  String get modelGuardianEventDogLeft => 'Dog left frame';

  @override
  String get modelGuardianEventBarking => 'Barking detected';

  @override
  String get modelGuardianEventTreatDispensed => 'Treat dispensed';

  @override
  String get modelGuardianEventBehaviorChange => 'Behavior change';

  @override
  String get modelGuardianEventMotionDetected => 'Motion detected';

  @override
  String get modelGuardianEventQuietReward => 'Quiet reward';

  @override
  String get modelGuardianEventAlertTriggered => 'Alert triggered';

  @override
  String get modelGuardianEventUnknown => 'Event';

  @override
  String modelGuardianEventWithDetails(String label, String details) {
    return '$label - $details';
  }

  @override
  String get modelNotifTitleBark => 'Barking Detected';

  @override
  String get modelNotifTitleSit => 'Sitting Detected';

  @override
  String get modelNotifTitleLieDown => 'Lay Down';

  @override
  String get modelNotifTitleStand => 'Come';

  @override
  String get modelNotifTitleTreatDispensed => 'Treat Dispensed';

  @override
  String get modelNotifTitleMissionStarted => 'Mission Started';

  @override
  String get modelNotifTitleMissionCompleted => 'Mission Completed';

  @override
  String get modelNotifTitleMissionFailed => 'Mission Failed';

  @override
  String get modelNotifTitleLowBattery => 'Low Battery';

  @override
  String get modelNotifTitleAlert => 'Alert';

  @override
  String get modelNotifTitleHappy => 'Happy Dog';

  @override
  String get modelNotifTitleConnected => 'Connected';

  @override
  String get modelNotifTitleDisconnected => 'Disconnected';

  @override
  String get modelNotifTitleCoachReward => 'Coach Reward';

  @override
  String get modelNotifTitlePanicAlert => 'Panic Alert';

  @override
  String get modelNotifTitleSgSummary => 'Guardian Summary';

  @override
  String get modelNightOverrideAuto => 'Auto';

  @override
  String get modelNightOverrideDay => 'Day mode';

  @override
  String get modelNightOverrideNight => 'Night mode';

  @override
  String get modelLuxDetecting => 'detecting…';

  @override
  String get modelLuxDark => 'dark';

  @override
  String get modelLuxDim => 'dim';

  @override
  String get modelLuxIndoor => 'indoor lighting';

  @override
  String get modelLuxWellLit => 'well lit';

  @override
  String get modelLuxBright => 'bright';

  @override
  String get modelControllerKindXbox => 'Xbox';

  @override
  String get modelControllerKindPlaystation => 'PlayStation';

  @override
  String get modelControllerKindEightBitDo => '8BitDo';

  @override
  String get modelControllerKindGeneric => 'Controller';

  @override
  String get modelControllerHintXbox =>
      'Hold the Xbox button, then hold the small Pair button on top until the light flashes quickly.';

  @override
  String get modelControllerHintPlaystation =>
      'Hold the PS button + Share (or Create) button together until the light bar flashes.';

  @override
  String get modelControllerHintEightBitDo =>
      'Set the controller to its Bluetooth mode, then hold Start (or the Pair button) until the LEDs flash.';

  @override
  String get modelControllerHintGeneric =>
      'Put the controller into Bluetooth pairing mode (usually a dedicated Pair button or a button-combo held until the light flashes), then wait for it to appear here.';

  @override
  String get modelDetectionDogDetected => 'Dog Detected';

  @override
  String get modelVideoTierLow => 'SD 480p';

  @override
  String get modelVideoTierMedium => '540p';

  @override
  String get modelVideoTierHigh => 'HD 720p';

  @override
  String get modelVideoQualityAuto => 'Auto';

  @override
  String get modelVideoQualityLow => 'Low';

  @override
  String get modelVideoQualityMedium => 'Medium';

  @override
  String get modelVideoQualityHigh => 'High';

  @override
  String get modelDaySun => 'Sun';

  @override
  String get modelDayMon => 'Mon';

  @override
  String get modelDayTue => 'Tue';

  @override
  String get modelDayWed => 'Wed';

  @override
  String get modelDayThu => 'Thu';

  @override
  String get modelDayFri => 'Fri';

  @override
  String get modelDaySat => 'Sat';

  @override
  String modelScheduleOnceAt(String time) {
    return 'Once at $time';
  }

  @override
  String modelScheduleDailyAt(String time) {
    return 'Daily at $time';
  }

  @override
  String modelScheduleWeeklyAt(String time) {
    return 'Weekly at $time';
  }

  @override
  String modelScheduleEveryDayAt(String time) {
    return 'Every day at $time';
  }

  @override
  String modelScheduleDaysAt(String days, String time) {
    return '$days at $time';
  }

  @override
  String get catalogMissionSit => 'Sit';

  @override
  String get catalogMissionSitDesc =>
      'Quick sit mission - wait for dog, then reward sit';

  @override
  String get catalogMissionSitTraining => 'Sit Training';

  @override
  String get catalogMissionSitTrainingDesc =>
      'Basic sit training - rewards dog for sitting behavior';

  @override
  String get catalogMissionSitSustained => 'Sit Sustained';

  @override
  String get catalogMissionSitSustainedDesc =>
      'Dog holds sit position for extended duration (30 seconds)';

  @override
  String get catalogMissionDownSustained => 'Lay Down Sustained';

  @override
  String get catalogMissionDownSustainedDesc =>
      'Dog holds lay down position for extended duration (30 seconds)';

  @override
  String get catalogMissionComeAndSit => 'Come and Sit';

  @override
  String get catalogMissionComeAndSitDesc =>
      'Call the dog over, then ask for a sit';

  @override
  String get catalogMissionTrainSitDaily => 'Daily Sit Training';

  @override
  String get catalogMissionTrainSitDailyDesc =>
      'Daily sit training with progressive difficulty and limits';

  @override
  String get catalogMissionLaydown => 'Lay Down';

  @override
  String get catalogMissionLaydownDesc =>
      'Quick lay down mission - wait for dog, then reward lay down';

  @override
  String get catalogMissionComeTraining => 'Come Training';

  @override
  String get catalogMissionComeTrainingDesc =>
      'Recall training - rewards dog for coming when called';

  @override
  String get catalogMissionSpinTraining => 'Spin Training';

  @override
  String get catalogMissionSpinTrainingDesc =>
      'Spin trick training - rewards dog for spinning in a circle';

  @override
  String get catalogMissionSitAndSpeak => 'Sit and Speak';

  @override
  String get catalogMissionSitAndSpeakDesc =>
      'Train dog to sit and bark on command for treat';

  @override
  String get catalogMissionSpeakMorning => 'Speak Morning';

  @override
  String get catalogMissionSpeakMorningDesc =>
      'Dog barks on cue twice during morning (8am-12pm)';

  @override
  String get catalogMissionSpeakAfternoon => 'Speak Afternoon';

  @override
  String get catalogMissionSpeakAfternoonDesc =>
      'Dog barks on cue twice during afternoon (2pm-6pm)';

  @override
  String get catalogMissionAlertTraining => 'Alert Training';

  @override
  String get catalogMissionAlertTrainingDesc =>
      'Guard dog training - rewards dog for sitting and giving alert barks';

  @override
  String get catalogMissionBarkPrevention => 'Bark Prevention';

  @override
  String get catalogMissionBarkPreventionDesc =>
      'Quiet training - reduces excessive barking behavior';

  @override
  String get catalogMissionStopBarking => 'Stop Barking';

  @override
  String get catalogMissionStopBarkingDesc =>
      'Quiet training - reduces excessive barking with escalation';

  @override
  String get catalogMissionQuietProgressive => 'Quiet Progressive';

  @override
  String get catalogMissionQuietProgressiveDesc =>
      'Progressive quiet training - increasing quiet duration requirements';

  @override
  String get catalogMissionComfortScared => 'Comfort Scared';

  @override
  String get catalogMissionComfortScaredDesc =>
      'Comfort dog when scared or anxious barking detected';

  @override
  String get catalogMissionMorningChill => 'Morning Chill';

  @override
  String get catalogMissionMorningChillDesc =>
      'Dog maintains calm behavior during morning (8am-12pm)';

  @override
  String get catalogMissionMorningQuiet2hr => 'Morning Quiet 2hr';

  @override
  String get catalogMissionMorningQuiet2hrDesc =>
      'Dog maintains quiet for 2 hours during morning period (7am-1pm)';

  @override
  String get catalogMissionAfternoonSit5 => 'Afternoon Sit 5';

  @override
  String get catalogMissionAfternoonSit5Desc =>
      'Dog performs 5 sits during afternoon (12pm-7pm)';

  @override
  String get catalogMissionAfternoonDown3 => 'Afternoon Lay Down 3';

  @override
  String get catalogMissionAfternoonDown3Desc =>
      'Dog performs 3 lay downs during afternoon (12pm-6pm)';

  @override
  String get catalogMissionEveningCalmTransition => 'Evening Calm Transition';

  @override
  String get catalogMissionEveningCalmTransitionDesc =>
      'Help dog transition to quiet evening behavior (6pm-9pm)';

  @override
  String get catalogMissionEveningSettle => 'Evening Settle';

  @override
  String get catalogMissionEveningSettleDesc =>
      'Dog settles down after dinner (5pm-9pm)';

  @override
  String get catalogMissionNightQuiet90pct => 'Night Quiet 90%';

  @override
  String get catalogMissionNightQuiet90pctDesc =>
      'Dog maintains 90% quiet overnight (7pm-4am)';

  @override
  String get catalogMissionDownTraining => 'Down Training';

  @override
  String get catalogMissionQuietTraining => 'Quiet Training';

  @override
  String get catalogMissionStayTraining => 'Stay Training';

  @override
  String get catalogMissionStandTraining => 'Stand Training';

  @override
  String get catalogProgramPuppyBasics => 'Puppy Basics';

  @override
  String get catalogProgramPuppyBasicsDesc =>
      'Foundation training: sit, down, and quiet behaviors';

  @override
  String get catalogProgramObedience101 => 'Obedience 101';

  @override
  String get catalogProgramObedience101Desc =>
      'Core commands every dog should know';

  @override
  String get catalogProgramCalmDog => 'Calm Dog';

  @override
  String get catalogProgramCalmDogDesc => 'Build patience and self-control';

  @override
  String get aiAssistantFallback => 'Assistant';

  @override
  String draftTranscriptProposed(String title) {
    return 'Proposed mission: $title';
  }

  @override
  String get draftTranscriptYou => 'You';

  @override
  String draftTranscriptApproved(String title) {
    return 'Approved \"$title\"';
  }

  @override
  String draftTranscriptDeclined(String title) {
    return 'Declined \"$title\"';
  }

  @override
  String get aiErrSignedOut => 'Sign in to manage connected assistants';

  @override
  String get aiErrLoadFailed => 'Couldn\'t load connected assistants';

  @override
  String get aiErrRevokeFailed => 'Revoke failed';

  @override
  String get notifMissionDraft => 'Mission approval';

  @override
  String notifMissionDraftFrom(String name) {
    return '$name proposed a mission';
  }

  @override
  String get notifPrefsMissionDraft => 'Mission approval requests';

  @override
  String get modelNotifTitleMissionDraft => 'Mission Approval';

  @override
  String get draftApprove => 'Approve';

  @override
  String get draftDecline => 'Decline';

  @override
  String get draftStatusApproved => 'Approved';

  @override
  String get draftStatusDeclined => 'Declined';

  @override
  String get draftStatusExpired => 'Expired';

  @override
  String get attachmentOpenFailed => 'Couldn\'t load media';

  @override
  String get todayCardTitle => 'Today';

  @override
  String get todayCardLocalCounts => 'Counts from this phone\'s activity feed';

  @override
  String get todayCardError => 'Couldn\'t reach the summary service';

  @override
  String get todayStatBarks => 'Barks';

  @override
  String get todayStatTreats => 'Treats';

  @override
  String get todayStatCoaching => 'Coaching';

  @override
  String get todayStatQuiet => 'Quiet';

  @override
  String get todayStatGuardian => 'Guardian';

  @override
  String get todayPlanTitle => 'Plan';

  @override
  String todayPlanBy(String source) {
    return 'Plan by $source';
  }

  @override
  String get todayHighlights => 'Highlights';

  @override
  String get connectedAiTitle => 'Connected AI';

  @override
  String get connectedAiSubtitle =>
      'Assistants, connector URL, kill switch, audit log';

  @override
  String get aiConnectorUrl => 'Connector URL';

  @override
  String get aiConnectorUrlCopied => 'Connector URL copied';

  @override
  String get aiConnectorUrlMissing => 'Not issued yet';

  @override
  String get aiCopyUrl => 'Copy URL';

  @override
  String get aiAssistantsHeader => 'Connected assistants';

  @override
  String get aiNoAssistants => 'No assistant connected yet';

  @override
  String get aiRevoke => 'Revoke';

  @override
  String aiRevokeConfirm(String name) {
    return 'Revoke $name? It loses access immediately.';
  }

  @override
  String aiLastUsed(String when) {
    return 'Last used $when';
  }

  @override
  String get aiNeverUsed => 'Never used';

  @override
  String get aiScopesNone => 'no scopes';

  @override
  String get aiAuditHeader => 'Audit log';

  @override
  String get aiAuditEmpty => 'No activity yet';

  @override
  String get aiSetupGuides => 'Setup guides';

  @override
  String get aiUnsupported =>
      'Connected AI isn\'t available on this server yet';

  @override
  String aiGuideTitle(String name) {
    return 'Connect $name';
  }

  @override
  String aiGuideStep1(String name) {
    return 'Open $name and go to Settings → Connectors (or Tools).';
  }

  @override
  String get aiGuideStep2 => 'Choose Add custom connector / MCP server.';

  @override
  String get aiGuideStep3 => 'Paste the WIM-Z connector URL below.';

  @override
  String get aiGuideStep4 =>
      'Sign in with your WIM-Z account and allow the scopes you want.';

  @override
  String aiGuideStep5(String name) {
    return 'Ask $name: \"How was my dog today?\" It appears in the list once connected.';
  }

  @override
  String get aiGuideNoteChatgpt =>
      'ChatGPT: turn on Developer mode under Settings → Connectors → Advanced first.';

  @override
  String get aiGuideNoteClaude =>
      'Claude: Settings → Connectors → Add custom connector (claude.ai, Pro/Max/Team).';

  @override
  String get aiGuideNoteGrok =>
      'Grok: Settings → Connectors → Add MCP server (grok.com).';

  @override
  String get aiGuideNotePerplexity =>
      'Perplexity: Settings → Connectors → Add connector (Pro/Max).';

  @override
  String get settingsSectionAdvanced => 'Advanced';

  @override
  String get settingsAdvancedMode => 'Advanced mode';

  @override
  String get settingsAdvancedModeSubtitle =>
      'Show every sound id with replace-from-phone';

  @override
  String get settingsSoundsAll => 'All sounds';

  @override
  String get settingsSoundsAllSubtitle =>
      'Replace any robot sound from this phone';

  @override
  String get settingsResetSounds => 'Reset sounds to factory default';

  @override
  String get settingsResetSoundsSubtitle =>
      'Restores every greeting, cue, alert and music sound';

  @override
  String get settingsResetSoundsConfirmTitle => 'Reset all sounds?';

  @override
  String get settingsResetSoundsConfirmBody =>
      'Every custom sound on the robot is replaced by the factory file. This can\'t be undone.';

  @override
  String get settingsResetSoundsDone => 'Sounds reset to factory default';

  @override
  String settingsResetSoundsFailed(String error) {
    return 'Reset failed: $error';
  }

  @override
  String get soundsTitle => 'Sounds';

  @override
  String get soundsReplace => 'Replace';

  @override
  String get soundsFactory => 'Factory';

  @override
  String get soundsCustom => 'Custom';

  @override
  String soundsReplaced(String id) {
    return 'Replaced $id';
  }

  @override
  String soundsReplaceFailed(String error) {
    return 'Replace failed: $error';
  }

  @override
  String get soundsRestoreOne => 'Restore factory sound';

  @override
  String get soundsCatalogFromRobot => 'Sound library from the server';

  @override
  String get soundsCatalogDefault => 'Default library (server didn\'t answer)';

  @override
  String get soundGroupGreeting => 'Greeting';

  @override
  String get soundGroupTreat => 'Treat';

  @override
  String get soundGroupCue => 'Cues';

  @override
  String get soundGroupAlert => 'Alerts';

  @override
  String get soundGroupSgLevel => 'Silent Guardian levels';

  @override
  String get soundGroupMusic => 'Music classes';

  @override
  String get songUploadTitle => 'Upload song';

  @override
  String get settingsSongUploadSubtitle =>
      'Send a public-domain recording to the robot';

  @override
  String get songUploadPdNotice =>
      'Only upload recordings you have the right to use — public domain or your own.';

  @override
  String get songUploadPdCheckbox => 'This recording is public domain or mine';

  @override
  String get songUploadChoose => 'Choose song';

  @override
  String get songUploadFormats => 'MP3 or WAV · up to 5 MB';

  @override
  String songUploadUploading(String name) {
    return 'Uploading $name…';
  }

  @override
  String songUploadDone(String name) {
    return 'Uploaded $name';
  }

  @override
  String songUploadFailed(String error) {
    return 'Upload failed: $error';
  }

  @override
  String get songUploadTooLarge => 'File is over 5 MB';

  @override
  String get songUploadNoDog => 'Select a dog first';

  @override
  String get songUploadNotSignedIn => 'Sign in to upload';

  @override
  String get songUploadPlayHint => 'Play it from the Music button on Home.';

  @override
  String get settingsSectionDemo => 'Demo';

  @override
  String get demoViewTitle => 'Demo view';

  @override
  String get demoViewSubtitle =>
      'Screen-mirror layout: today, guardian, agent transcript';

  @override
  String get demoPanelGuardian => 'Silent Guardian';

  @override
  String get demoPanelTranscript => 'Agent transcript';

  @override
  String get demoTranscriptEmpty => 'Waiting for an assistant…';

  @override
  String get demoNoDog => 'Select a dog on Home first';

  @override
  String get demoSgIdle => 'Guardian not running';

  @override
  String get aiErrNoDog => 'Select a dog first';

  @override
  String get aiErrRevokeAllFailed => 'Couldn\'t disconnect assistants';

  @override
  String get aiDisconnectAll => 'Disconnect all assistants';

  @override
  String get aiDisconnectAllSubtitle =>
      'Kill switch: every assistant loses access now and must be re-authorized';

  @override
  String get aiDisconnectAllConfirm =>
      'Disconnect every assistant? They lose access immediately and have to be connected again.';

  @override
  String aiDisconnectAllDone(int count) {
    return '$count tokens revoked';
  }

  @override
  String get draftActorVoiceAgent => 'WIM-Z voice agent';

  @override
  String get draftTriggerDeparture => 'Starts after you leave';

  @override
  String draftTriggerSchedule(String time) {
    return 'Daily at $time';
  }

  @override
  String get draftTriggerManual => 'Started manually';

  @override
  String draftDurationReward(int minutes, int treats) {
    return '$minutes min · $treats treats';
  }

  @override
  String get todayStatSettle => 'Settle';

  @override
  String get todayStatPacing => 'Pacing';

  @override
  String get todayStatMusic => 'Music';

  @override
  String get todayStatAlone => 'Alone';

  @override
  String get todayStatMissions => 'Missions';

  @override
  String get todayEpisodes => 'Top bark episodes';

  @override
  String todayEpisodeLine(int barks, String duration) {
    return '$barks barks · $duration';
  }

  @override
  String todayEpisodeSettled(String duration) {
    return 'settled in $duration';
  }

  @override
  String get todayCardEmptyRelay =>
      'No events on the relay yet today — counts from this phone';

  @override
  String get soundsFormats => 'MP3 or WAV · up to 5 MB';

  @override
  String get soundGroupSong => 'Songs';

  @override
  String get robotCardLocal => 'Connected directly to the robot';

  @override
  String get robotCardNonePaired => 'No robot paired';

  @override
  String get robotCardNoneBody =>
      'Pairing is optional — pair a robot whenever you\'re ready.';

  @override
  String get robotCardPair => 'Pair a robot';

  @override
  String get robotCardManage => 'Manage';

  @override
  String get dogNameYourDog => 'Name your dog';

  @override
  String get talkCardTitle => 'AI voice';

  @override
  String get talkHold => 'Hold to talk to WIM-Z';

  @override
  String get talkHint =>
      'Hold the mic and speak a command or a question — WIM-Z answers out loud.';

  @override
  String talkRecording(String seconds) {
    return 'Listening… ${seconds}s';
  }

  @override
  String get talkSending => 'Thinking…';

  @override
  String get talkPlayingRobot => 'WIM-Z is answering on the robot';

  @override
  String get talkPlayingPhone => 'Robot offline — answering on this phone';

  @override
  String get talkYou => 'You';

  @override
  String get talkTooShort => 'Hold a little longer';

  @override
  String get talkErrMic => 'Microphone permission is needed';

  @override
  String get talkErrSignedOut => 'Sign in to talk to WIM-Z';

  @override
  String get talkErrLocal => 'Talk to WIM-Z needs the cloud connection';

  @override
  String talkErrFailed(String error) {
    return 'Couldn\'t reach WIM-Z: $error';
  }

  @override
  String talkRefused(String reason) {
    return 'WIM-Z declined: $reason';
  }

  @override
  String get talkUnsupported =>
      'The voice agent isn\'t available on this server yet';

  @override
  String get quietHoursTitle => 'Quiet hours';

  @override
  String get quietHoursOff => 'Off';

  @override
  String get quietHoursStart => 'Start';

  @override
  String get quietHoursEnd => 'End';

  @override
  String get quietHoursHint =>
      'Pushes, music and the voice agent stay quiet. Assistants can only widen this window.';

  @override
  String get quietHoursUnsupported => 'Not available on this server yet';

  @override
  String quietHoursErrSave(String error) {
    return 'Couldn\'t save quiet hours: $error';
  }

  @override
  String get galleryAssistantPhoto => 'Taken by WIM-Z assistant';

  @override
  String galleryAssistantPhotoFor(String dogName) {
    return 'Taken by WIM-Z assistant · $dogName';
  }

  @override
  String get schedulerModeSilentGuardian => 'Silent Guardian';

  @override
  String get schedulerModeCoach => 'Coach mode';

  @override
  String get schedulerByAssistant => 'Scheduled by WIM-Z assistant';

  @override
  String schedulerNextToday(String time) {
    return 'today $time';
  }

  @override
  String schedulerNextTomorrow(String time) {
    return 'tomorrow $time';
  }

  @override
  String schedulerNextOn(String day, String time) {
    return '$day $time';
  }

  @override
  String schedulerDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String schedulerDurationHours(int hours) {
    return '$hours h';
  }

  @override
  String schedulerDurationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get demoControlsTitle => 'Demo controls';

  @override
  String demoReplayActive(String value) {
    return 'replay_active: $value';
  }

  @override
  String demoVirtualClock(String time) {
    return 'Virtual clock $time';
  }

  @override
  String get demoLoadGoodDay => 'Load good day';

  @override
  String get demoLoadBadDay => 'Load bad day';

  @override
  String demoStartSpeed(int speed) {
    return 'Start ($speed×)';
  }

  @override
  String get demoPause => 'Pause';

  @override
  String demoJumpTo(String time) {
    return 'Jump to $time';
  }

  @override
  String get demoReset => 'Reset';

  @override
  String get demoReplayIdle => 'No replay loaded';

  @override
  String get demoReplayStatusLoaded => 'Loaded';

  @override
  String get demoReplayStatusRunning => 'Running';

  @override
  String get demoReplayStatusPaused => 'Paused';

  @override
  String get demoReplayStatusDone => 'Done';

  @override
  String settingsDailyLimitSharedHint(String dog) {
    return 'Shared with the robot, Claude and the voice assistant. Showing $dog\'s limit.';
  }

  @override
  String settingsDailyLimitChangedBy(String actor) {
    return 'Changed by $actor';
  }

  @override
  String get settingsDailyLimitLocalOnly =>
      'Sent to the robot only (no relay in local mode)';

  @override
  String get settingsDailyLimitUnlimited => 'Unlimited';

  @override
  String get actorVoiceAssistant => 'the voice assistant';

  @override
  String get actorConnectedAi => 'a connected AI assistant';

  @override
  String get actorRobot => 'the robot';

  @override
  String treatRefusedCapReached(String counts) {
    return 'Daily treat limit reached$counts. Resets at midnight.';
  }

  @override
  String treatRefusedCapReachedAt(String counts, String time) {
    return 'Daily treat limit reached$counts. Resets at $time.';
  }

  @override
  String get treatRefusedRate =>
      'Too many treats in a row — try again in a minute.';

  @override
  String get treatRefusedWindowClosed =>
      'Treats are paused right now (outside the allowed treat window).';

  @override
  String treatRefusedGeneric(String reason) {
    return 'Treat refused: $reason';
  }

  @override
  String homeModeChip(String mode) {
    return 'Mode: $mode';
  }

  @override
  String get homeModeSheetTitle => 'MODE';

  @override
  String get homeAiShort => 'AI';
}
