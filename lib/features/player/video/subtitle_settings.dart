import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/server_config_provider.dart';
import '../../../core/models/playback.dart' as playback_models;

const subtitleDisabledSelectionKey = '__subtitle_disabled__';

// 这是尚未完成字幕布局测量时使用的安全回退范围。实际播放时会根据
// 视口高度和字幕文本高度重新计算边界，避免字幕绘制到屏幕外。
const subtitleVerticalOffsetMin = -1000.0;
const subtitleVerticalOffsetMax = 2000.0;

// 字幕调节项阈值。延迟偏移刻意不设上下限，允许任意整毫秒值。
const subtitleSizeScaleMin = 0.5;
const subtitleSizeScaleMax = 4.0;
const subtitleOpacityMin = 0.1;
const subtitleOpacityMax = 1.0;

double clampSubtitleVerticalOffset(
  double value, {
  double min = subtitleVerticalOffsetMin,
  double max = subtitleVerticalOffsetMax,
}) => value.clamp(min, max).toDouble();

@immutable
class SubtitleVerticalOffsetBounds {
  const SubtitleVerticalOffsetBounds({
    this.min = subtitleVerticalOffsetMin,
    this.max = subtitleVerticalOffsetMax,
  }) : assert(min <= max);

  final double min;
  final double max;

  double clamp(double value) => value.clamp(min, max).toDouble();

  @override
  bool operator ==(Object other) {
    return other is SubtitleVerticalOffsetBounds &&
        other.min == min &&
        other.max == max;
  }

  @override
  int get hashCode => Object.hash(min, max);
}

/// 使用轨道元数据记住字幕选择，不保存带鉴权信息的字幕 URL。
String subtitleSelectionKey(playback_models.SubtitleTrack track) {
  return jsonEncode([
    track.source.trim().toLowerCase(),
    track.language.trim().toLowerCase(),
    track.title.trim(),
    track.codec.trim().toLowerCase(),
  ]);
}

@immutable
class SubtitleSettings {
  const SubtitleSettings({
    this.rememberSelectedSubtitle = true,
    this.ignoreAssStyle = false,
    this.ignoreSrtStyle = false,
    this.fontFamily = 'Inter',
    this.bold = false,
    this.italic = false,
    this.fontColor = const Color(0xFFFFFFFF),
    this.backgroundColor = const Color(0xAA000000),
    this.outlineColor = const Color(0xFF000000),
    this.outlineWidth = 0.0,
    this.shadowColor = const Color(0x99000000),
    this.shadowSize = 0.0,
    this.adjustments = const SubtitleAdjustments(),
    this.rememberedSubtitleKey,
  });

  static const defaults = SubtitleSettings();

  final bool rememberSelectedSubtitle;
  final bool ignoreAssStyle;
  final bool ignoreSrtStyle;
  final String fontFamily;
  final bool bold;
  final bool italic;
  final Color fontColor;
  final Color backgroundColor;
  final Color outlineColor;
  final double outlineWidth;
  final Color shadowColor;
  final double shadowSize;

  /// 播放器内字幕调节值，跨影片和重启持久化恢复。
  final SubtitleAdjustments adjustments;

  /// 最近一次选择的字幕轨道，供播放器自动恢复使用。
  final String? rememberedSubtitleKey;

  SubtitleSettings copyWith({
    bool? rememberSelectedSubtitle,
    bool? ignoreAssStyle,
    bool? ignoreSrtStyle,
    String? fontFamily,
    bool? bold,
    bool? italic,
    Color? fontColor,
    Color? backgroundColor,
    Color? outlineColor,
    double? outlineWidth,
    Color? shadowColor,
    double? shadowSize,
    SubtitleAdjustments? adjustments,
    String? rememberedSubtitleKey,
    bool clearRememberedSubtitle = false,
  }) {
    return SubtitleSettings(
      rememberSelectedSubtitle:
          rememberSelectedSubtitle ?? this.rememberSelectedSubtitle,
      ignoreAssStyle: ignoreAssStyle ?? this.ignoreAssStyle,
      ignoreSrtStyle: ignoreSrtStyle ?? this.ignoreSrtStyle,
      fontFamily: fontFamily ?? this.fontFamily,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      fontColor: fontColor ?? this.fontColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      outlineColor: outlineColor ?? this.outlineColor,
      outlineWidth: outlineWidth ?? this.outlineWidth,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowSize: shadowSize ?? this.shadowSize,
      adjustments: adjustments ?? this.adjustments,
      rememberedSubtitleKey: clearRememberedSubtitle
          ? null
          : rememberedSubtitleKey ?? this.rememberedSubtitleKey,
    );
  }
}

@immutable
class SubtitleAdjustments {
  const SubtitleAdjustments({
    this.delayMs = 0,
    this.opacity = 1.0,
    this.verticalOffsetPortrait = 0,
    this.verticalOffsetLandscape = 0,
    this.sizeScalePortrait = 1.0,
    this.sizeScaleLandscape = 1.0,
  });

  // 延迟与不透明度跨方向共享；垂直偏移与大小缩放按竖屏/横屏分组
  // 保存，两个方向各自调校，互不覆盖。
  final int delayMs;
  final double opacity;
  final double verticalOffsetPortrait;
  final double verticalOffsetLandscape;
  final double sizeScalePortrait;
  final double sizeScaleLandscape;

  double verticalOffsetFor(bool landscape) =>
      landscape ? verticalOffsetLandscape : verticalOffsetPortrait;

  double sizeScaleFor(bool landscape) =>
      landscape ? sizeScaleLandscape : sizeScalePortrait;

  SubtitleAdjustments copyWith({
    int? delayMs,
    double? opacity,
    double? verticalOffsetPortrait,
    double? verticalOffsetLandscape,
    double? sizeScalePortrait,
    double? sizeScaleLandscape,
  }) {
    return SubtitleAdjustments(
      delayMs: delayMs ?? this.delayMs,
      opacity: opacity ?? this.opacity,
      verticalOffsetPortrait:
          verticalOffsetPortrait ?? this.verticalOffsetPortrait,
      verticalOffsetLandscape:
          verticalOffsetLandscape ?? this.verticalOffsetLandscape,
      sizeScalePortrait: sizeScalePortrait ?? this.sizeScalePortrait,
      sizeScaleLandscape: sizeScaleLandscape ?? this.sizeScaleLandscape,
    );
  }

  SubtitleAdjustments normalized() {
    double finiteOffset(double value) => value.isFinite ? value : 0;
    return SubtitleAdjustments(
      delayMs: delayMs,
      opacity: opacity.clamp(subtitleOpacityMin, subtitleOpacityMax).toDouble(),
      verticalOffsetPortrait: finiteOffset(verticalOffsetPortrait),
      verticalOffsetLandscape: finiteOffset(verticalOffsetLandscape),
      sizeScalePortrait: sizeScalePortrait
          .clamp(subtitleSizeScaleMin, subtitleSizeScaleMax)
          .toDouble(),
      sizeScaleLandscape: sizeScaleLandscape
          .clamp(subtitleSizeScaleMin, subtitleSizeScaleMax)
          .toDouble(),
    );
  }
}

const subtitleColorChoices = <Color>[
  Color(0xFFFFFFFF),
  Color(0xFFFFF3B0),
  Color(0xFFFFD166),
  Color(0xFFFF8A80),
  Color(0xFF80CBC4),
  Color(0xFF80D8FF),
  Color(0xFFB39DDB),
  Color(0xFF000000),
  Color(0xAA000000),
  Color(0x00000000),
];

class SubtitleSettingsRepository {
  SubtitleSettingsRepository(this._prefs);

  static const _rememberKey = 'subtitle.remember_selected';
  static const _ignoreAssKey = 'subtitle.ignore_ass_style';
  static const _ignoreSrtKey = 'subtitle.ignore_srt_style';
  static const _fontKey = 'subtitle.font_family';
  static const _boldKey = 'subtitle.bold';
  static const _italicKey = 'subtitle.italic';
  static const _fontColorKey = 'subtitle.font_color';
  static const _backgroundColorKey = 'subtitle.background_color';
  static const _outlineColorKey = 'subtitle.outline_color';
  static const _outlineWidthKey = 'subtitle.outline_width';
  static const _shadowColorKey = 'subtitle.shadow_color';
  static const _shadowSizeKey = 'subtitle.shadow_size';
  static const _delayMsKey = 'subtitle.adjustment_delay_ms';
  // 兼容读取旧版共享键，迁移时使用。
  static const _legacyVerticalOffsetKey = 'subtitle.adjustment_vertical_offset';
  static const _legacySizeScaleKey = 'subtitle.adjustment_size_scale';
  static const _verticalOffsetPortraitKey =
      'subtitle.adjustment_vertical_offset_portrait';
  static const _verticalOffsetLandscapeKey =
      'subtitle.adjustment_vertical_offset_landscape';
  static const _sizeScalePortraitKey =
      'subtitle.adjustment_size_scale_portrait';
  static const _sizeScaleLandscapeKey =
      'subtitle.adjustment_size_scale_landscape';
  static const _opacityKey = 'subtitle.adjustment_opacity';
  static const _rememberedSubtitleKey = 'subtitle.remembered_selection';
  // v3: 垂直偏移与大小缩放按竖屏/横屏分组存储。分组前各版本存储的
  // 偏移无法判断属于哪个方向，统一归零重新校准；大小缩放始终是倍率
  // 语义，直接带入两组。
  static const _adjustmentSchemaKey = 'subtitle.adjustment_schema';
  static const _adjustmentSchemaVersion = 3;

  final SharedPreferences _prefs;

  SubtitleSettings load() {
    _migrateAdjustmentGroups();
    return SubtitleSettings(
      rememberSelectedSubtitle: _prefs.getBool(_rememberKey) ?? true,
      ignoreAssStyle: _prefs.getBool(_ignoreAssKey) ?? false,
      ignoreSrtStyle: _prefs.getBool(_ignoreSrtKey) ?? false,
      fontFamily: _prefs.getString(_fontKey) ?? 'Inter',
      bold: _prefs.getBool(_boldKey) ?? false,
      italic: _prefs.getBool(_italicKey) ?? false,
      fontColor: _readColor(_fontColorKey, SubtitleSettings.defaults.fontColor),
      backgroundColor: _readColor(
        _backgroundColorKey,
        SubtitleSettings.defaults.backgroundColor,
      ),
      outlineColor: _readColor(
        _outlineColorKey,
        SubtitleSettings.defaults.outlineColor,
      ),
      outlineWidth: _prefs.getDouble(_outlineWidthKey) ?? 0.0,
      shadowColor: _readColor(
        _shadowColorKey,
        SubtitleSettings.defaults.shadowColor,
      ),
      shadowSize: _prefs.getDouble(_shadowSizeKey) ?? 0.0,
      adjustments: SubtitleAdjustments(
        delayMs: _prefs.getInt(_delayMsKey) ?? 0,
        verticalOffsetPortrait:
            _prefs.getDouble(_verticalOffsetPortraitKey) ?? 0.0,
        verticalOffsetLandscape:
            _prefs.getDouble(_verticalOffsetLandscapeKey) ?? 0.0,
        sizeScalePortrait: _prefs.getDouble(_sizeScalePortraitKey) ?? 1.0,
        sizeScaleLandscape: _prefs.getDouble(_sizeScaleLandscapeKey) ?? 1.0,
        opacity: _prefs.getDouble(_opacityKey) ?? 1.0,
      ).normalized(),
      rememberedSubtitleKey: _prefs.getString(_rememberedSubtitleKey),
    );
  }

  Future<void> save(SubtitleSettings settings) async {
    await Future.wait([
      _prefs.setBool(_rememberKey, settings.rememberSelectedSubtitle),
      _prefs.setBool(_ignoreAssKey, settings.ignoreAssStyle),
      _prefs.setBool(_ignoreSrtKey, settings.ignoreSrtStyle),
      _prefs.setString(_fontKey, settings.fontFamily),
      _prefs.setBool(_boldKey, settings.bold),
      _prefs.setBool(_italicKey, settings.italic),
      _prefs.setInt(_fontColorKey, settings.fontColor.toARGB32()),
      _prefs.setInt(_backgroundColorKey, settings.backgroundColor.toARGB32()),
      _prefs.setInt(_outlineColorKey, settings.outlineColor.toARGB32()),
      _prefs.setDouble(_outlineWidthKey, settings.outlineWidth),
      _prefs.setInt(_shadowColorKey, settings.shadowColor.toARGB32()),
      _prefs.setDouble(_shadowSizeKey, settings.shadowSize),
      ..._adjustmentEntries(settings.adjustments),
      if (settings.rememberedSubtitleKey == null)
        _prefs.remove(_rememberedSubtitleKey)
      else
        _prefs.setString(
          _rememberedSubtitleKey,
          settings.rememberedSubtitleKey!,
        ),
    ]);
  }

  Future<void> saveAdjustments(SubtitleAdjustments adjustments) async {
    await Future.wait(_adjustmentEntries(adjustments));
  }

  List<Future<bool>> _adjustmentEntries(SubtitleAdjustments adjustments) {
    final value = adjustments.normalized();
    // 写入即视为当前 schema 数据，之后 load 不再迁移。
    _prefs.setInt(_adjustmentSchemaKey, _adjustmentSchemaVersion);
    return [
      _prefs.setInt(_delayMsKey, value.delayMs),
      _prefs.setDouble(
        _verticalOffsetPortraitKey,
        value.verticalOffsetPortrait,
      ),
      _prefs.setDouble(
        _verticalOffsetLandscapeKey,
        value.verticalOffsetLandscape,
      ),
      _prefs.setDouble(_sizeScalePortraitKey, value.sizeScalePortrait),
      _prefs.setDouble(_sizeScaleLandscapeKey, value.sizeScaleLandscape),
      _prefs.setDouble(_opacityKey, value.opacity),
    ];
  }

  Color _readColor(String key, Color fallback) {
    final value = _prefs.getInt(key);
    return value == null ? fallback : Color(value);
  }

  /// v3 分组迁移：把旧版共享的偏移/缩放拆成竖屏、横屏两组。
  /// 偏移归零（旧值无法判断属于哪个方向），缩放带入两组；清理旧键。
  /// set 系列会同步更新内存缓存，迁移后本次读取即为新值；
  /// 落盘失败时下次启动重试，结果幂等。
  void _migrateAdjustmentGroups() {
    if (_prefs.getInt(_adjustmentSchemaKey) == _adjustmentSchemaVersion) return;
    final sharedScale = _prefs.getDouble(_legacySizeScaleKey);
    _prefs.setDouble(_verticalOffsetPortraitKey, 0);
    _prefs.setDouble(_verticalOffsetLandscapeKey, 0);
    if (sharedScale != null) {
      _prefs.setDouble(_sizeScalePortraitKey, sharedScale);
      _prefs.setDouble(_sizeScaleLandscapeKey, sharedScale);
    }
    _prefs.remove(_legacyVerticalOffsetKey);
    _prefs.remove(_legacySizeScaleKey);
    _prefs.setInt(_adjustmentSchemaKey, _adjustmentSchemaVersion);
  }
}

final subtitleSettingsRepositoryProvider = Provider<SubtitleSettingsRepository>(
  (ref) => SubtitleSettingsRepository(ref.watch(sharedPrefsProvider)),
);

class SubtitleSettingsNotifier extends Notifier<SubtitleSettings> {
  @override
  SubtitleSettings build() {
    return ref.watch(subtitleSettingsRepositoryProvider).load();
  }

  Future<void> update(SubtitleSettings next) async {
    final previous = state;
    state = next;
    try {
      await ref.read(subtitleSettingsRepositoryProvider).save(next);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> updateAdjustments(SubtitleAdjustments next) async {
    final normalized = next.normalized();
    final previous = state;
    state = state.copyWith(adjustments: normalized);
    try {
      await ref
          .read(subtitleSettingsRepositoryProvider)
          .saveAdjustments(normalized);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> rememberSelection(String key) async {
    await update(
      state.copyWith(
        rememberedSubtitleKey: key,
        clearRememberedSubtitle: false,
      ),
    );
  }

  Future<void> reset() async {
    await update(SubtitleSettings.defaults);
  }
}

final subtitleSettingsProvider =
    NotifierProvider<SubtitleSettingsNotifier, SubtitleSettings>(
      SubtitleSettingsNotifier.new,
    );
