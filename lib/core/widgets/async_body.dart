import 'package:flutter/material.dart';
import '../errors/app_exception.dart';
import 'app_skeleton.dart';
import 'app_states.dart';

/// Contenedor de UI para estados carga / error / vacío / éxito.
class AsyncBody<T> extends StatelessWidget {
  final AsyncSnapshot<T> snapshot;
  final Widget Function(BuildContext context, T data) builder;
  final String emptyMessage;
  final String? emptyTitle;
  final IconData emptyIcon;
  final bool Function(T data)? isEmpty;
  final VoidCallback? onRetry;
  final Widget? loading;
  final Widget? emptyAction;

  const AsyncBody({
    super.key,
    required this.snapshot,
    required this.builder,
    this.emptyMessage = 'No hay datos',
    this.emptyTitle,
    this.emptyIcon = Icons.inbox_outlined,
    this.isEmpty,
    this.onRetry,
    this.loading,
    this.emptyAction,
  });

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return loading ?? const ResumeListSkeleton();
    }

    if (snapshot.hasError) {
      return AppErrorState(
        message: ErrorMapper.messageOf(snapshot.error!),
        onRetry: onRetry,
      );
    }

    final data = snapshot.data;
    if (data == null || (isEmpty?.call(data) ?? false)) {
      return AppEmptyState(
        icon: emptyIcon,
        title: emptyTitle ?? emptyMessage,
        subtitle: emptyTitle == null ? null : emptyMessage,
        action: emptyAction,
      );
    }

    return builder(context, data);
  }
}
