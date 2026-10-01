"""R1 evidence export. Imports only the original stdlib-only export helper.

No application imports, package resolution, network, database or repository writes.
The two patch baselines are B1 HEAD and the verified original B2 snapshots.
"""
import argparse
import ast
from datetime import datetime, timezone
import difflib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import tempfile
import time

spec = importlib.util.spec_from_file_location("b2_export", Path(__file__).with_name("export_review.py"))
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
OLD = base.OUT
OUT = OLD.parent / "beta-b2-r1-20261001T152143Z-2bc8d433"
base.OUT = OUT
FINAL = ("r1-backend-01", "r1-regression-final", "r1-flutter-final-02", "r1-analyze-final-02")


def check_budget():
    budget = json.loads((OUT / "BUDGET.json").read_text(encoding="utf-8-sig"))
    assert time.monotonic() < budget["deadline_monotonic"], "Hard review deadline reached"
    return dict(utc=datetime.now(timezone.utc).isoformat(), monotonic=time.monotonic(),
                remaining_minutes=round((budget["deadline_monotonic"] - time.monotonic()) / 60, 2))


def verify_original():
    assert base.sha(OLD.with_suffix(".zip").read_bytes()) == "220f044ca42d53532c7521010627ec6d03ad01d7119974fef089399b300b65e0"
    assert OLD.with_suffix(".zip").stat().st_size == 590919
    with base.zipfile.ZipFile(OLD.with_suffix(".zip")) as archive:
        files = {p.relative_to(OLD).as_posix(): p for p in OLD.rglob("*") if p.is_file()}
        assert set(archive.namelist()) == set(files) and len(files) == 156
        for name, path in files.items():
            assert archive.read(name) == path.read_bytes(), name
    return dict(files=156, zip_sha256=base.sha(OLD.with_suffix(".zip").read_bytes()),
                every_original_export_file_matches_original_zip=True)


def copy(data, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)


def delta(label, files):
    with tempfile.TemporaryDirectory(prefix="emie-b2-r1-delta-") as directory:
        root = Path(directory).resolve()
        assert root.parent == Path(tempfile.gettempdir()).resolve()
        assert root.name.startswith("emie-b2-r1-delta-")
        before, after, rebuilt = (root / n for n in ("original", "changed", "reconstructed"))
        for folder in (before, after, rebuilt):
            folder.mkdir()
        for name in files:
            original = OUT / "b2-baseline" / label / name
            if original.exists():
                copy(original.read_bytes(), before / name)
                copy(original.read_bytes(), rebuilt / name)
            copy((OUT / "sources" / label / name).read_bytes(), after / name)
        raw = base.command(["git", "-c", "core.autocrlf=false", "diff", "--no-index", "--no-ext-diff",
                            "--no-renames", "--binary", "--full-index", "--src-prefix=a/", "--dst-prefix=b/",
                            "original", "changed"], root, (1,))
        lines = [re.sub(rb"([ab])/(?:original|changed)/", rb"\1/", line)
                 if line.startswith((b"diff --git ", b"--- ", b"+++ ")) else line
                 for line in raw.splitlines(keepends=True)]
        patch = OUT / "patches" / (label + "-r1-against-b2.patch")
        copy(b"".join(lines), patch)
        for flags in (("--check",), ()):
            base.command(["git", "-c", "core.autocrlf=false", "apply", "--binary", *flags, str(patch)], rebuilt)
        actual = sorted(p.relative_to(rebuilt).as_posix() for p in rebuilt.rglob("*") if p.is_file())
        assert actual == files
        for name in files:
            assert (rebuilt / name).read_bytes() == (after / name).read_bytes(), name
    return dict(repository=label, baseline="original verified B2 export", files=len(files),
                patch_sha256=base.sha(patch.read_bytes()), apply_check_exit=0, apply_exit=0,
                exact_raw_byte_reconstruction=True)


def analyze():
    rows = []
    for line in (OUT / "evidence/r1-analyze-final-02.log").read_text().splitlines():
        match = re.search(r"info - (.+) - ((?:lib|test)[\\/].+\.dart):(\d+):(\d+) - (\w+)", line)
        if not match:
            assert not re.search(r"\b(?:error|warning) - ", line), line
            continue
        message, name, number, column, code = match.groups()
        name = name.replace("\\", "/")
        root, head, _, _ = base.REPOS["flutter"]
        original = base.git(root, "show", head + ":" + name).decode("utf-8-sig").splitlines()
        current = (root / name).read_text(encoding="utf-8-sig").splitlines()
        old_line = None
        for a, b, count in difflib.SequenceMatcher(None, original, current, autojunk=False).get_matching_blocks():
            if b <= int(number) - 1 < b + count:
                old_line = a + int(number) - b
                break
        assert code == "deprecated_member_use" and old_line is not None, "New analyzer finding: " + line
        rows.append(dict(path=name, line=int(number), baseline_line=old_line, code=code, message=message))
    assert rows
    base.write_json(OUT / "evidence/analyzer-baseline-comparison.json",
                    dict(errors=0, warnings=0, new_findings=0, existing_infos=rows))
    return len(rows)


def support_sources(inventory):
    selected = set()
    for record in inventory:
        if record["id"] not in FINAL:
            continue
        for test in record.get("tests", []):
            if isinstance(test, str):
                match = re.match(r"(app\.tests\.test_[^.]+)", test)
                if match:
                    selected.add(("backend", match.group(1).replace(".", "/") + ".py"))
            elif test.get("file"):
                selected.add(("flutter", Path(test["file"]).relative_to(base.REPOS["flutter"][0]).as_posix()))
    helpers = {
        "flutter": ["lib/api/client.dart", "lib/core/config/env.dart", "lib/features/auth/controller/auth_controller.dart",
            "lib/data/chat/chat_repository.dart", "lib/data/chat/chat_session_models.dart", "lib/app.dart",
            "lib/data/memory/models/memory_item.dart", "lib/core/localization/app_localizations.dart",
            "android/app/build.gradle.kts", "android/build.gradle.kts", "android/settings.gradle.kts",
            "android/app/src/main/AndroidManifest.xml", "android/app/src/debug/AndroidManifest.xml",
            "android/app/src/profile/AndroidManifest.xml", "pubspec.yaml"],
        "backend": ["app/tests/run_account_recovery_b1.py", "app/tests/memory_test_support.py",
            "app/tests/memory_test_processes.py", "app/api/routes/chat.py", "app/api/routes/profile.py",
            "app/api/deps/profile.py", "app/api/deps/memory.py", "app/core/deps.py", "app/core/security.py",
            "app/core/config.py", "app/db/session.py", "app/db/base.py", "app/services/context/store.py",
            "app/emiso/memory/schema.py", "app/repositories/memory_repo.py", "app/contracts/memory/types.py",
            "app/db/models/apple_confirmation.py", "app/db/models/apple_deletion.py",
            "app/services/auth/apple_confirmation_service.py", "app/services/auth/apple_deletion_config.py",
            "app/services/auth/apple_deletion_service.py"],
    }
    for label, names in helpers.items():
        selected.update((label, name) for name in names)
    # Recursively include local test-only helpers imported by selected Dart tests.
    pending = [name for label, name in selected if label == "flutter" and name.startswith("test/")]
    while pending:
        name = pending.pop()
        root = base.REPOS["flutter"][0]
        for relative in re.findall(r"(?:import|export)\s+['\"]([^'\"]+)['\"]", (root / name).read_text(encoding="utf-8-sig")):
            if ":" in relative:
                continue
            path = (root / name).parent.joinpath(relative).resolve()
            candidate = path.relative_to(root).as_posix()
            if candidate.startswith("test/") and ("flutter", candidate) not in selected:
                selected.add(("flutter", candidate))
                pending.append(candidate)
    rows = []
    for label, name in sorted(selected):
        root, head, _, _ = base.REPOS[label]
        path = root / name
        assert path.is_file() and not path.is_symlink(), name
        assert not path.name.startswith(".env") and path.suffix in (".py", ".dart", ".kts", ".xml", ".yaml")
        data = path.read_bytes()
        hash_runs = []
        if path.suffix in (".py", ".dart"):
            for run_id in (FINAL[:2] if label == "backend" else FINAL[2:]):
                recorded = json.loads((OUT / "evidence" / (run_id + "-sources.json")).read_text())["after"]
                assert recorded[name] == base.sha(data), (name, run_id)
                hash_runs.append(run_id)
        destination = OUT / "test-support" / label / name
        copy(data, destination)
        rows.append(dict(repository=label, path=name, bytes=len(data), sha256=base.sha(data),
                         export_path=destination.relative_to(OUT).as_posix(),
                         final_source_hash_evidence=hash_runs))
    base.write_json(OUT / "TEST_SOURCE_MAP.json", rows)


def inspect():
    check_budget()
    original = verify_original()
    assert not OUT.with_suffix(".zip").exists()
    states = {label: base.repo_state(label) for label in base.REPOS}
    inventory = base.test_inventory()
    final = {r["id"]: r for r in inventory if r["id"] in FINAL}
    assert set(final) == set(FINAL) and all(r["exit_code"] == 0 for r in final.values())
    for record in final.values():
        assert not any(record.get(k, 0) for k in ("failures", "errors", "skipped", "hidden_error_results", "raw_error_events"))
    old_manifest = json.loads((OLD / "SOURCE_MANIFEST.json").read_text())
    old_sources = {(r["repository"], r["path"]): r for r in old_manifest}
    manifest, deltas, patches, syntax, protected = [], [], [], [], []
    for label, state in states.items():
        root, head, _, _ = base.REPOS[label]
        assert state["upstream"] == "origin/" + state["branch"]
        for name in state["files"]:
            data = (root / name).read_bytes()
            copy(data, OUT / "sources" / label / name)
            row = dict(repository=label, path=name, status="new" if name in state["untracked"] else "modified",
                       bytes=len(data), sha256=base.sha(data))
            previous = None
            if name in state["modified"]:
                baseline = base.git(root, "show", head + ":" + name)
                copy(baseline, OUT / "baseline" / label / name)
                row.update(baseline_bytes=len(baseline), baseline_sha256=base.sha(baseline))
                # A newly affected tracked path was byte-identical to its checkout
                # at B2 entry; preserve Windows checkout line endings for that base.
                previous = baseline.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n") if b"\r\n" in data else baseline
            if (label, name) in old_sources:
                previous = (OLD / "sources" / label / name).read_bytes()
                assert base.sha(previous) == old_sources[(label, name)]["sha256"]
            elif previous is not None:
                prior_run = "flutter-final" if label == "flutter" else "backend-05"
                prior_hashes = json.loads((OLD / "evidence" / (prior_run + "-sources.json")).read_text())["after"]
                assert base.sha(previous) == prior_hashes[name], "Unverified B2 checkout baseline: " + name
            row["r1_changed"] = previous != data
            if row["r1_changed"]:
                if previous is not None:
                    copy(previous, OUT / "b2-baseline" / label / name)
                deltas.append(dict(repository=label, path=name, bytes=len(data), sha256=base.sha(data),
                    original_b2_sha256=base.sha(previous) if previous is not None else None,
                    baseline_source="B2 snapshot" if (label, name) in old_sources else
                    "unchanged B1 checkout (B2 entry clean path)" if previous is not None else "absent at B2 entry"))
            if name.endswith(".py"):
                compile(data, str(root / name), "exec", dont_inherit=True)
                ast.parse(data, filename=name)
                syntax.append(dict(repository=label, path=name, sha256=base.sha(data)))
            manifest.append(row)
        patches.append(base.verify_patch(label, state))
        patches.append(delta(label, sorted(r["path"] for r in deltas if r["repository"] == label)))
        tracked = base.text_git(root, "ls-files").splitlines()
        guarded = [n for n in tracked if n.startswith(("alembic/versions/", "android/", "ios/", "app/services/auth/",
            "app/contracts/memory/", "app/emiso/memory/", "app/repositories/", "app/services/context/")) or n in (
                "pubspec.yaml", "pubspec.lock", "requirements.txt", "lib/api/client.dart")]
        for name in guarded:
            if name in state["files"]:
                continue
            previous = base.git(root, "show", head + ":" + name)
            data = (root / name).read_bytes()
            assert data.replace(b"\r\n", b"\n") == previous.replace(b"\r\n", b"\n"), name
            protected.append(dict(repository=label, path=name, sha256=base.sha(data), unchanged_from_b1=True))
    for row in old_manifest:
        if row["path"].startswith("alembic/versions/"):
            assert base.sha((base.REPOS[row["repository"]][0] / row["path"]).read_bytes()) == row["sha256"]
            protected.append(dict(repository=row["repository"], path=row["path"], sha256=row["sha256"], unchanged_from_b2=True))
    # Every changed product/test source must match the exact final run hashes.
    source_runs = {}
    for run_id in FINAL:
        evidence = json.loads((OUT / "evidence" / (run_id + "-sources.json")).read_text())
        assert evidence["unchanged"]
        source_runs[run_id] = evidence["after"]
    for row in manifest:
        label, name = row["repository"], row["path"]
        ids = FINAL[:2] if label == "backend" else FINAL[2:] if name.endswith(".dart") else ()
        for run_id in ids:
            assert source_runs[run_id][name] == row["sha256"], (name, run_id)
        row["final_source_evidence"] = list(ids) if ids else ["export/syntax or actual shared fixture"]
        if name.endswith("test_projects_b2_postgresql.py"):
            row["execution_status"] = "PREPARED, NOT RUN; hashes and syntax only; no PostgreSQL acceptance"
    fixture = OUT / "sources/flutter/test/fixtures/product_b2_responses.json"
    assert fixture.read_bytes() == (OUT / "evidence/r1-backend-01-backend-responses.json").read_bytes()
    assert base.sha(fixture.read_bytes()) == source_runs[FINAL[2]]["test/fixtures/product_b2_responses.json"]
    count = analyze()
    support_sources(inventory)
    base.write_json(OUT / "SOURCE_MANIFEST.json", manifest)
    base.write_json(OUT / "R1_DELTA_MANIFEST.json", deltas)
    base.write_json(OUT / "evidence/selected-test-inventory.json", inventory)
    base.write_json(OUT / "evidence/final-git-state.json", states)
    base.write_json(OUT / "evidence/patch-verification.json", patches)
    base.write_json(OUT / "evidence/protected-files.json", protected)
    base.write_json(OUT / "evidence/python-syntax.json", dict(exit_code=0, files=syntax, application_imports=False,
                    python_type_check="NOT RUN; no verified installed type checker; no installation"))
    base.write_json(OUT / "evidence/original-export-final-verification.json", original)
    base.write_json(OUT / "evidence/export-inspection-commands.json", dict(budget=check_budget(), commands=base.COMMANDS))
    lines = ["# Aktueller B2-Stand und Nacharbeitsdelta", "", "Gesamt gegen B1: " + str(len(manifest)) +
             " Dateien; R1 gegen ursprüngliches B2: " + str(len(deltas)) + " Dateien.", ""]
    for label, state in states.items():
        lines += ["## " + label, "", "```text", state["status"], "```", "", "R1:", ""]
        lines += ["- " + r["path"] for r in deltas if r["repository"] == label]
        lines.append("")
    (OUT / "FILES_AND_GIT_STATUS.md").write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps(dict(changed_sources=len(manifest), r1_delta_files=len(deltas), existing_analyzer_infos=count,
        final_tests=[{k: v for k, v in r.items() if k in ("id", "run", "failures", "errors", "skipped", "exit_code")}
                     for r in final.values()], patches=patches, budget=check_budget()), indent=2))


def package():
    check_budget()
    verify_original()
    base.write_json(OUT / "evidence/completion-budget.json", check_budget())
    base.package()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("inspect", "package"))
    args = parser.parse_args()
    (inspect if args.action == "inspect" else package)()
