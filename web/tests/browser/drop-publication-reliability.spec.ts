import { expect, test } from "@playwright/test";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DropPublicationStateUnknownError, publishDropSafely } from "../../lib/drop-publication";

const USER = "00000000-0000-4000-8000-000000000001";
const OPERATION = "44444444-4444-4444-8444-444444444444";

test("a lost publish response reconciles an already-created post without another write", async () => {
  let writes = 0;
  let lookups = 0;
  const client = {
    rpc: async (name: string, args: { p_operation_id: string }) => {
      expect(args.p_operation_id).toBe(OPERATION);
      if (name === "publish_drop") {
        writes += 1;
        return { data: null, error: new TypeError("Failed to fetch") };
      }
      if (name === "drop_id_for_publication") {
        lookups += 1;
        return { data: "already-created-post", error: null };
      }
      throw new Error("Unexpected RPC");
    },
  } as unknown as SupabaseClient;

  const result = await publishDropSafely(client, USER, {
    caption: "Do not duplicate this post",
    files: [],
    operationId: OPERATION,
  });
  expect(result).toEqual({ dropId: "already-created-post", operationId: OPERATION });
  expect(writes).toBe(1);
  expect(lookups).toBe(1);
});

test("when reconciliation is unreachable, preserve operation ID for a deliberate retry", async () => {
  const operations: string[] = [];
  let connected = false;
  const client = {
    rpc: async (name: string, args: { p_operation_id: string }) => {
      if (name === "publish_drop") {
        operations.push(args.p_operation_id);
        return connected
          ? { data: "reconciled-post", error: null }
          : { data: null, error: new TypeError("Network request failed") };
      }
      if (name === "drop_id_for_publication") {
        return connected
          ? { data: "reconciled-post", error: null }
          : { data: null, error: new TypeError("Network request failed") };
      }
      throw new Error("Unexpected RPC");
    },
  } as unknown as SupabaseClient;

  await expect(publishDropSafely(client, USER, {
    caption: "Retry unchanged after ambiguous network failure",
    files: [],
    operationId: OPERATION,
  })).rejects.toBeInstanceOf(DropPublicationStateUnknownError);
  connected = true;
  const retry = await publishDropSafely(client, USER, {
    caption: "Retry unchanged after ambiguous network failure",
    files: [],
    operationId: OPERATION,
  });
  expect(retry).toEqual({ dropId: "reconciled-post", operationId: OPERATION });
  expect(operations).toEqual([OPERATION, OPERATION]);
});
