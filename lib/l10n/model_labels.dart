/// Localized display labels for data-model enums and value objects.
///
/// Models keep their English `label`/`displayName` getters for logging and
/// wire compatibility; the UI must render through these extensions instead
/// (`context.l10n` in widgets, `ref.read(l10nProvider)` in providers).
library;

import 'package:intl/intl.dart';

import '../data/models/controller_info.dart';
import '../data/models/dog_profile.dart';
import '../data/models/guardian_event.dart';
import '../data/models/mission.dart';
import '../data/models/night_mode_state.dart';
import '../data/models/notification_event.dart';
import '../data/models/program.dart';
import '../data/models/schedule.dart';
import '../data/models/telemetry.dart';
import '../data/models/voice_command.dart';
import '../domain/providers/mode_provider.dart';
import '../domain/providers/video_quality_provider.dart';
import 'app_localizations.dart';

// ---------------------------------------------------------------------------
// Behaviors / tricks (robot behavior ids → display names)
// ---------------------------------------------------------------------------

/// Localized display name for a robot behavior/trick id ("sit", "lie_down",
/// "come", …). Mirrors `AppTheme.getBehaviorDisplayName`'s alias table.
/// Unknown ids are returned as-is.
String behaviorDisplayName(AppLocalizations l, String? behavior) {
  if (behavior == null) return l.modelBehaviorDog;
  switch (behavior.toLowerCase()) {
    case 'sit':
    case 'sitting':
      return l.modelBehaviorSit;
    case 'laydown':
    case 'lay_down':
    case 'down':
    case 'lying':
    case 'lie':
    case 'lie_down':
      return l.modelBehaviorLayDown;
    case 'come':
    case 'stand':
    case 'standing':
      return l.modelBehaviorCome;
    case 'stay':
      return l.modelBehaviorStay;
    case 'spin':
      return l.modelBehaviorSpin;
    case 'speak':
      return l.modelBehaviorSpeak;
    case 'bark':
    case 'barking':
      return l.modelBehaviorBark;
    case 'quiet':
      return l.modelBehaviorQuiet;
    default:
      return behavior;
  }
}

/// Localized name for a raw robot mode id ("idle", "guardian", "training",
/// "manual", "docking", …). Unknown ids are returned as-is.
String robotModeIdLabel(AppLocalizations l, String mode) {
  switch (mode.toLowerCase()) {
    case 'idle':
      return l.modelRobotModeIdle;
    case 'manual':
      return l.modelRobotModeManual;
    case 'guardian':
    case 'silent_guardian':
      return l.modelRobotModeSilentGuardian;
    case 'coach':
    case 'training':
      return l.modelRobotModeCoach;
    case 'mission':
      return l.modelRobotModeMission;
    case 'docking':
      return l.modelRobotModeDocking;
    default:
      return mode;
  }
}

extension RobotModeL10n on RobotMode {
  String localizedLabel(AppLocalizations l) => robotModeIdLabel(l, value);
}

// ---------------------------------------------------------------------------
// Dog profile
// ---------------------------------------------------------------------------

extension DogColorL10n on DogColor {
  String localizedLabel(AppLocalizations l) {
    switch (this) {
      case DogColor.black:
        return l.modelDogColorBlack;
      case DogColor.yellow:
        return l.modelDogColorYellow;
      case DogColor.brown:
        return l.modelDogColorBrown;
      case DogColor.white:
        return l.modelDogColorWhite;
      case DogColor.mixed:
        return l.modelDogColorMixed;
    }
  }
}

extension DogProfileL10n on DogProfile {
  /// Localized short age ("3 years" / "5 months"); null without a birth date.
  String? localizedShortAge(AppLocalizations l) {
    final birth = birthDate;
    if (birth == null) return null;
    final now = DateTime.now();
    var years = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      years--;
    }
    if (years < 1) {
      final months = now.difference(birth).inDays ~/ 30;
      return l.modelAgeMonths(months);
    }
    return l.modelAgeYears(years);
  }
}

// ---------------------------------------------------------------------------
// Voice commands
// ---------------------------------------------------------------------------

extension VoiceCommandTypeL10n on VoiceCommandType {
  String localizedLabel(AppLocalizations l) {
    switch (this) {
      case VoiceCommandType.name:
        return l.modelVoiceCmdName;
      case VoiceCommandType.sit:
        return l.modelVoiceCmdSit;
      case VoiceCommandType.stay:
        return l.modelVoiceCmdStay;
      case VoiceCommandType.lieDown:
        return l.modelVoiceCmdLieDown;
      case VoiceCommandType.spin:
        return l.modelVoiceCmdSpin;
      case VoiceCommandType.speak:
        return l.modelVoiceCmdSpeak;
      case VoiceCommandType.come:
        return l.modelVoiceCmdCome;
      case VoiceCommandType.treat:
        return l.modelVoiceCmdTreat;
      case VoiceCommandType.goodDog:
        return l.modelVoiceCmdGoodDog;
      case VoiceCommandType.no:
        return l.modelVoiceCmdNo;
      case VoiceCommandType.quiet:
        return l.modelVoiceCmdQuiet;
    }
  }

  String localizedPrompt(AppLocalizations l) {
    switch (this) {
      case VoiceCommandType.name:
        return l.modelVoiceCmdPromptName;
      case VoiceCommandType.sit:
        return l.modelVoiceCmdPromptSit;
      case VoiceCommandType.stay:
        return l.modelVoiceCmdPromptStay;
      case VoiceCommandType.lieDown:
        return l.modelVoiceCmdPromptLieDown;
      case VoiceCommandType.spin:
        return l.modelVoiceCmdPromptSpin;
      case VoiceCommandType.speak:
        return l.modelVoiceCmdPromptSpeak;
      case VoiceCommandType.come:
        return l.modelVoiceCmdPromptCome;
      case VoiceCommandType.treat:
        return l.modelVoiceCmdPromptTreat;
      case VoiceCommandType.goodDog:
        return l.modelVoiceCmdPromptGoodDog;
      case VoiceCommandType.no:
        return l.modelVoiceCmdPromptNo;
      case VoiceCommandType.quiet:
        return l.modelVoiceCmdPromptQuiet;
    }
  }
}

// ---------------------------------------------------------------------------
// Missions / programs
// ---------------------------------------------------------------------------

extension MissionStatusL10n on MissionStatus {
  String localizedLabel(AppLocalizations l) {
    switch (this) {
      case MissionStatus.waitingForDog:
        return l.modelMissionStatusWaitingForDog;
      case MissionStatus.greeting:
        return l.modelMissionStatusGreeting;
      case MissionStatus.command:
        return l.modelMissionStatusCommand;
      case MissionStatus.watching:
        return l.modelMissionStatusWatching;
      case MissionStatus.success:
        return l.modelMissionStatusSuccess;
      case MissionStatus.failed:
        return l.modelMissionStatusFailed;
      case MissionStatus.retry:
        return l.modelMissionStatusRetry;
      case MissionStatus.completed:
        return l.modelMissionStatusCompleted;
      case MissionStatus.stopped:
        return l.modelMissionStatusStopped;
      case MissionStatus.unknown:
        return '';
    }
  }
}

extension MissionProgressL10n on MissionProgress {
  /// Localized "Stage 2 of 5"; null when the robot sent no stage info.
  String? localizedStage(AppLocalizations l) {
    final stage = stageNumber;
    final total = totalStages;
    if (stage == null || total == null) return null;
    return l.modelMissionStageOf(stage, total);
  }

  /// Localized status line, with dog name / trick substituted like
  /// [MissionProgress.statusDisplay].
  String localizedStatus(AppLocalizations l) {
    final status = statusEnum;
    final dog = dogName;
    if (dog != null && status == MissionStatus.waitingForDog) {
      return l.modelMissionWaitingForDog(dog);
    }
    if (dog != null && status == MissionStatus.greeting) {
      return l.modelMissionGreetingDog(dog);
    }
    final t = trick;
    if (t != null && status == MissionStatus.command) {
      return '${behaviorDisplayName(l, t).toUpperCase()}!';
    }
    return status.localizedLabel(l);
  }
}

/// Localized catalog name for a mission id; null for ids not in the bundled
/// catalog (server-provided missions keep their own name).
String? missionCatalogName(AppLocalizations l, String id) {
  switch (id) {
    case 'sit':
      return l.catalogMissionSit;
    case 'sit_training':
      return l.catalogMissionSitTraining;
    case 'sit_sustained':
      return l.catalogMissionSitSustained;
    case 'down_sustained':
      return l.catalogMissionDownSustained;
    case 'come_and_sit':
      return l.catalogMissionComeAndSit;
    case 'train_sit_daily':
      return l.catalogMissionTrainSitDaily;
    case 'laydown':
      return l.catalogMissionLaydown;
    case 'come_training':
      return l.catalogMissionComeTraining;
    case 'spin_training':
      return l.catalogMissionSpinTraining;
    case 'sit_and_speak':
      return l.catalogMissionSitAndSpeak;
    case 'speak_morning':
      return l.catalogMissionSpeakMorning;
    case 'speak_afternoon':
      return l.catalogMissionSpeakAfternoon;
    case 'alert_training':
      return l.catalogMissionAlertTraining;
    case 'bark_prevention':
      return l.catalogMissionBarkPrevention;
    case 'stop_barking':
      return l.catalogMissionStopBarking;
    case 'quiet_progressive':
      return l.catalogMissionQuietProgressive;
    case 'comfort_scared':
      return l.catalogMissionComfortScared;
    case 'morning_chill':
      return l.catalogMissionMorningChill;
    case 'morning_quiet_2hr':
      return l.catalogMissionMorningQuiet2hr;
    case 'afternoon_sit_5':
      return l.catalogMissionAfternoonSit5;
    case 'afternoon_down_3':
      return l.catalogMissionAfternoonDown3;
    case 'evening_calm_transition':
      return l.catalogMissionEveningCalmTransition;
    case 'evening_settle':
      return l.catalogMissionEveningSettle;
    case 'night_quiet_90pct':
      return l.catalogMissionNightQuiet90pct;
    // Referenced by program sequences but not in the mission catalog.
    case 'down_training':
      return l.catalogMissionDownTraining;
    case 'quiet_training':
      return l.catalogMissionQuietTraining;
    case 'stay_training':
      return l.catalogMissionStayTraining;
    case 'stand_training':
      return l.catalogMissionStandTraining;
    default:
      return null;
  }
}

/// Localized catalog description for a mission id; null when unknown.
String? missionCatalogDescription(AppLocalizations l, String id) {
  switch (id) {
    case 'sit':
      return l.catalogMissionSitDesc;
    case 'sit_training':
      return l.catalogMissionSitTrainingDesc;
    case 'sit_sustained':
      return l.catalogMissionSitSustainedDesc;
    case 'down_sustained':
      return l.catalogMissionDownSustainedDesc;
    case 'come_and_sit':
      return l.catalogMissionComeAndSitDesc;
    case 'train_sit_daily':
      return l.catalogMissionTrainSitDailyDesc;
    case 'laydown':
      return l.catalogMissionLaydownDesc;
    case 'come_training':
      return l.catalogMissionComeTrainingDesc;
    case 'spin_training':
      return l.catalogMissionSpinTrainingDesc;
    case 'sit_and_speak':
      return l.catalogMissionSitAndSpeakDesc;
    case 'speak_morning':
      return l.catalogMissionSpeakMorningDesc;
    case 'speak_afternoon':
      return l.catalogMissionSpeakAfternoonDesc;
    case 'alert_training':
      return l.catalogMissionAlertTrainingDesc;
    case 'bark_prevention':
      return l.catalogMissionBarkPreventionDesc;
    case 'stop_barking':
      return l.catalogMissionStopBarkingDesc;
    case 'quiet_progressive':
      return l.catalogMissionQuietProgressiveDesc;
    case 'comfort_scared':
      return l.catalogMissionComfortScaredDesc;
    case 'morning_chill':
      return l.catalogMissionMorningChillDesc;
    case 'morning_quiet_2hr':
      return l.catalogMissionMorningQuiet2hrDesc;
    case 'afternoon_sit_5':
      return l.catalogMissionAfternoonSit5Desc;
    case 'afternoon_down_3':
      return l.catalogMissionAfternoonDown3Desc;
    case 'evening_calm_transition':
      return l.catalogMissionEveningCalmTransitionDesc;
    case 'evening_settle':
      return l.catalogMissionEveningSettleDesc;
    case 'night_quiet_90pct':
      return l.catalogMissionNightQuiet90pctDesc;
    default:
      return null;
  }
}

/// Display name for a mission id when no [Mission] object is at hand
/// (program sequences, history rows). Falls back to a humanized id.
String missionIdDisplayName(AppLocalizations l, String id) =>
    missionCatalogName(l, id) ?? id.replaceAll('_', ' ');

extension MissionL10n on Mission {
  String localizedName(AppLocalizations l) => missionCatalogName(l, id) ?? name;

  String? localizedDescription(AppLocalizations l) =>
      missionCatalogDescription(l, id) ?? description;
}

extension ProgramL10n on Program {
  String localizedName(AppLocalizations l) {
    switch (id) {
      case 'puppy_basics':
        return l.catalogProgramPuppyBasics;
      case 'obedience_101':
        return l.catalogProgramObedience101;
      case 'calm_dog':
        return l.catalogProgramCalmDog;
      default:
        return name;
    }
  }

  String localizedDescription(AppLocalizations l) {
    switch (id) {
      case 'puppy_basics':
        return l.catalogProgramPuppyBasicsDesc;
      case 'obedience_101':
        return l.catalogProgramObedience101Desc;
      case 'calm_dog':
        return l.catalogProgramCalmDogDesc;
      default:
        return description;
    }
  }
}

// ---------------------------------------------------------------------------
// Guardian events
// ---------------------------------------------------------------------------

extension GuardianEventTypeL10n on GuardianEventType {
  String localizedLabel(AppLocalizations l) {
    switch (this) {
      case GuardianEventType.dogDetected:
        return l.modelGuardianEventDogDetected;
      case GuardianEventType.dogLeft:
        return l.modelGuardianEventDogLeft;
      case GuardianEventType.barkingDetected:
        return l.modelGuardianEventBarking;
      case GuardianEventType.treatDispensed:
        return l.modelGuardianEventTreatDispensed;
      case GuardianEventType.behaviorChange:
        return l.modelGuardianEventBehaviorChange;
      case GuardianEventType.motionDetected:
        return l.modelGuardianEventMotionDetected;
      case GuardianEventType.quietReward:
        return l.modelGuardianEventQuietReward;
      case GuardianEventType.alertTriggered:
        return l.modelGuardianEventAlertTriggered;
      case GuardianEventType.unknown:
        return l.modelGuardianEventUnknown;
    }
  }
}

extension GuardianEventL10n on GuardianEvent {
  /// Locale-aware time of day (e.g. "10:30 AM" / "오전 10:30").
  String localizedTime(AppLocalizations l) =>
      DateFormat.jm(l.localeName).format(timestamp);

  /// Type label plus details when present.
  String localizedDisplayText(AppLocalizations l) {
    final d = details;
    if (d != null && d.isNotEmpty) {
      return l.modelGuardianEventWithDetails(type.localizedLabel(l), d);
    }
    return type.localizedLabel(l);
  }
}

// ---------------------------------------------------------------------------
// Notification events (default titles by type; instances built in
// notifications_provider may override title/subtitle with richer text)
// ---------------------------------------------------------------------------

extension NotificationEventTypeL10n on NotificationEventType {
  String localizedTitle(AppLocalizations l) {
    switch (this) {
      case NotificationEventType.bark:
        return l.modelNotifTitleBark;
      case NotificationEventType.sit:
        return l.modelNotifTitleSit;
      case NotificationEventType.lieDown:
        return l.modelNotifTitleLieDown;
      case NotificationEventType.stand:
        return l.modelNotifTitleStand;
      case NotificationEventType.treatDispensed:
        return l.modelNotifTitleTreatDispensed;
      case NotificationEventType.missionStarted:
        return l.modelNotifTitleMissionStarted;
      case NotificationEventType.missionCompleted:
        return l.modelNotifTitleMissionCompleted;
      case NotificationEventType.missionFailed:
        return l.modelNotifTitleMissionFailed;
      case NotificationEventType.lowBattery:
        return l.modelNotifTitleLowBattery;
      case NotificationEventType.alert:
        return l.modelNotifTitleAlert;
      case NotificationEventType.happy:
        return l.modelNotifTitleHappy;
      case NotificationEventType.connected:
        return l.modelNotifTitleConnected;
      case NotificationEventType.disconnected:
        return l.modelNotifTitleDisconnected;
      case NotificationEventType.coachReward:
        return l.modelNotifTitleCoachReward;
      case NotificationEventType.panicAlert:
        return l.modelNotifTitlePanicAlert;
      case NotificationEventType.sgSummary:
        return l.modelNotifTitleSgSummary;
      case NotificationEventType.missionDraft:
        return l.modelNotifTitleMissionDraft;
    }
  }
}

// ---------------------------------------------------------------------------
// Night vision
// ---------------------------------------------------------------------------

extension NightModeOverrideL10n on NightModeOverride {
  String localizedLabel(AppLocalizations l) {
    switch (this) {
      case NightModeOverride.auto:
        return l.modelNightOverrideAuto;
      case NightModeOverride.forceDay:
        return l.modelNightOverrideDay;
      case NightModeOverride.forceNight:
        return l.modelNightOverrideNight;
    }
  }
}

/// Localized lux-bucket label; thresholds mirror [NightModeState.luxLabel].
String luxLocalizedLabel(AppLocalizations l, double? lux) {
  if (lux == null) return l.modelLuxDetecting;
  if (lux < 5) return l.modelLuxDark;
  if (lux < 15) return l.modelLuxDim;
  if (lux < 100) return l.modelLuxIndoor;
  if (lux < 1000) return l.modelLuxWellLit;
  return l.modelLuxBright;
}

// ---------------------------------------------------------------------------
// Game controllers
// ---------------------------------------------------------------------------

extension ControllerKindL10n on ControllerKind {
  String localizedLabel(AppLocalizations l) {
    switch (this) {
      case ControllerKind.xbox:
        return l.modelControllerKindXbox;
      case ControllerKind.playstation:
        return l.modelControllerKindPlaystation;
      case ControllerKind.eightBitDo:
        return l.modelControllerKindEightBitDo;
      case ControllerKind.generic:
        return l.modelControllerKindGeneric;
    }
  }

  String localizedPairingHint(AppLocalizations l) {
    switch (this) {
      case ControllerKind.xbox:
        return l.modelControllerHintXbox;
      case ControllerKind.playstation:
        return l.modelControllerHintPlaystation;
      case ControllerKind.eightBitDo:
        return l.modelControllerHintEightBitDo;
      case ControllerKind.generic:
        return l.modelControllerHintGeneric;
    }
  }
}

// ---------------------------------------------------------------------------
// Detections
// ---------------------------------------------------------------------------

extension DetectionL10n on Detection {
  /// Dog name when known, else "Dog Detected" while a dog is in frame.
  String localizedDisplayName(AppLocalizations l) {
    final n = dogName;
    if (n != null && n.isNotEmpty) return n;
    if (detected) return l.modelDetectionDogDetected;
    return '';
  }
}

// ---------------------------------------------------------------------------
// Video quality
// ---------------------------------------------------------------------------

extension VideoTierL10n on VideoTier {
  String localizedLabel(AppLocalizations l) {
    switch (this) {
      case VideoTier.low:
        return l.modelVideoTierLow;
      case VideoTier.medium:
        return l.modelVideoTierMedium;
      case VideoTier.high:
        return l.modelVideoTierHigh;
    }
  }
}

extension VideoQualityModeL10n on VideoQualityMode {
  String localizedLabel(AppLocalizations l) {
    switch (this) {
      case VideoQualityMode.auto:
        return l.modelVideoQualityAuto;
      case VideoQualityMode.low:
        return l.modelVideoQualityLow;
      case VideoQualityMode.medium:
        return l.modelVideoQualityMedium;
      case VideoQualityMode.high:
        return l.modelVideoQualityHigh;
    }
  }
}

// ---------------------------------------------------------------------------
// Schedules
// ---------------------------------------------------------------------------

/// Localized short weekday name for a [DayOfWeek] string constant.
String dayOfWeekShortLabel(AppLocalizations l, String day) {
  switch (day) {
    case DayOfWeek.sunday:
      return l.modelDaySun;
    case DayOfWeek.monday:
      return l.modelDayMon;
    case DayOfWeek.tuesday:
      return l.modelDayTue;
    case DayOfWeek.wednesday:
      return l.modelDayWed;
    case DayOfWeek.thursday:
      return l.modelDayThu;
    case DayOfWeek.friday:
      return l.modelDayFri;
    case DayOfWeek.saturday:
      return l.modelDaySat;
    default:
      return day;
  }
}

extension MissionScheduleL10n on MissionSchedule {
  /// Card title (relay brief 2026-11-07 §1): a mode mission shows its name,
  /// falling back to "Silent Guardian" / "Coach mode" — never "SIT"; a
  /// training mission shows its name or the catalog label for its id.
  String localizedTitle(AppLocalizations l) {
    if (isModeMission) {
      if (name.isNotEmpty) return name;
      return missionType == 'coach'
          ? l.schedulerModeCoach
          : l.schedulerModeSilentGuardian;
    }
    if (name.isNotEmpty) return name;
    return missionIdDisplayName(l, missionType ?? missionName);
  }

  /// Locale-aware start time (e.g. "9:00 AM" / "오전 9:00").
  String localizedTime(AppLocalizations l) {
    final t = DateTime(2000, 1, 1, hour, minute);
    return DateFormat.jm(l.localeName).format(t);
  }

  /// Localized equivalent of [MissionSchedule.scheduleDescription].
  String localizedDescription(AppLocalizations l) {
    final time = localizedTime(l);
    switch (type) {
      case ScheduleType.once:
        return l.modelScheduleOnceAt(time);
      case ScheduleType.daily:
        return l.modelScheduleDailyAt(time);
      case ScheduleType.weekly:
        if (daysOfWeek.isEmpty) return l.modelScheduleWeeklyAt(time);
        if (daysOfWeek.length == 7) return l.modelScheduleEveryDayAt(time);
        final days = daysOfWeek.map((d) => dayOfWeekShortLabel(l, d)).join(', ');
        return l.modelScheduleDaysAt(days, time);
    }
  }
}
