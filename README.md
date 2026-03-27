# TennisScorer iOS

iOS + Apple Watch port of the Android TennisScorer app.

---

## Project Structure

```
TennisScorer-iOS/
├── Shared/
│   ├── Models/
│   │   ├── Enums.swift          — PlayerSide, MatchFormat, PointTag, etc.
│   │   └── Models.swift         — MatchConfig, MatchState, PointEvent, etc.
│   └── Engine/
│       ├── TennisEngine.swift   — Core scoring logic + undo
│       ├── SituationDetector.swift
│       ├── ScoreFormatter.swift
│       └── SpeechFormatter.swift
├── TennisScorer/                — iPhone app
│   ├── App/
│   ├── Settings/
│   ├── Persistence/
│   ├── ViewModels/
│   ├── Views/
│   ├── Audio/
│   ├── Cast/
│   └── Sync/
└── TennisScorer Watch App/      — Apple Watch app
    ├── Views/
    ├── ViewModels/
    └── Sync/
```

---

## Setup in Xcode

### Step 1 — Create the Xcode Project

1. Open **Xcode** → File → New → Project
2. Choose **iOS → App**
3. Product Name: `TennisScorer`
4. Bundle Identifier: `com.matt.tennisscorer`
5. Interface: **SwiftUI**
6. Language: **Swift**
7. Check **"Include Tests"** if desired
8. When prompted to add watchOS companion: **YES** — or after creation, File → New → Target → watchOS → Watch App, name it `TennisScorer Watch App`

### Step 2 — Add Source Files

1. In Xcode's project navigator, **right-click** each folder group and choose **"Add Files to TennisScorer"**
2. Add files in this order to avoid missing-type errors:
   - First: all files from `Shared/Models/` and `Shared/Engine/`
   - Then: all files from `TennisScorer/`
   - Then: all files from `TennisScorer Watch App/`
3. When adding Shared files, add them to **both targets** (iPhone + Watch) by checking both boxes in the target membership panel

### Step 3 — Configure Targets

**iPhone target:**
- Minimum deployment: iOS 16.0
- Bundle ID: `com.matt.tennisscorer`

**Watch target:**
- Minimum deployment: watchOS 9.0
- Bundle ID: `com.matt.tennisscorer.watchkitapp`

### Step 4 — Set Up WatchConnectivity

No extra setup needed — `WatchConnectivity` is a system framework. Just ensure both targets have it linked under:
Target → General → Frameworks, Libraries, and Embedded Content → `+` → `WatchConnectivity.framework`

### Step 5 — Chromecast (Optional)

The Cast integration is stubbed in `TennisScorer/Cast/CastManager.swift`. To complete it:

1. Install CocoaPods if not already: `sudo gem install cocoapods`
2. In the project root, create a `Podfile`:
   ```ruby
   platform :ios, '16.0'
   target 'TennisScorer' do
     use_frameworks!
     pod 'google-cast-sdk-no-bluetooth', '~> 4.8'
   end
   ```
3. Run `pod install` — open `TennisScorer.xcworkspace` from then on
4. Follow the TODO comments in `CastManager.swift` to wire up the real GCKCastContext and session manager

---

## Watch Pinch Gestures

On Apple Watch, the scoring gestures in `MatchControlView` are:
- **Single tap** on the background (not on a button) → server wins point
- **Double tap** on the background → receiver wins point
- Buttons still work normally for direct point entry

Apple Watch does not expose a physical pinch gesture API like Android's `KEYCODE_NAVIGATE_NEXT`. The background tap approach is the closest equivalent and works reliably.

---

## Chromecast Receiver

The existing receiver at `https://mattg241.github.io/tennis-scorer-reciever/` works unchanged — it receives the same JSON payload over the same namespace `urn:x-cast:com.matt.tennisscorer`. No changes needed to the receiver or the Cast Developer Console registration.

---

## App Store

Bundle ID to use: `com.matt.tennisscorer` (matches Android)
You will need a separate Apple Developer account ($99/year) and App Store Connect listing.
