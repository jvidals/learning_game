"""Offline checks for the Developer Knowledge MCP header helper."""
import contextlib
import io
import json
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from unittest.mock import Mock

import google_knowledge_headers as helper

SETTINGS_TEXT = """\
# Personal gcloud identity for development-only cloud tools.
export LC_GCLOUD_CONFIGURATION=personal
LC_GCLOUD_ACCOUNT="someone@example.com"
LC_GCLOUD_PROJECT='example-project-123'
"""


def completed(stdout: str) -> subprocess.CompletedProcess:
    return subprocess.CompletedProcess(args=[], returncode=0, stdout=stdout, stderr='')


class HeaderHelperTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.settings_path = Path(self.tmp.name) / 'personal-gcloud.env'
        self.settings_path.write_text(SETTINGS_TEXT)
        self.environ = {'LC_GCLOUD_SETTINGS': str(self.settings_path)}

    def run_main(self, environ, run):
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            code = helper.main(environ=environ, run=run)
        return code, stdout.getvalue(), stderr.getvalue()

    def test_settings_file_supplies_explicit_gcloud_flags(self):
        settings = helper.load_settings(self.environ)
        self.assertEqual(settings, helper.GcloudSettings(
            configuration='personal',
            account='someone@example.com',
            project='example-project-123',
        ))
        command = helper.token_command(settings)
        self.assertEqual(command[:3], [helper.GCLOUD, 'auth', 'print-access-token'])
        self.assertIn('--configuration=personal', command)
        self.assertIn('--account=someone@example.com', command)
        self.assertIn('--project=example-project-123', command)

    def test_environment_variables_override_the_settings_file(self):
        environ = dict(self.environ, LC_GCLOUD_PROJECT='other-project-456')
        settings = helper.load_settings(environ)
        self.assertEqual(settings.project, 'other-project-456')
        self.assertEqual(settings.account, 'someone@example.com')

    def test_environment_alone_works_without_a_settings_file(self):
        environ = {
            'LC_GCLOUD_SETTINGS': str(Path(self.tmp.name) / 'missing.env'),
            'LC_GCLOUD_CONFIGURATION': 'personal',
            'LC_GCLOUD_ACCOUNT': 'someone@example.com',
            'LC_GCLOUD_PROJECT': 'example-project-123',
        }
        self.assertEqual(helper.load_settings(environ).configuration, 'personal')

    def test_missing_settings_fail_without_calling_gcloud(self):
        run = Mock()
        environ = {'LC_GCLOUD_SETTINGS': str(Path(self.tmp.name) / 'missing.env')}
        code, out, err = self.run_main(environ, run)
        self.assertEqual(code, 1)
        self.assertEqual(out, '')
        self.assertIn('LC_GCLOUD_ACCOUNT', err)
        run.assert_not_called()

    def test_invalid_values_are_rejected(self):
        bad_values = {
            'LC_GCLOUD_ACCOUNT': ['not-an-email', '--impersonate@x.com', 'a b@example.com'],
            'LC_GCLOUD_PROJECT': ['Upper-Case', '-flag-like', 'short', 'ends-with-'],
            'LC_GCLOUD_CONFIGURATION': ['--all', 'Has Space', ''],
        }
        for key, values in bad_values.items():
            for value in values:
                with self.subTest(key=key, value=value):
                    with self.assertRaises(helper.SettingsError):
                        helper.load_settings(dict(self.environ, **{key: value}))

    def test_success_prints_only_the_headers(self):
        run = Mock(return_value=completed('ya29.token\n'))
        code, out, err = self.run_main(self.environ, run)
        self.assertEqual(code, 0)
        self.assertEqual(err, '')
        self.assertEqual(json.loads(out), {
            'Authorization': 'Bearer ya29.token',
            'X-Goog-User-Project': 'example-project-123',
        })
        self.assertEqual(run.call_args.kwargs['timeout'], helper.TIMEOUT_SECONDS)
        self.assertTrue(run.call_args.kwargs['check'])

    def test_gcloud_failures_never_print_to_stdout(self):
        failures = [
            subprocess.CalledProcessError(1, ['gcloud'], stderr='expired'),
            subprocess.TimeoutExpired(['gcloud'], helper.TIMEOUT_SECONDS),
            FileNotFoundError('gcloud'),
        ]
        for failure in failures:
            with self.subTest(failure=type(failure).__name__):
                code, out, err = self.run_main(self.environ, Mock(side_effect=failure))
                self.assertEqual(code, 1)
                self.assertEqual(out, '')
                self.assertIn('authentication failed', err)

    def test_empty_token_is_a_failure(self):
        code, out, _ = self.run_main(self.environ, Mock(return_value=completed('  \n')))
        self.assertEqual(code, 1)
        self.assertEqual(out, '')

    def test_source_contains_no_personal_identity(self):
        source = Path(helper.__file__).read_text()
        self.assertIsNone(re.search(r'[\w.+-]+@[\w-]+\.[\w.]+', source))


if __name__ == '__main__':
    unittest.main()
