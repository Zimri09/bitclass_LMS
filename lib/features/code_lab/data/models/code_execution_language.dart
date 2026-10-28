enum CodeExecutionLanguage {
  python,
  c,
  java;

  String get displayName => switch (this) {
    CodeExecutionLanguage.python => 'Python',
    CodeExecutionLanguage.c => 'C',
    CodeExecutionLanguage.java => 'Java',
  };

  String get fileExtension => switch (this) {
    CodeExecutionLanguage.python => '.py',
    CodeExecutionLanguage.c => '.c',
    CodeExecutionLanguage.java => '.java',
  };

  String get fileName => this == java ? 'Main.java' : 'main$fileExtension';

  int get executionLimitSeconds => this == java ? 20 : 5;

  Duration get requestTimeout => Duration(seconds: this == java ? 30 : 12);

  String get starterCode => switch (this) {
    CodeExecutionLanguage.java =>
      '''public class Main {
    public static void main(String[] args) {
        for (int number = 0; number < 5; number++) {
            System.out.println(number);
        }
    }
}''',
    CodeExecutionLanguage.python =>
      '''for number in range(5):
    print(number)''',
    CodeExecutionLanguage.c =>
      '''#include <stdio.h>

int main(void) {
    for (int number = 0; number < 5; number++) {
        printf("%d\\n", number);
    }
    return 0;
}''',
  };
}
