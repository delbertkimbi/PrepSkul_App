Here's a plain-English prompt you can paste into Cursor:

---

**Build a "Matching" learning game.**

**The goal of the game:**
The player is shown a list of terms on the left and a list of definitions on the right, in scrambled order. Their job is to correctly pair every term with its matching definition. The game ends when all pairs are matched.

**How the game works (rules):**

1. When the game starts, both columns are shuffled independently so the correct pairs are never side-by-side.
2. The player must always tap a **term on the left first**, then tap a **definition on the right** to attempt a match.
3. If the two belong together, the pair is locked in as "solved" and stays visible but disabled.
4. If they don't match, both briefly flash to show the mistake, then reset so the player can try again. There is no penalty, no score deduction, and no limit on attempts.
5. The player can change their mind before picking a definition by tapping a different term.
6. A running counter shows how many pairs have been matched so far (e.g. "3 / 6 matched").
7. A "Reset" button reshuffles everything and starts over at any time.
8. When every pair is matched, a celebration screen appears with a trophy, a congratulatory message, and a "Play again" button.

**UI interaction responses (what the player sees and feels):**

- **Tapping a term:** It lifts up with a soft shadow and fills with a bold gradient color to clearly show it's the active selection. Only one term can be selected at a time.
- **Tapping a definition while a term is selected:**
  - **Correct match:** Both cells smoothly turn a soft green, a checkmark appears next to the term, the text gets a subtle strike-through, and they fade slightly to show they're "done." They can no longer be tapped.
  - **Wrong match:** Both cells flash red with a red border for about half a second, then return to normal. The selected term is automatically deselected so the player can start a fresh attempt.
- **Tapping an already-matched cell:** Nothing happens — it's locked.
- **Tapping a definition with no term selected:** Nothing happens — the game gently ignores it.
- **Hover (desktop):** Unmatched cells get a subtle colored border to invite interaction.
- **Reset button:** All cells animate back to their default state, the columns reshuffle, and the counter returns to 0.
- **Winning the game:** The grid is replaced by a centered card that scales in with a trophy icon, the headline "All matched! 🎉", and a "Play again" button.

**Visual style:**
Soft, modern, neumorphic feel — rounded cells, gentle shadows, generous spacing, smooth transitions on every state change. Terms feel slightly heavier/bolder than definitions. The whole experience should feel tactile, forgiving, and satisfying, like flipping cards on a clean desk.

---

Plain-English Match game prompt ready to paste into Cursor.

Add Game Instructions Modal
Show Match Review Screen
Add Difficulty Toggle
Add Sound and Haptics
Improve Accessibility States