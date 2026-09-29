# Game translations

All player-facing copy lives in the locale catalogs in this folder:

- `en.json` — English and the fallback language
- `de.json` — German
- `fr.json` — French

Every catalog must contain the same keys. Game code and configuration files
refer to those keys through the `Localization` autoload. Add new player-facing
text to all three catalogs instead of embedding it in scripts or config files.

The selected language is stored in `user://settings.cfg` on every platform. A
web export also stores the locale code in the `dinos4helena_language` cookie for
one year.
