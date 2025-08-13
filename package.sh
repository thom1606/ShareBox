# Create the final DMG
create-dmg --volname ShareBox --window-size 600 400 --app-drop-link 400 100 --icon 'Applications' 400 100 --icon 'ShareBox.app' 100 100 --background ./assets/dmg-background.png ShareBox.dmg dist
# Detach the DMG volume
hdiutil detach /Volumes/ShareBox
