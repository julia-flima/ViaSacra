# Catecismos — obras embutidas e importador `.json`

Na **Biblioteca → Catecismo**:

- **Catecismo Maior de São Pio X (1905)**, embutido: as 993 perguntas e respostas do *Compendio della
  Dottrina Cristiana*, com busca offline (FTS5) por número ou palavra, favoritos, anotações e leitura
  em voz alta. Tradução do italiano feita pelo projeto e dedicada ao domínio público (CC0). O texto
  italiano fica ao lado, pergunta a pergunta, em `scripts/data/sao_pio_x_1905.json`: para sugerir
  uma correção, edite esse arquivo e rode `scripts/build_sao_pio_x.py`.
- **Catecismo da Igreja Católica (1992)**: só o índice das 4 partes vem no app; o texto abre no
  portal oficial da Santa Sé (`vatican.va`), sem cópia no repositório. "Ir ao §" abre a página de
  qualquer parágrafo: o nome de cada página traz a sua faixa (`ExternalLinks.catechismPages`).
  Na Web não há iframe, porque o `vatican.va` envia `X-Frame-Options: SAMEORIGIN`; o texto abre numa
  nova aba, já no parágrafo.
- **Importador local**: qualquer obra no formato abaixo (por exemplo, um CIC ou Compêndio que o
  usuário tenha) pode ser importada no próprio aparelho.

O Catecismo Romano (Trento, 1566) volta quando houver uma edição integral e fiel em domínio público.

## Esquema JSON para importação

```json
{
  "formato": "viasacra-catecismo",
  "versao": 1,
  "id": "cic_1992",
  "nome": "Catecismo da Igreja Católica",
  "nome_curto": "CIC (1992)",
  "sigla": "CIC",
  "ano": 1992,
  "idioma": "pt-BR",
  "licenca": "Uso pessoal (importação local)",
  "rotulo_entrada": "§",
  "entradas": [
    {
      "numero": 1324,
      "parte": "Segunda Parte — A Celebração do Mistério Cristão",
      "capitulo": "O Sacramento da Eucaristia",
      "pergunta": "A Eucaristia — fonte e ápice da vida eclesial",
      "resposta": "A Eucaristia é fonte e ápice de toda a vida cristã..."
    }
  ]
}
```

| Campo | Obrigatório | Descrição |
|---|---|---|
| `formato` | Recomendado | Deve ser `"viasacra-catecismo"` (quando informado). |
| `versao` | Recomendado | Versão do esquema (`1`). |
| `id` | **Sim** | Identificador único (`2` a `32` caracteres: `[a-z0-9_-]`). |
| `nome` | **Sim** | Nome completo da obra. |
| `nome_curto` / `sigla` | Não | Rótulo curto exibido no seletor de obras. |
| `idioma` | Não | Código BCP-47 (padrão: `"pt-BR"`). Define a voz do TTS. |
| `rotulo_entrada` | Não | Prefixo do número (ex.: `"§"` ou `"P."`). |
| `entradas` (ou `paragrafos`) | **Sim** | Lista de objetos com `numero` (inteiro positivo), `parte`, `capitulo` (opcional), `pergunta` / `titulo` (opcional) e `resposta` / `texto` (obrigatório). |
