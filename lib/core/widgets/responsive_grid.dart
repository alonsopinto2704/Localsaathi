import 'package:flutter/widgets.dart';

import '../theme/app_spacing.dart';

/// Lays children out in [columns] equal columns with the card gap; one column
/// is a plain list. Rows size to their tallest card.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.columns,
    required this.children,
    this.gap = AppSpacing.lg,
  });

  final int columns;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (columns == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int start = 0; start < children.length; start += columns) ...<Widget>[
          if (start > 0) SizedBox(height: gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = start; i < start + columns; i++) ...<Widget>[
                  if (i > start) SizedBox(width: gap),
                  Expanded(
                    child: i < children.length
                        ? children[i]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Columns for a list of cards at the given available width.
int cardColumnsFor(double width) =>
    width >= AppSpacing.wideBreakpoint ? 2 : 1;
