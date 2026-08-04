// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$Account {
  String get channelId => throw _privateConstructorUsedError;
  String get channelTitle => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;
  String? get accessToken => throw _privateConstructorUsedError;
  String? get refreshToken => throw _privateConstructorUsedError;
  DateTime? get tokenExpiresAt => throw _privateConstructorUsedError;

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AccountCopyWith<Account> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AccountCopyWith<$Res> {
  factory $AccountCopyWith(Account value, $Res Function(Account) then) =
      _$AccountCopyWithImpl<$Res, Account>;
  @useResult
  $Res call(
      {String channelId,
      String channelTitle,
      String? email,
      String? avatarUrl,
      String? accessToken,
      String? refreshToken,
      DateTime? tokenExpiresAt});
}

/// @nodoc
class _$AccountCopyWithImpl<$Res, $Val extends Account>
    implements $AccountCopyWith<$Res> {
  _$AccountCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? channelId = null,
    Object? channelTitle = null,
    Object? email = freezed,
    Object? avatarUrl = freezed,
    Object? accessToken = freezed,
    Object? refreshToken = freezed,
    Object? tokenExpiresAt = freezed,
  }) {
    return _then(_value.copyWith(
      channelId: null == channelId
          ? _value.channelId
          : channelId // ignore: cast_nullable_to_non_nullable
              as String,
      channelTitle: null == channelTitle
          ? _value.channelTitle
          : channelTitle // ignore: cast_nullable_to_non_nullable
              as String,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      accessToken: freezed == accessToken
          ? _value.accessToken
          : accessToken // ignore: cast_nullable_to_non_nullable
              as String?,
      refreshToken: freezed == refreshToken
          ? _value.refreshToken
          : refreshToken // ignore: cast_nullable_to_non_nullable
              as String?,
      tokenExpiresAt: freezed == tokenExpiresAt
          ? _value.tokenExpiresAt
          : tokenExpiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AccountImplCopyWith<$Res> implements $AccountCopyWith<$Res> {
  factory _$$AccountImplCopyWith(
          _$AccountImpl value, $Res Function(_$AccountImpl) then) =
      __$$AccountImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String channelId,
      String channelTitle,
      String? email,
      String? avatarUrl,
      String? accessToken,
      String? refreshToken,
      DateTime? tokenExpiresAt});
}

/// @nodoc
class __$$AccountImplCopyWithImpl<$Res>
    extends _$AccountCopyWithImpl<$Res, _$AccountImpl>
    implements _$$AccountImplCopyWith<$Res> {
  __$$AccountImplCopyWithImpl(
      _$AccountImpl _value, $Res Function(_$AccountImpl) _then)
      : super(_value, _then);

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? channelId = null,
    Object? channelTitle = null,
    Object? email = freezed,
    Object? avatarUrl = freezed,
    Object? accessToken = freezed,
    Object? refreshToken = freezed,
    Object? tokenExpiresAt = freezed,
  }) {
    return _then(_$AccountImpl(
      channelId: null == channelId
          ? _value.channelId
          : channelId // ignore: cast_nullable_to_non_nullable
              as String,
      channelTitle: null == channelTitle
          ? _value.channelTitle
          : channelTitle // ignore: cast_nullable_to_non_nullable
              as String,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      accessToken: freezed == accessToken
          ? _value.accessToken
          : accessToken // ignore: cast_nullable_to_non_nullable
              as String?,
      refreshToken: freezed == refreshToken
          ? _value.refreshToken
          : refreshToken // ignore: cast_nullable_to_non_nullable
              as String?,
      tokenExpiresAt: freezed == tokenExpiresAt
          ? _value.tokenExpiresAt
          : tokenExpiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc

class _$AccountImpl extends _Account {
  const _$AccountImpl(
      {required this.channelId,
      required this.channelTitle,
      this.email,
      this.avatarUrl,
      this.accessToken,
      this.refreshToken,
      this.tokenExpiresAt})
      : super._();

  @override
  final String channelId;
  @override
  final String channelTitle;
  @override
  final String? email;
  @override
  final String? avatarUrl;
  @override
  final String? accessToken;
  @override
  final String? refreshToken;
  @override
  final DateTime? tokenExpiresAt;

  @override
  String toString() {
    return 'Account(channelId: $channelId, channelTitle: $channelTitle, email: $email, avatarUrl: $avatarUrl, accessToken: $accessToken, refreshToken: $refreshToken, tokenExpiresAt: $tokenExpiresAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AccountImpl &&
            (identical(other.channelId, channelId) ||
                other.channelId == channelId) &&
            (identical(other.channelTitle, channelTitle) ||
                other.channelTitle == channelTitle) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.accessToken, accessToken) ||
                other.accessToken == accessToken) &&
            (identical(other.refreshToken, refreshToken) ||
                other.refreshToken == refreshToken) &&
            (identical(other.tokenExpiresAt, tokenExpiresAt) ||
                other.tokenExpiresAt == tokenExpiresAt));
  }

  @override
  int get hashCode => Object.hash(runtimeType, channelId, channelTitle, email,
      avatarUrl, accessToken, refreshToken, tokenExpiresAt);

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AccountImplCopyWith<_$AccountImpl> get copyWith =>
      __$$AccountImplCopyWithImpl<_$AccountImpl>(this, _$identity);
}

abstract class _Account extends Account {
  const factory _Account(
      {required final String channelId,
      required final String channelTitle,
      final String? email,
      final String? avatarUrl,
      final String? accessToken,
      final String? refreshToken,
      final DateTime? tokenExpiresAt}) = _$AccountImpl;
  const _Account._() : super._();

  @override
  String get channelId;
  @override
  String get channelTitle;
  @override
  String? get email;
  @override
  String? get avatarUrl;
  @override
  String? get accessToken;
  @override
  String? get refreshToken;
  @override
  DateTime? get tokenExpiresAt;

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AccountImplCopyWith<_$AccountImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
