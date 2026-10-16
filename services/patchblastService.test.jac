test "seed graph has direct and transitive exposure paths" {
    result = loadPatchblast();
    findings = result["analysis"]["findings"] as list[dict];
    direct = False;
    transitive = False;
    fixed = False;
    unrelated = False;
    for finding in findings {
        chain = finding["chain"] as list[str];
        if (finding["service"] as str) == "Auth API" and (finding["status"] as str) == "POTENTIALLY_AFFECTED" { direct = True; }
        if (finding["service"] as str) == "Checkout API" and "TokenKit" in " ".join(chain) and (finding["status"] as str) == "POTENTIALLY_AFFECTED" { transitive = True; }
        if (finding["service"] as str) == "Staff Login Service" and (finding["status"] as str) == "NOT_AFFECTED_BY_THIS_ADVISORY" { fixed = True; }
        if (finding["service"] as str) == "Event Collector" and (finding["status"] as str) == "NOT_AFFECTED_BY_THIS_ADVISORY" { unrelated = True; }
    }
    assert direct;
    assert transitive;
    assert fixed;
    assert unrelated;
}

test "unknown version needs verification" {
    result = loadPatchblast();
    findings = result["analysis"]["findings"] as list[dict];
    found_unknown = False;
    for finding in findings {
        if (finding["target"] as str) == "unknown-sdk" and (finding["status"] as str) == "NEEDS_VERIFICATION" { found_unknown = True; }
    }
    assert found_unknown;
}

test "selected scenario update clears direct path but preserves transitive path" {
    baseline = loadPatchblast();
    upgraded = upgradeScenario(baseline["components"] as list[dict],"auth-acme","2.4.0");
    findings = upgraded["analysis"]["findings"] as list[dict];
    direct_clear = False;
    indirect_remains = False;
    for finding in findings {
        chain = finding["chain"] as list[str];
        if (finding["service"] as str) == "Auth API" and (finding["status"] as str) == "NOT_AFFECTED_BY_THIS_ADVISORY" { direct_clear = True; }
        if (finding["service"] as str) == "Checkout API" and "TokenKit" in " ".join(chain) and (finding["status"] as str) == "POTENTIALLY_AFFECTED" { indirect_remains = True; }
    }
    assert direct_clear;
    assert indirect_remains;
}

test "reset restores seeded versions and baseline risk" {
    base = loadPatchblast();
    altered = upgradeScenario(base["components"] as list[dict],"auth-acme","2.4.0");
    reset = resetScenario();
    original_auth = "";
    reset_auth = "";
    for item in (base["components"] as list[dict]) { if (item["id"] as str) == "auth-acme" { original_auth = item["version"] as str; } }
    for item in (reset["components"] as list[dict]) { if (item["id"] as str) == "auth-acme" { reset_auth = item["version"] as str; } }
    assert original_auth == "2.3.1";
    assert reset_auth == original_auth;
    assert (altered["analysis"]["potential_count"] as int) < (reset["analysis"]["potential_count"] as int);
}

test "report matches current recalculated state" {
    result = loadPatchblast();
    summary = getReport(result["components"] as list[dict]);
    assert "potential_count" in summary;
    assert "ADV-DEMO-2026-001" in summary;
}

test "cycle in graph traversal terminates once per asset" {
    _seed_graph();
    first = _find_asset("service-auth");
    second = _find_asset("auth-acme");
    assert first is not None;
    assert second is not None;
    _link(second,first);
    snapshot = _snapshot();
    ids = snapshot["asset_ids"] as list[str];
    assert len(ids) == 24;
    for link in [edge second ->:Dependency:-> first] { del link; }
}
