# SafeEats

A food label scanning app for iOS, written in Swift and SwiftUI.

Point your camera at an ingredient list and SafeEats reads it, matches it against a
vocabulary of roughly 1,500 allergen keywords in six languages, and tells you what it
found — flagging the allergens you have asked it to watch for in red, precautionary
"may contain" mentions in amber, and everything else in green.

---

## Contents

- [Features](#features)
- [How detection works](#how-detection-works)
- [Project structure](#project-structure)
- [Allergen data](#allergen-data)
- [Building and testing](#building-and-testing)
- [Disclaimer](#disclaimer)
- [Release history](#release-history)
- [App Store description](#app-store-description)
- [Screenshots](#screenshots)
- [Author](#author)

---

## Features

**Real-time allergen detection.** Scan a food label and SafeEats highlights the
allergens it recognises, so grocery shopping and meal planning take less guesswork.

**Every allergen, free.** SafeEats supports all 23 of its allergens at once and costs
nothing. Comparable apps cap a free account at three.

**It shows its working.** Each result names the exact keyword that triggered it, so a
match on an additive code such as `E322` is distinguishable from a match on the word
"soy" and you can judge it yourself.

**Precautionary statements are understood.** "May contain traces of peanuts and tree
nuts" is reported as a precaution rather than as an ingredient, and a precaution on one
line never softens an ingredient on the next.

**Six languages.** The keyword vocabulary covers English, Spanish, German, Dutch,
Chinese and Japanese, and text recognition is configured to match.

**21 background styles**, and your choice is remembered between launches.

---

## How detection works

A scan runs through four stages.

**1. Capture.** `CameraSession` keeps an `AVCaptureSession` running so the preview stays
live, but discards every frame until you tap **Scan Now**. Recognising text on every
frame would drain the battery for no benefit — one careful read is what you actually
want. The capture connection is rotated to portrait so the recogniser receives an
upright image.

**2. Recognition.** `TextRecognitionService` runs Vision's `VNRecognizeTextRequest` over
the single captured frame, restricted to the languages the vocabulary covers *and* the
installed Vision revision supports. Recognised lines are joined with newlines, because
the line structure of a label carries meaning.

**3. Normalisation.** `ScannedLabelText` folds the text two different ways:

| Folding | Applies to | Why |
| --- | --- | --- |
| Case + width + **diacritics** stripped | Latin-script terms | So a label reading `Maíz` matches the keyword `maiz` |
| Case + width only | Chinese, Japanese, Korean | Stripping combining marks would turn `バター` (butter) into `ハター`, which means nothing |

Runs of spaces collapse; line breaks are deliberately kept.

**4. Matching.** `AllergenDetector` searches the folded text for every keyword in
`KeywordIndex`, applying a boundary rule chosen by the keyword itself:

| Keyword | Boundary | Effect |
| --- | --- | --- |
| Latin word, e.g. `corn` | Must start at a word boundary | Matches `cornstarch`, does **not** match `ham` inside `graham` |
| Additive code, e.g. `E322` | Boundary on both sides | Does not match `E3221` |
| CJK, e.g. `牛奶` | None | These scripts are written without spaces |

A match is then classified as precautionary if a phrase such as "may contain" or
"produced in a facility" appears within 80 characters *before* it with no sentence
terminator in between. A single outright mention outweighs any number of precautions.

Finally each allergen is given a severity:

| Severity | Colour | Meaning |
| --- | --- | --- |
| `avoid` | Red | One of your allergens, named in the ingredients |
| `advisory` | Amber | One of your allergens, named only in a "may contain" statement |
| `informational` | Green | On the label, but not one of your allergens |

`AllergenDetector` is a pure value type — the same text and the same profile always
produce the same result, with no camera and no storage involved — which is what makes
the rules above straightforward to unit test.

### A deliberate bias

SafeEats errs towards over-reporting. A keyword matches inside longer words, and phrases
such as "gluten free" are **not** treated as negations, so a gluten-free label will still
flag gluten. For an allergy tool a false alarm is a nuisance; a missed allergen is not.
Showing the matched keyword on every result is what keeps that bias honest.

---

## Project structure

```
SafeEats/SafeEats/
├── App/              Composition root: the App, RootView, AppDependencies
├── Models/           Value types, all Decodable from the JSON resources
├── Services/         Resource loading, keyword index, detector, Vision, camera
├── State/            @Observable stores: allergen profile, theme, scan session
├── Support/          Text folding, boundary matching, colour parsing, logging
├── Views/            One folder per screen, plus shared components
└── Resources/        All content as JSON — see below
```

Dependencies are built once in `AppDependencies` and passed down explicitly; nothing
below that reaches for a singleton or loads a resource on its own.

---

## Allergen data

**No allergen data lives in Swift source.** Everything is JSON under
`SafeEats/SafeEats/Resources/`:

| File | Contents |
| --- | --- |
| `AllergenCatalog.json` | The 23 allergens, their display names, icons and categories |
| `Keywords/AllergenKeywords-<id>.json` | One file per allergen: its keywords, grouped by language |
| `DetectionRules.json` | Precautionary phrases and the lookbehind window |
| `Themes.json` | The 21 background styles |
| `OnboardingContent.json` | Walkthrough copy and the terms of use |

A keyword file looks like this. Most terms are plain strings; the object form is only
needed when a term carries extra meaning:

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

`kind` is one of `ingredient` (the default), `additiveCode`, `scientificName` or
`compound`. Language `und` is for terms that belong to no single language.

### Adding an allergen

1. Add an image set named after the allergen id to `Assets.xcassets`.
2. Create `Resources/Keywords/AllergenKeywords-<id>.json`.
3. Add an entry to the `allergens` array in `AllergenCatalog.json`.

No Swift changes are required. The same is true of correcting a keyword, adding a
language, adding a background style or amending the terms of use.

---

## Building and testing

**Requirements:** Xcode 16 or later, iOS 18.0 deployment target, a physical device for
camera scanning (the simulator has no camera).

```sh
open SafeEats/SafeEats.xcodeproj
```

The project uses Xcode's synchronized file groups, so files added under
`SafeEats/SafeEats/` are picked up automatically — there is no project file to edit.

Run the tests with **⌘U**, or:

```sh
xcodebuild test \
  -project SafeEats/SafeEats.xcodeproj \
  -scheme SafeEats \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

`SafeEatsTests` covers text folding, boundary matching, precautionary detection,
severity assignment, resource decoding and the migration of saved allergen selections
from the previous release. It runs against hand-built fixtures for the rules and against
the real bundled JSON for the integration checks.

---

## Disclaimer

SafeEats is a helpful tool, not a medical device. It may not always be accurate: user
error, misprints, poor lighting and camera limitations all affect the result, and the
keyword vocabulary does not cover every word used on every product. Manufacturers change
their ingredients, and packaging can be incomplete or incorrect.

**If you have allergies or intolerances, do not rely on SafeEats alone to decide whether
a product is safe. Always double-check the packaging yourself.** The full terms of use
are shown during onboarding and stored in `OnboardingContent.json`.

---

## Release history

| Version | Change |
| --- | --- |
| 1.0 Beta | Onboarding |
| 1.1 Beta | Allergen database |
| 1.1.1 Beta | Bug fixes |
| 1.2 Beta | Keyword database |
| 1.3 Beta | Camera text detection |
| 1.3.1 Beta | Camera bug fixes |
| 2.0 | Rebuilt: allergen data moved to JSON, modular architecture, rewritten matching engine, unit tests |

---

## App Store description

**SafeEats: an easy-to-use food label scanner for allergies**

SafeEats is an intuitive app designed to help people with food allergies or dietary
restrictions make safe, informed choices. Scan food labels in real time and SafeEats
identifies the allergens it finds, giving you peace of mind on every meal and every
grocery run.

**Features**

*Real-time allergen detection.* Scan a food label and see instantly which allergens
appear in the ingredient list.

*Ingredient summaries.* SafeEats does not just find dangerous ingredients — it
summarises what is on the label, so you can see everything it read.

*A clean, simple interface.* The layout and visuals are designed so you can scan a label
and understand the result at a glance.

**How to use SafeEats**

1. Open the app and go to the Allergens tab.
2. Switch on every allergen you need to avoid.
3. Go to the Scan tab and point your camera at the food label.
4. Tap Scan Now and review the results. Allergens you selected appear in red, "may
   contain" warnings in amber, and other detected ingredients in green.
5. Double-check the packaging, and eat safely.

**Ideal for**

- People with food allergies, checking labels for allergens.
- Parents making sure snacks and meals are safe for their children.
- Dietary-conscious shoppers avoiding unwanted ingredients.

We want to make food safety simpler. Download SafeEats to stay informed with every bite.

---

## Screenshots

<img width="300" alt="SafeEats logo" src="https://github.com/user-attachments/assets/01699d36-ff39-4748-b145-eaa51b9472ca">
<img width="300" alt="SafeEats logo, dark" src="https://github.com/user-attachments/assets/63b4ef95-1a98-4d13-ae84-579bce0564d6">

<img width="392" alt="Scan screen" src="https://github.com/user-attachments/assets/96a64e4f-a628-4bbe-803b-48c1e1d7b9d0">

![Allergen selection](https://github.com/user-attachments/assets/648c1b43-a3d5-4618-8482-e226d4e06ab3)

---

## Author

**Edison Law** — camera scanning, allergen keyword database, allergen toggles, scanning
delay and camera preview.
