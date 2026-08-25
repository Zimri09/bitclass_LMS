# BitClass

A dark-themed, developer-focused Learning Management System (LMS) for Computer Science students and instructors.

## Features

- 🔐 **Authentication** - Email/password auth with role-based access (Student/Instructor)
- 📚 **Course Management** - Browse, create, edit, and manage programming courses
- 📖 **Lessons** - Markdown-based content with syntax-highlighted code blocks
- ✏️ **Assignments** - Code-based submissions with built-in editor and instructor grading
- 📝 **Quizzes** - Multiple choice with code snippet support
- 💬 **Discussions** - Channel-based forums per course
- 🔔 **Notifications** - Push notification settings and notification list
- 📁 **File Upload** - Course materials upload with filtering and search
- 📊 **Grades** - Grade overview across assignments and quizzes
- ✅ **Todos** - Personal task list for students and instructors
- ⚙️ **Settings** - App preferences and account management
- 🌙 **Dark Theme** - Code-editor inspired UI with neon accents

- **Admin Web Dashboard** - Separate role-protected web console for platform oversight

## Tech Stack

- **Flutter** - Cross-platform UI framework
- **Supabase** - Authentication, PostgreSQL database, and Storage
- **Bloc / Cubit** - State management
- **GoRouter** - Declarative routing
- **Hive** - Local caching

## Getting Started

### Prerequisites

- Flutter SDK 3.10+
- A Supabase project (optional — demo mode works without a backend)

### Setup

1. **Clone and install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Choose an environment** with `--dart-define=BITCLASS_ENV=...`:
   - `Environment.demo` — runs with mock data, no backend required
   - `Environment.development` — connects to your Supabase project
   - `Environment.production` — production Supabase credentials

3. **Configure Supabase** (for development/production):
   - Create a project at [supabase.com](https://supabase.com)
   - Run the schema in `supabase/schema.sql` via the Supabase SQL editor
   - Run `supabase/setup_storage.sql` after the schema to create the
     `bitclass_storage` bucket and its upload permissions
   - For an existing project, run `supabase/add_course_code.sql` to enable
     course creation and join-by-code
    - Run `supabase/harden_rls.sql` last to replace legacy policies with the
       enrollment-based access rules used by the app
    - Run `supabase/restrict_course_access.sql` after hardening to require a
      class code before students can view or join a course
    - If an account selected as an instructor is denied course creation, run
      `supabase/fix_instructor_role.sql` with that account's sign-in email
    - If file metadata writes are denied after hardening, run
     `supabase/fix_file_metadata_policy.sql` last and retry the upload
   - Development builds use the checked-in development project by default.
   - Release builds fail closed unless production values are supplied:

     ```bash
     flutter build web --release \
       --dart-define=BITCLASS_ENV=production \
       --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
       --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
     ```

   - Optional bucket overrides are `COURSE_MATERIALS_BUCKET` and
     `COURSE_THUMBNAILS_BUCKET`. Course materials are private and opened with
     short-lived signed URLs; avatars and course thumbnails remain public.

4. **Run the app:**
   ```bash
   flutter run
   ```

### Admin web dashboard

The separate web-only admin application lives in `apps/admin_web` and uses the
same Supabase project. See its [setup and security instructions](apps/admin_web/README.md).

```powershell
cd apps/admin_web
flutter pub get
flutter run -d chrome
```

The admin frontend never contains a Supabase secret or service-role key. Its
routes require a signed-in `profiles.role = 'admin'` account, and database RLS
remains the authorization boundary.

## Project Structure

```
apps/
â””â”€â”€ admin_web/      # Independently deployable Flutter web admin dashboard
lib/
├── core/
│   ├── bloc/           # Bloc observer
│   ├── config/         # Environment and backend configuration
│   ├── constants/      # App constants, database paths
│   ├── router/         # GoRouter configuration
│   ├── theme/          # Dark theme, colors, typography
│   └── utils/          # Seed data and helpers
├── features/
│   ├── assignments/    # Assignment submission with code editor
│   ├── auth/           # Authentication (login, register, forgot password)
│   ├── courses/        # Course catalog, detail, creation
│   ├── dashboard/      # Main dashboard
│   ├── discussions/    # Discussion forums with channels
│   ├── files/          # File upload and course materials
│   ├── grades/         # Grade tracking and overview
│   ├── lessons/        # Lesson content with Markdown
│   ├── notifications/  # Push notification management
│   ├── profile/        # User profile
│   ├── quizzes/        # Quiz taking system
│   ├── settings/       # App settings
│   └── todos/          # Personal task list
├── shared/
│   └── widgets/        # Reusable components
└── main.dart           # Entry point
```

## Screens

| Screen | Route | Description |
|--------|-------|-------------|
| Login | `/login` | Sign in with email/password |
| Register | `/register` | Create account with role selection |
| Forgot Password | `/forgot-password` | Reset password via email |
| Dashboard | `/dashboard` | Overview, quick actions, activity |
| Todos | `/todos` | Personal task list |
| Course Catalog | `/courses` | Browse all published courses |
| Course Detail | `/courses/:courseId` | Course info, enrollment, content |
| Create Course | `/courses/create` | Create a new course (instructor) |
| Edit Course | `/courses/:courseId/edit` | Edit course details (instructor) |
| My Courses | `/my-courses` | Instructor's created courses |
| Enrolled Courses | `/enrolled-courses` | Student's enrolled courses |
| Enrolled Students | `/courses/:courseId/students` | View enrolled students (instructor) |
| Lesson | `/courses/:courseId/lessons/:lessonId` | Lesson content with Markdown |
| Create Lesson | `/courses/:courseId/lessons/create` | Create a new lesson (instructor) |
| Edit Lesson | `/courses/:courseId/lessons/:lessonId/edit` | Edit lesson content (instructor) |
| Quiz | `/courses/:courseId/quizzes/:quizId` | Take a quiz |
| Create Quiz | `/courses/:courseId/quizzes/create` | Create a new quiz (instructor) |
| Assignments | `/courses/:courseId/assignments` | List of course assignments |
| Assignment | `/courses/:courseId/assignments/:assignmentId` | View and submit assignment |
| Create Assignment | `/courses/:courseId/assignments/create` | Create assignment (instructor) |
| Grade Assignment | `/courses/:courseId/assignments/:assignmentId/grade` | Grade student submissions (instructor) |
| Discussions | `/courses/:courseId/discussions` | Discussion channels for course |
| Channel | `/courses/:courseId/discussions/:channelId` | Thread list in channel |
| Thread | `/courses/:courseId/discussions/:channelId/threads/:threadId` | Thread with replies |
| Notifications | `/notifications` | View all notifications |
| Notification Settings | `/notifications/settings` | Configure notification preferences |
| Course Files | `/courses/:courseId/files` | Browse and download course materials |
| Upload File | `/courses/:courseId/files/upload` | Upload new course materials |
| Grades | `/grades` | Grade overview across courses |
| Settings | `/settings` | App preferences and account settings |
| Profile | `/profile` | View and edit profile |

## Status

All planned features have been implemented:

- [x] Lesson content pages with Markdown rendering
- [x] Quiz creation and taking system
- [x] Assignment submission with code editor
- [x] Discussion forums with channels
- [x] Push notification system with settings
- [x] File upload for course materials
- [x] Grade tracking and overview
- [x] Personal todos
- [x] App settings
- [x] Supabase backend integration with demo mode fallback

## License

MIT
