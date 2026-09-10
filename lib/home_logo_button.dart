import 'package:flutter/material.dart';
import 'main_screen.dart';

class HomeLogoButton extends StatelessWidget {
  const HomeLogoButton({super.key, this.onPressed});
  final VoidCallback? onPressed;

  static void goHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed ?? () => goHome(context),
        child: const Text('숨트립',
            style: TextStyle(
                color: Color(0xFF4A7C59),
                fontSize: 23,
                fontWeight: FontWeight.bold,
                fontFamily: 'CustomFont')),
      );
}
