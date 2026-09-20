# SafeEats

A food label scanner for iOS, written in Swift and SwiftUI.

Point your camera at an ingredient list. SafeEats reads it, checks it against about
1,500 allergen keywords in six languages, and shows you what it found. Allergens you
picked show in red, "may contain" warnings in amber, and everything else in green.

## Features

* Scans food labels with the camera and flags allergens on the spot.
* All 23 allergens are available, for free. Other apps cap you at three.
* Every result shows the keyword that triggered it, so you can see why something got
  flagged.
* Understands "may contain" and "produced in a facility" notices, and marks those
  differently from real ingredients.
* Keywords cover English, Spanish, German, Dutch, Chinese and Japanese.
* 21 background styles, and your pick is remembered.

## Using the app

1. Open the Allergens tab and switch on everything you need to avoid.
2. Go to the Scan tab and point the camera at the food label.
3. Tap Scan Now and read the results.
4. Check the packaging yourself before you eat.

## How it works

Tapping Scan Now grabs a single camera frame. The app deliberately does not run text
recognition on every frame, which would drain the battery for no real gain.

Vision reads the text from that frame, set up with the same six languages the keyword
lists cover.

The text is then folded for comparison: lowercased, width normalised, and for Latin
scripts stripped of accents, so a label reading "Maíz" matches the keyword "maiz".
Accents are left alone for Japanese, because stripping them turns バター (butter) into
ハター, which means nothing. Line breaks are kept, since they matter in the next step.

Then the app searches for every keyword. Latin words have to start at a word boundary,
so "corn" still matches "cornstarch" but "ham" no longer matches "graham". Additive
codes like E322 need a boundary on both sides. Chinese and Japanese are written without
spaces, so those match anywhere.

A match counts as a warning rather than an ingredient when a phrase like "may contain"
appears within 80 characters before it, with no full stop or line break in between. One
plain mention in the ingredient list outweighs any number of warnings.

That gives three levels of result:

* **Red**: one of your allergens, listed in the ingredients.
* **Amber**: one of your allergens, but only in a "may contain" notice.
* **Green**: found on the label, but not one of your allergens.

SafeEats leans towards flagging too much rather than too little. Keywords match inside
longer words, and "gluten free" is not read as a negation, so a gluten free label will
still flag gluten. A false alarm is annoying. A missed allergen is worse. Showing the
matched keyword on every result is what keeps that trade honest.

## Project structure

```
SafeEats/SafeEats/
├── App/        entry point, root view, dependency setup
├── Models/     value types, all decoded from JSON
├── Services/   resource loading, keyword index, detector, Vision, camera
├── State/      observable stores for the profile, theme and scan
├── Support/    text folding, matching, colour parsing, logging
├── Views/      one folder per screen, plus shared components
└── Resources/  all content, as JSON
```

Everything is built once in `AppDependencies` and passed down from there. Nothing below
that reaches for a singleton or loads its own files.

## Allergen data

No allergen data lives in Swift. It is all JSON under `SafeEats/SafeEats/Resources/`:

* `AllergenCatalog.json` lists the 23 allergens with their names, icons and categories.
* `Keywords/AllergenKeywords-<id>.json` holds one allergen's keywords, grouped by
  language.
* `DetectionRules.json` holds the "may contain" phrases.
* `Themes.json` holds the 21 background styles.
* `OnboardingContent.json` holds the walkthrough text and the terms of use.

A keyword file looks like this. Most terms are plain strings, and the longer form is
only needed when a term carries extra information:

```json
{
  "schemaVersion": 1,
  "allergenID": "soy",
  "groups": [
    { "language": "en", "terms": ["soy", "soybean", "tofu", "tempeh"] },
    { "language": "ja", "terms": ["大豆", { "text": "醤油", "note": "soy sauce" }] },
    {
      "language": "und",
      "terms": [
        { "text": "E322", "kind": "additiveCode", "note": "soy lecithin code" }
      ]
    }
  ]
}
```

`kind` can be `ingredient` (the default), `additiveCode`, `scientificName` or
`compound`. Language `und` is for terms that belong to no particular language.

To add an allergen:

1. Add an image set named after the allergen id to `Assets.xcassets`.
2. Create `Resources/Keywords/AllergenKeywords-<id>.json`.
3. Add an entry to the `allergens` array in `AllergenCatalog.json`.

No Swift changes needed. The same goes for fixing a keyword, adding a language, adding
a background style, or editing the terms of use.

## Building and testing

You need Xcode 16 or later and iOS 18. Scanning needs a real device, since the
simulator has no camera.

```sh
open SafeEats/SafeEats.xcodeproj
```

The project uses Xcode's synchronized groups, so any file added under
`SafeEats/SafeEats/` is picked up automatically. There is no project file to edit.

Run the tests with Cmd+U, or:

```sh
xcodebuild test \
  -project SafeEats/SafeEats.xcodeproj \
  -scheme SafeEats \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

They cover text folding, keyword matching, "may contain" handling, severity, JSON
decoding, and the migration of saved allergen picks from the previous release.

## Disclaimer

SafeEats is a helpful tool, not a medical device. It will not always be right. User
error, misprints, bad lighting and camera limits all affect the result, and the keyword
lists do not cover every word used on every product. Manufacturers change their
ingredients, and packaging can be incomplete or wrong.

If you have allergies or intolerances, do not rely on SafeEats alone to decide whether
something is safe for you. Always check the packaging yourself. The full terms of use
are shown when you first open the app.

## Release history

* 1.0 Beta: onboarding
* 1.1 Beta: allergen database
* 1.1.1 Beta: bug fixes
* 1.2 Beta: keyword database
* 1.3 Beta: camera text detection
* 1.3.1 Beta: camera bug fixes
* 2.0: allergen data moved to JSON, modular rewrite, new matching engine, unit tests

## Screenshots

<img width="300" alt="SafeEats logo" src="https://github.com/user-attachments/assets/01699d36-ff39-4748-b145-eaa51b9472ca">
<img width="300" alt="SafeEats logo, dark" src="https://github.com/user-attachments/assets/63b4ef95-1a98-4d13-ae84-579bce0564d6">

<img width="392" alt="Scan screen" src="https://github.com/user-attachments/assets/96a64e4f-a628-4bbe-803b-48c1e1d7b9d0">

![Allergen selection](https://github.com/user-attachments/assets/648c1b43-a3d5-4618-8482-e226d4e06ab3)

## Author

Edison Law. Camera scanning, allergen keyword database, allergen toggles, scanning
delay and camera preview.
