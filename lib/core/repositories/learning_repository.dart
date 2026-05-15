import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subject.dart';
import '../models/unit.dart';
import '../models/topic.dart';
import '../models/question.dart';

final _firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Loads the list of subjects.
final subjectsProvider = FutureProvider<List<Subject>>((ref) async {
  final db = ref.read(_firestoreProvider);
  final snap = await db.collection('subjects').orderBy('name').get();
  return snap.docs.map((d) => Subject.fromFirestore(d)).toList();
});

/// Units by subjectId
final unitsProvider = FutureProvider.family<List<Unit>, String>((ref, subjectId) async {
  final db = ref.read(_firestoreProvider);
  final snap = await db
      .collection('units')
      .where('subjectId', isEqualTo: subjectId)
      .orderBy('order')
      .get();
  return snap.docs.map((d) => Unit.fromFirestore(d)).toList();
});

/// Topics by unitId
final topicsProvider = FutureProvider.family<List<Topic>, String>((ref, unitId) async {
  final db = ref.read(_firestoreProvider);
  final snap = await db
      .collection('topics')
      .where('unitId', isEqualTo: unitId)
      .orderBy('order')
      .get();
  return snap.docs.map((d) => Topic.fromFirestore(d)).toList();
});

/// Drill questions for a topic (topicId)
final drillQuestionsProvider = FutureProvider.family<List<Question>, String>((ref, topicId) async {
  final db = ref.read(_firestoreProvider);
  final snap = await db
      .collection('questions')
      .where('topicId', isEqualTo: topicId)
      .get();
  return snap.docs.map((d) => Question.fromFirestore(d)).toList();
});

/// WAEC exam questions by subjectId
final waecQuestionsProvider = FutureProvider.family<List<Question>, String>((ref, subjectId) async {
  final db = ref.read(_firestoreProvider);
  final snap = await db
      .collection('questions')
      .where('subjectId', isEqualTo: subjectId)
      .get();
  return snap.docs.map((d) => Question.fromFirestore(d)).toList();
});