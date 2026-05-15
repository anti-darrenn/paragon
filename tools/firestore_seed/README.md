Seed data for Firestore (manual import)

Files:
- subjects.json
- units.json
- topics.json
- questions.json

How to use:
1. Open Firebase console → Firestore Database.
2. For each file, create a collection with the filename (e.g. `subjects`) or use the collection names shown in the JSON.
3. Click "Add document" and use the `id` field as the document ID (or leave Firestore to generate one).
4. Copy the other fields into the document fields exactly as shown.

Notes:
- `questions.text` contains inline LaTeX delimited by `$...$` — the app's `MathText` handles this.
- The `questions` documents include both `topicId` and `subjectId` to support both drill and WAEC queries.
- This is sample data for local testing; adapt ids and fields to match your production data.
