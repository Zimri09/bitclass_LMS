# Generate Quiz Questions

Authenticated instructors can generate editable quiz-question drafts from a
PDF or UTF-8 TXT file. The function verifies the instructor role and course
ownership before sending the document to Gemini. It does not save or publish a
quiz.

Generated drafts can contain multiple-choice, true/false, and short-answer
questions. The Flutter editor assigns configurable points by question type and
requires instructors to review the generated answers before publishing.

## Configuration

Set the production secret and optional model override:

```powershell
supabase secrets set GEMINI_API_KEY=your-key
supabase secrets set GEMINI_MODEL=gemini-3.1-flash-lite
```

For local development, copy `supabase/functions/.env.example` to
`supabase/functions/.env`, then set a real key in the untracked file.

## Deploy

Keep JWT verification enabled (the default) and deploy with:

```powershell
supabase functions deploy generate-quiz-questions
```

The first release supports PDF files up to 8 MB and UTF-8 TXT files up to 1 MB.
DOCX and PPTX require a separate trusted text-extraction pipeline and are not
accepted yet.
