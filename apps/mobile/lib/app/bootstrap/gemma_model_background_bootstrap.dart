import 'package:clindiary/app/bootstrap/gemma_model_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GemmaModelBackgroundBootstrap extends ConsumerStatefulWidget {
  const GemmaModelBackgroundBootstrap({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<GemmaModelBackgroundBootstrap> createState() =>
      _GemmaModelBackgroundBootstrapState();
}

class _GemmaModelBackgroundBootstrapState
    extends ConsumerState<GemmaModelBackgroundBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gemmaModelBootstrapProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
