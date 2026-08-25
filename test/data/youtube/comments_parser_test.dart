// ============================================================
// CommentsParser — both of YouTube's comment shapes
// ============================================================
// The fixtures are trimmed `next` responses: every key the parser reads
// is present and everything else is gone. Nothing here touches the
// network — the parser is static and takes a decoded map.
// ============================================================

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/data/youtube/comments_service.dart';
import 'package:smarttube_poc/domain/entities/comment_item.dart';

/// A watch-page response: no comments in it, only the token that loads
/// them and the count printed on the entry point.
const _watchNext = '''
{
  "contents": {
    "twoColumnWatchNextResults": {
      "results": {
        "results": {
          "contents": [
            {
              "itemSectionRenderer": {
                "sectionIdentifier": "comment-item-section",
                "contents": [
                  {
                    "continuationItemRenderer": {
                      "trigger": "CONTINUATION_TRIGGER_ON_ITEM_SHOWN",
                      "continuationEndpoint": {
                        "continuationCommand": {
                          "token": "SECTION_TOKEN",
                          "request": "CONTINUATION_REQUEST_TYPE_WATCH_NEXT"
                        }
                      }
                    }
                  }
                ]
              }
            }
          ]
        }
      }
    }
  },
  "engagementPanels": [
    {
      "engagementPanelSectionListRenderer": {
        "panelIdentifier": "engagement-panel-comments-section",
        "header": {
          "engagementPanelTitleHeaderRenderer": {
            "contextualInfo": { "runs": [ { "text": "1,204" } ] }
          }
        }
      }
    }
  ],
  "commentsEntryPointHeaderRenderer": {
    "commentCount": { "simpleText": "1,204" }
  }
}
''';

/// The watch-page shape YouTube serves today: no `comment-item-section`
/// anywhere, only a comments engagement panel whose header holds the
/// count and the sort menu and whose content holds the section token.
const _watchNextPanel = '''
{
  "engagementPanels": [
    {
      "engagementPanelSectionListRenderer": {
        "panelIdentifier": "engagement-panel-macro-markers-description-chapters",
        "content": {
          "sectionListRenderer": {
            "contents": [
              {
                "itemSectionRenderer": {
                  "contents": [
                    {
                      "continuationItemRenderer": {
                        "continuationEndpoint": {
                          "continuationCommand": { "token": "CHAPTERS_TOKEN" }
                        }
                      }
                    }
                  ]
                }
              }
            ]
          }
        }
      }
    },
    {
      "engagementPanelSectionListRenderer": {
        "panelIdentifier": "engagement-panel-comments-section",
        "header": {
          "engagementPanelTitleHeaderRenderer": {
            "title": { "runs": [ { "text": "Comments" } ] },
            "contextualInfo": { "runs": [ { "text": "2.4M" } ] },
            "menu": {
              "sortFilterSubMenuRenderer": {
                "subMenuItems": [
                  {
                    "title": "Top",
                    "selected": true,
                    "serviceEndpoint": {
                      "continuationCommand": { "token": "PANEL_TOP" }
                    }
                  },
                  {
                    "title": "Newest",
                    "selected": false,
                    "serviceEndpoint": {
                      "continuationCommand": { "token": "PANEL_NEWEST" }
                    }
                  }
                ]
              }
            }
          }
        },
        "content": {
          "sectionListRenderer": {
            "contents": [
              {
                "itemSectionRenderer": {
                  "contents": [
                    {
                      "continuationItemRenderer": {
                        "continuationEndpoint": {
                          "continuationCommand": { "token": "PANEL_SECTION" }
                        }
                      }
                    }
                  ]
                }
              }
            ]
          }
        }
      }
    }
  ]
}
''';

/// The classic shape: everything inside `commentRenderer`.
const _legacyPage = '''
{
  "onResponseReceivedEndpoints": [
    {
      "reloadContinuationItemsCommand": {
        "slot": "RELOAD_CONTINUATION_SLOT_HEADER",
        "continuationItems": [
          {
            "commentsHeaderRenderer": {
              "countText": {
                "runs": [ { "text": "1,204" }, { "text": " Comments" } ]
              },
              "sortMenu": {
                "sortFilterSubMenuRenderer": {
                  "subMenuItems": [
                    {
                      "title": "Top comments",
                      "selected": true,
                      "serviceEndpoint": {
                        "continuationCommand": { "token": "TOP_TOKEN" }
                      }
                    },
                    {
                      "title": "Newest first",
                      "selected": false,
                      "serviceEndpoint": {
                        "continuationCommand": { "token": "NEWEST_TOKEN" }
                      }
                    }
                  ]
                }
              }
            }
          }
        ]
      }
    },
    {
      "reloadContinuationItemsCommand": {
        "slot": "RELOAD_CONTINUATION_SLOT_BODY",
        "continuationItems": [
          {
            "commentThreadRenderer": {
              "renderingPriority": "RENDERING_PRIORITY_PINNED_COMMENT",
              "comment": {
                "commentRenderer": {
                  "commentId": "UgxLEGACY001",
                  "authorText": { "simpleText": "@channelowner" },
                  "authorThumbnail": {
                    "thumbnails": [
                      { "url": "https://yt3.example/small.jpg", "width": 48 },
                      { "url": "https://yt3.example/big.jpg", "width": 176 }
                    ]
                  },
                  "authorEndpoint": {
                    "browseEndpoint": { "browseId": "UCowner0000000000000001" }
                  },
                  "authorIsChannelOwner": true,
                  "authorCommentBadge": {
                    "authorCommentBadgeRenderer": {
                      "icon": { "iconType": "CHECK_CIRCLE_THICK" },
                      "iconTooltip": "Verified"
                    }
                  },
                  "publishedTimeText": {
                    "runs": [ { "text": "2 years ago" } ]
                  },
                  "contentText": {
                    "runs": [
                      { "text": "Chapters: " },
                      { "text": "1:23" },
                      { "text": " intro" }
                    ]
                  },
                  "voteCount": { "simpleText": "1.2K" },
                  "replyCount": 42,
                  "actionButtons": {
                    "commentActionButtonsRenderer": {
                      "creatorHeart": {
                        "creatorHeartRenderer": {
                          "isHearted": true,
                          "heartedTooltip": "❤ by the creator"
                        }
                      }
                    }
                  }
                }
              },
              "replies": {
                "commentRepliesRenderer": {
                  "contents": [
                    {
                      "continuationItemRenderer": {
                        "continuationEndpoint": {
                          "continuationCommand": { "token": "REPLIES_TOKEN_1" }
                        }
                      }
                    }
                  ],
                  "viewReplies": {
                    "buttonRenderer": {
                      "text": { "runs": [ { "text": "42 replies" } ] }
                    }
                  }
                }
              }
            }
          },
          {
            "commentThreadRenderer": {
              "comment": {
                "commentRenderer": {
                  "commentId": "UgxLEGACY002",
                  "authorText": { "simpleText": "@someone" },
                  "authorEndpoint": {
                    "browseEndpoint": { "browseId": "UCviewer000000000000001" }
                  },
                  "publishedTimeText": {
                    "runs": [ { "text": "3 days ago (edited)" } ]
                  },
                  "contentText": { "runs": [ { "text": "plain comment" } ] },
                  "voteCount": { "simpleText": "7" }
                }
              }
            }
          },
          {
            "continuationItemRenderer": {
              "continuationEndpoint": {
                "continuationCommand": { "token": "PAGE_2_TOKEN" }
              }
            }
          }
        ]
      }
    }
  ]
}
''';

/// The current shape: the thread list names entity keys, and the content
/// arrives in `frameworkUpdates`.
const _entityPage = '''
{
  "frameworkUpdates": {
    "entityBatchUpdate": {
      "mutations": [
        {
          "entityKey": "ENTITY_KEY_1",
          "type": "ENTITY_MUTATION_TYPE_REPLACE",
          "payload": {
            "commentEntityPayload": {
              "key": "ENTITY_KEY_1",
              "properties": {
                "commentId": "UgxENTITY001",
                "content": {
                  "content": "great bit at 12:05 and again at 1:02:03",
                  "commandRuns": [
                    {
                      "startIndex": 14,
                      "length": 5,
                      "onTap": {
                        "innertubeCommand": {
                          "watchEndpoint": { "startTimeSeconds": 725 }
                        }
                      }
                    }
                  ]
                },
                "publishedTime": "5 hours ago",
                "replyLevel": 0,
                "toolbarStateKey": "TOOLBAR_STATE_1"
              },
              "author": {
                "channelId": "UCentity00000000000001",
                "displayName": "@entityfan",
                "avatarThumbnailUrl": "https://yt3.example/entity.jpg",
                "isVerified": true,
                "isCreator": false
              },
              "toolbar": {
                "likeCountNotliked": "3.4K",
                "likeCountA11ylabel": "3.4K likes",
                "replyCount": "18"
              },
              "avatar": {
                "image": {
                  "sources": [
                    { "url": "https://yt3.example/entity-88.jpg", "width": 88 }
                  ]
                }
              }
            }
          }
        },
        {
          "entityKey": "SURFACE_KEY_1",
          "payload": {
            "commentSurfaceEntityPayload": {
              "key": "SURFACE_KEY_1",
              "pinnedText": "Pinned by BoodTube"
            }
          }
        },
        {
          "entityKey": "TOOLBAR_STATE_1",
          "payload": {
            "engagementToolbarStateEntityPayload": {
              "key": "TOOLBAR_STATE_1",
              "heartState": "TOOLBAR_HEART_STATE_HEARTED",
              "likeState": "TOOLBAR_LIKE_STATE_INDIFFERENT"
            }
          }
        },
        {
          "entityKey": "ENTITY_KEY_2",
          "payload": {
            "commentEntityPayload": {
              "key": "ENTITY_KEY_2",
              "properties": {
                "commentId": "UgxENTITY002",
                "content": { "content": "second one" },
                "publishedTime": "1 week ago",
                "replyLevel": 0
              },
              "author": {
                "channelId": "UCentity00000000000002",
                "displayName": "@another"
              },
              "toolbar": { "likeCountNotliked": "12" }
            }
          }
        }
      ]
    }
  },
  "onResponseReceivedEndpoints": [
    {
      "reloadContinuationItemsCommand": {
        "slot": "RELOAD_CONTINUATION_SLOT_BODY",
        "continuationItems": [
          {
            "commentsHeaderRenderer": {
              "commentsCount": { "simpleText": "2.1K" },
              "sortMenu": {
                "sortFilterSubMenuRenderer": {
                  "subMenuItems": [
                    {
                      "title": "Top comments",
                      "selected": false,
                      "serviceEndpoint": {
                        "continuationCommand": { "token": "E_TOP" }
                      }
                    },
                    {
                      "title": "Newest first",
                      "selected": true,
                      "serviceEndpoint": {
                        "continuationCommand": { "token": "E_NEWEST" }
                      }
                    }
                  ]
                }
              }
            }
          },
          {
            "commentThreadRenderer": {
              "renderingPriority": "RENDERING_PRIORITY_PINNED_COMMENT",
              "commentViewModel": {
                "commentViewModel": {
                  "commentId": "UgxENTITY001",
                  "commentKey": "ENTITY_KEY_1",
                  "commentSurfaceKey": "SURFACE_KEY_1",
                  "toolbarStateKey": "TOOLBAR_STATE_1"
                }
              },
              "replies": {
                "commentRepliesRenderer": {
                  "contents": [
                    {
                      "continuationItemRenderer": {
                        "continuationEndpoint": {
                          "continuationCommand": { "token": "E_REPLIES_1" }
                        }
                      }
                    }
                  ]
                }
              }
            }
          },
          {
            "commentThreadRenderer": {
              "commentViewModel": {
                "commentViewModel": {
                  "commentId": "UgxENTITY002",
                  "commentKey": "ENTITY_KEY_2"
                }
              }
            }
          },
          {
            "continuationItemRenderer": {
              "continuationEndpoint": {
                "continuationCommand": { "token": "E_PAGE_2" }
              }
            }
          }
        ]
      }
    }
  ]
}
''';

/// A reply page: `appendContinuationItemsAction`, bare `commentRenderer`s.
const _legacyReplies = '''
{
  "onResponseReceivedEndpoints": [
    {
      "appendContinuationItemsAction": {
        "continuationItems": [
          {
            "commentRenderer": {
              "commentId": "UgxREPLY001",
              "authorText": { "simpleText": "@replier" },
              "authorEndpoint": {
                "browseEndpoint": { "browseId": "UCreply0000000000000001" }
              },
              "publishedTimeText": { "runs": [ { "text": "10 minutes ago" } ] },
              "contentText": { "runs": [ { "text": "agreed" } ] },
              "voteCount": { "simpleText": "2" }
            }
          }
        ]
      }
    }
  ]
}
''';

Map<String, dynamic> _decode(String source) =>
    jsonDecode(source) as Map<String, dynamic>;

void main() {
  group('parseEntryPoint', () {
    test('finds the section token and the printed count', () {
      final entry = CommentsParser.parseEntryPoint(_decode(_watchNext));

      expect(entry.continuation, 'SECTION_TOKEN');
      expect(entry.countText, '1,204');
    });

    test('prefers the panel content token over the sort menu', () {
      final entry = CommentsParser.parseEntryPoint(_decode(_watchNextPanel));

      // Not PANEL_TOP: the header's sort tokens sit earlier in the
      // document than the content's, and grabbing one of those would
      // make the default order depend on key order.
      expect(entry.continuation, 'PANEL_SECTION');
      expect(entry.countText, '2.4M');
      expect(entry.sortTokens, {
        CommentSort.top: 'PANEL_TOP',
        CommentSort.newest: 'PANEL_NEWEST',
      });
    });

    test('ignores engagement panels that are not the comments one', () {
      final entry = CommentsParser.parseEntryPoint(_decode(_watchNextPanel));

      expect(entry.continuation, isNot('CHAPTERS_TOKEN'));
    });

    test('reports comments disabled as a null token', () {
      final entry = CommentsParser.parseEntryPoint(
        _decode('{"contents": {"twoColumnWatchNextResults": {}}}'),
      );

      expect(entry.continuation, isNull);
      expect(entry.countText, isNull);
      expect(entry.sortTokens, isEmpty);
    });
  });

  group('parsePage — commentRenderer', () {
    late CommentPage page;

    setUp(() => page = CommentsParser.parsePage(_decode(_legacyPage)));

    test('reads both threads in order, and the next page token', () {
      expect(
        page.items.map((c) => c.id),
        ['UgxLEGACY001', 'UgxLEGACY002'],
      );
      expect(page.continuation, 'PAGE_2_TOKEN');
      expect(page.hasMore, isTrue);
    });

    test('reads the header count and the sort menu', () {
      // Only the number, not the " Comments" run beside it.
      expect(page.totalCountText, '1,204');
      expect(page.sortTokens, {
        CommentSort.top: 'TOP_TOKEN',
        CommentSort.newest: 'NEWEST_TOKEN',
      });
      expect(page.selectedSort, CommentSort.top);
    });

    test('reads every field of the pinned, hearted, owner comment', () {
      final pinned = page.items.first;

      expect(pinned.author, '@channelowner');
      expect(pinned.authorChannelId, 'UCowner0000000000000001');
      // The widest thumbnail, not the first.
      expect(pinned.authorAvatarUrl, 'https://yt3.example/big.jpg');
      expect(pinned.content, 'Chapters: 1:23 intro');
      expect(pinned.publishedTimeText, '2 years ago');
      expect(pinned.likeCountText, '1.2K');
      expect(pinned.likeCount, 1200);
      expect(pinned.replyCount, 42);
      expect(pinned.repliesContinuation, 'REPLIES_TOKEN_1');
      expect(pinned.isPinned, isTrue);
      expect(pinned.isHearted, isTrue);
      expect(pinned.isByOwner, isTrue);
      expect(pinned.isVerified, isTrue);
      expect(pinned.isReply, isFalse);
      expect(pinned.hasReplies, isTrue);
    });

    test('a plain comment carries none of the badges', () {
      final plain = page.items[1];

      expect(plain.content, 'plain comment');
      expect(plain.likeCount, 7);
      expect(plain.isPinned, isFalse);
      expect(plain.isHearted, isFalse);
      expect(plain.isByOwner, isFalse);
      expect(plain.isVerified, isFalse);
      expect(plain.repliesContinuation, isNull);
      expect(plain.hasReplies, isFalse);
    });

    test('turns YouTube wording into a moment', () {
      final published = page.items.first.publishedAt;
      final age = DateTime.now().difference(published);

      expect(age.inDays, closeTo(730, 2));
    });

    test('reads a reply page appended by continuation', () {
      final replies = CommentsParser.parsePage(_decode(_legacyReplies));

      expect(replies.items, hasLength(1));
      expect(replies.items.single.id, 'UgxREPLY001');
      expect(replies.items.single.content, 'agreed');
      expect(replies.continuation, isNull);
      expect(replies.hasMore, isFalse);
    });
  });

  group('parsePage — commentEntityPayload', () {
    late CommentPage page;

    setUp(() => page = CommentsParser.parsePage(_decode(_entityPage)));

    test('joins the thread list to the entity mutations, in order', () {
      expect(
        page.items.map((c) => c.id),
        ['UgxENTITY001', 'UgxENTITY002'],
      );
      expect(page.continuation, 'E_PAGE_2');
    });

    test('reads the header, including which order is selected', () {
      expect(page.totalCountText, '2.1K');
      expect(page.sortTokens, {
        CommentSort.top: 'E_TOP',
        CommentSort.newest: 'E_NEWEST',
      });
      expect(page.selectedSort, CommentSort.newest);
    });

    test('reads the payload, the surface and the toolbar state', () {
      final first = page.items.first;

      expect(first.author, '@entityfan');
      expect(first.authorChannelId, 'UCentity00000000000001');
      expect(first.authorAvatarUrl, 'https://yt3.example/entity.jpg');
      expect(first.content, 'great bit at 12:05 and again at 1:02:03');
      expect(first.publishedTimeText, '5 hours ago');
      expect(first.likeCount, 3400);
      expect(first.replyCount, 18);
      expect(first.repliesContinuation, 'E_REPLIES_1');
      // From commentSurfaceEntityPayload, not from the thread renderer.
      expect(first.isPinned, isTrue);
      // From engagementToolbarStateEntityPayload.
      expect(first.isHearted, isTrue);
      expect(first.isVerified, isTrue);
      expect(first.isByOwner, isFalse);
    });

    test('a comment with no surface or toolbar entity is still read', () {
      final second = page.items[1];

      expect(second.author, '@another');
      expect(second.content, 'second one');
      expect(second.likeCount, 12);
      expect(second.isPinned, isFalse);
      expect(second.isHearted, isFalse);
      expect(second.replyCount, isNull);
      expect(second.repliesContinuation, isNull);
    });

    test('reads a reply list of bare view models', () {
      final replies = CommentsParser.parsePage(_decode('''
        {
          "frameworkUpdates": {
            "entityBatchUpdate": {
              "mutations": [
                {
                  "entityKey": "REPLY_KEY_1",
                  "payload": {
                    "commentEntityPayload": {
                      "key": "REPLY_KEY_1",
                      "properties": {
                        "commentId": "UgxENTITYREPLY001",
                        "content": { "content": "same here" },
                        "publishedTime": "2 minutes ago",
                        "replyLevel": 1
                      },
                      "author": {
                        "channelId": "UCreply000000000000009",
                        "displayName": "@replier"
                      },
                      "toolbar": { "likeCountNotliked": "1" }
                    }
                  }
                }
              ]
            }
          },
          "onResponseReceivedEndpoints": [
            {
              "appendContinuationItemsAction": {
                "continuationItems": [
                  {
                    "commentViewModel": {
                      "commentId": "UgxENTITYREPLY001",
                      "commentKey": "REPLY_KEY_1"
                    }
                  }
                ]
              }
            }
          ]
        }
      '''),
      );

      final reply = replies.items.single;
      expect(reply.id, 'UgxENTITYREPLY001');
      expect(reply.content, 'same here');
      // replyLevel 1 is what makes it a reply rather than a thread.
      expect(reply.isReply, isTrue);
    });

    test('drops a thread whose entity never arrived', () {
      final orphan = CommentsParser.parsePage(_decode('''
        {
          "onResponseReceivedEndpoints": [
            {
              "reloadContinuationItemsCommand": {
                "continuationItems": [
                  {
                    "commentThreadRenderer": {
                      "commentViewModel": {
                        "commentViewModel": {
                          "commentId": "UgxMISSING",
                          "commentKey": "NOT_IN_MUTATIONS"
                        }
                      }
                    }
                  }
                ]
              }
            }
          ]
        }
      '''),
      );

      expect(orphan.items, isEmpty);
    });
  });

  group('parsePage — robustness', () {
    test('an unrecognised envelope still yields its comments', () {
      // No continuation-items list anywhere; the renderers are all the
      // parser has to go on.
      final page = CommentsParser.parsePage(_decode('''
        {
          "someNewWrapper": {
            "items": [
              {
                "commentThreadRenderer": {
                  "comment": {
                    "commentRenderer": {
                      "commentId": "UgxREWRAPPED",
                      "authorText": { "simpleText": "@x" },
                      "contentText": { "runs": [ { "text": "hi" } ] },
                      "publishedTimeText": { "simpleText": "1 day ago" }
                    }
                  }
                }
              }
            ]
          }
        }
      '''),
      );

      expect(page.items.single.id, 'UgxREWRAPPED');
      expect(page.items.single.likeCount, 0);
    });

    test('an empty response is an empty page, not a throw', () {
      final page = CommentsParser.parsePage(_decode('{}'));

      expect(page.items, isEmpty);
      expect(page.continuation, isNull);
      expect(page.totalCountText, isNull);
      expect(page.sortTokens, isEmpty);
    });

    test('the same comment repeated across lists is kept once', () {
      final page = CommentsParser.parsePage(_decode('''
        {
          "onResponseReceivedEndpoints": [
            {
              "reloadContinuationItemsCommand": {
                "continuationItems": [
                  {
                    "commentThreadRenderer": {
                      "comment": {
                        "commentRenderer": {
                          "commentId": "UgxDUPE",
                          "contentText": { "runs": [ { "text": "once" } ] }
                        }
                      }
                    }
                  }
                ]
              }
            },
            {
              "appendContinuationItemsAction": {
                "continuationItems": [
                  {
                    "commentThreadRenderer": {
                      "comment": {
                        "commentRenderer": {
                          "commentId": "UgxDUPE",
                          "contentText": { "runs": [ { "text": "twice" } ] }
                        }
                      }
                    }
                  }
                ]
              }
            }
          ]
        }
      '''),
      );

      expect(page.items, hasLength(1));
      expect(page.items.single.content, 'once');
    });
  });

  group('parsePublishedTime', () {
    final now = DateTime(2026, 8, 25, 12);

    test('reads every unit YouTube uses', () {
      expect(
        CommentsParser.parsePublishedTime('30 seconds ago', now: now),
        DateTime(2026, 8, 25, 11, 59, 30),
      );
      expect(
        CommentsParser.parsePublishedTime('4 minutes ago', now: now),
        DateTime(2026, 8, 25, 11, 56),
      );
      expect(
        CommentsParser.parsePublishedTime('5 hours ago', now: now),
        DateTime(2026, 8, 25, 7),
      );
      expect(
        CommentsParser.parsePublishedTime('3 days ago (edited)', now: now),
        DateTime(2026, 8, 22, 12),
      );
      expect(
        CommentsParser.parsePublishedTime('2 weeks ago', now: now),
        DateTime(2026, 8, 11, 12),
      );
      expect(
        CommentsParser.parsePublishedTime('6 months ago', now: now),
        now.subtract(const Duration(days: 180)),
      );
      expect(
        CommentsParser.parsePublishedTime('2 years ago', now: now),
        now.subtract(const Duration(days: 730)),
      );
    });

    test('falls back to now for anything it cannot read', () {
      expect(CommentsParser.parsePublishedTime(null, now: now), now);
      expect(CommentsParser.parsePublishedTime('just now', now: now), now);
    });
  });
}
