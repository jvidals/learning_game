import 'package:flutter/material.dart';
import '../progress_controller.dart';
import '../profiles.dart';
import '../widgets/parent_gate.dart';
import '../widgets/profile_portrait.dart';
import '../widgets/progress_widgets.dart';

Future<void> openProfiles(
  BuildContext context,
  ProgressController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => ProfilesSheet(controller: controller),
);

class ProfilesSheet extends StatefulWidget {
  const ProfilesSheet({super.key, required this.controller});
  final ProgressController controller;
  @override
  State<ProfilesSheet> createState() => _ProfilesSheetState();
}

class _ProfilesSheetState extends State<ProfilesSheet> {
  bool _managing = false;
  late final String? _openedPlayer = widget.controller.activeProfile?.id;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (widget.controller.activeProfile?.id != _openedPlayer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pop(context);
        }
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  Future<void> _save(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      /* Shared save status retains retry. */
    }
  }

  Future<void> _manage({bool adding = false}) async {
    final c = widget.controller;
    if (_managing || c.blocked.value) return;
    setState(() => _managing = true);
    try {
      if (!await openParentGate(
            context,
            purpose: adding ? 'add a player' : 'edit this player',
          ) ||
          !mounted) {
        return;
      }
      final edit = await showDialog<_PlayerEdit>(
        context: context,
        builder: (_) => _NameDialog(
          player: adding ? null : c.activeProfile,
          canDelete: c.profiles.length > 1,
        ),
      );
      if (edit == null || !mounted) return;
      if (edit.delete) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: Text('Delete ${c.activeProfile!.name}?'),
            content: const Text(
              'This removes this player’s progress and settings. This cannot be undone.',
            ),
            actions: [
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete player'),
              ),
            ],
          ),
        );
        if (confirmed == true && mounted) await _save(c.deleteProfile);
      } else {
        await _save(
          () => adding ? c.addProfile(edit.name!) : c.renameProfile(edit.name!),
        );
      }
    } finally {
      if (mounted) setState(() => _managing = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller,
          busy = _managing || widget.controller.blocked.value;
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Players',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close players',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: c.profiles.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) return SaveStatus(controller: c);
                      final player = c.profiles[index - 1],
                          selected = player.id == c.activeProfile?.id;
                      void select() {
                        if (selected) {
                          Navigator.pop(context);
                        } else {
                          _save(() => c.selectProfile(player.id));
                        }
                      }

                      final largeText =
                          MediaQuery.textScalerOf(context).scale(16) > 24;
                      final portrait = ProfilePortrait(
                        configuration: player.portrait,
                      );
                      final name = Text(player.name);
                      final check = selected
                          ? const Icon(
                              Icons.check_rounded,
                              semanticLabel: 'Current player',
                            )
                          : const SizedBox.shrink();
                      final edit = selected
                          ? IconButton(
                              tooltip: 'Edit ${player.name}',
                              onPressed: busy ? null : () => _manage(),
                              icon: const Icon(Icons.edit_outlined),
                            )
                          : const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: largeText
                            ? Semantics(
                                selected: selected,
                                child: InkWell(
                                  onTap: busy ? null : select,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          portrait,
                                          const SizedBox(width: 12),
                                          check,
                                          const Spacer(),
                                          edit,
                                        ],
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 8,
                                        ),
                                        child: name,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: Semantics(
                                      selected: selected,
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                        leading: portrait,
                                        title: name,
                                        trailing: selected ? check : null,
                                        onTap: busy ? null : select,
                                      ),
                                    ),
                                  ),
                                  edit,
                                ],
                              ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _manage(adding: true),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add player'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _PlayerEdit {
  const _PlayerEdit({this.name, this.delete = false});
  final String? name;
  final bool delete;
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({this.player, required this.canDelete});
  final PlayerProfile? player;
  final bool canDelete;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.player?.name ?? '');
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      Navigator.pop(
        context,
        _PlayerEdit(name: normalizePlayerName(_name.text)),
      );
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.player == null ? 'Add player' : 'Edit player'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: 24,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: 'Name', errorText: _error),
          onSubmitted: (_) => _submit(),
        ),
        if (widget.player != null) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: widget.canDelete
                ? () => Navigator.pop(context, const _PlayerEdit(delete: true))
                : null,
            child: const Text('Delete player'),
          ),
          if (!widget.canDelete)
            const Text(
              'Keep at least one player.',
              style: TextStyle(fontSize: 14),
            ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Save')),
    ],
  );
}
