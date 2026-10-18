/// Addresses for live quizzes that screens link to without importing each
/// other (the screens are deferred).
library;

/// The student's quiz history: games played and won, rooms hosted.
const kQuizHistoryPath = '/me/history';

/// A host's own quizzes, and one to edit (`new` for a new one).
const kMyQuizzesPath = '/quizzes';
String quizEditPath(String id) => '/quizzes/$id';
