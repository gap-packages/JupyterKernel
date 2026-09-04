import os
import unittest
from unittest.mock import patch

from gap_jupyter_kernel.__main__ import _find_gap


class LauncherTests(unittest.TestCase):
    @patch.dict(os.environ, {"GAP": "gap --quitonbreak"}, clear=True)
    @patch("gap_jupyter_kernel.__main__.shutil.which", return_value="/usr/bin/gap")
    def test_gap_command_environment_does_not_shadow_path(self, which):
        self.assertEqual(_find_gap(), "/usr/bin/gap")
        which.assert_called_once_with("gap")

    @patch.dict(
        os.environ,
        {"JUPYTER_GAP_EXECUTABLE": "/opt/gap/bin/gap"},
        clear=True,
    )
    @patch("gap_jupyter_kernel.__main__.shutil.which")
    def test_explicit_executable_override_takes_precedence(self, which):
        self.assertEqual(_find_gap(), "/opt/gap/bin/gap")
        which.assert_not_called()
