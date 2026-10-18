import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/widgets/stable_route_insets.dart';

void main() {
  const padding = FakeViewPadding(top: 24, bottom: 12);
  const viewPadding = FakeViewPadding(top: 24, bottom: 24);
  const viewInsets = FakeViewPadding(bottom: 12);

  void setInsets(WidgetTester tester, {required bool immersive}) {
    tester.view.padding = immersive ? const FakeViewPadding() : padding;
    tester.view.viewPadding = immersive ? const FakeViewPadding() : viewPadding;
    tester.view.viewInsets = immersive ? const FakeViewPadding() : viewInsets;
  }

  Future<void> mount(
    WidgetTester tester, {
    required ScrollController scroll,
    required GlobalKey<NavigatorState> navigator,
    required ValueChanged<BuildContext> onBuild,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    setInsets(tester, immersive: false);
    addTearDown(tester.view.reset);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: StableRouteInsets(
          child: Builder(
            builder: (context) {
              onBuild(context);
              return Scaffold(
                body: SafeArea(
                  child: ListView.builder(
                    controller: scroll,
                    padding: EdgeInsets.zero,
                    itemCount: 100,
                    itemExtent: 60,
                    itemBuilder: (_, index) => Text('Item $index'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
  }

  testWidgets('covered route keeps its insets and bottom scroll through pop', (
    tester,
  ) async {
    final scroll = ScrollController();
    final navigator = GlobalKey<NavigatorState>();
    late MediaQueryData observed;
    late ModalRoute<dynamic> routeA;
    await mount(
      tester,
      scroll: scroll,
      navigator: navigator,
      onBuild: (context) {
        observed = MediaQuery.of(context);
        routeA = ModalRoute.of(context)!;
      },
    );
    final initial = observed;
    final offset = scroll.offset;
    final extent = scroll.position.maxScrollExtent;
    void expectStable() {
      expect(observed.padding, initial.padding);
      expect(observed.viewPadding, initial.viewPadding);
      expect(observed.viewInsets, initial.viewInsets);
      expect(scroll.offset, offset);
      expect(scroll.position.maxScrollExtent, extent);
    }

    navigator.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Route B')),
      ),
    );
    await tester.pumpAndSettle();
    setInsets(tester, immersive: true);
    // Unrelated MediaQuery changes still reach the covered route.
    tester.view.physicalSize = const Size(420, 800);
    await tester.pumpAndSettle();
    expect(observed.size.width, 420);
    expectStable();

    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(routeA.isCurrent, isTrue);
    expect(routeA.secondaryAnimation!.status, AnimationStatus.reverse);
    expectStable();

    // The bars return while the route above is still animating out.
    setInsets(tester, immersive: false);
    await tester.pump(const Duration(milliseconds: 40));
    expect(routeA.secondaryAnimation!.status, AnimationStatus.reverse);
    expectStable();
    await tester.pumpAndSettle();
    expect(routeA.secondaryAnimation!.status, AnimationStatus.dismissed);
    expectStable();
  });

  testWidgets('uncovered route receives changed insets and relayouts', (
    tester,
  ) async {
    final scroll = ScrollController();
    late MediaQueryData observed;
    await mount(
      tester,
      scroll: scroll,
      navigator: GlobalKey<NavigatorState>(),
      onBuild: (context) => observed = MediaQuery.of(context),
    );
    final extent = scroll.position.maxScrollExtent;
    setInsets(tester, immersive: true);
    await tester.pumpAndSettle();
    expect(observed.padding, EdgeInsets.zero);
    expect(observed.viewPadding, EdgeInsets.zero);
    expect(observed.viewInsets, EdgeInsets.zero);
    expect(scroll.position.maxScrollExtent, lessThan(extent));
    expect(scroll.offset, scroll.position.maxScrollExtent);
    setInsets(tester, immersive: false);
    await tester.pumpAndSettle();
    expect(observed.padding, const EdgeInsets.only(top: 24, bottom: 12));
    expect(observed.viewPadding, const EdgeInsets.only(top: 24, bottom: 24));
    expect(observed.viewInsets, const EdgeInsets.only(bottom: 12));
    expect(scroll.position.maxScrollExtent, extent);
  });

  testWidgets('without an enclosing route the child passes through', (
    tester,
  ) async {
    // No MaterialApp or ModalRoute, and no added MediaQuery below the wrapper.
    await tester.pumpWidget(
      const StableRouteInsets(child: SizedBox(key: ValueKey('child'))),
    );
    expect(find.byKey(const ValueKey('child')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(StableRouteInsets),
        matching: find.byType(MediaQuery),
      ),
      findsNothing,
    );
  });
}
