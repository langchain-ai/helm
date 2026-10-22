#!/usr/bin/env python3

import importlib.util
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).with_name("check_version_bump_diff.py")
SPEC = importlib.util.spec_from_file_location("version_bump_guard", SCRIPT)
if not SPEC or not SPEC.loader:
    raise RuntimeError(f"could not load {SCRIPT}")
guard = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(guard)


class ValuesYamlDiffTests(unittest.TestCase):
    def test_dotted_key_cannot_hide_an_added_mapping_entry(self) -> None:
        old = {"config": {"endpoint": "https://api.smith.langchain.com"}}
        new = {
            "config.endpoint": "https://attacker.invalid",
            "config": {"endpoint": "https://api.smith.langchain.com"},
        }

        with patch.object(guard, "load_yaml_at", side_effect=[old, new]):
            problems = guard.check_values_yaml("base", "head", "charts/test/values.yaml")

        self.assertTrue(problems)

    def test_empty_mapping_addition_and_removal_are_rejected(self) -> None:
        for old, new in [
            ({"config": {}}, {"config": {}, "extra": {}}),
            ({"config": {}, "extra": {}}, {"config": {}}),
        ]:
            with self.subTest(old=old, new=new):
                with patch.object(guard, "load_yaml_at", side_effect=[old, new]):
                    problems = guard.check_values_yaml(
                        "base", "head", "charts/test/values.yaml"
                    )

                self.assertTrue(problems)

    def test_scalar_tag_cannot_become_a_sequence(self) -> None:
        old = {"images": {"backend": {"tag": "latest"}}}
        new = {"images": {"backend": {"tag": [{"injected": {"privileged": True}}]}}}

        with patch.object(guard, "load_yaml_at", side_effect=[old, new]):
            problems = guard.check_values_yaml("base", "head", "charts/test/values.yaml")

        self.assertTrue(problems)


class FileModeTests(unittest.TestCase):
    def test_only_regular_nonexecutable_files_are_allowed(self) -> None:
        self.assertEqual(guard.regular_file_problems("charts/demo/README.md", "100644", "100644"), [])
        for base_mode, head_mode in [
            ("100644", "120000"),
            ("120000", "100644"),
            ("100644", "100755"),
            ("100644", "160000"),
        ]:
            with self.subTest(base_mode=base_mode, head_mode=head_mode):
                self.assertTrue(
                    guard.regular_file_problems("charts/demo/README.md", base_mode, head_mode)
                )


if __name__ == "__main__":
    unittest.main()
