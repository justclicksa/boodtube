// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sponsor_segment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$SponsorSegment {
  Duration get start => throw _privateConstructorUsedError;
  Duration get end => throw _privateConstructorUsedError;
  SponsorCategory get category => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get uuid => throw _privateConstructorUsedError;

  /// Create a copy of SponsorSegment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SponsorSegmentCopyWith<SponsorSegment> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SponsorSegmentCopyWith<$Res> {
  factory $SponsorSegmentCopyWith(
          SponsorSegment value, $Res Function(SponsorSegment) then) =
      _$SponsorSegmentCopyWithImpl<$Res, SponsorSegment>;
  @useResult
  $Res call(
      {Duration start,
      Duration end,
      SponsorCategory category,
      String? description,
      String? uuid});
}

/// @nodoc
class _$SponsorSegmentCopyWithImpl<$Res, $Val extends SponsorSegment>
    implements $SponsorSegmentCopyWith<$Res> {
  _$SponsorSegmentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SponsorSegment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? start = null,
    Object? end = null,
    Object? category = null,
    Object? description = freezed,
    Object? uuid = freezed,
  }) {
    return _then(_value.copyWith(
      start: null == start
          ? _value.start
          : start // ignore: cast_nullable_to_non_nullable
              as Duration,
      end: null == end
          ? _value.end
          : end // ignore: cast_nullable_to_non_nullable
              as Duration,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as SponsorCategory,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      uuid: freezed == uuid
          ? _value.uuid
          : uuid // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SponsorSegmentImplCopyWith<$Res>
    implements $SponsorSegmentCopyWith<$Res> {
  factory _$$SponsorSegmentImplCopyWith(_$SponsorSegmentImpl value,
          $Res Function(_$SponsorSegmentImpl) then) =
      __$$SponsorSegmentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Duration start,
      Duration end,
      SponsorCategory category,
      String? description,
      String? uuid});
}

/// @nodoc
class __$$SponsorSegmentImplCopyWithImpl<$Res>
    extends _$SponsorSegmentCopyWithImpl<$Res, _$SponsorSegmentImpl>
    implements _$$SponsorSegmentImplCopyWith<$Res> {
  __$$SponsorSegmentImplCopyWithImpl(
      _$SponsorSegmentImpl _value, $Res Function(_$SponsorSegmentImpl) _then)
      : super(_value, _then);

  /// Create a copy of SponsorSegment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? start = null,
    Object? end = null,
    Object? category = null,
    Object? description = freezed,
    Object? uuid = freezed,
  }) {
    return _then(_$SponsorSegmentImpl(
      start: null == start
          ? _value.start
          : start // ignore: cast_nullable_to_non_nullable
              as Duration,
      end: null == end
          ? _value.end
          : end // ignore: cast_nullable_to_non_nullable
              as Duration,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as SponsorCategory,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      uuid: freezed == uuid
          ? _value.uuid
          : uuid // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$SponsorSegmentImpl extends _SponsorSegment {
  const _$SponsorSegmentImpl(
      {required this.start,
      required this.end,
      required this.category,
      this.description,
      this.uuid})
      : super._();

  @override
  final Duration start;
  @override
  final Duration end;
  @override
  final SponsorCategory category;
  @override
  final String? description;
  @override
  final String? uuid;

  @override
  String toString() {
    return 'SponsorSegment(start: $start, end: $end, category: $category, description: $description, uuid: $uuid)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SponsorSegmentImpl &&
            (identical(other.start, start) || other.start == start) &&
            (identical(other.end, end) || other.end == end) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.uuid, uuid) || other.uuid == uuid));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, start, end, category, description, uuid);

  /// Create a copy of SponsorSegment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SponsorSegmentImplCopyWith<_$SponsorSegmentImpl> get copyWith =>
      __$$SponsorSegmentImplCopyWithImpl<_$SponsorSegmentImpl>(
          this, _$identity);
}

abstract class _SponsorSegment extends SponsorSegment {
  const factory _SponsorSegment(
      {required final Duration start,
      required final Duration end,
      required final SponsorCategory category,
      final String? description,
      final String? uuid}) = _$SponsorSegmentImpl;
  const _SponsorSegment._() : super._();

  @override
  Duration get start;
  @override
  Duration get end;
  @override
  SponsorCategory get category;
  @override
  String? get description;
  @override
  String? get uuid;

  /// Create a copy of SponsorSegment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SponsorSegmentImplCopyWith<_$SponsorSegmentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
