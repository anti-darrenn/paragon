import 'package:flutter/material.dart';
 
class AppColors {
  // ── Primary brand color ───────────────────────────────────────────
  static const primary     = Color(0xFFFF7700); // Orange — from Figma
  static const primaryDark = Color(0xFFCC5F00); // Pressed shade — primary at 80% (~20% darker)

  // ── Secondary brand color ─────────────────────────────────────────
  static const secondary = Color(0xFF8B5CF6); // Figma: secondary — purple
 
  // ── Dark mode backgrounds ─────────────────────────────────────────
  static const backgroundDark = Color(0xFF0D1117);
  static const surfaceDark    = Color(0xFF161B22);
  static const borderDark     = Color(0xFF30363D);
 
  // ── Light mode backgrounds ────────────────────────────────────────
  static const backgroundLight = Color(0xFFF6F8FA);
  static const surfaceLight    = Color(0xFFFFFFFF);
  static const borderLight     = Color(0xFFD0D7DE);
 
  // ── Semantic feedback colors ──────────────────────────────────────
  static const correct = Color(0xFF3FB950); // green — correct answer · Figma: success
  static const wrong   = Color(0xFFF85149); // red   — wrong answer   · Figma: error
  static const warning = Color(0xFFD29922);
  static const submitGreen = Color(0xFF238636); // exam submit CTA — distinct from `correct` · Figma: success-overlay

  // ── Dark mode surfaces (elevated / inactive) ──────────────────────
  static const trackDark = Color(0xFF21262D); // progress track, inactive nav dots
  static const accentBlue = Color(0xFF58A6FF); // informational accent (stats, links)

  // ── Overlay ────────────────────────────────────────────────────────
  static const overlay = Color(0xFF000000); // Figma: overlay — apply with reduced opacity at call site (e.g. overlay.withAlpha(...))

  // ── Third-party brand colors (fixed — never theme these) ─────────
  static const googleBlue = Color(0xFF4285F4); // Google "G" mark, per Google brand guidelines

  // ── Text ──────────────────────────────────────────────────────────
  static const textPrimaryDark    = Color(0xFFE6EDF3);
  static const textSecondaryDark  = Color(0xFF8B949E);
  static const textPrimaryLight   = Color(0xFF24292F);
  static const textSecondaryLight = Color(0xFF57606A);
 
  // ── Subject colors (muted — readable on dark bg, distinct) ───────
  // Original picks softened: saturation reduced ~30%, lightness pulled
  // to mid-range so they glow gently without clashing.
  static const subjectMathematics       = Color(0xFFC47070); // muted red
  static const subjectFurtherMathematics = Color(0xFFC49A4A); // muted amber
  static const subjectBiology           = Color(0xFF5EA87A); // muted green
  static const subjectChemistry         = Color(0xFF86B44A); // muted lime
  static const subjectPhysics           = Color(0xFF4AA89C); // muted teal
  static const subjectEconomics         = Color(0xFF4A9EC4); // muted sky blue
  static const subjectGovernment        = Color(0xFF7A8FA8); // muted slate
  static const subjectEnglishLanguage   = Color(0xFF9070C4); // muted purple
  static const subjectMusic             = Color(0xFFC46A96); // muted pink
  static const subjectCommerce          = Color(0xFF6A66C4); // muted indigo
 
  // ── Subject color lookup ──────────────────────────────────────────
  // Use this anywhere you need to get a subject's color by name.
  static Color forSubject(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathematics':        return subjectMathematics;
      case 'further mathematics': return subjectFurtherMathematics;
      case 'biology':            return subjectBiology;
      case 'chemistry':          return subjectChemistry;
      case 'physics':            return subjectPhysics;
      case 'economics':          return subjectEconomics;
      case 'government':         return subjectGovernment;
      case 'english language':   return subjectEnglishLanguage;
      case 'music':              return subjectMusic;
      case 'commerce':           return subjectCommerce;
      default:                   return primary;
    }
  }
}