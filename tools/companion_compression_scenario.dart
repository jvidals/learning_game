// Diagnostics only: exercises the production companion without loading saves.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:rainbow_garden/companion.dart';
import 'package:rainbow_garden/companion/foal_assets.dart';
import 'package:rainbow_garden/progress.dart';

String compressionStage = 'loading';

class CompanionCompressionScenario extends StatefulWidget {
  const CompanionCompressionScenario({super.key});

  @override
  State<CompanionCompressionScenario> createState() =>
      _CompanionCompressionScenarioState();
}

class _CompanionCompressionScenarioState
    extends State<CompanionCompressionScenario> {
  Timer? _timer;
  int _seconds = 0, _trigger = 0, _action = -1, _outfit = -1;
  bool _ready = false, _reduced = false, _complete = false;
  CompanionReaction _reaction = CompanionReaction.happy;
  CompanionConfiguration _configuration = CompanionConfiguration({});

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  void _stage(String value) {
    if (compressionStage == value) return;
    compressionStage = value;
    debugPrint(
      'FOAL_SCENARIO ${jsonEncode({'stage': value, 'seconds': _seconds, 'decodedBytes': FoalAssets.ready?.decodedBytes})}',
    );
  }

  Future<void> _start() async {
    try {
      await FoalAssets.load();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _stage('idle');
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } catch (error) {
      debugPrint(
        'FOAL_SCENARIO ${jsonEncode({'stage': 'error', 'error': '$error'})}',
      );
    }
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _seconds++;
      if (_seconds >= 118) {
        _complete = true;
        _timer?.cancel();
        _stage('complete');
      } else if (_seconds >= 110) {
        _reduced = true;
        _trigger = 0;
        _stage('reduced-motion');
      } else if (_seconds >= 60) {
        _stage('outfits');
        final index = (_seconds - 60) ~/ 2;
        if (_outfit != index) {
          _outfit = index;
          const heads = ['none', 'flower', 'bow', 'star', 'heart'];
          const wings = ['none', 'feather', 'butterfly', 'rainbow', 'fairy'];
          const colors = [
            'pink',
            'blue',
            'mint',
            'gold',
            'lavender',
            'coral',
            'teal',
          ];
          _trigger = 0;
          _configuration = CompanionConfiguration({
            if (heads[index ~/ 5] != 'none')
              RewardCategory.accessory: heads[index ~/ 5],
            if (wings[index % 5] != 'none')
              RewardCategory.wings: wings[index % 5],
            if (colors[index % colors.length] != 'pink')
              RewardCategory.mane: colors[index % colors.length],
            RewardCategory.polish: index.isEven ? 'polish_gold' : 'polish_pink',
          });
        }
      } else if (_seconds >= 30) {
        _stage('celebrations');
        final index = (_seconds - 30) ~/ 3;
        if (_action != index) {
          _action = index;
          const actions = ['happy', 'simple', 'hop', 'bowing', 'twirl'];
          final action = actions[index % actions.length];
          _reaction = action == 'happy'
              ? CompanionReaction.happy
              : CompanionReaction.celebration;
          _configuration = CompanionConfiguration({
            RewardCategory.accessory: 'heart',
            RewardCategory.wings: 'fairy',
            RewardCategory.mane: 'teal',
            RewardCategory.polish: 'polish_gold',
            if (action != 'happy' && action != 'simple')
              RewardCategory.behavior: action,
          });
          _trigger++;
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Builder(
      builder: (context) {
        final dark = _outfit < 0 || _outfit.isEven;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: _reduced),
          child: Scaffold(
            backgroundColor: dark ? Colors.black : const Color(0xfffff7fc),
            body: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Compression playback: $compressionStage',
                    style: TextStyle(color: dark ? Colors.white : Colors.black),
                  ),
                  if (_ready && !_complete)
                    CompanionView(
                      configuration: _configuration,
                      height: 360,
                      reaction: _reaction,
                      reactionTrigger: _trigger,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
