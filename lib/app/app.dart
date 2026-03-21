import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/library/library_screen.dart';
import 'theme.dart';

class AffirmationPlayerApp extends ConsumerWidget {
  const AffirmationPlayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'アファメーションプレーヤー',
      theme: buildAppTheme(),
      home: const LibraryScreen(),
    );
  }
}
