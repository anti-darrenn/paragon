# Writes Paragon's flat illustrations. Marker colours are swapped at run
# time by `Illustration`'s ColorMapper:
#   INK    #101010  outlines            -> palette.textPrimary
#   PAPER  #FEFEFE  object fills        -> palette.surface
#   SHADE  #C8C8C8  shadows, back faces -> palette.track
#   LINE   #808080  soft lines          -> palette.border
#   ACCENT #FF00FF  the accent          -> the subject or tone colour
# Fixed brand colours that read on both themes are allowed as they are:
#   #FF7700 primary, #8B5CF6 secondary, #E3B341 gold.
import os, sys

INK, PAPER, SHADE, LINE, ACCENT = '#101010', '#FEFEFE', '#C8C8C8', '#808080', '#FF00FF'
ORANGE, VIOLET, GOLD = '#FF7700', '#8B5CF6', '#E3B341'
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'

def svg(w, h, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" '
            f'width="{w}" height="{h}" fill="none" stroke-linecap="round" '
            f'stroke-linejoin="round">{body}</svg>\n')

def stroke(c=INK, w=3):
    return f'stroke="{c}" stroke-width="{w}"'

def ground(cx, cy, rx, ry=6):
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{SHADE}"/>'

def sparkle(cx, cy, r, c=ACCENT, o=1):
    return (f'<path d="M{cx} {cy-r}Q{cx} {cy} {cx+r} {cy}Q{cx} {cy} {cx} {cy+r}'
            f'Q{cx} {cy} {cx-r} {cy}Q{cx} {cy} {cx} {cy-r}Z" fill="{c}" fill-opacity="{o}"/>')

def bit(x, y, rot, c):
    return f'<rect x="{x-4}" y="{y-2}" width="8" height="4" rx="1" fill="{c}" transform="rotate({rot} {x} {y})"/>'

art = {}

art['celebrate'] = svg(240, 160, ''.join([
    ground(120, 136, 58),
    f'<path d="M92 48H80C76 48 74 52 74 56C74 68 82 76 94 76" {stroke()}/>',
    f'<path d="M148 48H160C164 48 166 52 166 56C166 68 158 76 146 76" {stroke()}/>',
    f'<path d="M92 36H148V62C148 82 136 96 120 96C104 96 92 82 92 62Z" fill="{GOLD}" {stroke()}/>',
    f'<path d="M106 46V64" stroke="{PAPER}" stroke-width="5" stroke-opacity="0.7"/>',
    f'<rect x="112" y="96" width="16" height="16" fill="{GOLD}" {stroke()}/>',
    f'<rect x="96" y="112" width="48" height="16" rx="4" fill="{PAPER}" {stroke()}/>',
    sparkle(58, 40, 10), sparkle(186, 32, 8), sparkle(196, 86, 6), sparkle(46, 96, 6),
    bit(74, 18, 20, ORANGE), bit(170, 60, -30, VIOLET), bit(150, 16, 45, ACCENT),
    bit(80, 68, -15, VIOLET), bit(204, 118, 30, ORANGE), bit(36, 124, -40, ACCENT),
    bit(30, 60, 60, ORANGE), bit(214, 52, 10, GOLD),
]))

art['empty'] = svg(240, 160, ''.join([
    ground(120, 138, 66),
    f'<path d="M76 76L60 52L104 36L120 60Z" fill="{PAPER}" {stroke()}/>',
    f'<path d="M164 76L180 52L136 36L120 60Z" fill="{PAPER}" {stroke()}/>',
    f'<path d="M76 76L120 60L164 76L120 92Z" fill="{SHADE}" {stroke()}/>',
    f'<path d="M76 76L120 92L164 76V118L120 134L76 118Z" fill="{PAPER}" {stroke()}/>',
    f'<path d="M120 92V134" {stroke()}/>',
    f'<path d="M92 104L106 109" {stroke(LINE, 3)}/>',
    f'<circle cx="104" cy="20" r="3" fill="{ACCENT}" fill-opacity="0.6"/>',
    f'<circle cx="120" cy="12" r="3.5" fill="{ACCENT}"/>',
    f'<circle cx="136" cy="20" r="3" fill="{ACCENT}" fill-opacity="0.6"/>',
]))

art['search_empty'] = svg(240, 160, ''.join([
    ground(120, 140, 64),
    f'<rect x="66" y="22" width="84" height="108" rx="8" fill="{PAPER}" {stroke()}/>',
    f'<path d="M82 46H134M82 62H122M82 78H128M82 94H112" {stroke(LINE, 4)}/>',
    f'<circle cx="152" cy="94" r="26" fill="{ACCENT}" fill-opacity="0.15" {stroke(INK, 4)}/>',
    f'<path d="M171 113L192 134" {stroke(INK, 9)}/>',
    f'<path d="M140 84C142 78 148 74 154 74" stroke="{PAPER}" stroke-width="4" stroke-opacity="0.8"/>',
]))

art['offline'] = svg(240, 160, ''.join([
    ground(120, 138, 60),
    f'<path d="M82 112H164C180 112 190 100 190 87C190 73 178 63 164 65C160 49 146 39 130 39C112 39 98 51 96 67C84 67 70 77 70 91C70 103 78 112 82 112Z" fill="{PAPER}" {stroke()}/>',
    f'<path d="M108 84C116 77 126 77 134 84M114 92C118 89 124 89 128 92" {stroke(LINE, 4)}/>',
    f'<circle cx="121" cy="99" r="3" fill="{LINE}"/>',
    f'<path d="M80 30L168 122" {stroke(ACCENT, 7)}/>',
]))

art['not_found'] = svg(240, 160, ''.join([
    ground(120, 140, 56),
    f'<rect x="116" y="34" width="8" height="104" rx="2" fill="{SHADE}" {stroke()}/>',
    f'<path d="M64 46H116V72H64L52 59Z" fill="{ACCENT}" {stroke()}/>',
    f'<path d="M72 59H104" stroke="{PAPER}" stroke-width="4" stroke-opacity="0.8"/>',
    f'<path d="M124 82H174L186 95L174 108H124Z" fill="{PAPER}" {stroke()}/>',
    f'<path d="M136 95H166" {stroke(LINE, 4)}/>',
    f'<path d="M84 140C86 134 90 132 94 132M150 140C152 135 156 133 160 134" {stroke(LINE, 3)}/>',
    sparkle(184, 40, 7, ACCENT, 0.7), sparkle(46, 108, 5, ACCENT, 0.7),
]))

art['error'] = svg(240, 160, ''.join([
    ground(120, 140, 58),
    f'<path d="M76 30C76 25 80 22 84 22H140L164 46V126C164 131 160 134 156 134H84C80 134 76 131 76 126Z" fill="{PAPER}" {stroke()}/>',
    f'<path d="M140 22V46H164" fill="{SHADE}" {stroke()}/>',
    f'<path d="M120 56L148 106H92Z" fill="{ACCENT}" fill-opacity="0.2" {stroke()}/>',
    f'<path d="M120 72V88" {stroke(INK, 4)}/>',
    f'<circle cx="120" cy="97" r="2.5" fill="{INK}"/>',
]))

art['welcome'] = svg(320, 240, ''.join([
    ground(160, 214, 112, 8),
    f'<path d="M64 188C100 182 132 186 160 200C188 186 220 182 256 188V198C220 192 188 196 160 210C132 196 100 192 64 198Z" fill="{ACCENT}" {stroke()}/>',
    f'<path d="M160 198C136 186 104 182 72 186V94C104 90 136 94 160 106Z" fill="{PAPER}" {stroke()}/>',
    f'<path d="M160 198C184 186 216 182 248 186V94C216 90 184 94 160 106Z" fill="{PAPER}" {stroke()}/>',
    f'<path d="M86 116C106 113 126 115 146 121M86 134C106 131 126 133 146 139M86 152C102 150 116 151 130 155" {stroke(LINE, 3)}/>',
    f'<path d="M174 121C194 115 214 113 234 116M174 139C194 133 214 131 234 134M174 157C190 152 204 150 220 151" {stroke(LINE, 3)}/>',
    f'<path d="M96 36L128 62L88 72Z" fill="{ORANGE}" {stroke()}/>',
    f'<path d="M146 30H184M158 30V58M174 30C174 46 176 54 183 58" {stroke(INK, 4)}/>',
    f'<ellipse cx="244" cy="54" rx="28" ry="10" transform="rotate(30 244 54)" {stroke(INK, 2.5)}/>',
    f'<ellipse cx="244" cy="54" rx="28" ry="10" transform="rotate(-30 244 54)" {stroke(INK, 2.5)}/>',
    f'<ellipse cx="244" cy="54" rx="28" ry="10" transform="rotate(90 244 54)" {stroke(INK, 2.5)}/>',
    f'<circle cx="244" cy="54" r="5" fill="{VIOLET}"/>',
    f'<path d="M274 104V118L262 140C260 146 264 150 270 150H294C300 150 304 146 302 140L290 118V104Z" fill="{PAPER}" {stroke()}/>',
    f'<path d="M266 132H298L302 140C304 146 300 150 294 150H270C264 150 260 146 262 140Z" fill="{ACCENT}"/>',
    f'<path d="M274 104V118L262 140C260 146 264 150 270 150H294C300 150 304 146 302 140L290 118V104Z" {stroke()}/>',
    f'<path d="M270 104H294" {stroke()}/>',
    sparkle(40, 70, 9, ACCENT), sparkle(206, 22, 7, ORANGE), sparkle(296, 196, 6, VIOLET),
    sparkle(30, 160, 5, ORANGE),
]))

# Subject motifs: 96 x 96, the accent is the subject's colour.
def motif(body):
    return svg(96, 96, body)

art['subject_mathematics'] = motif(''.join([
    f'<circle cx="64" cy="32" r="16" fill="{ACCENT}" fill-opacity="0.5" {stroke()}/>',
    f'<path d="M14 82L40 36L66 82Z" fill="{PAPER}" {stroke()}/>',
    f'<rect x="54" y="56" width="28" height="28" rx="3" fill="{ACCENT}" {stroke()}/>',
]))
art['subject_further_mathematics'] = motif(''.join([
    f'<path d="M16 82C24 86 30 80 32 66L36 30C38 16 44 10 52 14" {stroke(INK, 4)}/>',
    f'<path d="M62 30H56V72H62M84 30H90V72H84" {stroke()}/>',
    f'<circle cx="66" cy="42" r="4" fill="{ACCENT}"/><circle cx="80" cy="42" r="4" fill="{ACCENT}" fill-opacity="0.5"/>',
    f'<circle cx="66" cy="60" r="4" fill="{ACCENT}" fill-opacity="0.5"/><circle cx="80" cy="60" r="4" fill="{ACCENT}"/>',
]))
art['subject_physics'] = motif(''.join([
    ''.join(f'<ellipse cx="48" cy="48" rx="36" ry="13" transform="rotate({a} 48 48)" {stroke(INK, 3)}/>' for a in (0, 60, 120)),
    f'<circle cx="48" cy="48" r="8" fill="{ACCENT}" {stroke()}/>',
    f'<circle cx="84" cy="48" r="4.5" fill="{ACCENT}"/>',
]))
art['subject_chemistry'] = motif(''.join([
    f'<path d="M40 12V38L18 76C15 82 19 86 25 86H71C77 86 81 82 78 76L56 38V12Z" fill="{PAPER}"/>',
    f'<path d="M26 64H70L78 78C80 83 77 86 71 86H25C19 86 16 83 18 78Z" fill="{ACCENT}"/>',
    f'<path d="M40 12V38L18 76C15 82 19 86 25 86H71C77 86 81 82 78 76L56 38V12M36 12H60" {stroke()}/>',
    f'<circle cx="44" cy="52" r="4" fill="{ACCENT}" fill-opacity="0.6"/><circle cx="54" cy="44" r="3" fill="{ACCENT}" fill-opacity="0.6"/>',
]))
art['subject_government'] = motif(''.join([
    f'<path d="M12 34L48 12L84 34Z" fill="{ACCENT}" {stroke()}/>',
    f'<rect x="16" y="34" width="64" height="8" fill="{PAPER}" {stroke()}/>',
    ''.join(f'<rect x="{x}" y="42" width="8" height="32" fill="{PAPER}" {stroke(INK, 2.5)}/>' for x in (22, 36, 52, 66)),
    f'<rect x="12" y="74" width="72" height="10" rx="2" fill="{ACCENT}" fill-opacity="0.5" {stroke()}/>',
]))
art['subject_biology'] = motif(''.join([
    f'<path d="M18 80C18 42 42 18 80 16C80 54 56 80 18 80Z" fill="{ACCENT}" fill-opacity="0.5" {stroke()}/>',
    f'<path d="M18 80L64 32M40 58L38 42M52 46L64 50" {stroke(INK, 2.5)}/>',
]))
art['subject_economics'] = motif(''.join([
    f'<path d="M14 14V82H84" {stroke()}/>',
    f'<rect x="24" y="58" width="12" height="24" fill="{ACCENT}" fill-opacity="0.5" {stroke(INK, 2.5)}/>',
    f'<rect x="44" y="44" width="12" height="38" fill="{ACCENT}" fill-opacity="0.75" {stroke(INK, 2.5)}/>',
    f'<rect x="64" y="28" width="12" height="54" fill="{ACCENT}" {stroke(INK, 2.5)}/>',
    f'<path d="M22 46L40 32L52 38L74 16M64 16H74V26" {stroke(INK, 3)}/>',
]))
art['subject_english_language'] = motif(''.join([
    f'<path d="M12 72H50M12 84H40" {stroke(LINE, 4)}/>',
    f'<path d="M32 66C42 40 60 22 86 12C80 38 64 56 38 66Z" fill="{ACCENT}" fill-opacity="0.5" {stroke()}/>',
    f'<path d="M32 66L22 80M40 58L64 32" {stroke()}/>',
]))
art['subject_commerce'] = motif(''.join([
    f'<path d="M34 34V28C34 16 62 16 62 28V34" {stroke()}/>',
    f'<rect x="18" y="34" width="60" height="48" rx="6" fill="{ACCENT}" fill-opacity="0.5" {stroke()}/>',
    f'<circle cx="72" cy="74" r="13" fill="{GOLD}" {stroke()}/>',
    f'<path d="M72 68V80" {stroke(INK, 2.5)}/>',
]))
art['subject_music'] = motif(''.join([
    f'<path d="M36 22L76 12V20L36 30Z" fill="{INK}"/>',
    f'<path d="M36 26V68M76 16V58" {stroke()}/>',
    f'<ellipse cx="28" cy="70" rx="10" ry="8" fill="{ACCENT}" {stroke()}/>',
    f'<ellipse cx="68" cy="60" rx="10" ry="8" fill="{ACCENT}" {stroke()}/>',
]))
art['subject_generic'] = motif(''.join([
    ground(48, 84, 40, 4),
    f'<rect x="16" y="62" width="64" height="14" rx="3" fill="{ACCENT}" {stroke()}/>',
    f'<rect x="22" y="46" width="56" height="16" rx="3" fill="{PAPER}" {stroke()}/>',
    f'<rect x="12" y="30" width="60" height="16" rx="3" fill="{ACCENT}" fill-opacity="0.5" {stroke()}/>',
    f'<path d="M30 54H62" {stroke(LINE, 3)}/>',
]))

os.makedirs(OUT, exist_ok=True)
for name, body in art.items():
    with open(os.path.join(OUT, name + '.svg'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(body)
    print(name, len(body))
