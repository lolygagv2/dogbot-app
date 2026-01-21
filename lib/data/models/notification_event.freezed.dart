// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

NotificationEvent _$NotificationEventFromJson(Map<String, dynamic> json) {
  return _NotificationEvent.fromJson(json);
}

/// @nodoc
mixin _$NotificationEvent {
  String get id => throw _privateConstructorUsedError;
  NotificationEventType get type => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get subtitle => throw _privateConstructorUsedError;
  String? get dogId => throw _privateConstructorUsedError;
  String? get missionId => throw _privateConstructorUsedError;
  String? get videoClipId => throw _privateConstructorUsedError;
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;
  bool get isRead => throw _privateConstructorUsedError;

  /// Serializes this NotificationEvent to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NotificationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NotificationEventCopyWith<NotificationEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NotificationEventCopyWith<$Res> {
  factory $NotificationEventCopyWith(
          NotificationEvent value, $Res Function(NotificationEvent) then) =
      _$NotificationEventCopyWithImpl<$Res, NotificationEvent>;
  @useResult
  $Res call(
      {String id,
      NotificationEventType type,
      DateTime timestamp,
      String title,
      String? subtitle,
      String? dogId,
      String? missionId,
      String? videoClipId,
      Map<String, dynamic>? metadata,
      bool isRead});
}

/// @nodoc
class _$NotificationEventCopyWithImpl<$Res, $Val extends NotificationEvent>
    implements $NotificationEventCopyWith<$Res> {
  _$NotificationEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NotificationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? timestamp = null,
    Object? title = null,
    Object? subtitle = freezed,
    Object? dogId = freezed,
    Object? missionId = freezed,
    Object? videoClipId = freezed,
    Object? metadata = freezed,
    Object? isRead = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as NotificationEventType,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      subtitle: freezed == subtitle
          ? _value.subtitle
          : subtitle // ignore: cast_nullable_to_non_nullable
              as String?,
      dogId: freezed == dogId
          ? _value.dogId
          : dogId // ignore: cast_nullable_to_non_nullable
              as String?,
      missionId: freezed == missionId
          ? _value.missionId
          : missionId // ignore: cast_nullable_to_non_nullable
              as String?,
      videoClipId: freezed == videoClipId
          ? _value.videoClipId
          : videoClipId // ignore: cast_nullable_to_non_nullable
              as String?,
      metadata: freezed == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      isRead: null == isRead
          ? _value.isRead
          : isRead // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NotificationEventImplCopyWith<$Res>
    implements $NotificationEventCopyWith<$Res> {
  factory _$$NotificationEventImplCopyWith(_$NotificationEventImpl value,
          $Res Function(_$NotificationEventImpl) then) =
      __$$NotificationEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      NotificationEventType type,
      DateTime timestamp,
      String title,
      String? subtitle,
      String? dogId,
      String? missionId,
      String? videoClipId,
      Map<String, dynamic>? metadata,
      bool isRead});
}

/// @nodoc
class __$$NotificationEventImplCopyWithImpl<$Res>
    extends _$NotificationEventCopyWithImpl<$Res, _$NotificationEventImpl>
    implements _$$NotificationEventImplCopyWith<$Res> {
  __$$NotificationEventImplCopyWithImpl(_$NotificationEventImpl _value,
      $Res Function(_$NotificationEventImpl) _then)
      : super(_value, _then);

  /// Create a copy of NotificationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? timestamp = null,
    Object? title = null,
    Object? subtitle = freezed,
    Object? dogId = freezed,
    Object? missionId = freezed,
    Object? videoClipId = freezed,
    Object? metadata = freezed,
    Object? isRead = null,
  }) {
    return _then(_$NotificationEventImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as NotificationEventType,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      subtitle: freezed == subtitle
          ? _value.subtitle
          : subtitle // ignore: cast_nullable_to_non_nullable
              as String?,
      dogId: freezed == dogId
          ? _value.dogId
          : dogId // ignore: cast_nullable_to_non_nullable
              as String?,
      missionId: freezed == missionId
          ? _value.missionId
          : missionId // ignore: cast_nullable_to_non_nullable
              as String?,
      videoClipId: freezed == videoClipId
          ? _value.videoClipId
          : videoClipId // ignore: cast_nullable_to_non_nullable
              as String?,
      metadata: freezed == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      isRead: null == isRead
          ? _value.isRead
          : isRead // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NotificationEventImpl implements _NotificationEvent {
  const _$NotificationEventImpl(
      {required this.id,
      required this.type,
      required this.timestamp,
      required this.title,
      this.subtitle,
      this.dogId,
      this.missionId,
      this.videoClipId,
      final Map<String, dynamic>? metadata,
      this.isRead = false})
      : _metadata = metadata;

  factory _$NotificationEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$NotificationEventImplFromJson(json);

  @override
  final String id;
  @override
  final NotificationEventType type;
  @override
  final DateTime timestamp;
  @override
  final String title;
  @override
  final String? subtitle;
  @override
  final String? dogId;
  @override
  final String? missionId;
  @override
  final String? videoClipId;
  final Map<String, dynamic>? _metadata;
  @override
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey()
  final bool isRead;

  @override
  String toString() {
    return 'NotificationEvent(id: $id, type: $type, timestamp: $timestamp, title: $title, subtitle: $subtitle, dogId: $dogId, missionId: $missionId, videoClipId: $videoClipId, metadata: $metadata, isRead: $isRead)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotificationEventImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.subtitle, subtitle) ||
                other.subtitle == subtitle) &&
            (identical(other.dogId, dogId) || other.dogId == dogId) &&
            (identical(other.missionId, missionId) ||
                other.missionId == missionId) &&
            (identical(other.videoClipId, videoClipId) ||
                other.videoClipId == videoClipId) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata) &&
            (identical(other.isRead, isRead) || other.isRead == isRead));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      type,
      timestamp,
      title,
      subtitle,
      dogId,
      missionId,
      videoClipId,
      const DeepCollectionEquality().hash(_metadata),
      isRead);

  /// Create a copy of NotificationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NotificationEventImplCopyWith<_$NotificationEventImpl> get copyWith =>
      __$$NotificationEventImplCopyWithImpl<_$NotificationEventImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NotificationEventImplToJson(
      this,
    );
  }
}

abstract class _NotificationEvent implements NotificationEvent {
  const factory _NotificationEvent(
      {required final String id,
      required final NotificationEventType type,
      required final DateTime timestamp,
      required final String title,
      final String? subtitle,
      final String? dogId,
      final String? missionId,
      final String? videoClipId,
      final Map<String, dynamic>? metadata,
      final bool isRead}) = _$NotificationEventImpl;

  factory _NotificationEvent.fromJson(Map<String, dynamic> json) =
      _$NotificationEventImpl.fromJson;

  @override
  String get id;
  @override
  NotificationEventType get type;
  @override
  DateTime get timestamp;
  @override
  String get title;
  @override
  String? get subtitle;
  @override
  String? get dogId;
  @override
  String? get missionId;
  @override
  String? get videoClipId;
  @override
  Map<String, dynamic>? get metadata;
  @override
  bool get isRead;

  /// Create a copy of NotificationEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NotificationEventImplCopyWith<_$NotificationEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
