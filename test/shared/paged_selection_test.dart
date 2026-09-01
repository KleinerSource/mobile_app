import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/paged_selection.dart';

void main() {
  group('PagedSelectionController 拖选语义', () {
    test('长按未选项开始选中扫选；长按已选项开始取消扫选', () {
      final selection = PagedSelectionController<int>(idOf: (id) => 'id-$id');

      selection.startSweep('id-1', true);
      expect(selection.isActive, isTrue);
      expect(selection.selectedIds, {'id-1'});

      selection.applySweep('id-2', true);
      expect(selection.selectedIds, {'id-1', 'id-2'});

      // 拖选结束仍有选中项：保持选择模式。
      selection.finishSweep();
      expect(selection.isActive, isTrue);

      // 已选集合上重新扫选 = 取消。
      selection.startSweep('id-1', false);
      selection.applySweep('id-2', false);
      selection.finishSweep();
      // 扫空后自动退出选择模式。
      expect(selection.isActive, isFalse);
      expect(selection.selectedIds, isEmpty);
    });

    test('选择模式下点按切换；取消到空集合自动退出', () {
      final selection = PagedSelectionController<int>(idOf: (id) => id);

      selection.toggle(1);
      expect(selection.selectedIds, {1});

      selection.toggle(2);
      expect(selection.selectedIds, {1, 2});

      selection.toggle(1);
      selection.toggle(2);
      expect(selection.isActive, isFalse);
    });

    test('selectAll 按 idOf 映射条目；retainWhere 保留仍存在的选择', () {
      final selection = PagedSelectionController<String>(idOf: (s) => s);

      selection.selectAll(['a', 'b', 'c']);
      expect(selection.selectedIds, {'a', 'b', 'c'});

      selection.retainWhere((id) => id != 'b');
      expect(selection.selectedIds, {'a', 'c'});
    });

    test('clear 清空选择但保持模式；exit 两者都重置', () {
      final selection = PagedSelectionController<int>();

      selection.toggle(1);
      selection.clear();
      expect(selection.isActive, isTrue);
      expect(selection.selectedIds, isEmpty);

      selection.toggle(2);
      selection.exit();
      expect(selection.isActive, isFalse);
      expect(selection.selectedIds, isEmpty);
    });
  });
}
