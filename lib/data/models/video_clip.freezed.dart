// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_clip.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

VideoClip _$VideoClipFromJson(Map<String, dynamic> json) {
  return _VideoClip.fromJson(json);
}

/// @nodoc
mixin _$VideoClip {
  String get id => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  Duration get duration => throw _privateConstructorUsedError;
  String? get thumbnailUrl => throw _privateConstructorUsedError;
  String? get dogId => throw _privateConstructorUsedError;
  String? get missionId => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError;
  List<VideoEvent> get events => throw _privateConstructorUsedError;
  bool get isFavorite => throw _privateConstructorUsedError;
  bool get isShared => throw _privateConstructorUsedError;

  /// Serializes this VideoClip to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VideoClip
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VideoClipCopyWith<VideoClip> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VideoClipCopyWith<$Res> {
  factory $VideoClipCopyWith(VideoClip value, $Res Function(VideoClip) then) =
      _$VideoClipCopyWithImpl<$Res, VideoClip>;
  @useResult
  $Res call(
      {String id,
      String url,
      DateTime timestamp,
      Duration duration,
      String? thumbnailUrl,
      String? dogId,
      String? missionId,
      List<String> tags,
      List<VideoEvent> events,
      bool isFavorite,
      bool isShared});
}

/// @nodoc
class _$VideoClipCopyWithImpl<$Res, $Val extends VideoClip>
    implements $VideoClipCopyWith<$Res> {
  _$VideoClipCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VideoClip
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? url = null,
    Object? timestamp = null,
    Object? duration = null,
    Object? thumbnailUrl = freezed,
    Object? dogId = freezed,
    Object? missionId = freezed,
    Object? tags = null,
    Object? events = null,
    Object? isFavorite = null,
    Object? isShared = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      dogId: freezed == dogId
          ? _value.dogId
          : dogId // ignore: cast_nullable_to_non_nullable
              as String?,
      missionId: freezed == missionId
          ? _value.missionId
          : missionId // ignore: cast_nullable_to_non_nullable
              as String?,
      tags: null == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      events: null == events
          ? _value.events
          : events // ignore: cast_nullable_to_non_nullable
              as List<VideoEvent>,
      isFavorite: null == isFavorite
          ? _value.isFavorite
          : isFavorite // ignore: cast_nullable_to_non_nullable
              as bool,
      isShared: null == isShared
          ? _value.isShared
          : isShared // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VideoClipImplCopyWith<$Res>
    implements $VideoClipCopyWith<$Res> {
  factory _$$VideoClipImplCopyWith(
          _$VideoClipImpl value, $Res Function(_$VideoClipImpl) then) =
      __$$VideoClipImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String url,
      DateTime timestamp,
      Duration duration,
      String? thumbnailUrl,
      String? dogId,
      String? missionId,
      List<String> tags,
      List<VideoEvent> events,
      bool isFavorite,
      bool isShared});
}

/// @nodoc
class __$$VideoClipImplCopyWithImpl<$Res>
    extends _$VideoClipCopyWithImpl<$Res, _$VideoClipImpl>
    implements _$$VideoClipImplCopyWith<$Res> {
  __$$VideoClipImplCopyWithImpl(
      _$VideoClipImpl _value, $Res Function(_$VideoClipImpl) _then)
      : super(_value, _then);

  /// Create a copy of VideoClip
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? url = null,
    Object? timestamp = null,
    Object? duration = null,
    Object? thumbnailUrl = freezed,
    Object? dogId = freezed,
    Object? missionId = freezed,
    Object? tags = null,
    Object? events = null,
    Object? isFavorite = null,
    Object? isShared = null,
  }) {
    return _then(_$VideoClipImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      dogId: freezed == dogId
          ? _value.dogId
          : dogId // ignore: cast_nullable_to_non_nullable
              as String?,
      missionId: freezed == missionId
          ? _value.missionId
          : missionId // ignore: cast_nullable_to_non_nullable
              as String?,
      tags: null == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      events: null == events
          ? _value._events
          : events // ignore: cast_nullable_to_non_nullable
              as List<VideoEvent>,
      isFavorite: null == isFavorite
          ? _value.isFavorite
          : isFavorite // ignore: cast_nullable_to_non_nullable
              as bool,
      isShared: null == isShared
          ? _value.isShared
          : isShared // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$VideoClipImpl extends _VideoClip {
  const _$VideoClipImpl(
      {required this.id,
      required this.url,
      required this.timestamp,
      required this.duration,
      this.thumbnailUrl,
      this.dogId,
      this.missionId,
      final List<String> tags = const [],
      final List<VideoEvent> events = const [],
      this.isFavorite = false,
      this.isShared = false})
      : _tags = tags,
        _events = events,
        super._();

  factory _$VideoClipImpl.fromJson(Map<String, dynamic> json) =>
      _$$VideoClipImplFromJson(json);

  @override
  final String id;
  @override
  final String url;
  @override
  final DateTime timestamp;
  @override
  final Duration duration;
  @override
  final String? thumbnailUrl;
  @override
  final String? dogId;
  @override
  final String? missionId;
  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  final List<VideoEvent> _events;
  @override
  @JsonKey()
  List<VideoEvent> get events {
    if (_events is EqualUnmodifiableListView) return _events;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_events);
  }

  @override
  @JsonKey()
  final bool isFavorite;
  @override
  @JsonKey()
  final bool isShared;

  @override
  String toString() {
    return 'VideoClip(id: $id, url: $url, timestamp: $timestamp, duration: $duration, thumbnailUrl: $thumbnailUrl, dogId: $dogId, missionId: $missionId, tags: $tags, events: $events, isFavorite: $isFavorite, isShared: $isShared)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VideoClipImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            (identical(other.dogId, dogId) || other.dogId == dogId) &&
            (identical(other.missionId, missionId) ||
                other.missionId == missionId) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            const DeepCollectionEquality().equals(other._events, _events) &&
            (identical(other.isFavorite, isFavorite) ||
                other.isFavorite == isFavorite) &&
            (identical(other.isShared, isShared) ||
                other.isShared == isShared));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      url,
      timestamp,
      duration,
      thumbnailUrl,
      dogId,
      missionId,
      const DeepCollectionEquality().hash(_tags),
      const DeepCollectionEquality().hash(_events),
      isFavorite,
      isShared);

  /// Create a copy of VideoClip
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VideoClipImplCopyWith<_$VideoClipImpl> get copyWith =>
      __$$VideoClipImplCopyWithImpl<_$VideoClipImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VideoClipImplToJson(
      this,
    );
  }
}

abstract class _VideoClip extends VideoClip {
  const factory _VideoClip(
      {required final String id,
      required final String url,
      required final DateTime timestamp,
      required final Duration duration,
      final String? thumbnailUrl,
      final String? dogId,
      final String? missionId,
      final List<String> tags,
      final List<VideoEvent> events,
      final bool isFavorite,
      final bool isShared}) = _$VideoClipImpl;
  const _VideoClip._() : super._();

  factory _VideoClip.fromJson(Map<String, dynamic> json) =
      _$VideoClipImpl.fromJson;

  @override
  String get id;
  @override
  String get url;
  @override
  DateTime get timestamp;
  @override
  Duration get duration;
  @override
  String? get thumbnailUrl;
  @override
  String? get dogId;
  @override
  String? get missionId;
  @override
  List<String> get tags;
  @override
  List<VideoEvent> get events;
  @override
  bool get isFavorite;
  @override
  bool get isShared;

  /// Create a copy of VideoClip
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VideoClipImplCopyWith<_$VideoClipImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

VideoEvent _$VideoEventFromJson(Map<String, dynamic> json) {
  return _VideoEvent.fromJson(json);
}

/// @nodoc
mixin _$VideoEvent {
  Duration get timestamp => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  String? get label => throw _privateConstructorUsedError;

  /// Serializes this VideoEvent to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VideoEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VideoEventCopyWith<VideoEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VideoEventCopyWith<$Res> {
  factory $VideoEventCopyWith(
          VideoEvent value, $Res Function(VideoEvent) then) =
      _$VideoEventCopyWithImpl<$Res, VideoEvent>;
  @useResult
  $Res call({Duration timestamp, String type, String? label});
}

/// @nodoc
class _$VideoEventCopyWithImpl<$Res, $Val extends VideoEvent>
    implements $VideoEventCopyWith<$Res> {
  _$VideoEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VideoEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? timestamp = null,
    Object? type = null,
    Object? label = freezed,
  }) {
    return _then(_value.copyWith(
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as Duration,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      label: freezed == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VideoEventImplCopyWith<$Res>
    implements $VideoEventCopyWith<$Res> {
  factory _$$VideoEventImplCopyWith(
          _$VideoEventImpl value, $Res Function(_$VideoEventImpl) then) =
      __$$VideoEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Duration timestamp, String type, String? label});
}

/// @nodoc
class __$$VideoEventImplCopyWithImpl<$Res>
    extends _$VideoEventCopyWithImpl<$Res, _$VideoEventImpl>
    implements _$$VideoEventImplCopyWith<$Res> {
  __$$VideoEventImplCopyWithImpl(
      _$VideoEventImpl _value, $Res Function(_$VideoEventImpl) _then)
      : super(_value, _then);

  /// Create a copy of VideoEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? timestamp = null,
    Object? type = null,
    Object? label = freezed,
  }) {
    return _then(_$VideoEventImpl(
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as Duration,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      label: freezed == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$VideoEventImpl extends _VideoEvent {
  const _$VideoEventImpl(
      {required this.timestamp, required this.type, this.label})
      : super._();

  factory _$VideoEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$VideoEventImplFromJson(json);

  @override
  final Duration timestamp;
  @override
  final String type;
  @override
  final String? label;

  @override
  String toString() {
    return 'VideoEvent(timestamp: $timestamp, type: $type, label: $label)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VideoEventImpl &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.label, label) || other.label == label));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, timestamp, type, label);

  /// Create a copy of VideoEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VideoEventImplCopyWith<_$VideoEventImpl> get copyWith =>
      __$$VideoEventImplCopyWithImpl<_$VideoEventImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VideoEventImplToJson(
      this,
    );
  }
}

abstract class _VideoEvent extends VideoEvent {
  const factory _VideoEvent(
      {required final Duration timestamp,
      required final String type,
      final String? label}) = _$VideoEventImpl;
  const _VideoEvent._() : super._();

  factory _VideoEvent.fromJson(Map<String, dynamic> json) =
      _$VideoEventImpl.fromJson;

  @override
  Duration get timestamp;
  @override
  String get type;
  @override
  String? get label;

  /// Create a copy of VideoEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VideoEventImplCopyWith<_$VideoEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
