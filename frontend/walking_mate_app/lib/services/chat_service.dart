import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walking_mate_app/models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendMessage(
      String chatRoomId, String text, String senderId) async {
    if (text.trim().isEmpty) {
      return;
    }

    final CollectionReference messagesRef = _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages');

    final DocumentReference chatRoomRef =
        _firestore.collection('chat_rooms').doc(chatRoomId);

    await _firestore.runTransaction((transaction) async {
      final newMessagesRef = messagesRef.doc();

      transaction.set(newMessagesRef, {
        'senderId': senderId,
        'text': text,
        'timestamp': Timestamp.now(),
      });

      transaction.update(chatRoomRef, {
        'lastMessage': text,
        'lastMessageTimestamp': Timestamp.now(),
      });
    });
  }

  Stream<List<Message>> getMessages(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromDocument(doc)).toList();
    });
  }

  Stream<DocumentSnapshot> getChatRoomStream(String chatRoomId) {
    return _firestore.collection('chat_rooms').doc(chatRoomId).snapshots();
  }
}
