"""Checks for the Git working-tree snapshot helper used around Codex workers."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parent / 'git_snapshot.sh'
IDENTITY = {
    'GIT_AUTHOR_NAME': 'Test', 'GIT_AUTHOR_EMAIL': 'test@example.com',
    'GIT_COMMITTER_NAME': 'Test', 'GIT_COMMITTER_EMAIL': 'test@example.com',
}


class GitSnapshotTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(self.tmp.name)
        self.env = dict(os.environ, **IDENTITY, GIT_CONFIG_GLOBAL=os.devnull)
        self.git('init', '-q', '-b', 'main')
        (self.repo / '.gitignore').write_text('ignored/\n')
        (self.repo / 'kept.txt').write_text('original\n')
        (self.repo / 'removed.txt').write_text('soon gone\n')
        self.git('add', '-A')
        self.git('commit', '-q', '-m', 'base')

    def git(self, *args: str) -> str:
        return subprocess.run(['git', *args], cwd=self.repo, env=self.env,
                              check=True, capture_output=True, text=True).stdout

    def snapshot(self, label: str) -> subprocess.CompletedProcess:
        return subprocess.run([str(SCRIPT), label], cwd=self.repo, env=self.env,
                              capture_output=True, text=True)

    def test_records_working_tree_without_touching_branch_index_or_files(self):
        (self.repo / 'kept.txt').write_text('lead edit in progress\n')
        (self.repo / 'new.txt').write_text('untracked work\n')
        (self.repo / 'ignored').mkdir()
        (self.repo / 'ignored' / 'big.bin').write_text('excluded\n')
        self.git('add', 'kept.txt')
        before = (self.git('rev-parse', 'HEAD'), self.git('status', '--porcelain'),
                  self.git('diff', '--cached'))

        result = self.snapshot('task-before')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), 'refs/snapshots/task-before')
        self.assertEqual(before, (self.git('rev-parse', 'HEAD'), self.git('status', '--porcelain'),
                                  self.git('diff', '--cached')))
        self.assertEqual(self.git('show', 'refs/snapshots/task-before:kept.txt'),
                         'lead edit in progress\n')
        self.assertEqual(self.git('show', 'refs/snapshots/task-before:new.txt'), 'untracked work\n')
        files = self.git('ls-tree', '-r', '--name-only', 'refs/snapshots/task-before').split()
        self.assertNotIn('ignored/big.bin', files)
        self.assertEqual(self.git('rev-parse', 'refs/snapshots/task-before^'),
                         self.git('rev-parse', 'HEAD'))

    def test_before_and_after_snapshots_show_exact_worker_changes(self):
        self.assertEqual(self.snapshot('w-before').returncode, 0)
        (self.repo / 'kept.txt').write_text('worker edit\n')
        (self.repo / 'removed.txt').unlink()
        (self.repo / 'added.txt').write_text('worker file\n')
        self.assertEqual(self.snapshot('w-after').returncode, 0)

        changes = self.git('diff', '--name-status', 'refs/snapshots/w-before',
                           'refs/snapshots/w-after').splitlines()
        self.assertEqual(sorted(changes), ['A\tadded.txt', 'D\tremoved.txt', 'M\tkept.txt'])

    def test_existing_label_is_never_overwritten(self):
        self.assertEqual(self.snapshot('once').returncode, 0)
        first = self.git('rev-parse', 'refs/snapshots/once')
        (self.repo / 'kept.txt').write_text('changed\n')
        result = self.snapshot('once')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.git('rev-parse', 'refs/snapshots/once'), first)

    def test_rejects_unsafe_or_missing_labels(self):
        for label in ['', '../heads/main', 'has space', '-flag', 'a..b']:
            with self.subTest(label=label):
                self.assertEqual(self.snapshot(label).returncode, 2)
        self.assertEqual(self.git('for-each-ref', 'refs/snapshots'), '')

    def test_fails_outside_a_repository(self):
        with tempfile.TemporaryDirectory() as outside:
            result = subprocess.run([str(SCRIPT), 'label'], cwd=outside, env=self.env,
                                    capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)


if __name__ == '__main__':
    unittest.main()
