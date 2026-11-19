# Design System — "Minimalismo editorial sacro"

Inspiração: missais tradicionais. Tipografia refinada, margens generosas, ícones lineares,
nenhuma poluição visual. Implementação: [`app/lib/core/theme.dart`](../app/lib/core/theme.dart).

## Cores

| Token | Claro (Pergaminho) | Escuro (Modo Igreja) |
|---|---|---|
| Fundo | `#FAF8F5` | `#121212` |
| Superfície | `#F3EFE8` | `#1C1B19` |
| Fio/contorno | `#E4DDD0` | `#2E2C28` |
| Texto | `#1E1E1E` (carvão) | `#EDE6D8` (vela) |
| Texto secundário | `#5C5852` | `#A59E92` |
| Dourado fosco | `#B8860B` | `#D9B35A` |

### Cor litúrgica → acento da interface

A cor do dia exibido vira o `primary` do tema (transição de 600 ms), dessaturada para
harmonizar com o dourado:

| Cor | Claro | Escuro |
|---|---|---|
| Verde | `#4F7A55` | `#8DB592` |
| Roxo | `#6B4C82` | `#B39DCB` |
| Branco/Dourado | `#B8860B` | `#D9B35A` |
| Vermelho | `#9E2B2B` | `#E08A80` |
| Rosa | `#B5677D` | `#E3A6B8` |

## Tipografia

- Títulos: serifada (EB Garamond, se empacotada → Noto Serif / New York do sistema).
- Leitura: serifada ou sem serifa (escolha do usuário), 18 px, entrelinha 1,6 (ajustável 1,3–2,1).
- Interface: sem serifa (Inter → Roboto / SF).
- Rótulos "eyebrow" em versalete com espaçamento 1,6 (ex.: `PRIMEIRA LEITURA`).
- Escala de texto do usuário: 85%–160%, somada à do sistema.

## Espaçamento e forma

Escala 4 · 8 · 16 · 24 · 32 · 48. Margem lateral: 22 px (celular), 48 px (tablet), coluna de
680 px centralizada (telas largas). Cartões com raio 14 e fio de 1 px, sem sombra.
Ornamento `CrossDivider`: fio dourado com ✝ ao centro.

## Componentes

`LiturgyHeader` · `AudioPlayerBar` · `ReadingCard` / `PsalmCard` (refrão com filete lateral na
cor litúrgica) · `HomilySection` (abas) · `LectioDivinaScreen` · `DecadeBeads` (10 contas em
arco + conta do Pai-Nosso dourada) · `StreakBadge` / `StreakCalendar` · `SacredArtImage`
(legenda obrigatória) · `SourceAttribution`.

## Acessibilidade

Todo botão de ícone tem `tooltip`; cabeçalhos com `Semantics(header)`; o passo do terço é
`liveRegion` (leitores de tela anunciam a conta); alvos ≥ 48 px; botão do terço com 72 px de
altura, posicionado na zona do polegar; contraste AA em ambos os temas.
