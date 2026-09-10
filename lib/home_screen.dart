import 'package:flutter/material.dart';

import 'my_destination_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MyDestinationsScreen(showBackButton: false, homeLayout: true);
  }
}
