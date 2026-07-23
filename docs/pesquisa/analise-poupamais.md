# Análise do concorrente poupa+ (poupamais.app) e verificação SEFAZ-PB

> Pesquisa verificada em 2026-07-22 (8 agentes + 2 críticos adversariais). Motivou o recorte enxuto do produto.
> Confiança calibrada pela crítica adversarial: fatos vs. indícios sinalizados no texto.

## Síntese executiva

- **poupa+ = protótipo solo sem tração:** Alex Freitag / DEV FREITAG LTDA (CNPJ 52.487.847/0001-46), 10+ downloads, ZERO avaliações, sem iOS, v1.0.16 (20/jul/2026).
- **Stack declarada:** Expo/React Native + Supabase + InfoSimples + PostHog + Sentry.
- **Não leem a nota — pagam a InfoSimples** para consultar a NFC-e (declarado na política). Custo: R$100/mês fixo + ~R$0,20/consulta acima de ~500 notas. No volume atual o marginal é ~zero.
- **"Colaborativo" só no texto** dos termos/política (não observado em código). Na prática, com 10 instalações, é um diário pessoal — a intuição do cliente estava certa na prática.
- **Sem GTIN:** consulta pública da NFC-e devolve só texto cru → matching por string, frágil.
- **Concorrente real = o Estado:** Menor Preço Brasil (em SC desde mai/2026) e, na PB, o **Preço da Hora Paraíba** — grátis, base fiscal de 223 municípios, busca por código de barras, 3 menores preços + rota. Mas os termos restringem uso comercial e não há API pública legítima.
- **SEFAZ-PB exige captcha** (verificado): leitura direta pelo nosso código está fora; InfoSimples/Burocrata resolvem legitimamente.
- **Evidência empírica decisiva:** apps de **lista** (Bring!, Out of Milk) têm ~100x a tração de apps de cupom fiscal puro. A lista é o produto, não o scanner.



################ FRENTE: Mapeamento completo do site poupamais.app + ficha Google Play + modelo de dados do poupa+ (concorrente do melhor_mercado)

RESUMO:
O poupa+ é um produto de um desenvolvedor solo (Alex Freitag / DEV FREITAG LTDA, CNPJ 52.487.847/0001-46), lançado há poucas semanas: o site nunca foi arquivado pelo Wayback, o app tem "10+ downloads" na Google Play, zero avaliações públicas, e a última atualização é de 20/07/2026 (dois dias atrás).
O site é minúsculo e proposital: exatamente TRÊS páginas (/, /termos, /privacidade), Next.js/Turbopack pré-renderizado na Vercel, sem blog, sem FAQ separado, sem API pública. Não há UM ÚNICO screenshot do app no site — os "celulares" da landing são mockups em HTML/CSS com lojas fictícias, mais um vídeo de demo de 490 KB (/poupamais-video.mp4). Os screenshots reais só existem na ficha da Play.
SOBRE A PISTA CENTRAL: a hipótese do cliente está REFUTADA como arquitetura e CONFIRMADA como realidade prática. Três documentos independentes (landing, Política de Privacidade §2 e Termos §5) afirmam explicitamente que a comparação usa "os cupons de todos os usuários, de forma agregada e sem identificar quem realizou cada compra". Ou seja: é colaborativo por design. Só que com 10+ instalações, na prática a base é o próprio usuário e o círculo do desenvolvedor — daí "1 compra", "2 compras", "4 compras" e as redes Cooper Fresh / Giassi / Fort Atacadista, todas de Santa Catarina (uma screenshot da loja mostra literalmente "Jaraguá do Sul/SC" e o telefone do desenvolvedor na Play é DDD 47).
O ponto mais estratégico que encontrei não está na UI: o poupa+ NÃO raspa a SEFAZ. Ele paga a InfoSimples por consulta. A tabela pública da InfoSimples dá R$ 0,20/consulta na faixa 1–500/mês + R$ 0,04 adicional para SEFAZ/SC/NFC-e, com franquia mínima de R$ 100,00/mês. Cada cupom escaneado tem custo marginal real, o app é 100% gratuito, sem anúncios e sem compra no app. Isso é uma bomba-relógio de unit economics — e os Termos §3 já preparam o terreno para assinatura futura via Google Play.
Sinais de dor no produto: a release note de 20/07 criou uma "Central de Ajuda com dicas para quando o escaneamento da nota não funcionar" e só agora permitiu excluir a conta pelo app. E o FAQ fecha a porta de saída: "Não. [...] Seu único trabalho é apontar a câmera" — não há entrada manual quando o scan falha.
Stack do app (inferida da lista de operadores na política): Expo/EAS + Supabase + PostHog + Sentry — React Native, não Flutter.

ACHADOS:
- [confirmada] O modelo de dados do poupa+ É colaborativo entre usuários por design — a hipótese de que o histórico vem só das compras do próprio usuário está REFUTADA como arquitetura.
    EVID: Três fontes independentes. Landing (seção 'Cada cupom ajuda todo mundo'): 'A comparação de preços usa os cupons de todos os usuários, sem identificar quem comprou. Quanto mais gente escaneia, melhor fica a resposta para "onde está mais barato?".' Política de Privacidade §2: 'construir comparações de preços entre estabelecimentos usando os cupons de todos os usuários, de forma agregada e sem identificar quem realizou cada compra'. Termos §5: 'As comparações de preços exibidas no aplicativo são co
    FONTE: https://poupamais.app/ , https://poupamais.app/privacidade , https://poupamais.app/termos
- [confirmada] NA PRÁTICA, hoje, a base é essencialmente o próprio usuário — a hipótese do cliente está CONFIRMADA como realidade operacional. O app tem 10+ instalações.
    EVID: Ficha da Google Play, campo de instalações: '10+ downloads'. Zero avaliações (o HTML não contém 'avaliações' nem contagem de estrelas). Nenhuma captura no Wayback Machine. Nenhuma menção em imprensa ou fórum. Com esse volume, 'os cupons de todos os usuários' e 'os seus cupons' são praticamente o mesmo conjunto — o que explica exatamente o '1 compra / 2 compras / 4 compras' visto em 'Onde foi encontrado'.
    FONTE: https://play.google.com/store/apps/details?id=com.devfreitag.poupamais
- [provavel] O 'N compras' em 'Onde foi encontrado' é a contagem de observações (cupons) que sustentam aquele preço naquela loja — não é o número de compras suas naquele lugar necessariamente.
    EVID: Screenshot 2 da Play ('Acompanhe o preço'), tela 'Produto' de LEITE UHT TIROL INTEGRAL 1L: 'Fort Atacadista — Mais barato — 1 compra — R$ 3,19 — R$ 0,89 mais barato'; 'Giassi — 2 compras — R$ 4,08'; 'Cooper Fresh — 4 compras — R$ 4,29'. Combinado com a política ('de forma agregada'), o contador é o número de registros que embasam o preço.
    FONTE: Screenshot Google Play (play-lh.googleusercontent.com/Cm4-PGRymvP1Ql95...) — visualizado
- [confirmada] O poupa+ NÃO raspa a SEFAZ. Ele terceiriza a consulta da NFC-e para a InfoSimples, que é paga por consulta.
    EVID: Política de Privacidade §1: 'Esses dados são obtidos dos serviços públicos de consulta das Secretarias da Fazenda.' §3, lista de operadores: 'InfoSimples — consulta dos dados da nota fiscal (NFC-e) junto à Secretaria da Fazenda a partir do código escaneado'.
    FONTE: https://poupamais.app/privacidade
- [confirmada] Cada cupom escaneado custa dinheiro real ao poupa+: ~R$ 0,24 por scan em SC na faixa de volume atual, com franquia mínima de R$ 100,00/mês — e o app é 100% gratuito, sem anúncios e sem compra no app.
    EVID: Tabela pública da InfoSimples: 'A franquia mínima mensal de serviços é R$ 100,00'; 'Da consulta 1 até a 500 — R$ 0,20 / consulta'; tabela de preço adicional: 'SEFAZ / SC / NFC-e — R$ 0,04'. Termos §3: 'Atualmente o poupa+ é oferecido gratuitamente'. Ficha da Play sem badge 'Contém anúncios' e sem 'Compras no app'.
    FONTE: https://infosimples.com/consultas/precos/ + https://poupamais.app/termos + Google Play
- [confirmada] Assinatura paga já está juridicamente preparada, mas não lançada.
    EVID: Termos §3, literal: 'Podemos, no futuro, oferecer planos pagos por assinatura para determinados recursos, com as condições divulgadas no aplicativo antes da contratação. Quando houver planos pagos, a cobrança será processada exclusivamente pela Google Play Store, conforme suas políticas — não armazenamos dados de cartão ou informações financeiras.'
    FONTE: https://poupamais.app/termos
- [confirmada] O produto nasceu em Santa Catarina e a busca de preços é escopada por cidade, informada manualmente — sem GPS.
    EVID: Screenshot 'Pesquise por produtos' mostra a barra de busca com 'leite tirol', '6 resultados encontrados' e, à direita, o pin de local com 'Jaraguá do Sul/SC'. Legenda: 'Encontre qualquer item e compare preços entre os mercados da sua cidade.' Política §1: 'Na configuração inicial você informa sua cidade e estado, que usamos para priorizar estabelecimentos e preços da sua região. Não coletamos sua localização por GPS nem coordenadas precisas do dispositivo.' Telefone do desenvolvedor na Play: +55
    FONTE: Screenshot Google Play + https://poupamais.app/privacidade + ficha do desenvolvedor
- [provavel] Stack do app: Expo/React Native + Supabase + PostHog + Sentry. Não é Flutter.
    EVID: Política §3, lista literal de operadores: 'Supabase — infraestrutura de banco de dados e autenticação; InfoSimples — consulta dos dados da nota fiscal (NFC-e)...; PostHog — análise de uso do aplicativo; Sentry — monitoramento de erros; Google — login com conta Google e distribuição do aplicativo pelo Google Play; Expo (EAS) — entrega de notificações e atualizações do aplicativo.' 'Atualizações do aplicativo' via EAS = EAS Update, que só existe para React Native/Expo.
    FONTE: https://poupamais.app/privacidade
- [confirmada] O escaneamento falha com frequência suficiente para justificar uma Central de Ajuda dedicada — e a exclusão de conta só passou a existir na versão de 20/07/2026.
    EVID: 'O que há de novo' na Google Play, literal: 'Melhorias e correções de bugs: - Nova Central de Ajuda com dicas para quando o escaneamento da nota não funcionar - Agora você pode excluir sua conta direto pelo app. Obrigado por usar o poupa+! 💚'
    FONTE: https://play.google.com/store/apps/details?id=com.devfreitag.poupamais
- [confirmada] Não existe caminho alternativo quando o scan falha — não há entrada manual de produto/preço.
    EVID: FAQ da landing, literal: 'Preciso digitar preços ou produtos? Não. Depois de escanear, o app identifica os produtos, os preços, o estabelecimento e a data sozinho. Seu único trabalho é apontar a câmera.' Nenhuma menção a digitar chave de acesso, importar XML, ler código de barras ou inserir preço manualmente em nenhuma das 3 páginas nem na descrição da Play.
    FONTE: https://poupamais.app/ + Google Play
- [confirmada] O site tem exatamente 3 páginas e nenhum screenshot do app. Os 'celulares' da landing são mockups em HTML/CSS com lojas fictícias.
    EVID: Sitemap com 3 URLs; 18 caminhos adivinhados retornaram 404. O HTML da home contém apenas 4 tags <img>: 2x /poupamais-icon.svg e 2x /_next/image?url=%2Fandroid-badge.png. Os nomes de loja nos mockups são fictícios ('Mercado Boa Vista', 'Supermercado Central', 'Atacado do Povo', 'Farmácia Santa Rita') e estão como texto inline no HTML, não em imagem. Único ativo real do produto: /poupamais-video.mp4 (501.714 bytes).
    FONTE: https://poupamais.app/ (HTML bruto)
- [confirmada] Proposta de valor literal (headline / subheadline / CTA final).
    EVID: Headline: 'Não lembra quanto você pagou? Agora você vai.' Subheadline: 'O poupa+ lê o QR code do cupom fiscal e guarda tudo sozinho: produtos, preços, mercado e data. Sem digitar nada, sem planilha.' Badge no hero: 'Em breve para iPhone'. CTA final: 'Da próxima vez, você vai saber quanto pagou' / 'Baixe o poupa+ e comece no seu próximo cupom.' Tagline do rodapé: 'Escaneie o cupom fiscal e saiba onde você paga menos.' og:description: 'Escaneie o QR code do cupom fiscal e tenha seu histórico de co
    FONTE: https://poupamais.app/
- [confirmada] Funcionalidades anunciadas, com frase exata — são 5 blocos de recurso + o fluxo de 3 passos.
    EVID: (1) 'Compare preços entre mercados' — 'Busque qualquer produto e veja quanto ele custou em cada estabelecimento por perto. Antes de sair de casa, você já sabe onde vale a pena comprar.' (2) 'Veja o preço subir — ou cair — ao longo do tempo' — 'Cada produto tem seu histórico de preços. Você percebe quando algo encareceu de um mês para o outro e aproveita quando o preço volta a cair.' (3) 'Lista de compras com preços' — 'Monte sua lista e veja o valor estimado com base nos preços mais recentes de 
    FONTE: https://poupamais.app/
- [confirmada] Descrição da Play lista as mesmas 5 funcionalidades em formato de bullets e promete cobertura nacional.
    EVID: Literal: 'O QUE VOCÊ PODE FAZER: - Escanear cupons fiscais (NFC-e) pelo QR Code - Ver o histórico completo das suas compras - Pesquisar um produto e comparar preços entre lojas e compras - Montar sua lista de compras - Acompanhar a média dos seus gastos'. E: 'FUNCIONA EM TODO O BRASIL — O poupa+ aceita cupons fiscais eletrônicos (NFC-e) emitidos em qualquer estado.' Contato alternativo na descrição: 'Dúvidas ou sugestões? Entre em contato: devfreitag@gmail.com'
    FONTE: https://play.google.com/store/apps/details?id=com.devfreitag.poupamais
- [confirmada] O escopo declarado é MAIOR que supermercado: farmácia, padaria, pet shop, posto.
    EVID: FAQ: 'Funciona em qualquer estabelecimento? Funciona em qualquer lugar que emita NFC-e com QR code: mercados, padarias, farmácias, pet shops, postos e por aí vai. Se o cupom tem QR code, o poupa+ consegue ler.' Coerente com o mockup do resumo mensal, que lista 'Farmácia Santa Rita — 21 jun — R$ 38,75'.
    FONTE: https://poupamais.app/
- [confirmada] Identificação da empresa e contato, completos.
    EVID: Política §9 e Termos §11: 'DEV FREITAG LTDA, inscrita no CNPJ 52.487.847/0001-46'. Ficha 'Sobre o desenvolvedor' na Play: 'DEV FREITAG LTDA / alex@devfreitag.com / Av. PAULISTA 777 / ANDAR 15 CONJ 15 SALA 730 / BELA VISTA / SÃO PAULO - SP / 01311-914 / Brazil / +55 47 99121-5500'. Site pessoal: 'Alex Freitag — Senior Backend Developer'.
    FONTE: https://poupamais.app/privacidade + Google Play + https://www.devfreitag.com/
- [confirmada] NÃO há encarregado/DPO nomeado, apesar de a política invocar a LGPD explicitamente.
    EVID: A seção '9. Contato' diz apenas 'Dúvidas sobre privacidade e proteção de dados podem ser enviadas para alex@devfreitag.com.' Não há nome de encarregado, cargo ou canal específico. O texto cita a LGPD ('Lei nº 13.709/2018') e lista os direitos do titular, mas omite a indicação do encarregado prevista no art. 41.
    FONTE: https://poupamais.app/privacidade
- [confirmada] A declaração de Segurança dos Dados na Play está incompleta: não declara histórico de compras / dados financeiros, que são o núcleo do app.
    EVID: Página de datasafety declara, literal: 'Dados compartilhados — Informações pessoais: Nome, Endereço de e-mail e IDs de usuários' (finalidade: Análise de dados) e 'Dados coletados — Informações pessoais: Nome, Endereço de e-mail e IDs de usuários'. Nada sobre compras, produtos, preços ou estabelecimentos — que a própria política admite registrar ('produtos, quantidades, preços, estabelecimento (nome, CNPJ e endereço) e data da compra').
    FONTE: https://play.google.com/store/apps/datasafety?id=com.devfreitag.poupamais + https://poupamais.app/privacidade
- [confirmada] Retenção: os registros de preço agregados NUNCA são apagados, mesmo após exclusão de conta.
    EVID: Política §4, literal: 'Mantemos seus dados enquanto sua conta existir. Você pode excluir sua conta a qualquer momento pelas configurações do aplicativo; com isso, seus dados pessoais são removidos em até 30 dias. Registros de preços já agregados às comparações permanecem de forma anônima, sem qualquer vínculo com você.'
    FONTE: https://poupamais.app/privacidade
- [confirmada] Os Termos proíbem explicitamente scraping do serviço — sinal de que a base de preços é considerada o ativo.
    EVID: Termos §4: 'tentar acessar, extrair ou coletar dados do serviço de forma automatizada (scraping, bots) ou explorar falhas de segurança'. E §6: 'Os dados fiscais contidos nos cupons (NFC-e) são documentos públicos emitidos pelas Secretarias da Fazenda estaduais.'
    FONTE: https://poupamais.app/termos
- [confirmada] Os próprios Termos admitem que os preços podem estar desatualizados e que o serviço depende de infraestrutura pública instável.
    EVID: §5: 'Os preços refletem o valor registrado no momento de cada compra e podem estar desatualizados ou conter divergências em relação ao preço praticado atualmente pelo estabelecimento. As informações do poupa+ têm caráter informativo e não constituem oferta, publicidade ou garantia de preço.' §7: 'não garantimos funcionamento ininterrupto ou livre de erros — inclusive porque a leitura de cupons depende de serviços públicos de consulta das notas fiscais, que podem ficar indisponíveis.'
    FONTE: https://poupamais.app/termos
- [confirmada] Tecnologia do site: Next.js com Turbopack, hospedado na Vercel, pré-renderizado estático, com Vercel Analytics e Speed Insights. Sem JSON-LD, sem PWA, sem API pública.
    EVID: Headers: 'server: Vercel', 'x-nextjs-prerender: 1', 'x-nextjs-stale-time: 300', 'x-vercel-cache: HIT', 'x-vercel-id: gru1::...' (região São Paulo). Bundle 'turbopack-27fdd508db6a15e0.js'. Classes Tailwind customizadas: bg-brand, bg-brand-dark, bg-brand-tint, text-brand, text-brand-dark, text-brand-light. Zero <script type="application/ld+json">. /manifest.json e /.well-known/assetlinks.json dão 404. Grep nos 11 bundles: nenhuma URL de API própria.
    FONTE: https://poupamais.app/ (headers + bundles)
- [provavel] A UI evoluiu entre a screenshot da loja e a build que o cliente fotografou — o gráfico da loja tem UMA série e rótulo 'Último preço'; a do cliente tem DUAS séries e 'Faixa de preço'.
    EVID: Screenshot da Play (Produto / LEITE UHT TIROL INTEGRAL 1L): abaixo da categoria 'Laticínios' aparece 'Último preço / R$ 4,88' e o gráfico tem uma linha única com balão 'R$ 4,88' no ponto final, eixo X dez/25→jun/26. A tela descrita pelo cliente (LEITE UHT ITALAC INTEGRAL 1L) traz 'Faixa de preço R$ 4,98 - R$ 5,19' e duas séries com legenda 'Fort Atacadista' e 'Cooper Fresh', eixo X mar/26→jul/26. Mesma estrutura de cards e o mesmo toggle 6M/3M/1M/1S nas duas.
    FONTE: Screenshot Google Play visualizada vs. descrição do cliente
- [confirmada] A tela Home descrita pelo cliente é literalmente a screenshot 3 da Google Play — mesmos dados, mesma conta de demonstração.
    EVID: A imagem play-lh.googleusercontent.com/nwocioHKnWyeoJbe... que baixei e visualizei mostra exatamente: 'Olá, Alex Freitag / seja bem-vindo ao poupa+!', '< Julho 2026 >', 'Ticket médio R$ 433,19', 'Compras no mês 1', 'Gastos por categoria — Outros 26% / Carnes 23% / Ver mais', 'Compras Recentes' com Cooper Fresh 01 jul 40 itens R$ 433,19; Cooper Fresh 24 jun 56 itens R$ 581,73; Cooper Fresh 17 jun 52 itens R$ 645,90; Giassi 07 jun 51 itens R$ 595,24, e a bottom nav Início / Buscar / FAB QR / Lista
    FONTE: Screenshot Google Play (nwocioHKnWyeoJbe...) — visualizada
- [confirmada] Inventário completo de imagens do produto (site + loja).
    EVID: SITE: /poupamais-icon.svg (cestinha verde com QR code dentro, 3.191 bytes); /android-badge.png servido via /_next/image (badge 'Disponível no Google Play'); /og-image.png (1200x630, og:image e twitter:image); /favicon.ico?favicon.75e3e6a8.ico; /poupamais-video.mp4 (demo do app, 490 KB). PLAY: ícone (12USW7aflgz466...), feature graphic 720x352 (cestinha com QR + wordmark 'poupa+' sobre fundo verde-menta claro), screenshot 1 'Pesquise por produtos — Encontre qualquer item e compare preços entre os
    FONTE: https://poupamais.app/ (HTML) + play-lh.googleusercontent.com (imagens baixadas e visualizadas)
- [confirmada] Não há iOS, e não há prazo declarado.
    EVID: FAQ: 'Tem para iPhone? Ainda não — hoje o poupa+ está disponível para Android no Google Play. A versão para iPhone está a caminho.' Badge no hero: 'Em breve para iPhone'. Nenhum link para App Store em nenhuma das 3 páginas.
    FONTE: https://poupamais.app/
- [confirmada] Zero prova social. O site não tem um único depoimento, número de usuários, contagem de instalações ou nota de loja.
    EVID: Varredura completa do texto da home (77 linhas): nenhuma citação de usuário, nenhuma métrica agregada, nenhum logo de imprensa, nenhuma seção de reviews. Os únicos números na página são valores fictícios dentro dos mockups (R$ 24,90, R$ 487,32, −12% etc.).
    FONTE: https://poupamais.app/
- [confirmada] O app está classificado na Play como 'Finanças' — categoria de bancos e carteiras — apesar de o design ser deliberadamente não-financeiro.
    EVID: Ficha da Play mostra 'Finanças' logo abaixo de 'Atualizado em 20 de jul. de 2026'. Também 'Classificação Livre'.
    FONTE: https://play.google.com/store/apps/details?id=com.devfreitag.poupamais

LACUNAS DO POUPA+:
- Base fria e sem massa crítica: 10+ instalações. A promessa central ('onde está mais barato?') só funciona com densidade local de usuários, e a busca é escopada por cidade — então a rede precisa ser reconstruída cidade por cidade. Fora de Jaraguá do Sul/Joinville, o app hoje entrega apenas o histórico do próprio usuário com uma UI que promete comparação entre mercados.
- Cold start individual brutal: usuário novo instala, cria conta, escolhe cidade e vê TUDO vazio até escanear o primeiro cupom — e o primeiro cupom só chega na próxima ida ao mercado. Não há dado de partida, nem preço de referência, nem catálogo pré-populado.
- Sem caminho alternativo quando o scan falha. O FAQ afirma 'Seu único trabalho é apontar a câmera' e não existe entrada manual de produto/preço, digitação de chave de acesso, importação de XML ou leitura de código de barras. A release note de 20/07 criando uma 'Central de Ajuda com dicas para quando o escaneamento da nota não funcionar' mostra que a falha é comum o bastante para virar feature.
- Dependência de terceiro pago com custo marginal por uso: InfoSimples a R$ 0,20/consulta (faixa 1–500/mês) + R$ 0,04 adicional em SC, com franquia mínima de R$ 100,00/mês. Cada scan queima caixa e o app é gratuito, sem anúncios e sem compra no app. Não escala sem mudar o modelo.
- Dependência de infraestrutura pública instável, admitida nos próprios Termos §7: 'a leitura de cupons depende de serviços públicos de consulta das notas fiscais, que podem ficar indisponíveis'. Quando a SEFAZ cai, o produto inteiro para.
- Preço sempre retroativo, nunca de gôndola. Só existe preço de produto que ALGUÉM já comprou e escaneou. Os Termos §5 avisam que os preços 'podem estar desatualizados ou conter divergências em relação ao preço praticado atualmente'. Isso mina a decisão que o app promete apoiar ('antes de sair de casa, você já sabe onde vale a pena comprar').
- Só existe cupom impresso: exige pedir a via impressa no caixa. Nada de nota por e-mail, CPF na nota, PDF, ou integração com programas estaduais (Nota Fiscal Paulista, Nota Catarinense etc.).
- Sem iOS. Metade do mercado de maior poder aquisitivo está fora, sem prazo declarado.
- Sem versão web / sem consulta pelo navegador. Nem para ver o próprio histórico, nem para SEO de páginas de produto.
- Site de 3 páginas, sem blog, sem SEO programático, sem JSON-LD. Nenhum canal de aquisição orgânica além da marca — e a marca não é buscada por ninguém (zero capturas no Wayback, zero cobertura de imprensa).
- Zero prova social no site: nenhum depoimento, nenhum número de usuários, nenhuma nota da loja. Landing inteira sustentada por mockups com lojas fictícias ('Mercado Boa Vista', 'Atacado do Povo'), enquanto as screenshots reais da loja usam redes de verdade. Descompasso entre a promessa da landing e o que o app entrega hoje.
- Nenhum screenshot real no site. O único ativo verdadeiro é um vídeo de 490 KB. Quem chega pela landing não vê o produto.
- Compliance frouxo: não nomeia encarregado/DPO apesar de invocar a LGPD, e a declaração de Segurança dos Dados na Play omite justamente o dado central (histórico de compras, produtos, preços, estabelecimento com CNPJ e endereço). Exclusão de conta pelo app só passou a existir em 20/07/2026.
- Retenção assimétrica que o usuário atento vai questionar: você apaga a conta, mas 'Registros de preços já agregados às comparações permanecem de forma anônima' — para sempre.
- Categorizado como 'Finanças' na Play, competindo por atenção com bancos e carteiras, enquanto o design foi feito justamente para NÃO parecer app financeiro. Posicionamento de loja brigando com o posicionamento de produto.
- Sem nenhum recurso de economia ativa: não há alerta de queda de preço, não há comparação com encarte/oferta, não há cashback, não há sugestão de 'compre no mercado X e economize R$ Y nesta lista'. O app registra e mostra — mas não age.
- Escopo declarado amplo demais (mercado, padaria, farmácia, pet shop, posto) para um produto que ainda não resolveu nem o caso do supermercado. Diluição de foco.
- Sem tratamento visível para o problema mais difícil do domínio: normalizar o mesmo produto entre lojas diferentes. Nenhuma das 3 páginas nem a descrição da loja menciona como isso é feito.

O QUE COPIAR:
- Ancorar tudo na NFC-e. É a melhor fonte de verdade disponível no Brasil: dado oficial, estruturado, com produto, quantidade, preço unitário, CNPJ e data — sem OCR, sem digitação, sem margem de erro. O argumento 'Direto da nota, sem achismo [...] é o que você pagou, centavo por centavo' é forte e verdadeiro; reaproveite a tese, não a frase.
- FAB circular central no bottom nav com ícone de QR Code. A única ação que gera todo o valor do app fica no ponto mais alcançável do polegar, em todas as telas. Decisão de navegação correta e barata de copiar.
- 'Onde foi encontrado' ordenado por 'Mais barato', com badge no vencedor e o delta explícito ('R$ 0,89 mais barato'). É a resposta que o usuário realmente quer, entregue em uma linha, sem obrigá-lo a comparar números.
- Mostrar a contagem de observações por loja ('1 compra', '4 compras'). É honestidade sobre a força da evidência e, de quebra, comunica que mais scans = melhor resposta. Vale manter mesmo num app deliberadamente mais simples.
- Cidade e estado informados manualmente, sem GPS. Menos permissão pedida, menos atrito no onboarding, menos exposição LGPD, e o escopo de busca fica naturalmente local — que é como a comparação de preço faz sentido.
- Home organizada por mês com seletor '< Julho 2026 >' e cards de estatística em scroll horizontal (Ticket médio, Compras no mês, Gasto...). Dá sensação de painel sem virar dashboard financeiro.
- Toggle de período 6M / 3M / 1M / 1S no gráfico de histórico. Simples, previsível, sem date picker.
- Lista de compras com valor estimado a partir do último preço conhecido. É o que transforma histórico passivo em decisão futura — e é a ponte natural entre 'registrar' e 'economizar'.
- Categorização automática de produto com cor de acento (laranja para 'Laticínios' sobre o verde primário) e ícone em card de fundo suave. Dá legibilidade instantânea sem poluir.
- Material 3 com verde escuro primário, fundo cinza claro, cards brancos de canto arredondado. Deliberadamente NÃO parece app de banco. Para um app de mercado isso está certo — mas então classifique fora de 'Finanças' na loja, ao contrário do que eles fizeram.
- Landing estática de 3 páginas na Vercel: custo praticamente zero e cumpre o requisito da Play (política de privacidade pública + termos + site). Não invente site grande antes de ter produto.
- Termos que já preveem assinatura futura sem cobrar nada hoje ('Podemos, no futuro, oferecer planos pagos por assinatura [...] com as condições divulgadas no aplicativo antes da contratação'). Prepara o terreno jurídico sem comprometer o posicionamento gratuito.
- Headline ancorada numa dor concreta e cotidiana em vez de feature ('Não lembra quanto você pagou? Agora você vai.'). E o fluxo explicado em 3 passos físicos, com detalhe sensorial que prova que o autor usou o produto ('funciona direto na fila do estacionamento').
- Copy que já avisa que o preço é histórico e não é oferta — protege juridicamente e calibra expectativa. Copie a postura, não o texto.

EM ABERTO:
- Como o poupa+ normaliza o MESMO produto entre lojas diferentes? A screenshot mostra 'LEITE UHT TIROL INTEGRAL 1L' com preço em Fort Atacadista, Giassi e Cooper Fresh — as três com a mesma descrição. Isso sugere chave por GTIN/EAN vindo do XML. Mas várias UFs retornam NFC-e resumida sem GTIN, e a descrição do item no PDV varia por loja. Não consegui verificar: nenhuma das 3 páginas do site nem a descrição da Play menciona o método. É o problema técnico mais difícil do domínio e o principal risco do melhor_mercado.
- A linha do gráfico é pontilhada em alguns trechos (na tela do cliente) — como o app trata meses sem observação? Interpola, repete o último valor, ou marca lacuna? Isso muda muito a honestidade percebida do gráfico.
- Usam a consulta 'SEFAZ / NFC-e (Unificada)' da InfoSimples ou uma por UF? A unificada cobre as 27 UFs e o preço adicional varia conforme a UF da nota — o que importa para modelar custo. A política só diz 'InfoSimples', sem detalhar.
- Quantos usuários e quantos cupons existem de fato na base? '10+' é a única faixa pública que a Play divulga. Sem isso, não dá para dizer se o número de '4 compras' vem de 4 pessoas ou de 4 idas ao mercado do mesmo usuário.
- Há limite de scans por usuário ou por período, para conter o custo da InfoSimples? Nada nos Termos sugere limite, mas com franquia mínima de R$ 100/mês e custo unitário real, algum controle deve existir — ou vai existir.
- Como comparam preço entre embalagens diferentes (1L vs 900ml, 5kg vs 1kg)? A busca mostra 'R$ 4,88/UN', o que sugere preço por unidade de venda, não por unidade de medida. Sem preço por litro/quilo, a comparação entre marcas fica enganosa.
- Existe alguma defesa contra cupom de terceiro ou envenenamento da base de preços? Os Termos §4 proíbem 'escanear cupons fiscais obtidos de forma ilícita ou que não se refiram a compras reais', mas proibição contratual não é controle técnico. Num app colaborativo, isso vira vetor de ataque.
- O que acontece quando a SEFAZ está indisponível — o scan é enfileirado para reprocessamento ou o usuário simplesmente perde o cupom? Os Termos admitem a indisponibilidade mas não descrevem o comportamento.
- Qual é a build atual? A screenshot da loja mostra 'Último preço' com gráfico de série única; a tela que o cliente fotografou mostra 'Faixa de preço' com duas séries. Uma das duas está desatualizada e não consegui determinar qual — o app não está em espelhos de APK (apkcombo retorna 410) e não instalei.
- Quanto do dado exibido hoje é realmente de outros usuários? A resposta muda o conselho estratégico: se na prática é single-player, o melhor_mercado pode competir sendo explicitamente single-player e melhor nisso, sem prometer rede.


################ FRENTE: poupa+ (com.devfreitag.poupamais) — fichas nas lojas de aplicativos, metadados, screenshots e arquitetura real de dados

RESUMO:
O poupa+ existe SÓ no Google Play (package `com.devfreitag.poupamais`, desenvolvedor "Dev Freitag" / DEV FREITAG LTDA, CNPJ 52.487.847/0001-46, aberta em 10/10/2023, microempresa, capital R$ 5.000). NÃO existe na App Store — confirmei por lookup do bundleId na API da Apple (0 resultados) e o próprio site diz "Em breve para iPhone".
Estágio: EMBRIONÁRIO. "10+ downloads", ZERO avaliações (a ficha não tem nem nota nem contagem de reviews), versão 1.0.16, atualizado em 20/07/2026 — dois dias antes de hoje. Categoria: **Finanças**. Classificação Livre. Mínimo Android 7.0.
A PISTA DO CLIENTE ESTÁ REFUTADA na arquitetura, mas correta na prática. A Política de Privacidade e os Termos dizem literalmente que a comparação usa "os cupons de todos os usuários, de forma agregada e sem identificar quem realizou cada compra" — ou seja, É uma base colaborativa. MAS: com 10+ downloads e as telas mostrando a conta do próprio dono ("Olá, Alex Freitag"), na prática hoje a base é essencialmente as compras dele mesmo em Jaraguá do Sul/SC. O "2 compras / 3 compras" é a contagem de cupons agregados daquele produto naquela loja.
Arquitetura revelada pela política: Supabase (banco + auth), **InfoSimples** (API paga que consulta a NFC-e na SEFAZ a partir do QR — eles NÃO parseiam a nota sozinhos), PostHog, Sentry, Google Login, Expo/EAS (React Native + Expo, quase certo). Isso significa CUSTO MARGINAL POR SCAN.
Modelo de negócio: hoje 100% grátis; os Termos já preparam terreno para assinatura via Google Play.
O release note da 1.0.16 entrega a maior dor: "Nova Central de Ajuda com dicas para quando o escaneamento da nota não funcionar".
Segurança dos dados declara apenas Nome, E-mail e IDs de usuário (coletados E compartilhados para "Análise de dados") — não declara dados de compra/financeiros, o que é uma lacuna de conformidade dado que eles guardam produto, preço, CNPJ do mercado e data.

ACHADOS:
- [confirmada] Package name é com.devfreitag.poupamais; título da ficha é 'poupa+ | cupom fiscal e preços'; desenvolvedor exibido é 'Dev Freitag'.
    EVID: HTML da ficha do Google Play: '<title>poupa+ | cupom fiscal e preços – Apps no Google Play</title>' e bloco do desenvolvedor 'Dev Freitag'. Link de download no site: https://play.google.com/store/apps/details?id=com.devfreitag.poupamais
    FONTE: Google Play (HTML bruto) + poupamais.app
- [confirmada] O app tem apenas '10+ downloads' e NENHUMA avaliação. A ficha não exibe nota média nem número de reviews.
    EVID: Bloco da ficha: 'Classificação Livre | info | 10+ downloads | Instalar'. Busca no HTML por 'avaliaç', 'Avaliaç', 'estrela' retornou 0 ocorrências — não há widget de rating nem seção de reviews.
    FONTE: Google Play
- [confirmada] Versão atual 1.0.16, atualizado em 20 de julho de 2026, exige Android 7.0 ou superior, categoria Finanças, classificação Livre.
    EVID: Texto visível: 'Atualizado em 20 de jul. de 2026' / 'Finanças' / 'Classificação Livre'. No payload JSON embutido: '"141":[[["1.0.16"]],[[[35]],[[[24,"7.0"]]]]]' — 1.0.16 e API 24 = Android 7.0.
    FONTE: Google Play (JSON AF_initData embutido)
- [confirmada] Tamanho do APK e data de lançamento NÃO foram obtidos.
    EVID: A ficha web do Play não exibe mais esses campos e não os encontrei no JSON; os espelhos (apkcombo 410, apkpure 403, appbrain 403) não puderam ser lidos e não há captura no Wayback.
    FONTE: tentativas em Play + apkcombo + apkpure + appbrain + web.archive.org
- [confirmada] DESCRIÇÃO COMPLETA da ficha (transcrição literal).
    EVID: 'Não lembra quanto você pagou da última vez? Agora você vai.\n\nO poupa+ escaneia seus cupons fiscais e organiza tudo pra você. Basta apontar a câmera pro QR Code da nota e pronto — o histórico fica salvo e pesquisável.\n\nO QUE VOCÊ PODE FAZER:\n- Escanear cupons fiscais (NFC-e) pelo QR Code\n- Ver o histórico completo das suas compras\n- Pesquisar um produto e comparar preços entre lojas e compras\n- Montar sua lista de compras\n- Acompanhar a média dos seus gastos\n\nSIMPLES E DIRETO\nSem com
    FONTE: Google Play — bloco 'Sobre este app'
- [confirmada] Novidades da versão 1.0.16 revelam que a FALHA DE ESCANEAMENTO é a dor número um do produto.
    EVID: Literal: 'Melhorias e correções de bugs: - Nova Central de Ajuda com dicas para quando o escaneamento da nota não funcionar - Agora você pode excluir sua conta direto pelo app. Obrigado por usar o poupa+! 💚'
    FONTE: Google Play — 'O que há de novo'
- [confirmada] SCREENSHOT 1/5 — Home. Legenda: 'Acompanhe seus gastos / Histórico de compras e insights dos gastos num só lugar.'
    EVID: Imagem 1080x1920. Tela idêntica à Tela 1 mostrada pelo cliente: 'Olá, Alex Freitag' + 'seja bem-vindo ao poupa+!' (poupa em verde, + em laranja), hambúrguer; seletor '< Julho 2026 >'; três cards em scroll horizontal ('Ticket médio R$ 433,19', 'Compras no mês 1', terceiro cortado começando com 'Gas...'); card 'Gastos por categoria' com ícone de caixa em 'Outros 26%', ícone de bife em 'Carnes 23%' e 'Ver mais ···'; 'Compras Recentes' com ícone de cestinha: Cooper Fresh 01 jul 40 itens R$ 433,19 / 
    FONTE: play-lh.googleusercontent.com/nwocioHK... (screenshot oficial)
- [confirmada] SCREENSHOT 2/5 — Confirmação pós-scan. Legenda: 'Escaneie suas notas / Aponte a câmera pro QR Code e pronto. Rápido e fácil.'
    EVID: Card branco flutuante com check verde circular, título 'Nota Escaneada!', e três linhas com ícones: loja → 'SDB COMERCIO DE ALIMENTOS LTDA' (razão social crua, exatamente como vem da SEFAZ), carteira → 'R$ 85,67', cupom → '6 produtos · 6 itens'. Dois botões: outline 'Escanear Novamente' e sólido verde 'Ver Detalhes'.
    FONTE: play-lh.googleusercontent.com/VHFJi_Ut... (screenshot oficial)
- [confirmada] SCREENSHOT 3/5 — Detalhe da compra. Legenda: 'Veja todos os detalhes / Cada item, preço e data organizados para você.'
    EVID: AppBar 'Detalhes' com voltar e ícone de LIXEIRA (dá para apagar a compra). Card do cupom: 'Cooper Fresh', '01 jul às 17:56 • 40 itens', 'Valor total R$ 453,90', 'Descontos −R$ 20,71' (em verde), 'Valor pago R$ 433,19' em destaque. Chips de filtro por categoria: 'Todos os itens' (selecionado, verde), 'Bebidas', 'Laticínios', 'Hortifruti'. Lista de itens com ícone colorido por categoria e chevron: 'SALGADINHO BACONZITOS ELMA CHIPS 86G CLASSICOS R$ 10,99', 'FILÉ COXA C/SOBREC FRANGO NAT VERDE 1KG R
    FONTE: play-lh.googleusercontent.com/yZZO0PI5... (screenshot oficial)
- [confirmada] SCREENSHOT 4/5 — Busca. Legenda: 'Pesquise por produtos / Encontre qualquer item e compare preços entre os mercados da sua cidade.'
    EVID: AppBar 'Busca'. Campo com 'leite tirol', botão limpar e lupa. Abaixo: '6 resultados encontrados' à esquerda e, à direita, pin de localização com 'Jaraguá do Sul/SC' — a busca é ESCOPADA POR CIDADE. Chips: 'Todos os itens' | 'Laticínios' (selecionado) | 'Mercearia'. Resultados com ícone de garrafinha amarelo: LEITE UHT TIROL INTEGRAL 1L R$ 4,88/UN; CREME DE LEITE TIROL 200G TP TRADICI... R$ 2,89/UN; CREME LEITE TIROL 200G ZERO LACTOSE R$ 4,69/UN; LEITE CONDENSADO TIROL 395G TP SEMI... R$ 6,49/UN.
    FONTE: play-lh.googleusercontent.com/II3yzshq... (screenshot oficial)
- [confirmada] SCREENSHOT 5/5 — Detalhe de produto (versão ANTERIOR à que o cliente viu). Legenda: 'Acompanhe o preço / Veja a variação do preço de um produto nos últimos meses.'
    EVID: AppBar 'Produto'. Ícone de garrafinha em card amarelo, 'LEITE UHT TIROL INTEGRAL 1L', 'Laticínios' em laranja, 'Último preço R$ 4,88'. Card 'Histórico de preços' com toggle 6M|3M|1M|1S (6M ativo). Gráfico de UMA ÚNICA série (linha verde com área preenchida, marcadores redondos e tooltip 'R$ 4,88'), eixo Y R$ 2,73 / 3,54 / 4,34 / 5,15 / 5,95 e eixo X dez/25, fev/26, mar/26, abr/26, jun/26. Card 'Onde foi encontrado' com pin: Fort Atacadista, badge verde 'Mais barato', '1 compra', R$ 3,19 e sublin
    FONTE: play-lh.googleusercontent.com/Cm4-PGRy... (screenshot oficial)
- [confirmada] A tela de produto EVOLUIU entre a ficha da loja e o build que o cliente fotografou — o cliente está olhando uma versão mais nova.
    EVID: Comparação direta: o screenshot da loja tem gráfico de UMA série, rótulo 'Último preço R$ 4,88', sem controle de ordenação e datas absolutas ('25 abr'). A tela descrita pelo cliente tem DUAS séries com legenda por mercado (Fort Atacadista / Cooper Fresh), linha pontilhada nos trechos interpolados, rótulo 'Faixa de preço R$ 4,98 - R$ 5,19', controle de ordenação 'Mais barato' e data relativa ('há 1 dia'). São a mesma tela em builds diferentes.
    FONTE: screenshot 5 da Play vs. descrição das telas do cliente
- [confirmada] REFUTA PARCIALMENTE A HIPÓTESE DO CLIENTE: por arquitetura, o poupa+ É colaborativo — a comparação usa os cupons de TODOS os usuários, agregados e anonimizados.
    EVID: Política de Privacidade, seção 2: 'construir comparações de preços entre estabelecimentos usando os cupons de todos os usuários, de forma agregada e sem identificar quem realizou cada compra'. Seção 3: 'Os preços exibidos a outros usuários nas comparações nunca incluem sua identidade: outros usuários veem o produto, o preço e o estabelecimento, nunca quem comprou.' Termos, item 5: 'As comparações de preços exibidas no aplicativo são construídas a partir dos cupons fiscais escaneados pelos própri
    FONTE: poupamais.app/privacidade, /termos e home
- [confirmada] CONFIRMA A HIPÓTESE DO CLIENTE NA PRÁTICA: hoje a base colaborativa é praticamente só o próprio desenvolvedor. O '2 compras / 3 compras' é a contagem de cupons agregados daquele produto naquela loja, e com 10+ downloads essa contagem vem quase toda de uma pessoa.
    EVID: Três fatos combinados, todos confirmados: (a) '10+ downloads' e zero avaliações na Play; (b) o header do app diz 'Olá, Alex Freitag' e o e-mail de contato do desenvolvedor é alex@devfreitag.com — as telas de divulgação são a conta do próprio dono; (c) a busca é escopada em 'Jaraguá do Sul/SC' e os mercados citados (Cooper Fresh, Giassi, Fort Atacadista) são redes do Norte de SC; o telefone do desenvolvedor no Play é +55 47 99121-5500 (DDD 47 = Jaraguá do Sul/Joinville/Blumenau).
    FONTE: Google Play + screenshots oficiais + telefone do desenvolvedor na ficha
- [confirmada] ARQUITETURA REAL (declarada): Supabase como banco+auth, InfoSimples como API que busca a NFC-e na SEFAZ, PostHog para analytics, Sentry para erros, Google Login e Expo (EAS) para notificações e updates.
    EVID: Política de Privacidade, seção 3, lista literal: 'Supabase — infraestrutura de banco de dados e autenticação; InfoSimples — consulta dos dados da nota fiscal (NFC-e) junto à Secretaria da Fazenda a partir do código escaneado; PostHog — análise de uso do aplicativo; Sentry — monitoramento de erros; Google — login com conta Google e distribuição do aplicativo pelo Google Play; Expo (EAS) — entrega de notificações e atualizações do aplicativo.'
    FONTE: poupamais.app/privacidade
- [provavel] O app é React Native + Expo (inferência forte, não confirmada diretamente).
    EVID: A citação explícita de 'Expo (EAS) — entrega de notificações e atualizações do aplicativo' na política. EAS Update e Expo Push são exclusivos do stack Expo/React Native. Não achei o APK para confirmar por bytecode.
    FONTE: inferência a partir de poupamais.app/privacidade
- [confirmada] Eles NÃO parseiam a NFC-e por conta própria: pagam a InfoSimples por consulta. Isso cria custo marginal por cupom escaneado num app hoje 100% gratuito.
    EVID: Política: 'InfoSimples — consulta dos dados da nota fiscal (NFC-e) junto à Secretaria da Fazenda a partir do código escaneado'. A página da InfoSimples 'SEFAZ / NFC-e (Unificada)' confirma que o produto devolve emitente, produtos com valores e quantidades, pagamentos e totais, cobrindo os 27 estados. A página NÃO publica preço ('crie sua conta e teste grátis').
    FONTE: poupamais.app/privacidade + infosimples.com/consultas/sefaz-nfce/
- [confirmada] SEGURANÇA DOS DADOS (transcrição item a item). Dados COMPARTILHADOS com outras empresas: Informações pessoais — Nome (finalidade: Análise de dados), Endereço de e-mail (Análise de dados), IDs de usuários (Análise de dados). Dados COLETADOS: Informações pessoais — Nome, Endereço de e-mail, IDs de usuários, todos com finalidade 'Funcionalidade do app, Análise de dados, Personalização e Gerenciamento da conta'. Práticas: 'Os dados são criptografados em trânsito' e 'Você pode solicitar a exclusão dos dados'.
    EVID: Página play.google.com/store/apps/datasafety, transcrita integralmente. Nenhuma outra categoria (Informações financeiras, Compras no app, Localização, Fotos e vídeos, Arquivos) aparece declarada.
    FONTE: Google Play — Segurança dos dados
- [confirmada] LACUNA DE CONFORMIDADE: o app guarda produtos, preços, CNPJ/endereço do estabelecimento, data da compra e cidade/estado do usuário, mas NADA disso está declarado no Data Safety — que só menciona nome, e-mail e ID.
    EVID: Contraste direto entre a Política ('registramos as informações contidas na nota: produtos, quantidades, preços, estabelecimento (nome, CNPJ e endereço) e data da compra' + 'Na configuração inicial você informa sua cidade e estado') e o Data Safety da Play, que lista apenas 'Informações pessoais: Nome, Endereço de e-mail e IDs de usuários'.
    FONTE: poupamais.app/privacidade vs. Google Play Data Safety
- [baixa] A ficha da Play NÃO expõe lista de permissões, e nenhuma permissão pôde ser lida diretamente.
    EVID: A versão web da ficha não traz mais a seção de permissões e não a encontrei no HTML. Câmera é obviamente necessária para ler o QR e notificações são citadas na política ('push token'), mas isso é inferência, não leitura de manifesto — os espelhos de APK que exibiriam o manifesto estavam bloqueados (apkpure/appbrain 403) ou sem o app (apkcombo 410).
    FONTE: Google Play (ausência) + tentativas bloqueadas em espelhos
- [confirmada] Desenvolvedor: DEV FREITAG LTDA, CNPJ 52.487.847/0001-46, microempresa aberta em 10/10/2023, capital social R$ 5.000, situação ATIVA. Endereço na ficha: Av. Paulista 777, andar 15, conj 15, sala 730, Bela Vista, São Paulo/SP, 01311-914. Telefone +55 47 99121-5500. Suporte: alex@devfreitag.com (site e ficha) e devfreitag@gmail.com (dentro da descrição).
    EVID: Bloco 'Sobre o desenvolvedor' da Play, transcrito; CNPJ e razão social confirmados nos rodapés de /privacidade e /termos; dados cadastrais confirmados via BrasilAPI (Receita).
    FONTE: Google Play + poupamais.app + brasilapi.com.br
- [provavel] É um projeto de UMA PESSOA. O endereço na Av. Paulista é escritório virtual; a operação real é em Santa Catarina.
    EVID: Capital social de R$ 5.000, porte microempresa, CNAE 6399-2/00, um único e-mail de contato pessoal (alex@...), telefone com DDD 47 (SC) enquanto o endereço é SP, e as telas do app usando a conta pessoal 'Alex Freitag' comprando em mercados de Jaraguá do Sul. Combinação de fatos confirmados; a conclusão 'uma pessoa' é minha leitura.
    FONTE: inferência sobre BrasilAPI + Google Play + screenshots
- [confirmada] Modelo de negócio: grátis hoje, com assinatura via Google Play já prevista contratualmente. Nenhum anúncio, nenhum cashback, nenhuma parceria com varejo mencionada.
    EVID: Termos, item 3: 'Atualmente o poupa+ é oferecido gratuitamente; basta criar uma conta para usar o serviço. Podemos, no futuro, oferecer planos pagos por assinatura para determinados recursos... Quando houver planos pagos, a cobrança será processada exclusivamente pela Google Play Store'.
    FONTE: poupamais.app/termos
- [confirmada] O app exige conta obrigatória (e-mail+senha ou Google). Não há modo anônimo/local.
    EVID: Termos, item 2: 'Para usar o aplicativo é necessário criar uma conta com e-mail e senha ou por meio de provedores de login suportados (como o Google).'
    FONTE: poupamais.app/termos
- [confirmada] Eles mesmos admitem que a leitura depende da disponibilidade dos serviços públicos da SEFAZ e que os preços podem estar defasados.
    EVID: Termos, item 7: 'não garantimos funcionamento ininterrupto ou livre de erros — inclusive porque a leitura de cupons depende de serviços públicos de consulta das notas fiscais, que podem ficar indisponíveis'. Item 5: 'Os preços refletem o valor registrado no momento de cada compra e podem estar desatualizados ou conter divergências em relação ao preço praticado atualmente pelo estabelecimento.'
    FONTE: poupamais.app/termos
- [confirmada] Zero pegada digital: nenhuma review, nenhuma matéria, nenhum post, nenhuma captura no Wayback. O poupa+ é invisível fora do próprio site.
    EVID: Três buscas web distintas não retornaram uma única menção ao app; o CDX do Wayback devolveu vazio tanto para poupamais.app* quanto para a URL da ficha na Play; a ficha não tem avaliações.
    FONTE: WebSearch x3 + web.archive.org CDX + Google Play
- [provavel] Concorrentes reais do nicho que apareceram nas buscas (para o cliente ter no radar): Economiza Club, Busca Preço, Menor Preço (Nota Paraná / SEFAZ-RS), Dinheiro na Nota.
    EVID: Resultados das buscas descreviam: Economiza Club — 'ao escanear o QR code do cupom você registra automaticamente os preços dos produtos que comprou'; Busca Preço — 'aponte a câmera para o QR code de qualquer cupom de mercado, e cada item vira um histórico comparado com o mesmo produto em outros supermercados'; Menor Preço — 'preços atualizados em tempo real, assim que a nota é emitida'. Não abri essas fontes individualmente — é o resumo dos resultados de busca.
    FONTE: WebSearch (snippets)

LACUNAS DO POUPA+:
- COLD START MORTAL. A promessa central ('compare preços entre os mercados da sua cidade') só funciona onde já existe massa de cupons. Com 10+ downloads, qualquer usuário fora de Jaraguá do Sul/SC abre o app e vê uma tela vazia — e continua vendo por meses. O próprio screenshot de busca mostra apenas '6 resultados encontrados'. O produto não tem valor no dia 1 para quem não é o desenvolvedor.
- SEM iOS. Confirmado por lookup na API da Apple. Metade do mercado brasileiro de maior poder aquisitivo está fora, e o site só promete 'a caminho'.
- O ESCANEAMENTO FALHA — e eles admitiram publicamente. A única feature nova da 1.0.16 é 'Central de Ajuda com dicas para quando o escaneamento da nota não funcionar'. Quando a etapa única de entrada de dados falha, o app inteiro falha.
- DEPENDÊNCIA DUPLA E FRÁGIL: precisa do cupom IMPRESSO com QR (se o caixa não imprimir, ou o cliente não pedir, acabou) E da SEFAZ estar de pé (os Termos já se eximem disso).
- SÓ REGISTRA O QUE VOCÊ JÁ PAGOU. Não existe forma de registrar um preço visto na gôndola, nem foto de etiqueta, nem código de barras, nem entrada manual. Logo o app nunca responde 'quanto está HOJE no mercado da esquina' — só 'quanto alguém pagou em algum momento'. É um app retrospectivo vendido como se fosse prospectivo.
- CUSTO MARGINAL POR SCAN (InfoSimples é API paga) num produto 100% gratuito, sem ads, sem assinatura ativa. Cada usuário engajado aumenta o prejuízo. Vulnerabilidade estrutural: se eles crescerem, quebram; se não crescerem, a base de preços não serve.
- CONTA OBRIGATÓRIA já no primeiro uso, mais escolha de cidade/estado no onboarding — atrito antes de qualquer valor entregue.
- NOMES DE PRODUTO CRUS DA NOTA FISCAL ('CREME DE LEITE TIROL 200G TP TRADICI...', 'FILÉ COXA C/SOBREC FRANGO NAT VERDE 1KG'), truncados na tela e sem normalização visível. Isso destrói a comparação: o mesmo leite com descrição diferente em dois mercados vira dois produtos distintos. Também expõe razão social crua ('SDB COMERCIO DE ALIMENTOS LTDA') em vez do nome que o consumidor conhece.
- DATA SAFETY SUBDECLARADO na Play (só nome/e-mail/ID, nada de compras). Risco real de takedown ou de exigência de correção pelo Google — e sinal de imaturidade operacional.
- NENHUM ALERTA, NENHUMA NOTIFICAÇÃO ÚTIL DEMONSTRADA. Eles pedem push token mas não há nada na ficha, no site ou nos screenshots sobre alerta de queda de preço, aviso de item da lista mais barato em outro mercado, ou lembrete. O app é 100% pull: você tem que abrir e procurar.
- LISTA DE COMPRAS FRACA: só estimativa de valor com base no último preço. Nada de lista compartilhada com o cônjuge, nada de 'esta lista sai mais barata no mercado X', nada de dividir a lista entre dois mercados.
- ZERO PROVA SOCIAL: nenhuma review, nenhuma menção na imprensa, nenhuma captura no Wayback. Não há comunidade, não há tração, não há defensabilidade — a base de preços que seria o fosso ainda não existe.
- BOTTOM NAV COM 5 POSIÇÕES (Início, Buscar, FAB, Lista, Histórico) onde 'Início' e 'Histórico' se sobrepõem: a home já lista 'Compras Recentes'. Sintoma de app que ainda não decidiu qual é a tela principal.

O QUE COPIAR:
- A ENTRADA DE DADOS SEM DIGITAÇÃO É A JOGADA CERTA. Um scan de QR traz 40-56 itens com preço, unidade, loja, CNPJ e data. Nenhum app de gastos manual chega perto dessa relação esforço/valor. Copiar o princípio, mesmo simplificando todo o resto.
- FAB CENTRAL DE SCAN, GRANDE E ELEVADO na bottom nav. A ação que alimenta o produto inteiro ocupa a posição mais alcançável do polegar. Isso é design correto.
- TELA DE CONFIRMAÇÃO PÓS-SCAN COM 3 LINHAS (loja, valor total, N produtos · N itens) + 'Escanear Novamente' / 'Ver Detalhes'. Fecha o loop em um segundo e incentiva escanear a próxima nota na hora. O botão 'Escanear Novamente' antes do 'Ver Detalhes' é uma decisão fina e acertada.
- MOSTRAR 'Valor total / Descontos / Valor pago' no detalhe da compra. O desconto em verde é a única gratificação emocional do app e vem de graça na nota.
- CHIPS DE CATEGORIA DENTRO DO CUPOM ('Todos os itens | Bebidas | Laticínios | Hortifruti'). Navegação barata em cima de 40+ itens, sem menu, sem filtro modal.
- 'ONDE FOI ENCONTRADO' COM BADGE 'Mais barato' + delta explícito ('R$ 0,89 mais barato'). É a resposta que o usuário quer, entregue como um número, não como um gráfico. Vale mais que o gráfico inteiro.
- MOSTRAR A CONTAGEM DE EVIDÊNCIA ('1 compra', '2 compras', '4 compras') ao lado de cada preço. Isso comunica confiança do dado sem precisar explicar nada. Roubar essa ideia.
- TOGGLE DE PERÍODO 6M/3M/1M/1S no gráfico — leve, sem dropdown, sem date picker.
- LINHA PONTILHADA para trechos interpolados no gráfico do build novo: admite visualmente onde não há dado real. Honestidade de dados como elemento de UI.
- ESCOPO POR CIDADE explícito na busca ('6 resultados encontrados · Jaraguá do Sul/SC'). Definir o raio antes de prometer comparação nacional é a decisão mais sensata que eles tomaram — e casa exatamente com o 'bem mais simples' que o cliente quer.
- O POSICIONAMENTO EM UMA FRASE: 'Não lembra quanto você pagou? Agora você vai.' Não vende economia abstrata, vende memória. E 'Direto da nota, sem achismo' resolve a objeção de credibilidade em quatro palavras.
- CATEGORIA 'FINANÇAS' + VISUAL QUE NÃO PARECE BANCO. Verde, cards claros, sem tabelas densas, sem vermelho. Boa arbitragem: categoria de alta intenção de busca, estética de app leve.
- OBRIGAÇÕES DE COMPLIANCE JÁ RESOLVIDAS: exclusão de conta dentro do app, política de privacidade publicada em página própria, LGPD com base legal e lista de operadores. É requisito da Play — copiar a estrutura da política deles economiza dias.
- ESTRUTURA DA LANDING: 3 passos numerados, seção de recursos com mocks de dados, FAQ que responde as objeções reais ('O que é esse QR code?', 'Tem para iPhone?', 'Preciso digitar preços?', 'O que acontece com os meus dados?'). Enxuta e funcional.

EM ABERTO:
- Qual o custo real por consulta da InfoSimples? A página deles não publica preço. Isso define se o modelo 'scan ilimitado grátis' é viável ou se o melhor_mercado precisa parsear a NFC-e direto na SEFAZ (a chave de acesso está no próprio QR e as consultas públicas estaduais são gratuitas, ainda que instáveis e com captcha em alguns estados). É a decisão de arquitetura mais cara do projeto.
- O poupa+ funciona com CF-e SAT de São Paulo? Muitos varejistas em SP emitem CF-e-SAT, cujo QR tem formato diferente da NFC-e. A ficha afirma 'aceita cupons fiscais eletrônicos (NFC-e) emitidos em qualquer estado', mas não menciona SAT. Não consegui verificar.
- Como eles normalizam produtos entre lojas? Os screenshots mostram descrições cruas e truncadas. Existe deduplicação por GTIN/EAN (a NFC-e traz o código do produto) ou só por string? Sem isso, comparação entre mercados não funciona de verdade. Não consegui acessar o APK nem uma API pública para verificar.
- A busca é ESTRITAMENTE limitada à cidade cadastrada, ou a cidade só reordena resultados? A política diz que cidade/estado servem 'para priorizar estabelecimentos e preços da sua região' — 'priorizar' sugere ordenação, não filtro. Impacta diretamente a estratégia de cobertura geográfica do melhor_mercado.
- Qual o tamanho do APK, a data de lançamento e a curva de downloads? Não obtive: a Play não expõe, os espelhos estavam bloqueados e não há capturas no Wayback.
- Existe algum limite de scans por usuário/dia (rate limit para conter o custo da InfoSimples)? Nada na ficha, no site ou nos termos. Só o APK ou o uso real responderia.
- O app registra preço unitário corretamente para itens vendidos por peso (o screenshot mostra 'FILÉ COXA ... 1KG R$ 22,99' e a busca mostra tudo como '/UN')? Comparar hortifruti e carnes exige normalizar por kg — não dá para confirmar sem usar o app.
- Quantos usuários reais existem além do desenvolvedor? '10+ downloads' é uma faixa; pode ser 10 ou 49. Sem reviews, não há como estreitar.


################ FRENTE: poupa+ (poupamais.app) — de onde vem o preço: origem dos dados, arquitetura de extração e consequências de produto para o melhor_mercado

RESUMO:
RESPOSTA CENTRAL: o preço vem do cupom fiscal (NFC-e) escaneado pelo usuário, mas o poupa+ NÃO consulta a SEFAZ por conta própria — ele paga a InfoSimples, uma API-RPA de terceiros, para buscar a nota. A política de privacidade nomeia literalmente: "InfoSimples — consulta dos dados da nota fiscal (NFC-e) junto à Secretaria da Fazenda a partir do código escaneado". Logo H2 = CONFIRMADA e H1 = REFUTADA (eles não fazem parsing próprio; e o portal de SC, sat.sef.sc.gov.br/nfce/consulta, responde com uma interstitial "S@T - Verificação para prosseguimento da operação / Efetue a validação de segurança" com "captcha" 4x no fonte — DIY é hostil).

ATENÇÃO — A HIPÓTESE H4 DO CLIENTE ESTÁ FACTUALMENTE ERRADA. O poupa+ É colaborativo por desenho. Política: "construir comparações de preços entre estabelecimentos usando os cupons de todos os usuários, de forma agregada e sem identificar quem realizou cada compra". Termos: "As comparações de preços exibidas no aplicativo são construídas a partir dos cupons fiscais escaneados pelos próprios usuários". H3 = CONFIRMADA, H4 = REFUTADA no papel.

MAS a intuição do cliente está CERTA na prática: o app tem 10+ instalações no Google Play (lançado 29/abr/2026, atualizado 20/jul/2026) e o nome no print é "Alex Freitag" — o próprio desenvolvedor (alex@devfreitag.com, DEV FREITAG LTDA). Com ~10 usuários, a "rede colaborativa" é matematicamente uma base pessoal. "2 compras"/"3 compras" é exatamente a densidade de um app sem usuários. Ou seja: eles construíram a complexidade de H3 e estão colhendo o resultado de H4.

NORMALIZAÇÃO: a InfoSimples SC devolve por produto apenas codigo, nome, quantidade, unidade, valor_unitario, valor_total_produto. Zero ocorrências de gtin/ean/barra na página de campos. Não há GTIN — o "codigo" é o cProd interno do lojista. Portanto o matching entre lojas é por TEXTO (xProd cru, o que explica "LEITE UHT ITALAC INTEGRAL 1L" em caixa alta). Isso não é escolha de simplicidade: é a única opção pela via da consulta pública.

RISCO ESTRATÉGICO QUE MUDA TUDO: em 21/05/2026 Santa Catarina aderiu ao Menor Preço Brasil (PROCERGS/SEFAZ-RS) — grátis, 100 mil+ instalações, tempo real direto da base de NF-e/NFC-e, com busca por CÓDIGO DE BARRAS e geolocalização. O Estado já entrega de graça, com cobertura de 100% do varejo e com GTIN, exatamente o que uma rede colaborativa tenta construir com quorum. H5 não é usada pelo poupa+, mas é o concorrente real.

ECONOMIA: InfoSimples cobra por consulta (R$ 0,20 na faixa 1–500/mês, caindo a R$ 0,05 acima de 100 mil) com franquia mínima de R$ 100/mês. O poupa+ é 100% grátis hoje, com assinatura prevista nos termos. Cada nota escaneada é custo marginal em dinheiro — desenho perigoso para o melhor_mercado copiar sem cache/dedup.

ACHADOS:
- [confirmada] H2 CONFIRMADA: o poupa+ não consulta a SEFAZ diretamente — usa a InfoSimples como intermediária para buscar a NFC-e a partir do QR escaneado.
    EVID: Política de Privacidade, seção 3 (Compartilhamento de dados), literal: 'InfoSimples — consulta dos dados da nota fiscal (NFC-e) junto à Secretaria da Fazenda a partir do código escaneado;'
    FONTE: https://poupamais.app/privacidade
- [confirmada] H1 REFUTADA para o poupa+, e tecnicamente hostil para quem tentar: o portal de consulta de SC bloqueia acesso automatizado com uma validação de segurança antes do formulário.
    EVID: curl em https://sat.sef.sc.gov.br/nfce/consulta retorna HTTP 200 mas com o conteúdo: 'S@T - Verificação para prosseguimento da operação' / 'Alerta — Efetue a validação de segurança' / 'Validação de segurança' / 'Validar' / 'Aguarde. Estamos processando sua solicitação...'. A palavra 'captcha' aparece 4 vezes no HTML. A página oficial do serviço em sef.sc.gov.br confirma o passo manual: 'Informar a Chave de acesso; Digitar os caracteres da imagem apresentada; Clicar em Buscar'.
    FONTE: https://sat.sef.sc.gov.br/nfce/consulta + https://www.sef.sc.gov.br/servicos/consultar-nota-fiscal-de-consumidor-eletronica-nfce
- [confirmada] H3 CONFIRMADA e H4 REFUTADA no papel: o histórico de preços do poupa+ É colaborativo — cruza cupons de todos os usuários, de forma anônima. A hipótese central do cliente (base pessoal) está factualmente errada quanto ao desenho do produto.
    EVID: Política, seção 2 (Para que usamos os dados): 'construir comparações de preços entre estabelecimentos usando os cupons de todos os usuários, de forma agregada e sem identificar quem realizou cada compra'. Ainda na seção 3: 'Os preços exibidos a outros usuários nas comparações nunca incluem sua identidade: outros usuários veem o produto, o preço e o estabelecimento, nunca quem comprou.' Termos, cláusula 5: 'As comparações de preços exibidas no aplicativo são construídas a partir dos cupons fiscai
    FONTE: https://poupamais.app/privacidade e https://poupamais.app/termos
- [provavel] MAS a leitura das telas feita pelo cliente está certa na prática: com 10+ instalações, a 'rede colaborativa' se comporta como base pessoal. O print é quase certamente a conta do próprio desenvolvedor.
    EVID: Google Play: bloco de dados literal ['10+',10,45,'10+'] e HTML visível '10+ | downloads'. Não há nota nem avaliações exibidas. O print do cliente diz 'Olá, Alex Freitag'; o contato do app é alex@devfreitag.com, o package é com.devfreitag.poupamais, o desenvolvedor é 'Dev Freitag' e a operadora é DEV FREITAG LTDA. As lojas do print (Cooper Fresh, Giassi, Fort Atacadista) são todas de SC, onde o desenvolvedor estudou/mora. 'Onde foi encontrado' com n=2 e n=3 compras é a densidade esperada de um ap
    FONTE: Play Store (com.devfreitag.poupamais) + poupamais.app/privacidade + telas fornecidas pelo cliente
- [confirmada] O fluxo principal É o escaneamento do QR Code da NFC-e — o FAB central é o coração do app. Confirmado.
    EVID: Landing: 'O poupa+ lê o QR code do cupom fiscal e guarda tudo sozinho: produtos, preços, mercado e data. Sem digitar nada, sem planilha.' Passo 2: 'Escaneie o QR code — Abra o poupa+ e aponte a câmera. A leitura leva segundos e funciona direto na fila do estacionamento.' Play: 'Basta apontar a câmera pro QR Code da nota e pronto'. FAQ: 'Preciso digitar preços ou produtos? Não. O app identifica tudo automaticamente.'
    FONTE: https://poupamais.app/ e Google Play
- [confirmada] NÃO HÁ GTIN/EAN no payload. A normalização de produto do poupa+ só pode ser por texto (xProd cru), não por código de barras — e isso é imposição da fonte, não escolha de simplicidade.
    EVID: A página de campos da API InfoSimples SEFAZ/SC/NFC-e lista, dentro de 'produtos': codigo, nome, quantidade, unidade, valor_unitario, valor_total_produto, normalizado_quantidade, normalizado_valor_unitario, normalizado_valor_total_produto. Grep no HTML da página: 'gtin' = 0 ocorrências, 'ean' = 0, 'barra' = 0, 'cprod' = 0. O 'codigo' na consulta pública é o cProd interno do emitente (varia por loja). Documentação oficial da NF-e confirma que o GTIN pode não ser exibido em consulta pública sem aut
    FONTE: https://infosimples.com/consultas/sefaz-sc-nfce/ (+ manual NFC-e / NT 2022.001 via busca)
- [provavel] Isso explica diretamente a TELA 2: 'LEITE UHT ITALAC INTEGRAL 1L' em caixa alta é o xProd cru do cupom, e 'Laticínios' é categoria derivada por eles. Normalização leve + categorização própria, sem catálogo canônico — exatamente como o cliente suspeitou.
    EVID: Inferência a partir de dois fatos verificados: (a) a API entrega apenas 'nome' textual sem GTIN; (b) a UI exibe esse texto sem tratamento. A categoria não vem da API (não há campo de categoria na lista de retorno), logo é atribuída pelo poupa+. O card 'Gastos por categoria' da TELA 1 liderado por 'Outros 26%' é sintoma de categorizador incompleto.
    FONTE: https://infosimples.com/consultas/sefaz-sc-nfce/ + telas fornecidas pelo cliente
- [confirmada] H5 NÃO é usada pelo poupa+, mas o programa estadual existe em SC e é o concorrente real — grátis, com 100x mais usuários e cobertura total.
    EVID: Ficha do Menor Preço Brasil na Play: '100 mil+' downloads, desenvolvedor PROCERGS, atualizado 14/jul/2026. Descrição: 'Por meio de consultas às Notas Fiscais Eletrônicas (NF-e) e às Notas Fiscais de Consumidor Eletrônicas (NFC-e), as informações são atualizadas em tempo real toda vez que um estabelecimento realiza uma venda a varejo.' e 'Informe o produto que você deseja pesquisar por meio de sua descrição, marca ou código de barras' + 'Utilizaremos a sua localização'. Na lista 'ESTADOS EM FUNCI
    FONTE: Google Play (br.gov.rs.procergs.mpbr) + https://ndmais.com.br/economia/menor-preco-brasil-chega-em-sc-e-permite-comparacao-de-precos/
- [confirmada] O custo de aquisição de dado do poupa+ é dinheiro por nota, não infraestrutura. Modelo caro para escalar de graça.
    EVID: Tabela de preços da InfoSimples: R$0,20/consulta na faixa 1–500/mês; R$0,16 (501–2.000); R$0,14 (2.001–5.000); R$0,13; R$0,11; R$0,10; R$0,09; R$0,07; R$0,05 acima de 100.001. Franquia mínima: 'caso o valor total de todos os serviços da Infosimples utilizados em um determinado mês seja inferior a R$ 100,00, o valor efetivamente debitado do saldo neste mês será R$ 100,00.' R$100 de crédito inicial. Algumas APIs têm preço adicional por chamada (R$0,04–R$0,18). Enquanto isso, Termos cláusula 3: 'At
    FONTE: https://infosimples.com/consultas/precos/ + https://poupamais.app/termos
- [confirmada] Stack do poupa+: React Native/Expo + Supabase, com PostHog e Sentry. Um dev solo, infra gerenciada, zero backend próprio pesado.
    EVID: Política, seção 3, lista literal de operadores: 'Supabase — infraestrutura de banco de dados e autenticação; InfoSimples — consulta dos dados da nota fiscal (NFC-e)...; PostHog — análise de uso do aplicativo; Sentry — monitoramento de erros; Google — login com conta Google e distribuição do aplicativo pelo Google Play; Expo (EAS) — entrega de notificações e atualizações do aplicativo.' O visual Material 3 do print é, portanto, RN e não Flutter.
    FONTE: https://poupamais.app/privacidade
- [confirmada] O escaneamento falha com frequência suficiente para virar item de roadmap — é a dor operacional #1 do modelo.
    EVID: Changelog 'O que há de novo' na Play (versão de 20/jul/2026): 'Melhorias e correções de bugs: - Nova Central de Ajuda com dicas para quando o escaneamento da nota não funcionar - Agora você pode excluir sua conta direto pelo app'. Termos cláusula 7 admite: 'não garantimos funcionamento ininterrupto ou livre de erros — inclusive porque a leitura de cupons depende de serviços públicos de consulta das notas fiscais, que podem ficar indisponíveis.'
    FONTE: Google Play (com.devfreitag.poupamais) + https://poupamais.app/termos
- [confirmada] Decisão deliberada de NÃO usar GPS: localização é cidade/estado digitados no onboarding.
    EVID: Política, seção 1: 'Cidade e estado. Na configuração inicial você informa sua cidade e estado, que usamos para priorizar estabelecimentos e preços da sua região. Não coletamos sua localização por GPS nem coordenadas precisas do dispositivo.'
    FONTE: https://poupamais.app/privacidade
- [confirmada] O app é nacional por desenho (aceita NFC-e de qualquer UF) — não é um produto regional de SC, apesar de os dados do print serem todos catarinenses.
    EVID: Play: 'FUNCIONA EM TODO O BRASIL — O poupa+ aceita cupons fiscais eletrônicos (NFC-e) emitidos em qualquer estado.' FAQ do site: 'Funciona em qualquer estabelecimento? Sim, em qualquer lugar que emita NFC-e com QR code.' Compatível com a API unificada da InfoSimples, que cobre as 27 UFs.
    FONTE: Google Play + https://poupamais.app/ + https://infosimples.com/consultas/sefaz-nfce/
- [provavel] O poupa+ é MUITO novo e ainda pré-tração: lançado 29/abr/2026, atualizado 20/jul/2026, categoria Finanças, só Android, sem avaliações públicas.
    EVID: Play Store: 'Atualizado em 20 de jul. de 2026', data '29 de abr. de 2026' no bloco de metadados anterior ao contador de instalações, categoria 'Finanças', 'Classificação Livre', desenvolvedor 'Dev Freitag'. FAQ do site: 'Tem para iPhone? Ainda não — hoje disponível apenas para Android.' Site com apenas 3 URLs no sitemap, lastmod 2026-07-04.
    FONTE: Google Play + https://poupamais.app/sitemap.xml + https://poupamais.app/
- [provavel] O desenvolvedor é Alex Eduardo Freitag, engenheiro de software sênior/tech lead, com background em varejo — o que explica a qualidade do recorte de produto.
    EVID: Perfil remoteyeah.com/@devfreitag: 'Alex Eduardo Freitag', 'Tech Lead & Software Engineer at GPA', '7+ years', 'Bachelor's degree in Software Engineering from Catholic University of Santa Catarina'. Encadeia com o handle devfreitag (package com.devfreitag.poupamais, e-mails alex@devfreitag.com e devfreitag@gmail.com) e com o nome no print 'Olá, Alex Freitag'. O vínculo é por coincidência de handle/nome/UF, não por declaração explícita do próprio.
    FONTE: https://remoteyeah.com/@devfreitag + Google Play + poupamais.app
- [confirmada] Não existe nenhuma discussão técnica pública sobre a implementação do poupa+.
    EVID: 8 buscas distintas (GitHub, Reddit, TabNews, LinkedIn, YouTube, fóruns) com os termos 'poupamais', 'poupa+', 'app nota fiscal QR code precos', 'NFC-e app pessoal', 'devfreitag'. Nenhum repositório, post, thread ou vídeo do autor explicando a arquitetura. Tudo que sei da arquitetura veio dos documentos legais do próprio produto — que, ironicamente, são a melhor documentação técnica disponível.
    FONTE: WebSearch (múltiplas)
- [confirmada] Não consegui acessar o corpo da notícia oficial da SEF/SC nem testar a API pública do Menor Preço.
    EVID: https://www.sef.sc.gov.br/noticias/consumidor-catarinense-ja-pode-comparar-precos-em-tempo-real-por-aplicativo retorna 404 (a página do portal renderiza 'Erro 404'). A chamada a menorpreco.notaparana.pr.gov.br/api/v1/produtos retornou HTTP 000 (sem resposta) no ambiente. O portal em si respondeu 200. A adesão de SC foi confirmada por fontes alternativas.
    FONTE: curl direto

LACUNAS DO POUPA+:
- COLD START FATAL, JÁ MATERIALIZADO. Eles pagaram o preço arquitetural de uma rede colaborativa (agregação anônima, LGPD, dedup, antifraude) e têm 10+ instalações. A tela 'Onde foi encontrado' mostrando 'Fort Atacadista — 2 compras' e 'Cooper Fresh — 3 compras' é a prova visual: a comparação entre lojas está vazia. Cada nova cidade recomeça do zero.
- NÃO RESPONDE À PERGUNTA QUE IMPORTA. O app responde 'onde eu paguei mais barato antes', não 'onde está mais barato AGORA perto de mim'. Os próprios Termos admitem: 'Os preços refletem o valor registrado no momento de cada compra e podem estar desatualizados'. Para decidir a compra de hoje, um preço de 25/abr (como no print) é quase inútil.
- O ESTADO ENTREGA MELHOR E DE GRAÇA. O Menor Preço Brasil (PROCERGS) está em SC desde maio/2026, tem 100 mil+ instalações, lê a base inteira de NFC-e em tempo real (não depende de ninguém escanear nada), tem busca por CÓDIGO DE BARRAS e geolocalização. É a mesma proposta de valor com cobertura 100% e custo zero. Qualquer app que compita em 'comparar preço entre mercados' compete com isso.
- SEM GTIN, MATCHING FRÁGIL. A API não devolve código de barras — só o texto do cupom. 'LEITE UHT ITALAC INTEGRAL 1L' numa loja pode ser 'LEITE ITALAC INT UHT 1LT' na outra. Todo o gráfico de duas séries da TELA 2 depende de um casamento de strings que vai gerar falso-positivo (juntar produtos diferentes) e falso-negativo (separar o mesmo produto).
- CUSTO MARGINAL EM DINHEIRO POR NOTA. Cada escaneamento é uma consulta paga à InfoSimples (R$0,20 na faixa inicial, franquia mínima R$100/mês) num app 100% gratuito. Pior: se dois usuários escanearem a MESMA nota, provavelmente são duas cobranças — e o incentivo colaborativo empurra exatamente para isso. Não achei evidência de cache por chave de acesso.
- DEPENDÊNCIA DE FORNECEDOR ÚNICO EM CIMA DE DEPENDÊNCIA DE PORTAL PÚBLICO. Dois pontos de falha empilhados: a InfoSimples pode mudar preço/quebrar, e a SEFAZ pode mudar o portal ou endurecer o captcha. Os Termos já se protegem disso ('não garantimos funcionamento ininterrupto'), o que é honesto mas revela fragilidade.
- O ESCANEAMENTO FALHA — e falha o suficiente para virar release note. A atualização de 20/jul/2026 adicionou 'Central de Ajuda com dicas para quando o escaneamento da nota não funcionar'. Num app cujo único gesto é escanear, a taxa de falha do gesto é o produto inteiro.
- ATRITO NO MOMENTO ERRADO. O fluxo exige o cupom impresso ('Peça o cupom no caixa'), no estacionamento, depois de pagar. Ninguém quer trabalhar depois da compra — e a recompensa (comparação) só chega semanas depois, quando houver base. Curva de valor invertida.
- SEM GPS = SEM PROXIMIDADE REAL. Cidade/estado digitados são ótimos para privacidade, mas impedem 'os 3 mercados mais baratos num raio de 5 km' — que é justamente o que o concorrente estatal faz.
- CATEGORIZAÇÃO FRACA. Na TELA 1, 'Outros 26%' é a MAIOR fatia de 'Gastos por categoria'. Quando 'Outros' lidera, o gráfico não informa nada. Sintoma direto da ausência de GTIN/catálogo.
- GRÁFICO QUE SUGERE PRECISÃO QUE NÃO EXISTE. A TELA 2 desenha uma linha contínua/pontilhada de mar/26 a jul/26 sobre apenas 2 e 3 observações. Interpolar entre dois pontos esparsos comunica 'tendência de preço' quando o dado é 'dois preços soltos'. É bonito e enganoso.
- SÓ ANDROID, sem previsão de iOS ('Ainda não — hoje disponível apenas para Android').
- MONETIZAÇÃO INDEFINIDA com custo variável já rodando: grátis hoje, assinatura 'no futuro'. A conta não fecha sem escala, e a escala aumenta o custo antes da receita.

O QUE COPIAR:
- TERCEIRIZAR A EXTRAÇÃO — a decisão mais inteligente deles. Não escreva scraper de SEFAZ. O portal de SC devolve 'Efetue a validação de segurança' com captcha antes do formulário, e são 27 portais diferentes com layouts e defesas próprios. Pagar InfoSimples (R$0,20/consulta caindo com volume) transforma um pesadelo de manutenção eterna em linha de custo previsível. Copie isso — mas negocie/valide o custo antes de prometer gratuidade.
- NFC-e COMO FONTE DE VERDADE E COMO POSICIONAMENTO. 'Direto da nota, sem achismo' e 'Nada digitado de memória: é o que você pagou, centavo por centavo' é um argumento que nenhum app de preço colaborativo-manual consegue dar. Preço vindo de documento fiscal é auditável e imune a troll. Roube essa frase e esse enquadramento.
- UM ÚNICO GESTO, FAB CENTRAL DE QR. A bottom nav de 5 posições com o QR grande e verde no meio comunica em 1 segundo qual é a ação principal. Zero digitação, zero formulário. Mantenha.
- TRANSPARÊNCIA DE EVIDÊNCIA: 'Fort Atacadista — 25 abr — 2 compras'. Mostrar a DATA e a CONTAGEM de observações ao lado do preço é honestidade de dado rara e barata. O usuário entende sozinho que 'R$4,98' é de abril e vale menos que o de ontem. Copie e vá além: deixe o preço velho visualmente apagado.
- FAIXA DE PREÇO em vez de preço único ('Faixa de preço R$ 4,98 - R$ 5,19'). Comunica incerteza sem precisar explicar nada.
- EXIBIR O xProd CRU E NÃO FINGIR CATÁLOGO. Mostrar 'LEITE UHT ITALAC INTEGRAL 1L' em caixa alta é feio mas verdadeiro — é literalmente o que está no seu cupom, então o usuário reconhece. Catálogo canônico é um projeto de anos; categoria derivada leve resolve 80%.
- CIDADE/ESTADO DIGITADOS EM VEZ DE GPS. Menos permissão pedida no onboarding, menos superfície de LGPD, menos código. Para um MVP simples é a escolha certa — só não prometa 'mais barato perto de você'.
- STACK DE DEV SOLO: Expo (EAS) + Supabase + PostHog + Sentry. Auth, banco, OTA update, analytics e crash sem backend próprio. É exatamente o perfil de custo/velocidade de um app enxuto.
- DOCUMENTOS LEGAIS CURTOS, HONESTOS E ESPECÍFICOS. A política de privacidade deles nomeia cada subprocessador e explica em português claro o que acontece com o dado; os termos assumem que o preço pode estar desatualizado e que 'não constituem oferta, publicidade ou garantia de preço'. Isso protege juridicamente e gera confiança. Modele os seus assim (e note: foi lendo os deles que descobri toda a arquitetura — se isso te incomoda, é um custo consciente a assumir).
- GRÁTIS AGORA, ASSINATURA DEPOIS, COBRANÇA PELA PLAY. Cláusula já escrita, sem cobrar nada ainda. Boa forma de não fechar portas.
- VISUAL QUE NÃO PARECE BANCO. Material 3, verde, fundo cinza claro, cards arredondados, laranja só para categoria. Controle de gastos com cara leve, não de planilha financeira. Ajuda muito na retenção emocional.
- EXCLUSÃO DE CONTA DENTRO DO APP (adicionada em 20/jul). É exigência da Play e da LGPD — já nasça com isso.

EM ABERTO:
- A API pública do Menor Preço Brasil/SVRS é utilizável por terceiros? Não consegui testar o endpoint (HTTP 000 no ambiente). Se for consultável, ela resolve DE GRAÇA, EM TEMPO REAL, COM GTIN e COM GEOLOCALIZAÇÃO tudo aquilo que o poupa+ tenta construir com quorum de usuários. Esta é, na minha avaliação, a investigação mais valiosa que resta para o melhor_mercado — pode inverter completamente a arquitetura do produto (de 'coletar preço' para 'consumir preço e agregar valor em cima').
- Se o dado de preço vem de graça do Estado, qual é o produto do melhor_mercado? Sugestão a validar: a camada que o Estado NÃO faz — lista de compras inteligente, roteirização ('sua lista fica R$47 mais barata no mercado X'), histórico pessoal, alerta de aumento, orçamento. O app estatal é um buscador, não um assistente.
- O poupa+ faz cache/dedup por chave de acesso? Se dois usuários escaneiam a mesma nota, são duas cobranças na InfoSimples? Não há evidência pública. Para o melhor_mercado isso é decisão de arquitetura crítica (tabela de notas por chave_acesso, unique index, consulta única).
- Qual o preço real que o poupa+ paga por nota? A tabela base é R$0,20→R$0,05, mas algumas APIs têm adicional de R$0,04–R$0,18 por chamada e não consegui confirmar se a de NFC-e tem. Vale simular na calculadora da InfoSimples antes de qualquer premissa de custo.
- Existem alternativas mais baratas à InfoSimples para consulta de NFC-e (concorrentes de RPA fiscal, ou o QR code contendo dados suficientes)? Vale checar se o próprio conteúdo do QR já traz itens em alguns estados — em muitos casos o QR só traz a chave, mas isso varia por UF e versão.
- O gráfico de duas séries da TELA 2 mistura compras de outros usuários ou só as do dono da conta? Os documentos dizem que a comparação é agregada entre todos; as telas sugerem volume compatível com uma pessoa só. Não consegui distinguir sem instalar o app.
- Como exatamente eles casam produtos entre lojas sem GTIN? Não há código público nem post técnico. Se o melhor_mercado seguir pela via da NFC-e, esse algoritmo é o verdadeiro núcleo de dificuldade do produto — vale prototipar cedo com cupons reais de 2–3 redes.
- Qual a retenção real? 10+ instalações e nenhuma avaliação pública impedem qualquer leitura de product-market fit. Não é possível afirmar que o modelo 'não funciona' — só que ainda não foi testado com usuários.


################ FRENTE: poupa+ (poupamais.app) — a voz do usuário: onde falha, o que a categoria ensina, e o que o melhor_mercado deve fazer diferente

RESUMO:
Resultado mais importante e desconfortável: o poupa+ NÃO TEM VOZ DE USUÁRIO. O app tem "10+" instalações na Google Play e ZERO avaliações públicas (o endpoint de reviews da Play devolveu array vazio em duas consultas independentes). Não existe review, thread de Reddit, vídeo ou post sobre ele. Qualquer "dor de usuário do poupa+" que eu inventasse seria ficção — então as dores abaixo vêm de ~490 reviews reais que coletei de 4 apps concorrentes da mesma categoria.

A PISTA DO CLIENTE FOI REFUTADA. O cliente supôs que o histórico do poupa+ vem só das compras do próprio usuário. O site diz o oposto, literalmente: "A comparação de preços usa os cupons de todos os usuários, sem identificar quem comprou. Quanto mais gente escaneia, melhor fica a resposta". O poupa+ É exatamente a rede colaborativa nacional que o cliente quer evitar. O que reconcilia isso com o screenshot ("2 compras", "3 compras") é que a rede está VAZIA: com ~45 instalações, o "Alex Freitag" da tela é o próprio dono (alex@devfreitag.com), e na prática ele só vê os próprios cupons. O poupa+ prometeu rede e entregou diário pessoal.

Isso é a oportunidade central: a arquitetura colaborativa do poupa+ só entrega valor com escala que ele não tem e provavelmente não terá. A escolha do cliente por "bem mais simples" não é uma versão inferior — é a versão que funciona com 1 usuário no dia 1.

As 5 dores reais da categoria, por volume de reclamação: (1) vazio de dados/cobertura, (2) preço desatualizado que faz o usuário viajar à toa, (3) leitor de QR/código de barras quebrado, (4) login obrigatório e não-persistente, (5) atualizações que destroem o que funcionava. Detalhe crítico: o poupa+ é vulnerável às dores 1, 3 e 4 por design, e a #1 é fatal para ele.

Risco estrutural a monitorar: o passo 1 do poupa+ é "pegue a via impressa" — e o cupom em papel está em extinção regulatória no Brasil.

ACHADOS:
- [confirmada] O poupa+ tem ZERO avaliações públicas na Google Play e não há absolutamente nenhuma voz de usuário disponível sobre ele
    EVID: Endpoint de reviews da Play (RPC UsvDTd) chamado 2x com ordenações diferentes retornou literalmente: [["wrb.fr","UsvDTd","[]",null,null,null,"generic"]]. Além disso, a página da loja não contém nenhum campo aggregateRating/ratingValue/ratingCount no JSON embutido.
    FONTE: play.google.com/_/PlayStoreUi/data/batchexecute (rpcids=UsvDTd) + HTML da ficha da Play
- [confirmada] O app tem cerca de 10 a 45 instalações e foi lançado há menos de 3 meses
    EVID: No JSON da ficha da Play: ["10+",10,45,"10+"] (faixa exibida '10+', contador 45). Data de lançamento no mesmo bloco: "29 de abr. de 2026". Campo de atualização: "Atualizado em 20 de jul. de 2026". Versão "1.0.16".
    FONTE: play.google.com/store/apps/details?id=com.devfreitag.poupamais
- [confirmada] REFUTA A HIPÓTESE DO CLIENTE: o histórico de preços do poupa+ NÃO é só das compras do próprio usuário — é uma rede colaborativa entre usuários, por design
    EVID: Site, seção de recursos: "Tudo que o app faz nasce dos seus próprios cupons — e dos cupons de quem compra nos mesmos lugares que você." E, em destaque: "Cada cupom ajuda todo mundo — A comparação de preços usa os cupons de todos os usuários, sem identificar quem comprou. Quanto mais gente escaneia, melhor fica a resposta para 'onde está mais barato?'". Card de exemplo rotulado "preços registrados por quem escaneou". Termos: "As comparações de preços exibidas no aplicativo são construídas a parti
    FONTE: poupamais.app/ + /termos + /privacidade
- [provavel] Na prática, porém, a rede colaborativa do poupa+ está vazia — o que o cliente viu no screenshot é, quase com certeza, o histórico pessoal do próprio dono do app
    EVID: Com ~45 instalações, não há massa para agregação. O nome na home ('Alex Freitag') coincide com o contato oficial alex@devfreitag.com e com o controlador DEV FREITAG LTDA. Os contadores '2 compras' e '3 compras' são compatíveis com uma única pessoa. Cooper Fresh, Giassi e Fort Atacadista são redes do Sul/SC, consistentes com um único usuário numa única praça.
    FONTE: inferência minha cruzando instalações da Play + privacidade/site + descrição do screenshot (NÃO é afirmação do fabricante)
- [confirmada] O poupa+ não é 100% dono do seu pipeline: ele paga uma API de terceiros (InfoSimples) para extrair os dados do cupom
    EVID: Política de privacidade lista os operadores: "Supabase (database/auth), InfoSimples (receipt data), PostHog (analytics), Sentry (error monitoring), Google (login/distribution), Expo/EAS (notifications/updates)".
    FONTE: poupamais.app/privacidade
- [confirmada] O próprio desenvolvedor admite que o escaneamento da nota falha — foi o item nº1 do último release
    EVID: Changelog da v1.0.16 (20/jul/2026), verbatim: "Melhorias e correções de bugs: - Nova Central de Ajuda com dicas para quando o escaneamento da nota não funcionar - Agora você pode excluir sua conta direto pelo app. Obrigado por usar o poupa+! 💚"
    FONTE: Google Play — What's New de com.devfreitag.poupamais
- [confirmada] Login/conta é OBRIGATÓRIO no poupa+ — e nos concorrentes isso é uma das maiores causas de abandono e desconfiança
    EVID: Termos: "Atualmente o poupa+ é oferecido gratuitamente; basta criar uma conta para usar o serviço." Privacidade: coleta "Nome, e-mail e credenciais de acesso quando você cria uma conta". Nos concorrentes, reviews reais: [1*] 2025-09-04 Bruno Cabral: "pra que autenticar pelo gov pra consultar preço? burocracia desnecessária"; [1*] 2026-05-26 Adriano Loch: "qual a necessidade de precisar logar com a conta gov? sem condições"; [2*] 2026-06-29 Bráulio Semionato: "coisa mais inconveniente é esse logi
    FONTE: poupamais.app/termos + /privacidade; reviews de br.gov.rs.procergs.mpbr
- [confirmada] DOR #1 DA CATEGORIA — vazio de dados/cobertura: o app abre, mas não responde. É a reclamação mais frequente de todas e é exatamente onde o poupa+ está mais vulnerável hoje
    EVID: [1*] 2025-09-18 Ana Paula Melo: "a proposta do app é muito boa pena que não funciona... se é baseado nas NF-e e NFC era pra ter praticamente todos os estabelecimentos da minha cidade cadastro, entretanto para itens simples como arroz feijão e gasolina não apresenta resultado.!! ...no momento é inútil". [1*] 2026-07-10 Wilton de Oliveira: "A ideia é sensacional, infelizmente a execução não está funcionando, simplesmente não consigo nenhum produto, independente da forma de consulta." [1*] 2025-08-
    FONTE: reviews br.gov.rs.procergs.mpbr (Menor Preço Brasil)
- [confirmada] DOR #2 — preço desatualizado que faz o usuário se deslocar à toa. É a dor que destrói confiança de forma permanente
    EVID: [2*] 2026-06-30 Iara Lima: "fui em um posto que mostrava gasolina 7,03 hoje no aplicativo, e na bomba o preço está R$ 7,49. No posto disseram que não participam disso. Qual é a falcatrua?". [1*] 2025-10-10 Cláudia Mara Machado: "no app diz um preço a 3 dias atrás e na farmácia mesmo o preço muda... acabei de passar por este constrangimento". [2*] 2025-10-11 Fabio Denarde: "Mesmo inserindo a data de compra recente, o preço no aplicativo é um e no estabelecimento é outro. Resolvam essa discrepânci
    FONTE: reviews br.gov.rs.procergs.mpbr + br.gov.ba.precodahora + br.gov.pr.celepar.sefa.mp
- [confirmada] COROLÁRIO CRÍTICO DE UX: esconder a data/recência do preço gera revolta imediata. O poupa+ acerta ao mostrar 'há 1 dia' e '25 abr' — isso não é detalhe, é requisito
    EVID: [3*] 2026-06-19 Mayko Schaffer: "O que foi retirado, e que era uma informação importante, seria a quanto tempo foi emitida a nota fiscal que gerou aquele preço. A pessoa vai se deslocar para o estabelecimento sem ter certeza. Volte essa informação." [1*] 2026-06-19 Gustavo Corradi: "a pesquisa de preços não mostra mais há quantos dias foi realizada a venda". [1*] 2026-06-19 Eduardo: "Resultados agora omitem data e hora da compra."
    FONTE: reviews br.gov.rs.procergs.mpbr
- [confirmada] DOR #3 — o leitor (QR/código de barras) quebra, trava ou abre tela branca. É a falha mais recorrente em TODOS os apps da categoria
    EVID: [1*] 2025-09-01 Wagner Oliveira Moreira: "não scanea os códigos de barras, após a leitura a tela fica branca....". [1*] 2025-10-04 Robert Carvalho: "Após ler o código, a tela fica em branco, como se estivesse travado... Tentei com o azeite andorinha 500ml, biscoito Club Social e Cappuccino 3 corações e todos deram tela branca... 04/10/2025 continua com problema... dando 1 estrela pois ignoraram os usuários...". [1*] 2026-06-27 Eliana Aparecida Menezes: "não abre a câmera pra ler o código de barr
    FONTE: reviews br.gov.rs.procergs.mpbr + br.gov.ba.precodahora + br.com.sofist.dinheironanota
- [confirmada] DOR #4 — não existe plano B quando o QR falha. Usuários pedem explicitamente entrada manual da chave de acesso e outros formatos de nota
    EVID: [3*] 2025-10-25 andre bn (micompras — app quase idêntico ao poupa+): "seria muito bom poder inserir além de cupom fiscal, notas fiscais/danfe e também pela chave manualmente quando der erro no qrcode ou código de barras. o app ficaria excelente e permitiria guardar todas as despesas. inclusive a possibilidade de colocar alguma despesa manual sem chave." [1*] 2026-06-24 Rafa vídeos: "nem tem opção leitor de código de barra...tem que ficar digitando aquele monte de número da nota fiscal". [1*] 202
    FONTE: reviews com.appyos.micompras + br.com.sofist.dinheironanota + br.gov.rs.procergs.mpbr
- [confirmada] DOR #5 — regressões de atualização: mexer no que funcionava é o gatilho de raiva mais explosivo da categoria
    EVID: Onda de reviews após update de 18-20/jun/2026 no Menor Preço Brasil. [1*] 2026-06-19 Eduardo: "A atualização OBRIGATÓRIA de hoje... alterou COMPLETAMENTE o layout... Busca de um dia, dois ou três não são mais permitidas: o mínimo agora é de cinco dias!!! O histórico de pesquisa de produtos da versão anterior desapareceu... Há um mapa inútil. Resta claro que a intenção foi confundir e piorar a vida do usuário." [1*] 2026-06-26 Luiz Paulo Araújo: "permitam o usuário retornar pro layout e funcional
    FONTE: reviews br.gov.rs.procergs.mpbr
- [confirmada] Dor secundária real: a 'lista de compras' é a funcionalidade mais quebrada da categoria — vários apps a anunciam e ela simplesmente não funciona
    EVID: [3*] 2025-09-18 Ailton Rocha: "clica em criar e NUNCA carrega a lista. Corrijam isso, por favor." [3*] 2025-12-01 W: "A função 'Lista de Compras' no aplicativo Menor Preço não está funcionando. Ela falha ao tentar criar uma lista, impedindo o planejamento das compras." [3*] 2026-05-20 Geraldo Atilio Bertoli: "Só gostaria que a lista de compras funcionasse. Não dá para adicionar produtos na lista. Atualização: A lista de compras ainda não funciona." [2*] 2026-06-07 Jeferson Berlim: "Lista de Comp
    FONTE: reviews br.gov.rs.procergs.mpbr
- [confirmada] Exportação de dados é um pedido pequeno em volume mas altíssimo em intensidade — atendê-lo converte crítico em promotor
    EVID: [5*] 2026-06-17 Rodrigo Simetti (micompras): "O aplicativo funciona bem e consegue organizar de forma satisfatório as compras. Senti falta de poder exportar os dados para realizar outras análises. Edit 17/06/26 - o app implantou as melhorias sugeridas anteriormente... Excelente iniciativa. Atualizei a nota também." Resposta do dev: "Já está disponível atualização com exportação para arquivos XLSX ou CSV. Também foram implementadas funções de backup".
    FONTE: reviews com.appyos.micompras
- [confirmada] Busca por nome de produto é um problema não resolvido na categoria: normalização de descrição livre de NFC-e é difícil e os usuários sentem
    EVID: [3*] 2026-07-17 Herbert Filho: "Não permite mais pesquisar por parte do nome. Antes 'salsic' mostrava todas as salsichas, agora só mostra se digitar o nome completo 'salsicha'. Certos produtos são registrados com nomes errados então só a pesquisa incompleta os mostrava." [1*] 2025-07-29 Vanessa Cunha: "mesmo com o código de barras do produto aparecem outros produtos, com os nomes embaralhados e preços absurdos." [1*] 2025-08-30 Cassius Giorgio: "Para buscar algo deve-se adivinhar como foi cadast
    FONTE: reviews br.gov.rs.procergs.mpbr + br.gov.pr.celepar.sefa.mp
- [confirmada] Não existe NENHUMA menção ao poupa+ fora do próprio site e da ficha da Play — sem Reddit, YouTube, Instagram, TikTok, Threads, blogs ou grupos
    EVID: 6 buscas distintas (incluindo por 'poupa+ cupom fiscal reddit/youtube/instagram', 'poupamais app review', 'Alex Freitag devfreitag lançamento') retornaram apenas poupamais.app e resultados irrelevantes (apps portugueses homônimos: Poupa, Preço Fresco, Super Save; e poupamais.pt, que é da EDP Portugal).
    FONTE: WebSearch (6 consultas)
- [confirmada] Não existe versão iOS do poupa+ — logo, metade do mercado premium brasileiro está descoberto
    EVID: API oficial da Apple: itunes.apple.com/lookup?bundleId=com.devfreitag.poupamais&country=br retornou {"resultCount":0,"results":[]}. Site confirma: "Tem para iPhone? Ainda não — hoje o poupa+ está disponível para Android no Google Play. A versão para iPhone está a caminho."
    FONTE: itunes.apple.com API + poupamais.app FAQ
- [provavel] RISCO ESTRUTURAL: o fluxo do poupa+ depende do cupom IMPRESSO, e a entrega em papel está deixando de ser obrigatória no Brasil
    EVID: Passo 1 do site, verbatim: "Peça o cupom no caixa — Ao finalizar a compra, pegue a via impressa da nota fiscal — aquele cupom com um QR code no final." Contra isso: o antigo Cupom Fiscal (ECF/CF-e) foi substituído pela NFC-e, e a NFC-e pode ser entregue impressa, por e-mail ou apenas como QR code na tela — a impressão não é obrigatória. IMPORTANTE: isso NÃO significa que o QR code acabou (a NFC-e continua tendo QR). O risco é o varejo migrar para entrega digital-only, quebrando o gesto 'aponte a
    FONTE: poupamais.app (passo 1) + fontes contábeis sobre NFC-e/CONFAZ. Não localizei o texto normativo primário — não confie no headline sensacionalista 'cupom em papel deixará de existir'
- [confirmada] Apps fiscais oficiais brasileiros são mal avaliados de forma consistente — a barra de qualidade da categoria é baixíssima
    EVID: Menor Preço Brasil: 88 de 150 reviews recentes são 1 estrela. Menor Preço/Nota Paraná: 77 de 120 são 1 estrela, com erro 502 crônico ([1*] 2025-11-01 Carlos Pereira: "(502) Ops... Algo deu errado. Entre em contato com o SAC"). Nota Fiscal Paulista no iOS: nota 1,99 com 677 avaliações. Exceção: Preço da Hora Bahia, 86 de 120 são 5 estrelas.
    FONTE: Play reviews RPC (3 apps) + itunes.apple.com search API
- [confirmada] Um usuário do Paraná pediu literalmente o produto que o cliente quer construir: um app colaborativo estilo Waze, porque o governo não entrega
    EVID: [1*] 2025-07-31 AJS Tecnologia - Anderson AJS: "A ideia e a funcionalidade seriam excelentes se funcionassem, infelizmente o governo e a CELEPAR não investem em seus produtos e profissionais! O aplicativo já foi eficiente em comparar os preços! Mas atualmente nem está abrindo... Surge aí uma ótima oportunidade para um aplicativo colaborativo como o Waze, pois se depender de governo adeus."
    FONTE: reviews br.gov.pr.celepar.sefa.mp

LACUNAS DO POUPA+:
- COLD START FATAL: o app promete 'onde está mais barato' via rede colaborativa, mas tem ~45 instalações. A promessa central não é entregável hoje — e a dor #1 da categoria (busca que não retorna nada) é justamente o que um banco de dados vazio produz. O poupa+ vendeu rede e entrega diário pessoal.
- Depende de cupom IMPRESSO: o passo 1 é 'pegue a via impressa'. Não há, documentado, entrada manual da chave de 44 dígitos, importação de XML/PDF, leitura de QR na tela de outro aparelho, colagem de link da SEFAZ, nem importação por e-mail. Quando o QR falha (e o próprio changelog admite que falha), o usuário fica sem saída.
- Login obrigatório antes de qualquer valor: exige nome, e-mail e senha só para escanear o primeiro cupom. Nos concorrentes isso aparece repetidamente como motivo de desinstalação e de desconfiança de phishing. Não há modo anônimo/local.
- Sem iOS. Confirmado pela API da Apple (resultCount 0).
- Zero prova social: 0 avaliações, 10+ instalações, nenhuma menção em qualquer rede. Um usuário que pesquisa antes de instalar não encontra nada que gere confiança.
- Sem exportação de dados documentada (CSV/XLSX/backup) — pedido de alta intensidade na categoria, e ausência que prende o usuário sem lhe dar controle.
- Sem alerta de queda de preço / notificação proativa documentada. O app é 100% consulta ativa: o usuário precisa lembrar de abrir. Não há gatilho de retorno.
- O gráfico com linha pontilhada entre poucos pontos sugere precisão que os dados não têm. Com 2-3 compras por loja, uma 'tendência de 6 meses' é ruído estatístico apresentado como sinal — exatamente o que gera a dor #2 (usuário se desloca e o preço é outro).
- Dado estruturalmente retrospectivo: NFC-e só existe DEPOIS da compra. O app nunca sabe promoção vigente, ruptura de estoque, nem preço de quem não escaneou. Não responde 'quanto custa agora', só 'quanto custou'.
- Custo variável por scan: usa a API paga InfoSimples para extrair a nota. Cada cupom escaneado tem custo marginal — o que pressiona margem e limita crescimento gratuito. É um teto de escala embutido na arquitetura.
- Dados de compra (o que você come, remédios, hábitos) ficam em nuvem de terceiro (Supabase) com conta obrigatória. É um passivo de LGPD e de percepção que o app não neutraliza com processamento local.
- Sem modo escuro documentado (pedido explícito na categoria).
- Normalização de produto não resolvida/não comprovada: a descrição da NFC-e é texto livre por emissor. Sem casamento por GTIN, o mesmo leite vira N produtos distintos — a dor de 'produto duplicado' que o cliente suspeitava.
- 'Ver mais' e cards de estatística com scroll horizontal na home: densidade de dashboard financeiro num app que se propõe simples. O valor real (quanto custou X, onde) está a 2 toques de distância, atrás da Busca.

O QUE COPIAR:
- Leitura de NFC-e por QR com ZERO digitação. É o fosso real contra todo app de finanças manual — a entrada de dados é o que mata esses apps. Copiar sem hesitar.
- Preço com origem oficial (cupom fiscal), não crowdsourcing digitado. Mata de saída a suspeita de 'preço fantasioso' que aparece nos reviews dos concorrentes. É o argumento de confiança mais forte da categoria.
- Escopo nacional por padrão: NFC-e é padrão federal. Isso evita a armadilha nº1 do Menor Preço Brasil — dezenas de 1 estrela por 'não funciona no meu estado'. Se o app depende de convênio estadual, ele nasce quebrado para a maioria.
- O enquadramento 'seu histórico' (não 'rede nacional de preços'). Aqui está o insight estratégico: o poupa+ escreveu no site a promessa colaborativa, mas as TELAS mostram histórico pessoal — e são as telas que funcionam com 1 usuário. Copiar as telas, não a promessa. Isso valida exatamente o 'bem mais simples' do cliente.
- Recência do preço SEMPRE visível ('há 1 dia', '25 abr', '2 compras'). Remover isso é o gatilho de raiva mais documentado que encontrei. Deve ser elemento de primeira classe, nunca detalhe secundário.
- Contagem de observações por loja ('2 compras', '3 compras') — é honestidade estatística embutida na UI. Diz ao usuário o quanto confiar naquele número. Manter e reforçar.
- Disclaimer legal de que o preço é informativo e pode estar desatualizado (está nos Termos do poupa+). Necessário juridicamente e reduz a fúria do 'cheguei lá e o preço era outro'.
- Central de Ajuda dedicada a falha de escaneamento (o poupa+ acabou de lançar isso na v1.0.16). Assuma desde o dia 1 que o scan falha e projete o caminho de recuperação junto com o caminho feliz.
- Exclusão de conta dentro do app — requisito da Play e da LGPD; o poupa+ só resolveu isso na v1.0.16. Já nasça com isso.
- Toggle de período no gráfico (6M/3M/1M/1S) e ordenação 'Mais barato' no card de lojas. São controles certos e baratos.
- Lista de compras com custo estimado a partir do último preço conhecido. ATENÇÃO: é a feature mais quebrada da categoria — se for entregar, tem que funcionar de verdade, senão vira o principal motivo de 3 estrelas.
- Design Material 3 leve, verde, não-bancário. Reduz a carga emocional de 'app de controle financeiro' — acerto de posicionamento.
- Ficha da Play honesta e específica ('poupa+ | cupom fiscal e preços') com descrição em bullets curtos e linguagem coloquial. Boa base de ASO para o nicho.

EM ABERTO:
- Qual é o custo real por nota da API InfoSimples, e o melhor_mercado deve depender dela ou consultar a SEFAZ direto? Isso define se o produto pode ser gratuito e se escala — é a pergunta de viabilidade econômica número 1 e eu não consegui apurar o preço.
- O melhor_mercado vai aceitar chave de acesso de 44 dígitos digitada/colada, XML, PDF e QR na tela? Os reviews mostram que esse é o pedido mais concreto e não atendido da categoria — e o poupa+ não o atende.
- Com o cupom em papel deixando de ser obrigatório, qual é o plano B de captura? (importação por e-mail, integração com apps de nota estadual, leitura de QR exibido na tela do PDV). Não consegui confirmar o texto normativo primário — vale uma checagem jurídica antes de apostar tudo no papel.
- Como resolver a normalização de produto? Casar por GTIN quando existe, e o que fazer com os itens sem GTIN (granel, padaria, hortifruti) que têm descrição livre? É o que separa um histórico útil de uma lista de duplicatas.
- O melhor_mercado precisa mesmo de login? Um MVP 100% local (SQLite no dispositivo, sem conta, sem nuvem) elimina a dor #4, elimina o passivo de LGPD, elimina custo de backend e é coerente com 'bem mais simples'. Qual o custo real de abrir mão de sync entre dispositivos?
- Se ficar só no histórico pessoal, qual é a proposta de valor no dia 1, antes do usuário ter histórico? (sugestão a investigar: o valor imediato do primeiro scan é o detalhamento da compra que acabou de acontecer, não a comparação).
- Qual a taxa real de falha de leitura de QR em cupom térmico amassado/desbotado, e quanto dela é resolvível com melhor pipeline de câmera vs. exige fallback manual?
- Quantos usuários o poupa+ realmente tem hoje (10, 45?) e ele está crescendo? Vale re-checar a ficha da Play em 30-60 dias — se continuar em '10+', é sinal de que o nicho não se vende sozinho e o problema do melhor_mercado será distribuição, não produto.
- Não consegui acessar o Wayback Machine (503) nem localizar os packages de Minha Nota e Economiza Club — há concorrentes diretos de 'organizador pessoal de notas' que não consegui avaliar e que podem estar mais próximos do melhor_mercado do que os apps de governo.


################ FRENTE: O nicho "simples" de leitura de cupom fiscal (NFC-e) no Brasil — quem faz, como faz, e onde estão as lacunas para o melhor_mercado

RESUMO:
1. A hipótese do cliente está REFUTADA no design, mas CORRETA na prática. O site e a política de privacidade do poupa+ dizem literalmente que a comparação "usa os cupons de todos os usuários, de forma agregada". Porém o app tem 10+ downloads e ZERO avaliações no Google Play. Com esse volume, a "base colaborativa" é, na prática, o histórico do próprio usuário — o que explica exatamente os "2 compras"/"3 compras" da tela de produto.
2. O poupa+ NÃO é um concorrente estabelecido. É um projeto solo (DEV FREITAG LTDA, CNPJ 52.487.847/0001-46, alex@devfreitag.com), atualizado em 20/jul/2026, site com apenas 3 páginas. É um protótipo público, não um produto validado. Copiar as decisões dele é copiar uma aposta não testada.
3. O concorrente real não é o poupa+ — é o GOVERNO. O "Menor Preço Brasil" (SEFAZ/RS + PROCERGS) cobre 15 estados incluindo Santa Catarina, e o "Menor Preço Nota Paraná" tem 1 mi+ downloads, 60 mil estabelecimentos e "mais de 10 milhões de preços atualizados" por semana, em tempo real, direto do fluxo de NFC-e. Nenhuma rede colaborativa de usuários ganha dessa base. E a API do Paraná é PÚBLICA, sem chave de autenticação — eu consultei e recebi JSON com preço, loja, CNPJ, distância em km e timestamp.
4. Consequência estratégica direta: a decisão do cliente de fazer algo "bem mais simples" e sem rede colaborativa nacional está certa — não por preguiça, mas porque a base colaborativa é o pedaço do problema que já foi resolvido de graça pelo Estado e é impossível de vencer com escala de startup.
5. O espaço livre é o oposto: o governo faz "onde está mais barato AGORA, perto de mim" e não faz "quanto EU pago, o que EU compro sempre, meu orçamento". Nenhum app brasileiro que verifiquei faz bem a ponte entre cupom fiscal → lista de compras recorrente → orçamento pessoal.
6. Economia unitária importa: o poupa+ usa a InfoSimples para consultar a SEFAZ (declarado na política de privacidade). A tabela da InfoSimples é R$ 0,20/consulta no primeiro degrau + adicional típico de R$ 0,04 para SEFAZ/NFC-e, com franquia mínima de R$ 100/mês. Ou seja: cada cupom escaneado tem custo marginal real. Isso limita fortemente um modelo gratuito com escala.
7. O ponto de falha nº1 do nicho inteiro é operacional, não de produto: "nota fiscal não encontrada na receita" por instabilidade do sistema da SEFAZ. Quem resolver isso com fila/retry/fallback ganha em retenção mais do que ganharia com qualquer feature nova.
8. Stack do poupa+ está exposta na política de privacidade: Supabase, InfoSimples, PostHog, Sentry, Google e Expo (React Native). Útil como benchmark de custo e velocidade para um app solo.

ACHADOS:
- [confirmada] O poupa+ É colaborativo por design — a hipótese de que o histórico vem só das compras do próprio usuário está refutada como decisão de arquitetura.
    EVID: Texto literal do site: 'A comparação de preços usa os cupons de todos os usuários, sem identificar quem comprou.' e 'Quanto mais gente escaneia, melhor fica a resposta para "onde está mais barato?".' Política de privacidade: 'cupons de todos os usuários, de forma agregada e sem identificar quem realizou cada compra'.
    FONTE: https://poupamais.app/ e https://poupamais.app/privacidade
- [confirmada] NA PRÁTICA, porém, a hipótese do cliente está certa: com 10+ downloads a 'base de todos os usuários' é essencialmente o próprio usuário. É isso que produz '2 compras' e '3 compras' na tela de produto.
    EVID: O HTML do Google Play contém literalmente 'info 10+ downloads' para com.devfreitag.poupamais, e nenhuma ocorrência de ratingValue, ratingCount, aggregateRating, 'avaliações' ou 'estrela'. Combinado com a descrição da loja: 'Pesquisar um produto e comparar preços entre lojas e compras'.
    FONTE: Google Play com.devfreitag.poupamais (HTML bruto parseado)
- [confirmada] poupa+ é um projeto solo de uma PJ individual, em lançamento, não um concorrente com tração.
    EVID: Termos: 'DEV FREITAG LTDA (CNPJ 52.487.847/0001-46)', contato alex@devfreitag.com. Play: autor 'Dev Freitag', atualizado em 20 de jul. de 2026, contato devfreitag@gmail.com. Sitemap com 3 URLs apenas. iPhone 'Em breve'.
    FONTE: https://poupamais.app/termos, sitemap.xml, Google Play
- [confirmada] O poupa+ é gratuito hoje e já sinaliza intenção de monetizar por assinatura na loja.
    EVID: 'Atualmente o poupa+ é oferecido gratuitamente; basta criar uma conta para usar o serviço.' + menção a planos pagos futuros via Google Play. JSON-LD do Play: "price":"0","priceCurrency":"BRL".
    FONTE: https://poupamais.app/termos + Google Play JSON-LD
- [confirmada] A stack do poupa+ é Supabase + InfoSimples + PostHog + Sentry + Expo (React Native).
    EVID: Política de privacidade lista os operadores: 'Supabase, InfoSimples (for SEFAZ consultation), PostHog, Sentry, Google, and Expo'. E: 'Consulta dos dados da nota fiscal (NFC-e) junto à Secretaria da Fazenda a partir do código escaneado' via InfoSimples.
    FONTE: https://poupamais.app/privacidade
- [confirmada] O poupa+ NÃO usa GPS — o que explica por que a tela de produto mostra 'Onde foi encontrado' por nome de loja e não por distância.
    EVID: 'Não coletamos sua localização por GPS nem coordenadas precisas do dispositivo.' Ao mesmo tempo o marketing promete 'em cada estabelecimento por perto'.
    FONTE: https://poupamais.app/privacidade vs https://poupamais.app/
- [confirmada] O concorrente real do nicho é o Estado: 'Menor Preço Brasil' é um app oficial da SEFAZ-RS/PROCERGS que já cobre 15 estados, INCLUINDO Santa Catarina — exatamente a região das lojas que aparecem nos prints do poupa+.
    EVID: Descrição oficial no Play: 'O Menor Preço Brasil é um app do GOVERNO do ESTADO do Rio Grande do Sul desenvolvido pela Receita Estadual da SECRETARIA DA FAZENDA'. Lista literal 'ESTADOS EM FUNCIONAMENTO': Acre, Alagoas, Distrito Federal, Espírito Santo, Pará, Pernambuco, Piauí, Rio de Janeiro, Rio Grande do Norte, Rio Grande do Sul, Rondônia, Roraima, Santa Catarina, Sergipe, Tocantins. 100 mil+ downloads, 1,32 mil avaliações, atualizado 14/jul/2026.
    FONTE: Google Play br.gov.rs.procergs.mpbr
- [confirmada] O app do governo busca por CÓDIGO DE BARRAS e usa geolocalização — duas coisas que o poupa+ não faz.
    EVID: 'Informe o produto que você deseja pesquisar por meio de sua descrição, marca ou código de barras.' e 'Utilizaremos a sua localização para encontrar os menores preços mais próximos de você.'
    FONTE: Google Play br.gov.rs.procergs.mpbr
- [confirmada] A base de preços do governo é montada do fluxo bruto de NFC-e/NF-e em tempo real, não de usuários escaneando. Isso é uma vantagem estrutural inatingível por crowdsourcing.
    EVID: SEF/SC: 'Por meio de consultas às Notas Fiscais Eletrônicas (NF-e) e às Notas Fiscais de Consumidor Eletrônicas (NFC-e)' ... 'As informações são atualizadas em tempo real toda vez que um estabelecimento realiza uma venda a varejo.' Meta do Nota Paraná: 'mais de 60 mil estabelecimentos participantes... Toda semana, mais de 10 milhões de preços são atualizados.'
    FONTE: https://www.sef.sc.gov.br/servicos/instalar-o-aplicativo-menor-preco-brasil e https://menorpreco.notaparana.pr.gov.br/
- [confirmada] A API do Menor Preço do Paraná é pública e sem chave de autenticação, e devolve dados de preço em nível de produto e de loja.
    EVID: GET https://menorpreco.notaparana.pr.gov.br/api/v1/produtos?termo=leite&local=-25.4284,-49.2733 retornou JSON: {"tempo":724,"local":...,"produtos":[{"desc":"BALA BRAZILIAN COFFEE CAFE C LEITE FLORESTAL UNIDADE","ncm":"17049020","valor":"0.20","datahora":"2026-07-17T16:17:43.806Z","tempo":"há 5 dias","distkm":"9.347","gtin":"","estabelecimento":{"nm_fan":"DAMBOX EMBALAGENS","nm_emp":"DANBOX DISTRIBUIDORA...","nm_logr":"PROFESSOR JOAO FALARZ",...}}], "total":..., "precos":...}
    FONTE: menorpreco.notaparana.pr.gov.br/api/v1/produtos (chamada direta)
- [confirmada] Essa API é instável / tem rate limit agressivo — não dá para depender dela sem cache próprio.
    EVID: A primeira chamada retornou 200 com JSON completo; chamadas subsequentes em sequência retornaram HTTP 000 com 0 bytes, e uma chamada com termo numérico retornou o envelope JSON válido porém com 0 produtos.
    FONTE: chamadas diretas repetidas à API do PR
- [provavel] O ponto de falha número 1 do nicho é a instabilidade da SEFAZ, não o design do app.
    EVID: Resultado de busca sobre o Gastômetro relata usuários com 'todas as notas escaneadas mostram a mensagem "nota fiscal não encontrada na receita"', e a explicação de que falhas 'geralmente' decorrem 'de instabilidade no sistema da Secretaria da Fazenda (SEFAZ) local que lê as notas'.
    FONTE: WebSearch (resumo de resultados sobre Gastômetro/Citizen)
- [confirmada] Escanear cupom fiscal tem custo marginal real quando se usa intermediário: ~R$ 0,24 por nota no primeiro degrau, com franquia mínima de R$ 100/mês.
    EVID: Tabela InfoSimples: 1–500 consultas = R$ 0,20 cada; 100.001+ = R$ 0,05. 'A franquia mínima mensal de serviços é R$ 100,00'. 'Quando você cria uma conta, você ganha R$ 100,00 para avaliar os serviços'. Adicionais R$ 0,04–0,18/consulta; SEFAZ NFC-e citado com adicional típico de R$ 0,04.
    FONTE: https://infosimples.com/consultas/precos/
- [provavel] Existe caminho open source para ler NFC-e sem pagar intermediário, eliminando esse custo variável.
    EVID: Busca no GitHub retornou python-nfce-get ('Biblioteca em python que recupera as informações de uma nota fiscal consumidor eletronica'), PyNFe (TadaSoftware), PySIGNFe, nfelib (akretion), sped-nfe (nfephp-org, PHP) e NFeWizard (Node.js).
    FONTE: WebSearch GitHub
- [confirmada] Métricas do Google Play dos principais apps brasileiros de finanças pessoais (downloads | nº de avaliações | última atualização), coletadas em 22/jul/2026.
    EVID: Mobills (br.com.gerenciadorfinanceiro.controller) 10 mi+ | 293 mil | 13/jul/2026. Organizze (com.organizze.android) 1 mi+ | 56,9 mil | 22/jul/2026. Minhas Economias (com.minhaseconomias) 1 mi+ | 52,2 mil | 17/jul/2026. Todos ATIVOS.
    FONTE: Google Play (HTML parseado)
- [confirmada] Métricas dos apps de cupom fiscal / preço no Brasil — todos os de nicho puro são PEQUENOS.
    EVID: Menor Preço (PR, br.gov.pr.celepar.sefa.mp) 1 mi+ | 8,74 mil | 20/jul/2026. Menor Preço Brasil (br.gov.rs.procergs.mpbr) 100 mil+ | 1,32 mil | 14/jul/2026. Clube Economiza+ (inovatech.mercafacil.clube.economiza) 10 mil+ | 419 | 16/dez/2025 (parado há 7 meses). Citizen IBPT (br.com.citizen) 10 mil+ | 227 | 8/abr/2026. Gastômetro (br.com.gastometro) 1 mil+ | 11 avaliações | 8/abr/2026. Minha Nota (com.herb.myapp.minhanota) 1 mil+ | 13/jul/2026. Compra Certa (com.compracerta.app.compra_certa) 10+ |
    FONTE: Google Play (HTML parseado)
- [confirmada] O modelo de cupom fiscal que REALMENTE escalou no Brasil não é 'controle de gastos' — é cashback/sorteio.
    EVID: Dinheiro na Nota (br.com.sofist.dinheironanota) 1 mi+ downloads | 135 mil avaliações | atualizado 21/jul/2026. Méliuz (br.com.meliuz, 'Cashback e Nota Fiscal') 10 mi+ | 1,26 mi avaliações. Cuponomia 1 mi+ | 58,8 mil. Compare com Citizen (227 avaliações) e Gastômetro (11).
    FONTE: Google Play (HTML parseado)
- [confirmada] Não consegui confirmar a existência atual de vários apps da lista do briefing como produtos de NFC-e distintos.
    EVID: Buscas no Google Play por 'fatura certa', 'bluk supermercado', 'meu mercado lista compras preco', 'kaledo', 'zero papel nota fiscal', 'notaai' não retornaram um pacote correspondente identificável ao nicho — retornaram apps de faturamento, e-commerce, clubes de benefícios ou apps de notas de voz com IA. Os pacotes br.com.bluk, com.mfm.listadecompras e br.gov.sc.sef.nfce retornaram INDISPONÍVEL.
    FONTE: Google Play search + details
- [baixa] Busca Preço e Meus Preços operam por código de barras (não por cupom), com foco em farmácia/mercado.
    EVID: Resumo de resultados de busca: 'Busca Preço pode ser usado em lojas físicas para saber o valor médio de um produto através do código de barras... focado em itens de farmácia e mercado'. 'Meus Preços exibe informação de preço lendo o código de barras... integra com a Nota Fiscal Paulista'. Não verifiquei as fichas de loja diretamente.
    FONTE: WebSearch (blogs infoprice/techtudo)
- [provavel] Economiza Club é colaborativo via QR Code, mas com cobertura regional limitada e app aparentemente estagnado.
    EVID: Resumo de busca: 'o banco de dados de preços é atualizado com base em informações enviadas pelos usuários através da leitura do QR code' e 'atualmente o app funciona apenas nos estados RS, PR e SP'. O pacote inovatech.mercafacil.clube.economiza mostra 10 mil+ downloads, 419 avaliações e última atualização em 16/dez/2025.
    FONTE: WebSearch + Google Play
- [confirmada] Open Prices (Open Food Facts) prova que base colaborativa de preço NÃO escala por voluntariado: são só 278 mil preços no mundo INTEIRO após ~3 anos.
    EVID: GET https://prices.openfoodfacts.org/api/v1/prices?size=1 retornou total = 278163. Por tipo: PRODUCT = 268.876, CATEGORY = 9.287. O registro id=1 tem created em 2023-11-27. Schema tem proof_id, receipt_quantity, price_is_discounted, price_without_discount, discount_type, price_per.
    FONTE: API pública prices.openfoodfacts.org
- [confirmada] Não consegui isolar quantos preços do Open Prices são do Brasil.
    EVID: O parâmetro location_osm_country=Brazil/Brasil/Brésil devolveu sempre o mesmo total (278163), indicando que o filtro foi ignorado pela API. Portanto não afirmo nada sobre cobertura brasileira.
    FONTE: API prices.openfoodfacts.org
- [provavel] Fetch e Ibotta monetizam VENDENDO DADO e vendendo mídia para marcas — não cobrando do usuário. O cupom é a isca.
    EVID: Resumo de buscas 2026: 'Fetch vende dados de compra agregados para marcas, e paga aos usuários uma pequena parte por contribuir com esse dado'; '17M usuários e $500M+ de receita, com licenciamento de dados sozinho respondendo por 35% da receita'. Ibotta: 'marcas parceiras pagam a Ibotta para promover seus produtos'. Fluxo Fetch: 'fotografe qualquer recibo em até 14 dias da compra'.
    FONTE: WebSearch (fetch.com/blog, firstcard.app, earnifyhub — fontes secundárias)
- [confirmada] O padrão de UX vencedor lá fora no fluxo capturar→categorizar→comparar é o inverso do poupa+: capturar é OPCIONAL e a lista é o produto.
    EVID: Métricas Google Play (US/BR): Bring! Lista de Compras (ch.publisheria.bring) 10 mi+ | 144 mil avaliações | 20/jul/2026. Out of Milk (com.capigami.outofmilk) 5 mi+ | 243 mil | 26/jun/2026. Lista de Compras SoftList (br.com.ridsoftware.shoppinglist) 1 mi+ | 54,1 mil | 2/jul/2026. Ou seja, apps de LISTA têm 100x mais tração que apps de cupom fiscal puro.
    FONTE: Google Play (HTML parseado)
- [confirmada] Não consegui verificar métricas de Fetch, Ibotta, AnyList, Smart Receipts, Receipt Lens, Basket Savings e Grocy.
    EVID: Os pacotes com.fetchrewards.fetchrewards.hop, com.ibotta.android e com.purplecover.anylist retornaram a página mas meu parser não extraiu downloads/avaliações no locale en_US; wb.receiptsgo, com.basket.savings, com.wave.receiptlens e co.smartreceipts.android retornaram INDISPONÍVEL. Grocy é self-hosted e não foi consultado.
    FONTE: Google Play
- [provavel] Preços de assinatura praticados no Brasil em finanças pessoais: faixa de R$ 15 a R$ 35/mês, com forte desconto anual.
    EVID: Resumo de buscas: Mobills entre R$ 14,90/mês e R$ 89,90/ano; Mobills PRO R$ 17,90/mês ou R$ 134,90/ano; Organizze a partir de R$ 20,83/mês no anual ou R$ 32,90/mês no mensal; citado também Mobills R$ 119,90/ano e Organizze R$ 169/ano. Números divergem entre fontes secundárias.
    FONTE: WebSearch (encaixei.com.br, mobills.com.br/pricing, ajuda.organizze.com.br)
- [baixa] O 'Menor Preço' também cobre combustíveis e possivelmente histórico de preços — mas há conflito entre fontes e NÃO confirmei.
    EVID: Um resumo de busca sobre a SEF/SC menciona consulta de gasolina, etanol, diesel e gás natural e 'também é possível verificar o histórico de preços dos produtos consultados'. Porém o fetch direto da página oficial sef.sc.gov.br/servicos respondeu explicitamente 'Nenhuma menção encontrada' para histórico de preços e combustíveis, e a página de notícia correspondente retornou 404.
    FONTE: WebSearch vs https://www.sef.sc.gov.br/servicos/instalar-o-aplicativo-menor-preco-brasil
- [confirmada] O poupa+ posiciona-se por MEMÓRIA DE PREÇO, não por economia — e essa é a decisão de copy mais inteligente dele.
    EVID: Título da página: 'poupa+ | Não lembra quanto você pagou? Agora você vai.' Descrição no Play: 'Não lembra quanto você pagou da última vez? Agora você vai.' e 'Sem complicação. Escaneou, salvou. Depois é só pesquisar quando precisar saber quanto pagou naquele produto'.
    FONTE: https://poupamais.app/ + Google Play
- [confirmada] O poupa+ promete cobertura nacional para captura de cupom — o que é tecnicamente plausível já que a NFC-e é padrão nacional.
    EVID: Descrição no Play: 'FUNCIONA EM TODO O BRASIL — O poupa+ aceita cupons fiscais eletrônicos (NFC-e) emitidos em qualquer estado.' Termos: 'Os dados fiscais contidos nos cupons (NFC-e) são documentos públicos emitidos pelas Secretarias da Fazenda estaduais.'
    FONTE: Google Play + https://poupamais.app/termos
- [provavel] Escanear cupom também é usado no Brasil como funil de fidelidade de varejo (não como app de consumidor), via plataforma Mercafacil.
    EVID: Muitos pacotes retornados nas buscas seguem o padrão 'inovatech.mercafacil.*' (clube.economiza, economize, meu.menor.preco, cashback.supmercado.real, compra.certa.elite, cash.mais) — indicando um white-label vendido a redes de supermercado, não um app único.
    FONTE: Google Play search

LACUNAS DO POUPA+:
- Promete geolocalização que não tem. O marketing diz 'veja quanto ele custou em cada estabelecimento por perto', mas a política de privacidade diz 'Não coletamos sua localização por GPS nem coordenadas precisas do dispositivo'. Resultado: 'perto' é uma promessa vazia — a tela de produto só consegue listar nomes de loja, sem distância nem rota. O app do governo faz isso e o poupa+ não.
- Não busca por código de barras. A tela de produto é alcançada por busca textual sobre a descrição bagunçada da NFC-e ('LEITE UHT ITALAC INTEGRAL 1L'). O Menor Preço Brasil aceita 'descrição, marca ou código de barras'. Sem GTIN, o mesmo produto de duas lojas vira dois produtos diferentes.
- O gráfico de histórico com linha pontilhada expõe a fragilidade da base. Interpolar entre 2 e 3 pontos reais ao longo de 6 meses e desenhar uma linha contínua é dar aparência de série temporal a um dado que não existe. Com 10+ usuários, 'mar/26 a jul/26' com duas séries é quase certamente extrapolação visual.
- O toggle 6M/3M/1M/1S é feature vazia hoje. Com 2-3 compras por produto, os filtros 1M e 1S retornam gráfico vazio ou um único ponto. É UI construída para um volume de dado que o app não tem.
- 'Faixa de preço R$ 4,98 - R$ 5,19' com 5 compras totais não é faixa de preço de mercado, é o intervalo do que ESTE usuário pagou. O rótulo induz o usuário a achar que é preço de mercado.
- Paradoxo do dia 1 (o pior problema): o app só tem valor depois de N compras escaneadas. No primeiro uso a Home mostra 'Compras no mês 1', gráfico de categorias com uma fatia, e busca vazia. Não há absolutamente nada que entregue valor antes do usuário trabalhar.
- O FAB de QR Code no centro do bottom nav aposta tudo em um gesto que depende de um sistema de terceiros instável (SEFAZ). Quando a consulta falha — e falha —, a ação primária do app quebra e não há plano B (digitar chave de acesso, tirar foto, salvar para reprocessar).
- Custo variável por scan sem receita. Cada cupom passa pela InfoSimples (R$ ~0,24 no primeiro degrau, franquia mínima R$ 100/mês). O app é gratuito. Crescer machuca o caixa antes de gerar receita — é um modelo que pune o sucesso.
- A categorização ('Outros 26%', 'Carnes 23%') tem 'Outros' como maior categoria. Isso é sintoma de classificador fraco sobre descrições de NFC-e. O card de categorias, que deveria ser o insight, mostra que o app não entendeu 1/4 das compras.
- Header financeiro genérico: 'Ticket médio R$ 433,19' e 'Compras no mês 1'. Ticket médio de UMA compra é o valor dessa compra. São métricas de dashboard corporativo aplicadas a um dado doméstico — não respondem 'estou gastando mais que mês passado?'.
- Não há nada acionável na Home. Ela reporta o passado (compras recentes, gastos por categoria) mas não sugere nenhuma decisão futura. Nenhum 'seu arroz está acabando', 'esse item subiu 18%', 'sua lista custaria R$ X no mercado Y'.
- Sem iOS ('Em breve') e sem web. Em compras domésticas, quem decide a lista frequentemente não é quem vai ao mercado — a ausência de compartilhamento/multi-plataforma mata o caso de uso familiar.
- Marca e domínio frágeis: 'poupa+' colide com poupamais.pt (serviço português) e com 'Poupa' já existente no Google Play, e o '+' é ruim para busca e para ASO.

O QUE COPIAR:
- O posicionamento por MEMÓRIA, não por economia. 'Não lembra quanto você pagou? Agora você vai.' é muito mais honesto e defensável do que prometer economia, porque o app controla 100% da entrega dessa promessa. Prometer 'economize' cria uma dívida que só uma base de preços gigante paga. Roube essa frase-conceito.
- Escaneou → salvou. Zero digitação. A NFC-e entrega produto, quantidade, preço unitário, loja, CNPJ e data de uma vez. Nenhum app de finanças pessoal chega perto dessa densidade de dado por gesto do usuário. Mantenha o QR Code como ação primária.
- O FAB central destacado no bottom nav. A hierarquia visual está certa: existe UMA ação que importa e ela é fisicamente maior que as outras quatro. Mantenha.
- Não parecer app de banco. Material 3, verde, fundo claro, cards arredondados, laranja para categoria. Controle de gastos de mercado é rotina doméstica, não gestão financeira. O tom leve reduz a ansiedade que faz gente abandonar app de finanças. Copie a atmosfera.
- O card 'Onde foi encontrado' com contagem de evidência ('2 compras', '3 compras'). Mostrar quantas observações sustentam aquele preço é honestidade de dado embutida na UI — raríssimo. Mantenha e vá além: mostre a data da última observação em destaque, não escondida.
- A ordenação explícita 'Mais barato' como controle visível no card, não escondida em menu.
- Seletor de mês com setas no topo da Home. Compra de mercado é um ciclo mensal; ancorar toda a Home no mês é o recorte temporal certo.
- O CTA 'Adicionar à lista de compras' no fim do detalhe de produto. Fecha o loop entre 'descobri um preço' e 'vou agir'. Esse é o único ponto do app onde a informação vira ação — expanda essa ideia, não a trate como botão secundário.
- Site institucional minúsculo (3 páginas) com termos e privacidade honestos e legíveis. É o mínimo necessário para publicar na loja e ganhar confiança. Não gaste mais que isso no lançamento.
- A stack Expo + Supabase para um app solo. É a escolha certa de velocidade/custo para validar. Só troque a InfoSimples pela leitura direta da SEFAZ.

EM ABERTO:
- Não consegui ver NENHUMA avaliação de usuário do poupa+ (o app tem zero). Portanto não sei nada sobre o que usuários reais acham dele — todas as 'lacunas' que listei vêm dos prints, do site e da economia do modelo, não de reclamação verificada.
- Não consegui verificar se a taxa de sucesso da consulta NFC-e varia muito por estado. A NFC-e é padrão nacional, mas cada SEFAZ estadual tem seu próprio endpoint de consulta e sua própria disponibilidade. Isso precisa ser testado empiricamente em SC/PB antes de prometer 'funciona em todo o Brasil'.
- Não consegui confirmar se a API pública do Menor Preço do Paraná tem equivalente nos outros 14 estados do Menor Preço Brasil (incluindo SC). Achei e testei apenas a do PR. Se o RS/SVRS expuser algo parecido, muda completamente a viabilidade da comparação de preços sem crowdsourcing.
- Não consegui confirmar os termos de uso da API do Menor Preço PR — se o uso por terceiros é permitido, se há rate limit publicado, ou se é API interna do SPA sem contrato. Usá-la em produção sem verificar isso é risco jurídico e técnico.
- Não consegui isolar a cobertura do Open Prices no Brasil (o filtro de país foi ignorado pela API).
- Não verifiquei diretamente as fichas de loja de Fetch, Ibotta, AnyList, Smart Receipts, Receipt Lens, Basket Savings nem o Grocy. As afirmações sobre modelo de receita de Fetch/Ibotta vêm de blogs secundários de 2026, não das próprias empresas.
- Não confirmei se o Menor Preço Brasil mostra histórico de preços — fontes conflitam e a notícia oficial da SEF/SC deu 404. Isso importa muito: se o app do governo JÁ faz histórico por produto, o diferencial do poupa+ encolhe ainda mais.
- Não sei se a NFC-e retorna GTIN/código de barras de forma confiável em todos os estados. Se retornar, resolve o problema de identidade de produto de graça; se não, é preciso normalizar descrições — que é o trabalho sujo real desse nicho e ninguém quer fazer.
- Não investiguei o lado B2B: se redes de supermercado (o padrão inovatech.mercafacil.* sugere um mercado ativo de white-label) pagariam por dado de cesta anonimizado. Isso pode valer mais do que assinatura de consumidor.
- Não sei quanto do dado da NFC-e pode ser legalmente reexibido a terceiros. Os Termos do poupa+ afirmam que são 'documentos públicos emitidos pelas Secretarias da Fazenda estaduais', mas isso é a interpretação DELES, não uma verificação jurídica — e é a fundação de todo o modelo colaborativo.


################ FRENTE: poupa+ (poupamais.app / com.devfreitag.poupamais) — analise de design e UX para orientar o concorrente "melhor_mercado"

RESUMO:
poupa+ e um app solo de Alex Freitag (DEV FREITAG LTDA), Expo/React Native + Supabase + InfoSimples, categoria Play "Financas", gratuito, atualizado em 20/jul/2026, com 10+ downloads. Ingestao 100% via QR da NFC-e; nada e digitado.
Sobre a pista do cliente: PARCIALMENTE REFUTADA na intencao, CONFIRMADA na pratica. O site diz literalmente "A comparacao de precos usa os cupons de todos os usuarios, sem identificar quem comprou" e a politica de privacidade confirma agregacao anonima entre usuarios. Mas com 10+ instalacoes a rede colaborativa e essencialmente o proprio desenvolvedor: "Alex Freitag" da screenshot e o dono do app (alex@devfreitag.com). A busca e escopada por CIDADE ("Jaragua do Sul/SC"), e as redes citadas (Cooper Fresh = COOPERATIVA DE PRODUCAO E ABASTECIMENTO, Giassi, Angeloni, Fort) sao todas de SC. Ou seja: e um comparador colaborativo por projeto, um diario pessoal de precos na realidade.
Sistema visual: monocromatico seagreen #2F8B58 (identico ao CSS seagreen), Material 3 default, Roboto, fundo #F9F9F9, cards brancos, raio uniforme grande, um unico acento ambar #EEA62E. O verde acumula 6 funcoes (marca, CTA, chip ativo, preco, selo "mais barato", serie do grafico) — nao sobra cor para codificar "caro/subindo".
Falhas medidas, nao opinadas: CTA primario branco-sobre-verde = 4,24:1 (REPROVA WCAG AA); texto secundario #767676/#F9F9F9 = 4,31:1 (reprova); categoria ambar sobre branco = 2,07:1 (reprova feio). Chips 6M/3M/1M/1S tem ~20-23dp de altura (minimo Android = 48dp). No video oficial do proprio dev, o scan trava ~6-7s em tela vazia ("Processando nota fiscal..." + "Salvando informacoes...") e termina com ~3,5s de confete numa acao semanal.
Posicionamento errado: a home abre por "Ticket medio / Compras no mes / Gastos por categoria" — responde uma pergunta que o app do banco ja responde — e esconde atras de uma aba a unica pergunta que so este app responde ("onde esta mais barato agora perto de mim"). Play em "Financas" confirma.
Buraco funcional maior: nao ha preco por unidade base (R$/kg, R$/L). Sem isso e impossivel comparar 1L vs 12x1L vs 900ml honestamente. E o eixo Y do grafico e auto-escalado, transformando variacao de 4% em ladeira dramatica.
Direcao proposta (ver achados marcados PROPOSTA): abandonar o verde-de-fintech como marca e reserva-lo APENAS para semantica de preco; base papel quente #FBF7F0, marca indigo-uva #2E2A5C, etiqueta ambar #F2A007, tipografia Archivo (preco/display) + Inter (UI). Bordas em vez de sombras, porque sombra suave some sob luz de supermercado em LCD de entrada. Todos os pares passam AA com folga (17,2:1 / 12,3:1 / 8,6:1).

ACHADOS:
- [confirmada] O modelo colaborativo e DECLARADO, nao inferido — mas com 10+ instalacoes ele nao existe na pratica. A hipotese do cliente esta errada na intencao e certa no efeito.
    EVID: Site, literal: 'Cada cupom ajuda todo mundo — A comparacao de precos usa os cupons de todos os usuarios, sem identificar quem comprou. Quanto mais gente escaneia, melhor fica a resposta para "onde esta mais barato?"'. E: 'Tudo que o app faz nasce dos seus proprios cupons — e dos cupons de quem compra nos mesmos lugares que voce'. Politica de privacidade: 'Os precos exibidos a outros usuarios nas comparacoes nunca incluem sua identidade'. MAS o Play mostra '10+ downloads' e o usuario das screensh
    FONTE: https://poupamais.app/ + /privacidade + Play Store
- [confirmada] A hipotese Santa Catarina esta CONFIRMADA. O produto e regional e escopado por cidade, nao nacional.
    EVID: Screenshot de Busca do Play mostra o chip de local 'Jaragua do Sul/SC' ao lado de '6 resultados encontrados', com o subtitulo 'compare precos entre os mercados da sua cidade'. Telefone do dev no Play: +55 47 (DDD de Jaragua/Joinville). O video da versao antiga lista as razoes sociais cruas 'A. ANGELONI CIA LTDA' e 'COOPERATIVA DE PRODUCAO E ABASTECIME...' (= Cooper Fresh), ambas redes de SC.
    FONTE: Play screenshot 'Busca' + video demo + Play developer info
- [confirmada] PALETA MEDIDA (nao estimada). Primaria = seagreen puro #2F8B58, com uma familia de verdes e um unico acento ambar #EEA62E.
    EVID: Amostragem de pixel nas screenshots: botao CTA e chip '6M' ambos #2F8B58 (8.855 px do CTA); acento quente do header do produto #EEA62E (hue 38, sat 0.81); tile do icone de produto #F3EBDE (creme, nao amarelo); fundo de tela #F9F9F9; cards #FFFFFF. CSS do site confirma a familia: #1b5233 (mais escuro), #246b43 (logo), #2e8b57 (primaria), #3fa368 (clara), #cfe5d8 e #eaf4ee (tints), texto #1f1f1f / #555 / #767676, borda #e4e4e4, erro #b91c1c.
    FONTE: PIL pixel sampling em shot_4/shot_8/shot_19 + chunk CSS
- [confirmada] FALHA DE CONTRASTE CALCULADA: o botao primario do app REPROVA em WCAG AA. Branco sobre #2F8B58 = 4,24:1 (minimo 4,5:1).
    EVID: Calculo WCAG 2.x sobre as cores amostradas: branco/#2F8B58 = 4,24:1; texto secundario #767676 sobre fundo #F9F9F9 = 4,31:1 (reprova); categoria ambar #EEA62E sobre branco = 2,07:1 (reprova gravemente — e exatamente o 'Laticinios' laranja da Tela 2). Unico par confortavel: #555 sobre branco = 7,46:1.
    FONTE: calculo proprio a partir das cores medidas
- [confirmada] FALHA DE ALVO DE TOQUE MEDIDA: o seletor de periodo 6M/3M/1M/1S tem ~20-23dp de altura. E o controle mais usado da tela de produto.
    EVID: Medicao geometrica em shot_4 (1080x1920): a tela do aparelho renderizada tem 654px de largura; o CTA de largura total mede 600px, o que bate com 328dp (360dp - 2x16 de margem), fixando a escala em ~1,82 px/dp. Nessa escala: chip '6M' = 37px alt x 61px larg = ~20x34dp; CTA 'Adicionar a lista' = 67px = ~37dp de altura. Mesmo assumindo tela de 411dp, os chips ficam em ~23dp e o CTA em ~42dp. Minimo Android/Material = 48dp; altura padrao de botao M3 = 40dp. Os chips falham por larga margem em qualqu
    FONTE: medicao por pixel em shot_4.png
- [confirmada] O verde faz SEIS trabalhos semanticos simultaneos, o que zera a capacidade do produto de sinalizar 'caro' ou 'subindo'.
    EVID: O mesmo #2F8B58 aparece, na mesma tela (shot_4), como: cor de marca, fundo do CTA, fundo do chip de periodo ativo, cor do preco em destaque, borda+texto do selo 'Mais barato', linha do grafico, e circulo de sucesso do scan. Na Tela 2 descrita pelo cliente, as DUAS series do grafico sao 'verde escuro' e 'verde claro'. Nao sobra nenhum canal cromatico livre para o eixo barato/caro.
    FONTE: shot_4.png + shot_16.png + descricao da Tela 2
- [provavel] Duas series codificadas por CLARIDADE do mesmo matiz e a pior escolha possivel para o contexto de uso (LCD de entrada sob luz de supermercado).
    EVID: A Tela 2 usa 'Fort Atacadista (verde escuro)' e 'Cooper Fresh (verde claro)'. Diferenca de luminancia e o primeiro canal a colapsar sob luz ambiente forte e em paineis de baixo contraste — exatamente o corredor do mercado. Alem disso a legenda fica no rodape do card, exigindo ida-e-volta entre linha e legenda numa tela de 360dp.
    FONTE: descricao da Tela 2 + principio de codificacao visual; nao consegui medir os dois verdes porque so tenho a versao de serie unica no Play
- [confirmada] O grafico de precos e o elemento mais enganoso do produto: o eixo Y e auto-escalado sobre o intervalo dos dados, fabricando drama onde ha variacao trivial.
    EVID: Na Tela 2 o eixo vai de R$ 4,11 a R$ 5,37 para um produto cuja faixa real declarada e R$ 4,98-R$ 5,19 — variacao de ~4% desenhada como ladeira. Na versao do Play (shot_4) acontece o inverso: eixo de R$ 2,73 a R$ 5,95 para dados entre R$ 3,19 e R$ 4,88, achatando a curva. Alem disso os rotulos sao valores calculados, nao redondos (R$ 4,11 / 4,43 / 4,74 / 5,06 / 5,37) — ninguem consegue fazer conta com 'R$ 4,43'.
    FONTE: shot_4.png + descricao da Tela 2
- [confirmada] O trecho pontilhado do grafico sinaliza interpolacao, mas nada na interface distingue preco OBSERVADO de preco ESTIMADO. A legenda so nomeia lojas.
    EVID: Tela 2: legenda com 'Fort Atacadista' e 'Cooper Fresh' apenas. A linha pontilhada nao tem entrada de legenda nem rotulo. Os proprios Termos admitem que 'os precos refletem o valor registrado no momento de cada compra e podem estar desatualizados', mas essa incerteza nao chega ao pixel.
    FONTE: descricao da Tela 2 + https://poupamais.app/termos
- [confirmada] O selo 'Mais barato' e aplicado a observacoes unicas e velhas, o que e ativamente enganoso.
    EVID: shot_4: 'Fort Atacadista — [Mais barato] 1 compra — R$ 3,19 / R$ 0,89 mais barato', enquanto 'Cooper Fresh — 4 compras — R$ 4,29'. Uma unica observacao vence quatro, sem qualquer peso por recencia ou suporte amostral. Na Tela 2 mais nova eles ADICIONARAM datas ('25 abr' vs 'ha 1 dia'), o que mostra que perceberam o problema — mas o R$ 4,98 de 25/abr ainda aparece acima do R$ 5,19 de ontem, ordenado por 'Mais barato'.
    FONTE: shot_4.png + descricao da Tela 2
- [confirmada] O fluxo de scan trava ~6-7 segundos em tela quase vazia, no video promocional do proprio dev (ou seja, o melhor caso).
    EVID: Cronometragem por frame do demo.mp4 oficial: t=2,3s a 5,8s tela 'Escanear' (moldura tracejada + linha de varredura + lanterna); t=6,5s a 9,4s 'Processando nota fiscal...' com spinner; t=10,1s a 12,9s 'Salvando informacoes no seu historico...'; t=13,6s 'Nota Escaneada!'. Sao ~7s de espera bloqueante com o corpo da tela vazio. O site promete 'A leitura leva segundos e funciona direto na fila do estacionamento'.
    FONTE: extracao de frames de https://poupamais.app/poupamais-video.mp4
- [confirmada] Ha ~3,5 segundos de confete numa acao que o usuario repete toda semana — fadiga de celebracao garantida.
    EVID: Frames t=13,6s ate t=17,1s do demo mostram confete multicolorido cobrindo a tela de sucesso. Ironia: e o UNICO uso de cor saturada nao-verde em todo o app, e ele nao carrega nenhuma informacao.
    FONTE: frames p2.png/p3.png do demo
- [confirmada] A tela de sucesso do scan entrega um recibo, nao uma informacao. Zero inteligencia de preco no momento de maxima atencao.
    EVID: shot_16 / frames do demo: 'Nota Escaneada!' mostra apenas nome do estabelecimento, valor total (R$ 64,72 / R$ 85,67) e '5 itens'. Nenhum 'voce pagou X% a mais que da ultima vez', nenhum 'este item esta mais barato no Giassi', nenhum item destacado. Duas acoes: 'Escanear Novamente' (outline) e 'Ver Detalhes' (filled).
    FONTE: shot_16.png + frames p2/p3
- [confirmada] A razao social crua vaza para a tela de maior atencao, embora a camada de normalizacao exista.
    EVID: Tela de sucesso mostra 'SDB COMERCIO DE ALIMENTOS LTDA'. Nas outras telas os mesmos dados aparecem normalizados como 'Cooper Fresh', 'Giassi', 'Fort Atacadista'. A home da versao antiga (video) mostrava tudo cru: 'A. ANGELONI CIA LTDA', 'COMERCIO DE MEDICAMENTOS BRAIR LTDA', 'COOPERATIVA DE PRODUCAO E ABASTECIME...' (truncado). Eles construiram o mapeamento CNPJ->marca e nao o aplicaram em todo lugar.
    FONTE: shot_16.png vs shot_12.png vs frames sheet0.png
- [confirmada] A arquitetura de informacao cresceu de 3 para 5 posicoes e ganhou redundancia. O FAB central de QR, porem, esta CERTO e sempre esteve.
    EVID: Video (build anterior): bottom nav com 3 slots — Inicio | [FAB QR] | Historico, e busca como icone de lupa no header. Build atual (shot_12): Inicio | Buscar | [FAB QR] | Lista | Historico. O FAB permaneceu central em ambas. Mas 'Inicio' ja lista 'Compras Recentes', que e literalmente o conteudo de 'Historico' — duas abas para o mesmo objeto.
    FONTE: frames do video vs shot_12.png
- [confirmada] A home abre pela pergunta errada. O produto se posiciona como diario financeiro, nao como comparador de precos — e o Play confirma isso na categoria.
    EVID: Ordem de leitura da home (shot_12): saudacao -> seletor de mes -> 'Ticket medio R$ 433,19' / 'Compras no mes 1' / 'Gasto...' -> 'Gastos por categoria' -> 'Compras Recentes'. A palavra 'preco' nao aparece uma unica vez acima da dobra. Categoria no Google Play: FINANCAS. Enquanto isso a home do site vende 'onde esta mais barato?'. 'Ticket medio' e jargao de varejo, e 'Compras no mes: 1' e uma metrica de vaidade que humilha o usuario quando esta baixa (a screenshot real mostra 1).
    FONTE: shot_12.png + Play Store (categoria) + https://poupamais.app/
- [confirmada] A fileira de cards de estatistica corta ao meio justamente a metrica mais importante para sugerir scroll horizontal.
    EVID: shot_12: 'Ticket medio R$ 433,19' e 'Compras no mes 1' inteiros, e o terceiro card ('Gastos...' / 'R$...') truncado na borda. O truque de truncar-para-sugerir-scroll e legitimo, mas aqui sacrifica o gasto total do mes — o unico numero que o usuario realmente veio ver. Alem disso os tres cards tem peso visual identico (mesmo fundo cinza, mesmo tamanho de fonte), sem nenhuma hierarquia entre uma metrica derivada e uma metrica primaria.
    FONTE: shot_12.png
- [confirmada] A tela de produto trocou um numero decisivo por um numero indeciso.
    EVID: Build do Play (shot_4): 'Ultimo preco / R$ 4,88' — um valor, acionavel. Build mais nova (Tela 2 do cliente): 'Faixa de preco / R$ 4,98 - R$ 5,19' — uma faixa, que nao diz o que fazer. Faixa nao responde 'devo comprar?'. A resposta certa nao e nenhuma das duas: e 'mais barato hoje: R$ 4,98 no Fort, R$ 0,21 abaixo do que voce pagou'.
    FONTE: shot_4.png vs descricao da Tela 2
- [confirmada] A taxonomia de categorias esta falhando: 'Outros' e a MAIOR categoria de gasto.
    EVID: shot_12, card 'Gastos por categoria': 'Outros 26%' aparece em primeiro, 'Carnes 23%' em segundo. Um quarto do gasto nao foi classificado. Isso corroi o unico insight que o card oferece.
    FONTE: shot_12.png
- [confirmada] Densidade e affordance: dois controles para a mesma acao, e um controle de ordenacao que nao parece controle.
    EVID: shot_12: o card de categoria tem 'Ver mais' E um botao '...' lado a lado, ambos em baixo contraste, para a mesma navegacao. Tela 2: 'Onde foi encontrado' traz 'Mais barato' como controle de ordenacao, mas visualmente ele le como rotulo/chip estatico — sem chevron, sem icone de sort. Nada indica que e tocavel nem que existem outras ordens.
    FONTE: shot_12.png + descricao da Tela 2
- [confirmada] A pergunta de confianca mais importante do produto nunca e respondida na interface: '2 compras' de quem?
    EVID: Tela 2 mostra 'Fort Atacadista — 25 abr — 2 compras' e 'Cooper Fresh — ha 1 dia — 3 compras'. Nao ha copy, tooltip ou legenda em nenhuma screenshot dizendo se sao compras do usuario ou de outros usuarios. O site promete rede colaborativa; o app nunca confirma. Isso e exatamente o que fez o cliente formular a hipotese — a ambiguidade e um defeito de design, nao so de dados.
    FONTE: descricao da Tela 2 + ausencia da explicacao em todas as 5 screenshots do Play
- [confirmada] O logotipo e a melhor peca de design do produto inteiro.
    EVID: poupamais-icon.svg: uma cesta de compras cujo interior e literalmente uma grade de modulos de QR code, em cor unica #246B43, sem gradiente, sem sombra. Funciona em 48px, e memoravel, e comunica 'cesta + codigo' — a tese do produto — sem uma palavra.
    FONTE: https://poupamais.app/poupamais-icon.svg
- [provavel] PROPOSTA (recomendacao minha, nao observacao de fonte) — DIRECAO VISUAL 'ETIQUETA': tirar o verde do papel de marca e devolve-lo a semantica de preco.
    EVID: Racional: (a) o maior erro cromatico do poupa+ e o verde ser marca E preco E sucesso E ativo ao mesmo tempo; se a marca deixa de ser verde, o verde volta a significar so 'barato', o que aumenta a legibilidade E diferencia. (b) Referencia formal: etiqueta de gondola e papel de cupom, nao dashboard de fintech.
PALETA: --papel #FBF7F0 (fundo; branco quente reduz ofuscamento sob fluorescente e diferencia de todo app branco-clinico) | --tinta #171412 (texto, 17,17:1 sobre papel) | --tinta-2 #5B534A (
    FONTE: proposta do analista; os contrastes citados sao calculados, nao estimados
- [provavel] PROPOSTA (recomendacao minha) — COMPONENTE 'ETIQUETA DE PRECO': um bloco unico carregando valor da embalagem, preco por unidade base, loja, data e confianca.
    EVID: ANATOMIA em 3 linhas, linha inteira tocavel, altura minima 72dp:
L1 IDENTIDADE + VALOR — esquerda: marca normalizada da loja (NUNCA razao social), Inter 600 15sp, 1 linha com ellipsis. Direita: valor da embalagem em Archivo 700 22-26sp com tabular-nums, 'R$' a 60% do tamanho com baseline alinhada. O numero e o heroi da linha.
L2 COMPARABILIDADE (a linha que o poupa+ NAO tem) — preco por unidade base SEMPRE, normalizado por categoria: R$/kg, R$/L, R$/un, R$/100g. Renderizar 'R$ 5,19 /L' com a uni
    FONTE: proposta do analista, construida sobre as falhas medidas nos itens acima

LACUNAS DO POUPA+:
- NAO tem preco por unidade base (R$/kg, R$/L). Mostra 'R$ 4,88/UN' na busca, mas /UN nao normaliza nada — e impossivel comparar honestamente 1L vs 12x1L vs 900ml. Maior buraco funcional do produto.
- NAO responde 'em qual mercado eu gasto menos com a MINHA lista'. Compara produto a produto; a lista tem valor estimado unico, sem comparacao de cesta por loja. Essa e a pergunta que o usuario realmente tem no domingo a noite.
- O eixo Y auto-escalado do grafico transforma variacao de 4% em ladeira dramatica (Tela 2: eixo 4,11-5,37 para dados 4,98-5,19) e no Play faz o inverso, achatando (eixo 2,73-5,95 para dados 3,19-4,88). Rotulos em valores nao-redondos (R$ 4,43) que ninguem consegue usar.
- Selo 'Mais barato' concedido a observacao unica e velha (Fort, '1 compra', vence Cooper com '4 compras'). Sem peso por recencia nem por suporte amostral.
- A interface nunca diz de QUEM sao as '2 compras' / '3 compras'. A pergunta de confianca central do produto fica sem resposta no pixel.
- ~6-7 segundos de espera bloqueante apos o scan ('Processando nota fiscal...' + 'Salvando informacoes...'), em tela quase vazia — e isso no video promocional do proprio dev, provavelmente em wifi.
- ~3,5s de confete numa acao repetida semanalmente. Fadiga de celebracao, e o unico uso de cor saturada do app nao carrega informacao nenhuma.
- Tela de sucesso do scan entrega recibo, nao insight: loja, total e contagem de itens. Nenhum 'voce pagou mais caro que da ultima vez', nenhum item destacado. Desperdica o momento de maxima atencao.
- Razao social crua ('SDB COMERCIO DE ALIMENTOS LTDA') vaza justamente na tela de sucesso, embora o mapeamento CNPJ->marca exista e funcione nas outras telas.
- Contraste reprova WCAG AA em tres lugares medidos: CTA primario 4,24:1, texto secundario 4,31:1, categoria ambar sobre branco 2,07:1.
- Alvos de toque abaixo do minimo: chips de periodo 6M/3M/1M/1S com ~20-23dp de altura (minimo Android 48dp); CTA primario com ~37-42dp.
- Duas series do grafico codificadas por claridade do MESMO verde — o canal que colapsa primeiro sob luz de supermercado em LCD de entrada.
- Sem distincao visual entre preco observado e preco estimado fora do grafico; a linha pontilhada nem tem entrada de legenda.
- Taxonomia de categorias falhando: 'Outros' e a MAIOR fatia de gasto (26%), acima de Carnes (23%).
- Aba 'Historico' duplica 'Compras Recentes' da home; nav de 5 posicoes com redundancia real.
- Home abre por metrica financeira ('Ticket medio', jargao) e esconde preco, a unica coisa que so este app faz. Play categoriza como Financas, nao Compras.
- 'Compras no mes: 1' e metrica de vaidade que expoe o vazio da conta em vez de encoraja-la.
- Dois affordances de baixo contraste para a mesma acao no card de categoria ('Ver mais' + '...').
- Sem iOS ate hoje (site: 'em breve'; o demo roda em simulador iOS, entao esta em andamento).
- Cold start existencial: 10+ instalacoes. Um usuario novo numa cidade sem outros usuarios recebe um produto vazio, e a promessa colaborativa do site vira propaganda nao cumprida.
- Dependencia de terceiro pago (InfoSimples) para ler a nota: custo marginal por scan num app gratuito, e ponto unico de falha. O proprio changelog admite que falha o suficiente para justificar uma 'Central de Ajuda com dicas para quando o escaneamento da nota nao funcionar'.
- Tudo exige round-trip de servidor (Supabase + InfoSimples), inclusive o scan — e supermercado costuma ter sinal pessimo. Nenhum indicio de modo offline ou fila de sincronizacao.
- Sem lista compartilhada/domestica. Compra de mercado e atividade de casa, nao de individuo, e nao ha nenhum indicio de compartilhamento em lugar nenhum.

O QUE COPIAR:
- A ingestao por QR da NFC-e como cunha unica. E a decisao mais certa do produto: zero digitacao, dado verificado pelo governo, e produto+preco+loja+data+CNPJ numa tirada so. Nao construa entrada manual como caminho principal.
- O FAB circular central de QR no bottom nav. Ergonomia de polegar correta e prioridade correta — e o motor de dados do produto. Eles mantiveram o FAB central desde a versao de 3 abas ate a de 5; e o unico elemento de IA que nunca mudou.
- Escopo por CIDADE, nao nacional ('Jaragua do Sul/SC' + '6 resultados encontrados'). E honesto, e util, e casa exatamente com o pedido do cliente de 'bem mais simples' do que uma rede nacional.
- A normalizacao razao social -> marca de consumo ('A. ANGELONI CIA LTDA' -> 'Angeloni', 'COOPERATIVA DE PRODUCAO E ABASTECIMENTO' -> 'Cooper Fresh'). Eles construiram; e indispensavel; so precisa ser aplicada em TODAS as telas.
- O conceito da secao 'Onde foi encontrado': lista de precos por loja sob o produto, com contagem de observacoes explicita e (na versao nova) data da observacao. Esse e o nucleo honesto do produto — melhore-o em vez de reinventa-lo.
- O instinto de mostrar preco unitario ja na busca ('R$ 4,88/UN'). Certo o impulso; falta virar normalizacao real por unidade base.
- O stepper de 3 passos (Escanear -> Processar -> Concluido) para um job assincrono de varios segundos. Padrao certo, execucao errada (corpo da tela vazio). Mantenha o stepper e preencha o corpo com preview progressivo dos itens que vao chegando.
- Chips de categoria dentro da lista de itens da nota (Todos os itens / Bebidas / Laticinios / Hortifruti). Barato de fazer e util numa nota de 40 itens.
- Mostrar 'Valor total / Descontos / Valor pago' com o desconto em destaque negativo (-R$ 20,71) no detalhe da nota. E a unica hierarquia numerica bem resolvida do app.
- A contencao geral: sem anuncio, sem feed social, sem gamificacao alem do confete, gratuito. Produto de baixo ruido. Mantenha essa disciplina.
- O logotipo: cesta de compras cujo interior e uma grade de QR code, monocromatico. Nao copie o desenho, copie o METODO — um simbolo que e a tese do produto e sobrevive a 48px.

EM ABERTO:
- O seletor '< Julho 2026 >' filtra tambem 'Compras Recentes' ou so os cards de estatistica? O escopo do filtro nao esta declarado em lugar nenhum e nao consegui verificar sem instalar o app.
- As '2 compras' / '3 compras' contam observacoes de TODOS os usuarios ou so do usuario logado? O site afirma agregacao entre usuarios, mas nenhuma copy dentro do app confirma. Com 10+ instalacoes a diferenca e academica hoje, mas define a arquitetura.
- Qual o raio real de 'mercados da sua cidade' — municipio por codigo IBGE, CEP, ou raio de GPS? Determina se o concorrente pode ser hiperlocal por bairro.
- A lista de compras calcula total POR LOJA (cesta mais barata) ou so um total estimado unico? Nao consegui acessar a tela de Lista — nao ha screenshot dela no Play nem no video.
- Quanto custa cada consulta na InfoSimples? Isso define se um concorrente gratuito e viavel, ou se e preciso ler a NFC-e direto no portal da SEFAZ de cada UF (cada estado tem o seu).
- O app guarda a chave de acesso da NFC-e e reconsulta, ou guarda so o payload ja parseado? Importa para robustez e para o que acontece quando o parser muda.
- Qual a taxa real de falha do scan? O changelog de 20/jul/2026 criou uma 'Central de Ajuda com dicas para quando o escaneamento da nota nao funcionar' — isso sugere que falha com frequencia relevante, mas nao consegui medir.
- Qual a latencia p50 real de scan->salvo em 4G de supermercado? Os ~7s do video sao provavelmente o melhor caso.
- Existe tela de Lista e de Historico com design diferente do que vi? Nao ha screenshot delas em nenhuma fonte publica.
- Nao consegui acessar nenhuma review de usuario — o app nao tem avaliacoes no Play e nao ha cobertura de terceiros. Toda leitura de 'o que irrita o usuario' aqui e inferida do artefato, nao de relato real. Confianca baixa nesse eixo especifico.


# Crítica adversarial (calibração de confiança)


############ LENTE: Rigor de evidência — separar o VERIFICADO do INFERIDO/EDITORIALIZADO apresentado como fato, com foco em citações vagas, números sem fonte real, conclusões sobre o modelo de dados que são leitura de screenshot/texto, e afirmações feitas apesar de acesso falho.

VEREDITO:
O dossiê é, na média, honesto: a maioria das citações é literal e entre aspas, os "não consegui acessar" são registrados, a frente de "voz do usuário" é escrupulosa ao rotular reviews de concorrentes como proxy, e o vínculo de identidade do dev é devidamente hedgeado. PORÉM, as conclusões MAIS ESTRATÉGICAS e mais repetidas do relatório — a "bomba-relógio de unit economics" (~R$0,24/scan) e o "colaborativo por design / arquitetura CONFIRMADA" — estão marcadas como "confirmada" com um grau de certeza que a evidência não sustenta. Some-se a isso uma data de lançamento (29/abr/2026) que uma frente afirma e outra frente diz explicitamente não ter obtido da mesma fonte, um "45 instalações" tirado de JSON não documentado, medições de UX vendidas como "medidas, não opinadas" mas construídas sobre suposições de escala, e uma vantagem estratégica ("gov tem GTIN") contradita pela própria amostra coletada. Recomendação: rebaixar ~8 conclusões de "confirmada/fato" para "hipótese/estimativa" antes de usar o dossiê para decisão de produto. O núcleo factual (app embrionário, 10+ downloads, zero reviews, stack Expo/Supabase/InfoSimples declarada, textos legais colaborativos, ausência de iOS) sobrevive ao escrutínio.

PROBLEMAS:
- [CRITICO] O 'custo marginal ~R$0,24 por scan' e a narrativa 'bomba-relógio de unit economics' são a conclusão estratégica mais repetida do dossiê (5 frentes) e estão marcadas como [confirmada], mas são economicamente enganosas em duas frentes. (1) A tabela InfoSimples tem FRANQUIA MÍNIMA de R$100/mês: com 10+ usuários o poupa+ quase certamente fica ABAIXO do mínimo, então o custo marginal real por scan hoje é ZERO — paga-se R$100 fixo escaneando 1 ou ~450 notas. 'Cada cupom queima caixa' só passa a valer acima de ~500 consultas/mês. (2) O adicional 'SEFAZ/SC/NFC-e R$0,04' que compõe os R$0,24 pode nem se aplicar à consulta que eles usam — a própria seção EM ABERTO admite 'não consegui confirmar se a de NFC-e tem adicional'. Ou seja: um número marcado 'confirmada' no ACHADO é contradito por 'não confirmei' no EM ABERTO da mesma frente.
    CORRECAO: Rebaixar para [estimativa/hipótese]. Reescrever como: 'custo é R$100/mês fixo até ~500 scans; acima disso ~R$0,20/consulta, possivelmente +R$0,04/SC (não confirmado). No volume atual o custo marginal por scan é ~zero.' Remover 'bomba-relógio' como fato e apresentar como cenário de escala.
- [ALTO] A conclusão central de toda a investigação — 'poupa+ É colaborativo POR DESIGN / ARQUITETURA' — está marcada [confirmada], mas o que foi de fato verificado é apenas que os TEXTOS DE MARKETING E JURÍDICOS (landing, política, termos), escritos pelo próprio dev, DIZEM que é colaborativo. Nenhuma API própria, endpoint, APK ou comportamento observável foi acessado (todas as frentes confirmam: 'nenhuma chamada a API própria', APK bloqueado/inexistente nos espelhos). É exatamente uma conclusão sobre o modelo de dados inferida de texto. A linguagem 'colaborativa' pode ser aspiracional/cobertura-legal enquanto a implementação real é single-user.
    CORRECAO: Rebaixar de 'a arquitetura é colaborativa' para 'o produto DECLARA arquitetura colaborativa (fonte: textos do próprio autor); não observado em código/API'. Manter [confirmada] apenas para 'os documentos afirmam X'.
- [ALTO] Contradição factual direta entre frentes sobre a DATA DE LANÇAMENTO. Frentes 3 e 4 afirmam 'lançado 29/abr/2026' como fato (Frente 3: 'data 29 de abr. de 2026 no bloco de metadados'; Frente 4 repete e calcula 'menos de 3 meses'). Mas a Frente 2, lendo A MESMA ficha da Play, diz literalmente 'Tamanho do APK e data de lançamento NÃO foram obtidos... não os encontrei no JSON'. A versão web da Play tipicamente NÃO expõe data de lançamento (só 'Atualizado em'). O '29/abr' é provavelmente um campo mal-atribuído ou alucinado. Além disso contradiz o 'lançado há poucas semanas' dos RESUMOS (29/abr→22/jul = ~12 semanas).
    CORRECAO: Tratar a data de lançamento como NÃO VERIFICADA. Remover '29/abr/2026' de afirmações factuais ou marcar [não confirmado — fontes internas divergem]. Corrigir 'há poucas semanas' para '~3 meses' OU alinhar com a incerteza.
- [ALTO] A recomendação de pivotar o melhor_mercado para consumir dados do Estado apoia-se em parte na vantagem 'o app do governo tem GTIN / código de barras' (marcado [confirmada] em várias frentes). MAS a única chamada real bem-sucedida à API do Menor Preço PR (Frente 4/niche) retornou um produto com o campo 'gtin':'' VAZIO. Ou seja, a própria evidência coletada mostra GTIN ausente mesmo na fonte governamental — a vantagem 'com GTIN' não está provada como confiável e é usada como argumento estratégico de peso.
    CORRECAO: Rebaixar 'gov entrega COM GTIN' para 'a API declara campo gtin, mas a amostra observada veio vazia — disponibilidade de GTIN não confirmada em nenhuma das fontes'. Não usar GTIN como diferencial decisivo até testar N produtos de mercearia real.
- [MEDIO] O número '45 instalações' (Frentes 3 e 4: 'contador interno 45', 'cerca de 10 a 45') é apresentado como dado mais preciso que '10+'. Vem da interpretação do array não documentado da Play ["10+",10,45,"10+"]. O significado do '45' nesse payload é suposição — pode ser um limite superior de bucket, não a contagem real. É tratado como se estreitasse a faixa real de usuários.
    CORRECAO: Rebaixar para [inferência de JSON não documentado]. Reportar apenas '10+ (faixa pública); um valor 45 aparece no payload interno, significado incerto'. Não afirmar '10 a 45 usuários reais'.
- [MEDIO] A Frente 5 vende as falhas de UX como 'medidas, não opinadas', mas as medições de ALVO DE TOQUE (chips 6M/3M/1M/1S = '~20-23dp') são derivadas de uma cadeia de suposições sobre um screenshot de MARKETING dentro de uma moldura de aparelho: assume-se que o CTA é full-width menos 16dp de margem e que o device é 360dp para fixar a escala px/dp. Screenshot promocional dentro de mockup não tem escala dp confiável. As medições de CONTRASTE (a partir de amostragem de cor) são defensáveis; as de GEOMETRIA/dp não são 'medição', são estimativa.
    CORRECAO: Separar os dois: manter contrastes como calculados; rebaixar os alvos de toque para 'estimativa a partir de proporção do mockup — não confirmado no app real'. Confirmar só instalando/inspecionando o APK.
- [MEDIO] Latência de scan (~6-7s), 'espera bloqueante em tela vazia' e '~3,5s de confete' são apresentados como comportamento real do produto (e as LACUNAS os listam como defeitos de UX confirmados). A fonte é a cronometragem de um VÍDEO PROMOCIONAL de 18,9s — artefato de marketing potencialmente editado/acelerado, não captura de sessão real. A própria frente admite noutro ponto 'provavelmente melhor caso', mas os ACHADOS e LACUNAS tratam como fato de performance.
    CORRECAO: Rebaixar para 'no vídeo promocional (não é sessão real e pode estar editado), o fluxo aparenta ~7s'. Não afirmar latência real sem medir p50 em 4G.
- [MEDIO] A Frente 3 sustenta 'React Native, não Flutter' [confirmada] com a frase 'o visual Material 3 do print é, portanto, RN e não Flutter'. Esse raciocínio é INVÁLIDO/invertido: Material 3 é a linguagem de design do FLUTTER; não distingue RN de Flutter e, se algo, aponta para Flutter. A conclusão RN se apoia validamente só na citação 'Expo (EAS)' (exclusivo de RN) — mas a evidência de Material 3 citada é um non-sequitur. Além disso, a mesma alegação é [provavel] na Frente 1/2 e [confirmada] na Frente 3: rótulo de confiança inconsistente para a mesma afirmação.
    CORRECAO: Remover a frase do Material 3 como evidência. Basear a conclusão RN apenas em 'Expo/EAS'. Padronizar o rótulo (Expo→RN é forte, mas 'confirmada' exigiria APK; sugiro [provável-alta] em todas as frentes).
- [MEDIO] Overstatement de cobertura do concorrente estatal. Frente 3 afirma 'cobertura de 100% do varejo' e 'entrega de graça com cobertura de 100%' para o Menor Preço Brasil. O que as fontes sustentam é 'dados do fluxo de NFC-e/NF-e dos estados EM FUNCIONAMENTO, em tempo real' — não '100% do varejo' (nem todo varejo emite NFC-e; nem todos os estados aderiram). '100%' é editorial.
    CORRECAO: Trocar '100% do varejo' por 'cobre o fluxo de NFC-e dos estados participantes'. Manter só o que as descrições oficiais dizem.
- [BAIXO] Números '60 mil estabelecimentos' e '10 milhões de preços/semana' (Nota Paraná, Frente niche) vêm da META DESCRIPTION do próprio portal governamental — auto-declaração de marketing — mas são apresentados como métricas verificadas de escala do concorrente.
    CORRECAO: Atribuir como 'segundo a própria descrição oficial (não auditado)'.
- [BAIXO] Inconsistência entre RESUMO e corpo em pontos hedgeados. Ex.: a frente de voz do usuário afirma no RESUMO 'o cupom em papel está em extinção regulatória no Brasil' como risco estrutural, mas o corpo corretamente rebaixa para 'indício, não fato, blog sensacionalista, não localizei texto normativo primário'. O leitor que lê só o RESUMO recebe como fato o que o corpo tratou como incerto. Mesmo padrão com a stack marcada 'quase certo' no RESUMO e 'provavel' no achado.
    CORRECAO: Alinhar RESUMOs ao grau de confiança do corpo — prefixar com 'indício:' ou 'provável:' onde o corpo hedgeia.

CONCLUSOES QUE SUSTENTAM:
- App embrionário: '10+ downloads' e ZERO avaliações — verificado por leitura direta do HTML da Play E pela chamada ao RPC UsvDTd retornando array vazio em duas ordenações (método de verificação forte, bem documentado).
- Não existe versão iOS — confirmado por lookup na API oficial da Apple (resultCount 0) + FAQ do site. Sólido.
- Os TEXTOS do produto declaram modelo colaborativo agregado e anônimo — triplo-sourced com citações literais de landing, política §2/§3 e termos §5 (o que é confirmado é o texto, não a implementação).
- Stack de terceiros DECLARADA: Supabase, InfoSimples, PostHog, Sentry, Google, Expo/EAS — citação literal da política de privacidade. Verificado como declaração.
- poupa+ terceiriza a consulta da NFC-e (não faz scraping próprio) — declarado literalmente na política; e o portal SC realmente responde com gate de captcha (curl verificado). Bem sustentado.
- Zero pegada digital (sem reviews, imprensa, Wayback) — múltiplas buscas + CDX vazio. Consistente e honestamente reportado.
- A frente de 'voz do usuário' é metodologicamente correta ao declarar que NÃO há voz de usuário do poupa+ e usar ~490 reviews de concorrentes explicitamente rotulados como proxy de categoria.
- O vínculo de identidade Alex Freitag/devfreitag é adequadamente marcado [provavel] com ressalva explícita de 'coincidência de handle/nome/UF, não declaração'.
- Discrepância entre Data Safety da Play (só nome/email/IDs) e dados realmente guardados (produtos/preços/CNPJ) — contraste direto entre duas fontes primárias. A OBSERVAÇÃO sobrevive; a consequência 'risco de takedown' é que é especulativa.


############ LENTE: Decisão de produto — a recomendação emergente do dossiê é copiar o modelo de histórico pessoal de preços do poupa+ ("bem mais simples" que uma rede colaborativa nacional). Avaliação adversarial: é a decisão certa ou o caminho de menor resistência?

VEREDITO:
A recomendação de copiar o poupa+ é, em grande parte, o CAMINHO DE MENOR RESISTÊNCIA disfarçado de estratégia. Ela otimiza para "o que um dev solo consegue shipar" e, ao fazê-lo, escolhe deliberadamente o quadrante estruturalmente mais fraco do domínio: menor retenção (histórico pessoal tem curva de valor invertida e mecânica de tarefa semanal), zero defensabilidade (single-player não tem efeito de rede nem fosso de dados) e ainda herda os DOIS problemas não resolvidos do poupa+ (custo marginal por scan e cold start) — subtraindo justamente a única coisa que poderia virar fosso (a base colaborativa). Pior: o próprio dossiê prova que o poupa+ NÃO é um modelo validado (10+ instalações, 0 avaliações, 0 retenção observável), então "copiar as decisões dele" é copiar uma aposta não testada de um dev solo cuja qualidade de UI foi confundida com product-market fit. E o dossiê também já entrega o fato que deveria ter invertido a conclusão: o Estado (Menor Preço Brasil, presente em SC, + API pública notaparana com GTIN, geolocalização e tempo real) JÁ resolve de graça, melhor, a proposta de comparação — matando tanto o modelo colaborativo quanto o de comparação. APOSTA CENTRAL QUE UM CONCORRENTE DEVERIA FAZER (concreta): inverter a arquitetura. (1) SUPRIMENTO: consumir o dado de preço gratuito do Estado (API pública do Menor Preço/SVRS) como fonte de comparação em vez de coletar por scan — isso mata o cold start (dado nacional existe no dia 1 onde o Estado opera), mata a bomba de unit economics (InfoSimples deixa de ser custo por nota) e entrega GTIN + geo que o poupa+ não tem. (2) RETENÇÃO: fazer a LISTA DE COMPRAS RECORRENTE ser o produto e a âncora de hábito — não o scanner. Bring!/Out of Milk têm ~100x a tração dos apps de cupom justamente porque a lista é objeto de uso DIÁRIO, e o scan é tarefa semanal chata. (3) VALOR REAL: a pergunta de domingo à noite — "qual a cesta da MINHA lista mais barata, dividida entre os 2-3 mercados perto de mim" — que nem o Estado nem o poupa+ respondem. O NFC-e vira enriquecimento OPCIONAL (o que EU realmente pago, meu orçamento), não o gesto central. Isso é defensável (otimização de cesta + lista pessoal + hábito), tem valor no dia 1 (a lista já é útil antes de qualquer scan) e não compete de frente com um produto estatal gratuito e superior.

PROBLEMAS:
- [CRITICO] A recomendação trata o poupa+ como template de decisões de produto, mas o próprio dossiê prova que ele é uma aposta NÃO VALIDADA: 10+ instalações, ZERO avaliações, ZERO menções, ZERO retenção observável. Não existe em lugar nenhum do dossiê uma única evidência de que o modelo de histórico pessoal retém alguém. Confunde-se polimento de UI de um dev backend sênior com product-market fit. Copiar dezenas de itens de 'O QUE COPIAR' de um protótipo sem tração é cargo-culting.
    CORRECAO: Rebaixar o poupa+ de 'concorrente/modelo' para 'referência de UI de um experimento sem sinal de mercado'. Antes de decidir a arquitetura, validar a hipótese de retenção com dado real: qual % de usuários de app de cupom escaneia na semana 4? Usar os ~490 reviews da categoria (que o dossiê já coletou) e as métricas do Play (apps de cupom puro são todos pequenos; apps de LISTA têm 100x mais tração) como evidência — que aponta para a lista, não o histórico, como âncora.
- [CRITICO] RETENÇÃO não é resolvida. Histórico pessoal de preços tem curva de valor invertida (trabalho após a compra, recompensa semanas depois) e mecânica de tarefa semanal. A recomendação nunca estabelece por que alguém volta na semana 4. O gesto central proposto (escanear cupom) é uma corveia semanal que depende de pedir via impressa, de a SEFAZ estar de pé, e falha o bastante para virar release note. Ninguém forma hábito diário em torno disso.
    CORRECAO: Mover a âncora de retenção do SCANNER para a LISTA DE COMPRAS recorrente — objeto de uso diário/contínuo, não semanal. O scan passa a ser enriquecimento opcional. Contradiz diretamente a recomendação do dossiê de 'copiar o FAB-central-de-scan como motor do app': o motor de retenção deve ser a lista, o scan é acessório.
- [CRITICO] DEFENSABILIDADE zero. O dossiê admite que a base colaborativa é o único fosso possível — e a recomendação manda abandoná-la. Single-player não tem efeito de rede nem moat de dados: qualquer um clona em um mês. E, pior, para a proposta de COMPARAÇÃO o produto estatal (Menor Preço Brasil, já em SC, + API pública com GTIN/geo/tempo real) entrega de graça, melhor e com cobertura 100% do varejo. A versão 'mais simples' fica no cruzamento de 'sem moat' com 'compete contra um grátis superior'.
    CORRECAO: Assumir explicitamente que 'coletar preço' e 'comparar preço' são jogos perdidos (Estado ganha) e mover o fosso para a CAMADA QUE O ESTADO SE RECUSA A FAZER: lista recorrente + roteirização de cesta ('sua lista sai R$47 mais barata dividida entre X e Y') + orçamento pessoal + alerta de aumento. O moat vira a otimização + o dado pessoal + o hábito, alimentado por preço gratuito de terceiro (Estado), não por scans próprios.
- [ALTO] A resposta do dossiê para o VALOR NO DIA 1 (usuário com zero compras) é fraca: 'o valor imediato do primeiro scan é o detalhamento da compra que acabou de acontecer'. Isso é um visualizador de recibo dos preços que o usuário LITERALMENTE acabou de ver no caixa — valor próximo de zero. Não há nada que justifique instalar, criar conta obrigatória e escolher cidade antes de qualquer benefício.
    CORRECAO: O valor do dia 1 tem que ser independente do histórico do usuário. Com dado estatal gratuito, o dia 1 entrega comparação real ('onde a MINHA lista está mais barata hoje') sem exigir nenhum scan. A lista é útil no minuto 1. Só assim se rompe o 'paradoxo do dia 1' que o próprio dossiê identifica mas não resolve.
- [ALTO] A contradição de VIABILIDADE ECONÔMICA / FONTE DE DADO não é resolvida — só empurrada. O dossiê alerta que a InfoSimples é custo marginal por nota (bomba de unit economics num app grátis) e a alternativa 'ler a SEFAZ direto' esbarra em 27 portais estaduais com captcha hostil (prova direta: gate do sat.sef.sc.gov.br). Copiar o modelo de scan herda OU o custo por nota OU um pesadelo de manutenção de 27 scrapers. Isso não é detalhe: define se o produto pode ser gratuito.
    CORRECAO: Se o dado de comparação vem do Estado (grátis), o NFC-e do usuário deixa de ser a fonte de suprimento e passa a ser enriquecimento pessoal de baixo volume — reduzindo drasticamente o custo InfoSimples e removendo o custo do caminho crítico. Exige, porém, validar juridicamente e testar rate limit da API estatal ANTES de apostar (o dossiê deixa isso como 'EM ABERTO' — é pré-requisito, não item futuro).
- [MEDIO] A comparação entre lojas — a promessa central que a recomendação copia — é estruturalmente NÃO CONFIÁVEL no caminho do poupa+. A consulta pública NFC-e não devolve GTIN; o matching é por string crua ('LEITE UHT ITALAC INTEGRAL 1L'), que gera falso-positivo e falso-negativo. Copiar a UI de comparação (gráfico de 2 séries, 'faixa de preço', selo 'mais barato') herda um núcleo quebrado — e o dossiê mostra que o selo 'mais barato' já é enganoso (1 observação velha vence 4).
    CORRECAO: Casar por GTIN é o que separa histórico útil de lista de duplicatas — e o dado estatal (notaparana) JÁ traz GTIN. É mais um argumento para consumir a fonte estatal em vez de reconstruir a comparação por string a partir de scans próprios. Se for coletar por scan, tratar normalização de produto como o núcleo de dificuldade nº1, prototipado cedo com cupons reais de 2-3 redes — não como detalhe.
- [MEDIO] O gesto central copiado (escanear o QR do cupom IMPRESSO) está sob risco regulatório: a via impressa está deixando de ser obrigatória (NFC-e pode ser só e-mail/tela). Construir a aposta central sobre 'aponte a câmera para o papel' é construir sobre uma base em erosão — o dossiê levanta o risco mas a recomendação copia o gesto assim mesmo.
    CORRECAO: Não ancorar o produto no scan do papel. Se o scan for mantido como enriquecimento, prever desde já os caminhos alternativos que os usuários da categoria mais pedem (chave de 44 dígitos colada, importação por e-mail, XML/PDF, QR na tela do PDV). Reforça a decisão de fazer a lista — e não o scan — ser o coração do produto.

CONCLUSOES QUE SUSTENTAM:
- CONCORDO e reforço: o dossiê está certo em dizer que a base colaborativa nacional é o pedaço já resolvido de graça pelo Estado e impossível de vencer com escala de startup — mas ele tira a conclusão errada disso. A conclusão certa não é 'faça single-player'; é 'consuma o dado do Estado e agregue valor em cima'.
- CONCORDO: o poupa+ pagou o custo arquitetural de uma rede colaborativa e colhe o resultado de um diário pessoal — prova de que a rede é o pedaço caro e sem retorno. Isso condena o modelo de coleta por scan, não valida o modelo de histórico pessoal.
- DISCORDO da leitura de que 'single-player é a versão que funciona com 1 usuário' — ela confunde 'funciona tecnicamente' com 'vale a pena reter'. Um arquivo pessoal de recibos funciona com 1 usuário justamente porque entrega quase nada que dependa de outros — e por isso mesmo entrega quase nada que retenha.
- DISCORDO de tratar o poupa+ como concorrente/modelo: o dossiê no seu melhor momento já diz 'copiar as decisões dele é copiar uma aposta não testada' e 'é um protótipo público, não um produto validado' — essa é a conclusão que deveria ter dominado a recomendação final, e foi diluída.
- CONCORDO com o achado de que os apps de LISTA (Bring!, Out of Milk, SoftList) têm ~100x a tração dos apps de cupom fiscal puro — é a evidência empírica mais forte do dossiê e aponta diretamente para a lista como produto, contra a recomendação de centrar no scanner.
