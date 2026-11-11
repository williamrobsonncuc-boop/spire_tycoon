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
- The spire earns gold every second. The game saves in the browser. When you come back, a welcome note pays what you missed, up to 8 hours. A 3 second practice "sponsor memo" doubles that payout. It is not a real ad.
- The tower is endless. Floors 1–5 are hand-built departments (lobby, Dragon Forge, alchemy, necromancy, HR & Legal). Later floors are generated, for example Floor 6: Marketing (Imps) and Floor 12: Legal Dept II. Build costs, timers, and income grow exponentially. Big numbers show as 1.2K, 3.4M, 5.6B, 7.8T, then aa, ab, and so on. The list only builds the floors on screen, and the save only stores floors you have started.
- Briefcase recruitment spends Gold Tickets (one per finished floor). The odds stay on the screen: Common 75%, Rare 18%, Epic 6%, Legendary 1%. Staff are Gary, Karen, Brutus, Vlad, and the Corporate Overlord Lich. TEST diamonds are a practice currency, not a real purchase. Shareholder Equity is reserved for restructuring.
- Construction can be finished with 1 TEST diamond, or a practice sponsor memo can cut the remaining time in half. Alchemy lines can clog, and other floors can get a sleeping orc. Tap the warning to clear it.
- Corporate Restructuring resets gold, floors, tickets, policies, and staff. You keep Shareholder Equity. Each point adds 10% gold, including on the next endless tower. TEST diamonds are kept.
- Tapping the receptionist pops a corporate line, such as "Can we circle back to this blood ritual after stand-up?"
- Sounds: a coin clink on tap, an office ding when you build or upgrade, a latch when a briefcase opens, and a buzz when a pipe clogs or an orc falls asleep. The mute button is in the header. The wav files in `assets/sounds` are original sine tones generated for this project, not samples from a sound library.
