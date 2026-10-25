import 'package:flutter/widgets.dart';

/// Keeps a tab, and so the data it watches, while other tabs are shown:
/// coming back to it shows it at once instead of loading it again. Pull to
/// refresh and changes made in the app still reload it.
class KeepTabAlive extends StatefulWidget {
  const KeepTabAlive({super.key, required this.child});

  final Widget child;

  @override
  State<KeepTabAlive> createState() => _KeepTabAliveState();
}

class _KeepTabAliveState extends State<KeepTabAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
