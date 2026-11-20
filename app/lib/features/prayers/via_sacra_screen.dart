import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../../services/reading_audio_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/common.dart';
import '../../widgets/global_audio_mini_player.dart';
import '../../widgets/reading_appearance_button.dart';
import '../../widgets/sacred_art_header.dart';

class _Station {
  const _Station(this.number, this.title, this.meditation, this.prayer);

  final int number;
  final String title;
  final String meditation;
  final String prayer;
}

/// Via Sacra completa (14 Estações), inspirada nas meditações clássicas de
/// Santo Afonso Maria de Ligório (Domínio Público — 1761), 100% offline.
class ViaSacraScreen extends StatefulWidget {
  const ViaSacraScreen({super.key});

  @override
  State<ViaSacraScreen> createState() => _ViaSacraScreenState();
}

class _ViaSacraScreenState extends State<ViaSacraScreen> {
  int _index = 0;

  static const _stations = <_Station>[
    _Station(
      1,
      'Jesus é condenado à morte',
      'Considera como Jesus, já flagelado e coroado de espinhos, foi injustamente condenado por Pilatos a morrer crucificado. Aceitou a sentença em silêncio por amor de nós.',
      'Meu Jesus adorável, não foi Pilatos, mas os meus pecados que vos condenaram à morte. Pelo mérito deste doloroso passo, peço-vos que me assistais no caminho que minha alma percorre rumo à eternidade. Amo-vos sobre todas as coisas e arrependo-me de vos ter ofendido.',
    ),
    _Station(
      2,
      'Jesus carrega a cruz às costas',
      'Considera como Jesus, caminhando com a cruz sobre os ombros feridos, pensava em nós e oferecia ao Pai eterno a morte que ia padecer pela nossa salvação.',
      'Meu amantíssimo Jesus, abraço todas as tribulações que destinastes para mim até à morte e peço-vos, pelos méritos da pena que sofrestes carregando a cruz, que me deis força para levar a minha com paciência e amor.',
    ),
    _Station(
      3,
      'Jesus cai pela primeira vez',
      'Considera esta primeira queda de Jesus sob o peso da cruz. A carne dilacerada pelos açoites, a cabeça coroada de espinhos e o cansaço extremo fizeram-No cair por terra.',
      'Meu Jesus, não é o peso da cruz, mas o peso dos meus pecados que vos faz sofrer tantas dores. Por esta primeira queda, livrai-me de cair em pecado mortal. Amo-vos de todo o coração e nunca mais quero ofender-vos.',
    ),
    _Station(
      4,
      'Jesus encontra sua Mãe Santíssima',
      'Considera o encontro do Filho e da Mãe no caminho do Calvário. Jesus e Maria olharam-se mutuamente, e os seus olhares foram como espadas que traspassaram ambos os corações.',
      'Meu amantíssimo Jesus, pela dor que sentistes neste encontro, concedei-me a graça de ser verdadeiramente devoto de vossa Mãe Santíssima. E vós, ó Rainha das Dores, alcançai-me uma contínua e terna lembrança da Paixão do vosso Filho.',
    ),
    _Station(
      5,
      'Simão Cirineu ajuda Jesus a carregar a cruz',
      'Considera como os soldados, vendo Jesus quase a expirar, obrigaram Simão de Cirene a levar a cruz atrás do Senhor para que não morresse antes de chegar ao Calvário.',
      'Meu dulcíssimo Jesus, não quero recusar a cruz como o Cirineu; antes a aceito e abraço de bom grado. Aceito especialmente a morte que me destinastes, com todas as dores que a acompanharem, unindo-a à vossa morte.',
    ),
    _Station(
      6,
      'Verônica enxuga o rosto de Jesus',
      'Considera como a piedosa Verônica, vendo Jesus fatigado e com o rosto banhado de suor e sangue, ofereceu-Lhe um pano no qual o Senhor deixou impressa a sua santa Face.',
      'Meu Jesus, o vosso rosto era outrora o mais belo; agora está desfigurado pelas feridas e pelo sangue. Também a minha alma se desfigurou pelo pecado. Só vós podeis restituir-lhe a antiga beleza: fazei-o pelos méritos da vossa Paixão.',
    ),
    _Station(
      7,
      'Jesus cai pela segunda vez',
      'Considera a segunda queda de Jesus sob a cruz, na qual se renovam todas as dores das chagas da cabeça e de todo o corpo do nosso aflito Senhor.',
      'Meu mansíssimo Jesus, quantas vezes me perdoastes e quantas vezes tornei a cair e a ofender-vos! Pelos méritos desta nova queda, ajudai-me a perseverar na vossa graça até à morte.',
    ),
    _Station(
      8,
      'Jesus consola as mulheres de Jerusalém',
      'Considera como aquelas piedosas mulheres choravam de compaixão ao ver Jesus coberto de sangue, e Ele lhes disse: "Não choreis por mim, mas chorai por vós mesmas e por vossos filhos".',
      'Meu aflito Jesus, choro as ofensas que cometi contra vós, não só pelos castigos que mereci, mas sobretudo pelo desgosto que causei a vós, que tanto me amastes.',
    ),
    _Station(
      9,
      'Jesus cai pela terceira vez',
      'Considera a terceira queda de Jesus Cristo. A sua fraqueza era extrema e a crueldade dos algozes excessiva, querendo fazê-Lo apressar o passo quando já mal podia mover-se.',
      'Meu Jesus maltratado, pelos méritos da fraqueza que quisestes padecer caminhando para o Calvário, dai-me tanta fortaleza que eu vença todo respeito humano e todas as minhas más inclinações.',
    ),
    _Station(
      10,
      'Jesus é despojado de suas vestes',
      'Considera a violência com que arrancaram as vestes de Jesus: estando coladas às carnes chagadas, arrancaram com elas a própria pele do seu corpo santíssimo.',
      'Meu inocente Jesus, pelos méritos da dor que sofrestes neste despojamento, ajudai-me a despojar-me de todo afeto às coisas criadas, para colocar todo o meu amor somente em vós.',
    ),
    _Station(
      11,
      'Jesus é pregado na cruz',
      'Considera como Jesus, lançado sobre a cruz, estende os braços e oferece ao Pai eterno o sacrifício da sua vida pela nossa salvação; os algozes pregam-No e erguem a cruz ao alto.',
      'Meu Jesus desprezado, pregai o meu coração aos vossos pés, para que fique sempre unido a vós pelo amor e jamais se separe de vós.',
    ),
    _Station(
      12,
      'Jesus morre na cruz',
      'Considera como Jesus, depois de três horas de agonia na cruz, consumido de dores, abandona o seu corpo ao peso da morte e, inclinando a cabeça, entrega o espírito ao Pai.',
      'Ó meu Jesus morto, beijo devotamente esta cruz na qual morrestes por mim. Eu merecia uma morte má pelos meus pecados, mas a vossa morte é a minha esperança. Fazei-me morrer abraçado aos vossos pés e abrasado no vosso amor.',
    ),
    _Station(
      13,
      'Jesus é descido da cruz e entregue a sua Mãe',
      'Considera como, expirando o Senhor, foi descido da cruz por dois dos seus discípulos, José e Nicodemos, e depositado nos braços de sua Mãe aflita, que O recebeu com ternura indizível.',
      'Ó Mãe das Dores, pelo amor deste Filho, aceitai-me como vosso servo e rogai por mim. E vós, meu Redentor, já que morrestes por mim, fazei que eu vos ame, pois não desejo senão a vós.',
    ),
    _Station(
      14,
      'Jesus é sepultado',
      'Considera como os discípulos levaram Jesus ao sepulcro, acompanhados de sua Mãe Santíssima, que o compôs com as próprias mãos; fechada a pedra, todos se retiraram em silêncio.',
      'Ó meu Jesus sepultado, beijo esta pedra que vos encerrou; mas vós ressuscitastes ao terceiro dia. Pela vossa Ressurreição, fazei-me ressuscitar glorioso convosco no último dia para vos louvar e amar eternamente no céu. Amém.',
    ),
  ];

  void _listen(_Station st) {
    final settings = context.read<SettingsService>();
    final speech =
        '${st.number}ª Estação: ${st.title}. '
        'Nós vos adoramos, ó Cristo, e vos bendizemos. Porque pela vossa Santa Cruz remistes o mundo. '
        '${st.meditation} '
        '${st.prayer}';
    context.read<ReadingAudioController>().playSingle(
      ReadingSegment(
        id: 'via-sacra-${st.number}',
        title: '${st.number}ª Estação',
        subtitle: st.title,
        text: speech,
        language: 'pt-BR',
      ),
      speed: settings.ttsSpeed,
    );
  }

  Future<void> _pickStation() async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Estações da Via Sacra', style: Theme.of(ctx).textTheme.titleLarge),
          ),
          for (var i = 0; i < _stations.length; i++)
            ListTile(
              leading: CircleAvatar(radius: 16, child: Text('${_stations[i].number}')),
              title: Text(_stations[i].title),
              trailing: i == _index ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, i),
            ),
        ],
      ),
    );
    if (chosen != null && mounted) setState(() => _index = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final st = _stations[_index];
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final pad = VsSpacing.page(context);
    final art = context.read<AppServices>().content.art['dolorosos-4'];

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _pickStation,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text('Via Sacra · ${st.number}/14'), const Icon(Icons.arrow_drop_down)],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Ouvir estação (TTS)',
            icon: const Icon(Icons.headphones_outlined),
            onPressed: () => _listen(st),
          ),
          const ReadingAppearanceButton(),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(value: st.number / _stations.length),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.sm, pad, VsSpacing.xxl),
        children: [
          SacredArtBanner(
            title: '${st.number}ª Estação · ${st.title}',
            subtitle: 'SANTO AFONSO MARIA DE LIGÓRIO',
            art: art,
          ),
          const SizedBox(height: VsSpacing.md),
          Eyebrow('${st.number}ª Estação'),
          const SizedBox(height: 6),
          Text(st.title, style: t.headlineMedium),
          const SizedBox(height: VsSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(VsSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'V. Nós vos adoramos, ó Cristo, e vos bendizemos.',
                    style: t.titleSmall?.copyWith(color: cs.primary),
                  ),
                  const SizedBox(height: 4),
                  Text('R. Porque pela vossa Santa Cruz remistes o mundo.', style: t.titleSmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: VsSpacing.md),
          SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Meditação'),
                const SizedBox(height: 6),
                Text(st.meditation, style: t.bodyLarge),
                const SizedBox(height: VsSpacing.md),
                const Eyebrow('Oração'),
                const SizedBox(height: 6),
                Text(st.prayer, style: t.bodyLarge),
              ],
            ),
          ),
          const SizedBox(height: VsSpacing.md),
          Text(
            'Reza-se: 1 Pai-Nosso · 1 Ave-Maria · 1 Glória ao Pai.',
            style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: VsSpacing.lg),
          Row(
            children: [
              if (_index > 0)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _index--),
                  icon: const Icon(Icons.chevron_left),
                  label: Text('$_indexª Estação'),
                ),
              const Spacer(),
              if (_index < _stations.length - 1)
                FilledButton.icon(
                  onPressed: () => setState(() => _index++),
                  icon: const Icon(Icons.chevron_right),
                  label: Text('${_index + 2}ª Estação'),
                )
              else
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check),
                  label: const Text('Concluir Via Sacra'),
                ),
            ],
          ),
          const CrossDivider(),
          const SourceAttribution(
            source: 'Santo Afonso Maria de Ligório — Via Sacra (1761)',
            license: 'Domínio público',
          ),
        ],
      ),
      bottomNavigationBar: const GlobalAudioMiniPlayer(useSafeArea: true),
    );
  }
}
