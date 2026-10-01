"""Explicit offline B2 commands using the verified B1 SDKs. No installs/pub."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

APP = Path(r"C:\Users\Patze\Emie\app")
BACKEND = Path(r"C:\Users\Patze\Emie\backend")
PYTHON = BACKEND / ".venv/Scripts/python.exe"
DART = r"C:\Users\Patze\flutter\bin\cache\dart-sdk\bin\dart.exe"
FLUTTER = r"C:\Users\Patze\flutter\bin\cache\flutter_tools.snapshot"


def source_hashes(root):
    files = subprocess.check_output([
        "git", "-c", "safe.directory=" + root.as_posix(), "-C", str(root),
        "ls-files", "--cached", "--others", "--exclude-standard", "-z"])
    return {name: hashlib.sha256((root / name).read_bytes()).hexdigest()
            for name in sorted(set(files.decode("utf-8").split("\0")))
            if name and (name.endswith((".py", ".dart")) or name in (
                "pubspec.yaml", "pubspec.lock", "requirements.txt",
                "test/fixtures/product_b2_responses.json"))}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("kind", choices=["backend", "regression", "flutter", "analyze", "format"])
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--id", required=True)
    parser.add_argument("paths", nargs="*")
    args = parser.parse_intermixed_args()
    out = args.output.resolve()
    assert out.parent == Path(r"C:\Users\Patze\Emie-Recovery") and out.name.startswith(("beta-b2-produktstamm-", "beta-b2-r1-"))
    evidence = out / "evidence"
    evidence.mkdir(exist_ok=True)
    stem = evidence / args.id
    assert not stem.with_suffix(".log").exists(), "Never overwrite earlier evidence"
    env = {k: os.environ[k] for k in ("SystemRoot", "PATH", "PATHEXT", "COMSPEC", "WINDIR",
        "TEMP", "TMP", "USERPROFILE", "APPDATA", "LOCALAPPDATA") if k in os.environ}
    env.update(FLUTTER_ROOT=r"C:\Users\Patze\flutter", CI="true", FLUTTER_SUPPRESS_ANALYTICS="true",
        DART_SUPPRESS_ANALYTICS="true", PUB_HOSTED_URL="http://127.0.0.1:1",
        FLUTTER_STORAGE_BASE_URL="http://127.0.0.1:1")
    apple_fixture = evidence / "b2-apple-responses.json"
    if args.kind == "flutter" and apple_fixture.exists():
        env["EMIE_APPLE_CONTRACT_FILE"] = str(apple_fixture)
    cwd = APP
    if args.kind in ("backend", "regression"):
        runner = "run_product_b2.py" if args.kind == "backend" else "run_product_b2_regression.py"
        command = [str(PYTHON), "-I", "-S", "-B", "-X", "utf8", str(BACKEND / "app/tests" / runner)]
        cwd = BACKEND
    elif args.kind == "format":
        command = [DART, "format", *args.paths]
    else:
        verb = "test" if args.kind == "flutter" else "analyze"
        command = [DART, FLUTTER, "--no-version-check", "--suppress-analytics", verb, "--no-pub"]
        command += ["--reporter=json"] if verb == "test" else ["--no-fatal-infos"]
        command += args.paths
    before_sources = source_hashes(cwd)
    started = time.perf_counter()
    process = subprocess.run(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
    after_sources = source_hashes(cwd)
    source_evidence = evidence / (args.id + "-sources.json")
    source_evidence.write_text(json.dumps(dict(root=str(cwd), before=before_sources,
        after=after_sources, unchanged=before_sources == after_sources), indent=2), encoding="utf-8")
    stem.with_suffix(".log").write_text(process.stdout, encoding="utf-8")
    result = dict(command=command, cwd=str(cwd), env_keys=sorted(env), exit_code=process.returncode,
        runtime_seconds=round(time.perf_counter() - started, 3), log=str(stem.with_suffix(".log")),
        source_evidence=str(source_evidence), source_unchanged=before_sources == after_sources)
    stem.with_suffix(".json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result))
    if args.kind == "regression" and process.returncode == 0:
        rows = [line.removeprefix("B2_APPLE_CONTRACT=") for line in process.stdout.splitlines()
                if line.startswith("B2_APPLE_CONTRACT=")]
        assert len(rows) == 1
        apple_fixture.write_text(json.dumps(json.loads(rows[0]), indent=2), encoding="utf-8")
    if args.kind == "backend" and process.returncode == 0:
        rows = [line.removeprefix("B2_CONTRACT_FIXTURE=") for line in process.stdout.splitlines()
                if line.startswith("B2_CONTRACT_FIXTURE=")]
        assert len(rows) == 1
        fixture = json.dumps(json.loads(rows[0]), indent=2, ensure_ascii=False) + "\n"
        (APP / "test/fixtures/product_b2_responses.json").write_text(fixture, encoding="utf-8")
        (evidence / (args.id + "-backend-responses.json")).write_text(fixture, encoding="utf-8")
    if args.kind == "flutter":
        for line in process.stdout.splitlines():
            try:
                row = json.loads(line)
            except ValueError:
                print(line[:1600])
                continue
            if row.get("type") in ("error", "done"):
                print(json.dumps(row, ensure_ascii=False))
    else:
        visible = "\n".join(line for line in process.stdout.splitlines()
                            if not line.startswith(("B2_CONTRACT_FIXTURE=", "B2_APPLE_CONTRACT=", '{"start_utc"')))
        print(visible[-9000:])
    return process.returncode


if __name__ == "__main__":
    raise SystemExit(main())
