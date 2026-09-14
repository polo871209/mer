# Mer

Mer is a personal iOS app for tracking expenses and income, themed around a cat named Mer. It uses SwiftUI, SwiftData, Swift 6, and targets iOS 27. The app is not released, so breaking changes are allowed.

## Public repository

The repository is public at https://github.com/polo871209/mer. Every file, commit message, and pull request is public, and a pushed commit stays readable even after a history rewrite.

- Never commit personal information: the user's real entries, amounts, balances, entry counts, currencies, places, contacts, or paths and file names from the user's machine.
- If a preview, example, or commit message needs data, use made-up data.
- Never commit keys, certificates, provisioning profiles, `.env` files, or exported data such as CSV files.
- Never bypass the prek hooks with `--no-verify`. If gitleaks reports a finding, remove the data from the change. Ask the user before you add an allowlist entry to `.gitleaks.toml`.
- If personal information is already in a pushed commit, stop and tell the user.

## Design principles

User experience comes first. Frequent actions, such as adding an entry, get the fewest taps. If a change adds a tap or a screen to a frequent action, find a design without it, even if the code gets harder.

One thing has one view. A calendar, a currency picker, or an entry row looks and behaves the same on every screen. If the app already shows the thing, reuse that view. If that view does not fit the new screen, change the shared view instead of adding a second style.

## Native iOS or Mer style

- Use native iOS for structure and for any input that iOS has a control for: navigation, sheets, toolbars, `Form` and grouped `List` for settings and management screens, `.searchable`, swipe actions, confirmation dialogs, menus, segmented pickers, toggles, and text fields.
- Use Mer style only for content that shows Mer's identity: money amounts in `.crayon`, category badges, `sketchyCard` cards, charts, the keypad, the calendar, `MerEmptyState`, and entry rows.
- If iOS has no control that does the job, build it in Mer style.
- If a button floats on paper outside a list or card, give it `.buttonStyle(.glass)`.
- Give every screen and sheet `.paperBackground()`.

## File placement

Xcode picks up files under `Mer/` by folder. Never add file references to `project.pbxproj`.

- If a type serves one screen, put it in `Mer/Features/<Feature>/`.
- Keep a screen's private types in that screen's file, even if a skill asks for one type per file.
- If a view is used by two or more features, put it in `Mer/DesignSystem/Components/`.
- If a type is a SwiftData `@Model` or a value type used by two or more features, put it in `Mer/Models/`.
- Put `ModelContainer` setup and `UserDefaults` keys in `Mer/Persistence/`.
- If new code calls an API with a required reason, add that reason to `Mer/Resources/PrivacyInfo.xcprivacy`.
