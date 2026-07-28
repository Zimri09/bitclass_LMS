import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import 'course_catalog_screen.dart';
import 'my_courses_screen.dart';

/// The shared Home and Classes destination, selected by the signed-in role.
class ClassroomLandingScreen extends StatelessWidget {
  const ClassroomLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated && state.user.role == 'instructor') {
          return const MyCoursesScreen();
        }
        return const CourseCatalogScreen();
      },
    );
  }
}
