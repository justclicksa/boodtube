// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $WatchHistoryTableTable extends WatchHistoryTable
    with TableInfo<$WatchHistoryTableTable, WatchHistoryTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchHistoryTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _videoIdMeta =
      const VerificationMeta('videoId');
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
      'video_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
      'author', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _channelIdMeta =
      const VerificationMeta('channelId');
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
      'channel_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _thumbnailUrlMeta =
      const VerificationMeta('thumbnailUrl');
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
      'thumbnail_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _durationMsMeta =
      const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
      'duration_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _watchedAtMeta =
      const VerificationMeta('watchedAt');
  @override
  late final GeneratedColumn<DateTime> watchedAt = GeneratedColumn<DateTime>(
      'watched_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _positionMsMeta =
      const VerificationMeta('positionMs');
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
      'position_ms', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        videoId,
        title,
        author,
        channelId,
        thumbnailUrl,
        durationMs,
        watchedAt,
        positionMs
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watch_history';
  @override
  VerificationContext validateIntegrity(
      Insertable<WatchHistoryTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('video_id')) {
      context.handle(_videoIdMeta,
          videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta));
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(_authorMeta,
          author.isAcceptableOrUnknown(data['author']!, _authorMeta));
    } else if (isInserting) {
      context.missing(_authorMeta);
    }
    if (data.containsKey('channel_id')) {
      context.handle(_channelIdMeta,
          channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta));
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
          _thumbnailUrlMeta,
          thumbnailUrl.isAcceptableOrUnknown(
              data['thumbnail_url']!, _thumbnailUrlMeta));
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
          _durationMsMeta,
          durationMs.isAcceptableOrUnknown(
              data['duration_ms']!, _durationMsMeta));
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('watched_at')) {
      context.handle(_watchedAtMeta,
          watchedAt.isAcceptableOrUnknown(data['watched_at']!, _watchedAtMeta));
    } else if (isInserting) {
      context.missing(_watchedAtMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
          _positionMsMeta,
          positionMs.isAcceptableOrUnknown(
              data['position_ms']!, _positionMsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WatchHistoryTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchHistoryTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      videoId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}video_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      author: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author'])!,
      channelId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}channel_id'])!,
      thumbnailUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_url']),
      durationMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_ms'])!,
      watchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}watched_at'])!,
      positionMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position_ms'])!,
    );
  }

  @override
  $WatchHistoryTableTable createAlias(String alias) {
    return $WatchHistoryTableTable(attachedDatabase, alias);
  }
}

class WatchHistoryTableData extends DataClass
    implements Insertable<WatchHistoryTableData> {
  final int id;
  final String videoId;
  final String title;
  final String author;
  final String channelId;
  final String? thumbnailUrl;
  final int durationMs;
  final DateTime watchedAt;
  final int positionMs;
  const WatchHistoryTableData(
      {required this.id,
      required this.videoId,
      required this.title,
      required this.author,
      required this.channelId,
      this.thumbnailUrl,
      required this.durationMs,
      required this.watchedAt,
      required this.positionMs});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['video_id'] = Variable<String>(videoId);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    map['channel_id'] = Variable<String>(channelId);
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    map['duration_ms'] = Variable<int>(durationMs);
    map['watched_at'] = Variable<DateTime>(watchedAt);
    map['position_ms'] = Variable<int>(positionMs);
    return map;
  }

  WatchHistoryTableCompanion toCompanion(bool nullToAbsent) {
    return WatchHistoryTableCompanion(
      id: Value(id),
      videoId: Value(videoId),
      title: Value(title),
      author: Value(author),
      channelId: Value(channelId),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      durationMs: Value(durationMs),
      watchedAt: Value(watchedAt),
      positionMs: Value(positionMs),
    );
  }

  factory WatchHistoryTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchHistoryTableData(
      id: serializer.fromJson<int>(json['id']),
      videoId: serializer.fromJson<String>(json['videoId']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
      channelId: serializer.fromJson<String>(json['channelId']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      watchedAt: serializer.fromJson<DateTime>(json['watchedAt']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'videoId': serializer.toJson<String>(videoId),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'channelId': serializer.toJson<String>(channelId),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'durationMs': serializer.toJson<int>(durationMs),
      'watchedAt': serializer.toJson<DateTime>(watchedAt),
      'positionMs': serializer.toJson<int>(positionMs),
    };
  }

  WatchHistoryTableData copyWith(
          {int? id,
          String? videoId,
          String? title,
          String? author,
          String? channelId,
          Value<String?> thumbnailUrl = const Value.absent(),
          int? durationMs,
          DateTime? watchedAt,
          int? positionMs}) =>
      WatchHistoryTableData(
        id: id ?? this.id,
        videoId: videoId ?? this.videoId,
        title: title ?? this.title,
        author: author ?? this.author,
        channelId: channelId ?? this.channelId,
        thumbnailUrl:
            thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
        durationMs: durationMs ?? this.durationMs,
        watchedAt: watchedAt ?? this.watchedAt,
        positionMs: positionMs ?? this.positionMs,
      );
  WatchHistoryTableData copyWithCompanion(WatchHistoryTableCompanion data) {
    return WatchHistoryTableData(
      id: data.id.present ? data.id.value : this.id,
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      watchedAt: data.watchedAt.present ? data.watchedAt.value : this.watchedAt,
      positionMs:
          data.positionMs.present ? data.positionMs.value : this.positionMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchHistoryTableData(')
          ..write('id: $id, ')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('channelId: $channelId, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('durationMs: $durationMs, ')
          ..write('watchedAt: $watchedAt, ')
          ..write('positionMs: $positionMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, videoId, title, author, channelId,
      thumbnailUrl, durationMs, watchedAt, positionMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchHistoryTableData &&
          other.id == this.id &&
          other.videoId == this.videoId &&
          other.title == this.title &&
          other.author == this.author &&
          other.channelId == this.channelId &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.durationMs == this.durationMs &&
          other.watchedAt == this.watchedAt &&
          other.positionMs == this.positionMs);
}

class WatchHistoryTableCompanion
    extends UpdateCompanion<WatchHistoryTableData> {
  final Value<int> id;
  final Value<String> videoId;
  final Value<String> title;
  final Value<String> author;
  final Value<String> channelId;
  final Value<String?> thumbnailUrl;
  final Value<int> durationMs;
  final Value<DateTime> watchedAt;
  final Value<int> positionMs;
  const WatchHistoryTableCompanion({
    this.id = const Value.absent(),
    this.videoId = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.channelId = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.watchedAt = const Value.absent(),
    this.positionMs = const Value.absent(),
  });
  WatchHistoryTableCompanion.insert({
    this.id = const Value.absent(),
    required String videoId,
    required String title,
    required String author,
    required String channelId,
    this.thumbnailUrl = const Value.absent(),
    required int durationMs,
    required DateTime watchedAt,
    this.positionMs = const Value.absent(),
  })  : videoId = Value(videoId),
        title = Value(title),
        author = Value(author),
        channelId = Value(channelId),
        durationMs = Value(durationMs),
        watchedAt = Value(watchedAt);
  static Insertable<WatchHistoryTableData> custom({
    Expression<int>? id,
    Expression<String>? videoId,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? channelId,
    Expression<String>? thumbnailUrl,
    Expression<int>? durationMs,
    Expression<DateTime>? watchedAt,
    Expression<int>? positionMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (videoId != null) 'video_id': videoId,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (channelId != null) 'channel_id': channelId,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (durationMs != null) 'duration_ms': durationMs,
      if (watchedAt != null) 'watched_at': watchedAt,
      if (positionMs != null) 'position_ms': positionMs,
    });
  }

  WatchHistoryTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? videoId,
      Value<String>? title,
      Value<String>? author,
      Value<String>? channelId,
      Value<String?>? thumbnailUrl,
      Value<int>? durationMs,
      Value<DateTime>? watchedAt,
      Value<int>? positionMs}) {
    return WatchHistoryTableCompanion(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      author: author ?? this.author,
      channelId: channelId ?? this.channelId,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationMs: durationMs ?? this.durationMs,
      watchedAt: watchedAt ?? this.watchedAt,
      positionMs: positionMs ?? this.positionMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (watchedAt.present) {
      map['watched_at'] = Variable<DateTime>(watchedAt.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchHistoryTableCompanion(')
          ..write('id: $id, ')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('channelId: $channelId, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('durationMs: $durationMs, ')
          ..write('watchedAt: $watchedAt, ')
          ..write('positionMs: $positionMs')
          ..write(')'))
        .toString();
  }
}

class $LocalSubscriptionsTableTable extends LocalSubscriptionsTable
    with TableInfo<$LocalSubscriptionsTableTable, LocalSubscriptionsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSubscriptionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _channelIdMeta =
      const VerificationMeta('channelId');
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
      'channel_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _avatarUrlMeta =
      const VerificationMeta('avatarUrl');
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
      'avatar_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _subscriberCountMeta =
      const VerificationMeta('subscriberCount');
  @override
  late final GeneratedColumn<int> subscriberCount = GeneratedColumn<int>(
      'subscriber_count', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _subscribedAtMeta =
      const VerificationMeta('subscribedAt');
  @override
  late final GeneratedColumn<DateTime> subscribedAt = GeneratedColumn<DateTime>(
      'subscribed_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [channelId, title, avatarUrl, subscriberCount, subscribedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_subscriptions_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalSubscriptionsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('channel_id')) {
      context.handle(_channelIdMeta,
          channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta));
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('avatar_url')) {
      context.handle(_avatarUrlMeta,
          avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta));
    }
    if (data.containsKey('subscriber_count')) {
      context.handle(
          _subscriberCountMeta,
          subscriberCount.isAcceptableOrUnknown(
              data['subscriber_count']!, _subscriberCountMeta));
    }
    if (data.containsKey('subscribed_at')) {
      context.handle(
          _subscribedAtMeta,
          subscribedAt.isAcceptableOrUnknown(
              data['subscribed_at']!, _subscribedAtMeta));
    } else if (isInserting) {
      context.missing(_subscribedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {channelId};
  @override
  LocalSubscriptionsTableData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSubscriptionsTableData(
      channelId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}channel_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      avatarUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_url']),
      subscriberCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}subscriber_count']),
      subscribedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}subscribed_at'])!,
    );
  }

  @override
  $LocalSubscriptionsTableTable createAlias(String alias) {
    return $LocalSubscriptionsTableTable(attachedDatabase, alias);
  }
}

class LocalSubscriptionsTableData extends DataClass
    implements Insertable<LocalSubscriptionsTableData> {
  final String channelId;
  final String title;
  final String? avatarUrl;
  final int? subscriberCount;
  final DateTime subscribedAt;
  const LocalSubscriptionsTableData(
      {required this.channelId,
      required this.title,
      this.avatarUrl,
      this.subscriberCount,
      required this.subscribedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['channel_id'] = Variable<String>(channelId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    if (!nullToAbsent || subscriberCount != null) {
      map['subscriber_count'] = Variable<int>(subscriberCount);
    }
    map['subscribed_at'] = Variable<DateTime>(subscribedAt);
    return map;
  }

  LocalSubscriptionsTableCompanion toCompanion(bool nullToAbsent) {
    return LocalSubscriptionsTableCompanion(
      channelId: Value(channelId),
      title: Value(title),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
      subscriberCount: subscriberCount == null && nullToAbsent
          ? const Value.absent()
          : Value(subscriberCount),
      subscribedAt: Value(subscribedAt),
    );
  }

  factory LocalSubscriptionsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSubscriptionsTableData(
      channelId: serializer.fromJson<String>(json['channelId']),
      title: serializer.fromJson<String>(json['title']),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
      subscriberCount: serializer.fromJson<int?>(json['subscriberCount']),
      subscribedAt: serializer.fromJson<DateTime>(json['subscribedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'channelId': serializer.toJson<String>(channelId),
      'title': serializer.toJson<String>(title),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
      'subscriberCount': serializer.toJson<int?>(subscriberCount),
      'subscribedAt': serializer.toJson<DateTime>(subscribedAt),
    };
  }

  LocalSubscriptionsTableData copyWith(
          {String? channelId,
          String? title,
          Value<String?> avatarUrl = const Value.absent(),
          Value<int?> subscriberCount = const Value.absent(),
          DateTime? subscribedAt}) =>
      LocalSubscriptionsTableData(
        channelId: channelId ?? this.channelId,
        title: title ?? this.title,
        avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
        subscriberCount: subscriberCount.present
            ? subscriberCount.value
            : this.subscriberCount,
        subscribedAt: subscribedAt ?? this.subscribedAt,
      );
  LocalSubscriptionsTableData copyWithCompanion(
      LocalSubscriptionsTableCompanion data) {
    return LocalSubscriptionsTableData(
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      title: data.title.present ? data.title.value : this.title,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      subscriberCount: data.subscriberCount.present
          ? data.subscriberCount.value
          : this.subscriberCount,
      subscribedAt: data.subscribedAt.present
          ? data.subscribedAt.value
          : this.subscribedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSubscriptionsTableData(')
          ..write('channelId: $channelId, ')
          ..write('title: $title, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('subscriberCount: $subscriberCount, ')
          ..write('subscribedAt: $subscribedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(channelId, title, avatarUrl, subscriberCount, subscribedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSubscriptionsTableData &&
          other.channelId == this.channelId &&
          other.title == this.title &&
          other.avatarUrl == this.avatarUrl &&
          other.subscriberCount == this.subscriberCount &&
          other.subscribedAt == this.subscribedAt);
}

class LocalSubscriptionsTableCompanion
    extends UpdateCompanion<LocalSubscriptionsTableData> {
  final Value<String> channelId;
  final Value<String> title;
  final Value<String?> avatarUrl;
  final Value<int?> subscriberCount;
  final Value<DateTime> subscribedAt;
  final Value<int> rowid;
  const LocalSubscriptionsTableCompanion({
    this.channelId = const Value.absent(),
    this.title = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.subscriberCount = const Value.absent(),
    this.subscribedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSubscriptionsTableCompanion.insert({
    required String channelId,
    required String title,
    this.avatarUrl = const Value.absent(),
    this.subscriberCount = const Value.absent(),
    required DateTime subscribedAt,
    this.rowid = const Value.absent(),
  })  : channelId = Value(channelId),
        title = Value(title),
        subscribedAt = Value(subscribedAt);
  static Insertable<LocalSubscriptionsTableData> custom({
    Expression<String>? channelId,
    Expression<String>? title,
    Expression<String>? avatarUrl,
    Expression<int>? subscriberCount,
    Expression<DateTime>? subscribedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (channelId != null) 'channel_id': channelId,
      if (title != null) 'title': title,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (subscriberCount != null) 'subscriber_count': subscriberCount,
      if (subscribedAt != null) 'subscribed_at': subscribedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSubscriptionsTableCompanion copyWith(
      {Value<String>? channelId,
      Value<String>? title,
      Value<String?>? avatarUrl,
      Value<int?>? subscriberCount,
      Value<DateTime>? subscribedAt,
      Value<int>? rowid}) {
    return LocalSubscriptionsTableCompanion(
      channelId: channelId ?? this.channelId,
      title: title ?? this.title,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      subscribedAt: subscribedAt ?? this.subscribedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (subscriberCount.present) {
      map['subscriber_count'] = Variable<int>(subscriberCount.value);
    }
    if (subscribedAt.present) {
      map['subscribed_at'] = Variable<DateTime>(subscribedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSubscriptionsTableCompanion(')
          ..write('channelId: $channelId, ')
          ..write('title: $title, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('subscriberCount: $subscriberCount, ')
          ..write('subscribedAt: $subscribedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoritesTableTable extends FavoritesTable
    with TableInfo<$FavoritesTableTable, FavoritesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _videoIdMeta =
      const VerificationMeta('videoId');
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
      'video_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
      'author', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _channelIdMeta =
      const VerificationMeta('channelId');
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
      'channel_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _thumbnailUrlMeta =
      const VerificationMeta('thumbnailUrl');
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
      'thumbnail_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _durationMsMeta =
      const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
      'duration_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _addedAtMeta =
      const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
      'added_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [videoId, title, author, channelId, thumbnailUrl, durationMs, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites_table';
  @override
  VerificationContext validateIntegrity(Insertable<FavoritesTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('video_id')) {
      context.handle(_videoIdMeta,
          videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta));
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(_authorMeta,
          author.isAcceptableOrUnknown(data['author']!, _authorMeta));
    } else if (isInserting) {
      context.missing(_authorMeta);
    }
    if (data.containsKey('channel_id')) {
      context.handle(_channelIdMeta,
          channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta));
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
          _thumbnailUrlMeta,
          thumbnailUrl.isAcceptableOrUnknown(
              data['thumbnail_url']!, _thumbnailUrlMeta));
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
          _durationMsMeta,
          durationMs.isAcceptableOrUnknown(
              data['duration_ms']!, _durationMsMeta));
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta,
          addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {videoId};
  @override
  FavoritesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoritesTableData(
      videoId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}video_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      author: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author'])!,
      channelId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}channel_id'])!,
      thumbnailUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_url']),
      durationMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_ms'])!,
      addedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}added_at'])!,
    );
  }

  @override
  $FavoritesTableTable createAlias(String alias) {
    return $FavoritesTableTable(attachedDatabase, alias);
  }
}

class FavoritesTableData extends DataClass
    implements Insertable<FavoritesTableData> {
  final String videoId;
  final String title;
  final String author;
  final String channelId;
  final String? thumbnailUrl;
  final int durationMs;
  final DateTime addedAt;
  const FavoritesTableData(
      {required this.videoId,
      required this.title,
      required this.author,
      required this.channelId,
      this.thumbnailUrl,
      required this.durationMs,
      required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['video_id'] = Variable<String>(videoId);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    map['channel_id'] = Variable<String>(channelId);
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    map['duration_ms'] = Variable<int>(durationMs);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  FavoritesTableCompanion toCompanion(bool nullToAbsent) {
    return FavoritesTableCompanion(
      videoId: Value(videoId),
      title: Value(title),
      author: Value(author),
      channelId: Value(channelId),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      durationMs: Value(durationMs),
      addedAt: Value(addedAt),
    );
  }

  factory FavoritesTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoritesTableData(
      videoId: serializer.fromJson<String>(json['videoId']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
      channelId: serializer.fromJson<String>(json['channelId']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'videoId': serializer.toJson<String>(videoId),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'channelId': serializer.toJson<String>(channelId),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'durationMs': serializer.toJson<int>(durationMs),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  FavoritesTableData copyWith(
          {String? videoId,
          String? title,
          String? author,
          String? channelId,
          Value<String?> thumbnailUrl = const Value.absent(),
          int? durationMs,
          DateTime? addedAt}) =>
      FavoritesTableData(
        videoId: videoId ?? this.videoId,
        title: title ?? this.title,
        author: author ?? this.author,
        channelId: channelId ?? this.channelId,
        thumbnailUrl:
            thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
        durationMs: durationMs ?? this.durationMs,
        addedAt: addedAt ?? this.addedAt,
      );
  FavoritesTableData copyWithCompanion(FavoritesTableCompanion data) {
    return FavoritesTableData(
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesTableData(')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('channelId: $channelId, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('durationMs: $durationMs, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      videoId, title, author, channelId, thumbnailUrl, durationMs, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoritesTableData &&
          other.videoId == this.videoId &&
          other.title == this.title &&
          other.author == this.author &&
          other.channelId == this.channelId &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.durationMs == this.durationMs &&
          other.addedAt == this.addedAt);
}

class FavoritesTableCompanion extends UpdateCompanion<FavoritesTableData> {
  final Value<String> videoId;
  final Value<String> title;
  final Value<String> author;
  final Value<String> channelId;
  final Value<String?> thumbnailUrl;
  final Value<int> durationMs;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const FavoritesTableCompanion({
    this.videoId = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.channelId = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoritesTableCompanion.insert({
    required String videoId,
    required String title,
    required String author,
    required String channelId,
    this.thumbnailUrl = const Value.absent(),
    required int durationMs,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  })  : videoId = Value(videoId),
        title = Value(title),
        author = Value(author),
        channelId = Value(channelId),
        durationMs = Value(durationMs),
        addedAt = Value(addedAt);
  static Insertable<FavoritesTableData> custom({
    Expression<String>? videoId,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? channelId,
    Expression<String>? thumbnailUrl,
    Expression<int>? durationMs,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (videoId != null) 'video_id': videoId,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (channelId != null) 'channel_id': channelId,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (durationMs != null) 'duration_ms': durationMs,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoritesTableCompanion copyWith(
      {Value<String>? videoId,
      Value<String>? title,
      Value<String>? author,
      Value<String>? channelId,
      Value<String?>? thumbnailUrl,
      Value<int>? durationMs,
      Value<DateTime>? addedAt,
      Value<int>? rowid}) {
    return FavoritesTableCompanion(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      author: author ?? this.author,
      channelId: channelId ?? this.channelId,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationMs: durationMs ?? this.durationMs,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesTableCompanion(')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('channelId: $channelId, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('durationMs: $durationMs, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchLaterTableTable extends WatchLaterTable
    with TableInfo<$WatchLaterTableTable, WatchLaterTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchLaterTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _videoIdMeta =
      const VerificationMeta('videoId');
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
      'video_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
      'author', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _channelIdMeta =
      const VerificationMeta('channelId');
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
      'channel_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _thumbnailUrlMeta =
      const VerificationMeta('thumbnailUrl');
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
      'thumbnail_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _durationMsMeta =
      const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
      'duration_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _addedAtMeta =
      const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
      'added_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [videoId, title, author, channelId, thumbnailUrl, durationMs, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watch_later_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<WatchLaterTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('video_id')) {
      context.handle(_videoIdMeta,
          videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta));
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(_authorMeta,
          author.isAcceptableOrUnknown(data['author']!, _authorMeta));
    } else if (isInserting) {
      context.missing(_authorMeta);
    }
    if (data.containsKey('channel_id')) {
      context.handle(_channelIdMeta,
          channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta));
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
          _thumbnailUrlMeta,
          thumbnailUrl.isAcceptableOrUnknown(
              data['thumbnail_url']!, _thumbnailUrlMeta));
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
          _durationMsMeta,
          durationMs.isAcceptableOrUnknown(
              data['duration_ms']!, _durationMsMeta));
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta,
          addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {videoId};
  @override
  WatchLaterTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchLaterTableData(
      videoId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}video_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      author: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author'])!,
      channelId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}channel_id'])!,
      thumbnailUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_url']),
      durationMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_ms'])!,
      addedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}added_at'])!,
    );
  }

  @override
  $WatchLaterTableTable createAlias(String alias) {
    return $WatchLaterTableTable(attachedDatabase, alias);
  }
}

class WatchLaterTableData extends DataClass
    implements Insertable<WatchLaterTableData> {
  final String videoId;
  final String title;
  final String author;
  final String channelId;
  final String? thumbnailUrl;
  final int durationMs;
  final DateTime addedAt;
  const WatchLaterTableData(
      {required this.videoId,
      required this.title,
      required this.author,
      required this.channelId,
      this.thumbnailUrl,
      required this.durationMs,
      required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['video_id'] = Variable<String>(videoId);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    map['channel_id'] = Variable<String>(channelId);
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    map['duration_ms'] = Variable<int>(durationMs);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  WatchLaterTableCompanion toCompanion(bool nullToAbsent) {
    return WatchLaterTableCompanion(
      videoId: Value(videoId),
      title: Value(title),
      author: Value(author),
      channelId: Value(channelId),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      durationMs: Value(durationMs),
      addedAt: Value(addedAt),
    );
  }

  factory WatchLaterTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchLaterTableData(
      videoId: serializer.fromJson<String>(json['videoId']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
      channelId: serializer.fromJson<String>(json['channelId']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'videoId': serializer.toJson<String>(videoId),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'channelId': serializer.toJson<String>(channelId),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'durationMs': serializer.toJson<int>(durationMs),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  WatchLaterTableData copyWith(
          {String? videoId,
          String? title,
          String? author,
          String? channelId,
          Value<String?> thumbnailUrl = const Value.absent(),
          int? durationMs,
          DateTime? addedAt}) =>
      WatchLaterTableData(
        videoId: videoId ?? this.videoId,
        title: title ?? this.title,
        author: author ?? this.author,
        channelId: channelId ?? this.channelId,
        thumbnailUrl:
            thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
        durationMs: durationMs ?? this.durationMs,
        addedAt: addedAt ?? this.addedAt,
      );
  WatchLaterTableData copyWithCompanion(WatchLaterTableCompanion data) {
    return WatchLaterTableData(
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchLaterTableData(')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('channelId: $channelId, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('durationMs: $durationMs, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      videoId, title, author, channelId, thumbnailUrl, durationMs, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchLaterTableData &&
          other.videoId == this.videoId &&
          other.title == this.title &&
          other.author == this.author &&
          other.channelId == this.channelId &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.durationMs == this.durationMs &&
          other.addedAt == this.addedAt);
}

class WatchLaterTableCompanion extends UpdateCompanion<WatchLaterTableData> {
  final Value<String> videoId;
  final Value<String> title;
  final Value<String> author;
  final Value<String> channelId;
  final Value<String?> thumbnailUrl;
  final Value<int> durationMs;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const WatchLaterTableCompanion({
    this.videoId = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.channelId = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchLaterTableCompanion.insert({
    required String videoId,
    required String title,
    required String author,
    required String channelId,
    this.thumbnailUrl = const Value.absent(),
    required int durationMs,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  })  : videoId = Value(videoId),
        title = Value(title),
        author = Value(author),
        channelId = Value(channelId),
        durationMs = Value(durationMs),
        addedAt = Value(addedAt);
  static Insertable<WatchLaterTableData> custom({
    Expression<String>? videoId,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? channelId,
    Expression<String>? thumbnailUrl,
    Expression<int>? durationMs,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (videoId != null) 'video_id': videoId,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (channelId != null) 'channel_id': channelId,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (durationMs != null) 'duration_ms': durationMs,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchLaterTableCompanion copyWith(
      {Value<String>? videoId,
      Value<String>? title,
      Value<String>? author,
      Value<String>? channelId,
      Value<String?>? thumbnailUrl,
      Value<int>? durationMs,
      Value<DateTime>? addedAt,
      Value<int>? rowid}) {
    return WatchLaterTableCompanion(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      author: author ?? this.author,
      channelId: channelId ?? this.channelId,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationMs: durationMs ?? this.durationMs,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchLaterTableCompanion(')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('channelId: $channelId, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('durationMs: $durationMs, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlayPositionsTableTable extends PlayPositionsTable
    with TableInfo<$PlayPositionsTableTable, PlayPositionsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayPositionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _videoIdMeta =
      const VerificationMeta('videoId');
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
      'video_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _positionMsMeta =
      const VerificationMeta('positionMs');
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
      'position_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [videoId, positionMs, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_positions_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<PlayPositionsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('video_id')) {
      context.handle(_videoIdMeta,
          videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta));
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
          _positionMsMeta,
          positionMs.isAcceptableOrUnknown(
              data['position_ms']!, _positionMsMeta));
    } else if (isInserting) {
      context.missing(_positionMsMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {videoId};
  @override
  PlayPositionsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayPositionsTableData(
      videoId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}video_id'])!,
      positionMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position_ms'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PlayPositionsTableTable createAlias(String alias) {
    return $PlayPositionsTableTable(attachedDatabase, alias);
  }
}

class PlayPositionsTableData extends DataClass
    implements Insertable<PlayPositionsTableData> {
  final String videoId;
  final int positionMs;
  final DateTime updatedAt;
  const PlayPositionsTableData(
      {required this.videoId,
      required this.positionMs,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['video_id'] = Variable<String>(videoId);
    map['position_ms'] = Variable<int>(positionMs);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlayPositionsTableCompanion toCompanion(bool nullToAbsent) {
    return PlayPositionsTableCompanion(
      videoId: Value(videoId),
      positionMs: Value(positionMs),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlayPositionsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayPositionsTableData(
      videoId: serializer.fromJson<String>(json['videoId']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'videoId': serializer.toJson<String>(videoId),
      'positionMs': serializer.toJson<int>(positionMs),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PlayPositionsTableData copyWith(
          {String? videoId, int? positionMs, DateTime? updatedAt}) =>
      PlayPositionsTableData(
        videoId: videoId ?? this.videoId,
        positionMs: positionMs ?? this.positionMs,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PlayPositionsTableData copyWithCompanion(PlayPositionsTableCompanion data) {
    return PlayPositionsTableData(
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      positionMs:
          data.positionMs.present ? data.positionMs.value : this.positionMs,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayPositionsTableData(')
          ..write('videoId: $videoId, ')
          ..write('positionMs: $positionMs, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(videoId, positionMs, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayPositionsTableData &&
          other.videoId == this.videoId &&
          other.positionMs == this.positionMs &&
          other.updatedAt == this.updatedAt);
}

class PlayPositionsTableCompanion
    extends UpdateCompanion<PlayPositionsTableData> {
  final Value<String> videoId;
  final Value<int> positionMs;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PlayPositionsTableCompanion({
    this.videoId = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlayPositionsTableCompanion.insert({
    required String videoId,
    required int positionMs,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : videoId = Value(videoId),
        positionMs = Value(positionMs),
        updatedAt = Value(updatedAt);
  static Insertable<PlayPositionsTableData> custom({
    Expression<String>? videoId,
    Expression<int>? positionMs,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (videoId != null) 'video_id': videoId,
      if (positionMs != null) 'position_ms': positionMs,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlayPositionsTableCompanion copyWith(
      {Value<String>? videoId,
      Value<int>? positionMs,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return PlayPositionsTableCompanion(
      videoId: videoId ?? this.videoId,
      positionMs: positionMs ?? this.positionMs,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayPositionsTableCompanion(')
          ..write('videoId: $videoId, ')
          ..write('positionMs: $positionMs, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadsTableTable extends DownloadsTable
    with TableInfo<$DownloadsTableTable, DownloadTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _videoIdMeta =
      const VerificationMeta('videoId');
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
      'video_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
      'author', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _channelIdMeta =
      const VerificationMeta('channelId');
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
      'channel_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _thumbnailUrlMeta =
      const VerificationMeta('thumbnailUrl');
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
      'thumbnail_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _durationMsMeta =
      const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
      'duration_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _videoPathMeta =
      const VerificationMeta('videoPath');
  @override
  late final GeneratedColumn<String> videoPath = GeneratedColumn<String>(
      'video_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _audioPathMeta =
      const VerificationMeta('audioPath');
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
      'audio_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _qualityLabelMeta =
      const VerificationMeta('qualityLabel');
  @override
  late final GeneratedColumn<String> qualityLabel = GeneratedColumn<String>(
      'quality_label', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _totalBytesMeta =
      const VerificationMeta('totalBytes');
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
      'total_bytes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _downloadedAtMeta =
      const VerificationMeta('downloadedAt');
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
      'downloaded_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        videoId,
        title,
        author,
        channelId,
        thumbnailUrl,
        durationMs,
        videoPath,
        audioPath,
        qualityLabel,
        totalBytes,
        downloadedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloads_table';
  @override
  VerificationContext validateIntegrity(Insertable<DownloadTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('video_id')) {
      context.handle(_videoIdMeta,
          videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta));
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(_authorMeta,
          author.isAcceptableOrUnknown(data['author']!, _authorMeta));
    } else if (isInserting) {
      context.missing(_authorMeta);
    }
    if (data.containsKey('channel_id')) {
      context.handle(_channelIdMeta,
          channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta));
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
          _thumbnailUrlMeta,
          thumbnailUrl.isAcceptableOrUnknown(
              data['thumbnail_url']!, _thumbnailUrlMeta));
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
          _durationMsMeta,
          durationMs.isAcceptableOrUnknown(
              data['duration_ms']!, _durationMsMeta));
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('video_path')) {
      context.handle(_videoPathMeta,
          videoPath.isAcceptableOrUnknown(data['video_path']!, _videoPathMeta));
    } else if (isInserting) {
      context.missing(_videoPathMeta);
    }
    if (data.containsKey('audio_path')) {
      context.handle(_audioPathMeta,
          audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta));
    }
    if (data.containsKey('quality_label')) {
      context.handle(
          _qualityLabelMeta,
          qualityLabel.isAcceptableOrUnknown(
              data['quality_label']!, _qualityLabelMeta));
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
          _totalBytesMeta,
          totalBytes.isAcceptableOrUnknown(
              data['total_bytes']!, _totalBytesMeta));
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
          _downloadedAtMeta,
          downloadedAt.isAcceptableOrUnknown(
              data['downloaded_at']!, _downloadedAtMeta));
    } else if (isInserting) {
      context.missing(_downloadedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {videoId};
  @override
  DownloadTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadTableData(
      videoId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}video_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      author: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author'])!,
      channelId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}channel_id'])!,
      thumbnailUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_url']),
      durationMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_ms'])!,
      videoPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}video_path'])!,
      audioPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audio_path']),
      qualityLabel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}quality_label']),
      totalBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_bytes'])!,
      downloadedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}downloaded_at'])!,
    );
  }

  @override
  $DownloadsTableTable createAlias(String alias) {
    return $DownloadsTableTable(attachedDatabase, alias);
  }
}

class DownloadTableData extends DataClass
    implements Insertable<DownloadTableData> {
  final String videoId;
  final String title;
  final String author;
  final String channelId;
  final String? thumbnailUrl;
  final int durationMs;
  final String videoPath;
  final String? audioPath;
  final String? qualityLabel;
  final int totalBytes;
  final DateTime downloadedAt;
  const DownloadTableData(
      {required this.videoId,
      required this.title,
      required this.author,
      required this.channelId,
      this.thumbnailUrl,
      required this.durationMs,
      required this.videoPath,
      this.audioPath,
      this.qualityLabel,
      required this.totalBytes,
      required this.downloadedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['video_id'] = Variable<String>(videoId);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    map['channel_id'] = Variable<String>(channelId);
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    map['duration_ms'] = Variable<int>(durationMs);
    map['video_path'] = Variable<String>(videoPath);
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    if (!nullToAbsent || qualityLabel != null) {
      map['quality_label'] = Variable<String>(qualityLabel);
    }
    map['total_bytes'] = Variable<int>(totalBytes);
    map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    return map;
  }

  DownloadsTableCompanion toCompanion(bool nullToAbsent) {
    return DownloadsTableCompanion(
      videoId: Value(videoId),
      title: Value(title),
      author: Value(author),
      channelId: Value(channelId),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      durationMs: Value(durationMs),
      videoPath: Value(videoPath),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
      qualityLabel: qualityLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(qualityLabel),
      totalBytes: Value(totalBytes),
      downloadedAt: Value(downloadedAt),
    );
  }

  factory DownloadTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadTableData(
      videoId: serializer.fromJson<String>(json['videoId']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
      channelId: serializer.fromJson<String>(json['channelId']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      videoPath: serializer.fromJson<String>(json['videoPath']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
      qualityLabel: serializer.fromJson<String?>(json['qualityLabel']),
      totalBytes: serializer.fromJson<int>(json['totalBytes']),
      downloadedAt: serializer.fromJson<DateTime>(json['downloadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'videoId': serializer.toJson<String>(videoId),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'channelId': serializer.toJson<String>(channelId),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'durationMs': serializer.toJson<int>(durationMs),
      'videoPath': serializer.toJson<String>(videoPath),
      'audioPath': serializer.toJson<String?>(audioPath),
      'qualityLabel': serializer.toJson<String?>(qualityLabel),
      'totalBytes': serializer.toJson<int>(totalBytes),
      'downloadedAt': serializer.toJson<DateTime>(downloadedAt),
    };
  }

  DownloadTableData copyWith(
          {String? videoId,
          String? title,
          String? author,
          String? channelId,
          Value<String?> thumbnailUrl = const Value.absent(),
          int? durationMs,
          String? videoPath,
          Value<String?> audioPath = const Value.absent(),
          Value<String?> qualityLabel = const Value.absent(),
          int? totalBytes,
          DateTime? downloadedAt}) =>
      DownloadTableData(
        videoId: videoId ?? this.videoId,
        title: title ?? this.title,
        author: author ?? this.author,
        channelId: channelId ?? this.channelId,
        thumbnailUrl:
            thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
        durationMs: durationMs ?? this.durationMs,
        videoPath: videoPath ?? this.videoPath,
        audioPath: audioPath.present ? audioPath.value : this.audioPath,
        qualityLabel:
            qualityLabel.present ? qualityLabel.value : this.qualityLabel,
        totalBytes: totalBytes ?? this.totalBytes,
        downloadedAt: downloadedAt ?? this.downloadedAt,
      );
  DownloadTableData copyWithCompanion(DownloadsTableCompanion data) {
    return DownloadTableData(
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      videoPath: data.videoPath.present ? data.videoPath.value : this.videoPath,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      qualityLabel: data.qualityLabel.present
          ? data.qualityLabel.value
          : this.qualityLabel,
      totalBytes:
          data.totalBytes.present ? data.totalBytes.value : this.totalBytes,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTableData(')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('channelId: $channelId, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('durationMs: $durationMs, ')
          ..write('videoPath: $videoPath, ')
          ..write('audioPath: $audioPath, ')
          ..write('qualityLabel: $qualityLabel, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      videoId,
      title,
      author,
      channelId,
      thumbnailUrl,
      durationMs,
      videoPath,
      audioPath,
      qualityLabel,
      totalBytes,
      downloadedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadTableData &&
          other.videoId == this.videoId &&
          other.title == this.title &&
          other.author == this.author &&
          other.channelId == this.channelId &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.durationMs == this.durationMs &&
          other.videoPath == this.videoPath &&
          other.audioPath == this.audioPath &&
          other.qualityLabel == this.qualityLabel &&
          other.totalBytes == this.totalBytes &&
          other.downloadedAt == this.downloadedAt);
}

class DownloadsTableCompanion extends UpdateCompanion<DownloadTableData> {
  final Value<String> videoId;
  final Value<String> title;
  final Value<String> author;
  final Value<String> channelId;
  final Value<String?> thumbnailUrl;
  final Value<int> durationMs;
  final Value<String> videoPath;
  final Value<String?> audioPath;
  final Value<String?> qualityLabel;
  final Value<int> totalBytes;
  final Value<DateTime> downloadedAt;
  final Value<int> rowid;
  const DownloadsTableCompanion({
    this.videoId = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.channelId = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.videoPath = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.qualityLabel = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadsTableCompanion.insert({
    required String videoId,
    required String title,
    required String author,
    required String channelId,
    this.thumbnailUrl = const Value.absent(),
    required int durationMs,
    required String videoPath,
    this.audioPath = const Value.absent(),
    this.qualityLabel = const Value.absent(),
    this.totalBytes = const Value.absent(),
    required DateTime downloadedAt,
    this.rowid = const Value.absent(),
  })  : videoId = Value(videoId),
        title = Value(title),
        author = Value(author),
        channelId = Value(channelId),
        durationMs = Value(durationMs),
        videoPath = Value(videoPath),
        downloadedAt = Value(downloadedAt);
  static Insertable<DownloadTableData> custom({
    Expression<String>? videoId,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? channelId,
    Expression<String>? thumbnailUrl,
    Expression<int>? durationMs,
    Expression<String>? videoPath,
    Expression<String>? audioPath,
    Expression<String>? qualityLabel,
    Expression<int>? totalBytes,
    Expression<DateTime>? downloadedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (videoId != null) 'video_id': videoId,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (channelId != null) 'channel_id': channelId,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (durationMs != null) 'duration_ms': durationMs,
      if (videoPath != null) 'video_path': videoPath,
      if (audioPath != null) 'audio_path': audioPath,
      if (qualityLabel != null) 'quality_label': qualityLabel,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadsTableCompanion copyWith(
      {Value<String>? videoId,
      Value<String>? title,
      Value<String>? author,
      Value<String>? channelId,
      Value<String?>? thumbnailUrl,
      Value<int>? durationMs,
      Value<String>? videoPath,
      Value<String?>? audioPath,
      Value<String?>? qualityLabel,
      Value<int>? totalBytes,
      Value<DateTime>? downloadedAt,
      Value<int>? rowid}) {
    return DownloadsTableCompanion(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      author: author ?? this.author,
      channelId: channelId ?? this.channelId,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationMs: durationMs ?? this.durationMs,
      videoPath: videoPath ?? this.videoPath,
      audioPath: audioPath ?? this.audioPath,
      qualityLabel: qualityLabel ?? this.qualityLabel,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (videoPath.present) {
      map['video_path'] = Variable<String>(videoPath.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (qualityLabel.present) {
      map['quality_label'] = Variable<String>(qualityLabel.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadsTableCompanion(')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('channelId: $channelId, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('durationMs: $durationMs, ')
          ..write('videoPath: $videoPath, ')
          ..write('audioPath: $audioPath, ')
          ..write('qualityLabel: $qualityLabel, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WatchHistoryTableTable watchHistoryTable =
      $WatchHistoryTableTable(this);
  late final $LocalSubscriptionsTableTable localSubscriptionsTable =
      $LocalSubscriptionsTableTable(this);
  late final $FavoritesTableTable favoritesTable = $FavoritesTableTable(this);
  late final $WatchLaterTableTable watchLaterTable =
      $WatchLaterTableTable(this);
  late final $PlayPositionsTableTable playPositionsTable =
      $PlayPositionsTableTable(this);
  late final $DownloadsTableTable downloadsTable = $DownloadsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        watchHistoryTable,
        localSubscriptionsTable,
        favoritesTable,
        watchLaterTable,
        playPositionsTable,
        downloadsTable
      ];
}

typedef $$WatchHistoryTableTableCreateCompanionBuilder
    = WatchHistoryTableCompanion Function({
  Value<int> id,
  required String videoId,
  required String title,
  required String author,
  required String channelId,
  Value<String?> thumbnailUrl,
  required int durationMs,
  required DateTime watchedAt,
  Value<int> positionMs,
});
typedef $$WatchHistoryTableTableUpdateCompanionBuilder
    = WatchHistoryTableCompanion Function({
  Value<int> id,
  Value<String> videoId,
  Value<String> title,
  Value<String> author,
  Value<String> channelId,
  Value<String?> thumbnailUrl,
  Value<int> durationMs,
  Value<DateTime> watchedAt,
  Value<int> positionMs,
});

class $$WatchHistoryTableTableFilterComposer
    extends Composer<_$AppDatabase, $WatchHistoryTableTable> {
  $$WatchHistoryTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get videoId => $composableBuilder(
      column: $table.videoId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get channelId => $composableBuilder(
      column: $table.channelId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get watchedAt => $composableBuilder(
      column: $table.watchedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get positionMs => $composableBuilder(
      column: $table.positionMs, builder: (column) => ColumnFilters(column));
}

class $$WatchHistoryTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchHistoryTableTable> {
  $$WatchHistoryTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get videoId => $composableBuilder(
      column: $table.videoId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get channelId => $composableBuilder(
      column: $table.channelId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get watchedAt => $composableBuilder(
      column: $table.watchedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get positionMs => $composableBuilder(
      column: $table.positionMs, builder: (column) => ColumnOrderings(column));
}

class $$WatchHistoryTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchHistoryTableTable> {
  $$WatchHistoryTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<DateTime> get watchedAt =>
      $composableBuilder(column: $table.watchedAt, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
      column: $table.positionMs, builder: (column) => column);
}

class $$WatchHistoryTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WatchHistoryTableTable,
    WatchHistoryTableData,
    $$WatchHistoryTableTableFilterComposer,
    $$WatchHistoryTableTableOrderingComposer,
    $$WatchHistoryTableTableAnnotationComposer,
    $$WatchHistoryTableTableCreateCompanionBuilder,
    $$WatchHistoryTableTableUpdateCompanionBuilder,
    (
      WatchHistoryTableData,
      BaseReferences<_$AppDatabase, $WatchHistoryTableTable,
          WatchHistoryTableData>
    ),
    WatchHistoryTableData,
    PrefetchHooks Function()> {
  $$WatchHistoryTableTableTableManager(
      _$AppDatabase db, $WatchHistoryTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchHistoryTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchHistoryTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchHistoryTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> videoId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> author = const Value.absent(),
            Value<String> channelId = const Value.absent(),
            Value<String?> thumbnailUrl = const Value.absent(),
            Value<int> durationMs = const Value.absent(),
            Value<DateTime> watchedAt = const Value.absent(),
            Value<int> positionMs = const Value.absent(),
          }) =>
              WatchHistoryTableCompanion(
            id: id,
            videoId: videoId,
            title: title,
            author: author,
            channelId: channelId,
            thumbnailUrl: thumbnailUrl,
            durationMs: durationMs,
            watchedAt: watchedAt,
            positionMs: positionMs,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String videoId,
            required String title,
            required String author,
            required String channelId,
            Value<String?> thumbnailUrl = const Value.absent(),
            required int durationMs,
            required DateTime watchedAt,
            Value<int> positionMs = const Value.absent(),
          }) =>
              WatchHistoryTableCompanion.insert(
            id: id,
            videoId: videoId,
            title: title,
            author: author,
            channelId: channelId,
            thumbnailUrl: thumbnailUrl,
            durationMs: durationMs,
            watchedAt: watchedAt,
            positionMs: positionMs,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WatchHistoryTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WatchHistoryTableTable,
    WatchHistoryTableData,
    $$WatchHistoryTableTableFilterComposer,
    $$WatchHistoryTableTableOrderingComposer,
    $$WatchHistoryTableTableAnnotationComposer,
    $$WatchHistoryTableTableCreateCompanionBuilder,
    $$WatchHistoryTableTableUpdateCompanionBuilder,
    (
      WatchHistoryTableData,
      BaseReferences<_$AppDatabase, $WatchHistoryTableTable,
          WatchHistoryTableData>
    ),
    WatchHistoryTableData,
    PrefetchHooks Function()>;
typedef $$LocalSubscriptionsTableTableCreateCompanionBuilder
    = LocalSubscriptionsTableCompanion Function({
  required String channelId,
  required String title,
  Value<String?> avatarUrl,
  Value<int?> subscriberCount,
  required DateTime subscribedAt,
  Value<int> rowid,
});
typedef $$LocalSubscriptionsTableTableUpdateCompanionBuilder
    = LocalSubscriptionsTableCompanion Function({
  Value<String> channelId,
  Value<String> title,
  Value<String?> avatarUrl,
  Value<int?> subscriberCount,
  Value<DateTime> subscribedAt,
  Value<int> rowid,
});

class $$LocalSubscriptionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSubscriptionsTableTable> {
  $$LocalSubscriptionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get channelId => $composableBuilder(
      column: $table.channelId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatarUrl => $composableBuilder(
      column: $table.avatarUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get subscriberCount => $composableBuilder(
      column: $table.subscriberCount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get subscribedAt => $composableBuilder(
      column: $table.subscribedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalSubscriptionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSubscriptionsTableTable> {
  $$LocalSubscriptionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get channelId => $composableBuilder(
      column: $table.channelId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
      column: $table.avatarUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get subscriberCount => $composableBuilder(
      column: $table.subscriberCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get subscribedAt => $composableBuilder(
      column: $table.subscribedAt,
      builder: (column) => ColumnOrderings(column));
}

class $$LocalSubscriptionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSubscriptionsTableTable> {
  $$LocalSubscriptionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<int> get subscriberCount => $composableBuilder(
      column: $table.subscriberCount, builder: (column) => column);

  GeneratedColumn<DateTime> get subscribedAt => $composableBuilder(
      column: $table.subscribedAt, builder: (column) => column);
}

class $$LocalSubscriptionsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalSubscriptionsTableTable,
    LocalSubscriptionsTableData,
    $$LocalSubscriptionsTableTableFilterComposer,
    $$LocalSubscriptionsTableTableOrderingComposer,
    $$LocalSubscriptionsTableTableAnnotationComposer,
    $$LocalSubscriptionsTableTableCreateCompanionBuilder,
    $$LocalSubscriptionsTableTableUpdateCompanionBuilder,
    (
      LocalSubscriptionsTableData,
      BaseReferences<_$AppDatabase, $LocalSubscriptionsTableTable,
          LocalSubscriptionsTableData>
    ),
    LocalSubscriptionsTableData,
    PrefetchHooks Function()> {
  $$LocalSubscriptionsTableTableTableManager(
      _$AppDatabase db, $LocalSubscriptionsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSubscriptionsTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSubscriptionsTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSubscriptionsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> channelId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> avatarUrl = const Value.absent(),
            Value<int?> subscriberCount = const Value.absent(),
            Value<DateTime> subscribedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalSubscriptionsTableCompanion(
            channelId: channelId,
            title: title,
            avatarUrl: avatarUrl,
            subscriberCount: subscriberCount,
            subscribedAt: subscribedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String channelId,
            required String title,
            Value<String?> avatarUrl = const Value.absent(),
            Value<int?> subscriberCount = const Value.absent(),
            required DateTime subscribedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalSubscriptionsTableCompanion.insert(
            channelId: channelId,
            title: title,
            avatarUrl: avatarUrl,
            subscriberCount: subscriberCount,
            subscribedAt: subscribedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalSubscriptionsTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $LocalSubscriptionsTableTable,
        LocalSubscriptionsTableData,
        $$LocalSubscriptionsTableTableFilterComposer,
        $$LocalSubscriptionsTableTableOrderingComposer,
        $$LocalSubscriptionsTableTableAnnotationComposer,
        $$LocalSubscriptionsTableTableCreateCompanionBuilder,
        $$LocalSubscriptionsTableTableUpdateCompanionBuilder,
        (
          LocalSubscriptionsTableData,
          BaseReferences<_$AppDatabase, $LocalSubscriptionsTableTable,
              LocalSubscriptionsTableData>
        ),
        LocalSubscriptionsTableData,
        PrefetchHooks Function()>;
typedef $$FavoritesTableTableCreateCompanionBuilder = FavoritesTableCompanion
    Function({
  required String videoId,
  required String title,
  required String author,
  required String channelId,
  Value<String?> thumbnailUrl,
  required int durationMs,
  required DateTime addedAt,
  Value<int> rowid,
});
typedef $$FavoritesTableTableUpdateCompanionBuilder = FavoritesTableCompanion
    Function({
  Value<String> videoId,
  Value<String> title,
  Value<String> author,
  Value<String> channelId,
  Value<String?> thumbnailUrl,
  Value<int> durationMs,
  Value<DateTime> addedAt,
  Value<int> rowid,
});

class $$FavoritesTableTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesTableTable> {
  $$FavoritesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get videoId => $composableBuilder(
      column: $table.videoId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get channelId => $composableBuilder(
      column: $table.channelId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnFilters(column));
}

class $$FavoritesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesTableTable> {
  $$FavoritesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get videoId => $composableBuilder(
      column: $table.videoId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get channelId => $composableBuilder(
      column: $table.channelId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnOrderings(column));
}

class $$FavoritesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesTableTable> {
  $$FavoritesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$FavoritesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FavoritesTableTable,
    FavoritesTableData,
    $$FavoritesTableTableFilterComposer,
    $$FavoritesTableTableOrderingComposer,
    $$FavoritesTableTableAnnotationComposer,
    $$FavoritesTableTableCreateCompanionBuilder,
    $$FavoritesTableTableUpdateCompanionBuilder,
    (
      FavoritesTableData,
      BaseReferences<_$AppDatabase, $FavoritesTableTable, FavoritesTableData>
    ),
    FavoritesTableData,
    PrefetchHooks Function()> {
  $$FavoritesTableTableTableManager(
      _$AppDatabase db, $FavoritesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> videoId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> author = const Value.absent(),
            Value<String> channelId = const Value.absent(),
            Value<String?> thumbnailUrl = const Value.absent(),
            Value<int> durationMs = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FavoritesTableCompanion(
            videoId: videoId,
            title: title,
            author: author,
            channelId: channelId,
            thumbnailUrl: thumbnailUrl,
            durationMs: durationMs,
            addedAt: addedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String videoId,
            required String title,
            required String author,
            required String channelId,
            Value<String?> thumbnailUrl = const Value.absent(),
            required int durationMs,
            required DateTime addedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              FavoritesTableCompanion.insert(
            videoId: videoId,
            title: title,
            author: author,
            channelId: channelId,
            thumbnailUrl: thumbnailUrl,
            durationMs: durationMs,
            addedAt: addedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FavoritesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FavoritesTableTable,
    FavoritesTableData,
    $$FavoritesTableTableFilterComposer,
    $$FavoritesTableTableOrderingComposer,
    $$FavoritesTableTableAnnotationComposer,
    $$FavoritesTableTableCreateCompanionBuilder,
    $$FavoritesTableTableUpdateCompanionBuilder,
    (
      FavoritesTableData,
      BaseReferences<_$AppDatabase, $FavoritesTableTable, FavoritesTableData>
    ),
    FavoritesTableData,
    PrefetchHooks Function()>;
typedef $$WatchLaterTableTableCreateCompanionBuilder = WatchLaterTableCompanion
    Function({
  required String videoId,
  required String title,
  required String author,
  required String channelId,
  Value<String?> thumbnailUrl,
  required int durationMs,
  required DateTime addedAt,
  Value<int> rowid,
});
typedef $$WatchLaterTableTableUpdateCompanionBuilder = WatchLaterTableCompanion
    Function({
  Value<String> videoId,
  Value<String> title,
  Value<String> author,
  Value<String> channelId,
  Value<String?> thumbnailUrl,
  Value<int> durationMs,
  Value<DateTime> addedAt,
  Value<int> rowid,
});

class $$WatchLaterTableTableFilterComposer
    extends Composer<_$AppDatabase, $WatchLaterTableTable> {
  $$WatchLaterTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get videoId => $composableBuilder(
      column: $table.videoId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get channelId => $composableBuilder(
      column: $table.channelId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnFilters(column));
}

class $$WatchLaterTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchLaterTableTable> {
  $$WatchLaterTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get videoId => $composableBuilder(
      column: $table.videoId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get channelId => $composableBuilder(
      column: $table.channelId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnOrderings(column));
}

class $$WatchLaterTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchLaterTableTable> {
  $$WatchLaterTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$WatchLaterTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WatchLaterTableTable,
    WatchLaterTableData,
    $$WatchLaterTableTableFilterComposer,
    $$WatchLaterTableTableOrderingComposer,
    $$WatchLaterTableTableAnnotationComposer,
    $$WatchLaterTableTableCreateCompanionBuilder,
    $$WatchLaterTableTableUpdateCompanionBuilder,
    (
      WatchLaterTableData,
      BaseReferences<_$AppDatabase, $WatchLaterTableTable, WatchLaterTableData>
    ),
    WatchLaterTableData,
    PrefetchHooks Function()> {
  $$WatchLaterTableTableTableManager(
      _$AppDatabase db, $WatchLaterTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchLaterTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchLaterTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchLaterTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> videoId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> author = const Value.absent(),
            Value<String> channelId = const Value.absent(),
            Value<String?> thumbnailUrl = const Value.absent(),
            Value<int> durationMs = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WatchLaterTableCompanion(
            videoId: videoId,
            title: title,
            author: author,
            channelId: channelId,
            thumbnailUrl: thumbnailUrl,
            durationMs: durationMs,
            addedAt: addedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String videoId,
            required String title,
            required String author,
            required String channelId,
            Value<String?> thumbnailUrl = const Value.absent(),
            required int durationMs,
            required DateTime addedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              WatchLaterTableCompanion.insert(
            videoId: videoId,
            title: title,
            author: author,
            channelId: channelId,
            thumbnailUrl: thumbnailUrl,
            durationMs: durationMs,
            addedAt: addedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WatchLaterTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WatchLaterTableTable,
    WatchLaterTableData,
    $$WatchLaterTableTableFilterComposer,
    $$WatchLaterTableTableOrderingComposer,
    $$WatchLaterTableTableAnnotationComposer,
    $$WatchLaterTableTableCreateCompanionBuilder,
    $$WatchLaterTableTableUpdateCompanionBuilder,
    (
      WatchLaterTableData,
      BaseReferences<_$AppDatabase, $WatchLaterTableTable, WatchLaterTableData>
    ),
    WatchLaterTableData,
    PrefetchHooks Function()>;
typedef $$PlayPositionsTableTableCreateCompanionBuilder
    = PlayPositionsTableCompanion Function({
  required String videoId,
  required int positionMs,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$PlayPositionsTableTableUpdateCompanionBuilder
    = PlayPositionsTableCompanion Function({
  Value<String> videoId,
  Value<int> positionMs,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$PlayPositionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $PlayPositionsTableTable> {
  $$PlayPositionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get videoId => $composableBuilder(
      column: $table.videoId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get positionMs => $composableBuilder(
      column: $table.positionMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$PlayPositionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayPositionsTableTable> {
  $$PlayPositionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get videoId => $composableBuilder(
      column: $table.videoId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get positionMs => $composableBuilder(
      column: $table.positionMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PlayPositionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayPositionsTableTable> {
  $$PlayPositionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
      column: $table.positionMs, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlayPositionsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlayPositionsTableTable,
    PlayPositionsTableData,
    $$PlayPositionsTableTableFilterComposer,
    $$PlayPositionsTableTableOrderingComposer,
    $$PlayPositionsTableTableAnnotationComposer,
    $$PlayPositionsTableTableCreateCompanionBuilder,
    $$PlayPositionsTableTableUpdateCompanionBuilder,
    (
      PlayPositionsTableData,
      BaseReferences<_$AppDatabase, $PlayPositionsTableTable,
          PlayPositionsTableData>
    ),
    PlayPositionsTableData,
    PrefetchHooks Function()> {
  $$PlayPositionsTableTableTableManager(
      _$AppDatabase db, $PlayPositionsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayPositionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayPositionsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayPositionsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> videoId = const Value.absent(),
            Value<int> positionMs = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlayPositionsTableCompanion(
            videoId: videoId,
            positionMs: positionMs,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String videoId,
            required int positionMs,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PlayPositionsTableCompanion.insert(
            videoId: videoId,
            positionMs: positionMs,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlayPositionsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlayPositionsTableTable,
    PlayPositionsTableData,
    $$PlayPositionsTableTableFilterComposer,
    $$PlayPositionsTableTableOrderingComposer,
    $$PlayPositionsTableTableAnnotationComposer,
    $$PlayPositionsTableTableCreateCompanionBuilder,
    $$PlayPositionsTableTableUpdateCompanionBuilder,
    (
      PlayPositionsTableData,
      BaseReferences<_$AppDatabase, $PlayPositionsTableTable,
          PlayPositionsTableData>
    ),
    PlayPositionsTableData,
    PrefetchHooks Function()>;
typedef $$DownloadsTableTableCreateCompanionBuilder = DownloadsTableCompanion
    Function({
  required String videoId,
  required String title,
  required String author,
  required String channelId,
  Value<String?> thumbnailUrl,
  required int durationMs,
  required String videoPath,
  Value<String?> audioPath,
  Value<String?> qualityLabel,
  Value<int> totalBytes,
  required DateTime downloadedAt,
  Value<int> rowid,
});
typedef $$DownloadsTableTableUpdateCompanionBuilder = DownloadsTableCompanion
    Function({
  Value<String> videoId,
  Value<String> title,
  Value<String> author,
  Value<String> channelId,
  Value<String?> thumbnailUrl,
  Value<int> durationMs,
  Value<String> videoPath,
  Value<String?> audioPath,
  Value<String?> qualityLabel,
  Value<int> totalBytes,
  Value<DateTime> downloadedAt,
  Value<int> rowid,
});

class $$DownloadsTableTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadsTableTable> {
  $$DownloadsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get videoId => $composableBuilder(
      column: $table.videoId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get channelId => $composableBuilder(
      column: $table.channelId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get videoPath => $composableBuilder(
      column: $table.videoPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get audioPath => $composableBuilder(
      column: $table.audioPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get qualityLabel => $composableBuilder(
      column: $table.qualityLabel, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalBytes => $composableBuilder(
      column: $table.totalBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt, builder: (column) => ColumnFilters(column));
}

class $$DownloadsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadsTableTable> {
  $$DownloadsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get videoId => $composableBuilder(
      column: $table.videoId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get channelId => $composableBuilder(
      column: $table.channelId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get videoPath => $composableBuilder(
      column: $table.videoPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get audioPath => $composableBuilder(
      column: $table.audioPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get qualityLabel => $composableBuilder(
      column: $table.qualityLabel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalBytes => $composableBuilder(
      column: $table.totalBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt,
      builder: (column) => ColumnOrderings(column));
}

class $$DownloadsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadsTableTable> {
  $$DownloadsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<String> get videoPath =>
      $composableBuilder(column: $table.videoPath, builder: (column) => column);

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<String> get qualityLabel => $composableBuilder(
      column: $table.qualityLabel, builder: (column) => column);

  GeneratedColumn<int> get totalBytes => $composableBuilder(
      column: $table.totalBytes, builder: (column) => column);

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt, builder: (column) => column);
}

class $$DownloadsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DownloadsTableTable,
    DownloadTableData,
    $$DownloadsTableTableFilterComposer,
    $$DownloadsTableTableOrderingComposer,
    $$DownloadsTableTableAnnotationComposer,
    $$DownloadsTableTableCreateCompanionBuilder,
    $$DownloadsTableTableUpdateCompanionBuilder,
    (
      DownloadTableData,
      BaseReferences<_$AppDatabase, $DownloadsTableTable, DownloadTableData>
    ),
    DownloadTableData,
    PrefetchHooks Function()> {
  $$DownloadsTableTableTableManager(
      _$AppDatabase db, $DownloadsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> videoId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> author = const Value.absent(),
            Value<String> channelId = const Value.absent(),
            Value<String?> thumbnailUrl = const Value.absent(),
            Value<int> durationMs = const Value.absent(),
            Value<String> videoPath = const Value.absent(),
            Value<String?> audioPath = const Value.absent(),
            Value<String?> qualityLabel = const Value.absent(),
            Value<int> totalBytes = const Value.absent(),
            Value<DateTime> downloadedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DownloadsTableCompanion(
            videoId: videoId,
            title: title,
            author: author,
            channelId: channelId,
            thumbnailUrl: thumbnailUrl,
            durationMs: durationMs,
            videoPath: videoPath,
            audioPath: audioPath,
            qualityLabel: qualityLabel,
            totalBytes: totalBytes,
            downloadedAt: downloadedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String videoId,
            required String title,
            required String author,
            required String channelId,
            Value<String?> thumbnailUrl = const Value.absent(),
            required int durationMs,
            required String videoPath,
            Value<String?> audioPath = const Value.absent(),
            Value<String?> qualityLabel = const Value.absent(),
            Value<int> totalBytes = const Value.absent(),
            required DateTime downloadedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              DownloadsTableCompanion.insert(
            videoId: videoId,
            title: title,
            author: author,
            channelId: channelId,
            thumbnailUrl: thumbnailUrl,
            durationMs: durationMs,
            videoPath: videoPath,
            audioPath: audioPath,
            qualityLabel: qualityLabel,
            totalBytes: totalBytes,
            downloadedAt: downloadedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DownloadsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DownloadsTableTable,
    DownloadTableData,
    $$DownloadsTableTableFilterComposer,
    $$DownloadsTableTableOrderingComposer,
    $$DownloadsTableTableAnnotationComposer,
    $$DownloadsTableTableCreateCompanionBuilder,
    $$DownloadsTableTableUpdateCompanionBuilder,
    (
      DownloadTableData,
      BaseReferences<_$AppDatabase, $DownloadsTableTable, DownloadTableData>
    ),
    DownloadTableData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WatchHistoryTableTableTableManager get watchHistoryTable =>
      $$WatchHistoryTableTableTableManager(_db, _db.watchHistoryTable);
  $$LocalSubscriptionsTableTableTableManager get localSubscriptionsTable =>
      $$LocalSubscriptionsTableTableTableManager(
          _db, _db.localSubscriptionsTable);
  $$FavoritesTableTableTableManager get favoritesTable =>
      $$FavoritesTableTableTableManager(_db, _db.favoritesTable);
  $$WatchLaterTableTableTableManager get watchLaterTable =>
      $$WatchLaterTableTableTableManager(_db, _db.watchLaterTable);
  $$PlayPositionsTableTableTableManager get playPositionsTable =>
      $$PlayPositionsTableTableTableManager(_db, _db.playPositionsTable);
  $$DownloadsTableTableTableManager get downloadsTable =>
      $$DownloadsTableTableTableManager(_db, _db.downloadsTable);
}
