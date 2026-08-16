part of '../repositories/assignment_repository.dart';

extension _AssignmentDemoData on AssignmentRepository {
  void _initDemoData() {
    // Flutter Course Assignments
    _assignments['assignment-flutter-1'] = AssignmentModel(
      id: 'assignment-flutter-1',
      courseId: 'course-1',
      lessonId: 'lesson-1-3-1',
      title: 'Build a Counter App',
      description: 'Create a simple counter application using Flutter widgets',
      instructions: '''
# Counter App Assignment

## Objective
Build a simple counter application that demonstrates your understanding of Flutter's StatefulWidget.

## Requirements
1. Display a counter value starting at 0
2. Include a **+** button that increments the counter
3. Include a **-** button that decrements the counter
4. The counter should not go below 0
5. Style the app with a dark theme

## Hints
- Use `StatefulWidget` for managing state
- Use `setState()` to update the counter value
- Consider using `FloatingActionButton` for the buttons

## Submission
Submit your `main.dart` file with the complete counter app implementation.
''',
      language: ProgrammingLanguage.dart,
      starterCode: '''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Counter App',
      theme: ThemeData.dark(),
      home: const CounterPage(),
    );
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  // TODO: Add counter variable

  // TODO: Add increment method

  // TODO: Add decrement method

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Counter App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // TODO: Display counter value
            const Text(
              '0',
              style: TextStyle(fontSize: 48),
            ),
          ],
        ),
      ),
      // TODO: Add floating action buttons
    );
  }
}
''',
      maxPoints: 100,
      dueDate: DateTime.now().add(const Duration(days: 7)),
      allowLateSubmission: true,
      latePenaltyPercent: 10,
      isPublished: true,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    );

    _assignments['assignment-flutter-2'] = AssignmentModel(
      id: 'assignment-flutter-2',
      courseId: 'course-1',
      title: 'Todo List App',
      description: 'Build a fully functional todo list application',
      instructions: '''
# Todo List App Assignment

## Objective
Create a todo list application that allows users to add, complete, and delete tasks.

## Requirements
1. Add new todo items via a text input
2. Display all todo items in a list
3. Mark items as complete/incomplete with a checkbox
4. Delete items with a swipe or delete button
5. Show the total count of remaining items

## Bonus Points
- Persist data using SharedPreferences
- Add categories or priority levels
- Implement search/filter functionality

## Submission
Submit your complete project with all Dart files.
''',
      language: ProgrammingLanguage.dart,
      starterCode: '''
import 'package:flutter/material.dart';

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo List',
      theme: ThemeData.dark(),
      home: const TodoListPage(),
    );
  }
}

class TodoItem {
  final String id;
  final String title;
  bool isCompleted;

  TodoItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });
}

class TodoListPage extends StatefulWidget {
  const TodoListPage({super.key});

  @override
  State<TodoListPage> createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  final List<TodoItem> _todos = [];
  final TextEditingController _controller = TextEditingController();

  // TODO: Implement add todo method

  // TODO: Implement toggle complete method

  // TODO: Implement delete todo method

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo List'),
      ),
      body: Column(
        children: [
          // TODO: Add input field for new todos
          // TODO: Display list of todos
        ],
      ),
    );
  }
}
''',
      maxPoints: 150,
      dueDate: DateTime.now().add(const Duration(days: 14)),
      allowLateSubmission: true,
      latePenaltyPercent: 15,
      isPublished: true,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    );

    _assignments['assignment-dart-1'] = AssignmentModel(
      id: 'assignment-dart-1',
      courseId: 'course-2',
      lessonId: 'lesson-2-1-1',
      title: 'Async Data Fetcher',
      description:
          'Implement an async function that fetches and processes data',
      instructions: '''
# Async Data Fetcher Assignment

## Objective
Practice Dart async/await by building a data-fetching function.

## Requirements
Write a function `fetchUserData(int userId)` that:
1. Returns a `Future<Map<String, dynamic>>`
2. Simulates a network delay of 1 second using `Future.delayed`
3. Returns user data for valid IDs (1–5)
4. Throws an `Exception` for invalid IDs

## Example
```dart
final user = await fetchUserData(1);
print(user); // {id: 1, name: 'Alice', email: 'alice@example.com'}

await fetchUserData(99); // throws Exception('User not found')
```

## Testing
Your solution will be tested with valid and invalid user IDs.
''',
      language: ProgrammingLanguage.dart,
      starterCode: '''
Future<Map<String, dynamic>> fetchUserData(int userId) async {
  // TODO: Simulate a 1-second network delay
  // TODO: Return user data for IDs 1-5
  // TODO: Throw an Exception for invalid IDs
  throw UnimplementedError();
}

void main() async {
  try {
    final user = await fetchUserData(1);
    print('Got user: \$user');

    final invalid = await fetchUserData(99);
    print(invalid);
  } catch (e) {
    print('Error: \$e');
  }
}
''',
      maxPoints: 50,
      dueDate: DateTime.now().add(const Duration(days: 3)),
      allowLateSubmission: false,
      isPublished: true,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    );

    _submissionsByAssignment['assignment-flutter-1'] = [
      SubmissionModel(
        id: 'submission-1',
        assignmentId: 'assignment-flutter-1',
        courseId: 'course-1',
        userId: AssignmentRepository._demoStudentUserId,
        userDisplayName: 'Demo Student',
        code: '''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Counter App',
      theme: ThemeData.dark(),
      home: const CounterPage(),
    );
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int _counter = 0;

  void _increment() {
    setState(() {
      _counter++;
    });
  }

  void _decrement() {
    setState(() {
      if (_counter > 0) {
        _counter--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Counter App'),
      ),
      body: Center(
        child: Text(
          '\$_counter',
          style: TextStyle(fontSize: 48),
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _decrement,
            child: Icon(Icons.remove),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            onPressed: _increment,
            child: Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
''',
        status: SubmissionStatus.graded,
        score: 92,
        feedback: 'Great work on state management and clean widget structure.',
        gradedBy: 'demo-instructor-1',
        gradedAt: DateTime.now().subtract(const Duration(hours: 1)),
        isLate: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];

    _submissionsByUser[AssignmentRepository._demoStudentUserId] = {
      'assignment-flutter-1':
          _submissionsByAssignment['assignment-flutter-1']!.first,
    };
    _submissionsByUser[AssignmentRepository._legacyDemoStudentUserId] = {
      'assignment-flutter-1':
          _submissionsByAssignment['assignment-flutter-1']!.first,
    };
  }
}
