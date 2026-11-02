import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Based on Lucide pen-line; the underline path is intentionally omitted.
// https://github.com/lucide-icons/lucide/blob/main/icons/pen-line.svg
// ISC License
// Copyright (c) 2026 Lucide Icons and Contributors
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
// ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
// ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
// OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

/// 모든 글쓰기·수정 아이콘에 공통으로 사용하는 둥근 펜 모양이다.
/// 슬롯 크기와 관계없이 홈 아이콘과 같은 실제 2px 선을 유지한다.
class EditIcon extends StatelessWidget {
  const EditIcon({super.key, this.size = 17.5, this.color}) : assert(size > 0);
  final double size;
  final Color? color;
  static const _path =
      'M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z';

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">'
    '<path d="$_path" stroke="black" stroke-width="${2 * 24 / size}" '
    'stroke-linecap="round" stroke-linejoin="round"/></svg>',
    width: size,
    height: size,
    clipBehavior: Clip.none,
    colorFilter: ColorFilter.mode(
      color ?? IconTheme.of(context).color ?? Colors.white,
      BlendMode.srcIn,
    ),
  );
}
