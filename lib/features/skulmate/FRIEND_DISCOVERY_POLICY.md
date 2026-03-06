# skulMate Friend Discovery Policy

## Current Behavior

- **Search**: Users can search by `full_name` or `email` in `profiles`.
- **Who is shown**: Any profile matching the query (except self and existing friends).
- **RLS**: Authenticated users can read all profiles (migration 044: "Users can view public profiles" uses `USING (true)`).

## Why "No Users Found" or Zero Friends?

1. **Few matching profiles**: Most accounts may be parents/tutors; learners with `full_name`/`email` set might be few.
2. **Empty search**: Empty or very short query returns no results.
3. **No skulMate users yet**: Everyone in DB may not use skulMate (no game activity).

## Who Should We Show as Potential Friends?

### Option A: Search by name/email (current)
- **Pros**: Simple, user-driven.
- **Cons**: Requires knowing name/email; exposes PII; doesn’t surface “people like you.”

### Option B: Only skulMate users (recommended)
- **Who**: Users who have played at least one skulMate game (have rows in `user_game_stats`).
- **Why**: Only shows people who actually use skulMate, more relevant for friend discovery.
- **How**: Use an RPC function (e.g. `search_skulmate_users(query)`) because `user_game_stats` RLS only allows users to read their own stats—client-side joins cannot see other users’ stats.

### Option C: Same age/class range
- **Who**: Users in the same `learner_profiles.age_group` or class.
- **Why**: More relevant for learners.
- **Requires**: Learner profiles and age/class fields populated.

### Option D: Suggested friends
- **Who**: Users who played recently + similar age band.
- **Why**: “People like you” suggestions.
- **Requires**: More data and logic.

## Recommendation

1. Keep **name/email search** but restrict to **skulMate users only** (Option B) so we don’t expose non-skulMate profiles.
2. Add a **“Suggested friends”** section later: top skulMate players in the same age band (if available).
3. Add **privacy opt-in**: Let users opt out of being discoverable (new column, e.g. `profiles.skulmate_discoverable`).

## Implementation Notes

- To restrict search to skulMate users, create a Supabase RPC `search_skulmate_users(query TEXT)` that joins profiles + `user_game_stats` and returns matching users (bypasses RLS for the stats lookup).
- Add `skulmate_discoverable BOOLEAN DEFAULT true` to `profiles` if you want opt-out.
- Consider excluding `user_type IN ('tutor','admin')` from friend search.
