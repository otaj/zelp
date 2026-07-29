import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/output/output_folder.dart';

void main() {
  group('OutputFolder', () {
    test('default label', () {
      expect(OutputFolder.defaults.label, 'Downloads/Zelp');
    });

    test('normalizes incomplete custom folders to defaults', () {
      expect(
        OutputFolder.normalized(
          kind: OutputFolderKind.androidTree,
          treeUri: '',
        ),
        OutputFolder.defaults,
      );
      expect(
        OutputFolder.normalized(
          kind: OutputFolderKind.filesystem,
        ),
        OutputFolder.defaults,
      );
    });

    test('androidTreeUriOrNull only for tree kind', () {
      final OutputFolder tree = OutputFolder.normalized(
        kind: OutputFolderKind.androidTree,
        treeUri: 'content://tree/abc',
        displayName: 'GPS',
      );
      expect(tree.androidTreeUriOrNull, 'content://tree/abc');
      expect(tree.label, 'GPS');
      expect(OutputFolder.defaults.androidTreeUriOrNull, isNull);
    });

    test('filesystem label prefers path over display name', () {
      final OutputFolder folder = OutputFolder.normalized(
        kind: OutputFolderKind.filesystem,
        filesystemPath: '/tmp/out',
        displayName: 'ignored-when-path-set',
      );
      expect(folder.label, '/tmp/out');
      expect(folder.androidTreeUriOrNull, isNull);
    });

    test('equality includes kind and location fields', () {
      final OutputFolder a = OutputFolder.normalized(
        kind: OutputFolderKind.androidTree,
        treeUri: 'content://tree/a',
        displayName: 'A',
      );
      final OutputFolder b = OutputFolder.normalized(
        kind: OutputFolderKind.androidTree,
        treeUri: 'content://tree/a',
        displayName: 'A',
      );
      final OutputFolder c = OutputFolder.normalized(
        kind: OutputFolderKind.androidTree,
        treeUri: 'content://tree/b',
        displayName: 'A',
      );
      expect(a, b);
      expect(a, isNot(equals(c)));
    });
  });

  group('ClearFolderWarning', () {
    test('empty folder does not confirm', () {
      const ClearFolderWarning warning = ClearFolderWarning(0);
      expect(warning.shouldConfirm, isFalse);
      expect(warning.message, 'This folder is empty.');
    });

    test('singular and plural file counts', () {
      expect(
        const ClearFolderWarning(1).message,
        'This folder contains 1 file. Delete them?',
      );
      expect(
        const ClearFolderWarning(7).message,
        'This folder contains 7 files. Delete them?',
      );
      expect(const ClearFolderWarning(7).shouldConfirm, isTrue);
    });
  });
}
