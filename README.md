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
- First day: the lights start dark, a phone note appoints you CEO of Spire Corp, you hire the receptionist as an intern, you build Floor 2, and a free briefcase is guaranteed Epic.
- Practice shop: Intern Pack £1.99, Manager's Choice £14.99, Boardroom Vault £89.99, Coffee Pass £4.99/mo, Executive Platinum £9.99/mo. Test purchase grants TEST diamonds. No real payment is taken.
- Weekend subsidiary: on Saturday and Sunday you can file one report a day. The leaderboard is a local stand-in, not a live server. A daily check-in streak pays 10 gold times the streak.
- Market domination: five automatic boardroom pitches. Your tower income is your strength. One campaign per day. A win pays gold. It is not a live match.
- Milestones at desk levels 10, 25, 50, 100, 200, and beyond double that floor's speed. Achievements such as Synergy Achieved, Hostile Takeover, and First Billion pay Gold Tickets once.
- Themed districts every 10 floors: Basement Dungeon, Corporate Offices, Skyscraper, Cloud Penthouse, Space Station, then Abyssal HQ. The background tint and later monsters change, and a dismissible note announces a new district once.
- Boss floors every 25 floors. An Audit or Hostile Takeover asks you to raise income before 45 seconds run out. Clearing it pays gold and hires Karen. Missing it returns the gold.
- Quests open with Floor 3: tap 25 times today, open a floor this week, recruit 3 staff this week. A streak freeze keeps your check-in if you miss a day. You can hold two.
- Managers have up to 5 stars. A sixth copy becomes a Gold Ticket. The codex shows every monster, with silhouettes for ones you have not met. A finished district set adds 5% gold.
- Research opens at floor 10. Compliance Points buy faster floors and cheaper builds. Shareholder Equity buys a longer offline cap and heavier taps. The labs stay after a restructuring.
- Every few minutes the office can have a visitor: a golden goblin courier, a one-minute Market Boom, an office party, or a power outage you tap to fix. The note stays until you tap it. A boom simply ends when its minute is up.
- Each restructuring unlocks something that stays: a cosmetic skin, Night Shift floors that pay 50% more, an auto-upgrade toggle, then a second skin. The dialog previews the next reward. Equity still adds 10% gold per point.
- Taps can crit for ×10. The chance is on the lobby (5%, plus 1% per Heavier Taps level). Tapping again within 2 seconds builds a combo, up to about ×2. A crit shakes the receptionist. One tap never pays more than 1T gold.
- The stats screen shows lifetime gold, floors built, time played, and a net-worth chart. Net worth is wallet gold plus 1,000 per Shareholder Equity point. The chart keeps the latest 40 points.
- Unlock pacing: quests at Floor 3, briefcases at Floor 5, research at Floor 10, restructuring at Floor 20. The first-day briefcase still opens during the tutorial. Odds stay on the recruitment screen before you can hire.

## Changelog

- Visual polish. The wallet pulses when gold changes, buttons show a press highlight, and the column stays readable from a 360px phone to a desktop window. Empty trophies, an empty codex, and a market day with no campaign yet say so in words.
- Balance pass. Early floors step by 1.48 so a new buy shows up about every half minute. From Floor 14 the step is 4.2, so Floor 20 and a restructuring land around an hour of active play, and the equity bonus makes the next climb faster. Construction waits cap at 3 minutes. A wallet that would overflow stays at its ceiling instead of resetting to zero. Shareholder Equity also multiplies tap gold.
- Unlock pacing. Quests, briefcases, research, and restructuring wait for Floors 3, 5, 10, and 20. A briefcase opened too early does not spend the ticket, and the tutorial briefcase still hires Brutus.
- Stats screen. Lifetime gold, floors built, and time played stay after a restructuring. A broken chart point is skipped, and the history cannot grow past 40 points.
- Tap crits and combos. The crit chance is shown on the lobby, a 2 second pause resets the combo, and a huge desk cannot crit into infinity.
- Restructuring rewards. The first reset unlocks a skin, the second unlocks Night Shift floors, the third unlocks auto-upgrade, and the fourth unlocks another skin. A locked skin in a save is ignored, and the count cannot go below zero or above 100.
- Office events. A courier and a party pay a capped pouch, a boom doubles gold for 60 seconds, and a power outage pauses income until you tap it. An unknown saved event name is ignored, and a broken save clears the labs too.
- Research labs. Levels are capped, a negative save level cannot go below zero, and the offline cap cannot pass 24 hours.
- Manager stars cap at 5, and a finished district set in the codex adds 5% gold.
- Daily and weekly quests, plus a streak freeze so one missed day does not reset the check-in.
- Boss floors every 25 floors. A failed audit returns the gold. The prize is capped so a huge tower cannot overflow.
- Themed districts every 10 floors, with a one-time unlock note. Floors past the last theme stay in Abyssal HQ instead of crashing.
- Milestones and an achievements screen. Ticket rewards are granted once.
- Market domination, a once-a-day auto campaign. A second run the same day does nothing, and a broken or huge income cannot mint an infinite prize.
- Weekend subsidiary and daily check-in.
- Bug hunt: huge upgrade costs and build timers no longer throw or become free; NaN, infinity, and negative balances load as zero; a broken floor in a save is skipped; a corrupted save still opens Floor 1; leaving the app for under 30 seconds still pays that gap, and longer absences stay capped at 8 hours.
