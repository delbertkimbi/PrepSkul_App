# P1 Migration Rollout Verification (Staging + Production)

Owner: __________  
Date: __________  
Ticket/Release: __________

## Scope

Primary migration in this pass:
- `prepskul_app/supabase/migrations/075_skulmate_source_metadata.sql`

Expected DB changes on `public.skulmate_games`:
- `source_type` check includes `docx`
- `source_file_name` column exists
- `source_text_snapshot` column exists

## Preconditions

- Confirm latest app + web code is deployed to staging first.
- Confirm migration file order is correct and no later migration overrides this schema.
- Ensure DB backup/snapshot policy is active.

## Rollout Order

1. Apply migration to **staging**
2. Run schema verification SQL (below)
3. Run functional verification (API + app behavior)
4. Apply migration to **production**
5. Re-run schema + functional verification

## Schema Verification SQL

Run in Supabase SQL editor (staging, then prod):

```sql
-- 1) Columns exist
select
  column_name,
  data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'skulmate_games'
  and column_name in ('source_file_name', 'source_text_snapshot')
order by column_name;

-- 2) source_type check contains docx
select conname, pg_get_constraintdef(oid) as definition
from pg_constraint
where conrelid = 'public.skulmate_games'::regclass
  and conname = 'skulmate_games_source_type_check';
```

Pass criteria:
- both columns returned
- check definition includes `docx`

## Functional Verification (Staging)

### API write path

Generate 2 games:
- file/image upload (expect `source_file_name` populated)
- text input (expect `source_text_snapshot` populated)

SQL check:

```sql
select
  id,
  source_type,
  source_file_name,
  case when source_text_snapshot is null then 0 else length(source_text_snapshot) end as text_len,
  created_at
from public.skulmate_games
where is_deleted = false
order by created_at desc
limit 20;
```

Pass criteria:
- recent file/image rows have non-null `source_file_name`
- recent text rows have `text_len > 0`

### Backward compatibility

Confirm old rows (pre-migration) still load in app/library without crashes.

## Production Safety Checks

- Monitor API errors for 30-60 min post-release:
  - `/api/skulmate/generate` 4xx/5xx
- Verify game generation success rate baseline unchanged.
- Verify no spike in client-side parsing errors for SkulMate screens.

## Rollback / Mitigation

If unexpected app issues occur:
- Stop release traffic to affected app build (if phased release is used)
- Keep migration in place (columns are additive and safe)
- Patch app/web read logic to tolerate null/legacy rows (already done)

## Sign-off

- [ ] Staging schema verified
- [ ] Staging functional checks passed
- [ ] Production migration applied
- [ ] Production checks passed
- [ ] Release owner sign-off

