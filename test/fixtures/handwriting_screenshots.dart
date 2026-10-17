import 'package:rainbow_garden/handwriting.dart';

/// Manually reconstructed from Screenshot_20260917-184706 (Q), -184919 (j),
/// -185126 (h), and -185224 (u). These approximate visible ink centerlines;
/// they are not original touch recordings or samples of the production guide.
final screenshotWriting = <String, List<InkStroke>>{
  'Q': [
    [
      for (final p in <(double, double)>[
        (.65, -.03),
        (.49, -.05),
        (.28, -.02),
        (.17, .14),
        (.09, .33),
        (.10, .53),
        (.18, .72),
        (.32, .85),
        (.48, .90),
        (.66, .86),
        (.84, .74),
        (.97, .56),
        (1.00, .37),
        (.96, .16),
        (.88, .01),
        (.75, -.09),
      ])
        InkPoint(p.$1, p.$2),
    ],
    [
      for (final p in <(double, double)>[
        (.73, .65),
        (.86, .74),
        (.99, .86),
        (1.10, .97),
        (1.16, 1.0),
      ])
        InkPoint(p.$1, p.$2),
    ],
  ],
  'j': [
    [
      for (final p in <(double, double)>[
        (.60, .51),
        (.61, .73),
        (.61, .94),
        (.61, 1.11),
        (.58, 1.17),
        (.48, 1.22),
        (.34, 1.23),
        (.29, 1.20),
        (.29, 1.10),
      ])
        InkPoint(p.$1, p.$2),
    ],
    [const InkPoint(.58, .35)],
  ],
  'h': [
    [
      for (final p in <(double, double)>[
        (.24, 0),
        (.25, .21),
        (.25, .43),
        (.27, .63),
        (.27, .82),
        (.28, 1.0),
      ])
        InkPoint(p.$1, p.$2),
    ],
    [
      for (final p in <(double, double)>[
        (.27, .78),
        (.32, .61),
        (.41, .52),
        (.48, .50),
        (.53, .51),
        (.58, .57),
        (.61, .73),
        (.62, .88),
        (.63, 1.0),
      ])
        InkPoint(p.$1, p.$2),
    ],
  ],
  'u': [
    [
      for (final p in <(double, double)>[
        (.25, .49),
        (.25, .72),
        (.25, .93),
        (.29, 1.02),
        (.40, .99),
        (.53, .95),
        (.62, .87),
        (.65, .75),
        (.65, .47),
      ])
        InkPoint(p.$1, p.$2),
    ],
    [
      const InkPoint(.65, .47),
      const InkPoint(.65, .75),
      const InkPoint(.64, 1.0),
    ],
  ],
};
