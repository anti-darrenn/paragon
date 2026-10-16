import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'support/donate_card.dart';

import '../core/config/support_config.dart';
import '../core/legal/legal_documents.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/nav/back_navigation.dart';
import '../core/widgets/ui/ui.dart';

/// `/support`: why Paragon is free, what it costs to keep it that way,
/// and how schools and tutors can work with it — Khan Academy's page in
/// spirit. The donate card stays hidden while [kDonateLinks] has no link.
/// Readable signed out, like About.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final partner = Uri(
      scheme: 'mailto',
      path: contactEmail,
      query: 'subject=${Uri.encodeComponent(partnerSubject)}',
    );
    Widget para(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: AppTheme.bodyMd.copyWith(
          color: palette.textSecondary,
          height: 1.5,
        ),
      ),
    );
    return Scaffold(
      appBar: const ParagonAppBar(title: Text('Support Paragon')),
      body: PageBody(
        children: [
          const PageIntro(
            title: 'Free WAEC prep, for every student',
            subtitle:
                'Paragon is free and has no adverts. Here is what keeps it '
                'that way, and how you can help.',
          ),
          const SectionHeader('What it costs'),
          para(
            'Paragon runs on free tiers today: hosting, the database and the '
            'tools we build with. As more students use it each day, that '
            'stops being enough, and the questions, lessons and examiner '
            'notes take people time to write and check.',
          ),
          if (!kDonateLinks.isEmpty) ...[
            const SizedBox(height: 4),
            const DonateCard(),
            const SizedBox(height: kSectionGap),
          ],
          const SectionHeader('Schools and tutors'),
          para(
            'Use Paragon with a class: run a live quiz on any topic from '
            'your phone or a projector, and your students join with a code '
            'as guests if they like. If you would like to work with us on '
            'questions, lessons or a pilot, write to us.',
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/join'),
                icon: const Icon(Icons.groups_rounded),
                label: const Text('Live quiz'),
              ),
              OutlinedButton.icon(
                onPressed: () => launchUrl(partner),
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('Write to us'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            contactEmail,
            style: AppTheme.caption.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: kSectionGap),
          const SectionHeader('Help another student'),
          para(
            'The biggest help is free: share Paragon with a classmate, '
            'challenge a friend from a practice session, and report any '
            'answer that looks wrong. Every report is read.',
          ),
        ],
      ),
    );
  }
}
