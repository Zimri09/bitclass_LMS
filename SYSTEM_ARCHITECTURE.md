# BitClass LMS — System Architecture

---

## 1. Architectural Pattern — 3-Layer Feature-First Architecture

Each feature follows the same 3-layer structure:

```
lib/
├── core/                        # Shared infrastructure
│   ├── config/                  # Environment (demo/dev/prod)
│   ├── router/                  # GoRouter navigation
│   ├── theme/                   # Dark theme, colors, typography
│   ├── constants/               # App-wide constants
│   ├── bloc/                    # BlocObserver (debug logging)
│   └── utils/                   # Helpers / seed data
│
├── features/                    # One folder per feature
│   └── [feature]/
│       ├── data/
│       │   ├── models/          # Data models (JSON ↔ Dart)
│       │   └── repositories/    # Data access (Supabase or mock)
│       └── presentation/
│           ├── bloc/ or cubit/  # State management
│           ├── screens/         # UI pages
│           └── widgets/         # Feature-specific widgets
│
└── shared/
    └── widgets/                 # Reusable UI components
```

---

## 2. Technology Stack

| Layer                  | Technology                                           | Purpose                                                                     |
|------------------------|------------------------------------------------------|-----------------------------------------------------------------------------|
| UI Framework           | Flutter (Dart, SDK ^3.10.1)                          | Cross-platform app (Android, iOS, Web, Windows, macOS, Linux)               |
| State Management       | Bloc / Cubit (flutter_bloc ^8.1.6)                   | Predictable, event-driven UI state                                          |
| Navigation             | GoRouter (^14.6.2)                                   | Declarative routing + auth-aware redirect guards                            |
| Backend (Auth)         | Supabase Auth                                        | Email/password + OTP sign-in, session management, JWT tokens                |
| Backend (Database)     | Supabase PostgreSQL                                  | All persistent data: courses, lessons, quizzes, assignments, grades, etc.   |
| Backend (Storage)      | Supabase Storage (bitclass_storage)                  | File uploads, course materials, avatars                                     |
| Local Cache            | Hive (^2.2.3)                                        | Offline persistence, settings, caching                                      |
| Push Notifications     | Firebase Messaging (FCM) + flutter_local_notifications | Push delivery (currently stubbed)                                         |
| HTTP Client            | Dio (^5.8.0)                                         | Additional HTTP requests where needed                                       |

---

## 3. System Context Diagram

```
+--------------------------------------------------+
|                BitClass Flutter App              |
|                                                  |
|  +--------------+   +--------------+             |
|  |  Instructor  |   |   Student    |             |
|  |   (Role)     |   |   (Role)     |             |
|  +------+-------+   +------+-------+             |
|         |    GoRouter       |                    |
|         v                  v                    |
|  +------------------------------------------+   |
|  |          Presentation Layer              |   |
|  |  Screens -> Bloc/Cubit -> Events/States  |   |
|  +--------------+---------------------------+   |
|                 |                               |
|  +--------------v---------------------------+   |
|  |           Data Layer                    |   |
|  |  Repositories -> Models -> Supabase SDK |   |
|  +--------------+---------------------------+   |
|                 |                               |
|  +--------------v---------------------------+   |
|  |         Local Cache (Hive)              |   |
|  +------------------------------------------+   |
+--------------------+-----------------------------+
                     | HTTPS
        +------------v---------------------------+
        |          Supabase Cloud                |
        |  +--------+ +------+ +--------+        |
        |  |  Auth  | |  DB  | |Storage |        |
        |  | (JWT)  | | (PG) | | (Files)|        |
        |  +--------+ +------+ +--------+        |
        |  Row-Level Security (RLS)              |
        +------------------------------------------+
                     |
        +------------v--------------------------+
        |  Firebase Cloud Messaging             |
        |  (Push Notifications -- stubbed)      |
        +----------------------------------------+
```

---

## 4. Key Architectural Decisions

| Decision                | Detail                                                                                                                                   |
|-------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| Role-based access       | Two roles — instructor and student — enforced at the router level (GoRouter guards) and at the database level (Supabase RLS policies).   |
| Repository pattern      | Each feature has its own repository that abstracts Supabase queries; the same repository returns mock data in demo mode.                 |
| Environment switching   | A single EnvironmentConfig constant switches between demo, development, and production without code changes.                              |
| Demo mode               | The entire app works with local mock data when Environment.demo is selected — no backend required.                                       |
| Dependency injection    | Repositories are injected via RepositoryProvider (Flutter Bloc), Blocs/Cubits via BlocProvider, both provided at the root main.dart.    |
| Composite repositories  | GradeRepository and ClassRecordRepository aggregate data from multiple other repositories (course, quiz, assignment, attendance).         |

---

## 5. Data Flow

Every feature follows this exact pattern:

    Screen --event--> Bloc/Cubit --calls--> Repository --query--> Supabase
      <--state-------------------------------<-----------<--result--

---

## 6. Feature Modules

All 13 features follow the 3-layer pattern listed above:

1.  auth             — Login, register, OTP, forgot/reset password
2.  courses          — Catalog, course detail, create/edit, enrollment, student list
3.  lessons          — Lesson viewer, lesson editor, progress tracking
4.  assignments      — Assignment list, code editor submission, grading screen
5.  quizzes          — Quiz taking, quiz editor, auto-grading
6.  discussions      — Channels, thread list, thread detail, replies, reactions
7.  files            — File list, upload, offline files, download
8.  grades           — Grade overview across assignments and quizzes
9.  notifications    — Notification list, settings, push notification service
10. attendance       — Attendance tracking screen and session management
11. class_records    — Course records aggregating grades and attendance
12. todos            — Personal task list per user
13. profile          — View and edit user profile
14. settings         — App preferences, theme, notification preferences

---

## 7. Database Security (Supabase RLS)

Row-Level Security policies are applied on every table so that:

- Unauthenticated users cannot read any protected data.
- Students can only read data for courses they are enrolled in.
- Students cannot write course content, grade work, or access another student's submission.
- Instructors can manage only courses they own.
- File access, discussion access, and lesson progress all require enrollment verification.

Key migration files (applied in order):
  schema.sql → setup_storage.sql → harden_rls.sql → restrict_course_access.sql
  → fix_file_metadata_policy.sql → harden_submission_rls.sql

---

## 8. Platforms Supported

- Android
- iOS
- Web
- Windows
- macOS
- Linux
