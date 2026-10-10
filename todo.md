# Manual steps

These steps need your Apple developer account, Xcode, or real devices, so an agent cannot do them. Do them in order, and delete a step when it is done.

## 1. Set the development team

In Xcode, open Signing & Capabilities and pick your team for both the Mer target and the MerWidget target. Make sure that the iCloud section shows CloudKit, Key-value storage, and the container `iCloud.com.polo.Mer` with no errors. Xcode creates the container the first time it signs the app. Make sure that the App Groups section of both targets shows `group.com.polo.Mer` with no errors, because the widget reads the category list from that group.

## 2. Reset your test data

In the default categories, Home is now Rent, Mer is now Pets, and School is new. Mer creates the default categories only in an empty store, and iCloud brings old categories back to a new install. Do these steps to start clean. They delete every entry, category, and trip.

1. Delete Mer from every device and simulator that has it.
2. Open the CloudKit Console at https://icloud.developer.apple.com, select `iCloud.com.polo.Mer`, and pick Reset Development Environment.
3. Install Mer from Xcode. Make sure that Settings > Categories shows Rent, School, and Pets, and that Settings > Budget shows Rent and School turned off.

## 4. Test the Quick Add widget

1. Install Mer from Xcode and open it once, then add the small Quick Add widget to the Home Screen.
2. Make sure that the widget shows the icons of Food, Groceries, Transport, and Shopping in a 2×2 grid, or of the first four expense categories in your order.
3. Tap each icon. Make sure that Mer opens the New Entry keypad with that category already picked, with no slide-up animation. Do this once with Mer closed and once with Mer in the background.
4. Long-press the widget, pick Edit Widget, and choose four other categories, including one income category. Make sure that the widget shows them, and that a tap on the income category opens the keypad on Income.
5. Change the icon of a category in Settings > Categories. Make sure that the widget shows the new icon.
6. Turn on the app lock, send Mer to the background, and tap a category. Make sure that the keypad shows with that category after you unlock.

## 5. Test Siri

Do this on a real iPhone. Install Mer from Xcode and open it once, so that Siri learns the category names.

1. Say "Log Food in Mer". Make sure that Siri asks "How much?", and that after you say "12" it replies that it logged 12 for Food and shows the entry row. Make sure that the entry shows in Mer with the Food category.
2. Say "Log Salary in Mer" and give an amount. Make sure that the entry is income.
3. Say "Log an expense in Mer". Make sure that Siri asks for the amount and then shows the category list.
4. Rename a category in Settings > Categories, for example Food to Lunch. Make sure that "Log Lunch in Mer" works.
5. Start a trip with a currency, for example New Taiwan Dollar, and say "Log Food in Mer" with "200". Make sure that the entry is NT$200 on the trip, with the converted amount shown under it.
6. Say "Log 12 ringgit for lunch in Mer" in one sentence. Write down what happens, because it shows whether the iOS 27 Siri fills the amount and the currency without a question. If Siri does not hear "Mer" correctly, write down what it hears.
7. Open the Shortcuts app and make sure that Add Entry shows Amount, Category, Currency, Date, and Note.

## 6. Test sync on two devices

Sign both devices in to the same Apple Account and install Mer from Xcode on each.

1. Add an entry on the first device. Make sure that it shows on the second device.
2. Change the main account in Settings > Accounts on the first device. Make sure that the second device shows the same main account.
3. Make sure that Settings > Categories shows each built-in category once on both devices.
4. Add a trip in Settings > Trips on the first device and tap Start Trip. Make sure that the second device shows Mer in the travel hat and the trip card on Home.
5. Turn on the budget in Settings > Budget on the first device, set an amount, and turn off one category. Make sure that the second device shows the same amount, the same category turned off, and the budget card on Home.

## 7. Deploy the CloudKit schema to production

Do this after step 6 passes and before the first TestFlight build. TestFlight and App Store builds use the production environment, and sync fails there until the schema is deployed.

Deploy only when the `Entry`, `EntryCategory`, and `Trip` fields are final. After deployment, CloudKit lets you add fields but never rename or delete them.

1. Open the CloudKit Console at https://icloud.developer.apple.com and select `iCloud.com.polo.Mer`.
2. Open Schema, then Deploy Schema Changes. Make sure that the changes cover only the record types `CD_Entry`, `CD_EntryCategory`, and `CD_Trip`, because SwiftData adds the `CD_` prefix.
3. Confirm the deployment.
