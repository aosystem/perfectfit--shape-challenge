import 'package:flutter/material.dart';

import 'package:perfectfit/parse_locale_tag.dart';
import 'package:perfectfit/setting_page.dart';
import 'package:perfectfit/shape_painter.dart';
import 'package:perfectfit/theme_color.dart';
import 'package:perfectfit/theme_mode_number.dart';
import 'package:perfectfit/ad_manager.dart';
import 'package:perfectfit/loading_screen.dart';
import 'package:perfectfit/model.dart';
import 'package:perfectfit/main.dart';
import 'package:perfectfit/ad_banner_widget.dart';
import 'package:perfectfit/shape_type.dart';
import 'package:perfectfit/l10n/app_localizations.dart';

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});
  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> with TickerProviderStateMixin {
  late AdManager _adManager;
  late ThemeColor _themeColor;
  bool _isReady = false;

  List<Offset> points = [];
  double? score;
  final double radiusRatio = 0.8;

  late AnimationController _flashController;
  late AnimationController _scoreFlashController;

  bool isShowingGuide = false;
  ShapeType currentShape = ShapeType.circle;

  int _lastGreen = 0;
  int _lastBlue = 0;
  int _lastRed = 0;
  int _lastTotal = 0;
  Set<int> _lastCovered = {};

  double? plusScore;
  double? minusInnerScore;
  double? minusOuterScore;
  double? totalScore;
  bool isPracticeMode = false;

  @override
  void initState() {
    super.initState();

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scoreFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 1.0,
    );

    _initAsync();
  }

  Future<void> _initAsync() async {
    _adManager = AdManager();

    if (mounted) {
      setState(() {
        _themeColor = ThemeColor(context: context);
        _isReady = true;
      });
      _startSequence();
    }
  }

  @override
  void dispose() {
    _scoreFlashController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  void _openSetting() async {
    final updatedSettings = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingPage()),
    );

    if (updatedSettings != null && mounted) {
      final mainState = context.findAncestorStateOfType<MainAppState>();
      if (mainState != null) {
        mainState
          ..locale = parseLocaleTag(Model.languageCode)
          ..themeMode = ThemeModeNumber.numberToThemeMode(Model.themeNumber)
          ..setState(() {});
      }
    }
  }

  void _calculateScore() {
    if (points.length < 10 || _lastTotal == 0) return;

    setState(() {
      plusScore = (_lastGreen / _lastTotal) * 100;
      minusInnerScore = (_lastBlue / _lastTotal) * 100;
      minusOuterScore = (_lastRed / _lastTotal) * 100;

      double progress;
      const double threshold = 200.0;
      progress = (_lastCovered.length >= threshold)
          ? 1.0
          : _lastCovered.length / threshold;

      totalScore = (plusScore! * progress).clamp(0.0, 100.0);
      score = totalScore;

      _startScoreFlash();
    });
  }

  void _startScoreFlash() async {
    _scoreFlashController.reset();
    for (int i = 0; i < 2; i++) {
      await _scoreFlashController.forward();
      await _scoreFlashController.reverse();
    }
    _scoreFlashController.forward();
  }

  void _startSequence() async {
    if (!mounted) {
      return;
    }
    _flashController.stop();
    _scoreFlashController.forward();

    setState(() {
      isShowingGuide = false;
      points.clear();
      score = null;
      plusScore = null;
    });

    for (int i = 0; i < 2; i++) {
      await _flashController.forward();
      await _flashController.reverse();
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const LoadingScreen();
    }
    return Scaffold(
      backgroundColor: _themeColor.mainBackColor,
      body: Stack(children: [
        _buildBackground(),
        SafeArea(
          child: Column(children: [
            _buildAppBar(),
            Expanded(child: _buildStage()),
          ]),
        )
      ]),
      bottomNavigationBar: AdBannerWidget(adManager: _adManager),
    );
  }

  Widget _buildAppBar() {
    final l = AppLocalizations.of(context)!;
    final t = Theme.of(context).textTheme;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          const SizedBox(width: 16),
          Text('Perfect Fit Challenge', style: t.bodySmall?.copyWith(color: _themeColor.mainForeColor.withValues(alpha: 0.5))),
          const Spacer(),
          Text(l.practice, style: TextStyle(fontSize: 12, color: _themeColor.mainForeColor.withValues(alpha: 0.7))),
          SizedBox(
            width: 44,
            child: Transform.scale(
              scale: 0.7,
              child: Switch(
                value: isPracticeMode,
                onChanged: (value) {
                  setState(() {
                    isPracticeMode = value;
                    if (value) {
                      points.clear();
                      score = null;
                    }
                  });
                },
              ),
            ),
          ),
          IconButton(
            onPressed: _openSetting,
            icon: Icon(Icons.settings, color: _themeColor.mainForeColor.withValues(alpha: 0.6)),
          ),
        ],
      )
    );
  }

  Widget _buildScoreDisplay() {
    if (totalScore == null) return const SizedBox.shrink();
    const TextStyle baseStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.bold);
    final Color mainTextColor = _themeColor.mainForeColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("${plusScore!.toStringAsFixed(0)}%", style: baseStyle.copyWith(color: Colors.greenAccent)),
        _buildSeparator(mainTextColor),
        Text("${minusInnerScore!.toStringAsFixed(0)}%", style: baseStyle.copyWith(color: Colors.blueAccent)),
        _buildSeparator(mainTextColor),
        Text("${minusOuterScore!.toStringAsFixed(0)}%", style: baseStyle.copyWith(color: Colors.redAccent)),
        _buildSeparator(mainTextColor),
        FadeTransition(
          opacity: _scoreFlashController,
          child: Text(
            totalScore!.toStringAsFixed(1),
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: mainTextColor
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeparator(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(":", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildStage() {
    final l = AppLocalizations.of(context)!;
    final shapeData = {
      ShapeType.circle: {"name": l.circle},
      ShapeType.triangle: {"name": l.triangle},
      ShapeType.square: {"name": l.square},
      ShapeType.pentagon: {"name": l.pentagon},
      ShapeType.hexagon: {"name": l.hexagon},
      ShapeType.heptagon: {"name": l.heptagon},
      ShapeType.octagon: {"name": l.octagon},
      ShapeType.nonagon: {"name": l.nonagon},
      ShapeType.decagon: {"name": l.decagon},
    };
    String shapeName = shapeData[currentShape]?["name"] ?? l.shapes;

    return Column(
      children: [
        const SizedBox(height: 10),
        Text("${l.draw}: $shapeName", style: TextStyle(color: _themeColor.mainAccentForeColor)),
        SizedBox(
          height: 40,
          child: score != null ? _buildScoreDisplay() : const SizedBox.shrink(),
        ),
        const SizedBox(height: 10),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AspectRatio(
            aspectRatio: 1.0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (isShowingGuide && !isPracticeMode) ? null : (_) {
                setState(() { points.clear(); score = null; });
              },
              onPanUpdate: (isShowingGuide && !isPracticeMode) ? null : (details) {
                if (points.isEmpty || (details.localPosition - points.last).distance > 4.0) {
                  setState(() => points.add(details.localPosition));
                }
              },
              onPanEnd: (isShowingGuide && !isPracticeMode) ? null : (_) => _calculateScore(),
              child: AnimatedBuilder(
                animation: _flashController,
                builder: (context, child) => CustomPaint(
                  painter: ShapePainter(
                    points: points,
                    radiusRatio: radiusRatio,
                    guideOpacity: _flashController.value,
                    isShowingGuide: isPracticeMode,
                    shapeType: currentShape,
                    score: score,
                    onResult: (g, b, r, t, c) {
                      _lastGreen = g; _lastBlue = b; _lastRed = r; _lastTotal = t; _lastCovered = c;
                    },
                  ),
                  child: Container(width: double.infinity, height: double.infinity, color: Colors.transparent),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: shapeData.keys.map((type) {
                      return _modeButton(shapeData[type]!["name"] as String, type);
                    }).toList(),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _modeButton(String label, ShapeType type) {
    bool isSelected = currentShape == type;
    Color activeColor = _themeColor.mainForeColor;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent, foregroundColor: activeColor,
        elevation: 0, shadowColor: Colors.transparent, surfaceTintColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        side: BorderSide(color: isSelected ? _themeColor.mainAccentForeColor : Colors.transparent, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) return Colors.transparent;
          return null;
        }),
      ),
      onPressed: () {
        setState(() { currentShape = type; });
        _startSequence();
      },
      child: Text(label, style: TextStyle(color: isSelected ? activeColor : activeColor.withValues(alpha: 0.5), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_themeColor.mainBack2Color, _themeColor.mainBackColor], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        image: const DecorationImage(image: AssetImage('assets/image/tile.png'), repeat: ImageRepeat.repeat, opacity: 0.1),
      ),
    );
  }
}
