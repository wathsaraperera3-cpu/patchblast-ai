node Asset {
    has id: str;
    has name: str;
    has kind: str;
    has version: str = "";
    has criticality: str = "Low";
    has internet: bool = False;
}

edge Dependency: Asset --> Asset {
    has relation: str = "depends_on";
}

walker DiscoverGraph {
    has asset_ids: list[str] = [];
    has links: list[dict] = [];
    has visited: list[str] = [];
    has reports: list[dict] = [];

    can start with Root entry {
        visit [-->][?:Asset];
    }

    can discover with Asset entry {
        if here.id in self.visited { skip; }
        self.visited = self.visited + [here.id];
        self.asset_ids = self.asset_ids + [here.id];
        for target in [here ->:Dependency:->] {
            self.links = self.links + [{"from":here.id,"to":target.id,"relation":"depends_on"}];
        }
        visit [here ->:Dependency:->];
    }

    can finish with Root exit {
        report {"asset_ids":self.asset_ids,"links":self.links};
    }
}

def _version_tuple(version: str) -> list[int] | None {
    parts = version.split(".");
    if len(parts) != 3 { return None; }
    values: list[int] = [];
    for part in parts {
        try { values = values + [int(part)]; }
        except ValueError { return None; }
    }
    return values;
}

def _compare_versions(left: str, right: str) -> int | None {
    a = _version_tuple(left);
    b = _version_tuple(right);
    if a is None or b is None { return None; }
    for i in range(3) {
        if a[i] < b[i] { return -1; }
        if a[i] > b[i] { return 1; }
    }
    return 0;
}

def _find_asset(identifier: str) -> Asset | None {
    for asset in [root -->][?:Asset] {
        if asset.id == identifier { return asset; }
    }
    return None;
}

def _ensure_asset(identifier: str, label: str, kind: str, version: str = "", criticality: str = "Low", internet: bool = False) -> Asset {
    existing = _find_asset(identifier);
    if existing is not None { return existing; }
    fresh = Asset(id=identifier,name=label,kind=kind,version=version,criticality=criticality,internet=internet);
    root ++> fresh;
    return fresh;
}

def _link(source: Asset, target: Asset) {
    existing = [source ->:Dependency:->];
    if target not in existing { source +>:Dependency(relation="depends_on"):+> target; }
}

def _seed_graph() {
    customer = _ensure_asset("app-customer","Customer Portal","application","","High",True);
    checkout = _ensure_asset("app-checkout","Checkout Platform","application","","Critical",True);
    staff = _ensure_asset("app-staff","Staff Console","application","","Medium",False);
    analytics = _ensure_asset("app-analytics","Analytics Portal","application","","Low",False);
    auth = _ensure_asset("service-auth","Auth API","service");
    checkout_api = _ensure_asset("service-checkout","Checkout API","service");
    order = _ensure_asset("service-order","Order API","service");
    billing = _ensure_asset("service-billing","Billing Worker","service");
    staff_login = _ensure_asset("service-staff-login","Staff Login Service","service");
    event = _ensure_asset("service-event","Event Collector","service");
    notify = _ensure_asset("service-notify","Notification Service","service");
    reporting = _ensure_asset("service-reporting","Reporting Service","service");
    acme_auth = _ensure_asset("auth-acme","AcmeAuth","component","2.3.1");
    tokenkit = _ensure_asset("checkout-token","TokenKit","component","1.1.0");
    checkout_auth = _ensure_asset("checkout-acme","AcmeAuth","component","2.3.1");
    staff_auth = _ensure_asset("staff-acme","AcmeAuth","component","2.4.0");
    jsonkit = _ensure_asset("event-json","JsonKit","component","3.2.0");
    queue = _ensure_asset("order-queue","QueueFlow","component","4.0.2");
    money = _ensure_asset("billing-money","MoneyMath","component","1.9.4");
    http = _ensure_asset("notify-http","HttpClient","component","5.1.0");
    csv = _ensure_asset("report-csv","CsvKit","component","2.0.0");
    ui = _ensure_asset("staff-ui","UiCore","component","7.2.1");
    date = _ensure_asset("checkout-date","DateTools","component","3.0.0");
    unknown = _ensure_asset("unknown-sdk","LegacySDK","component","unknown");
    _link(customer,auth); _link(customer,notify);
    _link(checkout,checkout_api); _link(checkout,order); _link(checkout,billing);
    _link(staff,staff_login); _link(analytics,event); _link(analytics,reporting);
    _link(auth,acme_auth); _link(checkout_api,tokenkit); _link(checkout_api,date);
    _link(tokenkit,checkout_auth); _link(staff_login,staff_auth); _link(staff_login,ui);
    _link(event,jsonkit); _link(reporting,csv); _link(order,queue);
    _link(billing,money); _link(billing,unknown);
}

def _snapshot() -> dict {
    result = root spawn DiscoverGraph();
    if len(result.reports) == 0 { return {"asset_ids":[],"links":[]}; }
    return result.reports[0];
}

def _component_rows(snapshot: dict) -> list[dict] {
    rows: list[dict] = [];
    for identifier in (snapshot["asset_ids"] as list[str]) {
        asset = _find_asset(identifier);
        if asset is not None and asset.kind == "component" {
            owner_name = asset.id;
            if asset.id == "auth-acme" { owner_name = "Auth API"; }
            elif asset.id == "checkout-acme" { owner_name = "Checkout API"; }
            elif asset.id == "staff-acme" { owner_name = "Staff Login Service"; }
            elif asset.id == "checkout-token" or asset.id == "checkout-date" { owner_name = "Checkout API"; }
            elif asset.id == "event-json" { owner_name = "Event Collector"; }
            elif asset.id == "order-queue" { owner_name = "Order API"; }
            elif asset.id == "billing-money" or asset.id == "unknown-sdk" { owner_name = "Billing Worker"; }
            elif asset.id == "notify-http" { owner_name = "Notification Service"; }
            elif asset.id == "report-csv" { owner_name = "Reporting Service"; }
            elif asset.id == "staff-ui" { owner_name = "Staff Login Service"; }
            rows = rows + [{"id":asset.id,"name":asset.name,"version":asset.version,"kind":"library","owner":owner_name}];
        }
    }
    return rows;
}

def _version_for(identifier: str, overrides: list[dict]) -> str {
    for row in overrides {
        if (row["id"] as str) == identifier { return row["version"] as str; }
    }
    asset = _find_asset(identifier);
    if asset is None { return "unknown"; }
    return asset.version;
}

def _dfs(current: Asset, app: Asset, chain: list[str], seen: list[str], overrides: list[dict], out: list[dict]) -> list[dict] {
    if current.id in seen { return out; }
    next_seen = seen + [current.id];
    label = current.name;
    if current.kind == "component" { label = current.name + " " + _version_for(current.id,overrides); }
    next_chain = chain + [label];
    children = [current ->:Dependency:->];
    if len(children) == 0 {
        if current.kind == "component" {
            service_name = chain[1] if len(chain) > 1 else "";
            return out + [{"application":app.name,"criticality":app.criticality,"internet":app.internet,"service":service_name,"chain":next_chain,"target":current.id}];
        }
        return out;
    }
    for child in children {
        found = _dfs(child,app,next_chain,next_seen,overrides,out);
        out = found;
    }
    return out;
}

def _analysis(snapshot: dict, overrides: list[dict]) -> dict {
    _ = snapshot;
    all_paths: list[dict] = [];
    for app in [root -->][?:Asset] {
        if app.kind == "application" {
            for service in [app ->:Dependency:->] {
                found = _dfs(service,app,[app.name],[app.id],overrides,[]);
                all_paths = all_paths + found;
            }
        }
    }
    findings: list[dict] = [];
    affected_apps: list[str] = [];
    affected_services: list[str] = [];
    for path in all_paths {
        chain = path["chain"] as list[str];
        leaf = chain[len(chain) - 1];
        pkg_parts = leaf.split(" ");
        package_name = pkg_parts[0];
        installed = pkg_parts[len(pkg_parts) - 1];
        status = "NOT_AFFECTED_BY_THIS_ADVISORY";
        evidence = "No AcmeAuth version on this path matches the simulated affected range.";
        priority = 0;
        if package_name == "AcmeAuth" {
            low_cmp = _compare_versions(installed,"2.0.0");
            high_cmp = _compare_versions(installed,"2.3.9");
            if low_cmp is None or high_cmp is None {
                status = "NEEDS_VERIFICATION";
                evidence = "AcmeAuth inventory version is ambiguous and requires human verification.";
            } elif low_cmp >= 0 and high_cmp <= 0 {
                status = "POTENTIALLY_AFFECTED";
                evidence = "AcmeAuth " + installed + " is within the inclusive affected range 2.0.0–2.3.9.";
            }
        } elif installed == "unknown" {
            status = "NEEDS_VERIFICATION";
            evidence = "A dependency record has no parseable version; verify the inventory separately.";
        }
        if status == "POTENTIALLY_AFFECTED" {
            criticality = path["criticality"] as str;
            priority = 62;
            if criticality == "Critical" { priority += 24; }
            elif criticality == "High" { priority += 18; }
            elif criticality == "Medium" { priority += 10; }
            if path["internet"] as bool { priority += 10; }
            if priority > 100 { priority = 100; }
            app_name = path["application"] as str;
            service_name = path["service"] as str;
            if app_name not in affected_apps { affected_apps = affected_apps + [app_name]; }
            if service_name not in affected_services { affected_services = affected_services + [service_name]; }
        }
        label = "Monitor";
        if status == "POTENTIALLY_AFFECTED" { label = "Investigate now"; }
        elif status == "NEEDS_VERIFICATION" { label = "Verify inventory"; }
        findings = findings + [{"application":path["application"],"service":path["service"],"chain":chain,"target":path["target"],"status":status,"evidence":evidence,"priority":priority,"priority_label":label,"criticality":path["criticality"],"internet":path["internet"]}];
    }
    potentially = 0; verification = 0;
    for finding in findings {
        if finding["status"] as str == "POTENTIALLY_AFFECTED" { potentially += 1; }
        if finding["status"] as str == "NEEDS_VERIFICATION" { verification += 1; }
    }
    return {"findings":findings,"paths":all_paths,"affected_apps":affected_apps,"affected_services":affected_services,"potential_count":potentially,"verification_count":verification};
}

def:pub analyzeDependencies() -> dict {
    _seed_graph();
    snapshot = _snapshot();
    rows = _component_rows(snapshot);
    return _analysis(snapshot,rows);
}

def:pub loadPatchblast(components: list[dict] = []) -> dict {
    _seed_graph();
    snapshot = _snapshot();
    rows = components;
    if len(rows) == 0 { rows = _component_rows(snapshot); }
    analysis = _analysis(snapshot,rows);
    return {"company":"NovaCommerce Technologies","applications":4,"services":8,"component_count":len(rows),"components":rows,"analysis":analysis,"agents":[{"name":"Dependency Discovery","detail":"A Jac walker discovers graph nodes and typed dependency edges; cycle-safe traversal preserves full application paths."},{"name":"Vulnerability Investigation","detail":"Deterministic numeric version comparison checks each reached package against the inclusive advisory range."},{"name":"Business Impact","detail":"Review priority combines advisory severity, business criticality, and internet exposure."},{"name":"Remediation Planning","detail":"Upgrade recommendations are generated from the current graph-derived evidence and remaining paths."}],"advisory":{"id":"ADV-DEMO-2026-001","title":"AcmeAuth Authentication Validation Vulnerability","package":"AcmeAuth","range":"2.0.0 – 2.3.9 inclusive","fixed":"2.4.0","severity":"High","description":"A fictional validation weakness affects the listed AcmeAuth versions. Services containing these versions require investigation and potential remediation.","simulated":True}};
}

def:pub upgradeScenario(components: list[dict], target: str, version: str) -> dict {
    if target not in ["auth-acme","checkout-acme","staff-acme"] { return loadPatchblast(components); }
    if _version_tuple(version) is None { return loadPatchblast(components); }
    changed: list[dict] = [];
    for component in components {
        if (component["id"] as str) == target { changed = changed + [{**component,"version":version}]; }
        else { changed = changed + [component]; }
    }
    return loadPatchblast(changed);
}

def:pub resetScenario() -> dict { return loadPatchblast(); }

def:pub getReport(components: list[dict]) -> str {
    import json;
    result = loadPatchblast(components);
    payload = {"product":"PatchBlast AI","generated_at":"Current scenario snapshot","company":result["company"],"advisory":result["advisory"],"analysis":result["analysis"],"components":result["components"],"notice":"Fictional demonstration data. Potential exposure does not prove exploitability."};
    return json.dumps(payload,indent=2);
}
