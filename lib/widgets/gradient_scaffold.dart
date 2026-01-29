import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A scaffold that applies the Drugs Taken gradient background + AppBar
/// decoration used across the app.
class GradientScaffold extends StatelessWidget {
  const GradientScaffold({
    super.key,
    required this.title,
    required this.body,
    this.bottom,
    this.actions,
    this.leading,
    this.floatingActionButton,
    this.titleSpacing = 20,
    this.extendBodyBehindAppBar = false,
    this.backgroundGradient,
  });

  final Widget title;
  final Widget body;
  final PreferredSizeWidget? bottom;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? floatingActionButton;
  final double titleSpacing;
  final bool extendBodyBehindAppBar;
  final Gradient? backgroundGradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: backgroundGradient ?? AppTheme.backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
        appBar: AppBar(
          titleSpacing: titleSpacing,
          title: title,
          leading: leading,
          actions: actions,
          bottom: bottom,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.appBarGradient,
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
          ),
        ),
        body: body,
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}
