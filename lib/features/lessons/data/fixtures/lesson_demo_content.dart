part of '../repositories/lesson_repository.dart';

extension _LessonDemoContent on LessonRepository {
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
}
