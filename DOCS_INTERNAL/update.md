# How are updates rolled out?

## 1. Archiving the project

Each new version of ShareBox is created by updating the `Build` number and/or the `Version` string. It is important that the versions for both the finder sync and the main app keep in sync. So always update them both.

After this is done, archive the project and distribute for `direct distribution`.

## 2. Registering the build to appcast

After the project is exported, zip it and place the zip inside the Builds folder. After doing so, open xCode and right click on the "Sparkle" project dependency.

This should take you to the checkouts folder, go up one and navigate to the artifects/sparkle/Sparkle/bin folder.

From here open a terminal and run `./generate_appcast [absolute path to "Builds" folder]`. This will update the appcast.xml for you.

## 3. Create the DMG

Move the generated ShareBox.app to the root folder and run the `./package.sh`. This should create a new DMG called ShareBox.dmg.

## 4. Creating a release

Create a new release on GitHub and upload both the zip and dmg files.

## 5. Updating Appcast.xml

After creating the release, we need to update the `<enclosure url="...` to match the url which you can copy from the zip in the newly created dmg. After this is done, you can submit the appcast.xml to GitHub.
