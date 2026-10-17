#!/usr/bin/env python3
"""Supply MCP headers from the existing personal gcloud sign-in.

Used by Codex (http_headers_helper) and Claude Code (headersHelper) for the
Developer Knowledge server. Stdout contains a short-lived credential: invoke
only through those helpers, and never log its output or redirect it into the
project.

The personal identity is not stored in the repository. Values come from
LC_GCLOUD_CONFIGURATION, LC_GCLOUD_ACCOUNT and LC_GCLOUD_PROJECT, either in the
environment or in a KEY=VALUE file outside the project (default
~/.config/learning-corner/personal-gcloud.env, override with
LC_GCLOUD_SETTINGS). Environment values take precedence over the file.
"""

from dataclasses import dataclass
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from typing import Callable, Mapping, Optional

GCLOUD = '/usr/bin/gcloud'
TIMEOUT_SECONDS = 30
DEFAULT_SETTINGS = Path('~/.config/learning-corner/personal-gcloud.env')
SETTINGS_KEYS = ('LC_GCLOUD_CONFIGURATION', 'LC_GCLOUD_ACCOUNT', 'LC_GCLOUD_PROJECT')
DOCS_HINT = ('See the personal Google Cloud account section in '
             'docs/DEVELOPMENT_ENVIRONMENT.md.')

# Validation keeps every value from being read by gcloud as an extra flag.
PATTERNS = {
    'LC_GCLOUD_CONFIGURATION': re.compile(r'[a-z][a-z0-9-]*'),
    'LC_GCLOUD_ACCOUNT': re.compile(r'[A-Za-z0-9._%+][A-Za-z0-9._%+-]*@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+'),
    'LC_GCLOUD_PROJECT': re.compile(r'[a-z][a-z0-9-]{4,28}[a-z0-9]'),
}


class SettingsError(ValueError):
    """The personal gcloud identity is missing or malformed."""


@dataclass(frozen=True)
class GcloudSettings:
    configuration: str
    account: str
    project: str


def parse_settings_file(text: str) -> dict[str, str]:
    """Read shell-style KEY=VALUE lines, so the file can also be `source`d."""
    values = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        key, value = line.removeprefix('export ').split('=', 1)
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in '\'"':
            value = value[1:-1]
        values[key.strip()] = value
    return values


def load_settings(environ: Mapping[str, str]) -> GcloudSettings:
    path = Path(environ.get('LC_GCLOUD_SETTINGS') or DEFAULT_SETTINGS).expanduser()
    try:
        values = parse_settings_file(path.read_text())
    except FileNotFoundError:
        values = {}
    except OSError as error:
        raise SettingsError(f'Cannot read {path}: {error.strerror}') from error
    values.update({key: environ[key] for key in SETTINGS_KEYS if key in environ})

    missing = [key for key in SETTINGS_KEYS if key not in values]
    if missing:
        raise SettingsError(f'Missing {", ".join(missing)} (checked environment and {path}).')
    for key in SETTINGS_KEYS:
        if not PATTERNS[key].fullmatch(values[key]):
            raise SettingsError(f'{key} is not a valid value.')
    return GcloudSettings(
        configuration=values['LC_GCLOUD_CONFIGURATION'],
        account=values['LC_GCLOUD_ACCOUNT'],
        project=values['LC_GCLOUD_PROJECT'],
    )


def token_command(settings: GcloudSettings) -> list[str]:
    return [
        GCLOUD,
        'auth',
        'print-access-token',
        f'--configuration={settings.configuration}',
        f'--account={settings.account}',
        f'--project={settings.project}',
        '--quiet',
    ]


def main(environ: Optional[Mapping[str, str]] = None,
         run: Callable[..., subprocess.CompletedProcess] = subprocess.run) -> int:
    try:
        settings = load_settings(os.environ if environ is None else environ)
    except SettingsError as error:
        print(f'Personal Google settings unavailable: {error} {DOCS_HINT}', file=sys.stderr)
        return 1
    try:
        result = run(
            token_command(settings),
            capture_output=True,
            text=True,
            timeout=TIMEOUT_SECONDS,
            check=True,
        )
        token = result.stdout.strip()
        if not token:
            raise ValueError('Empty access token')
    except (OSError, subprocess.SubprocessError, ValueError):
        print(f'Personal Google authentication failed. {DOCS_HINT}', file=sys.stderr)
        return 1
    print(json.dumps({
        'Authorization': 'Bearer ' + token,
        'X-Goog-User-Project': settings.project,
    }))
    return 0


if __name__ == '__main__':
    sys.exit(main())
