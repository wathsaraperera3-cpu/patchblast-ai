import from services.patchblastService { loadPatchblast, upgradeScenario, resetScenario, getReport }
import from "@jac/runtime" { Router, Routes, Route }
import from .components.PatchBlastDashboard { PatchBlastDashboard }
import ".styles.global.css";

def:pub app() -> JsxElement {
    return <Router><Routes><Route path="/" element={<PatchBlastDashboard />} /></Routes></Router>;
}
