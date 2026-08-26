# BitClass project structure

BitClass uses a feature-first structure. Code should be grouped by the product
feature it supports, not by the application's user roles.

```text
lib/
  core/                 App-wide configuration, routing, themes, and utilities
  shared/               Reusable UI and behavior with no feature ownership
  features/
    <feature>/
      data/              Models, data sources, and repository implementations
      presentation/      State, screens, and feature-owned widgets
        bloc/            Bloc, Cubit, events, and states
        screens/         Route-level widgets
        widgets/
          shared/        UI used by both students and instructors
          student/       Student-only UI and workflows
          instructor/    Instructor-only UI and workflows
```

## Placement rules

- Start with the owning feature. Roles are a secondary subdivision inside that
  feature.
- Keep shared student/instructor screens together and extract only the controls
  or sections that differ by role.
- Put a widget in `lib/shared` only when it is useful across multiple features.
- Screens coordinate state and navigation. Reusable visual sections belong in
  `presentation/widgets`.
- Repository files should contain data access behavior. Demo fixtures, sample
  lesson text, and starter-code templates should live in dedicated fixture or
  content files.
- Permissions must be enforced by the backend and database policies. Hiding an
  instructor control in the UI is not authorization.

## Naming

- Route-level widgets end in `Screen`.
- Reusable sections use descriptive names such as `CourseResourceLinks`.
- Role-specific names start with the role only when the behavior is exclusive,
  such as `InstructorContentActions` or `StudentCourseProgressCard`.
- Avoid generic files such as `helpers.dart` or `common.dart`; name files after
  the responsibility they contain.

## Refactoring guideline

Prefer small, behavior-preserving extractions. A screen should generally
coordinate its tabs and state rather than implement every card, dialog, and
role-specific section in the same file.
