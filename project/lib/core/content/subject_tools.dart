/// Which study tools each subject gets, and which of them the WAEC exam
/// hall allows.
///
/// Keyed by subject **name**, normalised: Firestore subject ids are auto-ids,
/// and the name is what `AppColors.forSubject` and the catalog already key
/// on. An unknown subject gets only the tools every subject has.
library;

/// Every tool the study dock can offer. A tool registers itself in
/// `lib/core/study/study_tool_registry.dart` under one of these ids.
enum StudyToolId {
  calculator,
  scratchpad,
  fourFigureTables,
  periodicTable,
  constants,
  formulaSheet,
  glossary,
}

String normaliseSubject(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'[\s_]+'), '-');

/// Tools every subject has.
const _everywhere = {StudyToolId.scratchpad, StudyToolId.glossary};

const Map<String, Set<StudyToolId>> _bySubject = {
  'mathematics': {
    StudyToolId.calculator,
    StudyToolId.fourFigureTables,
    StudyToolId.formulaSheet,
  },
  'further-mathematics': {
    StudyToolId.calculator,
    StudyToolId.fourFigureTables,
    StudyToolId.formulaSheet,
  },
  'physics': {
    StudyToolId.calculator,
    StudyToolId.fourFigureTables,
    StudyToolId.constants,
    StudyToolId.formulaSheet,
  },
  'chemistry': {
    StudyToolId.calculator,
    StudyToolId.periodicTable,
    StudyToolId.constants,
    StudyToolId.formulaSheet,
  },
  'government': {},
};

Set<StudyToolId> toolsForSubject(String subjectName) => {
  ..._everywhere,
  ...?_bySubject[normaliseSubject(subjectName)],
};

/// What a candidate may use in the WAEC hall, and so what the practice
/// exam screen offers. Everything else (formula sheets, glossary, notes)
/// is hidden during an exam.
///
/// The calculator: WAEC permits non-programmable scientific calculators.
/// Four-figure tables: supplied in the hall. Scratchpad: rough work is
/// done in the answer booklet.
///
/// **The periodic table is off until checked.** Whether WAEC supplies one
/// in the Chemistry paper has not been verified; switch it on here only
/// once it has, rather than guessing in the student's favour.
const Set<StudyToolId> examAllowedTools = {
  StudyToolId.calculator,
  StudyToolId.fourFigureTables,
  StudyToolId.scratchpad,
};
