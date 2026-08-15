# Bug Report — ZOKY-004

Status: bugs (แก้แล้ว รอ QA รอบ 2)
Owner: AI Debug Engineer (เสร็จ)

Bug: `reviews` table's `update` RLS policy does not re-verify the delivered-order-ownership gate, letting a user retarget their own (legitimately-written) review onto any `product_id`/`order_item_id` without ever having purchased/received it — defeating the entire feature's core "no fake reviews" security guarantee.

Reproduction:
1. As User A, buy Product X, get the order marked `delivered` (ZOKY-003 flow), write a legitimate review for it via `ZokyOrderDetailScreen` — this succeeds correctly through the `insert` policy's `exists` gate.
2. Still as User A, call `ZokyRepository.editReview` (or the raw Supabase client `.from('reviews').update(...)`) on that same review row, but pass a different `product_id` (any product in the catalog, including one User A never bought) and/or a different `order_item_id`.
3. Read `supabase/schema.sql`'s `update` policy for `reviews`:
   ```sql
   create policy "Users can update their own reviews"
     on public.reviews
     for update
     to authenticated
     using (auth.uid() = user_id);
   ```
   No `with check` clause is attached.

Root Cause: Per Postgres RLS semantics, when a `for update` policy has no explicit `with check`, Postgres reuses the `using` expression as the check on the *new* row too. Here that expression is only `auth.uid() = user_id` — it says nothing about `order_item_id`/`product_id`, so an update that changes either of those columns is not re-validated against the delivered-order-ownership invariant the way `insert` is. The `insert` policy's `exists` subquery (verifying the order_item belongs to the caller's own `delivered` order and its `product_id` matches) is the only place that invariant is checked — and it is never re-checked on `update`.

The schema comment above the `update` policy ("Editing/deleting a review never re-checks the order's status -- ... there's nothing left to re-verify beyond plain ownership") reasoned correctly that an order's *status* can't regress out of `delivered`, but missed that the *review row's own* `order_item_id`/`product_id` values are freely reassignable via `update` with no gate at all — a completely separate concern from order status.

Confirmed by QA (round 1) via schema reading and Postgres RLS documentation; not runnable against a live Supabase instance since this project has no deployed project yet (same limitation as every prior RLS review this session — see `.wyn/tasks/approved/*.md`'s QA reports, all of which verified RLS by reading SQL only).

Fix: Add a `with check` clause to the `update` policy on `public.reviews`, mirroring the `insert` policy's `exists` gate exactly, so that whatever the resulting row's `order_item_id`/`product_id` end up being after an update, they must still reference a `delivered` order the caller owns:

```sql
create policy "Users can update their own reviews"
  on public.reviews
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and exists (
      select 1
      from public.order_items oi
      join public.orders o on o.id = oi.order_id
      where oi.id = order_item_id
        and oi.product_id = product_id
        and o.buyer_id = auth.uid()
        and o.status = 'delivered'
    )
  );
```

This doesn't need to additionally forbid changing `order_item_id`/`product_id` outright (Postgres RLS can't compare OLD vs NEW values within one policy without a trigger) — re-running the same ownership/delivered gate on the new values is sufficient to close the exploit, since any retargeted value must itself be a genuine delivered purchase owned by the same user.

Files Changed: `supabase/schema.sql` (ZOKY-004 section, `reviews`' update policy) — expected to be the only file that needs to change; this is a pure RLS gap, not an application-code bug, so no Dart changes are anticipated (but re-run `flutter analyze`/`flutter test` regardless per standing practice, and double-check `zoky_repository.dart`'s `editReview` doesn't rely on any behavior the tightened policy would break).

Tests: No existing Flutter widget test can exercise raw RLS policy behavior (there's no live Postgres in this environment). Document the fix's correctness via the SQL diff itself and an explanation of why it closes the gap, same as how the `insert` gate was originally verified by QA. If technically feasible, add a code comment cross-referencing this bug report so a future reader understands why the `update` policy carries a `with check`.

Regression Risk: Low — the fix only *tightens* the update policy; it cannot make any previously-valid, legitimate edit (rating/text_content change without touching `order_item_id`/`product_id`) fail, since those values remain unchanged and were already known-valid at insert time. Re-run the full `flutter analyze`/`flutter test` suite to confirm no Dart-side behavior assumed the looser policy.

Handoff to QA: Once the `with check` clause is added and verified (SQL read-through, since there's no live Postgres to execute against), send back to AI QA & Security for round 2 — QA must re-verify this specific policy plus re-run the full Requirements/Design/Acceptance Criteria walk (not just the fixed spot), per the project's established regression-test-memory convention (`.wyn/company/WORKFLOW.md`, "QA รอบถัดไปตรวจสอบ failure เดิมด้วย").

---

## Debug Output (AI Debug Engineer)

Fix applied exactly as proposed above — `supabase/schema.sql`'s `"Users can update their own reviews"` policy now carries `with check (auth.uid() = user_id and exists (...))`, mirroring the `insert` policy's gate. Added an expanded code comment explaining why `delete` doesn't need the same treatment (no "new row" to retarget) while `update` does (Postgres reuses `using` as the implicit check when `with check` is absent — that's precisely the gap), and cross-referenced this bug report.

No Dart changes were needed or made: `ZokyRepository.editReview` only ever sends `rating`/`text_content`/`updated_at` in its update payload, never `order_item_id`/`product_id`, so those columns retain their already-valid values on every legitimate edit — the tightened policy cannot reject any behavior the app actually performs.

Tests: no Flutter test can exercise live RLS (no deployed Supabase project this session, same limitation noted in every prior RLS review). Re-ran the full suite regardless to confirm the SQL-only change didn't disturb anything: `flutter analyze` clean, `flutter test` 253/253 (identical count to before the fix, as expected for a change with zero Dart-code impact).

Regression Risk: Low, as anticipated — the fix only tightens a policy that no legitimate app code path could have violated in the first place.

Lessons learned: recorded in `.wyn/learning/LESSONS_LEARNED.md` and `.wyn/learning/MISTAKES.md` — RLS `update`/`delete` policies must always get the same explicit security-audit attention as `insert` policies, specifically checking whether an absent `with check` silently falls back to a weaker implicit check via Postgres' `using`-as-check-for-update behavior.

Handoff to QA: send back to AI QA & Security for round 2.
