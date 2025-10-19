import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RealtimeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _statusSubscription;

  void listenToFriendUpdates(void Function() onUpdate) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _statusSubscription?.cancel();
    _statusSubscription = _firestore
        .collection('user_status')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        onUpdate();
      }
    });
  }

  void dispose() {
    _statusSubscription?.cancel();
  }
}
