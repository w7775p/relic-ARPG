"""在临时用户目录运行引擎导入和 M0 回归，发现脚本错误时失败。"""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    """接收引擎路径并依次运行导入、启动和场景回归。"""
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1] / "game"
    with tempfile.TemporaryDirectory(prefix="relic-m0-") as directory:
        env = os.environ.copy()
        env["XDG_DATA_HOME"] = directory
        env["APPDATA"] = directory
        commands = [
            ["--editor", "--import", "--quit"],
            ["--quit-after", "10"],
            ["res://tests/m0_smoke.tscn"],
        ]
        for extra in commands:
            result = subprocess.run(
                [args.godot, "--headless", "--path", str(project), *extra],
                env=env, capture_output=True, text=True, timeout=120,
                encoding="utf-8", errors="replace",
            )
            output = result.stdout + result.stderr
            print(output)
            if result.returncode or "SCRIPT ERROR:" in output or "ERROR:" in output:
                raise SystemExit(result.returncode or 1)
            if extra == commands[-1] and "M0_SMOKE_RESULT: 0 failures" not in output:
                raise SystemExit("测试未运行到完成标记")


if __name__ == "__main__":
    main()
