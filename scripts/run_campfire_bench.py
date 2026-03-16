#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


REQUIRED_SCENARIO_FIELDS = {
    "id",
    "name",
    "category",
    "description",
    "objective",
    "required_capabilities",
    "success_criteria",
    "scoring_weights",
    "overhead_budget",
}

REQUIRED_RESULT_FIELDS = {
    "scenario_id",
    "run_id",
    "status",
    "task_success",
    "state_fidelity",
    "resume_fidelity",
    "replan_quality",
    "validation_quality",
    "orchestration_tokens",
    "total_tokens",
    "orchestration_seconds",
}


def load_json(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
      raise SystemExit(f"Expected JSON object in {path}")
    return data


def scenario_dir_for_root(root: Path) -> Path:
    return root / "benchmarks" / "campfire-bench" / "scenarios"


def default_results_dir(root: Path) -> Path:
    return root / "benchmarks" / "campfire-bench" / "fixtures" / "results"


def validate_scenarios(scenario_dir: Path) -> list[dict[str, Any]]:
    scenarios: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    for path in sorted(scenario_dir.glob("*.json")):
        payload = load_json(path)
        missing = REQUIRED_SCENARIO_FIELDS - payload.keys()
        if missing:
            raise SystemExit(f"{path} missing fields: {sorted(missing)}")
        scenario_id = str(payload["id"]).strip()
        if not scenario_id:
            raise SystemExit(f"{path} has empty scenario id")
        if scenario_id in seen_ids:
            raise SystemExit(f"Duplicate scenario id: {scenario_id}")
        seen_ids.add(scenario_id)
        scenarios.append(payload)
    if not scenarios:
        raise SystemExit(f"No scenario files found in {scenario_dir}")
    return scenarios


def validate_results(results_dir: Path, scenario_ids: set[str]) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    for path in sorted(results_dir.glob("*.json")):
        payload = load_json(path)
        missing = REQUIRED_RESULT_FIELDS - payload.keys()
        if missing:
            raise SystemExit(f"{path} missing fields: {sorted(missing)}")
        scenario_id = str(payload["scenario_id"]).strip()
        if scenario_id not in scenario_ids:
            raise SystemExit(f"{path} references unknown scenario_id: {scenario_id}")
        results.append(payload)
    return results


def overall_score(result: dict[str, Any], scenario: dict[str, Any]) -> float:
    weights = scenario["scoring_weights"]
    score = 0.0
    for key, weight in weights.items():
        if key == "overhead":
            total = max(float(result["total_tokens"]), 1.0)
            orchestration = float(result["orchestration_tokens"])
            ratio = orchestration / total
            budget = float(scenario["overhead_budget"]["max_orchestration_token_ratio"])
            component = 1.0 if ratio <= budget else max(0.0, 1.0 - ((ratio - budget) / max(budget, 0.01)))
        else:
            component = float(result.get(key, 0.0))
        score += component * float(weight)
    return round(score, 4)


def main() -> int:
    parser = argparse.ArgumentParser(description="Campfire benchmark scaffold runner")
    parser.add_argument("--root", default=".", help="Campfire repo root")
    parser.add_argument("--results-dir", help="Directory of benchmark result JSON files")
    parser.add_argument("--validate-only", action="store_true", help="Only validate scenario definitions")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    scenarios = validate_scenarios(scenario_dir_for_root(root))

    if args.validate_only:
        print(json.dumps({
            "scenario_count": len(scenarios),
            "categories": sorted({str(item["category"]) for item in scenarios}),
            "scenario_ids": [str(item["id"]) for item in scenarios],
        }, indent=2))
        return 0

    results_dir = Path(args.results_dir).resolve() if args.results_dir else default_results_dir(root)
    results = validate_results(results_dir, {str(item["id"]) for item in scenarios})
    scenario_map = {str(item["id"]): item for item in scenarios}

    scored_results = []
    for result in results:
        scenario = scenario_map[str(result["scenario_id"])]
        ratio = float(result["orchestration_tokens"]) / max(float(result["total_tokens"]), 1.0)
        scored_results.append(
            {
                "scenario_id": result["scenario_id"],
                "run_id": result["run_id"],
                "status": result["status"],
                "overall_score": overall_score(result, scenario),
                "orchestration_token_ratio": round(ratio, 4),
            }
        )

    print(json.dumps(
        {
            "scenario_count": len(scenarios),
            "result_count": len(scored_results),
            "results": scored_results,
        },
        indent=2,
    ))
    return 0


if __name__ == "__main__":
    sys.exit(main())
