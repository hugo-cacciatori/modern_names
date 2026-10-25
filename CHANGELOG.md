# Changelog

All notable changes to the `modern_names` mod will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-25

### Added
- Formatted Pokémon species display names in official modern Title Case (Generation 4+ standard) across Generation 1, Generation 2, and Generation 3 games.
- Full exception handling for special punctuation and gender glyphs:
  - `Nidoran♀` and `Nidoran♂` preserve gender symbols.
  - `Farfetch'd` preserves apostrophe and lowercase `'d`.
  - `Mr. Mime` and `Mime Jr.` preserve periods and spacing.
  - `Ho-Oh` and `Porygon-Z` preserve hyphens and capitalization.
  - `Porygon2` preserves numerals.
  - `Type: Null` preserves colons and spacing.
- Strict player nickname preservation: custom nicknames (e.g. `Sparky`, `VOLT`, `fluffy`) are never modified or re-cased.
- Legacy save compatibility: unnicknamed Pokémon stored with default uppercase names (e.g. `PIKACHU`) are treated as unnicknamed, rendering in modern title case and correctly updating upon evolution.
- Clean rollback and reset behavior: restoring original uppercase names and disabling bridges without modifying player save files.
