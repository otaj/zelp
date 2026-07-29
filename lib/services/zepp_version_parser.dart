import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:zelp/domain/exceptions.dart';

/// APKMirror HTML parsing for Zepp Play version (`name_code`).
class ZeppVersionParser {
  const ZeppVersionParser();

  static const String expectedListingTitle = 'Download Zepp APKs for Android';
  static const String expectedDetailTitle = 'APK Download by Zepp, Inc.';

  /// Parses listing HTML and returns the relative or absolute href of the
  /// latest version detail page.
  String parseLatestVersionHref(String listingHtml) {
    final Document doc = html_parser.parse(listingHtml);
    final String title = doc.querySelector('title')?.text ?? '';
    if (!title.contains(expectedListingTitle)) {
      throw DeviceException(
        'Unexpected APKMirror listing page (possible block)',
        code: 'zepp-version-listing',
      );
    }
    final String? href = findLatestVersionHref(doc);
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
    final Document doc = html_parser.parse(detailHtml);
    final String title = doc.querySelector('title')?.text ?? '';
    if (!title.contains(expectedDetailTitle)) {
      throw DeviceException(
        'Unexpected APKMirror detail page (possible block)',
        code: 'zepp-version-detail',
      );
    }
    return parseVersionFromDetail(doc);
  }

  String? findLatestVersionHref(Document listingDoc) {
    final List<Element> headers = listingDoc.querySelectorAll('div.widgetHeader');
    for (final Element header in headers) {
      if (!header.text.contains('All versions')) continue;
      final Element? parent = header.parent;
      if (parent == null) continue;
      final Element? link = parent.querySelector('a.fontBlack');
      final String? href = link?.attributes['href'];
      if (href != null && href.isNotEmpty) return href;
    }
    final Element? fallback = listingDoc.querySelector('a.fontBlack');
    return fallback?.attributes['href'];
  }

  String parseVersionFromDetail(Document detailDoc) {
    for (final Element h3 in detailDoc.querySelectorAll('h3')) {
      final String text = h3.text.trim();
      if (!text.startsWith('Download Zepp ')) continue;
      final String versionName = text.substring('Download Zepp '.length).trim();
      final Element? parent = h3.parent;
      if (parent == null) break;
      final List<Element> rows = parent.querySelectorAll('.table-row');
      if (rows.length < 2) break;
      final Element? codeSpan = rows[1].querySelector('span.colorLightBlack');
      final String? versionCode = codeSpan?.text.trim();
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
