 # BitClass

A dark-themed, developer-focused Learning Management System (LMS) for Computer Science students and instructors.

## Features

- 🔐 **Authentication** - Email/password auth with role-based access (Student/Instructor)
- 📚 **Course Management** - Browse, create, and manage programming courses
- 📖 **Lessons** - Markdown-based content with syntax-highlighted code blocks
- ✏️ **Assignments** - Code-based submissions with built-in editor
- 📝 **Quizzes** - Multiple choice with code snippet support
- 💬 **Discussions** - Channel-based forums per course
- � **Notifications** - Push notification settings and notification list- 📁 **File Upload** - Course materials upload with filtering and search- �📊 **Progress Tracking** - Visual progress bars and grade overview
- 🌙 **Dark Theme** - Code-editor inspired UI with neon accents

## Tech Stack

- **Flutter** - Cross-platform UI framework
- **Firebase** - Authentication, Firestore, Storage
- **Bloc** - State management
- **GoRouter** - Declarative routing
- **Hive** - Local caching

## Getting Started

### Prerequisites

- Flutter SDK 3.10+
- Firebase CLI
- A Firebase project

### Setup

1. **Clone and install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Configure Firebase:**
   ```bash
   # Install FlutterFire CLI
   dart pub global activate flutterfire_cli
   
   # Configure Firebase for your project
   flutterfire configure
   ```

3. **Set up Firestore Security Rules:**
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{uid} {
         allow read, write: if request.auth.uid == uid;
       }
       match /courses/{courseId} {
         allow read: if request.auth != null;
         allow create: if request.auth != null && 
           get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'instructor';
         allow update, delete: if resource.data.instructorId == request.auth.uid;
         
         match /enrollments/{enrollmentId} {
           allow read: if request.auth != null;
           allow create: if request.auth.uid == request.resource.data.userId;
           allow update: if request.auth.uid == resource.data.userId;
         }
       }
     }
   }
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── core/
│   ├── bloc/           # Bloc observer
│   ├── constants/      # App constants, Firebase paths
│   ├── router/         # GoRouter configuration
│   └── theme/          # Dark theme, colors, typography
├── features/
│   ├── assignments/    # Assignment submission with code editor
│   ├── auth/           # Authentication (login, register)
│   ├── courses/        # Course catalog, detail, creation
│   ├── dashboard/      # Main dashboard
│   ├── discussions/    # Discussion forums with channels
│   ├── files/          # File upload and course materials
│   ├── lessons/        # Lesson content with Markdown
│   ├── notifications/  # Push notification management
│   ├── quizzes/        # Quiz taking system
│   └── profile/        # User profile
├── shared/
│   └── widgets/        # Reusable components
└── main.dart           # Entry point
```

## Screens

| Screen | Route | Description |
|--------|-------|-------------|
| Login | `/login` | Sign in with email/password |
| Register | `/register` | Create account with role selection |
| Dashboard | `/dashboard` | Overview, quick actions, activity |
| Course Catalog | `/courses` | Browse all published courses |
| Course Detail | `/courses/:id` | Course info, enrollment, content |
| My Courses | `/my-courses` | Instructor's created courses |
| Enrolled Courses | `/enrolled-courses` | Student's enrolled courses |
| Lesson | `/courses/:id/lessons/:lessonId` | Lesson content with Markdown |
| Quiz | `/courses/:id/quizzes/:quizId` | Take a quiz |
| Assignments | `/courses/:id/assignments` | List of course assignments |
| Assignment | `/courses/:id/assignments/:assignmentId` | Submit code for assignment |
| Discussions | `/courses/:id/discussions` | Discussion channels for course |
| Channel | `/courses/:id/discussions/:channelId` | Thread list in channel |
| Thread | `/courses/:id/discussions/:channelId/threads/:threadId` | Thread with replies |
| Notifications | `/notifications` | View all notifications |
| Notification Settings | `/notifications/settings` | Configure notification preferences |
| Course Files | `/courses/:id/files` | Browse and download course materials |
| Upload File | `/courses/:id/files/upload` | Upload new course materials |
| Profile | `/profile` | View and edit profile |

## Next Steps

Phase 1 foundation is complete. Lessons, Quizzes, Assignments, and Discussions are now fully implemented.

### Completed
- [x] Lesson content pages with Markdown rendering
- [x] Quiz creation and taking system
- [x] Assignment submission with code editor
- [x] Discussion forums with channels
- [x] Push notification system with settings
- [x] File upload for course materials

All planned features have been implemented! 🎉

## License

MIT
