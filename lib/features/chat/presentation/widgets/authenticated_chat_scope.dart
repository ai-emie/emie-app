import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../../state/session_store.dart';
import '../../controller/chat_controller.dart';

/// Owns one controller and consumer subtree per authenticated identity.
class AuthenticatedChatScope extends StatefulWidget {
  const AuthenticatedChatScope({
    super.key,
    required this.session,
    required this.child,
    this.createController,
  });

  final SessionStore session;
  final Widget child;
  final ChatController Function()? createController;

  @override
  State<AuthenticatedChatScope> createState() => _AuthenticatedChatScopeState();
}

class _AuthenticatedChatScopeState extends State<AuthenticatedChatScope> {
  Object? _identity;
  ChatController? _controller;

  Object? get _currentIdentity {
    final session = widget.session;
    if (session.isBootstrapping || !session.isAuthenticated) return null;

    final user = session.user!;
    final id = user.id.trim();
    final email = user.email.trim().toLowerCase();
    // /me currently may omit id. Never group different emails under an empty id.
    // An unidentified profile is scoped to that exact profile object instead.
    return id.isEmpty && email.isEmpty ? user : (id, email);
  }

  @override
  void initState() {
    super.initState();
    _replaceController();
    widget.session.addListener(_onSessionChanged);
  }

  void _replaceController() {
    _controller?.dispose();
    _identity = _currentIdentity;
    _controller = _identity == null
        ? null
        : (widget.createController?.call() ?? ChatController());
  }

  void _onSessionChanged() {
    if (_identity == _currentIdentity) return;

    // Invalidate synchronously, even if logout and login happen before a frame.
    // Token refreshes and preference changes do not change the identity.
    setState(_replaceController);
  }

  @override
  void didUpdateWidget(covariant AuthenticatedChatScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session.removeListener(_onSessionChanged);
      _replaceController();
      widget.session.addListener(_onSessionChanged);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();

    // This State owns disposal. A new key also discards consumer-local state,
    // including Home's cached welcome future and Chat's search/selection state.
    return ChangeNotifierProvider<ChatController>.value(
      key: ObjectKey(controller),
      value: controller,
      child: widget.child,
    );
  }
}
