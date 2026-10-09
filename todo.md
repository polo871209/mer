# Manual steps

These steps need your Apple developer account, Xcode, or real devices, so an agent cannot do them. Do them in order, and delete a step when it is done.

## 1. Set the development team

In Xcode, open Signing & Capabilities and pick your team for both the Mer target and the MerWidget target. Make sure that the iCloud section shows CloudKit, Key-value storage, and the container `iCloud.com.polo.Mer` with no errors. Xcode creates the container the first time it signs the app. Make sure that the App Groups section of both targets shows `group.com.polo.Mer` with no errors, because the widget reads the category list from that group.

## 2. Test the Quick Add widget

1. Install Mer from Xcode and open it once, then add the small Quick Add widget to the Home Screen.
2. Make sure that the widget shows the icons of Food, Groceries, Transport, and Shopping in a 2×2 grid, or of the first four expense categories in your order.
3. Tap each icon. Make sure that Mer opens the New Entry keypad with that category already picked, with no slide-up animation. Do this once with Mer closed and once with Mer in the background.
4. Long-press the widget, pick Edit Widget, and choose four other categories, including one income category. Make sure that the widget shows them, and that a tap on the income category opens the keypad on Income.
5. Change the icon of a category in Settings > Categories. Make sure that the widget shows the new icon.
6. Turn on the app lock, send Mer to the background, and tap a category. Make sure that the keypad shows with that category after you unlock.

## 3. Test sync on two devices

Sign both devices in to the same Apple Account and install Mer from Xcode on each.

1. Add an entry on the first device. Make sure that it shows on the second device.
2. Change the main account in Settings > Accounts on the first device. Make sure that the second device shows the same main account.
3. Make sure that Settings > Categories shows each built-in category once on both devices.

## 4. Deploy the CloudKit schema to production

Do this after step 3 passes and before the first TestFlight build. TestFlight and App Store builds use the production environment, and sync fails there until the schema is deployed.

Deploy only when the `Entry` and `EntryCategory` fields are final. After deployment, CloudKit lets you add fields but never rename or delete them.

1. Open the CloudKit Console at https://icloud.developer.apple.com and select `iCloud.com.polo.Mer`.
2. Open Schema, then Deploy Schema Changes. Make sure that the changes cover only the record types `CD_Entry` and `CD_EntryCategory`, because SwiftData adds the `CD_` prefix.
3. Confirm the deployment.
