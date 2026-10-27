"""Export existing Flutter Material glyphs; requires fonttools only at generation time."""
import argparse
from pathlib import Path
import re
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

parser = argparse.ArgumentParser()
parser.add_argument('--flutter-root', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
names = sorted(set(re.findall(r'Icons\.([A-Za-z_0-9]+)',
    '\n'.join(p.read_text() for p in (root / 'lib').rglob('*.dart')))))
icons = (args.flutter_root / 'packages/flutter/lib/src/material/icons.dart').read_text()
fonts = args.flutter_root / 'bin/cache/artifacts/material_fonts'
font = TTFont(fonts / 'MaterialIcons-Regular.otf')
glyphs, cmap = font.getGlyphSet(), font.getBestCmap()
scale = 24 / font['head'].unitsPerEm
entries = []
for name in names:
    match = re.search(r'static const IconData ' + name + r' = IconData\(\s*(0x[0-9a-f]+)', icons)
    if not match:
        raise ValueError('Missing icon: ' + name)
    code = int(match[1], 16)
    def number(n):
        return format(n, '.3f').rstrip('0').rstrip('.') if n else '0'
    pen = SVGPathPen(glyphs, ntos=number)
    glyphs[cmap[code]].draw(TransformPen(pen, (scale, 0, 0, -scale, 0, 24)))
    entries.append(f"  {hex(code)}: '{pen.getCommands()}', // {name}")
output = root / 'lib/ui/core/widgets/material_icon_paths.dart'
output.write_text('// Material Icons outlines from the Flutter SDK, Copyright Google, Apache-2.0.\n'
    '// See tools/icons/MaterialIcons_LICENSE.txt. Normalized to a 24px canvas.\n'
    '// Generated paths retain the existing icon silhouettes.\n'
    'const materialIconPaths = <int, String>{\n' + '\n'.join(entries) + '\n};\n')
(root / 'tools/icons/MaterialIcons_LICENSE.txt').write_text((fonts / 'MaterialIcons_LICENSE.txt').read_text())
print(f'Exported {len(entries)} icons. Run dart format on {output}.')
