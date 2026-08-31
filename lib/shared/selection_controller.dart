import 'package:flutter/foundation.dart';

/// 统一管理列表/网格的选择模式与已选标识。
///
/// [activeListenable] 只在进入或退出选择模式时通知；[selectedListenable]
/// 只在选择集合变化时通知。页面可以据此避免每次勾选都重建整棵页面树。
class SelectionController<T> {
  SelectionController({bool active = false, Iterable<T> selected = const []})
    : _active = ValueNotifier<bool>(active),
      _selected = ValueNotifier<Set<T>>(Set<T>.unmodifiable(selected));

  final ValueNotifier<bool> _active;
  final ValueNotifier<Set<T>> _selected;

  ValueListenable<bool> get activeListenable => _active;
  ValueListenable<Set<T>> get selectedListenable => _selected;

  bool get isActive => _active.value;
  Set<T> get selected => _selected.value;
  int get count => _selected.value.length;
  bool get isEmpty => _selected.value.isEmpty;

  bool contains(T id) => _selected.value.contains(id);

  void enter() {
    if (!_active.value) _active.value = true;
  }

  /// 清空选择，但保留当前选择模式。
  void clear() => _replaceSelected(const []);

  /// 退出选择模式并清空选择。
  void exit() {
    _replaceSelected(const []);
    if (_active.value) _active.value = false;
  }

  /// 普通点按切换；取消最后一项时默认退出选择模式。
  void toggle(T id, {bool deactivateWhenEmpty = true}) {
    final next = Set<T>.of(_selected.value);
    if (!next.remove(id)) {
      next.add(id);
      enter();
    }
    _replaceSelected(next);
    if (deactivateWhenEmpty && next.isEmpty && _active.value) {
      _active.value = false;
    }
  }

  /// 拖选期间设置单项值。取消到空集合时不会提前退出，调用方可在拖选
  /// 结束后根据 [isEmpty] 决定是否 [exit]。
  void setSelected(T id, bool selected, {bool activate = false}) {
    if (selected && activate) enter();
    if (contains(id) == selected) return;
    final next = Set<T>.of(_selected.value);
    selected ? next.add(id) : next.remove(id);
    _replaceSelected(next);
  }

  void selectAll(Iterable<T> ids, {bool activate = true}) {
    if (activate) enter();
    _replaceSelected(ids);
  }

  void retainWhere(
    bool Function(T id) predicate, {
    bool deactivateWhenEmpty = false,
  }) {
    final next = Set<T>.of(_selected.value)..retainWhere(predicate);
    _replaceSelected(next);
    if (deactivateWhenEmpty && next.isEmpty && _active.value) {
      _active.value = false;
    }
  }

  void dispose() {
    _active.dispose();
    _selected.dispose();
  }

  void _replaceSelected(Iterable<T> ids) {
    final next = Set<T>.unmodifiable(ids);
    final current = _selected.value;
    if (current.length == next.length && current.containsAll(next)) return;
    _selected.value = next;
  }
}
