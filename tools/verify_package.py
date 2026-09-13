"""在隔离用户目录验证导出 PCK 或 Windows 成品的生成、真实拾取与存档读回。"""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def run_checked(command, env, log_path=None):
    """运行引擎或成品，超时保留日志，并拒绝退出失败及脚本错误。"""
    try:
        result = subprocess.run(
            command, env=env, capture_output=True, text=True,
            encoding="utf-8", errors="replace", timeout=120,
        )
    except subprocess.TimeoutExpired as error:
        if log_path is not None and log_path.exists():
            print(log_path.read_text(encoding="utf-8", errors="replace"))
        raise SystemExit("成品验证超过 120 秒") from error
    diagnostics = result.stdout + result.stderr
    output = (log_path.read_text(encoding="utf-8", errors="replace")
              if log_path is not None and log_path.exists()
              else diagnostics)
    print(output)
    if result.returncode or "SCRIPT ERROR:" in output + diagnostics or "ERROR:" in output + diagnostics:
        if diagnostics and diagnostics not in output:
            print(diagnostics)
        raise SystemExit(result.returncode or 1)
    return output


def verify_package(godot=None, executable=None, log_path=None):
    """源码引擎先导出 PCK；发行 exe 直接运行相同的包内拾取场景。"""
    with tempfile.TemporaryDirectory(prefix="relic-package-") as directory:
        temporary = Path(directory)
        env = dict(os.environ, XDG_DATA_HOME=directory, APPDATA=directory)
        if executable is not None:
            command = [str(Path(executable).resolve())]
        else:
            project = Path(__file__).resolve().parents[1] / "game"
            packed = temporary / "relic.pck"
            run_checked([godot, "--headless", "--path", str(project),
                         "--export-pack", "Windows Desktop", str(packed)], env)
            # 运行目录没有源码资源，防止遗漏文件被本地工程意外补齐。
            command = [godot, "--path", directory, "--main-pack", str(packed)]
        log = Path(log_path).resolve() if log_path else temporary / "package-smoke.log"
        log.parent.mkdir(parents=True, exist_ok=True)
        if log.exists():
            log.unlink()
        output = run_checked([
            *command, "--headless", "--fixed-fps", "60", "--quit-after", "600",
            "--log-file", str(log), "--", "--smoke-loot",
        ], env, log)
        for marker in ("PACKAGE_LOOT_BOOT_READY", "PICKUP_INPUT_RESULT: 0 failures"):
            if marker not in output:
                raise SystemExit("成品验证未完成：" + marker)
        print("PACKAGE_LOOT_RESULT: 0 failures")


def main():
    """选择源码引擎或独立发行包，并允许 CI 保留包内验证日志。"""
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--godot")
    target.add_argument("--executable")
    parser.add_argument("--log")
    args = parser.parse_args()
    verify_package(args.godot, args.executable, args.log)


if __name__ == "__main__":
    main()
