"""Source-only B2 readiness counterexample. No application import or DB access."""
import ast
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import time

APP = Path(r"C:\Users\Patze\Emie\app")
BACKEND = APP.parent / "backend"
OUT = Path(r"C:\Users\Patze\Emie-Recovery\beta-b2-r1-20261001T152143Z-2bc8d433")
sources = []


def tree(name):
    data = (BACKEND / name).read_bytes()
    sources.append(dict(path=name, sha256=hashlib.sha256(data).hexdigest()))
    return ast.parse(data, filename=name)


def constants(parsed):
    result = {}
    for node in parsed.body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            try:
                result[node.targets[0].id] = ast.literal_eval(node.value)
            except (ValueError, TypeError):
                pass
    return result


def main():
    budget = json.loads((OUT / "BUDGET.json").read_text(encoding="utf-8-sig"))
    assert time.monotonic() < budget["deadline_monotonic"]
    migration = constants(tree("alembic/versions/d8e4b2a90173_add_projects_v0.py"))
    assert migration["revision"] == "d8e4b2a90173" and migration["down_revision"] == "c92f6a10d847"
    memory = tree("app/repositories/memory_repo.py")
    values = constants(memory)
    values.update(constants(tree("app/contracts/memory/types.py")))
    function = next(n for n in memory.body if isinstance(n, ast.FunctionDef) and n.name == "_check_memory_schema")
    condition = next(n for n in ast.walk(function) if isinstance(n, ast.If) and
                     "revisions[0] not in" in ast.unparse(n.test))
    # Evaluate only the inspected revision predicate, with literals and len.
    expression = ast.Expression(condition.test)
    rows = []
    for revision, expected in ((migration["down_revision"], False), (migration["revision"], True)):
        rejected = eval(compile(expression, "memory-revision-predicate", "eval"),
                        {"__builtins__": {"len": len}}, {**values, "revisions": [revision]})
        assert rejected is expected
        rows.append(dict(guard="memory", revision=revision, rejected=rejected,
                         line=condition.lineno, predicate=ast.unparse(condition.test)))
    for filename, function_name in (
        ("app/db/models/apple_confirmation.py", "check_apple_confirmation_schema"),
        ("app/db/models/apple_deletion.py", "check_deletion_schema"),
    ):
        parsed = tree(filename)
        values = constants(parsed)
        function = next(n for n in parsed.body if isinstance(n, ast.FunctionDef) and n.name == function_name)
        condition = next(n for n in ast.walk(function) if isinstance(n, ast.If) and
                         "SELECT version_num FROM alembic_version" in ast.unparse(n.test))
        assert isinstance(condition.test, ast.Compare) and len(condition.test.ops) == 1
        # Substitute the hypothetical revision query result; never execute SQL.
        predicate = ast.Expression(ast.Compare(ast.Name("revisions", ast.Load()),
                                               condition.test.ops, condition.test.comparators))
        ast.fix_missing_locations(predicate)
        for revision, expected in ((migration["down_revision"], False), (migration["revision"], True)):
            rejected = eval(compile(predicate, "apple-revision-predicate", "eval"),
                            {"__builtins__": {}}, {**values, "revisions": [revision]})
            assert rejected is expected
            rows.append(dict(guard=function_name, revision=revision, rejected=rejected,
                             line=condition.lineno, predicate=ast.unparse(condition.test)))
    prior = APP.parent.parent / "Emie-Recovery/beta-b2-produktstamm-20260930T201000Z-7e6194ab"
    runtime = json.loads((prior / "evidence/runtime-and-open-gates.json").read_text())
    for record in runtime["executables"]:
        assert hashlib.sha256(Path(record["path"]).read_bytes()).hexdigest() == record["sha256"]
    result = dict(utc=datetime.now(timezone.utc).isoformat(), monotonic=time.monotonic(),
        remaining_minutes=round((budget["deadline_monotonic"] - time.monotonic()) / 60, 2),
        kind="source-only counterexample, NOT a server startup or database test",
        application_imports=False, database_connections=False, server_started=False,
        b2_start_blocker_confirmed=True, revision_cases=rows, sources=sources,
        runtime_hashes_match_original_b2=True, runtime_executables=runtime["executables"],
        existence_only={name: (APP / name).exists() for name in (
            "android/local.properties", "android/key.properties", "android/app/google-services.json",
            "assets/icons", "assets/images", ".dart_tool/package_config.json")},
        secret_configuration_contents_read=False)
    target = OUT / "evidence/source-start-readiness.json"
    assert not target.exists()
    target.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
