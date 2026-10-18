import 'package:flutter/material.dart';
export '../widgets/parent_gate.dart';
import '../sight_words.dart';
import '../letter_sounds.dart';
import '../app_settings.dart';
import '../progress_controller.dart';
import '../widgets/progress_widgets.dart';
import '../widgets/page_body.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.onReset,
  });
  final ProgressController controller;
  final Future<void> Function() onReset;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;
  String? _message, _soundsError, _packsError;

  Future<void> _change(AppSettings Function(AppSettings) update) async {
    if (_busy || !widget.controller.canEditSettings) return;
    try {
      await widget.controller.updateSettings(update);
    } catch (_) {
      /* The controller retains the change and exposes retry. */
    }
  }

  void _sound(String letter, bool enabled) {
    final next = {
      ...widget.controller.effectiveSettings.enabledLetterSounds.enabled,
    };
    if (enabled) {
      next.add(letter);
    } else {
      next.remove(letter);
    }
    if (!SoundSelection.isValid(next)) {
      setState(() => _soundsError = 'Keep at least three different sounds.');
      return;
    }
    setState(() => _soundsError = null);
    _change((s) => s.copyWith(enabledLetterSounds: SoundSelection(next)));
  }

  void _pack(SightWordPack pack, bool enabled) {
    final next = {
      ...widget.controller.effectiveSettings.enabledSightWordPacks.enabled,
    };
    if (enabled) {
      next.add(pack);
    } else {
      next.remove(pack);
    }
    if (next.isEmpty) {
      setState(() => _packsError = 'Keep at least one pack.');
      return;
    }
    setState(() => _packsError = null);
    _change((s) => s.copyWith(enabledSightWordPacks: SightWordPacks(next)));
  }

  Future<void> _reset() async {
    if (_busy || widget.controller.blocked.value) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          widget.controller.profileStoreUnavailable
              ? 'Reset all players?'
              : 'Reset ${widget.controller.activeProfile!.name}’s progress?',
        ),
        content: Text(
          widget.controller.profileStoreUnavailable
              ? 'The player list could not be read. This removes all players, progress and settings and creates Player 1. This cannot be undone.'
              : 'This removes XP, unicorn rewards and scores, including your Writing alphabet, 2048 game and Tap Challenge high scores. '
                    '${widget.controller.activeProfile!.hasValidSettings ? 'All your settings will stay the same.' : 'This player’s unreadable settings will return to the app defaults.'}',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset progress'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || widget.controller.blocked.value)
      return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.onReset();
      if (mounted)
        setState(() {
          _busy = false;
          _message = 'Your progress is ready for a fresh start.';
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _busy = false;
          _message = 'Progress could not be reset. Please try again.';
        });
    }
  }

  Widget _error(String message) => Padding(
    padding: const EdgeInsets.all(16),
    child: Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final settings = widget.controller.effectiveSettings;
      final enabled = !_busy && widget.controller.canEditSettings;
      return PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            leading: IconButton(
              tooltip: 'Back to home',
              onPressed: _busy ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          body: PageBody(
            children: [
              SaveStatus(controller: widget.controller),
              if (widget.controller.activeProfile != null)
                Text(
                  'Settings for ${widget.controller.activeProfile!.name}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 8),
              const Text('Changes apply and save automatically.'),
              const SizedBox(height: 16),
              const Text(
                'Appearance',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              RadioGroup<AppAppearance>(
                groupValue: settings.appearance,
                onChanged: (value) {
                  if (value != null && enabled)
                    _change((s) => s.copyWith(appearance: value));
                },
                child: Column(
                  children: [
                    for (final appearance in AppAppearance.values)
                      RadioListTile<AppAppearance>(
                        key: ValueKey('appearance-${appearance.name}'),
                        value: appearance,
                        enabled: enabled,
                        title: Text(switch (appearance) {
                          AppAppearance.system => 'System',
                          AppAppearance.light => 'Light',
                          AppAppearance.dark => 'Dark',
                        }),
                        subtitle: Text(switch (appearance) {
                          AppAppearance.system =>
                            'Follow the phone’s light or dark setting.',
                          AppAppearance.light => 'Use light appearance.',
                          AppAppearance.dark =>
                            'Black backgrounds with rainbow colors.',
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ExpansionTile(
                maintainState: true,
                expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
                    ? AnimationStyle.noAnimation
                    : null,
                title: const Text('Letter Sounds'),
                subtitle: Text(
                  '${settings.enabledLetterSounds.letters.length} letters enabled',
                ),
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Short vowels and common consonant sounds. c and k share a sound. Keep at least three different sounds.',
                    ),
                  ),
                  if (_soundsError != null) _error(_soundsError!),
                  TextButton(
                    onPressed: enabled
                        ? () {
                            setState(() => _soundsError = null);
                            _change(
                              (s) => s.copyWith(
                                enabledLetterSounds: SoundSelection.defaults,
                              ),
                            );
                          }
                        : null,
                    child: const Text('Select all letters'),
                  ),
                  for (final sound in letterSounds)
                    CheckboxListTile(
                      key: ValueKey('sound-letter-${sound.letter}'),
                      title: Text('${sound.letter} — ${sound.word}'),
                      value: settings.enabledLetterSounds.enabled.contains(
                        sound.letter,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: enabled
                          ? (value) => _sound(sound.letter, value == true)
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              ExpansionTile(
                maintainState: true,
                expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
                    ? AnimationStyle.noAnimation
                    : null,
                title: const Text('Sight Word packs'),
                subtitle: Text(
                  '${settings.enabledSightWordPacks.enabled.length} ${settings.enabledSightWordPacks.enabled.length == 1 ? 'pack' : 'packs'} enabled · ${settings.enabledSightWordPacks.words.length} words',
                ),
                children: [
                  if (_packsError != null) _error(_packsError!),
                  for (final pack in SightWordPack.values)
                    CheckboxListTile(
                      key: ValueKey('word-pack-${pack.name}'),
                      title: Text('${pack.title} · ${pack.words.length} words'),
                      subtitle: Text(pack.words.join(', ')),
                      value: settings.enabledSightWordPacks.enabled.contains(
                        pack,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: enabled
                          ? (value) => _pack(pack, value == true)
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Tap Next'),
                subtitle: const Text(
                  'Wait for Next after each find and Next round after learning rounds or ordering boards. When off, questions and saved rounds continue after a short pause. Accessible navigation always waits for a tap. Writing always uses Next.',
                ),
                value: settings.tapNext,
                onChanged: enabled
                    ? (v) => _change((s) => s.copyWith(tapNext: v))
                    : null,
              ),
              SwitchListTile(
                title: const Text('Haptics'),
                subtitle: const Text(
                  'Gentle touch feedback for finds and unicorn reactions. Also respects system touch feedback settings.',
                ),
                value: settings.haptics,
                onChanged: enabled
                    ? (v) => _change((s) => s.copyWith(haptics: v))
                    : null,
              ),
              SwitchListTile(
                key: const ValueKey('settings-sketch-save-photos'),
                title: const Text('Save drawings to photos'),
                subtitle: const Text('Shows the save button in Sketch Pad'),
                value: settings.sketchSaveToPhotos,
                onChanged: enabled
                    ? (v) => _change((s) => s.withSketchSaveToPhotos(v))
                    : null,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(),
              ),
              const Text(
                'Player progress',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Start again at level 1 with your pink-maned unicorn.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy || widget.controller.blocked.value
                    ? null
                    : _reset,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset progress'),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(liveRegion: true, child: Text(_message!)),
                ),
            ],
          ),
        ),
      );
    },
  );
}
