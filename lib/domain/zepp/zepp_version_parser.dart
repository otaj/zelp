import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../services/exceptions.dart';

/// Pure APKMirror HTML parsing for Zepp Play version (`name_code`).
class ZeppVersionParser {
  const ZeppVersionParser();

  static const expectedListingTitle = 'Download Zepp APKs for Android';
  static const expectedDetailTitle = 'APK Download by Zepp, Inc.';

  /// Parses listing HTML and returns the relative or absolute href of the
  /// latest version detail page.
  String parseLatestVersionHref(String listingHtml) {
    final doc = html_parser.parse(listingHtml);
    final title = doc.querySelector('title')?.text ?? '';
    if (!title.contains(expectedListingTitle)) {
      throw DeviceException(
        'Unexpected APKMirror listing page (possible block)',
        code: 'zepp-version-listing',
      );
    }
    final href = findLatestVersionHref(doc);
    if (href == null || href.isEmpty) {
      throw DeviceException(
        'Could not find latest Zepp version link on APKMirror',
        code: 'zepp-version-link',
      );
    }
    return href;
  }

  /// Parses a version detail page into `name_code`.
  String parseVersionFromDetailHtml(String detailHtml) {
    final doc = html_parser.parse(detailHtml);
    final title = doc.querySelector('title')?.text ?? '';
    if (!title.contains(expectedDetailTitle)) {
      throw DeviceException(
        'Unexpected APKMirror detail page (possible block)',
        code: 'zepp-version-detail',
      );
    }
    return parseVersionFromDetail(doc);
  }

  String? findLatestVersionHref(Document listingDoc) {
    final headers = listingDoc.querySelectorAll('div.widgetHeader');
    for (final header in headers) {
      if (!header.text.contains('All versions')) continue;
      final parent = header.parent;
      if (parent == null) continue;
      final link = parent.querySelector('a.fontBlack');
      final href = link?.attributes['href'];
      if (href != null && href.isNotEmpty) return href;
    }
    final fallback = listingDoc.querySelector('a.fontBlack');
    return fallback?.attributes['href'];
  }

  String parseVersionFromDetail(Document detailDoc) {
    for (final h3 in detailDoc.querySelectorAll('h3')) {
      final text = h3.text.trim();
      if (!text.startsWith('Download Zepp ')) continue;
      final versionName = text.substring('Download Zepp '.length).trim();
      final parent = h3.parent;
      if (parent == null) break;
      final rows = parent.querySelectorAll('.table-row');
      if (rows.length < 2) break;
      final codeSpan = rows[1].querySelector('span.colorLightBlack');
      final versionCode = codeSpan?.text.trim();
      if (versionName.isEmpty || versionCode == null || versionCode.isEmpty) {
        break;
      }
      return '${versionName}_$versionCode';
    }

    throw DeviceException(
      'Could not parse Zepp version name/code from APKMirror',
      code: 'zepp-version-parse',
    );
  }

  /// Resolves a possibly-relative APKMirror href against [origin].
  Uri resolveDetailUrl(
    String href, {
    String origin = 'https://www.apkmirror.com',
  }) {
    if (href.startsWith('http')) return Uri.parse(href);
    return Uri.parse('$origin$href');
  }
}
