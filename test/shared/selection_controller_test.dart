import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/selection_controller.dart';

void main() {
  test('active 与 selected 分别通知', () {
    final controller = SelectionController<int>();
    addTearDown(controller.dispose);
    var activeNotifications = 0;
    var selectedNotifications = 0;
    controller.activeListenable.addListener(() => activeNotifications++);
    controller.selectedListenable.addListener(() => selectedNotifications++);

    controller.enter();
    controller.setSelected(1, true);
    controller.setSelected(2, true);

    expect(controller.isActive, isTrue);
    expect(controller.selected, {1, 2});
    expect(activeNotifications, 1);
    expect(selectedNotifications, 2);
  });

  test('clear 保持模式，exit 清空并退出', () {
    final controller = SelectionController<int>();
    addTearDown(controller.dispose);

    controller.selectAll([1, 2]);
    controller.clear();
    expect(controller.isActive, isTrue);
    expect(controller.selected, isEmpty);

    controller.setSelected(3, true);
    controller.exit();
    expect(controller.isActive, isFalse);
    expect(controller.selected, isEmpty);
  });

  test('toggle 取消最后一项时退出，拖选设置不会提前退出', () {
    final controller = SelectionController<int>();
    addTearDown(controller.dispose);

    controller.toggle(1);
    expect(controller.isActive, isTrue);
    controller.toggle(1);
    expect(controller.isActive, isFalse);

    controller.enter();
    controller.setSelected(2, true);
    controller.setSelected(2, false);
    expect(controller.isActive, isTrue);
    expect(controller.selected, isEmpty);
  });

  test('retainWhere 裁剪失效项并可在空集合时退出', () {
    final controller = SelectionController<int>(
      active: true,
      selected: [1, 2, 3],
    );
    addTearDown(controller.dispose);

    controller.retainWhere((id) => id.isEven);
    expect(controller.selected, {2});
    expect(controller.isActive, isTrue);

    controller.retainWhere((_) => false, deactivateWhenEmpty: true);
    expect(controller.selected, isEmpty);
    expect(controller.isActive, isFalse);
  });

  test('重复写入不产生额外通知', () {
    final controller = SelectionController<int>(active: true, selected: [1]);
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.selectedListenable.addListener(() => notifications++);

    controller.setSelected(1, true);
    controller.selectAll([1]);
    controller.retainWhere((_) => true);

    expect(notifications, 0);
  });
}
