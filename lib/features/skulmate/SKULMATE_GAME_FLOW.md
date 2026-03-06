# skulMate Game Flow – Clear Approach

## Game Type Selection: Auto-Select

**Decision:** We use **automatic game type selection**. The API chooses the best game type for the content and returns `gameType`. We route directly to that game screen—no post-generation picker.

- **We do NOT** show "choose your game type" after generation.
- **Rationale:** Lower friction, clearer flow. The API has full context (content structure, topics, format) and can pick the best format (quiz for Q&A, flashcards for terms, matching for pairs, etc.).
- **If API chooses poorly:** Improve API prompts and validation; add a picker only if users consistently report mismatches.

### Routing Logic (`game_generation_screen.dart`)

| API `gameType`   | Screen                   |
|------------------|--------------------------|
| quiz             | QuizGameScreen           |
| flashcards       | FlashcardGameScreen      |
| matching         | MatchingGameScreen       |
| fill_blank       | WordGuessingGameScreen   |
| drag_drop        | DragDropGameScreen       |
| simulation       | SimulationGameScreen     |
| mystery          | MysteryGameScreen        |
| escape_room      | EscapeRoomGameScreen     |
| (other)          | QuizGameScreen (fallback)|

### Alternative: User Picks After Generation

If we ever switch to letting users pick:

1. After generation, show a screen: “Your game is ready! Choose how to play:” with cards for Quiz, Flashcards, Matching, etc.
2. Each card would need to validate that the game data supports that format (e.g., quiz needs question + options).
3. Pros: User agency. Cons: Extra step, possible mismatch if data doesn’t support chosen format.

**Decision:** Stick with auto-select for now. Add a picker only if users clearly ask for it or if the API often returns a format that doesn’t fit the content.
