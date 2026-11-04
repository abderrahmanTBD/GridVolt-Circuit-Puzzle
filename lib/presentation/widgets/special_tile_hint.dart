import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../theme/volt_theme.dart';
import 'volt_cell.dart';

/// One-time banner explaining a special tile the first time one is dealt.
/// Shown at the top of the screen so it never covers the tray.
class SpecialTileHint extends StatelessWidget {
  const SpecialTileHint({super.key, required this.tile, required this.onClose});

  final SpecialTile tile;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final (title, text) = switch (tile) {
      SpecialTile.battery => (
        'New: Battery tile',
        'Clear its line and it explodes, wiping the 3×3 area around it.',
      ),
      SpecialTile.multiplier => (
        'New: ×2 Multiplier',
        'Clear it to double the points of that move. They stack!',
      ),
      SpecialTile.none => ('', ''),
    };

    return Material(
      key: Key('hint-${tile.name}'),
      color: VoltColors.surface.withValues(alpha: 0.96),
      elevation: 8,
      shadowColor: VoltColors.volt.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: VoltColors.volt.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onClose,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              VoltCell(
                cell: GridCell(
                  colorId: tile == SpecialTile.battery ? 2 : 3,
                  special: tile,
                ),
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: VoltColors.volt,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: VoltColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
