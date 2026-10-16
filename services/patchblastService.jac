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

def _seed_components() -> list[dict] {
    return [
        {"id":"auth-acme","name":"AcmeAuth","version":"2.3.1","kind":"library","owner":"Auth API"},
        {"id":"checkout-token","name":"TokenKit","version":"1.1.0","kind":"library","owner":"Checkout API"},
        {"id":"checkout-acme","name":"AcmeAuth","version":"2.3.1","kind":"library","owner":"Checkout API"},
        {"id":"staff-acme","name":"AcmeAuth","version":"2.4.0","kind":"library","owner":"Staff Login Service"},
        {"id":"event-json","name":"JsonKit","version":"3.2.0","kind":"library","owner":"Event Collector"},
        {"id":"order-queue","name":"QueueFlow","version":"4.0.2","kind":"library","owner":"Order API"},
        {"id":"billing-money","name":"MoneyMath","version":"1.9.4","kind":"library","owner":"Billing Worker"},
        {"id":"notify-http","name":"HttpClient","version":"5.1.0","kind":"library","owner":"Notification Service"},
        {"id":"report-csv","name":"CsvKit","version":"2.0.0","kind":"library","owner":"Reporting Service"},
        {"id":"staff-ui","name":"UiCore","version":"7.2.1","kind":"library","owner":"Staff Login Service"},
        {"id":"checkout-date","name":"DateTools","version":"3.0.0","kind":"library","owner":"Checkout API"},
        {"id":"unknown-sdk","name":"LegacySDK","version":"unknown","kind":"library","owner":"Billing Worker"}
    ];
}

def _paths(components: list[dict]) -> list[dict] {
    paths: list[dict] = [];
    paths = paths + [{"application":"Customer Portal","criticality":"High","service":"Auth API","internet":True,"chain":["Customer Portal","Auth API","AcmeAuth " + (components[0]["version"] as str)],"target":"auth-acme"}];
    token_v = components[1]["version"] as str;
    acme_v = components[2]["version"] as str;
    paths = paths + [{"application":"Checkout Platform","criticality":"Critical","service":"Checkout API","internet":True,"chain":["Checkout Platform","Checkout API","TokenKit " + token_v,"AcmeAuth " + acme_v],"target":"checkout-acme"}];
    paths = paths + [{"application":"Checkout Platform","criticality":"Critical","service":"Checkout API","internet":True,"chain":["Checkout Platform","Checkout API","DateTools " + (components[10]["version"] as str)],"target":"checkout-date"}];
    paths = paths + [{"application":"Staff Console","criticality":"Medium","service":"Staff Login Service","internet":False,"chain":["Staff Console","Staff Login Service","AcmeAuth " + (components[3]["version"] as str)],"target":"staff-acme"}];
    paths = paths + [{"application":"Staff Console","criticality":"Medium","service":"Staff Login Service","internet":False,"chain":["Staff Console","Staff Login Service","UiCore " + (components[9]["version"] as str)],"target":"staff-ui"}];
    paths = paths + [{"application":"Analytics Portal","criticality":"Low","service":"Event Collector","internet":False,"chain":["Analytics Portal","Event Collector","JsonKit " + (components[4]["version"] as str)],"target":"event-json"}];
    paths = paths + [{"application":"Analytics Portal","criticality":"Low","service":"Reporting Service","internet":False,"chain":["Analytics Portal","Reporting Service","CsvKit " + (components[8]["version"] as str)],"target":"report-csv"}];
    paths = paths + [{"application":"Checkout Platform","criticality":"Critical","service":"Order API","internet":False,"chain":["Checkout Platform","Order API","QueueFlow " + (components[5]["version"] as str)],"target":"order-queue"}];
    paths = paths + [{"application":"Checkout Platform","criticality":"Critical","service":"Billing Worker","internet":False,"chain":["Checkout Platform","Billing Worker","MoneyMath " + (components[6]["version"] as str)],"target":"billing-money"}];
    paths = paths + [{"application":"Customer Portal","criticality":"High","service":"Notification Service","internet":False,"chain":["Customer Portal","Notification Service","HttpClient " + (components[7]["version"] as str)],"target":"notify-http"}];
    paths = paths + [{"application":"Checkout Platform","criticality":"Critical","service":"Billing Worker","internet":False,"chain":["Checkout Platform","Billing Worker","LegacySDK unknown"],"target":"unknown-sdk"}];
    return paths;
}

def _analysis(components: list[dict]) -> dict {
    paths = _paths(components);
    findings: list[dict] = [];
    affected_apps: list[str] = [];
    affected_services: list[str] = [];
    for path in paths {
        chain = path["chain"] as list[str];
        status = "NOT_AFFECTED_BY_THIS_ADVISORY";
        evidence = "No AcmeAuth version on this path matches the simulated affected range.";
        priority = 0;
        for item in chain {
            if item.startswith("AcmeAuth ") {
                installed = item.replace("AcmeAuth ", "");
                low_cmp = _compare_versions(installed, "2.0.0");
                high_cmp = _compare_versions(installed, "2.3.9");
                if low_cmp is None or high_cmp is None {
                    status = "NEEDS_VERIFICATION";
                    evidence = "AcmeAuth inventory version is ambiguous and requires human verification.";
                } elif low_cmp >= 0 and high_cmp <= 0 {
                    status = "POTENTIALLY_AFFECTED";
                    evidence = "AcmeAuth " + installed + " is within the inclusive affected range 2.0.0–2.3.9.";
                }
            } elif item.startswith("LegacySDK unknown") {
                status = "NEEDS_VERIFICATION";
                evidence = "A dependency record has no parseable version; verify the inventory separately.";
            }
        }
        if status == "POTENTIALLY_AFFECTED" {
            criticality = path["criticality"] as str;
            priority = 62;
            if criticality == "Critical" { priority = priority + 24; }
            elif criticality == "High" { priority = priority + 18; }
            elif criticality == "Medium" { priority = priority + 10; }
            if path["internet"] as bool { priority = priority + 10; }
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
    potentially = 0;
    verification = 0;
    for finding in findings {
        if finding["status"] as str == "POTENTIALLY_AFFECTED" { potentially += 1; }
        if finding["status"] as str == "NEEDS_VERIFICATION" { verification += 1; }
    }
    return {"findings":findings,"paths":paths,"affected_apps":affected_apps,"affected_services":affected_services,"potential_count":potentially,"verification_count":verification};
}

def:pub loadPatchblast(components: list[dict] = []) -> dict {
    data = components;
    if len(data) == 0 { data = _seed_components(); }
    analysis = _analysis(data);
    return {"company":"NovaCommerce Technologies","applications":4,"services":8,"component_count":len(data),"components":data,"analysis":analysis,"agents":[{"name":"Dependency Discovery","detail":"Enumerated application-to-service dependency paths with cycle-safe visited records."},{"name":"Vulnerability Investigation","detail":"Compared package versions numerically against the inclusive simulated advisory range."},{"name":"Business Impact","detail":"Calculated review priority from severity, criticality, and internet exposure."},{"name":"Remediation Planning","detail":"Generated review-first upgrade candidates from affected path evidence."}],"advisory":{"id":"ADV-DEMO-2026-001","title":"AcmeAuth Authentication Validation Vulnerability","package":"AcmeAuth","range":"2.0.0 – 2.3.9 inclusive","fixed":"2.4.0","severity":"High","description":"A fictional validation weakness affects the listed AcmeAuth versions. Services containing these versions require investigation and potential remediation.","simulated":True}};
}

def:pub upgradeScenario(components: list[dict], target: str, version: str) -> dict {
    if target not in ["auth-acme","checkout-acme","staff-acme"] { return loadPatchblast(components); }
    if _version_tuple(version) is None { return loadPatchblast(components); }
    changed: list[dict] = [];
    for component in components {
        if (component["id"] as str) == target {
            changed = changed + [{**component,"version":version}];
        } else { changed = changed + [component]; }
    }
    return loadPatchblast(changed);
}

def:pub resetScenario() -> dict {
    return loadPatchblast();
}

def:pub getReport(components: list[dict]) -> dict {
    result = loadPatchblast(components);
    return {"product":"PatchBlast AI","company":result["company"],"advisory":result["advisory"],"analysis":result["analysis"],"components":result["components"],"notice":"Fictional demonstration data. Potential exposure does not prove exploitability."};
}
