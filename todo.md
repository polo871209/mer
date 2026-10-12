# Manual steps

These steps need your Apple developer account, Xcode, or real devices, so an agent cannot do them. Do them in order, and delete a step when it is done.

## 0. Join the Apple Developer Program

A free Personal Team cannot sign the iCloud and Push Notifications capabilities, and it cannot upload to TestFlight or the App Store.

1. Make sure that your Apple Account has two-factor authentication turned on.
2. Open https://developer.apple.com/programs/enroll/, sign in with the Apple Account that Xcode uses, and enroll as an Individual. The fee is US$99 per year.
3. Wait for the approval email from Apple.
4. In Xcode, open Settings > Accounts and make sure that your account shows a team without "(Personal Team)".

## 1. Set the development team

In Xcode, open Signing & Capabilities and pick your team for both the Mer target and the MerWidget target. Make sure that the iCloud section shows CloudKit, Key-value storage, and the container `iCloud.com.polo.Mer` with no errors. Xcode creates the container the first time it signs the app. Make sure that the App Groups section of both targets shows `group.com.polo.Mer` with no errors, because the widget reads the category list from that group.

## 2. Reset your test data

In the default categories, Home is now Rent, Mer is now Pets, and School is new. Mer creates the default categories only in an empty store, and iCloud brings old categories back to a new install. Do these steps to start clean. They delete every entry, category, and trip.

1. Delete Mer from every device and simulator that has it.
2. Open the CloudKit Console at https://icloud.developer.apple.com, select `iCloud.com.polo.Mer`, and pick Reset Development Environment.
3. Install Mer from Xcode. Make sure that Settings > Categories shows Rent, School, and Pets, and that Settings > Budget shows Rent and School turned off.
4. In Settings > Categories, pick Everyday. Make sure that Flight, Hotel, and Tours show as hidden. Pick Trip. Make sure that Bills, Rent, School, Health, Sport, Travel, and Pets show as hidden.
5. Add a trip that starts today, then open the New Entry keypad and tap the category. Make sure that the picker shows Flight, Hotel, and Tours, and that Show Hidden reveals Rent and the other hidden categories.

## 3. Test the Quick Add widget

1. Install Mer from Xcode and open it once, then add the small Quick Add widget to the Home Screen.
2. Make sure that the widget shows the icons of Food, Groceries, Transport, and Shopping in a 2×2 grid, or of the first four expense categories in your order.
3. Tap each icon. Make sure that Mer opens the New Entry keypad with that category already picked, with no slide-up animation. Do this once with Mer closed and once with Mer in the background.
4. Long-press the widget, pick Edit Widget, and choose four other categories, including one income category. Make sure that the widget shows them, and that a tap on the income category opens the keypad on Income.
5. Change the icon of a category in Settings > Categories. Make sure that the widget shows the new icon.
6. Turn on the app lock, send Mer to the background, and tap a category. Make sure that the keypad shows with that category after you unlock.

## 4. Test Siri

Do this on a real iPhone. Install Mer from Xcode and open it once, so that Siri learns the category names.

1. Say "Log Food in Mer". Make sure that Siri asks "How much?", and that after you say "12" it replies that it logged 12 for Food and shows the entry row. Make sure that the entry shows in Mer with the Food category.
2. Say "Log Salary in Mer" and give an amount. Make sure that the entry is income.
3. Say "Log an expense in Mer". Make sure that Siri asks for the amount and then shows the category list.
4. Rename a category in Settings > Categories, for example Food to Lunch. Make sure that "Log Lunch in Mer" works.
5. Start a trip with a currency, for example New Taiwan Dollar, and say "Log Food in Mer" with "200". Make sure that the entry is NT$200 on the trip, with the converted amount shown under it.
6. Say "Log 12 ringgit for lunch in Mer" in one sentence. Write down what happens, because it shows whether the iOS 27 Siri fills the amount and the currency without a question. If Siri does not hear "Mer" correctly, write down what it hears.
7. Open the Shortcuts app and make sure that Add Entry shows Amount, Category, Currency, Date, and Note.

## 5. Test sync on two devices

Sign both devices in to the same Apple Account and install Mer from Xcode on each.

1. Add an entry on the first device. Make sure that it shows on the second device.
2. Change the main account in Settings > Accounts on the first device. Make sure that the second device shows the same main account.
3. Make sure that Settings > Categories shows each built-in category once on both devices.
4. Add a trip in Settings > Trips on the first device and tap Start Trip. Make sure that the second device shows Mer in the travel hat and the trip card on Home.
5. Turn on the budget in Settings > Budget on the first device, set an amount, and turn off one category. Make sure that the second device shows the same amount, the same category turned off, and the budget card on Home.
6. On the first device, add an entry, tap the receipt button, and pick Take Photo. Make sure that Mer asks for camera access once, and that View Receipt shows the photo after you save. Make sure that the second device shows the same receipt in that entry.
7. On the second device, pick Share Receipt in that entry, then Save Image. Make sure that Mer asks for photo library access once and that the photo shows in Photos. Share it again with Save to Files, and make sure that Files shows `Receipt.jpg`.
8. On the second device, pick Remove Receipt in that entry and save. Make sure that the first device shows no receipt.

## 6. Deploy the CloudKit schema to production

Do this after step 5 passes and before the first TestFlight build. TestFlight and App Store builds use the production environment, and sync fails there until the schema is deployed.

Deploy only when the `Entry`, `EntryCategory`, and `Trip` fields are final. After deployment, CloudKit lets you add fields but never rename or delete them.

1. Open the CloudKit Console at https://icloud.developer.apple.com and select `iCloud.com.polo.Mer`.
2. Open Schema, then Deploy Schema Changes. Make sure that the changes cover only the record types `CD_Entry`, `CD_EntryCategory`, and `CD_Trip`, because SwiftData adds the `CD_` prefix.
3. Confirm the deployment.

## 7. Create the app in App Store Connect

1. Open https://appstoreconnect.apple.com, then Apps, then the + button, then New App.
2. Pick iOS, type the name Mer, pick your primary language, pick the bundle ID `com.polo.Mer`, and type a SKU such as `mer`. If the name Mer is taken, use a longer store name such as "Mer: Money Notes". The Home Screen name stays Mer, because `CFBundleDisplayName` sets it.
3. Open Pricing and Availability. Set the price to Free and pick the countries.
4. Open Business and answer the Digital Services Act trader question. App Store Connect does not release the app in the EU until you answer it.

## 8. Fill in privacy in App Store Connect

1. Open https://polo871209.github.io/mer/privacy/ and make sure that the Mer privacy policy shows.
2. In App Store Connect, open Mer, then App Information, and set Privacy Policy URL to that address.
3. Open App Privacy and answer that Mer does not collect data. Make sure that the product page preview shows "Data Not Collected".

## 9. Upload a build and test it in TestFlight

Do this after step 6, because the TestFlight build uses the production CloudKit environment. The production environment starts empty, so entries from your Xcode builds do not show in it.

1. In the Xcode build on your iPhone, open Settings > Export CSV and save the file. You import it again in step 6 of this list.
2. Make sure that your Xcode is a release version and not a beta, because App Store Connect rejects builds from a beta Xcode.
3. In Xcode, pick Any iOS Device as the destination, then Product > Archive.
4. In the Organizer, pick the archive, then Distribute App, then App Store Connect, then Upload.
5. Wait until App Store Connect finishes processing the build, then add yourself to internal testing in TestFlight. Delete the Xcode build of Mer from the iPhone and install Mer from TestFlight.
6. Open Settings > Import CSV and pick the file from step 1. Make sure that all your entries show.
7. Install the TestFlight build on a second device. Make sure that an entry added on one device shows on the other device. Make sure that the widget and Siri work.

## 10. Fill in the App Store page

1. Take screenshots on an iPhone with a 6.9-inch display, or in that simulator. App Store Connect needs at least one, and it takes up to ten. Mer is iPhone only, so no iPad screenshots are needed.
2. In the 1.0 version page, add the screenshots, the subtitle, the description, the keywords, the support URL, and the copyright line. The support URL must open a page that tells people how to contact you.
3. In App Information, set the primary category to Finance and fill in the age rating questions.
4. In App Review Information, add your contact details. In the notes, write that Mer needs no account and that the Face ID lock is optional in Settings.

## 11. Submit for review

1. In the 1.0 version page, pick the build from step 9.
2. Choose Manually release this version, so that you pick the release day.
3. Pick Add for Review, then Submit to App Review.
4. When Apple approves Mer, pick Release This Version.
