"""Checks for the gitleaks pre-commit hook in tools/git-hooks."""
import os
from pathlib import Path
import secrets
import shutil
import string
import subprocess
import tempfile
import unittest

HOOKS = Path(__file__).resolve().parent / 'git-hooks'
GITLEAKS = shutil.which('gitleaks') or str(Path.home() / '.local/bin/gitleaks')
IDENTITY = {
    'GIT_AUTHOR_NAME': 'Test', 'GIT_AUTHOR_EMAIL': 'test@example.com',
    'GIT_COMMITTER_NAME': 'Test', 'GIT_COMMITTER_EMAIL': 'test@example.com',
}


def fake_github_token() -> str:
    # Built at runtime so this file never contains a token-shaped literal.
    alphabet = string.ascii_letters + string.digits
    return 'gh' + 'p_' + ''.join(secrets.choice(alphabet) for _ in range(36))


class PreCommitHookTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(self.tmp.name) / 'repo'
        self.repo.mkdir()
        self.env = dict(os.environ, **IDENTITY, GIT_CONFIG_GLOBAL=os.devnull)
        self.git('init', '-q', '-b', 'main')
        self.git('config', 'core.hooksPath', str(HOOKS))

    def git(self, *args: str, env=None) -> subprocess.CompletedProcess:
        return subprocess.run(['git', *args], cwd=self.repo, env=env or self.env,
                              capture_output=True, text=True)

    def commit_file(self, name: str, content: str, env=None) -> subprocess.CompletedProcess:
        (self.repo / name).write_text(content)
        self.git('add', name)
        return self.git('commit', '-q', '-m', f'add {name}', env=env)

    @unittest.skipUnless(Path(GITLEAKS).exists(), 'gitleaks not installed')
    def test_clean_commit_is_allowed(self):
        result = self.commit_file('notes.txt', 'Just notes.\n')
        self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(Path(GITLEAKS).exists(), 'gitleaks not installed')
    def test_commit_with_secret_is_blocked_without_printing_it(self):
        token = fake_github_token()
        result = self.commit_file('config.py', f'GITHUB_TOKEN = "{token}"\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(token, result.stdout + result.stderr)
        self.assertIn('gitleaks', (result.stdout + result.stderr).lower())
        self.assertNotEqual(self.git('rev-parse', '-q', '--verify', 'HEAD').returncode, 0)

    def test_missing_gitleaks_blocks_the_commit(self):
        git_dir = str(Path(shutil.which('git')).parent)
        env = dict(self.env, PATH=f'{git_dir}:/usr/bin:/bin', HOME=self.tmp.name)
        result = self.commit_file('notes.txt', 'Just notes.\n', env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('gitleaks is not installed', result.stderr)


if __name__ == '__main__':
    unittest.main()
