"""Offline checks for the development-only speech generator."""
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import wave

import generate_audio as generator


def samples():
    stream = io.BytesIO()
    with wave.open(stream, 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(24000)
        wav.writeframes(b'\x00\x10' * 4800)
    return stream.getvalue()


class GeneratorTests(unittest.TestCase):
    def test_letter_case_wording_and_matching_directions(self):
        phrases = json.loads(generator.PHRASES.read_text())
        for letter in 'abcdefghijklmnopqrstuvwxyz':
            for prefix, case in [('upper', 'uppercase'), ('lower', 'lowercase')]:
                phrase = phrases[f'{prefix}_{letter}']
                self.assertEqual(phrase, f'Find the {case} letter, {letter.upper()}.')
        self.assertEqual(phrases['match_lower'],
                         'Find the lowercase letter that matches this uppercase letter.')
        self.assertEqual(phrases['match_upper'],
                         'Find the uppercase letter that matches this lowercase letter.')

    def test_letter_names_are_explicit_and_phrase_edits_change_request(self):
        original = generator.request_for('upper_a', 'Find the uppercase letter, A.')
        changed = generator.request_for('upper_a', 'Please find A & smile.')
        self.assertIn('<say-as interpret-as="characters">A</say-as>', original['input']['ssml'])
        self.assertIn('&amp;', changed['input']['ssml'])
        self.assertNotEqual(original, changed)
        self.assertIn('<break time="400ms"/><say-as interpret-as="cardinal">100</say-as>',
                      generator.request_for('number_100', 'Find the number, 100.')['input']['ssml'])

    def test_all_targets_have_one_pause_immediately_before_the_target(self):
        from xml.etree import ElementTree
        phrases = json.loads(generator.PHRASES.read_text())
        changed = 0
        for clip, phrase in phrases.items():
            source = generator.request_for(clip, phrase)['input']
            if clip.startswith(('upper_', 'lower_', 'number_')):
                xml = ElementTree.fromstring(source['ssml'])
                self.assertEqual([child.tag for child in xml], ['break', 'say-as'])
                self.assertEqual(xml[0].attrib, {'time': '400ms'})
                self.assertFalse(xml.text.endswith(','))
                self.assertEqual(xml[1].text, clip.split('_')[1].upper())
                changed += 1
            elif clip.startswith('word_'):
                xml = ElementTree.fromstring(source['ssml'])
                self.assertEqual([child.tag for child in xml], ['break'])
                self.assertEqual(xml[0].attrib, {'time': '400ms'})
                word = 'I' if clip == 'word_i' else clip[5:]
                self.assertEqual(xml[0].tail, word + '.')
                self.assertEqual(xml.text, 'Find the word')
            elif clip.startswith('sound_'):
                self.assertNotIn('ssml', source)
                self.assertIn(f'/{generator.PHONEMES[clip[6:]]}/', source['prompt'])
            elif clip.startswith('cvc_'):
                self.assertEqual(source, {'text': phrase + '.'})
            elif clip.startswith('nonsense_'):
                self.assertEqual(source['text'], phrase)
                self.assertIn(f'/{generator.ipa_for(phrase)}/', source['prompt'])
            else:
                self.assertEqual(source, {'text': phrase})
        self.assertEqual(changed, 153)

    def test_word_prompts_preserve_whole_word_pronunciation_and_case(self):
        phrases = json.loads(generator.PHRASES.read_text())
        words = {clip: phrase for clip, phrase in phrases.items() if clip.startswith('word_')}
        self.assertEqual(len(words), 43)
        for clip, phrase in words.items():
            target = 'I' if clip == 'word_i' else clip[5:]
            self.assertEqual(phrase, f'Find the word, {target}.')
            source = generator.request_for(clip, phrase)['input']['ssml']
            self.assertEqual(source, f'<speak>Find the word<break time="400ms"/>{target}.</speak>')
            self.assertNotIn('say-as', source)

    def test_pause_normalization_preserves_speech_and_sets_the_interior_gap(self):
        for gap_ms in [300, 500, 1500]:
            speech = b'\x00\x10' * 12000
            source = io.BytesIO()
            with wave.open(source, 'wb') as wav:
                wav.setnchannels(1)
                wav.setsampwidth(2)
                wav.setframerate(24000)
                wav.writeframes(speech + b'\x00\x00' * (24 * gap_ms) + speech)
            result = generator.normalize_target_pause(source.getvalue())
            with wave.open(io.BytesIO(result)) as wav:
                frames = wav.readframes(wav.getnframes())
            self.assertEqual(frames, speech + b'\x00\x00' * 9600 + speech)
        # Isolated clicks inside a long pause must not split the target gap.
        noisy = bytearray(speech + b'\x00\x00' * 24000 + speech)
        noisy[36000:36480] = b'\xff\x7f' * 240
        source = io.BytesIO()
        with wave.open(source, 'wb') as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(24000)
            wav.writeframes(noisy)
        with wave.open(io.BytesIO(generator.normalize_target_pause(source.getvalue()))) as wav:
            self.assertEqual(wav.getnframes(), 12000 + 9600 + 12000)
        with self.assertRaisesRegex(ValueError, 'No clear interior'):
            generator.normalize_target_pause(samples())

    def test_rejects_truncated_or_non_wav_audio(self):
        data = samples()
        generator.valid_wav(data)
        with self.assertRaises(ValueError):
            generator.valid_wav(data[:-200])
        with self.assertRaises((wave.Error, EOFError)):
            generator.valid_wav(b'not audio')

    def test_verified_audio_is_reused_without_authentication_and_corruption_is_detected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            phrase = 'Find the number, 100.'
            request = generator.request_for('number_100', phrase)
            data = samples()
            (root / 'number_100.wav').write_bytes(data)
            (root / 'phrases.json').write_text(json.dumps({'number_100': phrase}))
            entry = {'number_100': {
                'request_sha256': generator.digest(json.dumps(request, sort_keys=True).encode()),
                'audio_sha256': generator.digest(data), 'processing': 'target-pause-v2'}}
            (root / 'manifest.json').write_text(json.dumps(entry))
            with patch.object(generator, 'PHRASES', root / 'phrases.json'), \
                 patch.object(generator, 'MANIFEST', root / 'manifest.json'), \
                 patch.object(generator, 'DESTINATION', root), \
                 patch.object(generator.subprocess, 'run') as auth, \
                 patch.object(generator.urllib.request, 'urlopen') as network, \
                 patch('sys.argv', ['generate_audio.py', '--verify']):
                generator.main()
                auth.assert_not_called()
                network.assert_not_called()
                (root / 'number_100.wav').write_bytes(data[:-200])
                with self.assertRaisesRegex(SystemExit, 'incomplete or stale'):
                    generator.main()
                auth.assert_not_called()
                network.assert_not_called()

    def test_reading_game_words_are_isolated_and_nonsense_is_phonics_directed(self):
        real = generator.request_for('cvc_six', 'six')
        self.assertEqual(real['input'], {'text': 'six.'})
        self.assertEqual(real['voice'], generator.VOICE)
        fake = generator.request_for('nonsense_koz', 'koz')
        self.assertEqual(fake['input']['text'], 'koz')
        self.assertIn('/kɑz/', fake['input']['prompt'])
        self.assertIn('as in dog', fake['input']['prompt'])
        self.assertEqual(fake['voice']['modelName'], 'gemini-2.5-pro-tts')
        self.assertEqual(generator.ipa_for('fox'), 'fɑks')
        self.assertEqual(generator.ipa_for('cat'), 'kæt')
        self.assertTrue(generator.is_isolated_word('nonsense_pib'))
        self.assertFalse(generator.is_isolated_word('word_the'))

    def test_bundled_reading_words_match_the_word_bank(self):
        import re
        root = Path(generator.__file__).resolve().parents[1]
        bank = (root / 'lib/word_bank.dart').read_text()
        phrases = json.loads((root / 'assets/audio_phrases.json').read_text())
        real = re.findall(r"DecodableWord\('([a-z]{3})', picture:", bank)
        fake = {w for item in re.findall(
            r"MakeBelieveItem\('([a-z]{3})', \['([a-z]{3})', '([a-z]{3})'\]\)", bank) for w in item}
        self.assertEqual({k for k in phrases if k.startswith('cvc_')}, {f'cvc_{w}' for w in real})
        self.assertEqual({k for k in phrases if k.startswith('nonsense_')}, {f'nonsense_{w}' for w in fake})
        self.assertFalse(set(real) & fake)


if __name__ == '__main__':
    unittest.main()
