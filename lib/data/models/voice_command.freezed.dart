// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'voice_command.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

VoiceCommand _$VoiceCommandFromJson(Map<String, dynamic> json) {
  return _VoiceCommand.fromJson(json);
}

/// @nodoc
mixin _$VoiceCommand {
  String get dogId => throw _privateConstructorUsedError;
  String get commandId => throw _privateConstructorUsedError;
  String? get localPath => throw _privateConstructorUsedError;
  DateTime? get recordedAt => throw _privateConstructorUsedError;
  bool get isSynced => throw _privateConstructorUsedError;
  DateTime? get syncedAt => throw _privateConstructorUsedError;
  int get durationMs => throw _privateConstructorUsedError;

  /// Serializes this VoiceCommand to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VoiceCommand
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VoiceCommandCopyWith<VoiceCommand> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VoiceCommandCopyWith<$Res> {
  factory $VoiceCommandCopyWith(
          VoiceCommand value, $Res Function(VoiceCommand) then) =
      _$VoiceCommandCopyWithImpl<$Res, VoiceCommand>;
  @useResult
  $Res call(
      {String dogId,
      String commandId,
      String? localPath,
      DateTime? recordedAt,
      bool isSynced,
      DateTime? syncedAt,
      int durationMs});
}

/// @nodoc
class _$VoiceCommandCopyWithImpl<$Res, $Val extends VoiceCommand>
    implements $VoiceCommandCopyWith<$Res> {
  _$VoiceCommandCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VoiceCommand
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dogId = null,
    Object? commandId = null,
    Object? localPath = freezed,
    Object? recordedAt = freezed,
    Object? isSynced = null,
    Object? syncedAt = freezed,
    Object? durationMs = null,
  }) {
    return _then(_value.copyWith(
      dogId: null == dogId
          ? _value.dogId
          : dogId // ignore: cast_nullable_to_non_nullable
              as String,
      commandId: null == commandId
          ? _value.commandId
          : commandId // ignore: cast_nullable_to_non_nullable
              as String,
      localPath: freezed == localPath
          ? _value.localPath
          : localPath // ignore: cast_nullable_to_non_nullable
              as String?,
      recordedAt: freezed == recordedAt
          ? _value.recordedAt
          : recordedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isSynced: null == isSynced
          ? _value.isSynced
          : isSynced // ignore: cast_nullable_to_non_nullable
              as bool,
      syncedAt: freezed == syncedAt
          ? _value.syncedAt
          : syncedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      durationMs: null == durationMs
          ? _value.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VoiceCommandImplCopyWith<$Res>
    implements $VoiceCommandCopyWith<$Res> {
  factory _$$VoiceCommandImplCopyWith(
          _$VoiceCommandImpl value, $Res Function(_$VoiceCommandImpl) then) =
      __$$VoiceCommandImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String dogId,
      String commandId,
      String? localPath,
      DateTime? recordedAt,
      bool isSynced,
      DateTime? syncedAt,
      int durationMs});
}

/// @nodoc
class __$$VoiceCommandImplCopyWithImpl<$Res>
    extends _$VoiceCommandCopyWithImpl<$Res, _$VoiceCommandImpl>
    implements _$$VoiceCommandImplCopyWith<$Res> {
  __$$VoiceCommandImplCopyWithImpl(
      _$VoiceCommandImpl _value, $Res Function(_$VoiceCommandImpl) _then)
      : super(_value, _then);

  /// Create a copy of VoiceCommand
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dogId = null,
    Object? commandId = null,
    Object? localPath = freezed,
    Object? recordedAt = freezed,
    Object? isSynced = null,
    Object? syncedAt = freezed,
    Object? durationMs = null,
  }) {
    return _then(_$VoiceCommandImpl(
      dogId: null == dogId
          ? _value.dogId
          : dogId // ignore: cast_nullable_to_non_nullable
              as String,
      commandId: null == commandId
          ? _value.commandId
          : commandId // ignore: cast_nullable_to_non_nullable
              as String,
      localPath: freezed == localPath
          ? _value.localPath
          : localPath // ignore: cast_nullable_to_non_nullable
              as String?,
      recordedAt: freezed == recordedAt
          ? _value.recordedAt
          : recordedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isSynced: null == isSynced
          ? _value.isSynced
          : isSynced // ignore: cast_nullable_to_non_nullable
              as bool,
      syncedAt: freezed == syncedAt
          ? _value.syncedAt
          : syncedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      durationMs: null == durationMs
          ? _value.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$VoiceCommandImpl implements _VoiceCommand {
  const _$VoiceCommandImpl(
      {required this.dogId,
      required this.commandId,
      this.localPath,
      this.recordedAt,
      this.isSynced = false,
      this.syncedAt,
      this.durationMs = 0});

  factory _$VoiceCommandImpl.fromJson(Map<String, dynamic> json) =>
      _$$VoiceCommandImplFromJson(json);

  @override
  final String dogId;
  @override
  final String commandId;
  @override
  final String? localPath;
  @override
  final DateTime? recordedAt;
  @override
  @JsonKey()
  final bool isSynced;
  @override
  final DateTime? syncedAt;
  @override
  @JsonKey()
  final int durationMs;

  @override
  String toString() {
    return 'VoiceCommand(dogId: $dogId, commandId: $commandId, localPath: $localPath, recordedAt: $recordedAt, isSynced: $isSynced, syncedAt: $syncedAt, durationMs: $durationMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VoiceCommandImpl &&
            (identical(other.dogId, dogId) || other.dogId == dogId) &&
            (identical(other.commandId, commandId) ||
                other.commandId == commandId) &&
            (identical(other.localPath, localPath) ||
                other.localPath == localPath) &&
            (identical(other.recordedAt, recordedAt) ||
                other.recordedAt == recordedAt) &&
            (identical(other.isSynced, isSynced) ||
                other.isSynced == isSynced) &&
            (identical(other.syncedAt, syncedAt) ||
                other.syncedAt == syncedAt) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, dogId, commandId, localPath,
      recordedAt, isSynced, syncedAt, durationMs);

  /// Create a copy of VoiceCommand
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VoiceCommandImplCopyWith<_$VoiceCommandImpl> get copyWith =>
      __$$VoiceCommandImplCopyWithImpl<_$VoiceCommandImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VoiceCommandImplToJson(
      this,
    );
  }
}

abstract class _VoiceCommand implements VoiceCommand {
  const factory _VoiceCommand(
      {required final String dogId,
      required final String commandId,
      final String? localPath,
      final DateTime? recordedAt,
      final bool isSynced,
      final DateTime? syncedAt,
      final int durationMs}) = _$VoiceCommandImpl;

  factory _VoiceCommand.fromJson(Map<String, dynamic> json) =
      _$VoiceCommandImpl.fromJson;

  @override
  String get dogId;
  @override
  String get commandId;
  @override
  String? get localPath;
  @override
  DateTime? get recordedAt;
  @override
  bool get isSynced;
  @override
  DateTime? get syncedAt;
  @override
  int get durationMs;

  /// Create a copy of VoiceCommand
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VoiceCommandImplCopyWith<_$VoiceCommandImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DogVoiceCommands _$DogVoiceCommandsFromJson(Map<String, dynamic> json) {
  return _DogVoiceCommands.fromJson(json);
}

/// @nodoc
mixin _$DogVoiceCommands {
  String get dogId => throw _privateConstructorUsedError;
  Map<String, VoiceCommand> get commands => throw _privateConstructorUsedError;
  bool get isRecording => throw _privateConstructorUsedError;
  String? get currentRecordingCommand => throw _privateConstructorUsedError;

  /// Serializes this DogVoiceCommands to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DogVoiceCommands
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DogVoiceCommandsCopyWith<DogVoiceCommands> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DogVoiceCommandsCopyWith<$Res> {
  factory $DogVoiceCommandsCopyWith(
          DogVoiceCommands value, $Res Function(DogVoiceCommands) then) =
      _$DogVoiceCommandsCopyWithImpl<$Res, DogVoiceCommands>;
  @useResult
  $Res call(
      {String dogId,
      Map<String, VoiceCommand> commands,
      bool isRecording,
      String? currentRecordingCommand});
}

/// @nodoc
class _$DogVoiceCommandsCopyWithImpl<$Res, $Val extends DogVoiceCommands>
    implements $DogVoiceCommandsCopyWith<$Res> {
  _$DogVoiceCommandsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DogVoiceCommands
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dogId = null,
    Object? commands = null,
    Object? isRecording = null,
    Object? currentRecordingCommand = freezed,
  }) {
    return _then(_value.copyWith(
      dogId: null == dogId
          ? _value.dogId
          : dogId // ignore: cast_nullable_to_non_nullable
              as String,
      commands: null == commands
          ? _value.commands
          : commands // ignore: cast_nullable_to_non_nullable
              as Map<String, VoiceCommand>,
      isRecording: null == isRecording
          ? _value.isRecording
          : isRecording // ignore: cast_nullable_to_non_nullable
              as bool,
      currentRecordingCommand: freezed == currentRecordingCommand
          ? _value.currentRecordingCommand
          : currentRecordingCommand // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DogVoiceCommandsImplCopyWith<$Res>
    implements $DogVoiceCommandsCopyWith<$Res> {
  factory _$$DogVoiceCommandsImplCopyWith(_$DogVoiceCommandsImpl value,
          $Res Function(_$DogVoiceCommandsImpl) then) =
      __$$DogVoiceCommandsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String dogId,
      Map<String, VoiceCommand> commands,
      bool isRecording,
      String? currentRecordingCommand});
}

/// @nodoc
class __$$DogVoiceCommandsImplCopyWithImpl<$Res>
    extends _$DogVoiceCommandsCopyWithImpl<$Res, _$DogVoiceCommandsImpl>
    implements _$$DogVoiceCommandsImplCopyWith<$Res> {
  __$$DogVoiceCommandsImplCopyWithImpl(_$DogVoiceCommandsImpl _value,
      $Res Function(_$DogVoiceCommandsImpl) _then)
      : super(_value, _then);

  /// Create a copy of DogVoiceCommands
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dogId = null,
    Object? commands = null,
    Object? isRecording = null,
    Object? currentRecordingCommand = freezed,
  }) {
    return _then(_$DogVoiceCommandsImpl(
      dogId: null == dogId
          ? _value.dogId
          : dogId // ignore: cast_nullable_to_non_nullable
              as String,
      commands: null == commands
          ? _value._commands
          : commands // ignore: cast_nullable_to_non_nullable
              as Map<String, VoiceCommand>,
      isRecording: null == isRecording
          ? _value.isRecording
          : isRecording // ignore: cast_nullable_to_non_nullable
              as bool,
      currentRecordingCommand: freezed == currentRecordingCommand
          ? _value.currentRecordingCommand
          : currentRecordingCommand // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DogVoiceCommandsImpl implements _DogVoiceCommands {
  const _$DogVoiceCommandsImpl(
      {required this.dogId,
      final Map<String, VoiceCommand> commands = const {},
      this.isRecording = false,
      this.currentRecordingCommand})
      : _commands = commands;

  factory _$DogVoiceCommandsImpl.fromJson(Map<String, dynamic> json) =>
      _$$DogVoiceCommandsImplFromJson(json);

  @override
  final String dogId;
  final Map<String, VoiceCommand> _commands;
  @override
  @JsonKey()
  Map<String, VoiceCommand> get commands {
    if (_commands is EqualUnmodifiableMapView) return _commands;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_commands);
  }

  @override
  @JsonKey()
  final bool isRecording;
  @override
  final String? currentRecordingCommand;

  @override
  String toString() {
    return 'DogVoiceCommands(dogId: $dogId, commands: $commands, isRecording: $isRecording, currentRecordingCommand: $currentRecordingCommand)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DogVoiceCommandsImpl &&
            (identical(other.dogId, dogId) || other.dogId == dogId) &&
            const DeepCollectionEquality().equals(other._commands, _commands) &&
            (identical(other.isRecording, isRecording) ||
                other.isRecording == isRecording) &&
            (identical(
                    other.currentRecordingCommand, currentRecordingCommand) ||
                other.currentRecordingCommand == currentRecordingCommand));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      dogId,
      const DeepCollectionEquality().hash(_commands),
      isRecording,
      currentRecordingCommand);

  /// Create a copy of DogVoiceCommands
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DogVoiceCommandsImplCopyWith<_$DogVoiceCommandsImpl> get copyWith =>
      __$$DogVoiceCommandsImplCopyWithImpl<_$DogVoiceCommandsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DogVoiceCommandsImplToJson(
      this,
    );
  }
}

abstract class _DogVoiceCommands implements DogVoiceCommands {
  const factory _DogVoiceCommands(
      {required final String dogId,
      final Map<String, VoiceCommand> commands,
      final bool isRecording,
      final String? currentRecordingCommand}) = _$DogVoiceCommandsImpl;

  factory _DogVoiceCommands.fromJson(Map<String, dynamic> json) =
      _$DogVoiceCommandsImpl.fromJson;

  @override
  String get dogId;
  @override
  Map<String, VoiceCommand> get commands;
  @override
  bool get isRecording;
  @override
  String? get currentRecordingCommand;

  /// Create a copy of DogVoiceCommands
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DogVoiceCommandsImplCopyWith<_$DogVoiceCommandsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
