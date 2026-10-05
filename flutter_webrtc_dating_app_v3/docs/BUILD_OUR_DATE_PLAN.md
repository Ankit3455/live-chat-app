# Build Our Date — plan

> **Update (2026-10-05):** Build Our Date now runs on a shared chat-games
> engine together with **Rate It**, **Red Flag, Green Flag** and
> **Telepathy** (`lib/feature/games/chat_games/`). Data lives at
> `conversations/{convId}/games/{date|rate|flags|telepathy}`, chat cards use message
> type `game` with `metadata.game` / `metadata.stage`, and the chat entry is
> 📎 → **Games**. Paths below that say `date_game` / `datePlan` describe the
> first draft.
>
> **Turn clock + chess (2026-10-05):** every turn (chess) or round (the other
> games) has 30 seconds, enforced by the rules with `request.time`. A game
> starts when the second player joins. A timed-out round skips the missing
> pick; a timed-out chess turn passes (`0000`), or loses on time if in check.
> Chess lives at `games/chess` and stores only the move list; both phones
> replay it with `chess/chess_engine.dart` (perft-tested).
>
> **Tennis Duel (2026-10-05):** `games/tennis`. Each shot both pick L/C/R in
> secret (hitter aims, receiver runs); same zone = rally goes on, else point
> to the hitter; a timed-out pick loses the point. Real tennis scoring, first
> to 2 games. Games are listed in `chat_games/chat_game_registry.dart`.
>
> **Thumb War + duel engine (2026-10-05):** Tennis Duel and Thumb War share
> `chat_games/duel/` (DuelRules, DuelService) and one rules block
> (`match /games/{duel}`, clock field `turnStartedAt`). Thumb War: each clash
> pick Pounce / Guard / Feint (triangle) + grip meter 0..100; winner hits
> 15..35, no pick = pinned for 25; 100 HP, first to 2 rounds. Idea inspired
> by schoolyard thumb wars; mechanics, look and names are our own.

Two matched users plan a pretend date together by picking cards. At the end
they get a "Date card" that is shared in their chat, which gives them an easy
reason to plan a real one.

Stays on the free Spark plan: Firestore + client code only, no Cloud
Functions, no Storage. Pushes go through the existing Cloudflare Worker.

## 1. How it plays

1. In a chat, tap the attachment button (or the game list) → **Build Our Date**.
2. The other person gets an invite card in the chat ("<name> wants to plan a
   date with you 💌 [Play]") and a push.
3. Both go through **5 rounds**. Each round shows 4 cards; each person picks
   one in secret.

   | Round | Question | Example cards |
   |---|---|---|
   | 1. Vibe | "What kind of date?" | Chill · Adventure · Foodie · Creative |
   | 2. Place | "Where?" | Café · Beach · Rooftop · Bookstore |
   | 3. Food | "What do we eat?" | Street food · Pizza · Chai & pakode · Dessert crawl |
   | 4. Activity | "What do we do?" | Board games · Long walk · Movie · Karaoke |
   | 5. Time | "When?" | Sunrise · Afternoon · Sunset · Late night |

4. **Reveal** after each round:
   - Same card → "Match! ✨" and that card goes on the date.
   - Different cards → a coin flip decides. The coin comes from
     `gameId + round`, so both phones show the same result without storing it.
5. **Final Date card**: both avatars side by side, the 5 chosen cards, a match
   score ("4/5 in sync"), and a one-line title made from the picks
   ("Sunset rooftop + chai & pakode + karaoke").
6. The card is posted in the chat as a message. Buttons on it: **Play again**
   and **Let's do this for real** (sends a ready-made text: "Should we
   actually go? 😄").

Rule for the cards: each player's questionnaire answers (interests, habits)
can put one card of theirs in each round (for example, Night Owl → "Late
night"). Those cards show a "Made for you" badge. The rest are random.

## 2. Screens

| Screen | What it shows |
|---|---|
| Invite bubble (in chat) | Title, the sender's avatar, Join / Not now |
| Waiting | "Waiting for <name> to join…" + cancel |
| Round | Round question, 4 big cards (2×2), "<name> has picked ✓" badge |
| Reveal | Both picks flip over; match animation or coin flip |
| Date card | The final card; Share to chat / Play again |

Reuse: `AppColors`, `CustomButton`, `Haptics` (`success` on a match),
`MediaQuery.disableAnimationsOf` for reduced motion, DiceBear avatars.

## 3. Data (Firestore)

One document per conversation, so a pair only ever has one game running:

```
conversations/{convId}/date_game/current
{
  gameId: string,                 // also seeds the coin flip
  status: 'playing' | 'cancelled',
  createdBy: uid,
  players: [uidA, uidB],          // == conversation participants
  round: 0..5,                    // 5 = finished
  deck: { r0: [cardId x4], ... r4 },  // maps: Firestore has no nested arrays
  picks: { r0: { uidA: cardId, uidB: cardId }, ... },
  createdAt, updatedAt: serverTimestamp
}
```

Round results and the score are worked out from `picks`, not stored.

- Picks stay hidden in the UI until both are in. Both players can still read
  the document, so a curious player could see the other's pick early. That's
  fine for a casual game (no money, no ranking). Hiding picks for real needs a
  server, which we don't have.
- No new top-level collection, so account deletion and the existing
  conversation cleanup already cover it.

### Security rules (sketch)

```
match /conversations/{convId}/date_game/{doc} {
  allow read: if signedIn() && request.auth.uid in conv().participants;
  allow create: if signedIn()
    && doc == 'current'
    && request.auth.uid in conv().participants
    && request.resource.data.players == conv().participants
    && request.resource.data.status == 'invited'
    && !hasBlocked(...) both ways;
  allow update: if signedIn()
    && request.auth.uid in resource.data.players
    // only your own pick can be added, picks are never changed once set,
    // round only moves forward by 1, players/deck/createdBy are fixed
    && datePickOk();
  allow delete: if false;
}
```

Add emulator tests next to the existing rules tests:
- a stranger can't read the game
- you can't write the other person's pick
- you can't change a pick once it's set
- you can't jump rounds
- you can't start a game while either person is blocked

### Chat message for the Date card

- Add `datePlan` to `MessageType` and to the `type in [...]` list in the
  messages create rule.
- Card data goes in `metadata` (`{gameId, cards, score}`), so no new
  top-level fields are needed.
- **Also fill `message` with plain text** ("Our date: Sunset rooftop + chai &
  pakode + karaoke 💕"). Older app versions don't know `datePlan` and show the
  message as text (`_typeFrom` falls back to `text`), so they still show
  something sensible.
- Last-message preview in the chat list: "💌 Date plan".

### Push

Invite and "your turn" pushes go through the existing worker. Add a
`/game-push` route there (same ID-token check as `/chat-push`), or reuse
`/chat-push` by sending the invite as a chat message. **Reuse first**: the
invite is just a chat message with `type: datePlan`, `metadata.kind:
'invite'`, so no worker change is needed for v1.

## 4. Code layout

```
lib/feature/games/build_our_date/
  date_cards.dart            // decks + personal-card picking from answers
  date_game_service.dart     // create/join/pick/advance, listens to the doc
  build_our_date_screen.dart // round + reveal + final card
  widgets/date_card_tile.dart
  widgets/date_plan_bubble.dart  // chat bubble for invite + final card
```

Changes outside the folder:
- `models/chat_message_model.dart`: new type
- the chat bubble switch: render `DatePlanBubble`
- `attachment_sheet.dart`: entry point
- `game_list_screen.dart`: card that opens a "pick a match" list
- `firestore.rules` + rules tests

## 5. Build order

| Step | Work | Done when |
|---|---|---|
| 1 | `date_cards.dart` + unit tests (deck, personal card) | tests pass |
| 2 | Rules + emulator tests | CI rules job green |
| 3 | `date_game_service.dart` (create / join / pick / advance) | two emulator users can finish a game |
| 4 | Round + reveal UI | playable on two phones |
| 5 | Date card + chat bubble + `datePlan` type | card shows in chat; old build shows the text |
| 6 | Entry points (attachment sheet, game list) + polish (haptics, reduced motion, a11y labels) | design review OK |
| 7 | Publish rules in the console, release | live |

Rough size: about 3–4 focused days for steps 1–6.

## 6. Edge cases

- Someone leaves halfway: the game stays `playing`, and "Continue our date"
  shows in the chat. After 24 h without a pick it can be cancelled by either
  player.
- Unmatch or block during a game: the rules stop further writes, and the UI
  shows "This date can't continue".
- Both tap "Play again" at the same time: create runs in a transaction on
  `date_game/current`, so the second tap joins the new game instead of
  making another one.
- Offline: picks are queued by Firestore and sent when the phone is back
  online. The UI shows "Sending…" on the card.

## 7. Status (2026-10-05)

Built: steps 1–6 (cards + tests, rules + emulator tests, service, screens,
chat card, entry points). Still to do:

- Device test on two phones.
- Publish `firestore.rules` in the console (the new `date_game` block and the
  `datePlan` message type). Until then starting a game is denied.
- `wrangler deploy` so game pushes say "Let's play Rate It!" etc. instead of
  "New message" (optional; it works without it).

## 8. Later ideas

- Seasonal decks (Valentine's, monsoon, Diwali).
- "Real date done ✓" button that adds a badge to the Date card.
- City-aware cards using the existing location service (only if both allow
  location).
