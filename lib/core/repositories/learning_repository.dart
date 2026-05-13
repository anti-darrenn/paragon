import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subject.dart';
import '../models/unit.dart';
import '../models/topic.dart';
import '../models/question.dart';

class LearningRepository {
  final FirebaseFirestore _db;
  LearningRepository(this._db);

  Future<List<Subject>> fetchSubjects() async {
    final snap = await _db.collection('subjects').get();
    return snap.docs.map(Subject.fromFirestore).toList();
  }

  Future<List<Unit>> fetchUnits(String subjectId) async {
    final snap = await _db
        .collection('units')
        .where('subjectId', isEqualTo: subjectId)
        .orderBy('order')
        .get();
    return snap.docs.map(Unit.fromFirestore).toList();
  }

  Future<List<Topic>> fetchTopics(String unitId) async {
    final snap = await _db
        .collection('topics')
        .where('unitId', isEqualTo: unitId)
        .orderBy('order')
        .get();
    return snap.docs.map(Topic.fromFirestore).toList();
  }

  Future<List<Question>> fetchDrillQuestions(String topicId) async {
    final snap = await _db
        .collection('questions')
        .where('topicId', isEqualTo: topicId)
        .where('source', isEqualTo: 'drill')
        .get();
    return snap.docs.map(Question.fromFirestore).toList();
  }

  Future<List<Question>> fetchWaecQuestions(String subjectId) async {
    final snap = await _db
        .collection('questions')
        .where('subjectId', isEqualTo: subjectId)
        .where('source', isEqualTo: 'waec')
        .orderBy('year')
        .get();
    return snap.docs.map(Question.fromFirestore).toList();
  }
}

// Providers
final learningRepositoryProvider = Provider<LearningRepository>((ref) {
  return LearningRepository(FirebaseFirestore.instance);
});

final subjectsProvider = FutureProvider<List<Subject>>((ref) {
  return ref.watch(learningRepositoryProvider).fetchSubjects();
});

final unitsProvider =
    FutureProvider.family<List<Unit>, String>((ref, subjectId) {
  return ref.watch(learningRepositoryProvider).fetchUnits(subjectId);
});

final topicsProvider =
    FutureProvider.family<List<Topic>, String>((ref, unitId) {
  return ref.watch(learningRepositoryProvider).fetchTopics(unitId);
});

final drillQuestionsProvider =
    FutureProvider.family<List<Question>, String>((ref, topicId) {
  return ref.watch(learningRepositoryProvider).fetchDrillQuestions(topicId);
});

final waecQuestionsProvider =
    FutureProvider.family<List<Question>, String>((ref, subjectId) {
  return ref.watch(learningRepositoryProvider).fetchWaecQuestions(subjectId);
});