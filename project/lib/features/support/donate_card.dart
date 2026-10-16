import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/support_config.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui/ui.dart';

/// Khan Academy's donate box: one-time or monthly, a few amounts and
/// "Other", then one button that opens the chosen payment page in a new
/// tab. Paying happens on the provider's site, so the CSP and the app hold
/// nothing about it. Draws nothing while [links] has no page at all.
class DonateCard extends StatefulWidget {
  const DonateCard({super.key, this.links = kDonateLinks, this.open});

  final DonateLinks links;

  /// Opens a payment page; tests pass their own.
  final void Function(Uri url)? open;

  @override
  State<DonateCard> createState() => _DonateCardState();
}

class _DonateCardState extends State<DonateCard> {
  late bool _monthly = !widget.links.hasOneTime;

  /// An amount from the tier list, or null for "Other".
  int? _amount;

  @override
  void initState() {
    super.initState();
    _amount = _defaultAmount();
  }

  int? _defaultAmount() {
    final tiers = widget.links.tiers(monthly: _monthly);
    if (tiers.isEmpty) return null;
    // The second tier, like Khan's pre-selected middle amount.
    return tiers[tiers.length > 1 ? 1 : 0].amount;
  }

  String? get _url {
    final amount = _amount;
    if (amount == null) return _monthly ? null : widget.links.oneTimeOther;
    for (final t in widget.links.tiers(monthly: _monthly)) {
      if (t.amount == amount) return t.url;
    }
    return null;
  }

  void _go() {
    final url = _url;
    if (url == null) return;
    final uri = Uri.parse(url);
    (widget.open ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication))(
      uri,
    );
  }

  @override
  Widget build(BuildContext context) {
    final links = widget.links;
    if (links.isEmpty) return const SizedBox.shrink();
    final palette = context.palette;
    final tiers = links.tiers(monthly: _monthly);
    final showOther = !_monthly && links.oneTimeOther != null;
    final amount = _amount;
    final label = amount == null
        ? 'Donate'
        : _monthly
        ? 'Donate ${formatNaira(amount)} a month'
        : 'Donate ${formatNaira(amount)}';

    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Make a donation',
            style: AppTheme.heading3.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: 14),
          if (links.hasOneTime && links.hasMonthly) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('One-time')),
                ButtonSegment(value: true, label: Text('Monthly')),
              ],
              selected: {_monthly},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                _monthly = s.first;
                _amount = _defaultAmount();
              }),
            ),
            const SizedBox(height: 14),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in tiers)
                ChoiceChip(
                  label: Text(formatNaira(t.amount)),
                  selected: amount == t.amount,
                  onSelected: (_) => setState(() => _amount = t.amount),
                ),
              if (showOther)
                ChoiceChip(
                  label: const Text('Other'),
                  selected: amount == null,
                  onSelected: (_) => setState(() => _amount = null),
                ),
            ],
          ),
          if (amount == null && showOther) ...[
            const SizedBox(height: 8),
            Text(
              'You choose the amount on the next page.',
              style: AppTheme.caption.copyWith(color: palette.textSecondary),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _url == null ? null : _go,
              child: Text(label),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Payments are made securely on Paystack, in a new tab. Paragon '
            'never sees your card details. Paragon is not a registered '
            'charity, so a donation is a gift, not tax-deductible.'
            '${_monthly ? ' You can cancel a monthly donation at any time '
                      'from the link in your Paystack receipt.' : ''}',
            style: AppTheme.caption.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
