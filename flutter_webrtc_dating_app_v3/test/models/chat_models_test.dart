import 'package:availchat/models/call_model.dart';
import 'package:availchat/models/chat_message_model.dart';
import 'package:availchat/models/conversation_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_document_snapshot.dart';

void main() {
  group('ChatMessage', () {
    test('parses a full message document', () {
      final at = DateTime(2026, 1, 2, 3, 4);
      final m = ChatMessage.fromFirestore(
        FakeDocumentSnapshot('m1', {
          'senderId': 'a',
          'receiverId': 'b',
          'conversationId': 'a_b',
          'message': 'hi',
          'type': 'image',
          'status': 'read',
          'timestamp': Timestamp.fromDate(at),
          'editedAt': at.millisecondsSinceEpoch,
          'replyTo': {
            'id': 'm0',
            'senderId': 'b',
            'text': 'yo',
            'type': 'text',
          },
          'mediaUrl': 'https://res.cloudinary.com/x/image/upload/a.jpg',
          'mediaDuration': 65.0,
        }),
      );
      expect(m.id, 'm1');
      expect(m.type, MessageType.image);
      expect(m.status, MessageStatus.read);
      expect(m.timestamp, at);
      expect(m.editedAt, at);
      expect(m.replyTo?['id'], 'm0');
      expect(m.isMedia, isTrue);
      expect(m.mediaDuration, 65);
      expect(m.formattedDuration, '01:05');
    });

    test('unknown or missing values fall back safely', () {
      final m = ChatMessage.fromFirestore(
        FakeDocumentSnapshot('m2', {
          'type': 'hologram',
          'status': 42,
          'replyTo': 'not a map',
        }),
      );
      expect(m.type, MessageType.text);
      expect(m.status, MessageStatus.sent);
      expect(m.replyTo, isNull);
      expect(m.message, '');
      expect(m.formattedDuration, '0:00');
    });

    test('previews and reply snapshots', () {
      expect(ChatMessage.previewFor(MessageType.audio, ''), '🎤 Voice message');
      expect(
        ChatMessage.previewFor(MessageType.image, 'look'),
        '📷 Photo: look',
      );
      expect(ChatMessage.previewFor(MessageType.text, 'plain'), 'plain');

      final deleted = ChatMessage.fromFirestore(
        FakeDocumentSnapshot('m3', {
          'senderId': 'a',
          'message': 'secret',
          'isDeleted': true,
        }),
      );
      expect(deleted.previewText, ChatMessage.deletedText);
      expect(deleted.toReplySnapshot(), {
        'id': 'm3',
        'senderId': 'a',
        'text': '',
        'type': 'text',
      });
    });
  });

  group('Conversation', () {
    Conversation conv(Map<String, dynamic> data, {String id = 'a_b'}) =>
        Conversation.fromFirestore(FakeDocumentSnapshot(id, data));

    test('idFor is deterministic and order-independent', () {
      expect(Conversation.idFor('b', 'a'), 'a_b');
      expect(Conversation.idFor('a', 'b'), Conversation.idFor('b', 'a'));
    });

    test('reads the canonical lastMessage map and legacy flat fields', () {
      final at = DateTime(2026, 3, 1);
      final canonical = conv({
        'participants': ['a', 'b'],
        'lastMessage': {
          'text': 'hey',
          'senderId': 'a',
          'type': 'text',
          'messageId': 'm9',
          'at': Timestamp.fromDate(at),
        },
      });
      expect(canonical.lastMessageText, 'hey');
      expect(canonical.lastMessageSender, 'a');
      expect(canonical.lastMessageId, 'm9');
      expect(canonical.lastMessageAt, at);

      final legacy = conv({
        'participants': ['a', 'b'],
        'lastMessage': 'old',
        'lastMessageSenderId': 'b',
        'lastMessageTime': at.millisecondsSinceEpoch,
      });
      expect(legacy.lastMessageText, 'old');
      expect(legacy.lastMessageSender, 'b');
      expect(legacy.lastMessageAt, at);
      expect(legacy.hasMessages, isTrue);
    });

    test('per-user state, mute and deleted-user resolution', () {
      final c = conv({
        'participants': ['a', 'b'],
        'statePerUser': {'a': 'active'},
        'participantData': {
          'a': {'muted': false, 'unreadCount': 3},
          'b': {'hasReplied': true, 'deleted': true},
        },
        'muted': {'a': true, 'b': true},
        'lastMessage': {'text': 'x', 'senderId': 'a'},
      });
      expect(c.stateFor('a'), 'active');
      expect(c.stateFor('b'), 'active');
      expect(c.isMuted('a'), isFalse);
      expect(c.isMuted('b'), isTrue);
      expect(c.isDeletedUser('b'), isTrue);
      expect(c.isDeletedUser('a'), isFalse);
      expect(c.getOtherParticipantId('a'), 'b');
      expect(
        conv({
          'deletedUsers': ['z'],
        }).isDeletedUser('z'),
        isTrue,
      );
      expect(
        conv({
          'participantData': {'b': {}},
        }).stateFor('b'),
        'new',
      );
    });

    test('cleared or deleted chats show no unread badge (DEST-118)', () {
      final at = DateTime(2026, 3, 1, 12);
      Map<String, dynamic> base(Map<String, dynamic> me) => {
        'participants': ['a', 'b'],
        'lastMessage': {
          'text': 'x',
          'senderId': 'b',
          'at': Timestamp.fromDate(at),
        },
        'participantData': {'a': me},
      };

      expect(conv(base({'unreadCount': 2})).visibleUnreadFor('a'), 2);
      expect(
        conv(
          base({'unreadCount': 2, 'clearedBefore': Timestamp.fromDate(at)}),
        ).visibleUnreadFor('a'),
        0,
      );
      final deleted = conv(
        base({'unreadCount': 2})..['statePerUser'] = {'a': 'deleted'},
      );
      expect(deleted.isVisibleTo('a'), isFalse);
      expect(deleted.visibleUnreadFor('a'), 0);
      expect(
        conv({
          'participants': ['a', 'b'],
        }).isVisibleTo('a'),
        isFalse,
      );
    });
  });

  group('CallModel', () {
    test('parses statuses and types, defaulting unknown values', () {
      CallModel parse(Map<String, dynamic> d) =>
          CallModel.fromFirestore(FakeDocumentSnapshot('c1', d));
      expect(
        parse({'callType': 'audio', 'status': 'missed'}).type,
        CallType.audio,
      );
      expect(parse({'status': 'missed'}).status, CallStatus.missed);
      expect(parse({'callType': 'video'}).type, CallType.video);
      expect(parse({'status': '???'}).status, CallStatus.ringing);
      expect(parse({'duration': 12.7}).duration, 12);
    });

    test('other party name and avatar depend on direction', () {
      final call = CallModel(
        id: 'c',
        callerId: 'a',
        callerName: 'Ann',
        callerAvatar: ' ',
        receiverId: 'b',
        receiverName: '',
        receiverAvatar: 'https://x/b.png',
        type: CallType.video,
        status: CallStatus.ended,
        timestamp: DateTime(2026),
      );
      expect(call.isOutgoingFor('a'), isTrue);
      expect(call.otherNameFor('a'), 'User');
      expect(call.otherNameFor('b'), 'Ann');
      expect(call.otherAvatarFor('a'), 'https://x/b.png');
      expect(call.otherAvatarFor('b'), isNull);
    });
  });
}
