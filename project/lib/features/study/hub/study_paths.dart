/// The Study tab's addresses, apart from the screens so the hub and the
/// router can link to them while the screens stay deferred (the bundle
/// budget; see CLAUDE.md, "Deferred screens").
library;

import '../../../core/content/subject_tools.dart';

const kCustomQuizPath = '/review/quiz';

const kDecksPath = '/review/flashcards';
String deckEditPath(String deckId) => '$kDecksPath/$deckId';
String deckStudyPath(String deckId) => '$kDecksPath/$deckId/study';
String deckQuizPath(String deckId) => '$kDecksPath/$deckId/quiz';

String studyToolPath(StudyToolId id) => '/review/tools/${id.name}';
