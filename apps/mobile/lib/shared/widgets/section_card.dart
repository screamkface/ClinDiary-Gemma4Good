import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    this.action,
    this.subtitle,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? action;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800);
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
      height: 1.35,
    );

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactHeader = action != null && constraints.maxWidth < 420;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (action == null)
                  _SectionHeader(
                    title: title,
                    subtitle: subtitle,
                    titleStyle: titleStyle,
                    subtitleStyle: subtitleStyle,
                  )
                else if (compactHeader)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: title,
                        subtitle: subtitle,
                        titleStyle: titleStyle,
                        subtitleStyle: subtitleStyle,
                      ),
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerLeft, child: action!),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _SectionHeader(
                          title: title,
                          subtitle: subtitle,
                          titleStyle: titleStyle,
                          subtitleStyle: subtitleStyle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: action!,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                child,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.titleStyle,
    required this.subtitleStyle,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    if (subtitle == null || subtitle!.trim().isEmpty) {
      return Text(title, style: titleStyle);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        const SizedBox(height: 4),
        Text(subtitle!, style: subtitleStyle),
      ],
    );
  }
}
