"""在临时用户目录运行引擎导入和 M0/M1/M2/D1/Hub/DebugLog 回归，发现脚本错误时失败。"""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile


TEST_MARKERS = {
    "res://tests/resource_model.tscn": "RESOURCE_MODEL_RESULT: 0 failures",
    "res://tests/resource_store.tscn": "RESOURCE_STORE_RESULT: 0 failures",
    "res://tests/m0_smoke.tscn": "M0_SMOKE_RESULT: 0 failures",
    "res://tests/m1_combat.tscn": "M1_COMBAT_RESULT: 0 failures",
    "res://tests/m2_loop.tscn": "M2_LOOP_RESULT: 0 failures",
    "res://tests/p1_loadout.tscn": "P1_LOADOUT_RESULT: 0 failures",
    "res://tests/p1_bleed_skills.tscn": "P1_BLEED_SKILLS_RESULT: 0 failures",
    "res://tests/hub_flow.tscn": "HUB_FLOW_RESULT: 0 failures",
    "res://tests/debug_console.tscn": "DEBUG_CONSOLE_RESULT: 0 failures",
}


def _partial_text(value):
    """把 TimeoutExpired 保留的字节或文本统一转换为可读日志。"""
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return value


def main():
    """接收引擎路径并依次运行导入、启动和场景回归。"""
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1] / "game"
    with tempfile.TemporaryDirectory(prefix="relic-tests-") as directory:
        env = os.environ.copy()
        env["XDG_DATA_HOME"] = directory
        env["APPDATA"] = directory
        commands = [
            ["--editor", "--import", "--quit"],
            ["--quit-after", "10"],
            *[[scene] for scene in TEST_MARKERS],
        ]
        for extra in commands:
            try:
                result = subprocess.run(
                    [args.godot, "--headless", "--path", str(project), *extra],
                    env=env, capture_output=True, text=True, timeout=120,
                    encoding="utf-8", errors="replace",
                )
            except subprocess.TimeoutExpired as error:
                print(_partial_text(error.stdout) + _partial_text(error.stderr))
                raise SystemExit("Godot 场景验证超过 120 秒：" + " ".join(extra)) from error
            output = result.stdout + result.stderr
            print(output)
            if result.returncode or "SCRIPT ERROR:" in output or "ERROR:" in output:
                raise SystemExit(result.returncode or 1)
            marker = TEST_MARKERS.get(extra[0])
            if marker is not None and marker not in output:
                raise SystemExit("测试未运行到完成标记")


if __name__ == "__main__":
    main()
