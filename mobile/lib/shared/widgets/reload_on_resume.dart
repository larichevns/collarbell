import 'package:flutter/widgets.dart';

/// Calls [onResume] when the app comes back to the screen: meanwhile
/// another phone of the household may have changed what [child] shows
/// (a purchase marked, a pet added).
class ReloadOnResume extends StatefulWidget {
  const ReloadOnResume({
    super.key,
    required this.onResume,
    required this.child,
  });

  final VoidCallback onResume;
  final Widget child;

  @override
  State<ReloadOnResume> createState() => _ReloadOnResumeState();
}

class _ReloadOnResumeState extends State<ReloadOnResume> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => widget.onResume());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
