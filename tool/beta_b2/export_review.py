"""Create the single B2 review export; never modifies either repository's Git state.

inspect: copy changed/new sources and baseline blobs, verify full raw-byte patches,
         inventory selected tests, compile Python sources without importing them.
package: verify snapshots against working sources, build one ZIP, verify each member.
No application imports, network calls, database connections, or package resolution.
"""
import argparse
import ast
from collections import Counter
from datetime import datetime, timezone
import difflib
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys
import subprocess
import tempfile
import zipfile

OUT = Path(r"C:\Users\Patze\Emie-Recovery\beta-b2-produktstamm-20260930T201000Z-7e6194ab")
REPOS = {
    "flutter": (Path(r"C:\Users\Patze\Emie\app"), "1f4c4b366c01a05cc87adc419cb675d0acaa9e40", "main", "https://github.com/ai-emie/emie-app.git"),
    "backend": (Path(r"C:\Users\Patze\Emie\backend"), "dca6311a3e6d00eaf409cfd70a299559b0e068f9", "feat/emiso-ai-router-v1", "https://github.com/ai-emie/emie-backend.git"),
}
COMMANDS = []


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def command(args, cwd, allowed=(0,)):
    result = subprocess.run(args, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    COMMANDS.append(dict(command=list(map(str, args)), cwd=str(cwd), exit_code=result.returncode))
    if result.returncode not in allowed:
        raise RuntimeError(result.stderr.decode("utf-8", errors="replace"))
    return result.stdout


def git(root, *args):
    return command(["git", "-c", "safe.directory=" + root.as_posix(), "-c", "core.quotepath=false", "-C", str(root), *args], root)


def text_git(root, *args):
    return git(root, *args).decode("utf-8").strip()


def safe_source(name):
    path = Path(name)
    assert not path.is_absolute() and ".." not in path.parts
    assert not set(path.parts) & {".git", ".venv", "venv", "__pycache__", ".dart_tool", "build"}
    assert not path.name.startswith(".env")
    assert path.suffix in {".py", ".dart", ".json"}, name


def repo_state(label):
    root, head, branch, origin = REPOS[label]
    assert Path(text_git(root, "rev-parse", "--show-toplevel")).resolve() == root.resolve()
    assert text_git(root, "rev-parse", "HEAD") == head
    assert text_git(root, "branch", "--show-current") == branch
    assert text_git(root, "remote", "get-url", "origin") == origin
    staged = text_git(root, "diff", "--cached", "--name-only")
    assert not staged, "Index changed"
    modified = text_git(root, "diff", "--name-only", head).splitlines()
    added = text_git(root, "ls-files", "--others", "--exclude-standard").splitlines()
    files = sorted(set(modified + added))
    for name in files:
        safe_source(name)
        assert (root / name).is_file() and not (root / name).is_symlink()
    return dict(root=str(root), branch=branch, head=head, origin=origin,
        upstream=text_git(root, "rev-parse", "--abbrev-ref", "@{upstream}"),
        status=git(root, "status", "--short", "--untracked-files=all").decode("utf-8").rstrip(),
        index_clean=True, modified=modified, untracked=added, files=files)


def verify_patch(label, state):
    # Both trees contain only the affected paths. No checkout, staging or repo writes.
    with tempfile.TemporaryDirectory(prefix="emie-b2-review-") as directory:
        temporary = Path(directory).resolve()
        assert temporary.parent == Path(tempfile.gettempdir()).resolve()
        assert temporary.name.startswith("emie-b2-review-")
        before, after, reconstructed = (temporary / x for x in ("original", "changed", "reconstructed"))
        for folder in (before, after, reconstructed):
            folder.mkdir()
        for name in state["files"]:
            baseline = OUT / "baseline" / label / name
            if baseline.exists():
                for target in (before / name, reconstructed / name):
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(baseline, target)
            target = after / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(OUT / "sources" / label / name, target)
        raw = command(["git", "-c", "core.autocrlf=false", "diff", "--no-index", "--no-ext-diff", "--no-renames", "--binary", "--full-index", "--src-prefix=a/", "--dst-prefix=b/", "original", "changed"], temporary, (1,))
        lines = []
        for line in raw.splitlines(keepends=True):
            if line.startswith((b"diff --git ", b"--- ", b"+++ ")):
                line = re.sub(rb"([ab])/(?:original|changed)/", rb"\1/", line)
            lines.append(line)
        patch = OUT / "patches" / (label + "-against-b1.patch")
        patch.parent.mkdir(exist_ok=True)
        patch.write_bytes(b"".join(lines))
        for flags in (("--check",), ()):
            command(["git", "-c", "core.autocrlf=false", "apply", "--binary", *flags, str(patch)], reconstructed)
        actual = sorted(p.relative_to(reconstructed).as_posix() for p in reconstructed.rglob("*") if p.is_file())
        assert actual == state["files"]
        for name in actual:
            assert (reconstructed / name).read_bytes() == (after / name).read_bytes(), name
        return dict(repository=label, baseline=state["head"], files=len(actual),
            patch_sha256=sha(patch.read_bytes()), apply_check_exit=0, apply_exit=0,
            exact_raw_byte_reconstruction=True, repository_git_state_untouched=True)


def test_inventory():
    inventory = []
    for metadata in sorted((OUT / "evidence").glob("*.json")):
        data = json.loads(metadata.read_text(encoding="utf-8-sig"))
        if not isinstance(data, dict) or "command" not in data or "exit_code" not in data:
            continue
        log = metadata.with_suffix(".log")
        if not log.exists():
            continue
        record = dict(id=metadata.stem, **data)
        events = []
        for line in log.read_text(encoding="utf-8-sig").splitlines():
            try:
                event = json.loads(line)
            except ValueError:
                continue
            if isinstance(event, dict):
                events.append(event)
        backend = next((x for x in events if "run" in x and "tests" in x), None)
        if backend:
            record.update({key: backend[key] for key in ("run", "failures", "errors", "skipped", "tests")})
        starts = {x["test"]["id"]: x["test"] for x in events if x.get("type") == "testStart"}
        suites = {x["suite"]["id"]: x["suite"] for x in events if x.get("type") == "suite"}
        if starts:
            done = [x for x in events if x.get("type") == "testDone" and not x.get("hidden", False)]
            tests = []
            for event in done:
                test = starts[event["testID"]]
                tests.append(dict(name=test["name"], result=event["result"], skipped=event.get("skipped", False),
                    file=suites[test["suiteID"]].get("path"), id=event["testID"]))
            record.update(run=len(done), failures=sum(x["result"] == "failure" for x in done),
                errors=sum(x["result"] == "error" for x in done), skipped=sum(x.get("skipped", False) for x in done), tests=tests)
            record["raw_error_events"] = sum(x.get("type") == "error" for x in events)
            record["hidden_error_results"] = sum(x.get("type") == "testDone" and x.get("hidden", False) and x.get("result") != "success" for x in events)
        inventory.append(record)
    return inventory


def inspect():
    assert OUT.is_dir() and not OUT.with_suffix(".zip").exists()
    states = {label: repo_state(label) for label in REPOS}
    manifest, patches, syntax, protected = [], [], [], []
    inventory = test_inventory()
    by_id = {x["id"]: x for x in inventory}
    assert by_id["backend-05"]["exit_code"] == by_id["backend-regression-03"]["exit_code"] == by_id["flutter-final"]["exit_code"] == by_id["analyze-03"]["exit_code"] == 0
    for label, state in states.items():
        root, head, _, _ = REPOS[label]
        for name in state["files"]:
            data = (root / name).read_bytes()
            target = OUT / "sources" / label / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            row = dict(repository=label, path=name, status="new" if name in state["untracked"] else "modified", bytes=len(data), sha256=sha(data))
            if name in state["modified"]:
                original = git(root, "show", head + ":" + name)
                baseline = OUT / "baseline" / label / name
                baseline.parent.mkdir(parents=True, exist_ok=True)
                baseline.write_bytes(original)
                row.update(baseline_bytes=len(original), baseline_sha256=sha(original))
            row["test_evidence"] = (["flutter-final", "analyze-03"] if label == "flutter" and name.endswith(".dart") else
                ["backend-05", "backend-regression-03"] if label == "backend" else ["export/syntax"])
            if name.endswith("test_projects_b2_postgresql.py"):
                row["test_evidence"] = ["export/syntax; PostgreSQL NOT RUN"]
            if name == "test/fixtures/product_b2_responses.json":
                row["test_evidence"] = ["backend-05 actual HTTP responses", "flutter-final consumers"]
            if name.endswith(".py"):
                compile(data, str(root / name), "exec", dont_inherit=True)
                ast.parse(data, filename=name)
                syntax.append(dict(repository=label, path=name, sha256=sha(data)))
            manifest.append(row)
        patches.append(verify_patch(label, state))
        tracked = text_git(root, "ls-files").splitlines()
        guarded = [name for name in tracked if (
            name.startswith("alembic/versions/") or name in ("pubspec.yaml", "pubspec.lock", "requirements.txt", "poetry.lock", "uv.lock", "pyproject.toml", "lib/api/client.dart") or
            name.startswith(("app/services/auth/", "app/contracts/memory/", "app/emiso/memory/", "app/repositories/"))
        ) and name not in state["files"]]
        for name in guarded:
            baseline = git(root, "show", head + ":" + name)
            data = (root / name).read_bytes()
            assert data.replace(b"\r\n", b"\n") == baseline.replace(b"\r\n", b"\n"), name
            protected.append(dict(repository=label, path=name, baseline_sha256=sha(baseline), working_sha256=sha(data), same_content_allowing_checkout_crlf=True))
    flutter_sources = json.loads((OUT / "evidence/flutter-final-sources.json").read_text())
    assert flutter_sources["unchanged"]
    for row in manifest:
        if row["repository"] == "flutter" and (row["path"].endswith(".dart") or row["path"] == "test/fixtures/product_b2_responses.json"):
            assert flutter_sources["after"][row["path"]] == row["sha256"], "Tested source differs"
    # Match remaining diagnostics to unchanged baseline lines, without a second checkout.
    analysis = []
    for line in (OUT / "evidence/analyze-03.log").read_text(encoding="utf-8").splitlines():
        match = re.search(r"info - (.+) - (lib[\\/].+\.dart):(\d+):(\d+) - (\w+)", line)
        if not match:
            continue
        message, name, number, column, code = match.groups()
        name = name.replace("\\", "/")
        root, head, _, _ = REPOS["flutter"]
        original = git(root, "show", head + ":" + name).decode("utf-8-sig").splitlines()
        current = (root / name).read_text(encoding="utf-8-sig").splitlines()
        old_line = None
        for a, b, length in difflib.SequenceMatcher(None, original, current, autojunk=False).get_matching_blocks():
            if b <= int(number) - 1 < b + length:
                old_line = a + int(number) - b
                break
        assert code == "deprecated_member_use" and old_line is not None, "New analyzer finding"
        analysis.append(dict(path=name, line=int(number), column=int(column), baseline_line=old_line, code=code, message=message, unchanged_from_b1=True))
    # Include the exact selected test source files and unchanged direct helper sources.
    test_sources = set()
    for record in inventory:
        if record["id"] not in ("backend-05", "backend-regression-03", "flutter-final"):
            continue
        for test in record.get("tests", []):
            if isinstance(test, str):
                match = re.match(r"(app\.tests\.test_[^.]+)", test)
                if match:
                    test_sources.add(("backend", match.group(1).replace(".", "/") + ".py"))
            elif test.get("file"):
                test_sources.add(("flutter", Path(test["file"]).relative_to(REPOS["flutter"][0]).as_posix()))
    for name in ("app/tests/run_account_recovery_b1.py", "app/tests/memory_test_support.py", "app/tests/memory_test_processes.py"):
        test_sources.add(("backend", name))
    mapped = []
    for label, name in sorted(test_sources):
        safe_source(name)
        data = (REPOS[label][0] / name).read_bytes()
        target = OUT / "test-support" / label / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        mapped.append(dict(repository=label, path=name, bytes=len(data), sha256=sha(data), export_path=target.relative_to(OUT).as_posix()))
    write_json(OUT / "SOURCE_MANIFEST.json", manifest)
    write_json(OUT / "TEST_SOURCE_MAP.json", mapped)
    write_json(OUT / "evidence/selected-test-inventory.json", inventory)
    write_json(OUT / "evidence/final-git-state.json", states)
    write_json(OUT / "evidence/patch-verification.json", patches)
    write_json(OUT / "evidence/protected-files.json", protected)
    write_json(OUT / "evidence/python-syntax.json", dict(exit_code=0, files=syntax, imports_executed=False, python_type_checker="unavailable; not installed; static type checking NOT RUN"))
    write_json(OUT / "evidence/analyzer-baseline-comparison.json", dict(errors=0, warnings=0, new_findings=0, existing_infos=analysis))
    dart = Path(r"C:\Users\Patze\flutter\bin\cache\dart-sdk\bin\dart.exe")
    flutter = Path(r"C:\Users\Patze\flutter\bin\cache\flutter_tools.snapshot")
    version = json.loads(Path(r"C:\Users\Patze\flutter\bin\cache\flutter.version.json").read_text())
    assert version["frameworkVersion"] == "3.38.6" and version["dartSdkVersion"] == "3.10.7"
    assert sys.version_info[:3] == (3, 11, 9) and sys.flags.isolated and sys.flags.no_site
    runtime_files = [dart, flutter, Path(sys.executable)]
    write_json(OUT / "evidence/runtime-and-open-gates.json", dict(
        python=sys.version, python_flags=dict(isolated=sys.flags.isolated, no_site=sys.flags.no_site, dont_write_bytecode=sys.dont_write_bytecode),
        flutter=version, executables=[dict(path=str(p), bytes=p.stat().st_size, sha256=sha(p.read_bytes())) for p in runtime_files],
        dart_version=command([str(dart), "--version"], REPOS["flutter"][0]).decode("utf-8").strip(),
        tool_presence={name:shutil.which(name) for name in ("psql", "pg_ctl", "initdb", "postgres", "docker", "mypy", "pyright", "basedpyright")},
        venv_python_type_checkers=[p.name for p in (REPOS["backend"][0] / ".venv/Lib/site-packages").iterdir() if p.name.startswith(("mypy", "pyright", "basedpyright"))],
        postgres_target="not verified; no connection attempted; prepared tests NOT RUN",
        native_device_tests="NOT RUN; synthetic widget tests are not device acceptance",
        cache="Existing C:/Users/Patze/AppData/Local/Pub/Cache; no pub/install/upgrade",
        initial_sdk_evidence="Existing successful B1 R2 evidence, confirmed locally before changes; recorded in PLAN_AND_RESUME.md"))
    write_json(OUT / "evidence/export-inspection-commands.json", dict(utc=datetime.now(timezone.utc).isoformat(), commands=COMMANDS))
    file_lines = ["# Vollständige Änderungsliste", ""]
    for label, state in states.items():
        file_lines += ["## " + label, "", "```text", state["status"], "```", ""]
    (OUT / "FILES_AND_GIT_STATUS.md").write_text("\n".join(file_lines), encoding="utf-8")
    print(json.dumps(dict(changed_sources=len(manifest), protected_files=len(protected), python_syntax_files=len(syntax), old_analyzer_infos=len(analysis), patches=patches,
        final_tests=[{k:v for k,v in record.items() if k in ("id", "run", "failures", "errors", "skipped", "exit_code")} for record in inventory if record["id"] in ("backend-05", "backend-regression-03", "flutter-final", "analyze-03")]), indent=2))


def package():
    archive = OUT.with_suffix(".zip")
    assert not archive.exists(), "Exactly one ZIP; never overwrite an earlier review"
    manifest = json.loads((OUT / "SOURCE_MANIFEST.json").read_text(encoding="utf-8"))
    for row in manifest:
        root = REPOS[row["repository"]][0]
        assert sha((root / row["path"]).read_bytes()) == row["sha256"]
        assert sha((OUT / "sources" / row["repository"] / row["path"]).read_bytes()) == row["sha256"]
    old_states = json.loads((OUT / "evidence/final-git-state.json").read_text(encoding="utf-8"))
    assert {label:repo_state(label) for label in REPOS} == old_states
    files = sorted(p for p in OUT.rglob("*") if p.is_file())
    assert not any(p.is_symlink() for p in files)
    rows = []
    for path in files:
        relative = path.relative_to(OUT)
        assert not set(relative.parts) & {".git", ".venv", "venv", "__pycache__", ".dart_tool", "build"}
        assert path.suffix not in {".db", ".sqlite", ".sqlite3", ".p8", ".pem", ".key", ".zip"}
        assert not path.name.startswith(".env")
        rows.append(dict(path=relative.as_posix(), bytes=path.stat().st_size, sha256=sha(path.read_bytes())))
    write_json(OUT / "EXPORT_INVENTORY.json", dict(description="Every payload file except this self-referential inventory. ZIP verifies this file too against the folder.", files=rows))
    files = sorted(p for p in OUT.rglob("*") if p.is_file())
    with zipfile.ZipFile(archive, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zipped:
        for path in files:
            zipped.write(path, path.relative_to(OUT).as_posix())
    with zipfile.ZipFile(archive) as zipped:
        expected = {p.relative_to(OUT).as_posix():p for p in files}
        assert set(zipped.namelist()) == set(expected)
        assert len(zipped.namelist()) == len(expected)
        assert zipped.testzip() is None
        for name, path in expected.items():
            assert zipped.getinfo(name).file_size == path.stat().st_size
            assert sha(zipped.read(name)) == sha(path.read_bytes()), name
    print(json.dumps(dict(zip=str(archive), bytes=archive.stat().st_size, files=len(files), sha256=sha(archive.read_bytes()), inventory_verified=True, every_member_hash_verified=True), indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["inspect", "package"])
    args = parser.parse_args()
    (inspect if args.action == "inspect" else package)()
