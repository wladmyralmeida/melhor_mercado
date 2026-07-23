# melhor mercado

Lista de compras que aprende quanto você paga. **Paraíba-first.**

- **A lista é o produto** — funciona offline, sem conta, útil no minuto 1.
- **Escanear cupom fiscal** (Fase 2) — lê o QR da NFC-e/NF-e/CF-e-SAT e
  identifica a nota (chave, UF, CNPJ, valor quando o QR traz). O QR não
  contém os itens da compra — nenhuma versão traz isso — então, por
  enquanto, adicionar o que foi comprado ainda é manual.
- **Meu histórico** (Fase 3) — ligar a busca de itens a essa identidade.
- **Minha cesta mais barata** (Fase 4) — "sua lista sai R$ X no mercado A,
  R$ Y no B", com base **no que você pagou** (nunca "preço de mercado").

Documentação de produto e arquitetura: [`docs/00-fase-0-visao-arquitetural.md`](docs/00-fase-0-visao-arquitetural.md).
Pesquisa que fundamenta as decisões (concorrentes, SEFAZ, LGPD): [`docs/pesquisa/`](docs/pesquisa/).

## Rodar

```bash
flutter pub get
dart run build_runner build   # gera o código do Drift
flutter run                   # dispositivo/emulador Android
```

## Testes e qualidade

```bash
dart format --set-exit-if-changed .
dart analyze
flutter test
```

## Stack

| Camada | Escolha | Nota |
|---|---|---|
| UI | Flutter + Material 3 | tema "papel quente", verde reservado a preço |
| Estado | Riverpod 3 (à mão) | sem codegen de providers |
| Banco | Drift/SQLite | local-first; único codegen do projeto |
| Navegação | go_router (`/`) + `Navigator.push` (scanner) | scanner é um fluxo transiente, não uma rota deep-linkável |
| Dinheiro | centavos inteiros | `double` nunca representa valor armazenado |
| Leitura fiscal | `mm_fiscal` (pacote próprio) + `mobile_scanner` | chave/DV/QR em Dart puro, sem SDK de terceiro no domínio |

## Estrutura

```
melhor_mercado/
├── lib/
│   ├── app.dart                  # MaterialApp.router + rotas
│   ├── main.dart
│   ├── core/
│   │   ├── db/                   # Drift: tabelas + AppDb (semente da 1ª lista)
│   │   ├── format/               # BRL, quantidade, CNPJ — parse/format
│   │   └── theme/                # cores AA-verificadas, numerais tabulares
│   └── features/
│       ├── lists/
│       │   ├── data/             # ListsRepository + ListTotals
│       │   ├── state/            # providers Riverpod
│       │   └── presentation/     # HomeScreen, AddItemSheet, widgets
│       └── scan/
│           ├── data/             # ReceiptsRepository (dedupe por chave natural)
│           ├── state/            # providers Riverpod
│           └── presentation/     # ScanScreen (câmera + resultado)
└── packages/
    └── mm_fiscal/                 # chave de acesso, DV mod11, GTIN, parser de QR
                                    # Dart puro — zero dependência de Flutter
```

### O que o scanner NÃO faz (ainda)

O QR Code da NFC-e (nenhuma versão) contém os itens da compra — só a
chave de acesso, UF, CNPJ do emitente e, às vezes, o valor total. Buscar
os itens exige uma fonte paga (ex.: InfoSimples) e a SEFAZ-PB **exige
captcha** na consulta direta — verificado, e por isso fora de escopo
(o projeto não contorna captcha). A Fase 2 identifica e deduplica a
nota; ligar a busca de itens fica para a Fase 3.
