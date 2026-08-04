// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_options.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$SearchOptions {
  String get query => throw _privateConstructorUsedError;
  SearchSortBy get sortBy => throw _privateConstructorUsedError;
  SearchDuration get duration => throw _privateConstructorUsedError;
  SearchUploadDate get uploadDate => throw _privateConstructorUsedError;
  SearchType get type => throw _privateConstructorUsedError;

  /// Create a copy of SearchOptions
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SearchOptionsCopyWith<SearchOptions> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SearchOptionsCopyWith<$Res> {
  factory $SearchOptionsCopyWith(
          SearchOptions value, $Res Function(SearchOptions) then) =
      _$SearchOptionsCopyWithImpl<$Res, SearchOptions>;
  @useResult
  $Res call(
      {String query,
      SearchSortBy sortBy,
      SearchDuration duration,
      SearchUploadDate uploadDate,
      SearchType type});
}

/// @nodoc
class _$SearchOptionsCopyWithImpl<$Res, $Val extends SearchOptions>
    implements $SearchOptionsCopyWith<$Res> {
  _$SearchOptionsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SearchOptions
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? query = null,
    Object? sortBy = null,
    Object? duration = null,
    Object? uploadDate = null,
    Object? type = null,
  }) {
    return _then(_value.copyWith(
      query: null == query
          ? _value.query
          : query // ignore: cast_nullable_to_non_nullable
              as String,
      sortBy: null == sortBy
          ? _value.sortBy
          : sortBy // ignore: cast_nullable_to_non_nullable
              as SearchSortBy,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as SearchDuration,
      uploadDate: null == uploadDate
          ? _value.uploadDate
          : uploadDate // ignore: cast_nullable_to_non_nullable
              as SearchUploadDate,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SearchType,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SearchOptionsImplCopyWith<$Res>
    implements $SearchOptionsCopyWith<$Res> {
  factory _$$SearchOptionsImplCopyWith(
          _$SearchOptionsImpl value, $Res Function(_$SearchOptionsImpl) then) =
      __$$SearchOptionsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String query,
      SearchSortBy sortBy,
      SearchDuration duration,
      SearchUploadDate uploadDate,
      SearchType type});
}

/// @nodoc
class __$$SearchOptionsImplCopyWithImpl<$Res>
    extends _$SearchOptionsCopyWithImpl<$Res, _$SearchOptionsImpl>
    implements _$$SearchOptionsImplCopyWith<$Res> {
  __$$SearchOptionsImplCopyWithImpl(
      _$SearchOptionsImpl _value, $Res Function(_$SearchOptionsImpl) _then)
      : super(_value, _then);

  /// Create a copy of SearchOptions
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? query = null,
    Object? sortBy = null,
    Object? duration = null,
    Object? uploadDate = null,
    Object? type = null,
  }) {
    return _then(_$SearchOptionsImpl(
      query: null == query
          ? _value.query
          : query // ignore: cast_nullable_to_non_nullable
              as String,
      sortBy: null == sortBy
          ? _value.sortBy
          : sortBy // ignore: cast_nullable_to_non_nullable
              as SearchSortBy,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as SearchDuration,
      uploadDate: null == uploadDate
          ? _value.uploadDate
          : uploadDate // ignore: cast_nullable_to_non_nullable
              as SearchUploadDate,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SearchType,
    ));
  }
}

/// @nodoc

class _$SearchOptionsImpl implements _SearchOptions {
  const _$SearchOptionsImpl(
      {this.query = '',
      this.sortBy = SearchSortBy.relevance,
      this.duration = SearchDuration.any,
      this.uploadDate = SearchUploadDate.any,
      this.type = SearchType.any});

  @override
  @JsonKey()
  final String query;
  @override
  @JsonKey()
  final SearchSortBy sortBy;
  @override
  @JsonKey()
  final SearchDuration duration;
  @override
  @JsonKey()
  final SearchUploadDate uploadDate;
  @override
  @JsonKey()
  final SearchType type;

  @override
  String toString() {
    return 'SearchOptions(query: $query, sortBy: $sortBy, duration: $duration, uploadDate: $uploadDate, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SearchOptionsImpl &&
            (identical(other.query, query) || other.query == query) &&
            (identical(other.sortBy, sortBy) || other.sortBy == sortBy) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.uploadDate, uploadDate) ||
                other.uploadDate == uploadDate) &&
            (identical(other.type, type) || other.type == type));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, query, sortBy, duration, uploadDate, type);

  /// Create a copy of SearchOptions
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SearchOptionsImplCopyWith<_$SearchOptionsImpl> get copyWith =>
      __$$SearchOptionsImplCopyWithImpl<_$SearchOptionsImpl>(this, _$identity);
}

abstract class _SearchOptions implements SearchOptions {
  const factory _SearchOptions(
      {final String query,
      final SearchSortBy sortBy,
      final SearchDuration duration,
      final SearchUploadDate uploadDate,
      final SearchType type}) = _$SearchOptionsImpl;

  @override
  String get query;
  @override
  SearchSortBy get sortBy;
  @override
  SearchDuration get duration;
  @override
  SearchUploadDate get uploadDate;
  @override
  SearchType get type;

  /// Create a copy of SearchOptions
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SearchOptionsImplCopyWith<_$SearchOptionsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
