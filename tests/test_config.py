"""Pure configuration and mocked dry-run tests; never run the bootstrap."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "start.sh"
FLAGS = "INSTALL_CLAUDE INSTALL_CODEX INSTALL_NODEJS INSTALL_DEV_TOOLS INSTALL_EXTENDED_TOOLS INSTALL_CODE_SERVER USE_ZSH".split()

class ConfigTests(unittest.TestCase):
    def run_config(self, **env):
        # Sourcing is guarded; PATH deliberately prevents any external command.
        return subprocess.run(["/bin/bash", "-c", 'source "$1"; resolve_profile; printf "%s " "$PROFILE" "$INSTALL_CLAUDE" "$INSTALL_CODEX" "$INSTALL_NODEJS" "$INSTALL_DEV_TOOLS" "$INSTALL_EXTENDED_TOOLS" "$INSTALL_CODE_SERVER" "$USE_ZSH"', "test", str(SCRIPT)], env={"PATH": "/nonexistent", **env}, text=True, capture_output=True)

    def test_profiles(self):
        for profile, expected in {"minimal": "1 0 0 0 0 0 0", "standard": "1 1 1 1 0 0 1", "full": "1 1 1 1 1 1 1"}.items():
            result = self.run_config(PROFILE=profile)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), f"{profile} {expected}")

    def test_all_explicit_overrides_including_final_flag(self):
        for profile in ["minimal", "standard", "full"]:
            for value in ["0", "1"]:
                result = self.run_config(PROFILE=profile, **dict.fromkeys(FLAGS, value))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), profile + " " + " ".join([value] * 7))

    def test_unknown_profile_falls_back(self):
        result = self.run_config(PROFILE="unknown")
        self.assertEqual(result.returncode, 0)
        self.assertIn("standard 1 1 1 1 0 0 1", result.stdout)
        self.assertIn("Unknown profile", result.stderr)

    def test_invalid_configuration(self):
        for key, value in [(f, "yes") for f in FLAGS] + [("INSTALL_CLAUDE", ""), ("TMUX_SESSION", "x;touch /tmp/unsafe"), ("TMUX_SESSION", ""), ("ENABLE_REBOOT_TMUX", "auto"), ("SWAP_SIZE_GB", "08"), ("SWAP_SIZE_GB", "0"), ("MIN_RAM_MB_FOR_NO_SWAP", "-1")]:
            with self.subTest(key=key, value=value):
                self.assertEqual(self.run_config(**{key: value}).returncode, 2)

    def test_source_has_no_effect(self):
        result = subprocess.run(["/bin/bash", "-c", 'source "$1"', "test", str(SCRIPT)], env={"PATH": "/nonexistent"}, capture_output=True)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b"")

    def test_dry_run_with_empty_path_and_scratch_home(self):
        with tempfile.TemporaryDirectory() as home:
            for profile in ["minimal", "standard", "full"]:
                result = subprocess.run(["/bin/bash", str(SCRIPT), "--dry-run"], env={"PATH": "/nonexistent", "HOME": home, "PROFILE": profile}, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("DRY RUN", result.stdout)
                self.assertEqual("Would install missing code-server" in result.stdout, profile == "full")
                self.assertEqual(list(Path(home).iterdir()), [])

    def test_mock_swap_detection(self):
        for output, status, expected in [("", 0, "0"), ("/swapfile file 1G 0B -2", 0, "1"), ("", 1, "")]:
            code = 'source "$1"; swapon() { printf "%s" "$MOCK_OUTPUT"; return "$MOCK_STATUS"; }; detect_swap'
            result = subprocess.run(["/bin/bash", "-c", code, "test", str(SCRIPT)], env={"PATH": "/nonexistent", "MOCK_OUTPUT": output, "MOCK_STATUS": str(status)}, capture_output=True, text=True)
            self.assertEqual(result.returncode, status)
            self.assertEqual(result.stdout, expected)

    def test_arguments_fail_before_bootstrap(self):
        for args in [["--unknown"], ["--dry-run", "extra"], [""]]:
            result = subprocess.run(["/bin/bash", str(SCRIPT), *args], env={"PATH": "/nonexistent"}, capture_output=True)
            self.assertEqual(result.returncode, 2)

if __name__ == "__main__":
    unittest.main()
