# MyAppCleaner

MyAppCleaner is an iOS storage cleaner app that helps users free up device space by finding duplicate photos, large videos, screenshots, and duplicate contacts. 


## Features (Core Loop)
- **Storage Dashboard**: View used and free device storage.
- **Similar Photos**: Groups visually similar photos using timestamp clustering for rapid scanning. Marks the best photo automatically.
- **Large Videos**: Lists videos sorted by file size, highlighting those over 10MB.
- **Screenshots**: Aggregates all screenshots in a single grid for easy multi-selection.
- **Duplicate Contacts**: Scans the Contacts library to group identical names and allows easy merging/deletion.
- **Safe Deletion**: A final review screen guarantees nothing is deleted without explicit user consent via iOS native dialogs.

## How to Build and Run
This project was generated using [XcodeGen](https://github.com/yonaskolb/XcodeGen) to maintain a clean project structure.

1. Open `MyAppCleaner.xcodeproj` in Xcode.
2. Select the **MyAppCleaner** target.
3. Under the **Signing & Capabilities** tab, select your personal Apple Developer Team to enable code signing.
4. Plug in a physical iPhone and select it as the run destination (Simulators do not have real photo/contact libraries).
5. Build and Run (**⌘R**).

*Note: If using a free Apple ID, you may need to go to **Settings > General > VPN & Device Management** on your iPhone to trust the developer certificate before the app will launch.*

