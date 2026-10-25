# Modern Names

Modern Names formats all default Pokémon species names in official Title Case (Generation 4+ standard) across Generation 1, Generation 2, and Generation 3 games in `pokemon-love2d`.

## Features
- **Official Title Case:** Formats all species names (e.g. `Pikachu`, `Charmander`, `Charizard`) across all dialogues, battle messages, party screens, storage boxes, summary menus, and Pokédex entries.
- **Punctuation & Gender Handling:** Full support for `Farfetch'd`, `Mr. Mime`, `Mime Jr.`, `Ho-Oh`, `Porygon2`, `Porygon-Z`, `Nidoran♀`, and `Nidoran♂`.
- **Strict Nickname Preservation:** Player-given custom nicknames (such as `Sparky`, `VOLT`, or `fluffy`) are never modified, re-cased, or altered.
- **Legacy Save Compatibility:** Unnicknamed Pokémon in pre-existing saves holding uppercase species names (e.g. `PIKACHU`) are treated as unnicknamed, rendering in modern title case and correctly receiving the new species name upon evolving.
- **Zero Save Mutation:** In-memory formatting only; save files and cartridge data are never altered or permanently modified. Rollback cleanly restores vanilla uppercase names.

## Compatibility
Works with all supported games:
- **Generation 1:** Red, Blue, Yellow
- **Generation 2:** Gold, Silver, Crystal
- **Generation 3:** FireRed, LeafGreen, Ruby, Sapphire, Emerald

## Installation
Place the `modern_names` directory or ZIP into your `pokemon-love2d` `mods` folder and enable it in the Mods menu.
