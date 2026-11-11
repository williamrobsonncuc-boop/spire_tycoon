# spire_tycoon

Spire Tycoon is a beginner's idle game. You run a haunted office tower. The interface uses [Inter](https://github.com/rsms/inter) (SIL Open Font License, see `assets/fonts/LICENSE.txt`).

## How to run

From this folder:

```bash
flutter pub get
flutter run -d chrome
```

## Features

- Floor 1, The Executive Lobby: tap the goblin receptionist for gold. Upgrade Desk costs 10 × 1.10^level gold and adds 1 gold per tap.
- The lobby also earns gold every second. The game saves in the browser. When you come back, a welcome note pays what you missed, up to 8 hours. A 3 second practice "sponsor memo" doubles that payout. It is not a real ad.
