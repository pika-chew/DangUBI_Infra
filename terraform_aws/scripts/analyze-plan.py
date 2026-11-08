"""Summarize a `terraform show -json` plan for the Jenkins pipeline.

Writes plan-summary.txt (human readable, used in Slack) and plan-flags
(HAS_CHANGES / HAS_DESTRUCTIVE) next to the plan JSON.
"""

import argparse
import json
from pathlib import Path


def classify(actions):
    if actions in (["delete", "create"], ["create", "delete"]):
        return "replace"
    if actions == ["delete"]:
        return "delete"
    if actions == ["create"]:
        return "create"
    if actions == ["update"]:
        return "update"
    if actions == ["forget"]:
        return "forget"
    return None  # no-op, read


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("plan_json")
    args = parser.parse_args()

    plan_path = Path(args.plan_json)
    plan = json.loads(plan_path.read_text(encoding="utf-8"))

    changes = {"create": [], "update": [], "replace": [], "delete": [], "forget": []}
    for rc in plan.get("resource_changes", []):
        kind = classify(rc["change"]["actions"])
        if kind:
            changes[kind].append(rc["address"])

    output_changed = any(
        oc["actions"] != ["no-op"] for oc in plan.get("output_changes", {}).values()
    )
    has_changes = any(changes.values()) or output_changed
    has_destructive = bool(changes["delete"] or changes["replace"])

    lines = [
        f"생성 {len(changes['create'])} / 변경 {len(changes['update'])} / "
        f"교체 {len(changes['replace'])} / 삭제 {len(changes['delete'])}"
    ]
    if changes["forget"]:
        lines[0] += f" / state 제거 {len(changes['forget'])}"
    if not has_changes:
        lines.append("변경 사항 없음")
    elif not any(changes.values()):
        lines.append("output 값만 변경")
    for kind, label in (("replace", "교체"), ("delete", "삭제")):
        for address in changes[kind]:
            lines.append(f"- [{label}] {address}")

    out_dir = plan_path.parent
    (out_dir / "plan-summary.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (out_dir / "plan-flags").write_text(
        f"HAS_CHANGES={str(has_changes).lower()}\n"
        f"HAS_DESTRUCTIVE={str(has_destructive).lower()}\n",
        encoding="utf-8",
    )
    print("\n".join(lines))


if __name__ == "__main__":
    main()
