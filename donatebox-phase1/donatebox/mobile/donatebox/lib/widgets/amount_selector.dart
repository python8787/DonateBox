import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Amount selector with preset quick-pick buttons + custom input.
///
/// Presets come from the backend config — never hardcoded.
class AmountSelector extends StatefulWidget {
  final List<int> presets;
  final double minAmount;
  final double maxAmount;
  final String currencySymbol;
  final ValueChanged<double?> onAmountChanged;
  final double? selectedAmount;

  const AmountSelector({
    super.key,
    required this.presets,
    required this.minAmount,
    required this.maxAmount,
    required this.currencySymbol,
    required this.onAmountChanged,
    this.selectedAmount,
  });

  @override
  State<AmountSelector> createState() => _AmountSelectorState();
}

class _AmountSelectorState extends State<AmountSelector> {
  final TextEditingController _customController = TextEditingController();
  int? _selectedPresetIndex;
  bool _isCustom = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _selectPreset(int index) {
    setState(() {
      _selectedPresetIndex = index;
      _isCustom = false;
      _customController.clear();
    });
    widget.onAmountChanged(widget.presets[index].toDouble());
  }

  void _onCustomAmountChanged(String value) {
    setState(() {
      _selectedPresetIndex = null;
      _isCustom = true;
    });
    final amount = double.tryParse(value);
    widget.onAmountChanged(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Amount',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTheme.spacingMd),

        // Preset buttons
        Wrap(
          spacing: AppTheme.spacingSm,
          runSpacing: AppTheme.spacingSm,
          children: List.generate(widget.presets.length, (index) {
            final isSelected = _selectedPresetIndex == index && !_isCustom;
            return _PresetChip(
              label: '${widget.currencySymbol}${widget.presets[index]}',
              isSelected: isSelected,
              onTap: () => _selectPreset(index),
            );
          }),
        ),
        const SizedBox(height: AppTheme.spacingMd),

        // Custom amount input
        TextField(
          controller: _customController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18),
          decoration: InputDecoration(
            prefixText: '${widget.currencySymbol} ',
            prefixStyle: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            hintText: 'Enter custom amount',
            helperText:
                'Min: ${widget.currencySymbol}${widget.minAmount.toStringAsFixed(0)} · '
                'Max: ${widget.currencySymbol}${widget.maxAmount.toStringAsFixed(0)}',
            helperStyle: const TextStyle(color: AppTheme.textMuted),
          ),
          onChanged: _onCustomAmountChanged,
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm + 4,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          gradient: isSelected ? AppTheme.buttonGradient : null,
          color: isSelected ? null : AppTheme.glassWhite,
          border: Border.all(
            color: isSelected ? Colors.transparent : AppTheme.glassBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
