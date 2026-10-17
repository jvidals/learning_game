/// Shared timing contract; checked against the authoring manifest by tests.
const foalDurations = <String, int>{
  'idle': 8000,
  'happy': 550,
  'simple': 1400,
  'hop': 1400,
  'bowing': 2000,
  'twirl': 2000,
};

Duration foalReactionDuration({bool happy = false, String? behavior}) =>
    Duration(
      milliseconds: foalDurations[happy ? 'happy' : behavior ?? 'simple']!,
    );

class FoalClipSample {
  const FoalClipSample(this.clip, this.frame);
  final String clip;
  final int frame;
  int get segment => frame ~/ 15;
  int get localFrame => frame % 15;

  static FoalClipSample evaluate({
    double idle = 0,
    double reaction = 0,
    bool happy = false,
    bool celebrating = false,
    String? behavior,
    bool reduced = false,
  }) {
    if (reduced) {
      return FoalClipSample(happy ? 'happy' : 'idle', happy ? 16 : 0);
    }
    final clip = happy
        ? 'happy'
        : celebrating
        ? behavior ?? 'simple'
        : 'idle';
    final progress = happy || celebrating ? reaction : idle;
    final count = (foalDurations[clip]! * 60 / 1000).round();
    final loop = clip == 'idle';
    final p = loop ? progress % 1 : progress.clamp(0.0, 1.0);
    return FoalClipSample(clip, (p * count).floor().clamp(0, count - 1));
  }
}
