enum CodeExecutionLanguage {
  python,
  c;

  String get displayName => switch (this) {
    CodeExecutionLanguage.python => 'Python',
    CodeExecutionLanguage.c => 'C',
  };

  String get fileExtension => switch (this) {
    CodeExecutionLanguage.python => '.py',
    CodeExecutionLanguage.c => '.c',
  };

  String get starterCode => switch (this) {
    CodeExecutionLanguage.python => '''for number in range(5):
    print(number)''',
    CodeExecutionLanguage.c => '''#include <stdio.h>

int main(void) {
    for (int number = 0; number < 5; number++) {
        printf("%d\\n", number);
    }
    return 0;
}''',
  };
}
