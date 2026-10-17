#!/usr/bin/env python3
"""Generate offline WAVs with Google Cloud TTS (Python standard library only).

Normal APK builds never call this tool. Run --dry-run first to inspect cost.
Each successful clip is checkpointed; unchanged, verified files are reused.
Credentials remain in gcloud; account/project flags never activate a config.
"""
import argparse
import array
import itertools
import base64
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
import wave
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
PHRASES = ROOT / 'assets/audio_phrases.json'
MANIFEST = ROOT / 'assets/audio_manifest.json'
DESTINATION = ROOT / 'assets/audio'
VOICE = {'languageCode': 'en-US', 'name': 'en-US-Chirp3-HD-Puck'}
AUDIO = {'audioEncoding': 'LINEAR16', 'speakingRate': 0.9, 'sampleRateHertz': 24000}


TARGET_PAUSE_MS = 400

# US English basic code. c and k share sound_k; q/x are not single phonemes.
PHONEMES = dict(zip(
    'abdefghijklmnoprstuvwyz',
    ['æ', 'b', 'd', 'ɛ', 'f', 'ɡ', 'h', 'ɪ', 'dʒ', 'k', 'l', 'm', 'n',
     'ɑ', 'p', 'ɹ', 's', 't', 'ʌ', 'v', 'w', 'j', 'z']))


PHONEME_WORDS = dict(zip(PHONEMES, [
    'apple', 'ball', 'dog', 'egg', 'fish', 'goat', 'hat', 'insect', 'jet',
    'kite', 'leaf', 'moon', 'nose', 'octopus', 'pig', 'rabbit', 'sun',
    'turtle', 'umbrella', 'van', 'web', 'yarn', 'zebra']))
PHONEME_CUES = dict(zip(PHONEMES, [
    'a', 'b', 'd', 'e', 'ffff', 'g', 'h', 'i', 'j', 'k', 'llll', 'mmmmmm',
    'nnnn', 'o', 'p', 'rrrr', 'ssssss', 't', 'u', 'vvvv', 'w', 'y', 'zzzz']))
PHONEME_VOICE = {'languageCode': 'en-US', 'name': 'Puck',
                 'modelName': 'gemini-2.5-flash-tts'}
PHONEME_AUDIO = {'audioEncoding': 'LINEAR16', 'sampleRateHertz': 24000}
# Whole CVC words for the reading games (no carrier phrase, no target pause).
WORD_PROCESSING = 'isolated-word-v1'
SHORT_VOWEL_WORDS = {'a': 'cat', 'e': 'bed', 'i': 'pig', 'o': 'dog', 'u': 'sun'}


def ipa_for(spelling):
    """Decodable short-vowel spelling to IPA: c is /k/, x is /ks/."""
    return ''.join('ks' if letter == 'x' else PHONEMES['k' if letter == 'c' else letter]
                   for letter in spelling)


def nonsense_request(spelling):
    # Plain TTS turns made-up words into nearby real words or letter names.
    # Direct the phonics model with IPA and the short-vowel reference word.
    vowel = spelling[1]
    prompt = (
        'You are a skilled American English phonics teacher recording one made-up '
        'word for a kindergarten decoding exercise. Say the word exactly once, as a '
        f'single smooth syllable, clearly and at a calm natural pace: /{ipa_for(spelling)}/. '
        f'The vowel is the short {vowel} sound as in {SHORT_VOWEL_WORDS[vowel]}. '
        'It is a pretend word, not a real word: do not change it into a similar '
        'real word, do not spell it, do not say letter names, and do not speak any '
        'other words or instructions. No "uh" after the final consonant.')
    return {'input': {'prompt': prompt, 'text': spelling},
            'voice': dict(PHONEME_VOICE, modelName='gemini-2.5-pro-tts'),
            'audioConfig': PHONEME_AUDIO}


def is_isolated_word(clip):
    return re.fullmatch(r'(cvc|nonsense)_[a-z]{3}', clip) is not None


def phoneme_request(sound):
    # Single-letter SSML phoneme requests yielded alphabet names in Chirp and
    # Neural2. Use a phonics-directed model; keep all existing prompts unchanged.
    prompt = (
        'You are a skilled American English phonics teacher recording one isolated '
        'speech sound for a kindergarten blending exercise. Produce ONLY the '
        f'initial phoneme /{PHONEMES[sound]}/ as in {PHONEME_WORDS[sound]}. '
        'The text is a phonetic cue, not a letter name. Do not say the letter name '
        'or example word, and do not speak any instructions. No extra vowel or '
        '"uh" before or after consonants. Sustain continuous sounds for about '
        'half a second; stop consonants are a single crisp release. Vowels are '
        'short vowel sounds, not alphabet names. One sound only, no repetitions.')
    if sound in 'bdgjkpt':
        prompt += (' Keep the release very short and clipped. Do not sustain '
                   'voicing after the release; avoid turning it into a syllable.')
    voice = PHONEME_VOICE
    if sound in 'bdghjkptw':
        voice = dict(PHONEME_VOICE, modelName='gemini-2.5-pro-tts')
        prompt += (' This is a pure-sounds phonics recording, not letter naming. '
                   'End immediately when the mouth releases the consonant, '
                   'before an uh vowel. A tiny sound is correct; do not fill the silence.')
    if sound == 'h':
        prompt += ' Make one soft, continuous unvoiced breath, with no vocal-cord vibration.'
    return {'input': {'prompt': prompt, 'text': PHONEME_CUES[sound]},
            'voice': voice, 'audioConfig': PHONEME_AUDIO}


def request_for(clip, phrase):
    letter = re.fullmatch(r'(upper|lower)_([a-z])', clip)
    number = re.fullmatch(r'number_(\d+)', clip)
    word = re.fullmatch(r'word_([a-z]+)', clip)
    if clip.startswith('sound_'):
        return phoneme_request(clip.removeprefix('sound_'))
    elif clip.startswith('nonsense_'):
        return nonsense_request(clip.removeprefix('nonsense_'))
    elif clip.startswith('cvc_'):
        source = {'text': f"{clip.removeprefix('cvc_')}."}
    elif word:
        target = 'I' if word[1] == 'i' else word[1]
        prefix, suffix = phrase.rsplit(target, 1)
        source = {'ssml': f'<speak>{escape(prefix.rstrip(" ,"))}'
                  f'<break time="{TARGET_PAUSE_MS}ms"/>{escape(target)}{escape(suffix)}</speak>'}
    elif letter or number:
        target = letter[2].upper() if letter else number[1]
        pronunciation = 'characters' if letter else 'cardinal'
        prefix, suffix = phrase.rsplit(target, 1)
        # Replace punctuation-based pacing with an explicit target pause.
        prefix = prefix.rstrip(' ,')
        source = {'ssml': f'<speak>{escape(prefix)}<break time="{TARGET_PAUSE_MS}ms"/>'
                  f'<say-as interpret-as="{pronunciation}">{target}</say-as>{escape(suffix)}</speak>'}
    else:
        source = {'text': phrase}
    return {'input': source, 'voice': VOICE, 'audioConfig': AUDIO}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def valid_wav(data):
    with wave.open(io.BytesIO(data), 'rb') as wav:
        if wav.getnchannels() != 1 or wav.getsampwidth() != 2 or wav.getframerate() != 24000:
            raise ValueError('Expected mono 16-bit PCM at 24 kHz')
        frames = wav.readframes(wav.getnframes())
        if len(frames) != wav.getnframes() * 2 or len(frames) < 4800 or not any(frames):
            raise ValueError('Missing or truncated audio samples')


def valid_phoneme(data):
    valid_wav(data)
    with wave.open(io.BytesIO(data), 'rb') as wav:
        duration = wav.getnframes() / wav.getframerate()
    if duration > 3:
        raise ValueError('Phoneme exceeds three seconds; regenerate and review, never truncate speech.')


def normalize_target_pause(data):
    """Keep the target gap at 400 ms, retaining quiet edges to protect onsets.

    Chirp can render a requested break much longer than specified. Only the
    longest interior quiet interval is adjusted; samples outside it are retained.
    Reject missing breaks rather than shipping a rushed target.
    """
    with wave.open(io.BytesIO(data), 'rb') as wav:
        rate = wav.getframerate()
        samples = array.array('h', wav.readframes(wav.getnframes()))
    if sys.byteorder != 'little':
        samples.byteswap()
    # Ten-millisecond RMS windows ignore isolated noise spikes. Merge only
    # tiny interruptions (<=30 ms) between substantial quiet spans (>=80 ms).
    block = rate // 100
    quiet = [sum(v * v for v in samples[i:i + block]) <= 327 ** 2 * len(samples[i:i + block])
             for i in range(0, len(samples), block)]
    spans = []
    start = 0
    for silent, values in itertools.groupby(quiet):
        length = sum(1 for _ in values)
        if silent and length >= 8:
            if spans and start - spans[-1][1] <= 3:
                spans[-1] = (spans[-1][0], start + length)
            else:
                spans.append((start, start + length))
        start += length
    gaps = [(start * block, (end - start) * block) for start, end in spans
            if start > 0 and end < len(quiet) and end - start >= 25]
    if not gaps:
        raise ValueError('No clear interior target pause found; regenerate this clip.')
    start, length = max(gaps, key=lambda gap: gap[1])
    desired = rate * TARGET_PAUSE_MS // 1000
    # Keep 50 ms at both quiet edges, including any low-level consonant onset.
    edge = min(rate // 20, length // 2)
    normalized = samples[:start + edge] + array.array('h', [0]) * (desired - 2 * edge) + samples[start + length - edge:]
    if sys.byteorder != 'little':
        normalized.byteswap()
    stream = io.BytesIO()
    with wave.open(stream, 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(normalized.tobytes())
    return stream.getvalue()


def normalize_phoneme(data):
    """Sound-only assets: explicit 400 ms lead-in, no interior word-gap surgery."""
    with wave.open(io.BytesIO(data), 'rb') as wav:
        samples = array.array('h', wav.readframes(wav.getnframes()))
        rate = wav.getframerate()
    if sys.byteorder != 'little':
        samples.byteswap()
    active = [i for i, value in enumerate(samples) if abs(value) > 100]
    if not active:
        raise ValueError('No audible phoneme')
    # Preserve quiet consonant onsets and release tails. Never cut into the sound.
    begin = max(0, active[0] - rate // 20)
    end = min(len(samples), active[-1] + rate // 10)
    samples = array.array('h', [0]) * (rate * TARGET_PAUSE_MS // 1000) + samples[begin:end]
    samples.extend([0] * (rate // 5))
    if sys.byteorder != 'little':
        samples.byteswap()
    stream = io.BytesIO()
    with wave.open(stream, 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(samples.tobytes())
    return stream.getvalue()


def shorten_sustained_l(data):
    """Authoring-only duration control for a held lateral, never for stop sounds.

    Gemini can sustain L for many seconds despite a half-second instruction.
    Retain the onset plus 700 ms, fade the final 20 ms, and restore the tail.
    This is recorded separately in the manifest and requires listening review.
    """
    with wave.open(io.BytesIO(data), 'rb') as wav:
        rate = wav.getframerate()
        samples = array.array('h', wav.readframes(wav.getnframes()))
    if sys.byteorder != 'little':
        samples.byteswap()
    # The input already has the protected leading silence from normalize_phoneme.
    active = next((i for i, value in enumerate(samples) if abs(value) > 500), None)
    if active is None:
        raise ValueError('No audible lateral sound')
    end = min(len(samples), active + rate * 700 // 1000)
    samples = samples[:end]
    fade = rate * 20 // 1000
    for i in range(fade):
        samples[end - fade + i] = round(samples[end - fade + i] * (fade - i - 1) / fade)
    samples.extend([0] * (rate // 5))
    if sys.byteorder != 'little':
        samples.byteswap()
    stream = io.BytesIO()
    with wave.open(stream, 'wb') as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(rate)
        wav.writeframes(samples.tobytes())
    return stream.getvalue()


def atomic_write(path, data):
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_bytes(data)
    temporary.replace(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', help='Explicit billing/quota project')
    parser.add_argument('--account', help='Saved gcloud account to use')
    parser.add_argument('--configuration', default='personal')
    parser.add_argument('--dry-run', action='store_true', help='No credentials or network access')
    parser.add_argument('--verify', action='store_true', help='Verify the complete bundle offline')
    parser.add_argument('--clips', nargs='+', help='Generate just these clip IDs')
    args = parser.parse_args()
    phrases = json.loads(PHRASES.read_text())
    manifest = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    selected = args.clips or list(phrases)
    pending = []
    for clip in selected:
        if clip not in phrases or not re.fullmatch('[a-z0-9_]+', clip):
            parser.error(f'Unknown clip: {clip}')
        request = request_for(clip, phrases[clip])
        request_hash = digest(json.dumps(request, sort_keys=True).encode())
        target = DESTINATION / f'{clip}.wav'
        entry = manifest.get(clip, {})
        is_target = clip.startswith(('upper_', 'lower_', 'number_', 'word_'))
        processed = (entry.get('processing') == ('phonics-directed-l-v3' if clip == 'sound_l' else 'phonics-directed-v2') if clip.startswith('sound_')
                     else entry.get('processing') == WORD_PROCESSING if is_isolated_word(clip)
                     else not is_target or entry.get('processing') == 'target-pause-v2')
        if target.exists() and entry.get('request_sha256') == request_hash and processed:
            data = target.read_bytes()
            if digest(data) == entry.get('audio_sha256'):
                if clip.startswith('sound_') or is_isolated_word(clip):
                    valid_phoneme(data)
                else:
                    valid_wav(data)
                continue
        pending.append((clip, request, request_hash))
    phonics_count = sum(clip.startswith(('sound_', 'nonsense_')) for clip, _, _ in pending)
    characters = sum(len(next(iter(req['input'].values()))) for clip, req, _ in pending
                     if not clip.startswith(('sound_', 'nonsense_')))
    print(f'{len(selected) - len(pending)} verified; {len(pending)} to generate. '
          f'Chirp: up to {characters} input characters; '
          f'${characters * 30 / 1_000_000:.4f} at $30/million before allowances/retries. '
          f'Phonics: {phonics_count} Gemini TTS clips, billed by input/output tokens.', flush=True)
    if args.verify:
        if pending:
            raise SystemExit('Bundle incomplete or stale: ' + ', '.join(c for c, _, _ in pending))
        return
    if args.dry_run or not pending:
        return
    if not args.project or not args.account:
        parser.error('Generation requires explicit --project and --account flags.')
    command = ['gcloud', f'--configuration={args.configuration}', f'--account={args.account}',
               f'--project={args.project}', 'auth', 'print-access-token']
    # Capture rather than printing tokens or command stdout.
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode:
        raise SystemExit('gcloud sign-in failed. Refresh the selected account with '
                         '`gcloud auth login ACCOUNT --no-activate`, then rerun.')
    token = result.stdout.strip()
    DESTINATION.mkdir(parents=True, exist_ok=True)
    for index, (clip, payload, request_hash) in enumerate(pending, 1):
        request = urllib.request.Request('https://texttospeech.googleapis.com/v1/text:synthesize',
            data=json.dumps(payload).encode(), headers={'Authorization': f'Bearer {token}',
            'x-goog-user-project': args.project, 'Content-Type': 'application/json'})
        for attempt in range(3):
            try:
                with urllib.request.urlopen(request, timeout=60) as response:
                    data = base64.b64decode(json.load(response)['audioContent'], validate=True)
                if clip.startswith('sound_'):
                    data = normalize_phoneme(data)
                    if clip == 'sound_l':
                        data = shorten_sustained_l(data)
                    valid_phoneme(data)
                elif is_isolated_word(clip):
                    data = normalize_phoneme(data)
                    valid_phoneme(data)
                valid_wav(data)
                if clip.startswith(('upper_', 'lower_', 'number_', 'word_')):
                    data = normalize_target_pause(data)
                break
            except urllib.error.HTTPError as error:
                if error.code not in (429, 500, 502, 503, 504) or attempt == 2:
                    detail = error.read().decode(errors='replace')
                    raise SystemExit(f'{clip}: HTTP {error.code}: {detail}') from None
                time.sleep(2 ** (attempt + 1))
        atomic_write(DESTINATION / f'{clip}.wav', data)
        manifest[clip] = {'request_sha256': request_hash, 'audio_sha256': digest(data),
                          'voice': payload['voice']['name'],
                          'speaking_rate': payload['audioConfig'].get('speakingRate', 1.0)}
        if clip.startswith('sound_'):
            manifest[clip]['processing'] = ('phonics-directed-l-v3' if clip == 'sound_l' else 'phonics-directed-v2')
            manifest[clip]['model'] = payload['voice']['modelName']
        if is_isolated_word(clip):
            manifest[clip]['processing'] = WORD_PROCESSING
            if 'modelName' in payload['voice']:
                manifest[clip]['model'] = payload['voice']['modelName']
        if clip.startswith(('upper_', 'lower_', 'number_', 'word_')):
            manifest[clip]['processing'] = 'target-pause-v2'
        atomic_write(MANIFEST, (json.dumps(manifest, indent=2, sort_keys=True) + '\n').encode())
        print(f'[{index}/{len(pending)}] {clip}', flush=True)
    print('Bundled voice generation complete.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError) as error:
        sys.exit(f'Generation stopped; completed clips can be resumed: {error}')
