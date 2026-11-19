#!/usr/bin/env python3
"""Gera app/assets/data/prayers.json a partir das orações definidas aqui.

Mantemos as orações em Python (texto multilinha legível, fácil de revisar em
PRs) e geramos o JSON consumido pelo app. Para corrigir uma oração, edite este
arquivo e rode: python tool/build_prayers.py

Fontes de referência: Compêndio do Catecismo (Apêndice A — Orações comuns),
Missal Romano (3ª ed. típica brasileira), Enchiridion Indulgentiarum e textos
tradicionais em domínio público. Não altere os `id` (usados nos favoritos).
"""

from __future__ import annotations

import json
from pathlib import Path
from textwrap import dedent

RAIZ = Path(__file__).resolve().parents[1]


def t(s: str) -> str:
    return dedent(s).strip("\n")


CATEGORIAS = [
    {"id": "fundamentais", "titulo": "Orações Fundamentais", "descricao": "As orações do dia a dia do cristão."},
    {"id": "eucaristicas", "titulo": "Eucarísticas e de Adoração", "descricao": "Para a Missa, a Comunhão e a Adoração."},
    {"id": "marianas", "titulo": "Orações Marianas", "descricao": "Com Maria, Mãe de Deus e nossa."},
    {"id": "santos", "titulo": "Santos e Proteção", "descricao": "Intercessão dos santos e exame diário."},
]

ORACOES = [
    # ------------------------------------------------------------ Fundamentais
    {
        "id": "sinal_da_cruz", "categoria": "fundamentais", "titulo": "Sinal da Cruz", "titulo_la": "Signum Crucis",
        "texto_pt": t("""
            Pelo sinal da Santa Cruz,
            livrai-nos, Deus, Nosso Senhor,
            dos nossos inimigos.

            Em nome do Pai, e do Filho, e do Espírito Santo. Amém.
        """),
        "texto_la": "In nomine Patris, et Filii, et Spiritus Sancti. Amen.",
    },
    {
        "id": "pai_nosso", "categoria": "fundamentais", "titulo": "Pai-Nosso", "titulo_la": "Pater Noster",
        "texto_pt": t("""
            Pai nosso que estais nos céus,
            santificado seja o vosso nome;
            venha a nós o vosso reino;
            seja feita a vossa vontade,
            assim na terra como no céu.
            O pão nosso de cada dia nos dai hoje;
            perdoai-nos as nossas ofensas,
            assim como nós perdoamos a quem nos tem ofendido;
            e não nos deixeis cair em tentação,
            mas livrai-nos do mal. Amém.
        """),
        "texto_la": t("""
            Pater noster, qui es in caelis,
            sanctificetur nomen tuum.
            Adveniat regnum tuum.
            Fiat voluntas tua, sicut in caelo et in terra.
            Panem nostrum quotidianum da nobis hodie,
            et dimitte nobis debita nostra,
            sicut et nos dimittimus debitoribus nostris.
            Et ne nos inducas in tentationem,
            sed libera nos a malo. Amen.
        """),
    },
    {
        "id": "ave_maria", "categoria": "fundamentais", "titulo": "Ave-Maria", "titulo_la": "Ave Maria",
        "texto_pt": t("""
            Ave, Maria, cheia de graça,
            o Senhor é convosco;
            bendita sois vós entre as mulheres,
            e bendito é o fruto do vosso ventre, Jesus.

            Santa Maria, Mãe de Deus,
            rogai por nós, pecadores,
            agora e na hora de nossa morte. Amém.
        """),
        "texto_la": t("""
            Ave Maria, gratia plena, Dominus tecum.
            Benedicta tu in mulieribus,
            et benedictus fructus ventris tui, Iesus.

            Sancta Maria, Mater Dei,
            ora pro nobis peccatoribus,
            nunc et in hora mortis nostrae. Amen.
        """),
    },
    {
        "id": "gloria", "categoria": "fundamentais", "titulo": "Glória ao Pai", "titulo_la": "Gloria Patri",
        "texto_pt": t("""
            Glória ao Pai, e ao Filho, e ao Espírito Santo.
            Como era no princípio, agora e sempre. Amém.
        """),
        "texto_la": t("""
            Gloria Patri, et Filio, et Spiritui Sancto.
            Sicut erat in principio, et nunc et semper,
            et in saecula saeculorum. Amen.
        """),
    },
    {
        "id": "credo_niceno", "categoria": "fundamentais", "titulo": "Credo Niceno-Constantinopolitano",
        "titulo_la": "Symbolum Nicaenum",
        "texto_pt": t("""
            Creio em um só Deus, Pai todo-poderoso,
            Criador do céu e da terra,
            de todas as coisas visíveis e invisíveis.

            Creio em um só Senhor, Jesus Cristo,
            Filho Unigênito de Deus,
            nascido do Pai antes de todos os séculos:
            Deus de Deus, Luz da Luz,
            Deus verdadeiro de Deus verdadeiro;
            gerado, não criado, consubstancial ao Pai.
            Por ele todas as coisas foram feitas.
            E por nós, homens, e para a nossa salvação,
            desceu dos céus
            e se encarnou pelo Espírito Santo,
            no seio da Virgem Maria,
            e se fez homem.
            Também por nós foi crucificado sob Pôncio Pilatos;
            padeceu e foi sepultado.
            Ressuscitou ao terceiro dia,
            conforme as Escrituras,
            e subiu aos céus,
            onde está sentado à direita do Pai.
            E de novo há de vir, em sua glória,
            para julgar os vivos e os mortos;
            e o seu reino não terá fim.

            Creio no Espírito Santo, Senhor que dá a vida,
            e procede do Pai e do Filho;
            e com o Pai e o Filho é adorado e glorificado:
            ele que falou pelos profetas.

            Creio na Igreja, una, santa, católica e apostólica.
            Professo um só batismo para remissão dos pecados.
            E espero a ressurreição dos mortos
            e a vida do mundo que há de vir. Amém.
        """),
        "texto_la": t("""
            Credo in unum Deum,
            Patrem omnipotentem, factorem caeli et terrae,
            visibilium omnium et invisibilium.

            Et in unum Dominum Iesum Christum,
            Filium Dei unigenitum,
            et ex Patre natum ante omnia saecula.
            Deum de Deo, lumen de lumine,
            Deum verum de Deo vero,
            genitum, non factum, consubstantialem Patri:
            per quem omnia facta sunt.
            Qui propter nos homines et propter nostram salutem
            descendit de caelis.
            Et incarnatus est de Spiritu Sancto
            ex Maria Virgine, et homo factus est.
            Crucifixus etiam pro nobis sub Pontio Pilato;
            passus et sepultus est,
            et resurrexit tertia die, secundum Scripturas,
            et ascendit in caelum, sedet ad dexteram Patris.
            Et iterum venturus est cum gloria,
            iudicare vivos et mortuos,
            cuius regni non erit finis.

            Et in Spiritum Sanctum, Dominum et vivificantem:
            qui ex Patre Filioque procedit.
            Qui cum Patre et Filio simul adoratur et conglorificatur:
            qui locutus est per prophetas.

            Et unam, sanctam, catholicam et apostolicam Ecclesiam.
            Confiteor unum baptisma in remissionem peccatorum.
            Et exspecto resurrectionem mortuorum,
            et vitam venturi saeculi. Amen.
        """),
        "fonte": "Missal Romano",
    },
    {
        "id": "credo_apostolos", "categoria": "fundamentais", "titulo": "Credo dos Apóstolos", "titulo_la": "Symbolum Apostolorum",
        "texto_pt": t("""
            Creio em Deus Pai todo-poderoso,
            Criador do céu e da terra;
            e em Jesus Cristo, seu único Filho, nosso Senhor,
            que foi concebido pelo poder do Espírito Santo;
            nasceu da Virgem Maria;
            padeceu sob Pôncio Pilatos,
            foi crucificado, morto e sepultado;
            desceu à mansão dos mortos;
            ressuscitou ao terceiro dia;
            subiu aos céus,
            está sentado à direita de Deus Pai todo-poderoso,
            donde há de vir a julgar os vivos e os mortos.
            Creio no Espírito Santo,
            na santa Igreja Católica,
            na comunhão dos santos,
            na remissão dos pecados,
            na ressurreição da carne,
            na vida eterna. Amém.
        """),
        "texto_la": t("""
            Credo in Deum Patrem omnipotentem,
            Creatorem caeli et terrae.
            Et in Iesum Christum, Filium eius unicum, Dominum nostrum,
            qui conceptus est de Spiritu Sancto,
            natus ex Maria Virgine,
            passus sub Pontio Pilato,
            crucifixus, mortuus, et sepultus,
            descendit ad inferos,
            tertia die resurrexit a mortuis,
            ascendit ad caelos,
            sedet ad dexteram Dei Patris omnipotentis,
            inde venturus est iudicare vivos et mortuos.
            Credo in Spiritum Sanctum,
            sanctam Ecclesiam catholicam,
            sanctorum communionem,
            remissionem peccatorum,
            carnis resurrectionem,
            vitam aeternam. Amen.
        """),
    },
    {
        "id": "ato_de_contricao", "categoria": "fundamentais", "titulo": "Ato de Contrição", "titulo_la": "Actus Contritionis",
        "texto_pt": t("""
            Meu Deus, eu me arrependo, de todo o coração,
            de vos ter ofendido,
            porque sois tão bom e amável.
            Prometo, com a vossa graça,
            esforçar-me para ser bom.
            Meu Jesus, misericórdia!
        """),
        "texto_la": t("""
            Deus meus, ex toto corde paenitet me omnium meorum peccatorum,
            eaque detestor, quia peccando,
            non solum poenas a Te iuste statutas promeritus sum,
            sed praesertim quia offendi Te,
            summum bonum, ac dignum qui super omnia diligaris.
            Ideo firmiter propono, adiuvante gratia Tua,
            de cetero me non peccaturum peccandique occasiones proximas fugiturum. Amen.
        """),
        "nota": "Fórmula breve usada no Brasil; o texto latino corresponde à fórmula tradicional mais longa.",
    },
    {
        "id": "vinde_espirito_santo", "categoria": "fundamentais", "titulo": "Vinde, Espírito Santo", "titulo_la": "Veni, Sancte Spiritus",
        "texto_pt": t("""
            Vinde, Espírito Santo,
            enchei os corações dos vossos fiéis
            e acendei neles o fogo do vosso amor.

            V. Enviai o vosso Espírito e tudo será criado.
            R. E renovareis a face da terra.

            Oremos: Ó Deus, que instruístes os corações dos vossos fiéis
            com a luz do Espírito Santo,
            concedei-nos que, no mesmo Espírito,
            saibamos o que é reto
            e gozemos sempre da sua consolação.
            Por Cristo, Senhor nosso. Amém.
        """),
        "texto_la": t("""
            Veni, Sancte Spiritus,
            reple tuorum corda fidelium,
            et tui amoris in eis ignem accende.

            V. Emitte Spiritum tuum et creabuntur.
            R. Et renovabis faciem terrae.

            Oremus: Deus, qui corda fidelium Sancti Spiritus illustratione docuisti,
            da nobis in eodem Spiritu recta sapere,
            et de eius semper consolatione gaudere.
            Per Christum Dominum nostrum. Amen.
        """),
    },
    # ------------------------------------------------------------ Eucarísticas
    {
        "id": "alma_de_cristo", "categoria": "eucaristicas", "titulo": "Alma de Cristo", "titulo_la": "Anima Christi",
        "texto_pt": t("""
            Alma de Cristo, santificai-me.
            Corpo de Cristo, salvai-me.
            Sangue de Cristo, inebriai-me.
            Água do lado de Cristo, lavai-me.
            Paixão de Cristo, confortai-me.
            Ó bom Jesus, ouvi-me.
            Dentro de vossas chagas, escondei-me.
            Não permitais que eu me separe de vós.
            Do espírito maligno, defendei-me.
            Na hora da minha morte, chamai-me
            e mandai-me ir para vós,
            para que com os vossos santos vos louve
            por todos os séculos dos séculos. Amém.
        """),
        "texto_la": t("""
            Anima Christi, sanctifica me.
            Corpus Christi, salva me.
            Sanguis Christi, inebria me.
            Aqua lateris Christi, lava me.
            Passio Christi, conforta me.
            O bone Iesu, exaudi me.
            Intra tua vulnera absconde me.
            Ne permittas me separari a te.
            Ab hoste maligno defende me.
            In hora mortis meae voca me.
            Et iube me venire ad te,
            ut cum Sanctis tuis laudem te
            in saecula saeculorum. Amen.
        """),
    },
    {
        "id": "tantum_ergo", "categoria": "eucaristicas", "titulo": "Tão Sublime Sacramento", "titulo_la": "Tantum Ergo",
        "texto_pt": t("""
            Tão sublime Sacramento
            adoremos neste altar,
            pois o Antigo Testamento
            deu ao Novo seu lugar.
            Venha a fé, por suplemento,
            os sentidos completar.

            Ao Eterno Pai cantemos
            e a Jesus, o Salvador.
            Ao Espírito exaltemos,
            na Trindade, eterno amor.
            Ao Deus uno e trino demos
            a alegria do louvor. Amém.

            V. Do céu lhes destes o pão.
            R. Que contém todo o sabor.

            Oremos: Senhor Jesus Cristo, neste admirável sacramento
            nos deixastes o memorial da vossa paixão.
            Dai-nos venerar com tão grande amor o mistério
            do vosso Corpo e do vosso Sangue,
            que possamos colher continuamente os frutos da vossa redenção.
            Vós que viveis e reinais para sempre. Amém.
        """),
        "texto_la": t("""
            Tantum ergo Sacramentum
            veneremur cernui:
            et antiquum documentum
            novo cedat ritui:
            praestet fides supplementum
            sensuum defectui.

            Genitori, Genitoque
            laus et iubilatio,
            salus, honor, virtus quoque
            sit et benedictio:
            procedenti ab utroque
            compar sit laudatio. Amen.

            V. Panem de caelo praestitisti eis.
            R. Omne delectamentum in se habentem.

            Oremus: Deus, qui nobis sub sacramento mirabili
            passionis tuae memoriam reliquisti:
            tribue, quaesumus, ita nos corporis et sanguinis tui
            sacra mysteria venerari,
            ut redemptionis tuae fructum in nobis iugiter sentiamus.
            Qui vivis et regnas in saecula saeculorum. Amen.
        """),
        "nota": "Últimas estrofes do hino Pange Lingua, de São Tomás de Aquino.",
    },
    {
        "id": "sao_tomas_antes_comunhao", "categoria": "eucaristicas",
        "titulo": "Oração de São Tomás de Aquino antes da Comunhão", "titulo_la": "Oratio S. Thomae ante Communionem",
        "texto_pt": t("""
            Deus eterno e todo-poderoso,
            eis que me aproximo do sacramento do vosso Filho único,
            Nosso Senhor Jesus Cristo.
            Venho como doente ao médico da vida,
            como impuro à fonte da misericórdia,
            como cego à luz da claridade eterna,
            como pobre e indigente ao Senhor do céu e da terra.

            Peço-vos, pois, pela abundância da vossa infinita bondade,
            que vos digneis curar a minha enfermidade,
            lavar a minha impureza, iluminar a minha cegueira,
            enriquecer a minha pobreza e vestir a minha nudez,
            para que eu receba o Pão dos Anjos,
            o Rei dos reis e Senhor dos senhores,
            com tanta reverência e humildade,
            com tanta contrição e devoção,
            com tanta pureza e fé,
            com tal propósito e intenção,
            como convém à salvação da minha alma.

            Ó Deus de bondade, concedei-me receber
            não só o sacramento do Corpo e do Sangue do Senhor,
            mas também a sua graça e a sua força.
            Ó Pai amantíssimo, concedei-me contemplar face a face,
            por toda a eternidade,
            o vosso Filho amado, que agora, peregrino,
            me proponho receber velado neste sacramento.
            Ele, que convosco vive e reina,
            na unidade do Espírito Santo, por todos os séculos. Amém.
        """),
        "texto_la": t("""
            Omnipotens sempiterne Deus,
            ecce accedo ad sacramentum unigeniti Filii tui,
            Domini nostri Iesu Christi:
            accedo tamquam infirmus ad medicum vitae,
            immundus ad fontem misericordiae,
            caecus ad lumen claritatis aeternae,
            pauper et egenus ad Dominum caeli et terrae.

            Rogo ergo immensae largitatis tuae abundantiam,
            quatenus meam curare digneris infirmitatem,
            lavare foeditatem, illuminare caecitatem,
            ditare paupertatem, vestire nuditatem;
            ut panem Angelorum, Regem regum et Dominum dominantium,
            tanta suscipiam reverentia et humilitate,
            tanta contritione et devotione,
            tanta puritate et fide,
            tali proposito et intentione,
            sicut expedit saluti animae meae.

            O benignissime Deus,
            da mihi Corporis et Sanguinis Domini
            non solum suscipere sacramentum,
            sed etiam rem et virtutem sacramenti.
            O amantissime Pater,
            concede mihi dilectum Filium tuum,
            quem nunc velatum in via suscipere propono,
            revelata tandem facie perpetuo contemplari:
            Qui tecum vivit et regnat in unitate Spiritus Sancti, Deus,
            per omnia saecula saeculorum. Amen.
        """),
        "nota": "Texto condensado da oração tradicional (domínio público).",
    },
    {
        "id": "sao_tomas_depois_comunhao", "categoria": "eucaristicas",
        "titulo": "Oração de São Tomás de Aquino depois da Comunhão", "titulo_la": "Oratio S. Thomae post Communionem",
        "texto_pt": t("""
            Eu vos dou graças, Senhor santo, Pai todo-poderoso, Deus eterno,
            porque, sem nenhum mérito meu,
            mas só pela condescendência da vossa misericórdia,
            vos dignastes saciar-me, a mim, pecador e vosso indigno servo,
            com o precioso Corpo e Sangue do vosso Filho,
            Nosso Senhor Jesus Cristo.

            Peço-vos que esta santa comunhão
            não seja para mim motivo de castigo,
            mas intercessão salutar para o perdão.
            Seja para mim armadura da fé e escudo da boa vontade;
            seja a extinção dos meus vícios,
            o aumento da caridade e da paciência,
            da humildade, da obediência e de todas as virtudes;
            firme defesa contra as ciladas de todos os inimigos;
            perfeita união convosco, único e verdadeiro Deus,
            e feliz consumação do meu fim.

            E peço-vos que vos digneis conduzir-me, pecador,
            àquele inefável banquete onde vós, com o vosso Filho
            e o Espírito Santo, sois para os vossos santos
            luz verdadeira, plena saciedade, gozo eterno,
            alegria completa e felicidade perfeita.
            Por Cristo, Senhor nosso. Amém.
        """),
        "texto_la": t("""
            Gratias tibi ago, Domine, sancte Pater, omnipotens aeterne Deus,
            qui me peccatorem, indignum famulum tuum,
            nullis meis meritis,
            sed sola dignatione misericordiae tuae
            satiare dignatus es
            pretioso Corpore et Sanguine Filii tui,
            Domini nostri Iesu Christi.

            Et precor, ut haec sancta communio
            non sit mihi reatus ad poenam,
            sed intercessio salutaris ad veniam.
            Sit mihi armatura fidei, et scutum bonae voluntatis.
            Sit vitiorum meorum evacuatio,
            caritatis et patientiae,
            humilitatis et oboedientiae,
            omniumque virtutum augmentatio;
            contra insidias inimicorum omnium firma defensio;
            in te uno ac vero Deo firma adhaesio,
            atque finis mei felix consummatio.

            Et precor te, ut ad illud ineffabile convivium
            me peccatorem perducere digneris,
            ubi tu, cum Filio tuo et Spiritu Sancto,
            Sanctis tuis es lux vera, satietas plena,
            gaudium sempiternum, iucunditas consummata et felicitas perfecta.
            Per eundem Christum Dominum nostrum. Amen.
        """),
        "nota": "Texto condensado da oração tradicional (domínio público).",
    },
    # ------------------------------------------------------------ Marianas
    {
        "id": "salve_rainha", "categoria": "marianas", "titulo": "Salve-Rainha", "titulo_la": "Salve Regina",
        "texto_pt": t("""
            Salve, Rainha, Mãe de misericórdia,
            vida, doçura e esperança nossa, salve!
            A vós bradamos, os degredados filhos de Eva;
            a vós suspiramos, gemendo e chorando
            neste vale de lágrimas.
            Eia, pois, advogada nossa,
            esses vossos olhos misericordiosos a nós volvei;
            e depois deste desterro mostrai-nos Jesus,
            bendito fruto do vosso ventre,
            ó clemente, ó piedosa, ó doce sempre Virgem Maria.

            V. Rogai por nós, santa Mãe de Deus.
            R. Para que sejamos dignos das promessas de Cristo.
        """),
        "texto_la": t("""
            Salve, Regina, Mater misericordiae,
            vita, dulcedo et spes nostra, salve.
            Ad te clamamus, exsules filii Hevae.
            Ad te suspiramus, gementes et flentes
            in hac lacrimarum valle.
            Eia ergo, advocata nostra,
            illos tuos misericordes oculos ad nos converte.
            Et Iesum, benedictum fructum ventris tui,
            nobis post hoc exsilium ostende.
            O clemens, o pia, o dulcis Virgo Maria.

            V. Ora pro nobis, sancta Dei Genetrix.
            R. Ut digni efficiamur promissionibus Christi.
        """),
    },
    {
        "id": "angelus", "categoria": "marianas", "titulo": "Angelus (O Anjo do Senhor)", "titulo_la": "Angelus Domini",
        "texto_pt": t("""
            V. O Anjo do Senhor anunciou a Maria.
            R. E ela concebeu do Espírito Santo.
            Ave, Maria…

            V. Eis aqui a serva do Senhor.
            R. Faça-se em mim segundo a vossa palavra.
            Ave, Maria…

            V. E o Verbo se fez carne.
            R. E habitou entre nós.
            Ave, Maria…

            V. Rogai por nós, santa Mãe de Deus.
            R. Para que sejamos dignos das promessas de Cristo.

            Oremos: Infundi, Senhor, nós vos pedimos, a vossa graça em nossas almas,
            para que nós, que pela anunciação do Anjo conhecemos
            a encarnação de Jesus Cristo, vosso Filho,
            pela sua paixão e cruz sejamos conduzidos à glória da ressurreição.
            Pelo mesmo Cristo, Senhor nosso. Amém.
        """),
        "texto_la": t("""
            V. Angelus Domini nuntiavit Mariae.
            R. Et concepit de Spiritu Sancto.
            Ave Maria…

            V. Ecce ancilla Domini.
            R. Fiat mihi secundum verbum tuum.
            Ave Maria…

            V. Et Verbum caro factum est.
            R. Et habitavit in nobis.
            Ave Maria…

            V. Ora pro nobis, sancta Dei Genetrix.
            R. Ut digni efficiamur promissionibus Christi.

            Oremus: Gratiam tuam, quaesumus, Domine, mentibus nostris infunde;
            ut qui, Angelo nuntiante, Christi Filii tui incarnationem cognovimus,
            per passionem eius et crucem ad resurrectionis gloriam perducamur.
            Per eundem Christum Dominum nostrum. Amen.
        """),
        "nota": "Reza-se tradicionalmente às 6h, 12h e 18h. No Tempo Pascal, substitui-se pelo Regina Caeli.",
    },
    {
        "id": "regina_caeli", "categoria": "marianas", "titulo": "Rainha do Céu", "titulo_la": "Regina Caeli",
        "texto_pt": t("""
            Rainha do céu, alegrai-vos, aleluia!
            Porque quem merecestes trazer em vosso seio, aleluia,
            ressuscitou como disse, aleluia!
            Rogai a Deus por nós, aleluia!

            V. Exultai e alegrai-vos, ó Virgem Maria, aleluia!
            R. Porque o Senhor ressuscitou verdadeiramente, aleluia!

            Oremos: Ó Deus, que vos dignastes alegrar o mundo
            com a ressurreição do vosso Filho, Nosso Senhor Jesus Cristo,
            concedei-nos, vos suplicamos, que, por sua Mãe, a Virgem Maria,
            alcancemos as alegrias da vida eterna.
            Pelo mesmo Cristo, Senhor nosso. Amém.
        """),
        "texto_la": t("""
            Regina caeli, laetare, alleluia.
            Quia quem meruisti portare, alleluia,
            resurrexit, sicut dixit, alleluia.
            Ora pro nobis Deum, alleluia.

            V. Gaude et laetare, Virgo Maria, alleluia.
            R. Quia surrexit Dominus vere, alleluia.

            Oremus: Deus, qui per resurrectionem Filii tui, Domini nostri Iesu Christi,
            mundum laetificare dignatus es:
            praesta, quaesumus, ut per eius Genetricem Virginem Mariam,
            perpetuae capiamus gaudia vitae.
            Per eundem Christum Dominum nostrum. Amen.
        """),
        "nota": "Rezada no Tempo Pascal, no lugar do Angelus.",
    },
    {
        "id": "lembrai_vos", "categoria": "marianas", "titulo": "Lembrai-vos (São Bernardo)", "titulo_la": "Memorare",
        "texto_pt": t("""
            Lembrai-vos, ó piíssima Virgem Maria,
            que nunca se ouviu dizer que algum daqueles
            que têm recorrido à vossa proteção,
            implorado a vossa assistência
            e reclamado o vosso socorro,
            fosse por vós desamparado.

            Animado eu, pois, com igual confiança,
            a vós, ó Virgem entre todas singular,
            como a Mãe recorro;
            de vós me valho e, gemendo sob o peso dos meus pecados,
            me prostro aos vossos pés.

            Não desprezeis as minhas súplicas,
            ó Mãe do Verbo de Deus humanado,
            mas dignai-vos de as ouvir propícia
            e de me alcançar o que vos rogo. Amém.
        """),
        "texto_la": t("""
            Memorare, o piissima Virgo Maria,
            non esse auditum a saeculo,
            quemquam ad tua currentem praesidia,
            tua implorantem auxilia,
            tua petentem suffragia,
            esse derelictum.

            Ego tali animatus confidentia,
            ad te, Virgo virginum, Mater, curro,
            ad te venio, coram te gemens peccator assisto.

            Noli, Mater Verbi, verba mea despicere,
            sed audi propitia et exaudi. Amen.
        """),
    },
    {
        "id": "ladainha_lauretana", "categoria": "marianas", "titulo": "Ladainha de Nossa Senhora (Lauretana)",
        "titulo_la": "Litaniae Lauretanae",
        "texto_pt": t("""
            Senhor, tende piedade de nós.
            Jesus Cristo, tende piedade de nós.
            Senhor, tende piedade de nós.
            Jesus Cristo, ouvi-nos.
            Jesus Cristo, atendei-nos.

            Deus Pai do céu, tende piedade de nós.
            Deus Filho, Redentor do mundo, tende piedade de nós.
            Deus Espírito Santo, tende piedade de nós.
            Santíssima Trindade, que sois um só Deus, tende piedade de nós.

            Santa Maria, rogai por nós.
            Santa Mãe de Deus,
            Santa Virgem das virgens,
            Mãe de Cristo,
            Mãe da Igreja,
            Mãe de misericórdia,
            Mãe da divina graça,
            Mãe da esperança,
            Mãe puríssima,
            Mãe castíssima,
            Mãe sempre virgem,
            Mãe imaculada,
            Mãe amável,
            Mãe admirável,
            Mãe do bom conselho,
            Mãe do Criador,
            Mãe do Salvador,
            Virgem prudentíssima,
            Virgem venerável,
            Virgem louvável,
            Virgem poderosa,
            Virgem clemente,
            Virgem fiel,
            Espelho de justiça,
            Sede da sabedoria,
            Causa da nossa alegria,
            Vaso espiritual,
            Vaso honorífico,
            Vaso insigne de devoção,
            Rosa mística,
            Torre de Davi,
            Torre de marfim,
            Casa de ouro,
            Arca da aliança,
            Porta do céu,
            Estrela da manhã,
            Saúde dos enfermos,
            Refúgio dos pecadores,
            Conforto dos migrantes,
            Consoladora dos aflitos,
            Auxílio dos cristãos,
            Rainha dos anjos,
            Rainha dos patriarcas,
            Rainha dos profetas,
            Rainha dos apóstolos,
            Rainha dos mártires,
            Rainha dos confessores,
            Rainha das virgens,
            Rainha de todos os santos,
            Rainha concebida sem pecado original,
            Rainha elevada ao céu,
            Rainha do santo Rosário,
            Rainha da família,
            Rainha da paz, rogai por nós.

            Cordeiro de Deus, que tirais o pecado do mundo, perdoai-nos, Senhor.
            Cordeiro de Deus, que tirais o pecado do mundo, ouvi-nos, Senhor.
            Cordeiro de Deus, que tirais o pecado do mundo, tende piedade de nós.

            V. Rogai por nós, santa Mãe de Deus.
            R. Para que sejamos dignos das promessas de Cristo.

            Oremos: Senhor Deus, nós vos suplicamos que concedais aos vossos servos
            perpétua saúde de alma e de corpo;
            e que, pela gloriosa intercessão da bem-aventurada sempre Virgem Maria,
            sejamos livres da presente tristeza e gozemos da eterna alegria.
            Por Cristo, Senhor nosso. Amém.
        """),
        "texto_la": t("""
            Kyrie, eleison. Christe, eleison. Kyrie, eleison.
            Christe, audi nos. Christe, exaudi nos.

            Pater de caelis, Deus, miserere nobis.
            Fili, Redemptor mundi, Deus, miserere nobis.
            Spiritus Sancte, Deus, miserere nobis.
            Sancta Trinitas, unus Deus, miserere nobis.

            Sancta Maria, ora pro nobis.
            Sancta Dei Genetrix,
            Sancta Virgo virginum,
            Mater Christi,
            Mater Ecclesiae,
            Mater misericordiae,
            Mater divinae gratiae,
            Mater spei,
            Mater purissima,
            Mater castissima,
            Mater inviolata,
            Mater intemerata,
            Mater amabilis,
            Mater admirabilis,
            Mater boni consilii,
            Mater Creatoris,
            Mater Salvatoris,
            Virgo prudentissima,
            Virgo veneranda,
            Virgo praedicanda,
            Virgo potens,
            Virgo clemens,
            Virgo fidelis,
            Speculum iustitiae,
            Sedes sapientiae,
            Causa nostrae laetitiae,
            Vas spirituale,
            Vas honorabile,
            Vas insigne devotionis,
            Rosa mystica,
            Turris Davidica,
            Turris eburnea,
            Domus aurea,
            Foederis arca,
            Ianua caeli,
            Stella matutina,
            Salus infirmorum,
            Refugium peccatorum,
            Solacium migrantium,
            Consolatrix afflictorum,
            Auxilium Christianorum,
            Regina Angelorum,
            Regina Patriarcharum,
            Regina Prophetarum,
            Regina Apostolorum,
            Regina Martyrum,
            Regina Confessorum,
            Regina Virginum,
            Regina Sanctorum omnium,
            Regina sine labe originali concepta,
            Regina in caelum assumpta,
            Regina sacratissimi Rosarii,
            Regina familiae,
            Regina pacis, ora pro nobis.

            Agnus Dei, qui tollis peccata mundi, parce nobis, Domine.
            Agnus Dei, qui tollis peccata mundi, exaudi nos, Domine.
            Agnus Dei, qui tollis peccata mundi, miserere nobis.

            V. Ora pro nobis, sancta Dei Genetrix.
            R. Ut digni efficiamur promissionibus Christi.

            Oremus: Concede nos famulos tuos, quaesumus, Domine Deus,
            perpetua mentis et corporis sanitate gaudere:
            et gloriosa beatae Mariae semper Virginis intercessione,
            a praesenti liberari tristitia, et aeterna perfrui laetitia.
            Per Christum Dominum nostrum. Amen.
        """),
        "nota": "Inclui as invocações acrescentadas pelo Papa Francisco em 2020 (Mãe de misericórdia, Mãe da esperança, Conforto dos migrantes).",
    },
    {
        "id": "consagracao_nossa_senhora", "categoria": "marianas", "titulo": "Consagração a Nossa Senhora",
        "titulo_la": "Consecratio ad B. M. V.",
        "texto_pt": t("""
            Ó Senhora minha, ó minha Mãe,
            eu me ofereço todo a vós
            e, em prova da minha devoção para convosco,
            vos consagro neste dia
            os meus olhos, os meus ouvidos,
            a minha boca, o meu coração
            e inteiramente todo o meu ser.
            E porque assim sou vosso, ó incomparável Mãe,
            guardai-me e defendei-me como coisa e propriedade vossa. Amém.
        """),
        "texto_la": t("""
            O Domina mea! O Mater mea!
            Tibi me totum offero,
            atque ut me tibi probem devotum,
            consecro tibi hodie
            oculos meos, aures meas, os meum,
            cor meum, plane me totum.
            Quoniam itaque tuus sum, o bona Mater,
            serva me, defende me, ut rem ac possessionem tuam. Amen.
        """),
    },
    # ------------------------------------------------------------ Santos e proteção
    {
        "id": "sao_miguel", "categoria": "santos", "titulo": "Oração a São Miguel Arcanjo", "titulo_la": "Sancte Michael Archangele",
        "texto_pt": t("""
            São Miguel Arcanjo, defendei-nos no combate;
            sede o nosso refúgio contra as maldades e ciladas do demônio.
            Ordene-lhe Deus, instantemente o pedimos;
            e vós, príncipe da milícia celeste,
            pelo divino poder, precipitai no inferno a Satanás
            e aos outros espíritos malignos
            que andam pelo mundo para perder as almas. Amém.
        """),
        "texto_la": t("""
            Sancte Michael Archangele, defende nos in proelio;
            contra nequitiam et insidias diaboli esto praesidium.
            Imperet illi Deus, supplices deprecamur:
            tuque, Princeps militiae caelestis,
            Satanam aliosque spiritus malignos,
            qui ad perditionem animarum pervagantur in mundo,
            divina virtute in infernum detrude. Amen.
        """),
        "nota": "Composta pelo Papa Leão XIII (1886).",
    },
    {
        "id": "sao_bento", "categoria": "santos", "titulo": "Oração de São Bento (Medalha)", "titulo_la": "Crux Sancti Patris Benedicti",
        "texto_pt": t("""
            A Cruz Sagrada seja a minha luz;
            não seja o dragão o meu guia.
            Retira-te, Satanás!
            Nunca me aconselhes coisas vãs.
            É mau o que tu me ofereces;
            bebe tu mesmo o teu veneno!

            São Bento, rogai por nós.
        """),
        "texto_la": t("""
            Crux Sancta sit mihi lux,
            non draco sit mihi dux.
            Vade retro, Satana!
            Numquam suade mihi vana.
            Sunt mala quae libas,
            ipse venena bibas!

            Sancte Pater Benedicte, ora pro nobis.
        """),
        "nota": "Inscrição da Medalha de São Bento (C.S.S.M.L. – N.D.S.M.D. – V.R.S. – N.S.M.V. – S.M.Q.L. – I.V.B.).",
    },
    {
        "id": "sao_francisco_paz", "categoria": "santos", "titulo": "Oração pela Paz (atribuída a São Francisco)",
        "texto_pt": t("""
            Senhor, fazei-me instrumento de vossa paz.
            Onde houver ódio, que eu leve o amor;
            onde houver ofensa, que eu leve o perdão;
            onde houver discórdia, que eu leve a união;
            onde houver dúvida, que eu leve a fé;
            onde houver erro, que eu leve a verdade;
            onde houver desespero, que eu leve a esperança;
            onde houver tristeza, que eu leve a alegria;
            onde houver trevas, que eu leve a luz.

            Ó Mestre, fazei que eu procure mais
            consolar que ser consolado,
            compreender que ser compreendido,
            amar que ser amado.
            Pois é dando que se recebe,
            é perdoando que se é perdoado,
            e é morrendo que se vive para a vida eterna. Amém.
        """),
        "nota": "Tradicionalmente atribuída a São Francisco de Assis; texto publicado anonimamente em 1912.",
    },
    {
        "id": "santo_anjo", "categoria": "santos", "titulo": "Santo Anjo da Guarda", "titulo_la": "Angele Dei",
        "texto_pt": t("""
            Santo Anjo do Senhor,
            meu zeloso guardador,
            se a ti me confiou a piedade divina,
            sempre me rege, me guarda,
            me governa e me ilumina. Amém.
        """),
        "texto_la": t("""
            Angele Dei, qui custos es mei,
            me, tibi commissum pietate superna,
            illumina, custodi, rege et guberna. Amen.
        """),
    },
    {
        "id": "exame_de_consciencia", "categoria": "santos", "titulo": "Exame de Consciência Diário",
        "texto_pt": t("""
            Antes de dormir, em silêncio, coloque-se na presença de Deus.

            1. Gratidão
            Agradeça a Deus pelos dons deste dia: as pessoas, os momentos, as graças pequenas e grandes.

            2. Pedir luz
            Peça ao Espírito Santo a graça de ver o seu dia com os olhos de Deus, com verdade e sem medo.

            3. Rever o dia
            Percorra as horas do dia. Onde você amou a Deus e ao próximo?
            Onde faltou com a caridade, a paciência, a verdade ou a pureza?
            Deixou de fazer algum bem que podia ter feito?

            4. Pedir perdão
            Reconheça humildemente as suas faltas e reze o Ato de Contrição.
            Se houver pecado grave, procure o sacramento da Confissão.

            5. Propósito
            Com confiança na graça, faça um pequeno propósito concreto para amanhã.

            Termine com um Pai-Nosso, uma Ave-Maria e um Glória.
        """),
        "nota": "Inspirado no exame diário de Santo Inácio de Loyola (Exercícios Espirituais, n. 43).",
    },
]


def main() -> None:
    ids = [o["id"] for o in ORACOES]
    assert len(ids) == len(set(ids)), "ids duplicados"
    cats = {c["id"] for c in CATEGORIAS}
    assert all(o["categoria"] in cats for o in ORACOES)
    saida = RAIZ / "app/assets/data/prayers.json"
    saida.write_text(json.dumps({"versao": 1, "categorias": CATEGORIAS, "oracoes": ORACOES},
                                ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(ORACOES)} orações → {saida.relative_to(RAIZ)}")


if __name__ == "__main__":
    main()
