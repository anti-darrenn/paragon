/// The studio editor's paths, apart from the editor itself so the router
/// can redirect to them without loading the studio, which is deferred
/// (audit F1).
library;

import '../../core/models/learn_resource.dart';

/// Path of the editor for an existing resource — also the link in the
/// draft-notification email (`tools/admin/notify_drafts.js`).
String adminResourcePath(String topicId, String resourceId) =>
    '/admin/topic/$topicId/resource/$resourceId';

String adminNewResourcePath(String topicId, LearnResourceType type) =>
    '/admin/topic/$topicId/new/${type.name}';

/// The question workbench: edit, preview, reports and history.
String adminQuestionPath(String questionId) => '/admin/question/$questionId';

/// The studio home open on one section (`StudioSection.name`).
String adminSectionPath(String section) =>
    section == 'overview' ? '/admin' : '/admin?s=$section';
