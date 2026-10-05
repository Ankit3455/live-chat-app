# Destined — UI/UX Design Review (design phase only)

Scope: audit of the current Flutter UI (code on `main`, after the remediation work) and a proposed design direction shown as HTML mockups in this folder. **No app code was changed.** Open `index.html` to see the gallery.

Legend: **Existing** = in the app today. **Proposed** = design change only, using data or features the app already has.

---

## 1. Current screen map

| Screen | Purpose | Main action | Related |
|---|---|---|---|
| Splash | Brand intro | Auto-continues after 2 s (CTA is redundant) | Login / Home |
| Login | Email / Google sign-in | Log in | Signup, Age gate |
| Signup | Account + natal details (DOB, birth time, birth city) + 18+ | Sign up | Questionnaire |
| Age gate | 18+ confirmation for accounts without DOB | Continue | Home |
| Questionnaire (9 steps) | Basic profile | Continue / Finish & Create Avatar | Avatar preview |
| Avatar preview | DiceBear avatar or photo | Continue | Post-signup questions |
| Post-signup questions (5) | Relationship, height, body, education | Next / Finish | Voice intro → Home |
| Discover (tab) | Feed of profiles | Tap card → quick sheet | Discovery settings, Chat |
| Profile quick sheet | Another user's details | Message | Chat |
| Chats (tab) | Active / New conversations | Open chat | Chat |
| Chat | Messaging, voice notes, calls, block/report | Send | Calls, Profile |
| Calls (incoming/audio/video) | WebRTC calls | Accept / End | Chat |
| Games (tab) | Ludo, Carrom | Play | Lobbies |
| My Profile (tab) | Own profile, completion | Edit / Settings | Edit profile, Astrology, Settings |
| Settings / Discovery settings | Account, privacy, filters | Save & Apply | — |

---

## 2. Current UI rating

| Category | /10 | Key reason |
|---|---:|---|
| Overall UI | 5 | Strong cosmic identity, but inconsistent execution from screen to screen |
| UX | 4.5 | Key info hidden (age, distance, consent toggles); duplicate entry points |
| Visual hierarchy | 5 | The big completion banner and the bubble strip push the feed down; cards emphasise profession over age |
| Navigation | 6 | Persistent 4-tab shell is good; 10px labels, "Chats" tab vs "Messages" title |
| Typography | 5 | Montserrat everywhere, sizes vary (title 48 on splash vs 36 on login); 9–11px text |
| Color system | 4.5 | ~70 colour constants, raw Material colours, off-brand Google blue, blue read ticks |
| Components | 4 | CustomButton/CustomTextField barely reused; 3 different button styles in onboarding |
| Consistency | 4 | Solid purple app bar on Chats, gradient on Profile, none on Discover |
| Accessibility | 5 | Contrast improved in remediation; still tiny labels, tooltip-only call controls |
| Dating experience | 4.5 | Compatibility exists but is small; voice intro hidden; no full profile view |
| Modernity | 5 | Floating card animations and gloss overlays feel dated |
| Global appeal | 5 | English copy is clean; the strong astrology theme is a differentiator |
| **Overall product experience** | **4.8** | Functionally rich, visually and structurally unpolished |

**Strengths**
- Distinct identity: night-sky purple, pink glow, zodiac compatibility, voice intros.
- Feature-rich for its stage: chat, voice notes, consent-gated calls, games, block/report.
- Persistent bottom-nav shell, real loading/error/empty states on most main screens.
- Thoughtful safety rules already in the product (silent new chats, both-sides call consent, 18+).

**Weaknesses**
- No single design system: duplicated colours, button styles, and app bar treatments.
- Valuable data is collected but never shown (age and distance on cards, height/education, voice intro on My Profile).
- Important rules are hidden: call consent lives in an overflow menu; the New-chat silence isn't explained.
- Repetition: profile completion shown 3 times, Settings 2 times, the name 2 times in the quick sheet.
- Tiny text (9–11px) and icon-only controls; perpetual float animations.

---

## 3. Screen-by-screen audit

| Screen | Score | What works | Main problems (observed in code) | Recommended direction | Priority |
|---|---:|---|---|---|---|
| Splash | 5 | Brand moment, short | Auto-advance makes CTA pointless; title size differs from login | Keep auto-advance, drop CTA; reuse login hero | Low |
| Login | 5 | Clear fields, Google option, loading state | Off-brand blue Google button; errors only in snackbars; legal text missing | Mockup 01: white Google button, inline errors, legal links | High |
| Signup | 4.5 | Natal details explain purpose | No show/hide password; Terms not tappable; birth city asked again later; hand-built button | Same field/button components as login; link Terms; ask city once | High |
| Questionnaire | 4 | Progress header, save errors handled | Unthemed Material widgets; 3 button styles; mandatory bio/location; back on step 1 exits | Mockup 02: one question per screen, themed options, sticky CTA | High |
| Avatar preview | 5 | Clear states (creating/ready/error) | "Choose Profile Photo" is weakest element; hardcoded colours | Make photo vs avatar an equal choice; reuse button styles | Medium |
| Discover | 4.5 | Shimmer/empty/error states, filters | Banner + strip don't scroll; cards hide age; empty state mentions search that doesn't exist | Mockup 03: slim nudge, age + city on cards, filter chips, honest empty state | **Critical** |
| Quick sheet | 4 | Rich data, voice intro, Message CTA | Name twice; "Other: Discoverable" noise; no block/report; height/education never shown | Mockup 04: full profile screen with grouped sections and safety | **Critical** |
| Chats | 5 | Active/New split, confirm on delete, states | Title mismatch; solid purple bar; no presence; unused skeleton | Mockup 05: consistent header, presence, labelled swipe, undo | High |
| Chat | 4.5 | Replies, edit, voice, consent rule, block/report | Consent only in ⋯ menu; invisible input pill; voice notes buried; blue ticks | Mockup 06: consent card + sheet, mic button, brand ticks | **Critical** |
| Calls | 5 | Clear accept/decline, end confirmation | Controls labelled by tooltip only; audio uses different layout than video | Visible labels under controls; one call layout | Medium |
| My Profile | 4.5 | Completion, cosmic card, quick actions | Completion ×3, Settings ×2, misleading "verified" icon, voice intro absent | Mockup 07: one checklist, photo edit on avatar, single Settings | High |
| Settings | 6 | Grouped, danger zone, delete flow | Footer says "AvailChat"; "SOON" items | Rename footer; hide unfinished items | Low |
| Discovery settings | 6 | Disabled-when-off filters, unsaved guard | No "Other" in Show me; long form | Keep; restyle with design-system controls | Low |
| Game list | 5 | Clear cards, coming-soon state | Off-palette colours; stats missing with no state | Re-skin with tokens; add stats empty/loading | Low |

---

## 4. Design system (summary — full tokens in `css/design-system.css`)

- **Color:** primary gradient #7C3AED → #C026D3 → #EC4899 (CTAs, sent bubbles); violet 600/500/300; pink 500 (badges); **gold #F5C26B reserved for zodiac/compatibility**; bg #0F0A1A, surface #1E1531, surface-2 #2A1F42; text #F6F2FF (17.6:1), muted #B9AED3 (9.1:1), subtle #8D82A8 (captions only); success #34D399, warning #FBBF24, error #F87171.
- **Type:** Montserrat for display/headings (32/26/20/17), Inter for body 15/22, labels 13, captions 12. Nothing smaller than 11px.
- **Components:** primary/secondary/ghost/Google buttons (pill, 52h) with disabled + loading; inputs with focus/error/help; chips (default/selected/compat/glass); segmented tabs with count; profile hero, grid card; avatar with presence/ring; list rows with unread state; bubbles (sent/received/reply/voice/system line); composer with mic→send; switch; bottom nav (docked, 24px icons, 11px labels, safe-area); bottom sheet; banner; skeleton; empty state.
- **Rules:** 4pt spacing, 20px gutters; radius 10/14/20/28/pill; 48×48 touch targets; one outline icon set; glow only on primary CTA/send; motion 120–200ms, no perpetual float, honour reduced motion.

---

## 5. Screens mocked (17)

**Priority set:** 01 Login · 02 Onboarding question · 03 Discover · 04 Profile details · 05 Chats · 06 Chat (+ call consent sheet) · 07 My Profile.

**Second set:** 08 Signup · 09 Age gate · 10 Avatar (ready/creating/error) · 11 Voice intro (record/preview) · 12 Cosmic profile (+ how compatibility works) · 13 Calls (incoming, audio, video reconnecting, call ended) · 14 Settings (+ discovery settings, delete account) · 15 Splash + verify email · 16 Edit profile + blocked users · 17 Games + Carrom matchmaking.

Each screen shows default plus key states (error, loading, empty, sheet).

**Proposed additions (UI only, data or features already exist):** age, city and voice-intro badge on discover cards; full profile screen (instead of the sheet); visible call-consent card/sheet; "Preview" of own profile; filter chips on Discover; "How compatibility works" sheet (example numbers are illustrative, not the real formula); "Message instead" on incoming calls; a call-ended screen with the end reason; voice-intro prompts; password strength bar; numbered tips on verify email. All are labelled "Proposed" in the captions.

**Copy to confirm against the app before implementing:** settings subtitles ("New messages and calls", "Email the Destined team"), the Carrom lobby hint "Keep this screen open", and the age-gate trigger (shown when an account has no DOB on file).

---

## 6. Final design review

| Category | Existing | Proposed |
|---|---:|---:|
| UI quality | 5 | 8 |
| UX | 4.5 | 8 |
| Modernity | 5 | 8.5 |
| Consistency | 4 | 8.5 |
| Accessibility | 5 | 8 |
| Global appeal | 5 | 8 |
| Dating experience | 4.5 | 8 |
| **Overall** | **4.8** | **8.1** |

Proposed scores are a design estimate for the mockups; they still need user testing.

### Top 10 improvements (ranked)
1. **Adopt one design system** (tokens + shared components) and delete duplicate colours/buttons.
2. **Discover cards show age and city** (data exists); compatibility chip in gold; voice-intro badge.
3. **Full profile screen** replacing the quick sheet, with Block/Report and a sticky Message CTA.
4. **Visible call consent** in chat (card + sheet with both users' status) instead of the ⋯ menu.
5. **Onboarding rebuilt** on themed components: one question per screen, sticky CTA, safe back.
6. **Slim, scrollable completion nudge** and a single checklist on My Profile (remove 2 duplicates).
7. **Chat composer**: visible input pill, mic button for voice notes, brand-coloured read ticks.
8. **Consistent headers**: large title style on all tabs; "Chats" naming everywhere.
9. **Accessibility pass**: ≥11px text, visible labels on call controls, 48dp targets, semantics.
10. **Calmer motion**: remove perpetual floating cards/bubbles; keep press feedback only.

### Implementation roadmap
- **Phase 1 — Core UI:** design tokens in `AppColors`/`AppTheme` (rename/replace, not add a second system); shared Button, Input, Chip, Card, Avatar, ListRow, Banner, EmptyState widgets; bottom nav restyle.
- **Phase 2 — Core UX:** Discover cards + filter chips + nudge; full profile screen; chat consent card/sheet + composer; Chats header/presence/undo.
- **Phase 3 — Secondary screens:** login/signup, onboarding, avatar preview, My Profile checklist, calls, settings, games re-skin.
- **Phase 4 — Accessibility & responsive:** text-scale testing to 200%, Semantics on all icon buttons, small-phone (360dp) and tablet layouts, reduced motion.
- **Phase 5 — Final polish:** micro-interactions (press, send, like), haptics, empty-state illustrations, copy review, store screenshots.
