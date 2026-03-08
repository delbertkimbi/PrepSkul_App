# skulMate Character Images

Place your character PNG images here. The app loads them by filename.

## Required Files

Add these files to this folder (`prepskul_app/assets/characters/`):

| Filename | Character | Description |
|----------|-----------|-------------|
| `elementary_male.png` | Mbiya | Elementary boy (5-10 yrs) |
| `elementary_female.png` | Nchia | Elementary girl (5-10 yrs) |
| `middle_male.png` | Etonge | Middle school boy (11-14 yrs) |
| `middle_female.png` | Aseh | Middle school girl (11-14 yrs) |
| `high_male.png` | Achu | High school boy (15-18 yrs) |
| `high_female.png` | Nde | High school girl (15-18 yrs) |

## Specs

- **Format:** PNG with transparent background recommended
- **Size:** ~256×256 px or square aspect ratio works best
- **Naming:** Use the exact filenames above (case-sensitive)

## Setup

1. Add your image files to this folder
2. Run `flutter pub get` (assets are already registered in `pubspec.yaml`)
3. Rebuild the app

The character selection screen and game screens will load them automatically.
