"""Standard-library tests; deliberately never access network, DB or Stripe."""
import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "food_contract_gate", ROOT / "scripts" / "check-staging-contract.py"
)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
manifest = json.loads((ROOT / "phase1" / "contract_manifest.json").read_text(encoding="utf-8"))


def compatible_fixture():
    return {
        "project_ref": "aaaaaaaaaaaaaaaaaaaa",
        "functions": [
            {"name": f["name"], "arguments": ", ".join(
                p + " text" for p in f["parameters"])}
            for f in manifest["rpcs"]
        ],
        "tables": [{"name": t["name"], "rls_enabled": True}
                   for t in manifest["tables"]],
        "edge_functions": [e["name"] for e in manifest["edgeFunctions"]],
    }


class ContractGateTests(unittest.TestCase):
    def test_complete_metadata_fixture_is_not_blocked(self):
        self.assertEqual([], gate.audit_contract(manifest, compatible_fixture()))

    def test_existing_stripe_sandbox_fails_both_scopes(self):
        snapshot = json.loads((ROOT / "phase1" / "sandbox_metadata_2026-10-15.json").read_text())
        for scope in ("foundation", "full"):
            failures = gate.audit_contract(manifest, snapshot, scope)
            self.assertIn("MISSING RPC food_public_catalog", failures)

    def test_production_project_ref_refused_even_with_all_metadata(self):
        snapshot = compatible_fixture()
        snapshot["project_ref"] = manifest["protectedProductionRef"]
        self.assertTrue(any("production project" in x for x in gate.audit_contract(manifest, snapshot)))

    def test_disabled_table_rls_is_blocked(self):
        snapshot = compatible_fixture()
        snapshot["tables"][0]["rls_enabled"] = False
        self.assertTrue(any("RLS DISABLED" in x for x in gate.audit_contract(manifest, snapshot)))

    def test_coupon_rpc_signature_mismatch_is_blocked(self):
        snapshot = compatible_fixture()
        next(f for f in snapshot["functions"] if f["name"] == "food_quote_order_v2")["arguments"] = "p_store_id uuid, p_items jsonb"
        self.assertTrue(any("RPC SIGNATURE food_quote_order_v2" in x for x in gate.audit_contract(manifest, snapshot)))

    def test_mobile_payment_missing_blocks_full_not_foundation(self):
        snapshot = compatible_fixture()
        snapshot["edge_functions"] = []
        self.assertEqual([], gate.audit_contract(manifest, snapshot, "foundation"))
        self.assertIn("MISSING EDGE FUNCTION food-mobile-payment-intent", gate.audit_contract(manifest, snapshot, "full"))


if __name__ == "__main__":
    unittest.main()
