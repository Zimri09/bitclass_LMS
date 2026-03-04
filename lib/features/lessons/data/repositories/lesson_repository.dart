import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/config/environment.dart';
import '../models/models.dart';

/// Repository handling lesson and module operations
class LessonRepository {
  final FirebaseFirestore? _firestore;

  // Demo mode storage
  final List<ModuleModel> _demoModules = [];
  final List<LessonModel> _demoLessons = [];
  final List<LessonProgressModel> _demoProgress = [];

  LessonRepository({FirebaseFirestore? firestore})
    : _firestore = EnvironmentConfig.isDemoMode
          ? null
          : (firestore ?? FirebaseFirestore.instance) {
    if (EnvironmentConfig.isDemoMode) {
      _initDemoData();
    }
  }

  void _initDemoData() {
    final now = DateTime.now();

    // Course 1: Introduction to Flutter - Modules
    _demoModules.addAll([
      ModuleModel(
        id: 'module-1-1',
        courseId: 'course-1',
        title: 'Getting Started',
        description: 'Set up your Flutter development environment',
        order: 0,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      ModuleModel(
        id: 'module-1-2',
        courseId: 'course-1',
        title: 'Dart Fundamentals',
        description: 'Learn the basics of Dart programming language',
        order: 1,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 28)),
      ),
      ModuleModel(
        id: 'module-1-3',
        courseId: 'course-1',
        title: 'Building Your First App',
        description: 'Create a complete Flutter application from scratch',
        order: 2,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 26)),
      ),
    ]);

    // Course 1 Lessons
    _demoLessons.addAll([
      LessonModel(
        id: 'lesson-1-1-1',
        courseId: 'course-1',
        moduleId: 'module-1-1',
        title: 'Installing Flutter SDK',
        description: 'Download and configure Flutter on your machine',
        order: 0,
        type: LessonType.text,
        content: _getFlutterInstallContent(),
        durationMinutes: 15,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      LessonModel(
        id: 'lesson-1-1-2',
        courseId: 'course-1',
        moduleId: 'module-1-1',
        title: 'IDE Setup',
        description: 'Configure VS Code or Android Studio for Flutter',
        order: 1,
        type: LessonType.text,
        content: _getIDESetupContent(),
        durationMinutes: 10,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 29)),
      ),
      LessonModel(
        id: 'lesson-1-2-1',
        courseId: 'course-1',
        moduleId: 'module-1-2',
        title: 'Variables and Types',
        description: 'Understanding Dart type system',
        order: 0,
        type: LessonType.code,
        content: _getDartVariablesContent(),
        durationMinutes: 20,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 28)),
      ),
      LessonModel(
        id: 'lesson-1-2-2',
        courseId: 'course-1',
        moduleId: 'module-1-2',
        title: 'Functions and Classes',
        description: 'Object-oriented programming in Dart',
        order: 1,
        type: LessonType.code,
        content: _getDartFunctionsContent(),
        durationMinutes: 25,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 27)),
      ),
      LessonModel(
        id: 'lesson-1-3-1',
        courseId: 'course-1',
        moduleId: 'module-1-3',
        title: 'Widget Basics',
        description: 'Learn about StatelessWidget and StatefulWidget',
        order: 0,
        type: LessonType.code,
        content: _getWidgetBasicsContent(),
        durationMinutes: 30,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 26)),
      ),
      LessonModel(
        id: 'lesson-1-3-2',
        courseId: 'course-1',
        moduleId: 'module-1-3',
        title: 'Layouts: Row, Column & Stack',
        description: 'Master Flutter layout widgets',
        order: 1,
        type: LessonType.code,
        content: _getLayoutsContent(),
        durationMinutes: 25,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 25)),
      ),
      LessonModel(
        id: 'lesson-1-3-3',
        courseId: 'course-1',
        moduleId: 'module-1-3',
        title: 'Navigation & Routing',
        description: 'Navigate between screens using Navigator and GoRouter',
        order: 2,
        type: LessonType.code,
        content: _getNavigationContent(),
        durationMinutes: 30,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 24)),
      ),
    ]);

    // Course 2: Advanced Dart - Modules
    _demoModules.addAll([
      ModuleModel(
        id: 'module-2-1',
        courseId: 'course-2',
        title: 'Asynchronous Programming',
        description: 'Master async/await, Futures, and Streams',
        order: 0,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 25)),
      ),
      ModuleModel(
        id: 'module-2-2',
        courseId: 'course-2',
        title: 'Generics & Collections',
        description: 'Type-safe data structures in Dart',
        order: 1,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 24)),
      ),
    ]);

    // Course 2 Lessons
    _demoLessons.addAll([
      LessonModel(
        id: 'lesson-2-1-1',
        courseId: 'course-2',
        moduleId: 'module-2-1',
        title: 'Understanding Futures',
        description: 'How asynchronous operations work in Dart',
        order: 0,
        type: LessonType.code,
        content: _getFuturesContent(),
        durationMinutes: 25,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 25)),
      ),
      LessonModel(
        id: 'lesson-2-1-2',
        courseId: 'course-2',
        moduleId: 'module-2-1',
        title: 'Working with Streams',
        description: 'Handle continuous data flows',
        order: 1,
        type: LessonType.code,
        content: _getStreamsContent(),
        durationMinutes: 30,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 24)),
      ),
      LessonModel(
        id: 'lesson-2-2-1',
        courseId: 'course-2',
        moduleId: 'module-2-2',
        title: 'Generic Types',
        description: 'Write reusable, type-safe code',
        order: 0,
        type: LessonType.code,
        content: _getGenericsContent(),
        durationMinutes: 20,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 23)),
      ),
      LessonModel(
        id: 'lesson-2-2-2',
        courseId: 'course-2',
        moduleId: 'module-2-2',
        title: 'Collections & Iterables',
        description: 'Master List, Set, Map and iterable methods',
        order: 1,
        type: LessonType.code,
        content: _getCollectionsContent(),
        durationMinutes: 25,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 22)),
      ),
      LessonModel(
        id: 'lesson-2-1-3',
        courseId: 'course-2',
        moduleId: 'module-2-1',
        title: 'Error Handling & Isolates',
        description: 'Manage exceptions and parallel execution',
        order: 2,
        type: LessonType.code,
        content: _getErrorHandlingContent(),
        durationMinutes: 20,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 21)),
      ),
    ]);

    // Course 3: Data Structures - Modules
    _demoModules.addAll([
      ModuleModel(
        id: 'module-3-1',
        courseId: 'course-3',
        title: 'Arrays and Lists',
        description: 'Fundamental data structures',
        order: 0,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      ModuleModel(
        id: 'module-3-2',
        courseId: 'course-3',
        title: 'Trees and Graphs',
        description: 'Hierarchical and networked data',
        order: 1,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 55)),
      ),
    ]);

    // Course 3 Lessons
    _demoLessons.addAll([
      LessonModel(
        id: 'lesson-3-1-1',
        courseId: 'course-3',
        moduleId: 'module-3-1',
        title: 'Array Operations',
        description: 'Common array algorithms and complexity',
        order: 0,
        type: LessonType.code,
        content: _getArraysContent(),
        durationMinutes: 25,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      LessonModel(
        id: 'lesson-3-2-1',
        courseId: 'course-3',
        moduleId: 'module-3-2',
        title: 'Binary Trees',
        description: 'Tree traversal algorithms',
        order: 0,
        type: LessonType.code,
        content: _getBinaryTreesContent(),
        durationMinutes: 35,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 55)),
      ),
      LessonModel(
        id: 'lesson-3-1-2',
        courseId: 'course-3',
        moduleId: 'module-3-1',
        title: 'Linked Lists',
        description: 'Singly and doubly linked list implementations',
        order: 1,
        type: LessonType.code,
        content: _getLinkedListContent(),
        durationMinutes: 30,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 54)),
      ),
      LessonModel(
        id: 'lesson-3-2-2',
        courseId: 'course-3',
        moduleId: 'module-3-2',
        title: 'Hash Maps & Sets',
        description: 'Hashing, collision resolution, and Dart implementations',
        order: 1,
        type: LessonType.code,
        content: _getHashMapContent(),
        durationMinutes: 25,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 53)),
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Demo Content Generators
  // ═══════════════════════════════════════════════════════════════════════════

  String _getFlutterInstallContent() => '''
# Installing Flutter SDK

Welcome to your first lesson! Let's get Flutter set up on your machine.

## Prerequisites

Before installing Flutter, ensure you have:
- **Windows**: Windows 10 or later (64-bit)
- **macOS**: macOS 10.14 or later
- **Linux**: Ubuntu 20.04 or similar

## Step 1: Download Flutter

Visit the official Flutter website and download the SDK:

```bash
# On macOS/Linux, you can use:
git clone https://github.com/flutter/flutter.git -b stable

# Or download from:
# https://flutter.dev/docs/get-started/install
```

## Step 2: Add to PATH

Add Flutter to your system PATH:

```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="\$PATH:\$HOME/flutter/bin"
```

## Step 3: Run Flutter Doctor

Verify your installation:

```bash
flutter doctor
```

This command checks your environment and displays a report:

```
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.10.0)
[✓] Android toolchain
[✓] Chrome - develop for the web
[✓] VS Code
[✓] Connected device
• No issues found!
```

## What's Next?

In the next lesson, we'll configure your IDE for the best Flutter development experience.
''';

  String _getIDESetupContent() => '''
# IDE Setup for Flutter

A good IDE makes Flutter development a breeze. Let's set up VS Code.

## VS Code Setup

### 1. Install Extensions

Install these essential extensions:

| Extension | Purpose |
|-----------|---------|
| **Flutter** | Flutter support |
| **Dart** | Dart language support |
| **Error Lens** | Inline error display |
| **Bracket Pair Colorizer** | Better code readability |

### 2. Configure Settings

Add to your `settings.json`:

```json
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": true,
    "source.organizeImports": true
  },
  "dart.previewFlutterUiGuides": true,
  "[dart]": {
    "editor.tabSize": 2,
    "editor.insertSpaces": true
  }
}
```

### 3. Useful Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+Shift+P` | Command palette |
| `F5` | Start debugging |
| `Ctrl+.` | Quick fixes |
| `Ctrl+Space` | IntelliSense |

## Create Your First Project

```bash
flutter create my_first_app
cd my_first_app
flutter run
```

You should see the Flutter demo app running!
''';

  String _getDartVariablesContent() => '''
# Variables and Types in Dart

Dart is a statically typed language with powerful type inference.

## Variable Declaration

```dart
// Type inference with var
var name = 'Alice';      // Inferred as String
var age = 25;            // Inferred as int
var height = 1.75;       // Inferred as double

// Explicit types
String greeting = 'Hello';
int count = 42;
double price = 19.99;
bool isActive = true;
```

## Final and Const

Use `final` for runtime constants and `const` for compile-time constants:

```dart
// final - set once at runtime
final DateTime now = DateTime.now();
final List<String> items = ['a', 'b', 'c'];

// const - compile-time constant
const int maxItems = 100;
const String apiUrl = 'https://api.example.com';
```

## Null Safety

Dart has sound null safety. Variables are non-nullable by default:

```dart
// Non-nullable (cannot be null)
String name = 'Alice';

// Nullable (can be null)
String? nickname;

// Null-aware operators
String displayName = nickname ?? 'Anonymous';
int? length = nickname?.length;
```

## Collections

```dart
// Lists
List<String> fruits = ['apple', 'banana', 'orange'];
var numbers = [1, 2, 3, 4, 5];

// Maps
Map<String, int> ages = {
  'Alice': 25,
  'Bob': 30,
};

// Sets
Set<int> uniqueNumbers = {1, 2, 3, 4, 5};
```

## Exercise

Try modifying the code below:

```dart
void main() {
  // TODO: Declare a variable for your name
  
  // TODO: Declare your age as an integer
  
  // TODO: Create a list of your favorite programming languages
  
  print('Hello from Dart!');
}
```
''';

  String _getDartFunctionsContent() => '''
# Functions and Classes

Learn to write clean, reusable code with Dart functions and classes.

## Functions

```dart
// Basic function
int add(int a, int b) {
  return a + b;
}

// Arrow syntax for single expressions
int multiply(int a, int b) => a * b;

// Optional parameters
void greet(String name, [String? greeting]) {
  print('\${greeting ?? 'Hello'}, \$name!');
}

// Named parameters
void createUser({
  required String name,
  required String email,
  int age = 0,
}) {
  print('User: \$name, \$email, \$age');
}
```

## Classes

```dart
class Person {
  // Properties
  final String name;
  int age;
  
  // Constructor
  Person(this.name, this.age);
  
  // Named constructor
  Person.guest() : name = 'Guest', age = 0;
  
  // Method
  void introduce() {
    print('Hi, I\\'m \$name and I\\'m \$age years old.');
  }
  
  // Getter
  bool get isAdult => age >= 18;
  
  // Setter
  set birthYear(int year) {
    age = DateTime.now().year - year;
  }
}
```

## Inheritance

```dart
class Animal {
  final String name;
  
  Animal(this.name);
  
  void speak() => print('\$name makes a sound');
}

class Dog extends Animal {
  Dog(String name) : super(name);
  
  @override
  void speak() => print('\$name barks!');
}

class Cat extends Animal {
  Cat(String name) : super(name);
  
  @override
  void speak() => print('\$name meows!');
}
```

## Abstract Classes and Interfaces

```dart
abstract class Shape {
  double get area;
  double get perimeter;
}

class Rectangle implements Shape {
  final double width;
  final double height;
  
  Rectangle(this.width, this.height);
  
  @override
  double get area => width * height;
  
  @override
  double get perimeter => 2 * (width + height);
}
```
''';

  String _getWidgetBasicsContent() => '''
# Widget Basics

Everything in Flutter is a widget! Let's understand the fundamentals.

## StatelessWidget

Use when your widget doesn't need to maintain state:

```dart
class GreetingCard extends StatelessWidget {
  final String name;
  
  const GreetingCard({super.key, required this.name});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('Hello, \$name!'),
      ),
    );
  }
}
```

## StatefulWidget

Use when your widget needs to maintain and update state:

```dart
class Counter extends StatefulWidget {
  const Counter({super.key});
  
  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int _count = 0;
  
  void _increment() {
    setState(() {
      _count++;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Count: \$_count'),
        ElevatedButton(
          onPressed: _increment,
          child: const Text('Increment'),
        ),
      ],
    );
  }
}
```

## Common Layout Widgets

```dart
// Column - Vertical layout
Column(
  children: [
    Text('Item 1'),
    Text('Item 2'),
    Text('Item 3'),
  ],
)

// Row - Horizontal layout
Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    Icon(Icons.star),
    Icon(Icons.star),
    Icon(Icons.star),
  ],
)

// Container - Decoration & sizing
Container(
  width: 200,
  height: 100,
  decoration: BoxDecoration(
    color: Colors.blue,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Center(
    child: Text('Styled Container'),
  ),
)
```

## Widget Tree Example

```dart
MaterialApp(
  home: Scaffold(
    appBar: AppBar(
      title: Text('My App'),
    ),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Welcome to Flutter!'),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {},
            child: Text('Get Started'),
          ),
        ],
      ),
    ),
  ),
)
```
''';

  String _getFuturesContent() => '''
# Understanding Futures

Futures represent values that will be available in the future.

## Basic Future

```dart
Future<String> fetchUserName() async {
  // Simulate network delay
  await Future.delayed(Duration(seconds: 2));
  return 'Alice';
}

// Using async/await
void main() async {
  print('Fetching user...');
  String name = await fetchUserName();
  print('Hello, \$name!');
}

// Using .then()
void main() {
  print('Fetching user...');
  fetchUserName().then((name) {
    print('Hello, \$name!');
  });
}
```

## Error Handling

```dart
Future<User> fetchUser(int id) async {
  final response = await http.get(Uri.parse('/users/\$id'));
  
  if (response.statusCode != 200) {
    throw Exception('Failed to fetch user');
  }
  
  return User.fromJson(jsonDecode(response.body));
}

// Handling errors with try/catch
void main() async {
  try {
    final user = await fetchUser(1);
    print('User: \${user.name}');
  } catch (e) {
    print('Error: \$e');
  }
}

// Handling errors with .catchError()
fetchUser(1)
  .then((user) => print('User: \${user.name}'))
  .catchError((e) => print('Error: \$e'));
```

## Parallel Execution

```dart
// Run multiple futures in parallel
Future<void> loadDashboard() async {
  final results = await Future.wait([
    fetchUser(),
    fetchPosts(),
    fetchNotifications(),
  ]);
  
  final user = results[0] as User;
  final posts = results[1] as List<Post>;
  final notifications = results[2] as List<Notification>;
  
  // Use the results...
}
```

## FutureBuilder in Flutter

```dart
FutureBuilder<User>(
  future: fetchUser(1),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return CircularProgressIndicator();
    }
    
    if (snapshot.hasError) {
      return Text('Error: \${snapshot.error}');
    }
    
    final user = snapshot.data!;
    return Text('Hello, \${user.name}!');
  },
)
```
''';

  String _getStreamsContent() => '''
# Working with Streams

Streams provide a sequence of asynchronous events.

## Stream Basics

```dart
// Creating a stream
Stream<int> countStream(int max) async* {
  for (int i = 1; i <= max; i++) {
    await Future.delayed(Duration(seconds: 1));
    yield i;
  }
}

// Listening to a stream
void main() async {
  await for (final count in countStream(5)) {
    print('Count: \$count');
  }
  print('Done!');
}
```

## StreamController

```dart
class ChatService {
  final _messageController = StreamController<Message>.broadcast();
  
  Stream<Message> get messages => _messageController.stream;
  
  void sendMessage(Message message) {
    _messageController.add(message);
  }
  
  void dispose() {
    _messageController.close();
  }
}
```

## Stream Transformations

```dart
Stream<int> numbers = Stream.fromIterable([1, 2, 3, 4, 5]);

// Map - transform each value
numbers.map((n) => n * 2); // [2, 4, 6, 8, 10]

// Where - filter values
numbers.where((n) => n.isEven); // [2, 4]

// Take - limit number of events
numbers.take(3); // [1, 2, 3]

// Distinct - remove duplicates
numbers.distinct();
```

## StreamBuilder in Flutter

```dart
StreamBuilder<List<Message>>(
  stream: chatService.messages,
  builder: (context, snapshot) {
    if (snapshot.hasError) {
      return Text('Error: \${snapshot.error}');
    }
    
    if (!snapshot.hasData) {
      return CircularProgressIndicator();
    }
    
    final messages = snapshot.data!;
    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) {
        return MessageTile(message: messages[index]);
      },
    );
  },
)
```

## BLoC Pattern with Streams

```dart
class CounterBloc {
  int _counter = 0;
  
  final _counterController = StreamController<int>.broadcast();
  
  Stream<int> get counterStream => _counterController.stream;
  
  void increment() {
    _counter++;
    _counterController.add(_counter);
  }
  
  void decrement() {
    _counter--;
    _counterController.add(_counter);
  }
  
  void dispose() {
    _counterController.close();
  }
}
```
''';

  String _getGenericsContent() => '''
# Generic Types

Generics allow you to write flexible, reusable code while maintaining type safety.

## Basic Generics

```dart
// Generic class
class Box<T> {
  final T value;
  
  Box(this.value);
  
  T get() => value;
}

// Usage
final intBox = Box<int>(42);
final stringBox = Box<String>('Hello');

print(intBox.get());       // 42
print(stringBox.get());    // Hello
```

## Generic Functions

```dart
T first<T>(List<T> items) {
  return items[0];
}

// Type is inferred
String firstString = first(['a', 'b', 'c']); // 'a'
int firstNumber = first([1, 2, 3]);          // 1
```

## Type Constraints

```dart
// T must extend Comparable
class SortedList<T extends Comparable<T>> {
  final List<T> _items = [];
  
  void add(T item) {
    _items.add(item);
    _items.sort();
  }
  
  List<T> get items => List.unmodifiable(_items);
}

// Usage
final numbers = SortedList<int>();
numbers.add(3);
numbers.add(1);
numbers.add(2);
print(numbers.items); // [1, 2, 3]
```

## Multiple Type Parameters

```dart
class Pair<K, V> {
  final K key;
  final V value;
  
  Pair(this.key, this.value);
  
  @override
  String toString() => 'Pair(\$key: \$value)';
}

// Usage
final pair = Pair<String, int>('age', 25);
print(pair); // Pair(age: 25)
```

## Generic Repository Pattern

```dart
abstract class Repository<T, ID> {
  Future<T?> findById(ID id);
  Future<List<T>> findAll();
  Future<T> save(T entity);
  Future<void> delete(ID id);
}

class UserRepository implements Repository<User, String> {
  @override
  Future<User?> findById(String id) async {
    // Implementation...
  }
  
  @override
  Future<List<User>> findAll() async {
    // Implementation...
  }
  
  @override
  Future<User> save(User entity) async {
    // Implementation...
  }
  
  @override
  Future<void> delete(String id) async {
    // Implementation...
  }
}
```
''';

  String _getArraysContent() => '''
# Array Operations

Master fundamental array algorithms and understand their complexity.

## Basic Operations

```dart
List<int> numbers = [5, 2, 8, 1, 9, 3];

// Access - O(1)
int first = numbers[0];
int last = numbers[numbers.length - 1];

// Search - O(n)
bool contains = numbers.contains(8);
int index = numbers.indexOf(8);

// Insert - O(n) worst case
numbers.add(10);           // O(1) amortized
numbers.insert(0, 0);      // O(n)

// Remove - O(n)
numbers.remove(5);
numbers.removeAt(0);
```

## Sorting Algorithms

```dart
// Built-in sort - O(n log n)
List<int> numbers = [5, 2, 8, 1, 9];
numbers.sort();
print(numbers); // [1, 2, 5, 8, 9]

// Custom comparator
List<String> names = ['Charlie', 'Alice', 'Bob'];
names.sort((a, b) => a.length.compareTo(b.length));

// Bubble Sort - O(n²) - Educational only!
void bubbleSort(List<int> arr) {
  for (int i = 0; i < arr.length - 1; i++) {
    for (int j = 0; j < arr.length - i - 1; j++) {
      if (arr[j] > arr[j + 1]) {
        // Swap
        int temp = arr[j];
        arr[j] = arr[j + 1];
        arr[j + 1] = temp;
      }
    }
  }
}
```

## Binary Search - O(log n)

```dart
int binarySearch(List<int> arr, int target) {
  int left = 0;
  int right = arr.length - 1;
  
  while (left <= right) {
    int mid = left + (right - left) ~/ 2;
    
    if (arr[mid] == target) {
      return mid;
    } else if (arr[mid] < target) {
      left = mid + 1;
    } else {
      right = mid - 1;
    }
  }
  
  return -1; // Not found
}

// Usage
List<int> sorted = [1, 3, 5, 7, 9, 11, 13];
int index = binarySearch(sorted, 7); // 3
```

## Two Pointer Technique

```dart
// Find pair that sums to target
List<int>? twoSum(List<int> sorted, int target) {
  int left = 0;
  int right = sorted.length - 1;
  
  while (left < right) {
    int sum = sorted[left] + sorted[right];
    
    if (sum == target) {
      return [sorted[left], sorted[right]];
    } else if (sum < target) {
      left++;
    } else {
      right--;
    }
  }
  
  return null; // No pair found
}
```

## Time Complexity Summary

| Operation | Array | Sorted Array |
|-----------|-------|--------------|
| Access    | O(1)  | O(1)         |
| Search    | O(n)  | O(log n)     |
| Insert    | O(n)  | O(n)         |
| Delete    | O(n)  | O(n)         |
''';

  String _getBinaryTreesContent() => '''
# Binary Trees

Understand tree structures and traversal algorithms.

## Tree Node Definition

```dart
class TreeNode<T> {
  T value;
  TreeNode<T>? left;
  TreeNode<T>? right;
  
  TreeNode(this.value, {this.left, this.right});
}

// Create a tree:
//       1
//      / \\
//     2   3
//    / \\
//   4   5

TreeNode<int> root = TreeNode(1,
  left: TreeNode(2,
    left: TreeNode(4),
    right: TreeNode(5),
  ),
  right: TreeNode(3),
);
```

## Tree Traversals

```dart
class BinaryTree<T> {
  TreeNode<T>? root;
  
  // In-order: Left -> Root -> Right
  List<T> inOrder() {
    List<T> result = [];
    void traverse(TreeNode<T>? node) {
      if (node == null) return;
      traverse(node.left);
      result.add(node.value);
      traverse(node.right);
    }
    traverse(root);
    return result;
  }
  
  // Pre-order: Root -> Left -> Right
  List<T> preOrder() {
    List<T> result = [];
    void traverse(TreeNode<T>? node) {
      if (node == null) return;
      result.add(node.value);
      traverse(node.left);
      traverse(node.right);
    }
    traverse(root);
    return result;
  }
  
  // Post-order: Left -> Right -> Root
  List<T> postOrder() {
    List<T> result = [];
    void traverse(TreeNode<T>? node) {
      if (node == null) return;
      traverse(node.left);
      traverse(node.right);
      result.add(node.value);
    }
    traverse(root);
    return result;
  }
}
```

## Level-Order Traversal (BFS)

```dart
List<T> levelOrder() {
  if (root == null) return [];
  
  List<T> result = [];
  Queue<TreeNode<T>> queue = Queue();
  queue.add(root!);
  
  while (queue.isNotEmpty) {
    TreeNode<T> node = queue.removeFirst();
    result.add(node.value);
    
    if (node.left != null) queue.add(node.left!);
    if (node.right != null) queue.add(node.right!);
  }
  
  return result;
}
```

## Binary Search Tree

```dart
class BST {
  TreeNode<int>? root;
  
  void insert(int value) {
    root = _insert(root, value);
  }
  
  TreeNode<int> _insert(TreeNode<int>? node, int value) {
    if (node == null) return TreeNode(value);
    
    if (value < node.value) {
      node.left = _insert(node.left, value);
    } else if (value > node.value) {
      node.right = _insert(node.right, value);
    }
    
    return node;
  }
  
  bool search(int value) {
    TreeNode<int>? current = root;
    
    while (current != null) {
      if (value == current.value) return true;
      if (value < current.value) {
        current = current.left;
      } else {
        current = current.right;
      }
    }
    
    return false;
  }
}
```

## Tree Properties

| Property | Formula |
|----------|---------|
| Max nodes at level L | 2^L |
| Max nodes in tree of height H | 2^(H+1) - 1 |
| Min height for N nodes | log₂(N+1) - 1 |
''';

  String _getFlutterFireContent() => '''
# FlutterFire CLI Setup

Learn to set up Firebase quickly using the FlutterFire CLI.

## Prerequisites

1. **Firebase CLI** installed globally

```bash
npm install -g firebase-tools
```

2. **FlutterFire CLI** installed

```bash
dart pub global activate flutterfire_cli
```

3. **Firebase account** with a project created

## Step 1: Login to Firebase

```bash
firebase login
```

This opens a browser for authentication.

## Step 2: Configure Project

Run from your Flutter project root:

```bash
flutterfire configure
```

This will:
1. List your Firebase projects
2. Let you select platforms (iOS, Android, Web, macOS)
3. Generate `firebase_options.dart`
4. Update native configuration files

## Step 3: Add Dependencies

```yaml
# pubspec.yaml
dependencies:
  firebase_core: ^2.24.0
  firebase_auth: ^4.16.0
  cloud_firestore: ^4.14.0
```

Then run:

```bash
flutter pub get
```

## Step 4: Initialize Firebase

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(MyApp());
}
```

## Project Structure

After configuration, your project will have:

```
lib/
  firebase_options.dart    # Generated config
  main.dart               # Initialize here
  
android/
  app/
    google-services.json  # Android config
    
ios/
  Runner/
    GoogleService-Info.plist  # iOS config
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "No Firebase project found" | Run `firebase projects:list` |
| "Configuration failed" | Check internet connection |
| "Platform not supported" | Ensure Flutter platform is enabled |
''';

  String _getFirebaseAuthContent() => '''
# Email Authentication

Implement secure email/password authentication with Firebase Auth.

## Setup

Add the Firebase Auth package:

```yaml
dependencies:
  firebase_auth: ^4.16.0
```

## AuthRepository

```dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Current user
  User? get currentUser => _auth.currentUser;
  
  // Sign up with email/password
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
  
  // Sign in with email/password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
  
  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  // Password reset
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
```

## Error Handling

```dart
try {
  await authRepository.signIn(
    email: email,
    password: password,
  );
} on FirebaseAuthException catch (e) {
  switch (e.code) {
    case 'user-not-found':
      showError('No account found with this email');
      break;
    case 'wrong-password':
      showError('Invalid password');
      break;
    case 'invalid-email':
      showError('Invalid email address');
      break;
    case 'user-disabled':
      showError('This account has been disabled');
      break;
    default:
      showError('Authentication failed');
  }
}
```

## Auth State in UI

```dart
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LoadingScreen();
        }
        
        if (snapshot.hasData) {
          return HomeScreen();
        }
        
        return LoginScreen();
      },
    );
  }
}
```

## Email Verification

```dart
// Send verification email
await currentUser?.sendEmailVerification();

// Check if verified
if (currentUser?.emailVerified ?? false) {
  // User is verified
} else {
  // Prompt to verify email
}
```
''';

  // ── Course 1 new content ───────────────────────────────────────────────

  String _getLayoutsContent() => '''
# Layouts: Row, Column & Stack

Flutter uses a composition-based approach to build UIs. Layout widgets
control how children are sized and positioned.

## Row — Horizontal Layout

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Icon(Icons.star, color: Colors.amber),
    Text('4.8'),
    Text('(128 reviews)'),
  ],
)
```

| Property | Description |
|---|---|
| `mainAxisAlignment` | Horizontal distribution (start, center, spaceBetween…) |
| `crossAxisAlignment` | Vertical alignment within the Row |
| `mainAxisSize` | `MainAxisSize.min` shrinks to children width |

## Column — Vertical Layout

```dart
Column(
  children: [
    Text('Title', style: TextStyle(fontSize: 24)),
    SizedBox(height: 8),
    Text('Subtitle'),
    Spacer(),
    ElevatedButton(onPressed: () {}, child: Text('Continue')),
  ],
)
```

> **Tip:** Use `Spacer()` to push remaining children to the end.

## Stack — Overlapping Widgets

```dart
Stack(
  children: [
    Image.network(url, fit: BoxFit.cover),
    Positioned(
      bottom: 16,
      left: 16,
      child: Text(
        'Overlay',
        style: TextStyle(color: Colors.white, fontSize: 20),
      ),
    ),
  ],
)
```

## Expanded & Flexible

```dart
Row(
  children: [
    Expanded(
      flex: 2,
      child: Container(color: Colors.blue),
    ),
    Expanded(
      flex: 1,
      child: Container(color: Colors.red),
    ),
  ],
)
```

- `Expanded` forces the child to fill remaining space.
- `Flexible` lets the child be *at most* the remaining space.

## Practice Exercise

Build a **profile card** that uses:
1. A `Column` for the overall structure
2. A `Stack` to overlay the user's name on their cover photo
3. A `Row` for stats (posts, followers, following)

```dart
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomLeft,
            children: [
              Container(height: 120, color: Colors.blueGrey),
              Padding(
                padding: EdgeInsets.all(12),
                child: Text('Jane Doe',
                    style: TextStyle(color: Colors.white, fontSize: 22)),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _stat('Posts', '42'),
                _stat('Followers', '1.2k'),
                _stat('Following', '300'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
          Text(label),
        ],
      );
}
```
''';

  String _getNavigationContent() => '''
# Navigation & Routing

Flutter provides imperative (`Navigator`) and declarative (`GoRouter`)
approaches to navigation.

## Navigator 1.0 (Imperative)

### Push a new screen

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const DetailScreen(),
  ),
);
```

### Pop back

```dart
Navigator.of(context).pop();
```

### Push and remove all previous routes

```dart
Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(builder: (_) => const HomeScreen()),
  (route) => false, // removes all
);
```

## GoRouter (Declarative)

GoRouter is the recommended routing package for Flutter.

### Setup

```dart
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/course/:courseId',
      builder: (context, state) {
        final id = state.pathParameters['courseId']!;
        return CourseScreen(courseId: id);
      },
    ),
  ],
);
```

### Navigate

```dart
// Go to a route
context.go('/course/flutter-101');

// Push a route (keeps back stack)
context.push('/course/flutter-101');

// Go back
context.pop();
```

### Passing data via query parameters

```dart
GoRoute(
  path: '/search',
  builder: (context, state) {
    final query = state.uri.queryParameters['q'] ?? '';
    return SearchScreen(query: query);
  },
),

// Navigate with query params
context.go('/search?q=flutter');
```

## Passing data between screens

```dart
// Approach 1: Constructor parameters
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => DetailScreen(item: selectedItem),
  ),
);

// Approach 2: GoRouter extra
context.go('/detail', extra: selectedItem);

// In the destination
final item = GoRouterState.of(context).extra as Item;
```

## Practice Exercise

Create a simple two-screen app with GoRouter:
1. A **ListScreen** showing a list of items
2. A **DetailScreen** showing the selected item
3. Use path parameters to pass the item ID

```dart
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const ListScreen(),
      routes: [
        GoRoute(
          path: 'item/:id',
          builder: (_, state) {
            final id = state.pathParameters['id']!;
            return DetailScreen(itemId: id);
          },
        ),
      ],
    ),
  ],
);
```
''';

  // ── Course 2 new content ───────────────────────────────────────────────

  String _getCollectionsContent() => '''
# Collections & Iterables

Dart ships with three core collection types — `List`, `Set`, and `Map` —
plus a rich set of iterable methods inspired by functional programming.

## List

```dart
final fruits = <String>['apple', 'banana', 'cherry'];

// Add / remove
fruits.add('date');
fruits.removeAt(0); // removes 'apple'

// Access
print(fruits[0]);       // banana
print(fruits.length);   // 3
```

## Set

A Set stores **unique** values.

```dart
final ids = <int>{1, 2, 3, 2, 1};
print(ids); // {1, 2, 3}

ids.add(4);
ids.contains(2); // true
```

## Map

Key-value pairs.

```dart
final scores = <String, int>{
  'Alice': 95,
  'Bob': 87,
  'Carol': 92,
};

scores['Dave'] = 78;
scores.remove('Bob');

for (final entry in scores.entries) {
  print('\${entry.key}: \${entry.value}');
}
```

## Iterable Methods

These methods work on any `Iterable` (List, Set, etc.):

```dart
final numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

// where — filter elements
final evens = numbers.where((n) => n.isEven); // (2, 4, 6, 8, 10)

// map — transform elements
final doubled = numbers.map((n) => n * 2);    // (2, 4, 6, …, 20)

// fold / reduce — accumulate
final sum = numbers.fold(0, (acc, n) => acc + n); // 55
final product = numbers.reduce((a, b) => a * b);  // 3628800

// any / every
numbers.any((n) => n > 9);   // true
numbers.every((n) => n > 0); // true

// firstWhere / singleWhere
final first = numbers.firstWhere((n) => n > 7); // 8
```

## Spread Operator & Collection If/For

```dart
final base = [1, 2, 3];
final extended = [...base, 4, 5]; // [1, 2, 3, 4, 5]

final showAll = true;
final items = [
  'Home',
  'Profile',
  if (showAll) 'Settings',
];

final squares = [
  for (var i = 1; i <= 5; i++) i * i,
]; // [1, 4, 9, 16, 25]
```

## Practice Exercise

Given a list of students, use collection methods to:
1. Filter students with grade >= 90
2. Map to a list of names only
3. Sort alphabetically

```dart
class Student {
  final String name;
  final int grade;
  Student(this.name, this.grade);
}

void main() {
  final students = [
    Student('Zara', 92),
    Student('Alice', 88),
    Student('Megan', 95),
    Student('Bob', 91),
  ];

  final honours = students
      .where((s) => s.grade >= 90)
      .map((s) => s.name)
      .toList()
    ..sort();

  print(honours); // [Bob, Megan, Zara]
}
```
''';

  String _getErrorHandlingContent() => '''
# Error Handling & Isolates

Robust Dart applications must handle errors gracefully and can use
isolates for CPU-intensive work.

## Try / Catch / Finally

```dart
try {
  final data = await fetchFromApi();
  processData(data);
} on FormatException catch (e) {
  // Handle specific exception type
  print('Bad format: \$e');
} on HttpException catch (e, stackTrace) {
  // Capture stack trace for logging
  log('HTTP error', error: e, stackTrace: stackTrace);
} catch (e) {
  // Catch-all for unexpected errors
  rethrow; // re-throw to let the caller handle it
} finally {
  // Always runs — cleanup resources
  closeConnection();
}
```

## Custom Exceptions

```dart
class AuthException implements Exception {
  final String code;
  final String message;

  const AuthException(this.code, this.message);

  @override
  String toString() => 'AuthException(\$code): \$message';
}

// Usage
void login(String email, String password) {
  if (email.isEmpty) {
    throw const AuthException('invalid-email', 'Email cannot be empty');
  }
}
```

## Result Pattern (No Exceptions)

A functional approach to error handling:

```dart
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

class Failure<T> extends Result<T> {
  final String error;
  const Failure(this.error);
}

Future<Result<User>> getUser(String id) async {
  try {
    final user = await api.fetchUser(id);
    return Success(user);
  } catch (e) {
    return Failure(e.toString());
  }
}

// Usage
final result = await getUser('123');
switch (result) {
  case Success(:final value):
    print('Got user: \${value.name}');
  case Failure(:final error):
    print('Error: \$error');
}
```

## Isolates — Parallel Execution

Dart is single-threaded, but **isolates** run code in separate threads
with their own memory.

```dart
import 'dart:isolate';

// Simple compute
final result = await Isolate.run(() {
  // Heavy computation runs on a separate thread
  return fibonacci(40);
});

int fibonacci(int n) {
  if (n <= 1) return n;
  return fibonacci(n - 1) + fibonacci(n - 2);
}
```

### Flutter's `compute()`

```dart
import 'package:flutter/foundation.dart';

// Must be a top-level or static function
static List<Item> parseItems(String json) {
  final data = jsonDecode(json) as List;
  return data.map((e) => Item.fromJson(e)).toList();
}

// Run in isolate
final items = await compute(parseItems, responseBody);
```

## Practice Exercise

1. Create a custom `NetworkException` with `statusCode` and `message`.
2. Write a function that simulates an API call and throws your exception.
3. Catch it and convert it to a `Result<T>`.

```dart
class NetworkException implements Exception {
  final int statusCode;
  final String message;
  const NetworkException(this.statusCode, this.message);
}

Future<Result<String>> fetchData() async {
  try {
    // Simulate a 404
    throw const NetworkException(404, 'Not found');
  } on NetworkException catch (e) {
    return Failure('HTTP \${e.statusCode}: \${e.message}');
  }
}
```
''';

  // ── Course 3 new content ───────────────────────────────────────────────

  String _getLinkedListContent() => '''
# Linked Lists

A linked list is a linear data structure where each element (node) holds
a value and a reference to the next node.

## Singly Linked List

```
[10] -> [20] -> [30] -> null
```

### Implementation in Dart

```dart
class Node<T> {
  T value;
  Node<T>? next;
  Node(this.value, [this.next]);
}

class LinkedList<T> {
  Node<T>? head;
  int _length = 0;

  int get length => _length;
  bool get isEmpty => head == null;

  /// Add to the end — O(n)
  void append(T value) {
    final newNode = Node(value);
    if (head == null) {
      head = newNode;
    } else {
      var current = head!;
      while (current.next != null) {
        current = current.next!;
      }
      current.next = newNode;
    }
    _length++;
  }

  /// Add to the front — O(1)
  void prepend(T value) {
    head = Node(value, head);
    _length++;
  }

  /// Remove first occurrence — O(n)
  bool remove(T value) {
    if (head == null) return false;
    if (head!.value == value) {
      head = head!.next;
      _length--;
      return true;
    }
    var current = head!;
    while (current.next != null) {
      if (current.next!.value == value) {
        current.next = current.next!.next;
        _length--;
        return true;
      }
      current = current.next!;
    }
    return false;
  }

  /// Print all values
  void display() {
    var current = head;
    final buffer = StringBuffer();
    while (current != null) {
      buffer.write('\${current.value} -> ');
      current = current.next;
    }
    buffer.write('null');
    print(buffer);
  }
}
```

### Usage

```dart
void main() {
  final list = LinkedList<int>();
  list.append(10);
  list.append(20);
  list.append(30);
  list.prepend(5);
  list.display(); // 5 -> 10 -> 20 -> 30 -> null

  list.remove(20);
  list.display(); // 5 -> 10 -> 30 -> null
}
```

## Complexity Comparison

| Operation | Array (List) | Linked List |
|---|---|---|
| Access by index | **O(1)** | O(n) |
| Insert at front | O(n) | **O(1)** |
| Insert at end | **O(1)** amortized | O(n) |
| Search | O(n) | O(n) |
| Delete by value | O(n) | O(n) |

## Reverse a Linked List

A classic interview problem:

```dart
void reverse() {
  Node<T>? prev;
  var current = head;
  while (current != null) {
    final next = current.next;
    current.next = prev;
    prev = current;
    current = next;
  }
  head = prev;
}
```

## Practice Exercise

Implement a method `T? findMiddle()` that returns the middle
element using the **slow/fast pointer** technique:

```dart
T? findMiddle() {
  if (head == null) return null;
  var slow = head;
  var fast = head;
  while (fast?.next != null) {
    slow = slow!.next;
    fast = fast!.next!.next;
  }
  return slow!.value;
}
```
''';

  String _getHashMapContent() => '''
# Hash Maps & Sets

Hash-based data structures provide **O(1)** average-time lookups by
computing a hash of the key.

## How Hashing Works

```
key "alice" ──hash──> 42 ──mod buckets──> index 2
```

A **hash function** converts a key into an integer. The integer is
mapped to a bucket index using modulo. Collisions occur when two
different keys map to the same bucket.

## Dart's Map

Dart's `Map` is a hash-map under the hood:

```dart
final cache = <String, int>{};

// Insert — O(1) avg
cache['page_home'] = 42;
cache['page_about'] = 17;

// Lookup — O(1) avg
print(cache['page_home']); // 42

// Check existence
if (cache.containsKey('page_about')) {
  print('Found!');
}

// Iterate
cache.forEach((key, value) {
  print('\$key = \$value');
});
```

## Building a Simple Hash Map

```dart
class SimpleHashMap<K, V> {
  static const _initialCapacity = 16;
  late List<List<MapEntry<K, V>>> _buckets;
  int _size = 0;

  SimpleHashMap() {
    _buckets = List.generate(_initialCapacity, (_) => []);
  }

  int get length => _size;

  int _index(K key) => key.hashCode.abs() % _buckets.length;

  void put(K key, V value) {
    final idx = _index(key);
    // Update existing
    for (var i = 0; i < _buckets[idx].length; i++) {
      if (_buckets[idx][i].key == key) {
        _buckets[idx][i] = MapEntry(key, value);
        return;
      }
    }
    // Insert new
    _buckets[idx].add(MapEntry(key, value));
    _size++;
  }

  V? get(K key) {
    final idx = _index(key);
    for (final entry in _buckets[idx]) {
      if (entry.key == key) return entry.value;
    }
    return null;
  }

  bool containsKey(K key) => get(key) != null;
}
```

## Dart's Set

A `Set` is backed by a hash table that stores unique values:

```dart
final visited = <String>{};
visited.add('page_a');
visited.add('page_b');
visited.add('page_a'); // duplicate ignored

print(visited.length);      // 2
print(visited.contains('page_a')); // true

// Set operations
final a = {1, 2, 3, 4};
final b = {3, 4, 5, 6};

print(a.union(b));        // {1, 2, 3, 4, 5, 6}
print(a.intersection(b)); // {3, 4}
print(a.difference(b));   // {1, 2}
```

## Common Interview Patterns

### Two-Sum using a Map

```dart
List<int> twoSum(List<int> nums, int target) {
  final seen = <int, int>{};
  for (var i = 0; i < nums.length; i++) {
    final complement = target - nums[i];
    if (seen.containsKey(complement)) {
      return [seen[complement]!, i];
    }
    seen[nums[i]] = i;
  }
  return [];
}

void main() {
  print(twoSum([2, 7, 11, 15], 9)); // [0, 1]
}
```

### Count Frequencies

```dart
Map<String, int> charFrequency(String s) {
  final freq = <String, int>{};
  for (final c in s.split('')) {
    freq[c] = (freq[c] ?? 0) + 1;
  }
  return freq;
}
```

## Complexity Summary

| Operation | Average | Worst (many collisions) |
|---|---|---|
| Insert | O(1) | O(n) |
| Lookup | O(1) | O(n) |
| Delete | O(1) | O(n) |
''';

  // ── Course 4 new content ───────────────────────────────────────────────

  String _getFirestoreCrudContent() => '''
# Firestore CRUD Operations

Cloud Firestore is a NoSQL document database. Data is organized into
**collections** and **documents**.

## Setup

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

final db = FirebaseFirestore.instance;
```

## Create (Add a document)

```dart
// Auto-generated ID
final docRef = await db.collection('users').add({
  'name': 'Alice',
  'email': 'alice@example.com',
  'createdAt': FieldValue.serverTimestamp(),
});
print('Created: \${docRef.id}');

// Custom ID
await db.collection('users').doc('alice-123').set({
  'name': 'Alice',
  'email': 'alice@example.com',
});
```

## Read (Get documents)

### Single document

```dart
final doc = await db.collection('users').doc('alice-123').get();
if (doc.exists) {
  final data = doc.data()!;
  print(data['name']); // Alice
}
```

### Query a collection

```dart
final snapshot = await db
    .collection('courses')
    .where('isPublished', isEqualTo: true)
    .where('category', isEqualTo: 'Flutter')
    .orderBy('createdAt', descending: true)
    .limit(10)
    .get();

for (final doc in snapshot.docs) {
  print('\${doc.id}: \${doc.data()['title']}');
}
```

### Real-time listener

```dart
db.collection('messages')
    .orderBy('timestamp')
    .snapshots()
    .listen((snapshot) {
  for (final change in snapshot.docChanges) {
    switch (change.type) {
      case DocumentChangeType.added:
        print('New: \${change.doc.data()}');
      case DocumentChangeType.modified:
        print('Modified: \${change.doc.data()}');
      case DocumentChangeType.removed:
        print('Removed: \${change.doc.id}');
    }
  }
});
```

## Update

```dart
// Update specific fields
await db.collection('users').doc('alice-123').update({
  'name': 'Alice Smith',
  'updatedAt': FieldValue.serverTimestamp(),
});

// Increment a numeric field
await db.collection('courses').doc('c1').update({
  'enrollmentCount': FieldValue.increment(1),
});

// Array operations
await db.collection('users').doc('alice-123').update({
  'interests': FieldValue.arrayUnion(['flutter']),
});
```

## Delete

```dart
// Delete a document
await db.collection('users').doc('alice-123').delete();

// Delete a field
await db.collection('users').doc('alice-123').update({
  'phone': FieldValue.delete(),
});
```

## Batch Writes

Execute multiple operations atomically:

```dart
final batch = db.batch();

batch.set(db.collection('users').doc('u1'), {'name': 'Bob'});
batch.update(db.collection('counters').doc('stats'), {
  'userCount': FieldValue.increment(1),
});
batch.delete(db.collection('temp').doc('old-session'));

await batch.commit(); // all or nothing
```

## Data Modeling with Dart Classes

```dart
class CourseModel {
  final String id;
  final String title;
  final bool isPublished;

  CourseModel({required this.id, required this.title, required this.isPublished});

  factory CourseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CourseModel(
      id: doc.id,
      title: data['title'] ?? '',
      isPublished: data['isPublished'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'isPublished': isPublished,
  };
}
```

## Practice Exercise

Create a `NotesRepository` class with methods for:
1. `addNote(title, body)` — add with auto ID
2. `getNotes()` — return all notes ordered by date
3. `updateNote(id, newBody)` — update body field
4. `deleteNote(id)` — remove the document
''';

  String _getCloudStorageContent() => '''
# Cloud Storage Uploads

Firebase Cloud Storage lets you upload and serve user-generated content
such as images, PDFs, and other files.

## Setup

```yaml
# pubspec.yaml
dependencies:
  firebase_storage: ^12.0.0
  image_picker: ^1.0.0
```

```dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
```

## Pick & Upload an Image

```dart
Future<String?> uploadProfilePicture(String userId) async {
  // 1. Pick image
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 75,
  );
  if (picked == null) return null;

  // 2. Create a storage reference
  final ref = FirebaseStorage.instance
      .ref()
      .child('users/\$userId/profile.jpg');

  // 3. Upload
  final file = File(picked.path);
  final task = ref.putFile(
    file,
    SettableMetadata(contentType: 'image/jpeg'),
  );

  // 4. Monitor progress
  task.snapshotEvents.listen((snapshot) {
    final progress =
        snapshot.bytesTransferred / snapshot.totalBytes;
    print('Upload: \${(progress * 100).toStringAsFixed(0)}%');
  });

  // 5. Get download URL
  final snapshot = await task;
  return await snapshot.ref.getDownloadURL();
}
```

## Upload from Web (Uint8List)

```dart
Future<String> uploadBytes(String path, Uint8List data) async {
  final ref = FirebaseStorage.instance.ref().child(path);
  final task = ref.putData(
    data,
    SettableMetadata(contentType: 'application/pdf'),
  );
  final snapshot = await task;
  return await snapshot.ref.getDownloadURL();
}
```

## Download & Display

```dart
// In a widget
FutureBuilder<String>(
  future: FirebaseStorage.instance
      .ref('courses/banner.png')
      .getDownloadURL(),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return Image.network(snapshot.data!);
    }
    return const CircularProgressIndicator();
  },
)
```

## List Files in a Folder

```dart
Future<List<String>> listCourseFiles(String courseId) async {
  final ref = FirebaseStorage.instance
      .ref()
      .child('courses/\$courseId/files');

  final result = await ref.listAll();

  final urls = <String>[];
  for (final item in result.items) {
    urls.add(await item.getDownloadURL());
  }
  return urls;
}
```

## Delete a File

```dart
await FirebaseStorage.instance
    .ref('users/user123/old_photo.jpg')
    .delete();
```

## Security Rules (storage.rules)

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId
                   && request.resource.size < 5 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
```

## Practice Exercise

Build a file upload widget that:
1. Lets the user pick a file via `FilePicker`
2. Shows a linear progress indicator during the upload
3. Displays the download URL when complete

```dart
class UploadWidget extends StatefulWidget { /* ... */ }

class _UploadWidgetState extends State<UploadWidget> {
  double _progress = 0;
  String? _downloadUrl;

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) return;

    final bytes = result.files.single.bytes!;
    final name = result.files.single.name;

    final ref = FirebaseStorage.instance.ref('uploads/\$name');
    final task = ref.putData(bytes);

    task.snapshotEvents.listen((s) {
      setState(() {
        _progress = s.bytesTransferred / s.totalBytes;
      });
    });

    final snap = await task;
    setState(() async {
      _downloadUrl = await snap.ref.getDownloadURL();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ElevatedButton(onPressed: _upload, child: Text('Upload')),
      LinearProgressIndicator(value: _progress),
      if (_downloadUrl != null) SelectableText(_downloadUrl!),
    ]);
  }
}
```
''';

  // ═══════════════════════════════════════════════════════════════════════════
  // Module Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all modules for a course
  Future<List<ModuleModel>> getModules(String courseId) async {
    if (EnvironmentConfig.isDemoMode) {
      final modules = _demoModules
          .where((m) => m.courseId == courseId)
          .toList();
      modules.sort((a, b) => a.order.compareTo(b.order));
      return modules;
    }

    final snapshot = await _firestore!
        .collection(FirestorePaths.courses)
        .doc(courseId)
        .collection(FirestorePaths.modules)
        .orderBy('order')
        .get();

    return snapshot.docs
        .map((doc) => ModuleModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get a single module
  Future<ModuleModel?> getModule(String courseId, String moduleId) async {
    if (EnvironmentConfig.isDemoMode) {
      try {
        return _demoModules.firstWhere((m) => m.id == moduleId);
      } catch (_) {
        return null; // Module not found in demo data
      }
    }

    final doc = await _firestore!
        .collection(FirestorePaths.courses)
        .doc(courseId)
        .collection(FirestorePaths.modules)
        .doc(moduleId)
        .get();

    if (!doc.exists) return null;
    return ModuleModel.fromMap(doc.data()!, doc.id);
  }

  /// Create a new module
  Future<ModuleModel> createModule({
    required String courseId,
    required String title,
    String? description,
    required int order,
  }) async {
    final now = DateTime.now();

    if (EnvironmentConfig.isDemoMode) {
      final module = ModuleModel(
        id: 'module-${DateTime.now().millisecondsSinceEpoch}',
        courseId: courseId,
        title: title,
        description: description,
        order: order,
        isPublished: false,
        createdAt: now,
      );
      _demoModules.add(module);
      return module;
    }

    final data = {
      'courseId': courseId,
      'title': title,
      'description': description,
      'order': order,
      'isPublished': false,
      'createdAt': now.toIso8601String(),
    };

    final docRef = await _firestore!
        .collection(FirestorePaths.courses)
        .doc(courseId)
        .collection(FirestorePaths.modules)
        .add(data);

    return ModuleModel.fromMap(data, docRef.id);
  }

  /// Update a module
  Future<ModuleModel> updateModule(
    String courseId,
    String moduleId,
    Map<String, dynamic> updates,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      final index = _demoModules.indexWhere((m) => m.id == moduleId);
      if (index == -1) throw Exception('Module not found');

      final current = _demoModules[index];
      final updated = ModuleModel(
        id: current.id,
        courseId: current.courseId,
        title: updates['title'] as String? ?? current.title,
        description: updates['description'] as String? ?? current.description,
        order: updates['order'] as int? ?? current.order,
        isPublished: updates['isPublished'] as bool? ?? current.isPublished,
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
      );
      _demoModules[index] = updated;
      return updated;
    }

    updates['updatedAt'] = DateTime.now().toIso8601String();

    await _firestore!
        .collection(FirestorePaths.courses)
        .doc(courseId)
        .collection(FirestorePaths.modules)
        .doc(moduleId)
        .update(updates);

    final updated = await getModule(courseId, moduleId);
    if (updated == null) throw Exception('Failed to fetch updated module');
    return updated;
  }

  /// Delete a module
  Future<void> deleteModule(String courseId, String moduleId) async {
    if (EnvironmentConfig.isDemoMode) {
      _demoModules.removeWhere((m) => m.id == moduleId);
      _demoLessons.removeWhere((l) => l.moduleId == moduleId);
      return;
    }

    // Delete all lessons in module first
    final lessons = await getLessons(courseId, moduleId: moduleId);
    for (final lesson in lessons) {
      await deleteLesson(courseId, lesson.id);
    }

    await _firestore!
        .collection(FirestorePaths.courses)
        .doc(courseId)
        .collection(FirestorePaths.modules)
        .doc(moduleId)
        .delete();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Lesson Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all lessons for a course or module
  Future<List<LessonModel>> getLessons(
    String courseId, {
    String? moduleId,
  }) async {
    if (EnvironmentConfig.isDemoMode) {
      var lessons = _demoLessons.where((l) => l.courseId == courseId);
      if (moduleId != null) {
        lessons = lessons.where((l) => l.moduleId == moduleId);
      }
      final list = lessons.toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      return list;
    }

    Query query = _firestore!
        .collection(FirestorePaths.courses)
        .doc(courseId)
        .collection(FirestorePaths.lessons)
        .orderBy('order');

    if (moduleId != null) {
      query = query.where('moduleId', isEqualTo: moduleId);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map(
          (doc) =>
              LessonModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  /// Get a single lesson
  Future<LessonModel?> getLesson(String courseId, String lessonId) async {
    if (EnvironmentConfig.isDemoMode) {
      try {
        return _demoLessons.firstWhere((l) => l.id == lessonId);
      } catch (_) {
        return null; // Lesson not found in demo data
      }
    }

    final doc = await _firestore!
        .collection(FirestorePaths.courses)
        .doc(courseId)
        .collection(FirestorePaths.lessons)
        .doc(lessonId)
        .get();

    if (!doc.exists) return null;
    return LessonModel.fromMap(doc.data()!, doc.id);
  }

  /// Create a new lesson
  Future<LessonModel> createLesson({
    required String courseId,
    required String moduleId,
    required String title,
    String? description,
    required int order,
    required LessonType type,
    String? content,
    String? videoUrl,
    required int durationMinutes,
    bool isPublished = false,
  }) async {
    final now = DateTime.now();

    if (EnvironmentConfig.isDemoMode) {
      // Auto-create a default module if the specified one doesn't exist
      final moduleExists = _demoModules.any(
        (m) => m.id == moduleId && m.courseId == courseId,
      );
      if (!moduleExists) {
        final existingModules = _demoModules
            .where((m) => m.courseId == courseId)
            .toList();
        if (existingModules.isEmpty) {
          final defaultModule = ModuleModel(
            id: moduleId,
            courseId: courseId,
            title: 'Course Content',
            order: 0,
            isPublished: true,
            createdAt: now,
          );
          _demoModules.add(defaultModule);
        }
      }

      final lesson = LessonModel(
        id: 'lesson-${DateTime.now().millisecondsSinceEpoch}',
        courseId: courseId,
        moduleId: moduleId,
        title: title,
        description: description,
        order: order,
        type: type,
        content: content,
        videoUrl: videoUrl,
        durationMinutes: durationMinutes,
        isPublished: isPublished,
        createdAt: now,
      );
      _demoLessons.add(lesson);
      return lesson;
    }

    final data = {
      'courseId': courseId,
      'moduleId': moduleId,
      'title': title,
      'description': description,
      'order': order,
      'type': type.name,
      'content': content,
      'videoUrl': videoUrl,
      'durationMinutes': durationMinutes,
      'isPublished': false,
      'createdAt': now.toIso8601String(),
    };

    final docRef = await _firestore!
        .collection(FirestorePaths.courses)
        .doc(courseId)
        .collection(FirestorePaths.lessons)
        .add(data);

    return LessonModel.fromMap(data, docRef.id);
  }

  /// Update a lesson
  Future<LessonModel> updateLesson(
    String courseId,
    String lessonId,
    Map<String, dynamic> updates,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      final index = _demoLessons.indexWhere((l) => l.id == lessonId);
      if (index == -1) throw Exception('Lesson not found');

      final current = _demoLessons[index];
      final updated = LessonModel(
        id: current.id,
        courseId: current.courseId,
        moduleId: updates['moduleId'] as String? ?? current.moduleId,
        title: updates['title'] as String? ?? current.title,
        description: updates['description'] as String? ?? current.description,
        order: updates['order'] as int? ?? current.order,
        type: updates['type'] != null
            ? LessonType.fromString(updates['type'] as String)
            : current.type,
        content: updates['content'] as String? ?? current.content,
        videoUrl: updates['videoUrl'] as String? ?? current.videoUrl,
        durationMinutes:
            updates['durationMinutes'] as int? ?? current.durationMinutes,
        isPublished: updates['isPublished'] as bool? ?? current.isPublished,
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
      );
      _demoLessons[index] = updated;
      return updated;
    }

    updates['updatedAt'] = DateTime.now().toIso8601String();

    await _firestore!
        .collection(FirestorePaths.courses)
        .doc(courseId)
        .collection(FirestorePaths.lessons)
        .doc(lessonId)
        .update(updates);

    final updated = await getLesson(courseId, lessonId);
    if (updated == null) throw Exception('Failed to fetch updated lesson');
    return updated;
  }

  /// Delete a lesson
  Future<void> deleteLesson(String courseId, String lessonId) async {
    if (EnvironmentConfig.isDemoMode) {
      _demoLessons.removeWhere((l) => l.id == lessonId);
      _demoProgress.removeWhere((p) => p.lessonId == lessonId);
      return;
    }

    await _firestore!
        .collection(FirestorePaths.courses)
        .doc(courseId)
        .collection(FirestorePaths.lessons)
        .doc(lessonId)
        .delete();
  }

  /// Toggle lesson publish status
  Future<LessonModel> toggleLessonPublish(
    String courseId,
    String lessonId,
    bool publish,
  ) async {
    return updateLesson(courseId, lessonId, {'isPublished': publish});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Progress Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get lesson progress for a user
  Future<LessonProgressModel?> getLessonProgress(
    String lessonId,
    String userId,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      try {
        return _demoProgress.firstWhere(
          (p) => p.lessonId == lessonId && p.userId == userId,
        );
      } catch (_) {
        return null; // No progress found for this lesson/user
      }
    }

    final snapshot = await _firestore!
        .collectionGroup('lessonProgress')
        .where('lessonId', isEqualTo: lessonId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return LessonProgressModel.fromMap(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    );
  }

  /// Get all lesson progress for a course enrollment
  Future<List<LessonProgressModel>> getCourseProgress(
    String courseId,
    String enrollmentId,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      return _demoProgress
          .where((p) => p.enrollmentId == enrollmentId)
          .toList();
    }

    final snapshot = await _firestore!
        .collection(FirestorePaths.courses)
        .doc(courseId)
        .collection(FirestorePaths.enrollments)
        .doc(enrollmentId)
        .collection('lessonProgress')
        .get();

    return snapshot.docs
        .map((doc) => LessonProgressModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Mark a lesson as complete
  Future<LessonProgressModel> markLessonComplete({
    required String courseId,
    required String lessonId,
    required String enrollmentId,
    required String userId,
  }) async {
    final now = DateTime.now();

    if (EnvironmentConfig.isDemoMode) {
      final existingIndex = _demoProgress.indexWhere(
        (p) => p.lessonId == lessonId && p.userId == userId,
      );

      if (existingIndex != -1) {
        final updated = _demoProgress[existingIndex].copyWith(
          isCompleted: true,
          completedAt: now,
          lastAccessedAt: now,
        );
        _demoProgress[existingIndex] = updated;
        return updated;
      }

      final progress = LessonProgressModel(
        id: 'progress-${DateTime.now().millisecondsSinceEpoch}',
        lessonId: lessonId,
        enrollmentId: enrollmentId,
        userId: userId,
        isCompleted: true,
        completedAt: now,
        lastAccessedAt: now,
      );
      _demoProgress.add(progress);
      return progress;
    }

    final existing = await getLessonProgress(lessonId, userId);

    if (existing != null) {
      await _firestore!
          .collection(FirestorePaths.courses)
          .doc(courseId)
          .collection(FirestorePaths.enrollments)
          .doc(enrollmentId)
          .collection('lessonProgress')
          .doc(existing.id)
          .update({
            'isCompleted': true,
            'completedAt': now.toIso8601String(),
            'lastAccessedAt': now.toIso8601String(),
          });

      return existing.copyWith(
        isCompleted: true,
        completedAt: now,
        lastAccessedAt: now,
      );
    }

    final data = {
      'lessonId': lessonId,
      'enrollmentId': enrollmentId,
      'userId': userId,
      'isCompleted': true,
      'completedAt': now.toIso8601String(),
      'lastAccessedAt': now.toIso8601String(),
    };

    final docRef = await _firestore!
        .collection(FirestorePaths.courses)
        .doc(courseId)
        .collection(FirestorePaths.enrollments)
        .doc(enrollmentId)
        .collection('lessonProgress')
        .add(data);

    return LessonProgressModel.fromMap(data, docRef.id);
  }

  /// Update lesson access time
  Future<void> updateLessonAccess({
    required String courseId,
    required String lessonId,
    required String enrollmentId,
    required String userId,
    Map<String, dynamic>? savedState,
  }) async {
    final now = DateTime.now();

    if (EnvironmentConfig.isDemoMode) {
      final existingIndex = _demoProgress.indexWhere(
        (p) => p.lessonId == lessonId && p.userId == userId,
      );

      if (existingIndex != -1) {
        _demoProgress[existingIndex] = _demoProgress[existingIndex].copyWith(
          lastAccessedAt: now,
          savedState: savedState,
        );
      } else {
        _demoProgress.add(
          LessonProgressModel(
            id: 'progress-${DateTime.now().millisecondsSinceEpoch}',
            lessonId: lessonId,
            enrollmentId: enrollmentId,
            userId: userId,
            isCompleted: false,
            lastAccessedAt: now,
            savedState: savedState,
          ),
        );
      }
      return;
    }

    final existing = await getLessonProgress(lessonId, userId);

    final data = {
      'lessonId': lessonId,
      'enrollmentId': enrollmentId,
      'userId': userId,
      'lastAccessedAt': now.toIso8601String(),
      'savedState': ?savedState,
    };

    if (existing != null) {
      await _firestore!
          .collection(FirestorePaths.courses)
          .doc(courseId)
          .collection(FirestorePaths.enrollments)
          .doc(enrollmentId)
          .collection('lessonProgress')
          .doc(existing.id)
          .update(data);
    } else {
      data['isCompleted'] = false;
      await _firestore!
          .collection(FirestorePaths.courses)
          .doc(courseId)
          .collection(FirestorePaths.enrollments)
          .doc(enrollmentId)
          .collection('lessonProgress')
          .add(data);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helper Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get next and previous lesson IDs
  Future<Map<String, String?>> getAdjacentLessons(
    String courseId,
    String lessonId,
  ) async {
    final lessons = await getLessons(courseId);
    final modules = await getModules(courseId);

    // Sort lessons by module order, then lesson order
    lessons.sort((a, b) {
      final moduleA = modules.firstWhere((m) => m.id == a.moduleId);
      final moduleB = modules.firstWhere((m) => m.id == b.moduleId);
      if (moduleA.order != moduleB.order) {
        return moduleA.order.compareTo(moduleB.order);
      }
      return a.order.compareTo(b.order);
    });

    final currentIndex = lessons.indexWhere((l) => l.id == lessonId);

    return {
      'previous': currentIndex > 0 ? lessons[currentIndex - 1].id : null,
      'next': currentIndex < lessons.length - 1
          ? lessons[currentIndex + 1].id
          : null,
    };
  }

  /// Get total duration of a course in minutes
  Future<int> getCourseDuration(String courseId) async {
    final lessons = await getLessons(courseId);
    return lessons.fold<int>(0, (sum, l) => sum + l.durationMinutes);
  }

  /// Get completion percentage for a course
  Future<double> getCourseCompletionPercentage(
    String courseId,
    String enrollmentId,
  ) async {
    final lessons = await getLessons(courseId);
    if (lessons.isEmpty) return 0.0;

    final progress = await getCourseProgress(courseId, enrollmentId);
    final completedCount = progress.where((p) => p.isCompleted).length;

    return completedCount / lessons.length;
  }
}
