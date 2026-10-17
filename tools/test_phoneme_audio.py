import array
import io
import json
from pathlib import Path
import unittest
import wave

import generate_audio as audio


class PhonemeAudioTests(unittest.TestCase):
    def test_phonics_uses_directed_model_instead_of_letter_name_ssml(self):
        for sound, ipa in audio.PHONEMES.items():
            request = audio.request_for('sound_' + sound, sound)
            self.assertIn(request['voice']['modelName'],
                          ['gemini-2.5-flash-tts', 'gemini-2.5-pro-tts'])
            self.assertNotIn('ssml', request['input'])
            self.assertIn(f'/{ipa}/', request['input']['prompt'])
            self.assertIn(audio.PHONEME_WORDS[sound], request['input']['prompt'])
            self.assertIn('not a letter name', request['input']['prompt'])
            self.assertEqual(request['input']['text'], audio.PHONEME_CUES[sound])

    def test_bundled_s_is_sibilant_not_the_letter_name_ess(self):
        # A file/hash check missed the original defect. /s/ is unvoiced noise;
        # the vowel in "ess" has long energetic, low-zero-crossing frames.
        with wave.open(str(audio.DESTINATION / 'sound_s.wav')) as wav:
            data = array.array('h', wav.readframes(wav.getnframes()))
        frames = [data[i:i + 1200] for i in range(0, len(data) - 1200, 1200)]
        energy = [sum(v * v for v in frame) for frame in frames]
        voiced_energy = 0
        for frame, power in zip(frames, energy):
            crossings = sum((a < 0) != (b < 0) for a, b in zip(frame, frame[1:]))
            if crossings / len(frame) < 0.15:
                voiced_energy += power
        self.assertGreater(sum(energy), 0)
        self.assertLess(voiced_energy / sum(energy), 0.05,
                        'The /s/ recording contains a voiced vowel, as in ess')

    def test_normalization_preserves_sound_and_adds_leading_pause(self):
        samples = array.array('h', [0] * 2400 + [500, -1000] * 1200 + [0] * 2400)
        stream = io.BytesIO()
        with wave.open(stream, 'wb') as wav:
            wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(24000)
            wav.writeframes(samples.tobytes())
        result = audio.normalize_phoneme(stream.getvalue())
        with wave.open(io.BytesIO(result)) as wav:
            actual = array.array('h', wav.readframes(wav.getnframes()))
        self.assertEqual(actual[:9600], array.array('h', [0] * 9600))
        self.assertEqual([v for v in actual if v], [v for v in samples if v])

    def test_sustained_l_duration_control_preserves_onset_and_fades_tail(self):
        samples = array.array('h', [0] * 9600 + [2000, -2000] * 48000)
        stream = io.BytesIO()
        with wave.open(stream, 'wb') as wav:
            wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(24000)
            wav.writeframes(samples.tobytes())
        result = audio.shorten_sustained_l(stream.getvalue())
        audio.valid_phoneme(result)
        with wave.open(io.BytesIO(result)) as wav:
            actual = array.array('h', wav.readframes(wav.getnframes()))
        self.assertEqual(actual[:24000], samples[:24000])
        self.assertEqual(actual[-4800:], array.array('h', [0] * 4800))
        self.assertEqual(actual[-4801], 0)
        self.assertGreater(abs(actual[-5000]), 0)
        self.assertLess(abs(actual[-5000]), 2000)

    def test_runaway_phoneme_is_rejected_instead_of_silently_clipped(self):
        stream = io.BytesIO()
        with wave.open(stream, 'wb') as wav:
            wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(24000)
            wav.writeframes(array.array('h', [500, -500] * 48000).tobytes())
        with self.assertRaisesRegex(ValueError, 'exceeds three seconds'):
            audio.valid_phoneme(stream.getvalue())

    def test_existing_audio_remains_byte_identical(self):
        baseline = audio.ROOT / 'artifacts/learning-0180/baseline/assets/audio_manifest.json'
        if not baseline.exists():
            self.skipTest('Local release baseline not present')
        previous = json.loads(baseline.read_text())
        for clip, metadata in previous.items():
            self.assertEqual(audio.digest((audio.DESTINATION / (clip + '.wav')).read_bytes()), metadata['audio_sha256'])


if __name__ == '__main__':
    unittest.main()
