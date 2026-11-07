// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'WIM-Z';

  @override
  String get cancel => '취소';

  @override
  String get save => '저장';

  @override
  String get delete => '삭제';

  @override
  String get ok => '확인';

  @override
  String get done => '완료';

  @override
  String get close => '닫기';

  @override
  String get retry => '다시 시도';

  @override
  String get edit => '편집';

  @override
  String get add => '추가';

  @override
  String get back => '뒤로';

  @override
  String get yes => '예';

  @override
  String get no => '아니요';

  @override
  String get confirm => '확인';

  @override
  String get remove => '제거';

  @override
  String get loading => '불러오는 중...';

  @override
  String get error => '오류';

  @override
  String get unknown => '알 수 없음';

  @override
  String get on => '켜짐';

  @override
  String get off => '꺼짐';

  @override
  String get enabled => '사용';

  @override
  String get disabled => '사용 안 함';

  @override
  String get connected => '연결됨';

  @override
  String get disconnected => '연결 끊김';

  @override
  String get connecting => '연결 중...';

  @override
  String get settings => '설정';

  @override
  String get signOut => '로그아웃';

  @override
  String get none => '없음';

  @override
  String get today => '오늘';

  @override
  String get yesterday => '어제';

  @override
  String get language => '언어';

  @override
  String get languageSystemDefault => '시스템 기본값';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKorean => '한국어';

  @override
  String get languageSubtitle => '앱 표시 언어를 선택하세요';

  @override
  String get appRateLimited => '명령이 너무 많아요. 잠시 천천히 해주세요';

  @override
  String get appReconnecting => '다시 연결 중...';

  @override
  String get appTapToRetry => '탭하여 다시 시도';

  @override
  String get navHome => '홈';

  @override
  String get navDogs => '반려견';

  @override
  String get navMissions => '미션';

  @override
  String get navPhotos => '사진';

  @override
  String get navActivity => '활동';

  @override
  String get unknownError => '알 수 없는 오류';

  @override
  String get quickActionsSongFallback => '노래';

  @override
  String get quickActionsFileFallback => '파일';

  @override
  String quickActionsDeleted(String filename) {
    return '\"$filename\"을(를) 삭제했습니다';
  }

  @override
  String quickActionsDeleteFailed(String error) {
    return '삭제 실패: $error';
  }

  @override
  String quickActionsUploaded(String filename) {
    return '\"$filename\" 업로드를 완료했습니다';
  }

  @override
  String quickActionsUploadFailed(String error) {
    return '업로드 실패: $error';
  }

  @override
  String get quickActionsTreat => '간식';

  @override
  String get quickActionsGood => '잘했어';

  @override
  String get quickActionsCallDog => '부르기';

  @override
  String get quickActionsWant => '먹을래?';

  @override
  String get quickActionsNo => '안 돼';

  @override
  String get quickActionsQuiet => '조용히';

  @override
  String get quickActionsSit => '앉아';

  @override
  String quickActionsLedPattern(String pattern) {
    return 'LED: $pattern';
  }

  @override
  String get quickActionsLedNotSent => '연결되지 않음 — LED 명령을 보내지 못했습니다';

  @override
  String get quickActionsSelectMp3 => 'MP3 파일을 선택하세요';

  @override
  String get quickActionsFileAccessFailed => '파일에 접근할 수 없습니다';

  @override
  String get quickActionsFileTooLarge => '파일이 너무 큽니다 (최대 20MB)';

  @override
  String get quickActionsUploadLocalUnavailable =>
      '로컬 모드에서는 음악 업로드를 사용할 수 없습니다';

  @override
  String get quickActionsNotAuthenticated => '인증되지 않았습니다 - 로그인하세요';

  @override
  String quickActionsUploading(String filename) {
    return '\"$filename\" 업로드 중...';
  }

  @override
  String quickActionsFilePickerFailed(String error) {
    return '파일 선택기를 열 수 없습니다: $error';
  }

  @override
  String get quickActionsSelectDogFirst => '먼저 반려견을 선택하세요';

  @override
  String get quickActionsDeleteSongTitle => '노래 삭제';

  @override
  String quickActionsDeleteSongConfirm(String name) {
    return '재생 목록에서 \"$name\"을(를) 삭제할까요?';
  }

  @override
  String quickActionsDeletingSong(String name) {
    return '\"$name\" 삭제 중...';
  }

  @override
  String get ledPatternRainbow => '무지개';

  @override
  String get ledPatternFire => '불꽃';

  @override
  String get ledPatternBlue => '파랑';

  @override
  String get ledPatternChase => '체이스';

  @override
  String get ledPatternAmbient => '앰비언트';

  @override
  String get quickActionsLighting => '조명';

  @override
  String get quickActionsBluLight => '블루라이트';

  @override
  String get dismiss => '닫기';

  @override
  String get pttTalk => '말하기';

  @override
  String get pttRecording => '녹음 중';

  @override
  String get pttSent => '전송됨 ✓';

  @override
  String pttSeconds(int sec) {
    return '$sec초';
  }

  @override
  String get pttSending => '전송 중...';

  @override
  String get pttPlaying => '재생 중...';

  @override
  String get pttListening => '듣는 중...';

  @override
  String get pttTapToListen => '눌러서 듣기';

  @override
  String panTiltPan(String value) {
    return 'P:$value';
  }

  @override
  String panTiltTilt(String value) {
    return 'T:$value';
  }

  @override
  String get panTiltCenter => '중앙';

  @override
  String get audioMuteListening => '로봇 소리 듣는 중...';

  @override
  String get audioMuteUnmute => '음소거 해제';

  @override
  String get audioMuteMute => '음소거';

  @override
  String get mjpegUnavailable => '영상을 사용할 수 없습니다';

  @override
  String get mjpegConnecting => '카메라에 연결 중...';

  @override
  String get videoHudFps => 'FPS';

  @override
  String get videoHudBattery => '배터리';

  @override
  String get videoHudPan => '팬';

  @override
  String get videoHudRec => 'REC';

  @override
  String get videoSavedNotWired => '로봇에 녹화 다운로드 기능(Chain REC)이 추가되면 사용할 수 있습니다';

  @override
  String get videoSavedSampleData => '샘플 데이터 — 실시간 아님';

  @override
  String get videoSavedTitle => '영상이 저장되었습니다';

  @override
  String get videoSavedOnRobotAt => '로봇 저장 위치';

  @override
  String get videoSavedPathCopied => '경로를 복사했습니다';

  @override
  String videoSavedRetention(String retentionClass) {
    return '보관: $retentionClass';
  }

  @override
  String get videoSavedSaveToPhone => '휴대폰에 저장';

  @override
  String get videoSavedShare => '공유';

  @override
  String get webrtcWaitingForConnection => '연결을 기다리는 중...';

  @override
  String get webrtcTapToConnect => '눌러서 연결';

  @override
  String get webrtcConnectingVideo => '영상 연결 중...';

  @override
  String get webrtcConnectionFailed => '영상 연결에 실패했습니다';

  @override
  String get webrtcInitializingRenderer => '렌더러 초기화 중...';

  @override
  String get webrtcWaitingForStream => '영상 스트림을 기다리는 중...';

  @override
  String get webrtcReceivingVideo => '영상 수신 중...';

  @override
  String get videoSavedToGallery => '영상을 갤러리에 저장했습니다!';

  @override
  String get videoSavedShort => '영상을 저장했습니다!';

  @override
  String get photoSavedToGallery => '사진을 갤러리에 저장했습니다!';

  @override
  String get photoSavedShort => '사진을 저장했습니다!';

  @override
  String get gaugeCharging => '충전 중';

  @override
  String get gaugeBattery => '배터리';

  @override
  String get gaugeLeft => '좌';

  @override
  String get gaugeRight => '우';

  @override
  String get schedulerTitle => '훈련 스케줄러';

  @override
  String get schedulerAddSchedule => '일정 추가';

  @override
  String get schedulerAutoScheduler => '자동 스케줄러';

  @override
  String get schedulerRunsAutomatically => '훈련이 자동으로 실행됩니다';

  @override
  String get schedulerPaused => '일정이 일시정지되었습니다';

  @override
  String get schedulerEmptyTitle => '예약된 훈련이 없습니다';

  @override
  String get schedulerEmptyBody => '반려견을 위한 자동 훈련 세션을\n원하는 시간에 예약하세요';

  @override
  String get schedulerDeleteTitle => '일정 삭제';

  @override
  String get schedulerDeleteConfirm => '이 일정을 삭제하시겠습니까?';

  @override
  String get schedulerUnknownDog => '알 수 없는 반려견';

  @override
  String get schedulerPausedBadge => '일시정지';

  @override
  String schedulerNextRun(String next) {
    return '다음: $next';
  }

  @override
  String get scheduleEditSelectDogAndMission => '반려견과 미션을 선택하세요';

  @override
  String get scheduleEditSelectOneDay => '요일을 하나 이상 선택하세요';

  @override
  String get scheduleEditMissionNotFound => '선택한 미션을 찾을 수 없습니다';

  @override
  String get scheduleEditUpdated => '일정이 업데이트되었습니다';

  @override
  String get scheduleEditCreated => '일정이 생성되었습니다';

  @override
  String get scheduleEditUpdateFailed => '일정 업데이트에 실패했습니다';

  @override
  String get scheduleEditCreateFailed => '일정 생성에 실패했습니다';

  @override
  String get scheduleEditTitleEdit => '일정 편집';

  @override
  String get scheduleEditTitleNew => '새 일정';

  @override
  String get scheduleEditSectionDog => '반려견';

  @override
  String get scheduleEditSelectDog => '반려견 선택';

  @override
  String get scheduleEditSectionMission => '훈련 미션';

  @override
  String get scheduleEditSelectMission => '미션 선택';

  @override
  String get scheduleEditSectionTime => '시간';

  @override
  String get scheduleEditSectionRepeat => '반복';

  @override
  String get scheduleEditOnce => '한 번';

  @override
  String get scheduleEditDaily => '매일';

  @override
  String get scheduleEditWeekly => '매주';

  @override
  String get scheduleEditWeekdayLetters => '일,월,화,수,목,금,토';

  @override
  String get missionsTitle => '훈련';

  @override
  String get missionsProgramsHeader => '훈련 프로그램';

  @override
  String get missionsProgramsSubtitle => '휴식 시간이 포함된 다중 미션 시퀀스';

  @override
  String get missionsIndividualHeader => '개별 미션';

  @override
  String get missionsIndividualSubtitle => '단일 훈련 세션';

  @override
  String get missionsNoneConfigured => '설정된 미션이 없습니다';

  @override
  String get missionsActiveBadge => '진행 중';

  @override
  String get missionsDriveButton => '조종';

  @override
  String get missionsStop => '중지';

  @override
  String missionsPercentComplete(int percent) {
    return '$percent% 완료';
  }

  @override
  String missionsCountChip(int count) {
    return '미션 $count개';
  }

  @override
  String missionsRestChip(int seconds) {
    return '휴식 $seconds초';
  }

  @override
  String get missionsProgramBadge => '프로그램';

  @override
  String missionsRestBreak(int seconds) {
    return '휴식 시간: $seconds초';
  }

  @override
  String missionsMissionOf(int current, int total) {
    return '미션 $current/$total';
  }

  @override
  String get missionsCoachMode => '코치 모드';

  @override
  String get missionsCoachWatching => '좋은 행동을 지켜보는 중...';

  @override
  String get missionsCoachSubtitle => '반려견이 트릭을 하면 자동으로 보상합니다';

  @override
  String get missionDetailTitle => '미션';

  @override
  String get missionDetailNotFound => '미션을 찾을 수 없습니다';

  @override
  String get missionDetailSectionDetails => '미션 정보';

  @override
  String get missionDetailTargetBehavior => '목표 행동';

  @override
  String get missionDetailHoldDuration => '유지 시간';

  @override
  String missionDetailSecondsShort(String seconds) {
    return '$seconds초';
  }

  @override
  String get missionDetailCooldown => '쿨다운';

  @override
  String missionDetailCooldownValue(int seconds) {
    return '보상 간 $seconds초';
  }

  @override
  String get missionDetailDailyLimit => '일일 제한';

  @override
  String missionDetailTreatsCount(int count) {
    return '간식 $count개';
  }

  @override
  String get missionDetailProgress => '진행 상황';

  @override
  String missionDetailTreatsGiven(int given, int limit) {
    return '간식 $given/$limit개 지급';
  }

  @override
  String get missionDetailHowItWorks => '작동 방식';

  @override
  String missionDetailBulletWatches(String behavior) {
    return 'WIM-Z가 \"$behavior\" 행동을 지켜봅니다';
  }

  @override
  String missionDetailBulletHold(String seconds) {
    return '반려견이 $seconds초 동안 자세를 유지해야 합니다';
  }

  @override
  String get missionDetailBulletTreat => '성공하면 간식이 자동으로 지급됩니다';

  @override
  String missionDetailBulletCooldown(int seconds) {
    return '보상 사이 $seconds초 쿨다운';
  }

  @override
  String missionDetailBulletLimit(int count) {
    return '세션당 최대 간식 $count개';
  }

  @override
  String get missionDetailStopMission => '미션 중지';

  @override
  String get missionDetailRobotNotConnected => '로봇이 연결되지 않음';

  @override
  String get missionDetailAnotherActive => '다른 미션 진행 중';

  @override
  String get missionDetailStarting => '시작하는 중...';

  @override
  String get missionDetailStartMission => '미션 시작';

  @override
  String get programTitle => '프로그램';

  @override
  String get programNotFound => '프로그램을 찾을 수 없습니다';

  @override
  String get programStop => '프로그램 중지';

  @override
  String get programMissionSequence => '미션 순서';

  @override
  String get programRunningBadge => '실행 중';

  @override
  String get programRestBreak => '휴식 시간';

  @override
  String programSecondsUntilNext(int seconds) {
    return '다음 미션까지 $seconds초';
  }

  @override
  String programPercentThrough(int percent) {
    return '프로그램 $percent% 진행';
  }

  @override
  String get programNowBadge => '지금';

  @override
  String get programDetails => '프로그램 정보';

  @override
  String get programTotalMissions => '총 미션 수';

  @override
  String get programRestBetween => '미션 간 휴식';

  @override
  String programSecondsValue(int seconds) {
    return '$seconds초';
  }

  @override
  String get programEstimatedTime => '예상 시간';

  @override
  String programMinutesRange(int min, int max) {
    return '$min~$max분';
  }

  @override
  String programStartWith(String dog) {
    return '$dog 훈련 시작';
  }

  @override
  String get programStart => '프로그램 시작';

  @override
  String get programConnectToStart => '시작하려면 로봇에 연결하세요';

  @override
  String get programStopCurrentFirst => '현재 진행 중인 훈련을 먼저 중지하세요';

  @override
  String get coachCoachingBadge => '코칭 중';

  @override
  String get coachStoppedBadge => '중지됨';

  @override
  String get coachDogDetected => '반려견 감지됨';

  @override
  String get coachWhenDogVisible => '반려견이 보일 때:';

  @override
  String get coachSelectDogHint => '반려견을 선택하거나 카메라가 인식할 때까지 기다리세요.';

  @override
  String get coachExit => '코치 모드 종료';

  @override
  String get coachGoodBang => '잘했어요!';

  @override
  String coachBehaviorBang(String behavior) {
    return '$behavior!';
  }

  @override
  String get historyTitle => '훈련 기록';

  @override
  String get historyTimeRange => '기간';

  @override
  String get historyLast7Days => '최근 7일';

  @override
  String get historyLast2Weeks => '최근 2주';

  @override
  String get historyLastMonth => '최근 한 달';

  @override
  String get historyDogFilter => '반려견';

  @override
  String get historyAllDogs => '모든 반려견';

  @override
  String get historyStatSessions => '세션';

  @override
  String get historyStatCompleted => '완료';

  @override
  String get historyStatTreats => '간식';

  @override
  String get historyStatSuccess => '성공률';

  @override
  String get historyInProgress => '진행 중';

  @override
  String historyStages(int done, int total) {
    return '단계 $done/$total';
  }

  @override
  String historyDurationSeconds(int n) {
    return '$n초';
  }

  @override
  String historyDurationMinutes(int n) {
    return '$n분';
  }

  @override
  String historyDurationHoursMinutes(int h, int m) {
    return '$h시간 $m분';
  }

  @override
  String get historyEmptyTitle => '훈련 기록이 없습니다';

  @override
  String get historyEmptyBody => '훈련 세션을 완료하면 진행 상황을 볼 수 있습니다';

  @override
  String get signOutConfirmBody => '정말 로그아웃하시겠어요? 다시 로그인해야 합니다.';

  @override
  String get settingsSectionConnection => '연결';

  @override
  String get settingsSectionMyRobots => '내 로봇';

  @override
  String get settingsSectionController => '컨트롤러';

  @override
  String get settingsSectionRobotStatus => '로봇 상태';

  @override
  String get settingsSectionCalibration => '보정';

  @override
  String get settingsSectionCamera => '카메라';

  @override
  String get settingsSectionNightVision => '야간 투시';

  @override
  String get settingsSectionVideo => '비디오';

  @override
  String get settingsSectionAudio => '오디오';

  @override
  String get settingsSectionNotifications => '알림';

  @override
  String get settingsSectionSilentGuardian => '사일런트 가디언';

  @override
  String get settingsSectionTraining => '훈련';

  @override
  String get settingsSectionDiagnostics => '진단';

  @override
  String get settingsSectionAbout => '정보';

  @override
  String get settingsSectionAccount => '계정';

  @override
  String get settingsGameController => '게임 컨트롤러';

  @override
  String get settingsGameControllerSubtitle => '게임 컨트롤러를 로봇에 페어링합니다';

  @override
  String get settingsBattery => '배터리';

  @override
  String get settingsTemperature => '온도';

  @override
  String get settingsNotAvailable => '해당 없음';

  @override
  String get settingsCurrentMode => '현재 모드';

  @override
  String get settingsTrainingScheduler => '훈련 스케줄러';

  @override
  String get settingsTrainingSchedulerSubtitle => '자동 훈련 세션을 예약합니다';

  @override
  String get settingsVoiceCommands => '음성 명령';

  @override
  String get settingsVoiceCommandsSubtitle => '반려견을 위한 맞춤 음성 명령을 녹음합니다';

  @override
  String get settingsTestRecording => '녹음 테스트';

  @override
  String get settingsTestRecordingSubtitle => '녹음 진단을 실행합니다';

  @override
  String get settingsConnectionDiagnostics => '연결 진단';

  @override
  String get settingsConnectionDiagnosticsSubtitle => 'WebRTC 시그널링 추적 (비디오 연결)';

  @override
  String get settingsUiPreviews => 'UI 미리보기';

  @override
  String get settingsUiPreviewsSubtitle => '샘플 데이터 기반 스펙 뷰 (개발용)';

  @override
  String get settingsAppName => 'WIM-Z 앱';

  @override
  String settingsAppVersion(String version) {
    return '버전 $version';
  }

  @override
  String get settingsApiVersion => 'API 버전';

  @override
  String settingsConnectedToRobot(String ip) {
    return '로봇에 연결됨 ($ip)';
  }

  @override
  String get settingsLocalNotConnected => '로컬 모드 — 연결되지 않음';

  @override
  String get settingsDirectViaWifi => 'WIMZ WiFi를 통한 직접 연결';

  @override
  String get settingsConnectedViaCloud => '클라우드로 연결됨';

  @override
  String settingsRelayHost(String host) {
    return '서버: $host';
  }

  @override
  String get settingsLocalRobotDirect => '로컬 로봇 · 직접 연결 (192.168.4.1)';

  @override
  String get settingsNoRobotsPaired => '페어링된 로봇 없음 — 탭하여 추가하세요';

  @override
  String settingsRobotsPairedActive(String name, int count) {
    return '$name · 로봇 $count대 페어링됨';
  }

  @override
  String settingsRobotsPairedSelect(int count) {
    return '로봇 $count대 페어링됨 — 탭하여 선택하세요';
  }

  @override
  String get settingsManageRobots => '로봇 관리';

  @override
  String settingsOtaUpdating(String version, String state, String pct) {
    return '$version(으)로 업데이트 중: $state$pct';
  }

  @override
  String settingsOtaUpdated(String version) {
    return '$version(으)로 업데이트됨 ✓';
  }

  @override
  String settingsOtaRolledBack(String detail) {
    return '업데이트 실패 — 안전하게 롤백됨$detail';
  }

  @override
  String settingsOtaFailed(String detail) {
    return '업데이트 실패$detail';
  }

  @override
  String get settingsOtaNotReported => '버전 정보 없음 — 로봇 업데이터가 아직 설치되지 않았습니다';

  @override
  String get settingsOtaUpToDateNoRelease => '최신 상태 — 서버에 새 릴리스가 없습니다';

  @override
  String settingsOtaAvailable(String version) {
    return '업데이트 가능: $version';
  }

  @override
  String get settingsOtaUpToDate => '최신 상태';

  @override
  String get settingsRobotSoftware => '로봇 소프트웨어';

  @override
  String get settingsUpdateCaps => '업데이트';

  @override
  String get settingsUpdate => '업데이트';

  @override
  String get settingsUpdateRobotSoftware => '로봇 소프트웨어 업데이트';

  @override
  String settingsUpdateConfirmBody(String from, String to) {
    return '로봇을 $from에서 $to(으)로 업데이트할까요?\n\n로봇은 대기 상태이고 배터리가 30% 이상이어야 합니다. 업데이트 중 재시작되며 문제가 생기면 자동으로 롤백됩니다.';
  }

  @override
  String get settingsTreats => '간식';

  @override
  String settingsTreatsOfCapacity(int remaining, int capacity) {
    return '$remaining / $capacity';
  }

  @override
  String get settingsTreatsEmpty => '비어 있음 — 리필이 필요합니다';

  @override
  String settingsTreatsRemaining(int remaining) {
    return '$remaining개 남음';
  }

  @override
  String settingsTreatsRemainingLow(int remaining) {
    return '$remaining개 남음 — 부족합니다';
  }

  @override
  String get settingsDailyTreatLimit => '일일 간식 제한';

  @override
  String settingsDailyLimitMax(int count) {
    return '하루 최대 $count개 자동 간식';
  }

  @override
  String get settingsDailyLimitNone => '일일 제한 없음 — 자동 간식 무제한';

  @override
  String get settingsCameraTrackDog => '카메라 반려견 추적';

  @override
  String get settingsCameraTrackOn => '코치/미션 모드에서 카메라가 반려견을 따라갑니다';

  @override
  String get settingsCameraTrackOff => '카메라가 중앙에 고정됩니다';

  @override
  String get settingsVideoQuality => '비디오 화질';

  @override
  String get settingsQualityAuto => '자동';

  @override
  String get settingsQualityLow => '낮음';

  @override
  String get settingsQualityMed => '중간';

  @override
  String get settingsQualityHigh => '높음';

  @override
  String get settingsStreamingNotConnected => '연결되지 않음';

  @override
  String settingsCurrentlyStreaming(String label) {
    return '현재 스트리밍: $label';
  }

  @override
  String get settingsBackgroundAudio => '백그라운드 오디오';

  @override
  String get settingsBackgroundAudioOn => '앱이 백그라운드에 있어도 계속 듣습니다';

  @override
  String get settingsBackgroundAudioOff => '앱이 백그라운드로 가면 오디오가 중지됩니다';

  @override
  String get settingsActivityNotifications => '활동 알림';

  @override
  String get settingsNotificationsOn => '잠금 화면 및 Apple Watch에 알림 표시';

  @override
  String get settingsNotificationsOff => '알림 꺼짐';

  @override
  String get settingsPerEventPrefs => '이벤트별 설정';

  @override
  String get settingsPerEventPrefsSubtitle =>
      '잠금 화면으로 푸시할 이벤트와 앱 내에서만 표시할 이벤트를 선택하세요';

  @override
  String get settingsMotorTrim => '모터 트림 (오른쪽)';

  @override
  String get settingsMotorTrimNone => '조정 없음';

  @override
  String settingsMotorTrimSlowing(int pct) {
    return '오른쪽 모터 $pct% 감속';
  }

  @override
  String settingsMotorTrimSpeeding(int pct) {
    return '오른쪽 모터 $pct% 가속';
  }

  @override
  String get settingsReset => '초기화';

  @override
  String get settingsMotorTrimHint => '로봇이 왼쪽으로 쏠리면 트림을 올리고, 오른쪽으로 쏠리면 내리세요.';

  @override
  String get settingsWifiHelp => 'WiFi 설정 도움말';

  @override
  String get settingsWifiHelpSubtitle => '로봇 연결 방법';

  @override
  String get settingsWifiHelpTitle => 'WIM-Z를 WiFi에 연결하기';

  @override
  String get settingsWifiStep1 => 'WIM-Z 로봇의 전원을 켜세요';

  @override
  String get settingsWifiStep2 =>
      'WiFi에 연결되어 있지 않으면 \"WIMZ-XXXX\"라는 핫스팟이 생성됩니다';

  @override
  String get settingsWifiStep3 => '휴대폰에서 설정 → WiFi로 이동하세요';

  @override
  String get settingsWifiStep4 => '\"WIMZ-XXXX\"에 연결하세요';

  @override
  String get settingsWifiStep4Detail => '비밀번호: wimzsetup';

  @override
  String get settingsWifiStep5 => '브라우저를 열고 다음 주소로 이동하세요:';

  @override
  String get settingsWifiStep6 => '집 WiFi 네트워크를 선택하고 비밀번호를 입력하세요';

  @override
  String get settingsWifiStep7 => '로봇이 재부팅되고 네트워크에 연결됩니다';

  @override
  String get settingsWifiStep8 => '이 앱으로 돌아와 로봇과 페어링하세요';

  @override
  String get settingsLedGuide => 'LED 상태 안내';

  @override
  String get settingsLedSpinningCyan => '회전하는 청록색';

  @override
  String get settingsLedSearchingWifi => 'WiFi 검색 중';

  @override
  String get settingsLedPulsingBlue => '깜빡이는 파란색';

  @override
  String get settingsLedSetupMode => '설정 모드 (WIMZ 핫스팟에 연결)';

  @override
  String get settingsLedSolidGreen => '고정 초록색';

  @override
  String get settingsLedConnectedWifi => 'WiFi에 연결됨';

  @override
  String get settingsLedPulsingRed => '깜빡이는 빨간색';

  @override
  String get settingsRobotNetwork => '로봇 네트워크';

  @override
  String get settingsNetHotspot => '핫스팟 (AP)';

  @override
  String get settingsNetWifi => 'WiFi';

  @override
  String get settingsNetMode => '모드';

  @override
  String get settingsNetNetwork => '네트워크';

  @override
  String get settingsNetIp => 'IP';

  @override
  String get settingsConfigureRobotWifi => '로봇 WiFi 설정';

  @override
  String get settingsWifiScanFailed => '검색 실패';

  @override
  String get settingsWifiScanning => 'WiFi 네트워크 검색 중...';

  @override
  String get settingsWifiNoneFound => 'WiFi 네트워크를 찾을 수 없습니다';

  @override
  String get settingsWifiScanAgain => '다시 검색';

  @override
  String get settingsWifiPassword => '비밀번호';

  @override
  String get settingsWifiPasswordHint => 'WiFi 비밀번호를 입력하세요';

  @override
  String get settingsWifiConnect => '연결';

  @override
  String get settingsTryAgain => '다시 시도';

  @override
  String get settingsWifiRobotConnecting => '로봇이 WiFi에 연결하는 중...';

  @override
  String get settingsWifiMayTakeMoment => '잠시 시간이 걸릴 수 있습니다.';

  @override
  String get settingsWifiRobotSwitching => '로봇이 WiFi로 전환하는 중...';

  @override
  String get settingsWifiHotspotShutdown =>
      '로컬 핫스팟이 종료됩니다.\n잠시 후 연결이 끊길 수 있습니다.';

  @override
  String get settingsWifiCommandSent => 'WiFi 명령을 보냈습니다!';

  @override
  String get settingsWifiCommandSentBody =>
      '로봇이 WiFi로 전환 중입니다. 휴대폰을 같은 WiFi 네트워크에 연결한 다음 로컬 모드를 끄면 서버 연결을 사용할 수 있습니다.';

  @override
  String get settingsGotIt => '알겠습니다';

  @override
  String get settingsSignalExcellent => '매우 좋음';

  @override
  String get settingsSignalGood => '좋음';

  @override
  String get settingsSignalFair => '보통';

  @override
  String get settingsSignalWeak => '약함';

  @override
  String get settingsDiagRunning => '진단 실행 중...';

  @override
  String settingsDiagError(String error, String stack) {
    return '진단 오류: $error\n\n스택: $stack';
  }

  @override
  String get settingsRecordingDiagnostics => '녹음 진단';

  @override
  String get settingsRunningTests => '테스트 실행 중...';

  @override
  String get settingsRunAgain => '다시 실행';

  @override
  String get notifPrefsTitle => '알림 설정';

  @override
  String get notifPrefsResetDefaults => '기본값으로 초기화';

  @override
  String get notifPrefsEnableLockScreen => '잠금 화면 알림 사용';

  @override
  String get notifPrefsMasterSubtitle =>
      '마스터 스위치입니다. 끄면 잠금 화면이나 Apple Watch로 아무것도 푸시되지 않으며, 이벤트는 앱 내 피드에만 표시됩니다.';

  @override
  String get notifPrefsPerEventType => '이벤트 유형별';

  @override
  String get notifPrefsLegend =>
      '꺼짐 — 기록하지 않습니다.\n앱 내 — 활동 피드에만 표시됩니다.\n앱 내 + 푸시 — 잠금 화면과 Apple Watch도 깨웁니다.';

  @override
  String get notifPrefsBarking => '짖음';

  @override
  String get notifPrefsSitDetected => '앉기 감지';

  @override
  String get notifPrefsLayDownDetected => '엎드리기 감지';

  @override
  String get notifPrefsComeStandDetected => '이리 와 / 서기 감지';

  @override
  String get notifPrefsTreatDispensed => '간식 지급';

  @override
  String get notifPrefsMissionStarted => '미션 시작';

  @override
  String get notifPrefsMissionCompleted => '미션 완료';

  @override
  String get notifPrefsMissionFailed => '미션 실패';

  @override
  String get notifPrefsLowBattery => '배터리 부족';

  @override
  String get notifPrefsGuardianAlert => '가디언 경고';

  @override
  String get notifPrefsHappyDog => '행복한 반려견';

  @override
  String get notifPrefsRobotConnected => '로봇 연결됨';

  @override
  String get notifPrefsRobotDisconnected => '로봇 연결 끊김';

  @override
  String get notifPrefsCoachReward => '코치 보상';

  @override
  String get notifPrefsPanicAlert => '패닉 경고';

  @override
  String get notifPrefsSgSummary => '가디언 세션 요약';

  @override
  String get notifPrefsInApp => '앱 내';

  @override
  String get notifPrefsPlusPush => '+ 푸시';

  @override
  String get controllerPairingTitle => '게임 컨트롤러';

  @override
  String get controllerPairingRefresh => '새로고침';

  @override
  String get controllerPairingRobotNotConnected => '로봇이 연결되지 않음';

  @override
  String get controllerPairingRobotNotConnectedBody =>
      '먼저 로봇에 연결한 다음 다시 돌아와 컨트롤러를 페어링하세요.';

  @override
  String get controllerPairingChecking => '로봇 확인 중…';

  @override
  String get controllerPairingCheckingBody => '로봇에 컨트롤러 정보를 요청하고 있습니다.';

  @override
  String get controllerPairingNoResponse => '로봇 응답 없음';

  @override
  String get controllerPairingNoResponseBody =>
      '로봇이 컨트롤러 확인에 응답하지 않았습니다. 아직 시작 중이거나 펌웨어가 컨트롤러 페어링을 지원하지 않을 수 있습니다. 잠시 후 다시 시도하세요.';

  @override
  String get controllerPairingSavedControllers => '저장된 컨트롤러';

  @override
  String get controllerPairingNoSaved =>
      '저장된 컨트롤러가 아직 없습니다. 아래에서 검색하여 페어링한 다음, 신뢰 설정을 켜면 로봇이 자동으로 다시 연결합니다.';

  @override
  String get controllerPairingAddController => '컨트롤러 추가';

  @override
  String get controllerPairingForgetTitle => '컨트롤러를 삭제할까요?';

  @override
  String controllerPairingForgetBody(String name) {
    return '로봇이 \"$name\"의 페어링을 해제하고 자동 재연결을 중단합니다. 나중에 다시 페어링할 수 있습니다.';
  }

  @override
  String get controllerPairingForget => '삭제';

  @override
  String get controllerPairingController => '컨트롤러';

  @override
  String get controllerPairingNoneConnected => '연결된 컨트롤러 없음';

  @override
  String get controllerPairingTrusted => '신뢰됨';

  @override
  String get controllerPairingSavedNotConnected => '저장됨 · 연결되지 않음';

  @override
  String get controllerPairingReconnect => '다시 연결';

  @override
  String get controllerPairingAutoReconnect => '자동 재연결 (신뢰)';

  @override
  String get controllerPairingPair => '페어링';

  @override
  String get controllerPairingScanning => '컨트롤러 검색 중…';

  @override
  String get controllerPairingScan => '컨트롤러 검색';

  @override
  String get controllerPairingScanningHint => '컨트롤러를 페어링 모드로 전환하세요';

  @override
  String get controllerPairingScanHint => '로봇이 근처 컨트롤러를 찾습니다';

  @override
  String get devicePairingEnterId => '기기 ID를 입력하세요';

  @override
  String get devicePairingInvalidId => '기기 ID는 3~50자여야 합니다: 영문, 숫자, _ 또는 -';

  @override
  String devicePairingPaired(String deviceId) {
    return '$deviceId 페어링 완료';
  }

  @override
  String get devicePairingUnpairTitle => '기기 페어링 해제';

  @override
  String devicePairingUnpairBody(String deviceId) {
    return '$deviceId의 페어링을 해제할까요?';
  }

  @override
  String get devicePairingUnpair => '페어링 해제';

  @override
  String devicePairingUnpaired(String deviceId) {
    return '$deviceId 페어링 해제됨';
  }

  @override
  String get devicePairingNotFoundTitle => '로봇을 찾을 수 없음';

  @override
  String devicePairingNotFoundBody(String deviceId) {
    return '서버에 \"$deviceId\" 기록이 없습니다. 이 항목은 고아 상태라 정상적으로 제거할 수 없습니다. 그래도 목록에서 숨길까요?';
  }

  @override
  String get devicePairingKeep => '유지';

  @override
  String get devicePairingHide => '숨기기';

  @override
  String devicePairingHidden(String deviceId) {
    return '$deviceId을(를) 목록에서 숨겼습니다';
  }

  @override
  String devicePairingConnectingTo(String label) {
    return '$label에 연결 중…';
  }

  @override
  String get devicePairingTitle => '내 로봇';

  @override
  String get devicePairingPairNew => '새 기기 페어링';

  @override
  String get devicePairingIdHint => '기기 ID 입력 (예: wimz_robot_01)';

  @override
  String get devicePairingPair => '페어링';

  @override
  String get devicePairingNoDevices => '페어링된 기기 없음';

  @override
  String get devicePairingNoDevicesBody => '위에 기기 ID를 입력하여 WIM-Z를 페어링하세요';

  @override
  String get devicePairingActive => '활성';

  @override
  String get devicePairingOnline => '온라인';

  @override
  String get devicePairingOffline => '오프라인';

  @override
  String devicePairingLastSeen(String when) {
    return ' - 마지막 접속 $when';
  }

  @override
  String get devicePairingUnpairTooltip => '기기 페어링 해제';

  @override
  String get devicePairingJustNow => '방금 전';

  @override
  String devicePairingMinutesAgo(int n) {
    return '$n분 전';
  }

  @override
  String devicePairingHoursAgo(int n) {
    return '$n시간 전';
  }

  @override
  String devicePairingDaysAgo(int n) {
    return '$n일 전';
  }

  @override
  String get connDiagCopied => '추적 로그를 클립보드에 복사했습니다';

  @override
  String get connDiagShareSubject => 'WIM-Z 연결 추적 로그';

  @override
  String get connDiagCleared => '추적 로그를 지웠습니다';

  @override
  String get connDiagNotConnected => '연결되지 않음 — 먼저 로봇에 연결하세요';

  @override
  String connDiagLedAcked(int ms) {
    return 'LED 응답 ${ms}ms — 아무것도 켜지지 않았다면 로봇 쪽 문제입니다';
  }

  @override
  String get connDiagLedTimeout => 'LED 명령을 보냈지만 3초 내 응답 없음 — 명령 경로가 끊겼습니다';

  @override
  String connDiagLedFailed(String error) {
    return 'LED 핑 실패: $error';
  }

  @override
  String get connDiagTitle => '연결 진단';

  @override
  String get connDiagLedPing => 'LED 핑';

  @override
  String get connDiagCopy => '복사';

  @override
  String get connDiagShare => '공유';

  @override
  String get connDiagClear => '지우기';

  @override
  String connDiagHeader(int count) {
    return 'WebRTC 시그널링 추적 — 이벤트 $count개 기록됨.\n느린 비디오를 재현한 다음 이 추적 로그를 공유하세요.';
  }

  @override
  String get connDiagEmpty =>
      '아직 기록된 이벤트가 없습니다.\n\n로그인하고 비디오 피드를 연 다음 여기로 돌아오세요.';

  @override
  String get nightVisionTitle => '야간 투시';

  @override
  String get nightVisionWaiting => '로봇을 기다리는 중…';

  @override
  String get nightVisionNightMode => '야간 투시';

  @override
  String get nightVisionDayMode => '주간 모드';

  @override
  String get nightVisionStaleTooltip => '90초 이상 로봇 업데이트 없음';

  @override
  String get nightVisionAuto => '자동';

  @override
  String get nightVisionDay => '주간';

  @override
  String get nightVisionNight => '야간';

  @override
  String get nightVisionAutoHint => '조명에 따라 자동으로 전환됩니다.';

  @override
  String get nightVisionOverrideHint => '수동 설정이 켜져 있습니다. 자동을 탭하면 자동 감지를 재개합니다.';

  @override
  String get nightVisionOfflineHint => '로봇 오프라인 — 다시 연결되면 변경이 적용됩니다.';

  @override
  String nightVisionLighting(String label) {
    return '조명: $label';
  }

  @override
  String nightVisionLux(String lux, String label) {
    return '$lux lux — $label';
  }

  @override
  String get nightVisionModeWordNight => '야간 투시';

  @override
  String get nightVisionModeWordDay => '주간 모드';

  @override
  String nightVisionSwitchedSecondsAgo(String mode, int n) {
    return '$n초 전 $mode(으)로 전환됨';
  }

  @override
  String nightVisionSwitchedMinutesAgo(String mode, int n) {
    return '$n분 전 $mode(으)로 전환됨';
  }

  @override
  String nightVisionSwitchedHoursAgo(String mode, int n) {
    return '$n시간 전 $mode(으)로 전환됨';
  }

  @override
  String nightVisionSwitchedDaysAgo(String mode, int n) {
    return '$n일 전 $mode(으)로 전환됨';
  }

  @override
  String get nightVisionBadgeNight => 'IR 야간 화면';

  @override
  String get nightVisionBadgeDay => '주간';

  @override
  String sgError(String error) {
    return '사일런트 가디언: $error';
  }

  @override
  String get sgInterventionLevel => '개입 수준';

  @override
  String get sgInterventionSubtitle => '지속적인 짖음에 로봇이 얼마나 빨리 진정 음악으로 넘어갈지 정합니다.';

  @override
  String sgBpm(int bpm) {
    return '$bpm BPM';
  }

  @override
  String get sgAggressive => '적극적';

  @override
  String get sgTolerant => '관대함';

  @override
  String get sgHelperOff => '사용 안 함 — 사일런트 가디언이 일반 L1→L4 단계만 따릅니다.';

  @override
  String get sgHelperLow => '약한 정도의 지속적 짖음에도 바로 진정 음악으로 넘어갑니다.';

  @override
  String get sgHelperMid => '일반적인 소란스러운 짖음에 진정 음악이 시작됩니다.';

  @override
  String get sgHelperHigh => '극심하게 쉬지 않고 짖을 때만 진정 음악이 시작됩니다.';

  @override
  String get sgSessionSummary => '세션 요약';

  @override
  String get sgTapRefresh => '새로고침을 탭하면 실시간 상태 보고서를 볼 수 있습니다';

  @override
  String get sgStatBarks => '짖음';

  @override
  String get sgStatTreats => '간식';

  @override
  String get sgStatInterventions => '개입';

  @override
  String get sgStatLevel => '단계';

  @override
  String get sgStatTrend => '추세';

  @override
  String get sgBarkTimeline => '짖음 타임라인';

  @override
  String sgRateLine(String recent, String session) {
    return '현재 $recent/분 · 세션 $session/분';
  }

  @override
  String get sgPanicActive => '패닉 진행 중';

  @override
  String sgPanicEpisodes(int count) {
    return '패닉 에피소드 $count회';
  }

  @override
  String get sgAggressiveBehavior => '공격적 행동';

  @override
  String get dogProfileTitle => '반려견 프로필';

  @override
  String get dogProfileNotFound => '반려견 프로필을 찾을 수 없습니다';

  @override
  String get dogProfileEditTooltip => '반려견 편집';

  @override
  String get dogProfileMissionStarted => '미션을 시작했습니다';

  @override
  String get dogProfileMissionActive => '미션 진행 중';

  @override
  String get dogProfileLaunchLastMission => '마지막 미션 시작';

  @override
  String get dogProfileStartAMission => '미션 시작하기';

  @override
  String get dogProfileTodaySummary => '오늘의 요약';

  @override
  String get dogProfileStatTreats => '간식';

  @override
  String get dogProfileStatSits => '앉기';

  @override
  String get dogProfileStatBarks => '짖음';

  @override
  String get dogProfileStatGoal => '목표';

  @override
  String get dogProfileMetrics => '지표';

  @override
  String get dogProfileRangeDay => '일';

  @override
  String get dogProfileRangeWeek => '주';

  @override
  String get dogProfileRangeAll => '전체';

  @override
  String get dogProfileStatDetections => '감지';

  @override
  String get dogProfileStatMissions => '미션';

  @override
  String get dogProfileStatSuccess => '성공률';

  @override
  String get dogProfileStatActive => '활동';

  @override
  String get dogProfileStatCoach => '코치';

  @override
  String dogProfileActiveMinutes(int minutes) {
    return '$minutes분';
  }

  @override
  String get dogProfileViewDashboard => '대시보드 보기';

  @override
  String get dogProfileQuickActions => '빠른 작업';

  @override
  String get dogProfileActionVoice => '음성';

  @override
  String get dogProfileActionStats => '통계';

  @override
  String get dogProfileMetricsHint => '지표는 위에 표시됩니다. 일/주/전체 토글을 사용하세요';

  @override
  String get dogProfileRecentActivity => '최근 활동';

  @override
  String get dogProfileSeeAll => '전체 보기';

  @override
  String get dogProfileNoRecentActivity => '최근 활동이 없습니다';

  @override
  String dogProfileRelMinutes(int n) {
    return '$n분';
  }

  @override
  String dogProfileRelHours(int n) {
    return '$n시간';
  }

  @override
  String dogProfileRelDays(int n) {
    return '$n일';
  }

  @override
  String get dogsListTitle => '반려견';

  @override
  String get dogsListEmpty => '아직 추가된 반려견이 없습니다';

  @override
  String get dogsListNoDetails => '정보 없음';

  @override
  String get dogNameLabel => '이름';

  @override
  String get dogBreedLabel => '견종';

  @override
  String get dogPhotoTakePhoto => '사진 촬영';

  @override
  String get dogPhotoChooseFromGallery => '갤러리에서 선택';

  @override
  String get dogPhotoRemovePhoto => '사진 제거';

  @override
  String get arucoPrintMarker => '마커 인쇄';

  @override
  String get editDogTitle => '반려견 편집';

  @override
  String get editDogNotFound => '반려견을 찾을 수 없습니다';

  @override
  String get editDogBreedHint => '예: 골든 리트리버';

  @override
  String get editDogCoatColorLabel => '털 색상';

  @override
  String get editDogDeleteDog => '반려견 삭제';

  @override
  String get editDogNameEmpty => '이름을 입력하세요';

  @override
  String get editDogSaved => '저장되었습니다';

  @override
  String editDogSaveFailed(String error) {
    return '저장 실패: $error';
  }

  @override
  String get editDogDeleteConfirmTitle => '반려견을 삭제할까요?';

  @override
  String editDogDeleteConfirmBody(String name) {
    return '$name을(를) 정말 삭제하시겠어요? 모든 데이터가 삭제되며 되돌릴 수 없습니다.';
  }

  @override
  String editDogDeleted(String name) {
    return '$name이(가) 삭제되었습니다';
  }

  @override
  String get editDogChangePhoto => '사진 변경';

  @override
  String get editDogChoosePhotoSource => '사진 가져오기';

  @override
  String get editDogPhotoUpdated => '사진이 업데이트되었습니다';

  @override
  String editDogPhotoSaveFailed(String error) {
    return '사진 저장 실패: $error';
  }

  @override
  String get editDogTreatsPerReward => '보상당 간식 개수';

  @override
  String get editDogTreatsHelper1 => '기본값 — 보상당 간식 1개.';

  @override
  String get editDogTreatsHelper2 => '중형견에게는 2개가 좋을 수 있습니다.';

  @override
  String get editDogTreatsHelper3 => '대형견은 보상을 느끼려면 더 많이 필요합니다.';

  @override
  String get editDogTreatsHelper4 => '초대형견 또는 고강도 훈련용.';

  @override
  String get editDogArucoMarker => 'ArUco 마커';

  @override
  String get editDogNoMarker => '지정된 마커가 없습니다. 마커를 지정하려면 반려견을 다시 등록하세요.';

  @override
  String editDogMarkerId(int id) {
    return 'DICT_4X4_1000 — ID $id';
  }

  @override
  String editDogPrintFailed(String error) {
    return '인쇄 실패: $error';
  }

  @override
  String get addDogTitle => '반려견 추가';

  @override
  String get addDogSaveDog => '반려견 저장';

  @override
  String get addDogContinue => '계속';

  @override
  String get addDogStepColor => '색상';

  @override
  String get addDogStepPhoto => '사진';

  @override
  String get addDogPhotoSelected => '사진 선택됨';

  @override
  String get addDogOptional => '선택 사항';

  @override
  String get addDogStepAruco => 'ARUCO 태그';

  @override
  String get addDogNameQuestion => '반려견의 이름은 무엇인가요?';

  @override
  String get addDogNameFieldLabel => '반려견 이름';

  @override
  String get addDogNameHint => '예: 맥스, 루나, 버디';

  @override
  String get addDogNameRequired => '이름을 입력해 주세요';

  @override
  String get addDogBreedQuestion => '반려견의 견종은 무엇인가요?';

  @override
  String get addDogBreedHint => '예: 골든 리트리버, 믹스, 모름';

  @override
  String get addDogColorQuestion => '반려견의 주된 털 색상은 무엇인가요?';

  @override
  String get addDogPhotoPrompt => '반려견 프로필 사진을 추가하세요';

  @override
  String get addDogTapToAdd => '탭하여 추가';

  @override
  String get addDogCamera => '카메라';

  @override
  String get addDogGallery => '갤러리';

  @override
  String get addDogRemovePhoto => '사진 제거';

  @override
  String get addDogArucoIntro => 'WIM-Z는 반려견 목걸이의 ARUCO 마커로 반려견을 구분합니다.';

  @override
  String get addDogArucoAutoPicked =>
      '다음 빈 ID를 자동으로 골랐습니다. 이 마커를 인쇄해 목걸이에 부착하세요.';

  @override
  String get addDogArucoIdLabel => 'ARUCO 마커 ID';

  @override
  String get addDogArucoIdHint => '예: 42';

  @override
  String get addDogArucoSkipHint =>
      '이 필드를 비우면 ArUco를 건너뛸 수 있습니다. 반려견이 한 마리뿐이거나 외형 기반 식별을 선호할 때 유용합니다.';

  @override
  String get addDogMarkerBundleMissing =>
      '마커 번들이 아직 생성되지 않았습니다 — scripts/generate_aruco_markers.py를 실행하세요';

  @override
  String addDogPickImageFailed(String error) {
    return '이미지 선택 실패: $error';
  }

  @override
  String addDogDuplicateName(String name) {
    return '\"$name\" 이름의 반려견이 이미 있습니다';
  }

  @override
  String addDogRobotWillRecognize(String name) {
    return '이제 로봇이 $name을(를) 인식합니다';
  }

  @override
  String get weeklySummaryTitle => '주간 요약';

  @override
  String get weeklyTapRefresh => '새로고침을 눌러 이번 주 리포트를 확인하세요';

  @override
  String get weeklyVsLastWeek => '지난주 대비';

  @override
  String get weeklyQuiets => '조용히 성공';

  @override
  String weeklyTricks(int completed, int attempts) {
    return '트릭: $attempts회 중 $completed회 완료';
  }

  @override
  String weeklyTricksWithRate(int completed, int attempts, String rate) {
    return '트릭: $attempts회 중 $completed회 완료 ($rate%)';
  }

  @override
  String weeklyGuardian(int interventions, int sessions) {
    return '가디언: $sessions회 세션 동안 $interventions회 개입';
  }

  @override
  String weeklyDataSince(String parts) {
    return '데이터 시작: $parts';
  }

  @override
  String get weeklyCoverageBarks => '짖음';

  @override
  String get weeklyCoverageBarkTypes => '짖음 유형';

  @override
  String get weeklyCoverageTreats => '간식';

  @override
  String get weeklyCoverageCoaching => '코칭';

  @override
  String get voiceTitle => '음성 명령';

  @override
  String get voiceNoDogSelected => '선택된 반려견이 없습니다';

  @override
  String get voiceResetTooltip => '기본 음성으로 초기화';

  @override
  String get voiceSyncAll => '모두 동기화';

  @override
  String voiceIntro(String dogName) {
    return '각 명령에 대해 목소리를 녹음하세요. $dogName이(가) 당신의 목소리에 반응하도록 배웁니다.';
  }

  @override
  String get voiceMobileOnlyBanner =>
      '녹음은 iOS/Android 앱에서만 가능합니다. 모바일에서 명령을 녹음하세요.';

  @override
  String voiceRecordedProgress(int recorded, int total) {
    return '$total개 중 $recorded개 녹음됨';
  }

  @override
  String voiceSyncedCount(int count) {
    return '$count개 동기화됨';
  }

  @override
  String get voiceMobileRequiredTitle => '모바일 필요';

  @override
  String get voiceMobileRequiredBody =>
      '음성 녹음은 iOS 또는 Android 앱이 필요합니다. 모바일 기기에서 음성 명령을 녹음해 주세요.';

  @override
  String get voiceDeleteRecordingTitle => '녹음을 삭제할까요?';

  @override
  String get voiceDeleteRecordingBody => '녹음된 음성 명령이 삭제됩니다.';

  @override
  String get voiceCommandSynced => '명령이 동기화되었습니다!';

  @override
  String get voiceSyncFailed => '동기화 실패';

  @override
  String get voiceResetTitle => '기본 음성으로 초기화할까요?';

  @override
  String voiceResetBody(int count, String dogName) {
    return '$dogName의 녹음 $count개가 모두 삭제됩니다. WIM-Z는 대신 내장 음성을 사용합니다.';
  }

  @override
  String get voiceResetAction => '초기화';

  @override
  String get voiceResetDone => '초기화됨 — WIM-Z가 기본 음성을 사용합니다';

  @override
  String voiceSyncedToRobot(int count) {
    return '$count개 명령이 로봇에 동기화되었습니다';
  }

  @override
  String get voiceRecordedSynced => '녹음 및 동기화됨';

  @override
  String get voiceRecordedTapToSync => '녹음됨 - 탭하여 동기화';

  @override
  String get voiceNotRecorded => '녹음되지 않음';

  @override
  String get voiceSyncToRobotTooltip => '로봇에 동기화';

  @override
  String get voiceReRecord => '다시 녹음';

  @override
  String get voiceRecord => '녹음';

  @override
  String get voiceStartFailed => '녹음을 시작하지 못했습니다. 마이크 권한을 확인하세요.';

  @override
  String get voiceRecordingFailed => '녹음에 실패했습니다. 다시 시도하세요.';

  @override
  String get voiceSavedTitle => '저장됨!';

  @override
  String voiceRecordTitle(String label) {
    return '녹음: $label';
  }

  @override
  String get voiceRecordedSuccess => '음성 명령이 녹음되었습니다!';

  @override
  String voiceSeconds(String seconds) {
    return '$seconds초';
  }

  @override
  String get voiceSayClearly => '명령을 또렷하게 말하세요...';

  @override
  String get voicePreparingMic => '마이크 준비 중...';

  @override
  String get voiceStop => '중지';

  @override
  String arucoIdLabel(int id) {
    return 'ID $id';
  }

  @override
  String get arucoBundleMissing =>
      '마커 번들이 생성되지 않았습니다.\nscripts/generate_aruco_markers.py를 참고하세요';

  @override
  String get loginTagline => 'Watchful Intelligent Mobile Zen';

  @override
  String get loginButton => '로그인';

  @override
  String get loginCloudHint => '클라우드 연결 (인터넷 필요)';

  @override
  String get loginConnectToRobot => '로봇에 연결';

  @override
  String get loginDirectHint => 'WIMZ WiFi 핫스팟으로 직접 연결';

  @override
  String get loginLocalConnectFailed =>
      '로봇에 연결할 수 없습니다.\n로봇과 같은 WiFi에 연결되어 있거나\nWIMZ 핫스팟에 연결되어 있는지 확인하세요.';

  @override
  String get loginConnectionFailedCheckWifi =>
      '연결에 실패했습니다. WiFi를 확인하고 다시 시도하세요.';

  @override
  String get loginDemoMode => '데모 모드';

  @override
  String get loginSignIn => '로그인';

  @override
  String get loginCreateAccount => '계정 만들기';

  @override
  String get loginEmailLabel => '이메일';

  @override
  String get loginEnterEmail => '이메일을 입력하세요';

  @override
  String get loginInvalidEmail => '올바르지 않은 이메일입니다';

  @override
  String get loginPasswordLabel => '비밀번호';

  @override
  String get loginEnterPassword => '비밀번호를 입력하세요';

  @override
  String get loginMin6Chars => '6자 이상 입력하세요';

  @override
  String get loginSavePassword => '비밀번호 저장';

  @override
  String get loginForgotPassword => '비밀번호를 잊으셨나요?';

  @override
  String get loginNoAccountSignUp => '계정이 없으신가요? 회원가입';

  @override
  String get loginHaveAccountSignIn => '이미 계정이 있으신가요? 로그인';

  @override
  String get forgotTitle => '비밀번호 재설정';

  @override
  String get forgotHeading => '비밀번호를 잊으셨나요?';

  @override
  String get forgotIntro => '계정 이메일을 입력하시면 비밀번호 재설정용 6자리 코드를 보내드립니다.';

  @override
  String get forgotSendCode => '코드 보내기';

  @override
  String get forgotCodeSentBanner =>
      '등록된 이메일이라면 6자리 코드가 발송됩니다. 코드는 15분 후 만료됩니다.';

  @override
  String get forgotEnterCodeHeading => '코드와 새 비밀번호 입력';

  @override
  String get forgotCodeLabel => '6자리 코드';

  @override
  String get forgotEnterCode => '코드를 입력하세요';

  @override
  String get forgotCodeIs6Digits => '코드는 6자리입니다';

  @override
  String get forgotNewPasswordLabel => '새 비밀번호';

  @override
  String get forgotEnterNewPassword => '새 비밀번호를 입력하세요';

  @override
  String get forgotMin8Chars => '8자 이상 입력하세요';

  @override
  String get forgotConfirmPasswordLabel => '새 비밀번호 확인';

  @override
  String get forgotConfirmYourPassword => '비밀번호를 다시 입력하세요';

  @override
  String get forgotPasswordsDontMatch => '비밀번호가 일치하지 않습니다';

  @override
  String get forgotResendCode => '코드 다시 보내기';

  @override
  String get homeLocalRobot => '로컬 로봇';

  @override
  String get homeFindYourRobot => '로봇 찾기 →';

  @override
  String homeNewDog(int arucoId) {
    return '새 반려견 #$arucoId';
  }

  @override
  String get homeDismiss => '닫기';

  @override
  String get homeExit => '종료';

  @override
  String get homeModeIdle => '대기';

  @override
  String get homeModeGuard => '가디언';

  @override
  String get homeModeCoach => '코치';

  @override
  String get homeSelectDog => '반려견 선택';

  @override
  String get driveLabel => '주행';

  @override
  String get driveEmergencyStop => '비상 정지';

  @override
  String get driveCall => '부르기';

  @override
  String get driveTreat => '간식';

  @override
  String get driveCenter => '중앙';

  @override
  String get driveSwitchingMode => '모드 전환 중...';

  @override
  String get driveCamera => '카메라';

  @override
  String get driveCoach => '코치';

  @override
  String get driveSelectDogFirst => '반려견을 선택하거나 카메라가 인식할 때까지 기다려 주세요.';

  @override
  String get driveMissionFallback => '미션';

  @override
  String driveMissionStage(String name, String stage) {
    return '$name — $stage';
  }

  @override
  String get driveStop => '정지';

  @override
  String get galleryTitle => '사진 갤러리';

  @override
  String get galleryRefresh => '새로고침';

  @override
  String get galleryNoPhotos => '아직 사진이 없습니다';

  @override
  String get galleryTakePhotosHint => '영상 화면에서 사진을 찍어 보세요';

  @override
  String get galleryShare => '공유';

  @override
  String get galleryFailedToLoad => '이미지를 불러오지 못했습니다';

  @override
  String galleryShareText(String date) {
    return 'WIM-Z 사진 - $date';
  }

  @override
  String galleryShareFailed(String error) {
    return '공유 실패: $error';
  }

  @override
  String get galleryDeleteTitle => '사진 삭제';

  @override
  String get galleryDeleteConfirm => '이 사진을 삭제하시겠습니까?';

  @override
  String get notificationsTitle => '활동';

  @override
  String get notificationsMarkAllRead => '모두 읽음으로 표시';

  @override
  String get notificationsFilterAll => '전체';

  @override
  String get notificationsFilterBehaviors => '행동';

  @override
  String get notificationsFilterMissions => '미션';

  @override
  String get notificationsFilterAlerts => '경고';

  @override
  String get notificationsFilterTreats => '간식';

  @override
  String get notificationsFilterCoach => '코치';

  @override
  String get notificationsClearAll => '모두 지우기';

  @override
  String get notificationsTabDashboard => '대시보드';

  @override
  String get notificationsTabEvents => '이벤트';

  @override
  String get notificationsEmpty => '아직 알림이 없습니다';

  @override
  String get notificationsEmptyHint => 'WIM-Z의 이벤트가 여기에 표시됩니다';

  @override
  String get notificationsGroupToday => '오늘';

  @override
  String get notificationsGroupYesterday => '어제';

  @override
  String get notificationsGroupThisWeek => '이번 주';

  @override
  String get notificationsGroupEarlier => '이전';

  @override
  String get activityNoDogSelected => '선택된 반려견이 없습니다';

  @override
  String get activityStatTreats => '간식';

  @override
  String get activityStatDetections => '감지';

  @override
  String get activityStatMissions => '미션';

  @override
  String get activityStatCoach => '코치';

  @override
  String get activitySeriesTreats => '간식';

  @override
  String get activitySeriesBarks => '짖음';

  @override
  String get activitySeriesBehaviors => '행동';

  @override
  String get activitySeriesMissions => '미션';

  @override
  String get activitySeriesAlerts => '경고';

  @override
  String get activityChartTitle => '활동 (7일)';

  @override
  String get activityNoSeriesSelected => '선택된 항목이 없습니다';

  @override
  String activitySeriesCount(String label, int count) {
    return '$label: $count';
  }

  @override
  String get activityRecentEvents => '최근 이벤트';

  @override
  String get activityNoEvents => '아직 이벤트가 없습니다';

  @override
  String get connBadgeNoRobot => '로봇 없음';

  @override
  String get connBadgeOffline => '오프라인';

  @override
  String get connBadgeNotPaired => '페어링 안 됨';

  @override
  String get connBadgeWaiting => '대기 중...';

  @override
  String get connBadgeRobotOnline => '로봇 온라인';

  @override
  String get connBadgeOtherDeviceActive => '다른 기기 사용 중';

  @override
  String get connBadgeDemo => '데모';

  @override
  String localApCouldntReach(String ssid, String password) {
    return '로봇에 연결할 수 없습니다. 먼저 WiFi 설정에서 \"$ssid\"(비밀번호 $password)에 연결한 뒤 다시 시도하세요.';
  }

  @override
  String get localApNoHotspotInfo =>
      '로봇이 핫스팟 시작을 확인하지 않았고 저장된 핫스팟 정보도 없습니다. 로봇을 업데이트한 뒤 다시 시도하세요.';

  @override
  String get localApJoinHotspotTitle => '로봇 핫스팟에 연결';

  @override
  String localApJoinHotspotBody(String ssid, String password) {
    return '로봇이 핫스팟을 시작하고 있습니다.\n\n1. 이 휴대폰의 WiFi 설정을 여세요\n2. \"$ssid\"에 연결하세요\n    비밀번호: $password\n3. 돌아와서 연결을 누르세요\n\n클라우드 모드로 다시 전환할 때까지 (또는 휴대폰 연결 없이 10분이 지날 때까지) 로봇은 핫스팟을 유지합니다.';
  }

  @override
  String get localApConnect => '연결';

  @override
  String get localApSwitchTitle => '로컬 모드로 전환';

  @override
  String get localApSwitchSubtitle => '로봇이 핫스팟을 시작하고 휴대폰이 직접 연결됩니다';

  @override
  String treatCounterOf(int remaining, int capacity) {
    return '$capacity개 중 $remaining개';
  }

  @override
  String treatCounterTitle(String headline) {
    return '간식: $headline';
  }

  @override
  String get treatCounterEmptyRefill => '비어 있음 — 리필 필요';

  @override
  String get treatCounterRemainingLabel => '남은 간식';

  @override
  String get treatCounterRefilledReset => '리필 완료 — 카운터 초기화';

  @override
  String get treatCounterClearing => '해결 중...';

  @override
  String get treatCounterClearJam => '걸림 해결';

  @override
  String treatCounterLoadedHint(int capacity) {
    return '넣은 간식 수 (최대 $capacity)';
  }

  @override
  String get treatCounterSet => '설정';

  @override
  String get eventFeedSgActive => '사일런트 가디언 작동 중';

  @override
  String get eventFeedWatching => '활동을 지켜보는 중...';

  @override
  String eventFeedRecentEvents(int count) {
    return '최근 이벤트 ($count)';
  }

  @override
  String get eventFeedClear => '지우기';

  @override
  String get notifBarkingDetected => '짖음 감지';

  @override
  String get notifPanicEpisodeEnded => '패닉 에피소드 종료';

  @override
  String get notifPanicAlert => '패닉 경고';

  @override
  String get notifSgLevel4 => '사일런트 가디언: 4단계';

  @override
  String get notifSgLevel4Body => '대응 단계가 최고 수준에 도달했습니다';

  @override
  String get notifTreatDispensed => '간식 급여됨';

  @override
  String notifTreatFor(String dogName) {
    return '$dogName에게';
  }

  @override
  String get notifGoodJob => '잘했어요!';

  @override
  String notifTreatsRemaining(int count) {
    return '간식 $count개 남음';
  }

  @override
  String get notifTreatsRunningLow => '간식 부족';

  @override
  String notifTreatsLowBody(int count) {
    return '간식 $count개 남음 — 채워주세요!';
  }

  @override
  String get notifTreatsEmpty => '간식 없음';

  @override
  String get notifTreatsEmptyBody => '계속 급여하려면 캐러셀을 채워주세요';

  @override
  String get notifMissionStarted => '미션 시작';

  @override
  String get notifMissionCompleted => '미션 완료';

  @override
  String get notifMissionFailed => '미션 실패';

  @override
  String notifCoachRewardedFor(String dogName, String behavior) {
    return '$dogName: $behavior 보상';
  }

  @override
  String notifCoachRewarded(String behavior) {
    return '$behavior 보상';
  }

  @override
  String notifCoachAttempt(String behavior) {
    return '$behavior 시도';
  }

  @override
  String get notifCoachMode => '코치 모드';

  @override
  String get notifTrick => '트릭';

  @override
  String get notifLowBattery => '배터리 부족';

  @override
  String notifBatteryRemaining(int percent) {
    return '$percent% 남음';
  }

  @override
  String get notifSessionEnded => '세션 종료';

  @override
  String get notifAggressiveToday => '오늘 반려견이 공격적이었어요';

  @override
  String notifPanicEpisodes(int count) {
    return '패닉 에피소드 $count회';
  }

  @override
  String get notifGuardianSessionEnded => '가디언 세션 종료';

  @override
  String get notifGuardianAlert => '가디언 경고';

  @override
  String get notifIntervention => '개입';

  @override
  String notifGuardianReason(String reason) {
    return '가디언: $reason';
  }

  @override
  String get notifSittingDetected => '앉기 감지';

  @override
  String get notifLayDown => '엎드려';

  @override
  String get notifCome => '이리 와';

  @override
  String get notifAlert => '경고';

  @override
  String get notifHappyDog => '행복한 반려견';

  @override
  String get notifCoachReward => '코치 보상';

  @override
  String get notifGuardianSummary => '가디언 요약';

  @override
  String get notifBehaviorDetected => '행동 감지';

  @override
  String notifBehaviorNamedDetected(String behavior) {
    return '$behavior 감지';
  }

  @override
  String notifConfidence(int percent) {
    return '신뢰도 $percent%';
  }

  @override
  String notifBarkType(String type) {
    return '$type 짖음';
  }

  @override
  String get channelActivityName => 'WIM-Z 활동';

  @override
  String get channelActivityDescription => '반려견 훈련 활동 알림';

  @override
  String get authErrRegistrationFailed => '회원가입에 실패했습니다';

  @override
  String get authErrEmailRegistered => '이미 등록된 이메일입니다';

  @override
  String get authErrInvalidCredentials => '이메일 또는 비밀번호가 올바르지 않습니다';

  @override
  String get authErrLoginFailed => '로그인에 실패했습니다';

  @override
  String get authErrAccountNotFound => '계정을 찾을 수 없습니다';

  @override
  String get authErrResetCodeSend => '재설정 코드를 보낼 수 없습니다. 연결 상태를 확인하세요.';

  @override
  String get authErrResetFailed => '재설정에 실패했습니다';

  @override
  String get authErrInvalidCode => '코드가 잘못되었거나 만료되었습니다';

  @override
  String get authErrTooManyAttempts => '시도 횟수가 너무 많습니다. 잠시 후 다시 시도하세요';

  @override
  String get authNoticeSessionExpired => '세션이 만료되었습니다. 다시 로그인해 주세요.';

  @override
  String get connStatusConnectingServer => '서버에 연결 중...';

  @override
  String get connStatusNotPaired => '기기가 페어링되지 않았습니다';

  @override
  String get connStatusWaitingRobot => '서버 연결됨. 로봇을 기다리는 중...';

  @override
  String get connStatusRobotOnline => '로봇 온라인';

  @override
  String get connStatusError => '연결 오류';

  @override
  String get connStatusSuperseded => '다른 기기에서 로그인됨';

  @override
  String get connErrServerNotResponding => '서버가 응답하지 않습니다';

  @override
  String get connErrLiveConnection => '서버와 실시간 연결을 열 수 없습니다';

  @override
  String get connErrLostConnection => '서버와의 연결이 끊어졌습니다';

  @override
  String get connErrHandshake => '연결 핸드셰이크에 실패했습니다. 앱을 업데이트해 주세요.';

  @override
  String get connErrSessionExpired => '세션이 만료되었습니다. 다시 로그인해 주세요.';

  @override
  String get connErrNotPairedGoSettings => '기기가 페어링되지 않았습니다. 설정에서 페어링하세요.';

  @override
  String get connErrRobotOffline => '로봇이 오프라인입니다';

  @override
  String get errNotAuthorizedLogin => '권한이 없습니다. 다시 로그인해 주세요.';

  @override
  String get connErrSuperseded => '이 계정이 다른 기기에서 사용 중입니다. 탭하여 제어권을 되찾으세요.';

  @override
  String get errNotConnectedToRobot => '로봇에 연결되지 않았습니다';

  @override
  String get errNoResponseUpdate => '응답 없음 — 로봇 업데이트가 필요할 수 있습니다';

  @override
  String get pttErrPlayFailed => '오디오 재생에 실패했습니다';

  @override
  String get pttErrMobileOnly => '녹음은 iOS/Android에서만 가능합니다';

  @override
  String get pttErrNotConnectedSend => '연결되지 않음 — 음성을 보낼 수 없습니다';

  @override
  String get pttErrMicDenied => '마이크 권한이 거부되었습니다';

  @override
  String get pttErrStartFailed => '녹음을 시작하지 못했습니다';

  @override
  String pttErrStartFailedDetail(String error) {
    return '녹음 시작 실패: $error';
  }

  @override
  String get pttErrRecordingFailed => '녹음에 실패했습니다';

  @override
  String get pttErrFileNotFound => '녹음 파일을 찾을 수 없습니다';

  @override
  String get pttErrEmpty => '녹음이 비어 있습니다 — 오디오가 캡처되지 않았습니다';

  @override
  String get pttErrNotConnectedNotSent => '연결되지 않음 — 음성 메시지를 보내지 못했습니다';

  @override
  String pttErrSendFailed(String error) {
    return '오디오 전송 실패: $error';
  }

  @override
  String get pttErrNoAudio => '수신된 오디오가 없습니다';

  @override
  String get pairErrPairFailed => '기기 페어링에 실패했습니다';

  @override
  String get pairErrNetwork => '네트워크 오류입니다. 연결 상태를 확인하세요.';

  @override
  String pairErrUnpairFailed(int code) {
    return '기기 페어링 해제에 실패했습니다 (상태 $code)';
  }

  @override
  String get pairErrDeviceNotFound => '기기를 찾을 수 없습니다. 기기 ID를 확인하세요.';

  @override
  String get pairErrAlreadyPaired => '이미 내 계정에 페어링된 기기입니다.';

  @override
  String get pairErrRobotUnavailable =>
      '로봇을 사용할 수 없습니다. 전원이 켜져 있고 연결되어 있는지 확인하세요.';

  @override
  String get pairErrTimeout => '연결 시간이 초과되었습니다. 로봇을 사용할 수 없는 상태일 수 있습니다.';

  @override
  String get pairErrGeneric => '오류가 발생했습니다. 다시 시도해 주세요.';

  @override
  String get ctrlPairPairing => '페어링 중…';

  @override
  String get ctrlPairSaving => '저장 중…';

  @override
  String get ctrlPairRemovingTrust => '신뢰 해제 중…';

  @override
  String get ctrlPairForgetting => '삭제 중…';

  @override
  String get ctrlPairReconnecting => '다시 연결 중…';

  @override
  String get ctrlPairConnecting => '연결 중…';

  @override
  String get ctrlPairError => '컨트롤러 오류';

  @override
  String get schedErrDeleteFailed => '일정 삭제에 실패했습니다';

  @override
  String get schedErrTimeout => '로봇의 일정 응답 시간이 초과되었습니다';

  @override
  String get modeErrMissionActive => '미션 진행 중에는 모드를 변경할 수 없습니다';

  @override
  String get videoErrRobotRecordFailed => '로봇이 영상을 녹화하지 못했습니다';

  @override
  String get videoErrNoDownloadUrl => '로봇에서 다운로드 URL을 받지 못했습니다';

  @override
  String get videoErrNotFound =>
      '서버에서 영상 파일을 찾을 수 없습니다 — 다운로드하려면 로봇에 직접 연결해야 할 수 있습니다';

  @override
  String get videoErrUnreachable => '영상 다운로드를 위해 로봇에 연결할 수 없습니다';

  @override
  String get videoErrDownloadFailed => '영상 다운로드에 실패했습니다';

  @override
  String videoErrEncodingTimeout(int seconds) {
    return '영상 인코딩 시간이 초과되었습니다 — $seconds초 동안 응답 없음';
  }

  @override
  String get photoErrEmpty => '빈 사진 데이터를 받았습니다';

  @override
  String get photoErrTimeout => '사진 촬영 시간이 초과되었습니다 — 로봇 응답 없음';

  @override
  String get webrtcErrTimeoutRetry => '연결 시간 초과 — 탭하여 다시 시도';

  @override
  String get webrtcErrFailed => '연결 실패';

  @override
  String get webrtcErrLost => '연결 끊김';

  @override
  String get webrtcErrFailedRetry => '연결 실패 — 탭하여 다시 시도';

  @override
  String wifiErrScanFailed(String error) {
    return 'WiFi 검색 실패: $error';
  }

  @override
  String wifiErrConnectFailed(String error) {
    return '연결 실패: $error';
  }

  @override
  String get missionsErrIncompleteData =>
      '로봇이 불완전한 미션 데이터를 보냈습니다 — 로봇 로그를 확인하세요';

  @override
  String get missionsErrAlreadyActive => '이미 진행 중인 미션이 있습니다';

  @override
  String missionsErrAlreadyActiveNamed(String name) {
    return '이미 진행 중인 미션이 있습니다 ($name)';
  }

  @override
  String get missionsErrStartFailed => '미션을 시작하지 못했습니다';

  @override
  String missionsErrStopFirst(String name) {
    return '현재 미션을 먼저 중지하세요 ($name)';
  }

  @override
  String get missionsErrStartFailedRobot => '로봇에서 미션을 시작하지 못했습니다';

  @override
  String get sgErrNotRunning => '사일런트 가디언이 실행 중이 아닙니다';

  @override
  String get weeklyErrUnknownDog => '로봇이 아직 이 반려견을 알지 못합니다';

  @override
  String get historyErrLocalMode => '로컬 모드에서는 기록을 볼 수 없습니다';

  @override
  String get historyErrNotLoggedIn => '로그인되지 않았습니다';

  @override
  String historyErrLoadFailed(String error) {
    return '기록 불러오기 실패: $error';
  }

  @override
  String uploadErrFailedStatus(String status) {
    return '업로드 실패 ($status)';
  }

  @override
  String get uploadErrTooLarge => '파일이 서버 제한보다 큽니다';

  @override
  String get uploadErrInvalidType => '잘못된 파일 형식 — MP3만 가능합니다';

  @override
  String get uploadErrNotAuthorized => '업로드 권한이 없습니다';

  @override
  String get uploadErrRobotOffline => '로봇 오프라인';

  @override
  String get uploadErrTimeout => '업로드 시간 초과 — 더 작은 파일로 시도하세요';

  @override
  String get uploadErrConnection => '연결 오류 — 네트워크를 확인하세요';

  @override
  String get uploadErrFailed => '업로드에 실패했습니다';

  @override
  String uploadErrGeneric(String error) {
    return '업로드 오류: $error';
  }

  @override
  String get modelBehaviorDog => '반려견';

  @override
  String get modelBehaviorSit => '앉아';

  @override
  String get modelBehaviorLayDown => '엎드려';

  @override
  String get modelBehaviorCome => '이리 와';

  @override
  String get modelBehaviorStay => '기다려';

  @override
  String get modelBehaviorSpin => '돌아';

  @override
  String get modelBehaviorSpeak => '짖어';

  @override
  String get modelBehaviorBark => '짖음';

  @override
  String get modelBehaviorQuiet => '조용히';

  @override
  String get modelRobotModeIdle => '대기';

  @override
  String get modelRobotModeManual => '수동';

  @override
  String get modelRobotModeSilentGuardian => '사일런트 가디언';

  @override
  String get modelRobotModeCoach => '코치';

  @override
  String get modelRobotModeMission => '미션';

  @override
  String get modelRobotModeDocking => '도킹';

  @override
  String get modelDogColorBlack => '검정';

  @override
  String get modelDogColorYellow => '노랑/골든';

  @override
  String get modelDogColorBrown => '갈색/초콜릿';

  @override
  String get modelDogColorWhite => '흰색';

  @override
  String get modelDogColorMixed => '혼합';

  @override
  String modelAgeYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count년',
    );
    return '$_temp0';
  }

  @override
  String modelAgeMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개월',
    );
    return '$_temp0';
  }

  @override
  String get modelVoiceCmdName => '반려견 이름';

  @override
  String get modelVoiceCmdPromptName => '반려견 이름을 또렷하게 말하세요';

  @override
  String get modelVoiceCmdSit => '앉아';

  @override
  String get modelVoiceCmdPromptSit => '\"앉아\"를 단호하게 말하세요';

  @override
  String get modelVoiceCmdStay => '기다려';

  @override
  String get modelVoiceCmdPromptStay => '\"기다려\"를 차분한 어조로 말하세요';

  @override
  String get modelVoiceCmdLieDown => '엎드려';

  @override
  String get modelVoiceCmdPromptLieDown => '\"엎드려\"라고 말하세요';

  @override
  String get modelVoiceCmdSpin => '돌아';

  @override
  String get modelVoiceCmdPromptSpin => '\"돌아\"를 신나게 말하세요';

  @override
  String get modelVoiceCmdSpeak => '짖어';

  @override
  String get modelVoiceCmdPromptSpeak => '\"짖어\"를 신나게 말하세요';

  @override
  String get modelVoiceCmdCome => '이리 와';

  @override
  String get modelVoiceCmdPromptCome => '\"이리 와\"라고 말하세요';

  @override
  String get modelVoiceCmdTreat => '간식 먹을래?';

  @override
  String get modelVoiceCmdPromptTreat => '\"간식 먹을래?\"를 장난스럽게 말하세요';

  @override
  String get modelVoiceCmdGoodDog => '착하지!';

  @override
  String get modelVoiceCmdPromptGoodDog => '\"착하지!\"를 칭찬하듯 말하세요';

  @override
  String get modelVoiceCmdNo => '안 돼';

  @override
  String get modelVoiceCmdPromptNo => '\"안 돼\"를 단호하게 말하세요';

  @override
  String get modelVoiceCmdQuiet => '조용히';

  @override
  String get modelVoiceCmdPromptQuiet => '\"조용히\"를 차분하지만 단호하게 말하세요';

  @override
  String get modelMissionStatusWaitingForDog => '반려견을 기다리는 중...';

  @override
  String get modelMissionStatusGreeting => '인사하는 중...';

  @override
  String get modelMissionStatusCommand => '명령 중';

  @override
  String get modelMissionStatusWatching => '그대로...';

  @override
  String get modelMissionStatusSuccess => '성공!';

  @override
  String get modelMissionStatusFailed => '다시 시도';

  @override
  String get modelMissionStatusRetry => '다시 시도하는 중...';

  @override
  String get modelMissionStatusCompleted => '완료!';

  @override
  String get modelMissionStatusStopped => '중지됨';

  @override
  String modelMissionWaitingForDog(String dogName) {
    return '$dogName을(를) 기다리는 중...';
  }

  @override
  String modelMissionGreetingDog(String dogName) {
    return '$dogName에게 인사하는 중...';
  }

  @override
  String modelMissionStageOf(int stage, int total) {
    return '$total단계 중 $stage단계';
  }

  @override
  String get modelGuardianEventDogDetected => '반려견 감지됨';

  @override
  String get modelGuardianEventDogLeft => '반려견이 화면을 벗어남';

  @override
  String get modelGuardianEventBarking => '짖음 감지됨';

  @override
  String get modelGuardianEventTreatDispensed => '간식 급여됨';

  @override
  String get modelGuardianEventBehaviorChange => '행동 변화';

  @override
  String get modelGuardianEventMotionDetected => '움직임 감지됨';

  @override
  String get modelGuardianEventQuietReward => '조용히 보상';

  @override
  String get modelGuardianEventAlertTriggered => '경고 발생';

  @override
  String get modelGuardianEventUnknown => '이벤트';

  @override
  String modelGuardianEventWithDetails(String label, String details) {
    return '$label - $details';
  }

  @override
  String get modelNotifTitleBark => '짖음 감지';

  @override
  String get modelNotifTitleSit => '앉기 감지';

  @override
  String get modelNotifTitleLieDown => '엎드려';

  @override
  String get modelNotifTitleStand => '이리 와';

  @override
  String get modelNotifTitleTreatDispensed => '간식 급여';

  @override
  String get modelNotifTitleMissionStarted => '미션 시작';

  @override
  String get modelNotifTitleMissionCompleted => '미션 완료';

  @override
  String get modelNotifTitleMissionFailed => '미션 실패';

  @override
  String get modelNotifTitleLowBattery => '배터리 부족';

  @override
  String get modelNotifTitleAlert => '경고';

  @override
  String get modelNotifTitleHappy => '행복한 반려견';

  @override
  String get modelNotifTitleConnected => '연결됨';

  @override
  String get modelNotifTitleDisconnected => '연결 끊김';

  @override
  String get modelNotifTitleCoachReward => '코치 보상';

  @override
  String get modelNotifTitlePanicAlert => '패닉 경고';

  @override
  String get modelNotifTitleSgSummary => '가디언 요약';

  @override
  String get modelNightOverrideAuto => '자동';

  @override
  String get modelNightOverrideDay => '주간 모드';

  @override
  String get modelNightOverrideNight => '야간 모드';

  @override
  String get modelLuxDetecting => '감지 중…';

  @override
  String get modelLuxDark => '어두움';

  @override
  String get modelLuxDim => '흐림';

  @override
  String get modelLuxIndoor => '실내 조명';

  @override
  String get modelLuxWellLit => '밝음';

  @override
  String get modelLuxBright => '매우 밝음';

  @override
  String get modelControllerKindXbox => 'Xbox';

  @override
  String get modelControllerKindPlaystation => 'PlayStation';

  @override
  String get modelControllerKindEightBitDo => '8BitDo';

  @override
  String get modelControllerKindGeneric => '컨트롤러';

  @override
  String get modelControllerHintXbox =>
      'Xbox 버튼을 누른 뒤 상단의 작은 페어링 버튼을 표시등이 빠르게 깜빡일 때까지 길게 누르세요.';

  @override
  String get modelControllerHintPlaystation =>
      'PS 버튼과 Share(또는 Create) 버튼을 라이트 바가 깜빡일 때까지 함께 길게 누르세요.';

  @override
  String get modelControllerHintEightBitDo =>
      '컨트롤러를 블루투스 모드로 설정한 뒤 Start(또는 페어링 버튼)를 LED가 깜빡일 때까지 길게 누르세요.';

  @override
  String get modelControllerHintGeneric =>
      '컨트롤러를 블루투스 페어링 모드로 전환한 뒤(보통 전용 페어링 버튼을 누르거나 표시등이 깜빡일 때까지 버튼 조합을 길게 누름) 여기에 표시될 때까지 기다리세요.';

  @override
  String get modelDetectionDogDetected => '반려견 감지됨';

  @override
  String get modelVideoTierLow => 'SD 480p';

  @override
  String get modelVideoTierMedium => '540p';

  @override
  String get modelVideoTierHigh => 'HD 720p';

  @override
  String get modelVideoQualityAuto => '자동';

  @override
  String get modelVideoQualityLow => '낮음';

  @override
  String get modelVideoQualityMedium => '중간';

  @override
  String get modelVideoQualityHigh => '높음';

  @override
  String get modelDaySun => '일';

  @override
  String get modelDayMon => '월';

  @override
  String get modelDayTue => '화';

  @override
  String get modelDayWed => '수';

  @override
  String get modelDayThu => '목';

  @override
  String get modelDayFri => '금';

  @override
  String get modelDaySat => '토';

  @override
  String modelScheduleOnceAt(String time) {
    return '$time에 한 번';
  }

  @override
  String modelScheduleDailyAt(String time) {
    return '매일 $time';
  }

  @override
  String modelScheduleWeeklyAt(String time) {
    return '매주 $time';
  }

  @override
  String modelScheduleEveryDayAt(String time) {
    return '매일 $time';
  }

  @override
  String modelScheduleDaysAt(String days, String time) {
    return '$days $time';
  }

  @override
  String get catalogMissionSit => '앉아';

  @override
  String get catalogMissionSitDesc => '간단한 앉아 미션 - 반려견을 기다렸다가 앉으면 보상';

  @override
  String get catalogMissionSitTraining => '앉아 훈련';

  @override
  String get catalogMissionSitTrainingDesc => '기본 앉아 훈련 - 앉는 행동에 보상';

  @override
  String get catalogMissionSitSustained => '앉아 유지';

  @override
  String get catalogMissionSitSustainedDesc => '반려견이 앉은 자세를 오래(30초) 유지';

  @override
  String get catalogMissionDownSustained => '엎드려 유지';

  @override
  String get catalogMissionDownSustainedDesc => '반려견이 엎드린 자세를 오래(30초) 유지';

  @override
  String get catalogMissionComeAndSit => '이리 와서 앉아';

  @override
  String get catalogMissionComeAndSitDesc => '반려견을 부른 뒤 앉게 하기';

  @override
  String get catalogMissionTrainSitDaily => '매일 앉아 훈련';

  @override
  String get catalogMissionTrainSitDailyDesc => '난이도와 제한이 점진적으로 높아지는 매일 앉아 훈련';

  @override
  String get catalogMissionLaydown => '엎드려';

  @override
  String get catalogMissionLaydownDesc => '간단한 엎드려 미션 - 반려견을 기다렸다가 엎드리면 보상';

  @override
  String get catalogMissionComeTraining => '이리 와 훈련';

  @override
  String get catalogMissionComeTrainingDesc => '리콜 훈련 - 부르면 오는 행동에 보상';

  @override
  String get catalogMissionSpinTraining => '돌아 훈련';

  @override
  String get catalogMissionSpinTrainingDesc => '돌기 트릭 훈련 - 제자리에서 도는 행동에 보상';

  @override
  String get catalogMissionSitAndSpeak => '앉아서 짖어';

  @override
  String get catalogMissionSitAndSpeakDesc => '명령에 따라 앉고 짖으면 간식으로 보상';

  @override
  String get catalogMissionSpeakMorning => '오전 짖어';

  @override
  String get catalogMissionSpeakMorningDesc => '오전(8시~12시) 동안 신호에 맞춰 두 번 짖기';

  @override
  String get catalogMissionSpeakAfternoon => '오후 짖어';

  @override
  String get catalogMissionSpeakAfternoonDesc => '오후(2시~6시) 동안 신호에 맞춰 두 번 짖기';

  @override
  String get catalogMissionAlertTraining => '경계 훈련';

  @override
  String get catalogMissionAlertTrainingDesc => '경비견 훈련 - 앉아서 경계 짖음을 하면 보상';

  @override
  String get catalogMissionBarkPrevention => '짖음 예방';

  @override
  String get catalogMissionBarkPreventionDesc => '조용히 훈련 - 과도한 짖음 줄이기';

  @override
  String get catalogMissionStopBarking => '짖음 멈추기';

  @override
  String get catalogMissionStopBarkingDesc => '조용히 훈련 - 단계적 대응으로 과도한 짖음 줄이기';

  @override
  String get catalogMissionQuietProgressive => '점진적 조용히';

  @override
  String get catalogMissionQuietProgressiveDesc =>
      '점진적 조용히 훈련 - 조용히 유지해야 하는 시간이 점점 길어짐';

  @override
  String get catalogMissionComfortScared => '겁먹은 반려견 달래기';

  @override
  String get catalogMissionComfortScaredDesc => '겁먹거나 불안한 짖음이 감지되면 반려견 달래기';

  @override
  String get catalogMissionMorningChill => '오전 휴식';

  @override
  String get catalogMissionMorningChillDesc => '오전(8시~12시) 동안 차분한 행동 유지';

  @override
  String get catalogMissionMorningQuiet2hr => '오전 2시간 조용히';

  @override
  String get catalogMissionMorningQuiet2hrDesc =>
      '오전 시간대(7시~13시)에 2시간 동안 조용히 유지';

  @override
  String get catalogMissionAfternoonSit5 => '오후 앉아 5회';

  @override
  String get catalogMissionAfternoonSit5Desc => '오후(12시~19시) 동안 앉기 5회 수행';

  @override
  String get catalogMissionAfternoonDown3 => '오후 엎드려 3회';

  @override
  String get catalogMissionAfternoonDown3Desc => '오후(12시~18시) 동안 엎드리기 3회 수행';

  @override
  String get catalogMissionEveningCalmTransition => '저녁 진정 전환';

  @override
  String get catalogMissionEveningCalmTransitionDesc =>
      '조용한 저녁 행동으로 전환하도록 돕기(18시~21시)';

  @override
  String get catalogMissionEveningSettle => '저녁 안정';

  @override
  String get catalogMissionEveningSettleDesc => '저녁 식사 후 안정 취하기(17시~21시)';

  @override
  String get catalogMissionNightQuiet90pct => '야간 90% 조용히';

  @override
  String get catalogMissionNightQuiet90pctDesc => '밤새(19시~4시) 90% 조용히 유지';

  @override
  String get catalogMissionDownTraining => '엎드려 훈련';

  @override
  String get catalogMissionQuietTraining => '조용히 훈련';

  @override
  String get catalogMissionStayTraining => '기다려 훈련';

  @override
  String get catalogMissionStandTraining => '서 훈련';

  @override
  String get catalogProgramPuppyBasics => '강아지 기초';

  @override
  String get catalogProgramPuppyBasicsDesc => '기초 훈련: 앉아, 엎드려, 조용히';

  @override
  String get catalogProgramObedience101 => '복종 훈련 기초';

  @override
  String get catalogProgramObedience101Desc => '모든 반려견이 알아야 할 핵심 명령';

  @override
  String get catalogProgramCalmDog => '차분한 반려견';

  @override
  String get catalogProgramCalmDogDesc => '인내심과 자제력 기르기';

  @override
  String get aiAssistantFallback => '어시스턴트';

  @override
  String draftTranscriptProposed(String title) {
    return '미션 제안: $title';
  }

  @override
  String get draftTranscriptYou => '나';

  @override
  String draftTranscriptApproved(String title) {
    return '\"$title\" 승인함';
  }

  @override
  String draftTranscriptDeclined(String title) {
    return '\"$title\" 거절함';
  }

  @override
  String get aiErrSignedOut => '연결된 어시스턴트를 관리하려면 로그인하세요';

  @override
  String get aiErrLoadFailed => '연결된 어시스턴트를 불러오지 못했습니다';

  @override
  String get aiErrRevokeFailed => '연결 해제 실패';

  @override
  String get notifMissionDraft => '미션 승인 요청';

  @override
  String notifMissionDraftFrom(String name) {
    return '$name이(가) 미션을 제안했습니다';
  }

  @override
  String get notifPrefsMissionDraft => '미션 승인 요청';

  @override
  String get modelNotifTitleMissionDraft => '미션 승인';

  @override
  String get draftApprove => '승인';

  @override
  String get draftDecline => '거절';

  @override
  String get draftStatusApproved => '승인됨';

  @override
  String get draftStatusDeclined => '거절됨';

  @override
  String get draftStatusExpired => '만료됨';

  @override
  String get attachmentOpenFailed => '미디어를 불러오지 못했습니다';

  @override
  String get todayCardTitle => '오늘';

  @override
  String get todayCardLocalCounts => '이 휴대폰의 활동 기록 기준';

  @override
  String get todayCardError => '요약 서비스에 연결할 수 없습니다';

  @override
  String get todayStatBarks => '짖음';

  @override
  String get todayStatTreats => '간식';

  @override
  String get todayStatCoaching => '코칭';

  @override
  String get todayStatQuiet => '조용';

  @override
  String get todayStatGuardian => '가디언';

  @override
  String get todayPlanTitle => '계획';

  @override
  String todayPlanBy(String source) {
    return '$source 계획';
  }

  @override
  String get todayHighlights => '하이라이트';

  @override
  String get connectedAiTitle => '연결된 AI';

  @override
  String get connectedAiSubtitle => '어시스턴트, 커넥터 URL, 긴급 차단, 감사 로그';

  @override
  String get aiConnectorUrl => '커넥터 URL';

  @override
  String get aiConnectorUrlCopied => '커넥터 URL 복사됨';

  @override
  String get aiConnectorUrlMissing => '아직 발급되지 않음';

  @override
  String get aiCopyUrl => 'URL 복사';

  @override
  String get aiAssistantsHeader => '연결된 어시스턴트';

  @override
  String get aiNoAssistants => '연결된 어시스턴트가 없습니다';

  @override
  String get aiRevoke => '해제';

  @override
  String aiRevokeConfirm(String name) {
    return '$name 연결을 해제할까요? 즉시 접근이 차단됩니다.';
  }

  @override
  String aiLastUsed(String when) {
    return '마지막 사용 $when';
  }

  @override
  String get aiNeverUsed => '사용 기록 없음';

  @override
  String get aiScopesNone => '권한 없음';

  @override
  String get aiAuditHeader => '감사 로그';

  @override
  String get aiAuditEmpty => '활동 없음';

  @override
  String get aiSetupGuides => '설정 안내';

  @override
  String get aiUnsupported => '이 서버에서는 아직 연결된 AI를 사용할 수 없습니다';

  @override
  String aiGuideTitle(String name) {
    return '$name 연결';
  }

  @override
  String aiGuideStep1(String name) {
    return '$name을(를) 열고 설정 → 커넥터(또는 도구)로 이동합니다.';
  }

  @override
  String get aiGuideStep2 => '사용자 지정 커넥터 / MCP 서버 추가를 선택합니다.';

  @override
  String get aiGuideStep3 => '아래 WIM-Z 커넥터 URL을 붙여넣습니다.';

  @override
  String get aiGuideStep4 => 'WIM-Z 계정으로 로그인하고 원하는 권한을 허용합니다.';

  @override
  String aiGuideStep5(String name) {
    return '$name에게 \"오늘 우리 개는 어땠어?\"라고 물어보세요. 연결되면 목록에 표시됩니다.';
  }

  @override
  String get aiGuideNoteChatgpt => 'ChatGPT: 먼저 설정 → 커넥터 → 고급에서 개발자 모드를 켜세요.';

  @override
  String get aiGuideNoteClaude =>
      'Claude: 설정 → 커넥터 → 사용자 지정 커넥터 추가 (claude.ai, Pro/Max/Team).';

  @override
  String get aiGuideNoteGrok => 'Grok: 설정 → 커넥터 → MCP 서버 추가 (grok.com).';

  @override
  String get aiGuideNotePerplexity =>
      'Perplexity: 설정 → 커넥터 → 커넥터 추가 (Pro/Max).';

  @override
  String get settingsSectionAdvanced => '고급';

  @override
  String get settingsAdvancedMode => '고급 모드';

  @override
  String get settingsAdvancedModeSubtitle => '모든 사운드 ID와 휴대폰에서 교체 기능 표시';

  @override
  String get settingsSoundsAll => '모든 사운드';

  @override
  String get settingsSoundsAllSubtitle => '휴대폰에서 로봇 사운드 교체';

  @override
  String get settingsResetSounds => '사운드를 공장 초기값으로 재설정';

  @override
  String get settingsResetSoundsSubtitle => '모든 인사, 신호, 알림, 음악 사운드를 복원합니다';

  @override
  String get settingsResetSoundsConfirmTitle => '모든 사운드를 재설정할까요?';

  @override
  String get settingsResetSoundsConfirmBody =>
      '로봇의 모든 사용자 지정 사운드가 공장 파일로 교체됩니다. 되돌릴 수 없습니다.';

  @override
  String get settingsResetSoundsDone => '사운드가 공장 초기값으로 재설정되었습니다';

  @override
  String settingsResetSoundsFailed(String error) {
    return '재설정 실패: $error';
  }

  @override
  String get soundsTitle => '사운드';

  @override
  String get soundsReplace => '교체';

  @override
  String get soundsFactory => '기본';

  @override
  String get soundsCustom => '사용자';

  @override
  String soundsReplaced(String id) {
    return '$id 교체됨';
  }

  @override
  String soundsReplaceFailed(String error) {
    return '교체 실패: $error';
  }

  @override
  String get soundsRestoreOne => '기본 사운드 복원';

  @override
  String get soundsCatalogFromRobot => '서버에서 가져온 사운드 목록';

  @override
  String get soundsCatalogDefault => '기본 목록 (서버 응답 없음)';

  @override
  String get soundGroupGreeting => '인사';

  @override
  String get soundGroupTreat => '간식';

  @override
  String get soundGroupCue => '신호';

  @override
  String get soundGroupAlert => '알림';

  @override
  String get soundGroupSgLevel => '사일런트 가디언 단계';

  @override
  String get soundGroupMusic => '음악 클래스';

  @override
  String get songUploadTitle => '노래 업로드';

  @override
  String get settingsSongUploadSubtitle => '퍼블릭 도메인 녹음을 로봇으로 전송';

  @override
  String get songUploadPdNotice => '사용 권한이 있는 녹음(퍼블릭 도메인 또는 직접 만든 것)만 업로드하세요.';

  @override
  String get songUploadPdCheckbox => '이 녹음은 퍼블릭 도메인이거나 내 것입니다';

  @override
  String get songUploadChoose => '노래 선택';

  @override
  String get songUploadFormats => 'MP3 또는 WAV · 최대 5MB';

  @override
  String songUploadUploading(String name) {
    return '$name 업로드 중…';
  }

  @override
  String songUploadDone(String name) {
    return '$name 업로드 완료';
  }

  @override
  String songUploadFailed(String error) {
    return '업로드 실패: $error';
  }

  @override
  String get songUploadTooLarge => '파일이 5MB를 초과합니다';

  @override
  String get songUploadNoDog => '먼저 반려견을 선택하세요';

  @override
  String get songUploadNotSignedIn => '업로드하려면 로그인하세요';

  @override
  String get songUploadPlayHint => '홈의 음악 버튼에서 재생할 수 있습니다.';

  @override
  String get settingsSectionDemo => '데모';

  @override
  String get demoViewTitle => '데모 화면';

  @override
  String get demoViewSubtitle => '화면 미러링용: 오늘, 가디언, 에이전트 대화';

  @override
  String get demoPanelGuardian => '사일런트 가디언';

  @override
  String get demoPanelTranscript => '에이전트 대화';

  @override
  String get demoTranscriptEmpty => '어시스턴트를 기다리는 중…';

  @override
  String get demoNoDog => '먼저 홈에서 반려견을 선택하세요';

  @override
  String get demoSgIdle => '가디언 미실행';

  @override
  String get aiErrNoDog => '먼저 강아지를 선택하세요';

  @override
  String get aiErrRevokeAllFailed => '어시스턴트 연결을 해제하지 못했습니다';

  @override
  String get aiDisconnectAll => '모든 어시스턴트 연결 해제';

  @override
  String get aiDisconnectAllSubtitle =>
      '긴급 차단: 모든 어시스턴트의 접근이 즉시 끊기며 다시 연결해야 합니다';

  @override
  String get aiDisconnectAllConfirm =>
      '모든 어시스턴트의 연결을 해제할까요? 즉시 접근이 끊기며 다시 연결해야 합니다.';

  @override
  String aiDisconnectAllDone(int count) {
    return '토큰 $count개 취소됨';
  }

  @override
  String get draftActorVoiceAgent => 'WIM-Z 음성 에이전트';

  @override
  String get draftTriggerDeparture => '외출 후 시작';

  @override
  String draftTriggerSchedule(String time) {
    return '매일 $time';
  }

  @override
  String get draftTriggerManual => '수동 시작';

  @override
  String draftDurationReward(int minutes, int treats) {
    return '$minutes분 · 간식 $treats개';
  }

  @override
  String get todayStatSettle => '진정';

  @override
  String get todayStatPacing => '서성임';

  @override
  String get todayStatMusic => '음악';

  @override
  String get todayStatAlone => '혼자';

  @override
  String get todayStatMissions => '미션';

  @override
  String get todayEpisodes => '주요 짖음 에피소드';

  @override
  String todayEpisodeLine(int barks, String duration) {
    return '짖음 $barks회 · $duration';
  }

  @override
  String todayEpisodeSettled(String duration) {
    return '$duration 만에 진정';
  }

  @override
  String get todayCardEmptyRelay => '오늘 릴레이에 기록된 이벤트가 없습니다 — 이 휴대폰의 집계';

  @override
  String get soundsFormats => 'MP3 또는 WAV · 최대 5MB';

  @override
  String get soundGroupSong => '노래';

  @override
  String get robotCardLocal => '로봇에 직접 연결됨';

  @override
  String get robotCardNonePaired => '페어링된 로봇 없음';

  @override
  String get robotCardNoneBody => '페어링은 선택 사항입니다 — 준비되면 언제든 로봇을 페어링하세요.';

  @override
  String get robotCardPair => '로봇 페어링';

  @override
  String get robotCardManage => '관리';

  @override
  String get dogNameYourDog => '강아지 이름 지어주기';
}
