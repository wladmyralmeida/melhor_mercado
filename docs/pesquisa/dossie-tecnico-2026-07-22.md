

################################################################
# TOPICO: Documento fiscal eletrônico brasileiro no varejo (NFC-e mod. 65, CF-e-SAT mod. 59, NF-e mod. 55): especificação real de leitura de QR Code e obtenção de itens
################################################################

## RESUMO EXECUTIVO
O QR Code da NFC-e NÃO contém os itens da compra — contém apenas a chave de acesso de 44 dígitos + 2 a 7 metadados + a URL de consulta da SEFAZ da UF emitente. Os itens só existem no XML da NFC-e e na página de consulta pública da UF. Hoje (2026-07) convivem dois leiautes: QR v2.00 (dominante, `?p=chave|2|tpAmb|idCSC|hash40`) e QR v3.00 (NT 2025.001, produção desde 01/09/2025, `?p=chave|3|tpAmb`, sem CSC). O v1.00 (query string com `chNFe=&nVersao=100&...&cHashQRCode=`) está morto desde 01/10/2018 mas ainda aparece em cupons antigos e deve ser aceito pelo parser. O CF-e-SAT (SP/CE) é diferente: o QR não é URL, é a string `chave|AAAAMMDDHHMMSS|vCFe|CPF_CNPJ|assinaturaQRCODE`. A chave de 44 dígitos e o dígito verificador módulo 11 (pesos 2..9 da direita para a esquerda, DV=11−resto, resto 0/1 → DV=0) foram verificados numericamente contra o exemplo do MOC 7.0 e contra uma chave real de CF-e-SAT. CONSEQUÊNCIA ARQUITETURAL CRÍTICA: consultar a página pública de NFC-e por UF em escala NÃO é viável nem legítimo — testei hoje por HTTP e RS usa hCaptcha, SP e MG usam reCAPTCHA, SC usa Cloudflare Turnstile, GO devolve 403 (WAF), RJ bloqueia por reputação de IP com mensagem explícita, PA não responde. Não existe API pública oficial documentada para consulta de NFC-e por chave sem certificado digital ICP-Brasil. Os únicos caminhos legítimos de obter ITENS são: (a) OCR do DANFE NFC-e impresso/fotografado (documento que o próprio usuário possui), (b) XML fornecido pelo emitente ao consumidor, (c) certificado digital próprio via NFeDistribuicaoDFe (só serve para documentos em que a empresa é participante — não serve para compras de terceiros), (d) convênio formal com SEFAZ/ENCAT, (e) encartes. O QR deve ser usado como fonte de VERDADE DE IDENTIDADE (chave, UF, CNPJ emitente, AAMM, valor total quando offline), não como fonte de itens.

## ACHADOS

### [confirmada] Chave de acesso NF-e/NFC-e (leiaute 4.00) tem 9 campos em posições fixas, totalizando 44 dígitos
Posições 1-indexadas: [1-2] cUF (B02, código IBGE); [3-6] AAMM extraído de dhEmi (B09); [7-20] CNPJ ou CPF do emitente (C02/C02a — CPF preenchido com zeros à esquerda até 14); [21-22] mod (B06) = 55 NF-e | 65 NFC-e; [23-25] serie (B07); [26-34] nNF (B08); [35] tpEmis (B22); [36-43] cNF (B03, 8 dígitos ALEATÓRIOS); [44] cDV (B23). Antes do leiaute 2.00 não havia tpEmis e cNF tinha 9 dígitos. Chave natural da NFC-e = UF + CNPJ emitente + série + número + modelo + tpEmis (NT 2018.001) — use isso como unique key no Postgres, não a chave completa.
FONTE: https://www.confaz.fazenda.gov.br/legislacao/arquivo-manuais/moc7-visao-geral.pdf

### [confirmada] Algoritmo do DV (módulo 11) — verificado numericamente, reproduz o exemplo oficial
Aplicar aos 43 primeiros dígitos os pesos cíclicos [2,3,4,5,6,7,8,9] da DIREITA para a ESQUERDA; somar; resto = soma % 11; DV = 11 − resto; SE resto ∈ {0,1} ENTÃO DV = 0. Python: `def dv(c43): p=[2,3,4,5,6,7,8,9]; s=sum(int(d)*p[i%8] for i,d in enumerate(reversed(c43))); r=s%11; return 0 if r<2 else 11-r`. Test vector do MOC 7.0: 43 dígitos '5206043300991100250655012000000780026730161' → soma=644, 644%11=6, DV=5. EXECUTEI e bate. Também validei contra chave real de CF-e-SAT 35111202767579000148598583801050151865833992 → DV calculado 2 = DV informado 2. ATENÇÃO: as chaves 'hipotéticas' 28170800156225000131650110000151341562040824 e ...151349562040824 do Manual do QR Code têm DV INVÁLIDO (calculado 8 e 3 vs. informado 4) — não use como test vector de DV, apenas de hash.
FONTE: https://www.confaz.fazenda.gov.br/legislacao/arquivo-manuais/moc7-visao-geral.pdf

### [confirmada] QR Code NFC-e versão 2.00 — formato exato (padrão dominante hoje)
URL = <endereço_UF>?p=<params separados por '|'>. ONLINE (5 campos): chave44|2|tpAmb|idCSC|hash40. OFFLINE/contingência (8 campos): chave44|2|tpAmb|DD|vNF|digVal|idCSC|hash40. Campos: tpAmb 1=Produção 2=Homologação; DD = dia da emissão, exatamente 2 dígitos; vNF = valor total (W16) com PONTO decimal, sem separador de milhar, até 15 bytes; digVal = DigestValue do XML convertido para HEXA (56 chars = hex ASCII da string base64 de 28 chars, ex.: 'yzGYhUx1/XYYzksWB+fPR3Qc50c=' → '797a4759685578312f5859597a6b7357422b6650523351633530633d'); idCSC = 1 a 6 dígitos SEM zeros à esquerda; hash = SHA-1 em HEXA MAIÚSCULO, 40 chars.
FONTE: https://betosouzace.github.io/nfe-documentacao/20250324-Manual_de_Especifica%C3%A7%C3%B5es_T%C3%A9cnicas_do_DANFE_NFC-e_QR_Code.html

### [confirmada] Cálculo do cHashQRCode v2.00 — reproduzido byte a byte, ambos os test vectors do manual batem
ONLINE: SHA1( 'chave|2|tpAmb|idCSC' + CSC ) — concatenação DIRETA do CSC, SEM separador '|' e SEM espaço. Verificado: SHA1('28170800156225000131650110000151341562040824|2|1|1' + 'SEU-CODIGO-CSC-CONTRIBUINTE-36-CARACTERES') = DC6AE2C2B9A992BE59679AC365E29922DE6B7511 ✓ (bate com o manual). OFFLINE: SHA1('chave|2|tpAmb|DD|vNF|digValHex|idCSC' + CSC). Verificado: SHA1('28170800156225000131650110000151349562040824|2|1|02|60.90|797a...633530633d|1' + CSC) = 4615A93BB0D7C4E780F8D30EE77EDD5BA55C7D66 ✓. Saída sempre em hexa MAIÚSCULO. CSC = 16 a 36 caracteres alfanuméricos, conhecido só pela SEFAZ e pelo contribuinte — NÃO é obtenível pelo app; portanto o app pode LER o hash mas NÃO pode validá-lo.
FONTE: https://betosouzace.github.io/nfe-documentacao/20250324-Manual_de_Especifica%C3%A7%C3%B5es_T%C3%A9cnicas_do_DANFE_NFC-e_QR_Code.html

### [confirmada] QR Code NFC-e versão 3.00 — novo padrão sem CSC, em produção desde 01/09/2025
ONLINE (3 campos apenas): <url_UF>?p=chave44|3|tpAmb. OFFLINE (8 campos): chave44|3|tpAmb|DD|vNF|tpIdDest|idDest|assinatura, onde tpIdDest = 1 CNPJ | 2 CPF | 3 idEstrangeiro (vazio se não identificado, mantendo o '|'), idDest = 3-14 dígitos (vazio se não identificado), assinatura = RSA SHA-1 em Base64 sobre a concatenação dos parâmetros 1..7 COM os separadores '|', assinada com o MESMO certificado digital que assina a NFC-e (≈344 chars para chave 2048 bits). No modo ONLINE v3 não há hash nem assinatura. Adoção OBRIGATÓRIA para Produtor Rural PF (exceto PR) e OPCIONAL para emitente PJ. NT 2025.001 v1.01 removeu a RV ZX02-220 'considerando que todas as UF irão disponibilizar o layout do qrCode v3'.
FONTE: https://www.nfe.fazenda.gov.br/portal/exibirArquivo.aspx?conteudo=uE%2BfQh6OuYw%3D

### [confirmada] QR Code NFC-e versão 1.00 — formato legado (query string com '&'), desativado em 01/10/2018
Exemplo literal da NT 2025.001: https://www.sefaz.rs.gov.br/NFCE/NFCE-COM.aspx?chNFe=43150108287693000157651010000000971000001251&nVersao=100&tpAmb=2&cDest=99999999000191&dhEmi=323031352d30312d32305431373a30303a34392d30323a3030&vNF=1.00&vICMS=0.00&digVal=2f4a70347771...&cIdToken=000001&cHashQRCode=ecc4f0e7e612456f2e3521768bd572b6f0eae240. Notas: nVersao='100'; dhEmi e digVal em HEXA ASCII; cIdToken com 6 dígitos COM zeros à esquerda; cHashQRCode em minúsculas neste exemplo; o conteúdo da tag qrCode do XML precisava de CDATA por causa do '&'. Cronograma: 02/07/2018 início da concomitância v1/v2; 01/10/2018 fim da concomitância — v4.00 do XML passa a aceitar SOMENTE v2.00. Parser deve aceitar v1 para cupons de arquivo/antigos.
FONTE: https://www.nfe.fazenda.gov.br/portal/exibirArquivo.aspx?conteudo=trSXReoZPuY%3D

### [confirmada] O QR Code da NFC-e NÃO contém itens — apenas metadados + URL de consulta. Explícito.
Maior payload possível é o v2 OFFLINE (~8 campos, ~200 chars) e o campo ZX02 (qrCode) do XML tem tamanho 60–1000 caracteres (ampliado pela NT 2025.001 v1.01; antes 100–600). Nem descrição, nem GTIN, nem quantidade, nem preço unitário aparecem no QR. O único valor monetário presente é vNF (total) e SOMENTE em contingência offline (v2 e v3). O manual é explícito: 'Como resultado da consulta QR Code, deverá ser apresentado ao consumidor na tela do dispositivo móvel o DANFE NFC-e completo (com itens de mercadoria)' — ou seja, os itens vêm da CONSULTA na SEFAZ, não do QR.
FONTE: https://betosouzace.github.io/nfe-documentacao/20250324-Manual_de_Especifica%C3%A7%C3%B5es_T%C3%A9cnicas_do_DANFE_NFC-e_QR_Code.html

### [confirmada] QR Code do CF-e-SAT (modelo 59) NÃO é URL — é string pipe-delimited de 5 campos
Conteúdo: chave_consulta|AAAAMMDDHHMMSS|valor_total|CPF_ou_CNPJ|assinaturaQRCODE. Sem delimitador final. Se não houver adquirente: 'chave|data_hora|valor||assinatura' (dois pipes seguidos). Exemplo de string assinada: '35087746478373757726265545868587463856478463|20110101170101|59.05|12345678912'. assinaturaQRCODE = assinatura RSA com o certificado do equipamento SAT, resultado em Base64 padrão PKCS#1 v1.5, campo de 344 chars (ID B13 no CF-e de venda, B12 no de cancelamento). Parâmetros do símbolo: ISO 18004, UTF-8, nível de correção L, mínimo 4x4 cm (3x3 cm facultativo a partir de 01.01.19), margem ≥0,5 cm.
FONTE: https://portal.fazenda.sp.gov.br/servicos/sat/Downloads/Manual_Orientacao_SAT_v_MO_2_19_04.pdf

### [confirmada] Chave do CF-e-SAT tem layout DIFERENTE da NF-e/NFC-e — não reutilize o mesmo parser
cUF(2) + AAMM(4) + CNPJ(14) + mod(2, sempre '59') + nserieSAT(9) + nCF(6) + cNF(6) + cDV(1) = 44. Não existe tpEmis; nserieSAT ocupa 9 posições (onde a NF-e tem serie 3 + nNF 9 = 12... na prática as faixas 21-22 (mod) e 23-31, 32-37, 38-43 diferem). O DV usa o MESMO módulo 11 base 2..9. No XML o campo Id vem prefixado pelo literal 'CFe' (ex.: 'CFe35111202767579000148598583801050151865833992'); no extrato impresso a chave aparece SEM o 'CFe', em 11 blocos de 4 posições com 2 espaços entre blocos. Regra prática de roteamento: leia chave[20:22]; '65'→NFC-e, '55'→NF-e, '59'→CF-e-SAT.
FONTE: https://servicos.sefaz.ce.gov.br/internet/download/projetomfe/Especificacao_SAT_v_ER_2_29_04.pdf

### [confirmada] Não existe campo 'urlChave' no QR Code — ele está no XML (grupo ZX), criado pela NT 2015.002
Grupo ZX 'Informações Suplementares da Nota Fiscal': ZX01 infNFeSupl (G, 0-1); ZX02 qrCode (C, 1-1, 60–1000 chars) = texto do QR impresso no DANFE; ZX03 urlChave (C, 1-1, 21–85 chars) = URL da consulta por chave de acesso impressa no DANFE. Não afeta a assinatura digital. As NTs relevantes CONFIRMADAS: NT 2015.002 (criou o grupo ZX / qrCode / urlChave), NT 2016.002 (troco obrigatório no DANFE), NT 2017.001 (validação de GTIN cEAN/cEANTrib contra o CCG), NT 2018.001 (chave natural + emitente CPF na chave), NT 2025.001 v1.01 jun/2025 (QR v3 + resposta síncrona). NÃO confirmei existência de 'NT 2020/006' para NFC-e.
FONTE: https://www.nfe.fazenda.gov.br/portal/exibirArquivo.aspx?conteudo=uE%2BfQh6OuYw%3D

### [confirmada] A tabela oficial de URLs de consulta por UF é mantida pelo ENCAT, não pela Receita Federal
QR Code: http://nfce.encat.org/desenvolvedor/qrcode/ (produção + homologação). Consulta por chave: Portal Nacional NFC-e → 'Consumidor' → 'Consulte sua Nota'. Ambas as URLs são citadas nominalmente no Manual v6.0 e na tabela ZX da NT 2025.001. Nota operacional: curl direto em nfce.encat.org retorna 403 (proteção anti-bot); acessei via fetch tipo navegador. As URLs MUDAM: MG migrou em 21/03/2022 (nfce.fazenda.mg → portalsped.fazenda.mg), RJ em 19/12/2023 (www4.fazenda.rj → consultadfe.fazenda.rj), GO em 16/06/2025, RN em 25/05/2026. Portanto: NUNCA hardcode a URL do QR — derive a UF de chave[0:2] e mantenha a tabela em banco versionado.
FONTE: http://nfce.encat.org/desenvolvedor/qrcode/

### [provavel] URLs de produção do QR Code por UF (snapshot 2026-07-22, do portal ENCAT)
AC http://www.sefaznet.ac.gov.br/nfce/qrcode? | AL http://nfce.sefaz.al.gov.br/QRCode/consultarNFCe.jsp | AP https://www.sefaz.ap.gov.br/nfce/nfcep.php | AM sistemas.sefaz.am.gov.br/nfceweb/consultarNFCe.jsp | BA http://nfe.sefaz.ba.gov.br/servicos/nfce/qrcode.aspx | CE http://nfce.sefaz.ce.gov.br/pages/ShowNFCe.html? | DF http://www.fazenda.df.gov.br/nfce/qrcode? | ES http://app.sefaz.es.gov.br/ConsultaNFCe/ | GO https://nfeweb.sefaz.go.gov.br/nfeweb/sites/nfce/danfeNFCe | MA nfce.sefaz.ma.gov.br/portal/consultarNFCe.jsp | MT http://www.sefaz.mt.gov.br/nfce/consultanfce | MS http://www.dfe.ms.gov.br/nfce/qrcode? | MG https://portalsped.fazenda.mg.gov.br/portalnfce/sistema/qrcode.xhtml | PA https://appnfc.sefa.pa.gov.br/portal/view/consultas/nfce/nfceForm.seam | PB http://www.sefaz.pb.gov.br/nfce | PR http://www.fazenda.pr.gov.br/nfce/qrcode? | PE http://nfce.sefaz.pe.gov.br/nfce/consulta | PI http://www.sefaz.pi.gov.br/nfce/qrcode | RJ https://consultadfe.fazenda.rj.gov.br/consultaNFCe/QRCode | RN https://nfce.sefaz.rn.gov.br/consultarNFCe.aspx | RS https://www.sefaz.rs.gov.br/NFCE/NFCE-COM.aspx | RO http://www.nfce.sefin.ro.gov.br/consultanfce/consulta.jsp | RR https://www.sefaz.rr.gov.br/nfce/servlet/qrcode | SC https://sat.sef.sc.gov.br/nfce/consulta? | SP https://www.nfce.fazenda.sp.gov.br/qrcode | SE http://www.nfce.se.gov.br/nfce/qrcode? | TO http://www.sefaz.to.gov.br/nfce/qrcode
FONTE: http://nfce.encat.org/desenvolvedor/qrcode/

### [confirmada] TESTE PRÁTICO 2026-07-22: as páginas públicas de consulta NFC-e por UF estão protegidas por CAPTCHA/WAF
Requisições HTTP GET únicas, User-Agent de navegador, resultado observado: RS (sefaz.rs.gov.br/NFCE/NFCE-COM.aspx) → HTTP 400 + markers 'hcaptcha'/'recaptcha'; SP (nfce.fazenda.sp.gov.br/NFCeConsultaPublica/.../ConsultaQRCode.aspx) → 200 + 'recaptcha'; MG (portalsped.fazenda.mg.gov.br/portalnfce/sistema/qrcode.xhtml) → 200 + 'reCAPTCHA'; SC (sat.sef.sc.gov.br/nfce/consulta) → 200 + 'Cloudflare Turnstile'; GO (nfeweb.sefaz.go.gov.br) → HTTP 403 (WAF); RJ (consultadfe.fazenda.rj.gov.br) → 200 com página de bloqueio textual: 'nosso serviço de segurança da informação bl[oqueia]...' por reputação de IP de operadora; PA (appnfc.sefa.pa.gov.br) → sem resposta (timeout). PR, BA, CE, PE responderam sem marcador de captcha na página inicial (pode haver captcha na submissão). Conclusão: raspagem em escala é inviável e ilegítima.
FONTE: https://www.nfce.fazenda.sp.gov.br/NFCeConsultaPublica/Paginas/ConsultaQRCode.aspx

### [confirmada] Portal Nacional da NF-e: consulta resumida pública com reCAPTCHA; consulta completa exige acesso identificado
Endpoint público real: https://www.nfe.fazenda.gov.br/portal/consultaRecaptcha.aspx?tipoConsulta=resumo — exige reCAPTCHA, sem certificado. MOC 7.0 §7.1: 'A Consulta Completa ... retornará todo o conteúdo da NF-e, EXCLUSIVAMENTE aos participantes da operação comercial descritos no documento eletrônico (emitente, destinatário, transportador e terceiros em autXML), por meio do acesso identificado do consulente'. §7.2: fora disso, só a consulta resumida. Exceção: a restrição NÃO se aplica a NF-e emitidas para PF (CPF) sem inscrição estadual ou PJ (CNPJ) sem IE. O Portal Nacional é o canal da NF-e mod. 55; a NFC-e mod. 65 é consultada no portal da UF emitente (mensagem padronizada 247 confirma validação de UF).
FONTE: https://www.confaz.fazenda.gov.br/legislacao/arquivo-manuais/moc7-visao-geral.pdf

### [confirmada] Não existe API pública oficial de consulta de NFC-e sem certificado digital. Os web services exigem ICP-Brasil A1/A3 com TLS mútuo
NFeDistribuicaoDFe: exige certificado PJ (e-CNPJ) ou PF (e-CPF) válido; devolve lotes de ATÉ 50 documentos por requisição; retenção de apenas 90 DIAS no Ambiente Nacional; a chave consultada 'deve estar vinculada ao interessado como destinatário, transportador ou terceiro'; documentos emitidos pela própria empresa NÃO são distribuídos; cStat 137 = nenhum documento localizado, 138 = documento localizado. Certificado: X.509 v3, CNPJ em OtherName OID 2.16.76.1.3.3 ou CPF em OID 2.16.76.1.3.1. NÃO confirmei se NFC-e modelo 65 é distribuída por esse WS para o CPF do consumidor — trate como não disponível até prova em contrário.
FONTE: https://www.confaz.fazenda.gov.br/legislacao/arquivo-manuais/moc7-visao-geral.pdf

### [confirmada] Existe rate limiting formal nos web services SEFAZ: rejeição 656 'Consumo Indevido'
MOC 7.0 §4 (Tabela 4-9): a SEFAZ autorizadora 'a seu critério, poderá implantar as regras de validação de Consumo Indevido'. Padrões punidos: loop consultando a mesma chave de acesso; consulta de chaves inexistentes de forma repetida ('em alguns casos, fica sendo consultada uma Chave de Acesso inexistente durante meses'); consulta de status em frequência maior que a prevista. Rejeição: cStat 656. 'O contribuinte que estiver utilizando indevidamente os sistemas poderá sofrer as penalidades definidas na legislação de cada UF.' Não há número absoluto publicado (req/min) — é discricionário por UF.
FONTE: https://www.confaz.fazenda.gov.br/legislacao/arquivo-manuais/moc7-visao-geral.pdf

### [confirmada] Campos obrigatórios do DANFE NFC-e impresso — mapa completo para o OCR (9 divisões)
DIV I cabeçalho: CNPJ 99.999.999/9999-99 (C02) OU CPF 999.999.999-99 (C02a, incluído em mar/2025); Razão Social/Nome (C03, xNome); endereço completo SEM país; texto 'Documento Auxiliar da Nota Fiscal de Consumidor Eletrônica'. DIV II itens (pode ser SUPRIMIDA no DANFE 'resumido/ecológico'): Código (I02 cProd), Descrição (I04 xProd), Qtde (I10 qCom), Un (I09 uCom), Valor unit. (I10a vUnCom), Valor total (I11 vProd) — decimais com VÍRGULA e milhar com PONTO. DIV III totais: Qtde. Total de Itens (itens distintos, NÃO soma de quantidades), Valor Total R$, Acréscimos/Desconto (W08/W09/W10/W15), Valor a Pagar R$ (W16 vNF), Forma de Pagamento (YA02 tPag, pode haver várias), Valor Pago (YA03 vPag), Troco (YA09 vTroco, obrigatório desde NT 2016.002). DIV IV: 'Consulte pela Chave de Acesso em' + URL + chave em 11 BLOCOS DE 4 DÍGITOS separados por espaço. DIV V: QR Code ≥25x25mm. DIV VI consumidor: 'CONSUMIDOR CPF:'/'CONSUMIDOR CNPJ:'/'CONSUMIDOR Id. Estrangeiro:' OU 'CONSUMIDOR NÃO IDENTIFICADO'. DIV VII: nNF (B08), série (B07), data/hora dhEmi convertida para horário LOCAL, 'Protocolo de autorização:' + nProt + dhRecbto. DIV VIII: infAdFisco / 'EMITIDA EM CONTINGÊNCIA Pendente de autorização' / 'EMITIDA EM AMBIENTE DE HOMOLOGAÇÃO – SEM VALOR FISCAL'. DIV IX: infCpl + Lei 12.741/2012 (vTotTrib). Papel: largura mínima 56mm, margens laterais ≥2mm, legibilidade garantida por ≥6 meses. Proibido imprimir DANFE NFC-e em ECF.
FONTE: https://betosouzace.github.io/nfe-documentacao/20250324-Manual_de_Especifica%C3%A7%C3%B5es_T%C3%A9cnicas_do_DANFE_NFC-e_QR_Code.html

### [confirmada] Identificação do consumidor no DANFE só é impressa acima de R$ 10.000,00 ou a pedido — não conte com CPF no cupom
Manual: 'As informações de CNPJ, CPF ou de identificação de estrangeiro somente deverão ser impressas se constarem do arquivo eletrônico da NFC-e em decorrência de NFC-e de valor igual ou superior a R$ 10.000,00 (valor que poderá ser MENOR, a critério da UF), NFC-e para entrega em domicílio ou atendendo pedido de identificação do consumidor.' Em entrega em domicílio é OBRIGATÓRIO imprimir nome do consumidor e endereço de entrega. Implicação de privacidade para o melhor_mercado: o cupom fotografado pode conter CPF e endereço → tratar como dado pessoal LGPD e mascarar/descartar na ingestão.
FONTE: https://betosouzace.github.io/nfe-documentacao/20250324-Manual_de_Especifica%C3%A7%C3%B5es_T%C3%A9cnicas_do_DANFE_NFC-e_QR_Code.html

### [confirmada] Extrato do CF-e-SAT: layout de itens e rodapé (para OCR em SP/CE)
Corpo: <n> nItem (H01) | <cod> cProd (I02) | <desc> xProd (I04) | <qtd> qCom (I08) | <un> uCom (I07) | <valor1> vUnCom (I09) | <valor3> vProd (I10, = qtd × valor1 ANTES de descontos) | <valor4> vDesc (I12) | <valor5> vOutro (I13) | <(valor2)> vItem12741 (M02, tributos aproximados, com asterisco e nota '*valor aproximado dos tributos do item'). Rodapé: chave de consulta em negrito (11 blocos de 4 com 2 espaços), código de barras CODE-128 C (OPCIONAL), QR Code, 'Consumidor: <CPF/CNPJ> - <nome>', 'No. Série do SAT' (B05 nserieSAT) em negrito, 'DD/MM/AAAA - HH:MM:SS' (B07 dEmi, B08 hEmi), mensagem 'Consulte o QR Code pelo aplicativo "De olho na nota"' (SP) ou '"Sua Nota Tem Valor"' (CE). Título: 'Extrato <nCFe> CUPOM FISCAL ELETRÔNICO - SAT'.
FONTE: https://portal.fazenda.sp.gov.br/servicos/sat/Downloads/Manual_Orientacao_SAT_v_MO_2_19_04.pdf

### [confirmada] Códigos de erro padronizados da consulta NFC-e — use-os como taxonomia de validação no seu backend
100 Hash QR Code inválido; 101 CSC inválido; 102 CSC revogado; 103/104 identificador de CSC inexistente/inválido; 201 DV da chave inválido; 202 chave com menos de 44 caracteres; 203 AAMM inconsistente com data de emissão; 204 modelo difere de 65; 205 CNPJ do emitente na chave com DV inválido; 211/212 versão do QR inválida/não preenchida; 213/214 tpAmb difere de 1/2 ou vazio; 217/218/219/242 dia da emissão inválido/vazio/inconsistente; 220/221 vNF em formato inválido / inconsistente; 227/233 digVal inconsistente/vazio; 229 e 240 NFC-e CANCELADA; 234 prazo de 24h para envio ultrapassado; 235 emitida em contingência, volte após 24h; 236 chave não existe; 237 'Código da imagem é inválido' (= CAPTCHA errado, prova textual de que a consulta é captcha-gated); 238 ainda não consta na base; 239 UF da chave difere; 245 chave inválida; 246 chave não é de NFC-e (modelo 65); 247 chave não é de contribuinte da UF indicada.
FONTE: https://betosouzace.github.io/nfe-documentacao/20250324-Manual_de_Especifica%C3%A7%C3%B5es_T%C3%A9cnicas_do_DANFE_NFC-e_QR_Code.html

### [confirmada] Existem apps oficiais de comparação de preços baseados em NFC-e — mas sem API pública documentada
'Menor Preço Brasil': desenvolvido por PROCERGS/SEFAZ-RS em parceria com o ENCAT e apoio do BID, lançado pelo CONFAZ, adotado por ~14 UFs como app OFICIAL único (ES adotou substituindo o app estadual). 'Preço da Hora Bahia' (precodahora.ba.gov.br, PRODEB/SEFAZ-BA): base de NFC-e mod 65 + NF-e mod 55, ~3,8 milhões de notas/dia, >500 mil produtos, ~180-200 mil estabelecimentos, 417 municípios. 'Menor Preço - Nota Paraná' (menorpreco.notaparana.pr.gov.br): >60 mil estabelecimentos, >10 milhões de preços atualizados por semana. NENHUM deles publica API documentada nem termos de uso de API. precodahora.ba.gov.br embute token reCAPTCHA na página (meta id="rc") → é anti-bot explícito, NÃO contornar.
FONTE: https://www.confaz.fazenda.gov.br/noticias-do-confaz/confaz-lanca-aplicativo-menor-preco-brasil-destinado-a-ajudar-o-cidadao-a-encontrar-os-melhores-valores-no-comercio

### [confirmada] O backend do Menor Preço/Nota Paraná respondeu sem autenticação nem captcha em teste único hoje — mas é API não documentada, não é 'API pública oficial'
GET https://menorpreco.notaparana.pr.gov.br/api/v1/produtos?local=<lat>,<lon>&termo=<texto>&raio=<km>&offset=<n> → HTTP 200 JSON. Schema observado: {tempo, local, produtos:[{id, local (geohash), desc, ncm, cdanp, valor_desconto, valor_tabela, valor, datahora (ISO-8601 Z), tempo (relativo pt-BR), distkm, gtin, nrdoc, estabelecimento:{codigo, nm_fan, nm_emp, tp_logr, nm_logr, nr_logr, complemento, bairro, mun, uf, mesoreg, microreg}}]}. Campos gtin e ncm vêm preenchidos em parte dos registros. /robots.txt retorna 404 (JSON {statusCode:404}). AVISO: ausência de robots.txt e de captcha NÃO equivale a licença de uso — não há ToS de API publicado. Antes de qualquer uso em produção, solicitar autorização formal à SEFAZ-PR/ENCAT (ou via LAI, Lei 12.527/2011).
FONTE: https://menorpreco.notaparana.pr.gov.br/

### [baixa] Regime jurídico da NFC-e mudou duas vezes em 12 meses — não codifique a regra 'NFC-e só para CPF'
Ajuste SINIEF 11/2025 vedava NFC-e para destinatário CNPJ a partir de 03/11/2025; Ajuste SINIEF 30/2025 (DOU 09/10/2025) adiou para 05/01/2026; Ajuste SINIEF 43 ou 44/2025 adiou novamente para 04/05/2026; e fontes secundárias indicam que o Ajuste SINIEF 12/2026 (abril/2026) REVOGOU a vedação, com o Ajuste SINIEF 11/2026 produzindo efeitos a partir de 05/10/2026 e o 'DANFE Simplificado Tipo 2' começando em 03/08/2026. Não consegui ler o texto oficial no CONFAZ — trate os números 43/44/2025 e 10-13/2026 como NÃO confirmados. Consequência de produto: o cupom NFC-e pode ter destinatário CNPJ ou CPF; o parser deve aceitar ambos.
FONTE: https://inventti.com.br/danfe-simplificado-tipo-2-ajustes-sinief-de-2026-modernizam-a-nf-e-e-a-nfc-e-no-varejo/

### [provavel] GTIN (cEAN/cEANTrib) existe no XML e é validado contra o CCG — é a chave de normalização de produto, mas NÃO aparece no DANFE impresso
NT 2017.001 (e sucessoras, NT 2021.003) criou a validação de cEAN/cEANTrib contra o Cadastro Centralizado de GTIN (CCG), com rejeição em caso de divergência, implantada por grupos de CNAE/NCM. cEAN = GTIN-8/12/13/14 do nível superior; cEANTrib = GTIN da menor unidade vendida no varejo. Como o DANFE NFC-e impresso NÃO exige GTIN (só cProd, xProd, qCom, uCom, vUnCom, vProd), o OCR entrega apenas o CÓDIGO INTERNO DO ESTABELECIMENTO (cProd) — que varia por rede. Portanto a normalização de produtos do melhor_mercado terá que ser feita por (cnpj_emitente, cProd) + fuzzy match de xProd, e só terá GTIN quando houver XML ou fonte externa.
FONTE: https://www.nfe.fazenda.gov.br/portal/exibirArquivo.aspx?conteudo=ItjrLYerN%2FE%3D

### [confirmada] Códigos cUF (IBGE) para roteamento por chave[0:2]
11 RO, 12 AC, 13 AM, 14 RR, 15 PA, 16 AP, 17 TO, 21 MA, 22 PI, 23 CE, 24 RN, 25 PB, 26 PE, 27 AL, 28 SE, 29 BA, 31 MG, 32 ES, 33 RJ, 35 SP, 41 PR, 42 SC, 43 RS, 50 MS, 51 MT, 52 GO, 53 DF. O MOC 7.0 confirma a linha '11-Rondônia 21-Maranhão 31-Minas Gerais 41-Paraná 50-Mato Grosso do Sul' e remete à Tabela de UF do IBGE. Regra de validação J02/226: 'Código da UF do Emitente diverge da UF' do web service.
FONTE: https://www.confaz.fazenda.gov.br/legislacao/arquivo-manuais/moc7-visao-geral.pdf

### [confirmada] Versões de pacotes verificadas hoje (2026-07-22) para o stack Flutter/Python
pub.dev: mobile_scanner 7.4.0 (sdk ^3.7.0, flutter >=3.29.0 — compatível com Flutter 3.44.7/Dart 3.12.2); google_mlkit_barcode_scanning 0.15.0 (sdk >=3.8.0, flutter >=3.32.0); flutter_zxing 2.3.0 (sdk >=3.11.0, flutter >=3.41.0). PyPI: erpbrasil.edoc 3.1.1 (assinatura/transmissão de DF-e com certificado ICP-Brasil), PyNFe 0.6.5 (py>=3.8), brutils 2.5.0 (validação de CPF/CNPJ, py>=3.10), python-barcode 0.16.1. Recomendação: mobile_scanner 7.4.0 como leitor primário (MLKit Android + AVFoundation iOS, sem dependência de ML Kit isolado).
FONTE: https://pub.dev/api/packages/mobile_scanner

## ESPECIFICACOES CONCRETAS
- Chave NF-e/NFC-e v4.00 (índices Python 0-based): cUF=k[0:2] | AAMM=k[2:6] | CNPJ/CPF=k[6:20] | mod=k[20:22] | serie=k[22:25] | nNF=k[25:34] | tpEmis=k[34:35] | cNF=k[35:43] | cDV=k[43:44]
- Chave CF-e-SAT (mod. 59, 0-based): cUF=k[0:2] | AAMM=k[2:6] | CNPJ=k[6:20] | mod=k[20:22]=='59' | nserieSAT=k[22:31] | nCF=k[31:37] | cNF=k[37:43] | cDV=k[43:44]
- DV módulo 11: pesos [2,3,4,5,6,7,8,9] cíclicos da direita para a esquerda sobre os 43 primeiros dígitos; r = soma % 11; DV = 0 se r in (0,1) senão 11 - r. Test vector: soma 644 → r 6 → DV 5.
- QR NFC-e v2.00 ONLINE: `<url_uf>?p=<chave44>|2|<tpAmb>|<idCSC>|<hash40>`  (5 campos)
- QR NFC-e v2.00 OFFLINE: `<url_uf>?p=<chave44>|2|<tpAmb>|<DD>|<vNF>|<digValHex56>|<idCSC>|<hash40>`  (8 campos)
- QR NFC-e v3.00 ONLINE: `<url_uf>?p=<chave44>|3|<tpAmb>`  (3 campos)
- QR NFC-e v3.00 OFFLINE: `<url_uf>?p=<chave44>|3|<tpAmb>|<DD>|<vNF>|<tpIdDest>|<idDest>|<assinaturaBase64>`  (8 campos)
- QR NFC-e v1.00 (legado): `<url_uf>?chNFe=&nVersao=100&tpAmb=&cDest=&dhEmi=<hex>&vNF=&vICMS=&digVal=<hex>&cIdToken=<6 dígitos com zeros>&cHashQRCode=<sha1 hex 40>`
- QR CF-e-SAT (NÃO é URL): `<chave44>|<AAAAMMDDHHMMSS>|<vCFe>|<CPF_ou_CNPJ_ou_vazio>|<assinaturaQRCODE_base64_344>`
- Hash v2 ONLINE = SHA1(bytes UTF-8 de 'chave|2|tpAmb|idCSC' + CSC).hexdigest().upper() → 40 chars. Verificado: 'DC6AE2C2B9A992BE59679AC365E29922DE6B7511'
- Hash v2 OFFLINE = SHA1('chave|2|tpAmb|DD|vNF|digValHex|idCSC' + CSC).hexdigest().upper(). Verificado: '4615A93BB0D7C4E780F8D30EE77EDD5BA55C7D66'
- digVal (v2 offline) = DigestValue base64 do XML convertido para hex ASCII: 'yzGYhUx1/XYYzksWB+fPR3Qc50c=' (28 chars) → '797a4759685578312f5859597a6b7357422b6650523351633530633d' (56 chars)
- Tamanhos de campo: chave 44*; versão QR 1*; tpAmb 1*; DD 2*; vNF ≤15 (ponto decimal, sem milhar); digVal 56*; idCSC 1–6 (sem zeros à esquerda); hash 40*; CSC 16–36 alfanum; assinaturaQRCODE SAT 344; assinatura QR v3 = RSA-SHA1 Base64 (≈344 p/ 2048 bits). (* = exato)
- XML grupo ZX: ZX01 infNFeSupl (0-1) / ZX02 qrCode (C, 1-1, 60–1000 chars após NT 2025.001 v1.01; era 100–600) / ZX03 urlChave (C, 1-1, 21–85 chars)
- Símbolo QR NFC-e: ISO/IEC 18004, UTF-8, correção de erro nível M, mínimo 25 mm × 25 mm (22 mm de conteúdo + 3 mm de quiet zone; acima de 25 mm usar margem de 10%)
- Símbolo QR CF-e-SAT: ISO 18004, UTF-8, correção de erro nível L, mínimo 4 cm × 4 cm (3 cm × 3 cm facultativo desde 01.01.2019), margem ≥0,5 cm
- Papel do DANFE NFC-e: largura mínima 56 mm, margens laterais ≥2 mm, legibilidade garantida ≥6 meses, proibida impressão em ECF
- Limiar de identificação obrigatória do consumidor no DANFE: R$ 10.000,00 (a UF pode definir valor MENOR); sempre obrigatório em entrega em domicílio (nome + endereço)
- tpAmb: 1 = Produção, 2 = Homologação. mod: 55 = NF-e, 59 = CF-e-SAT, 65 = NFC-e. tpIdDest (v3): 1=CNPJ, 2=CPF, 3=idEstrangeiro
- cUF (IBGE): 11 RO, 12 AC, 13 AM, 14 RR, 15 PA, 16 AP, 17 TO, 21 MA, 22 PI, 23 CE, 24 RN, 25 PB, 26 PE, 27 AL, 28 SE, 29 BA, 31 MG, 32 ES, 33 RJ, 35 SP, 41 PR, 42 SC, 43 RS, 50 MS, 51 MT, 52 GO, 53 DF
- Documentos-fonte: Manual de Especificações Técnicas do DANFE NFC-e e QR Code v6.0 (março/2025, cobre QR v2.00 e v3.00); MOC 7.0 – Visão Geral (16/12/2020); NT 2015.002 (grupo ZX); NT 2016.002 (troco); NT 2017.001 e NT 2021.003 (GTIN/CCG); NT 2018.001 (chave natural, emitente CPF); NT 2025.001 v1.01 (junho/2025, QR v3 — teste até 02/06/2025, produção até 01/09/2025); Especificação Técnica SAT ER 2.29.04 (23/12/2021); Manual de Orientação AC-SAT MO 2.19.04 (14/04/2023)
- NFeDistribuicaoDFe: certificado ICP-Brasil A1/A3 (e-CNPJ OID 2.16.76.1.3.3 ou e-CPF OID 2.16.76.1.3.1); lote máximo 50 documentos; retenção 90 dias; cStat 137 = nenhum documento, 138 = documento localizado; rejeição 656 = Consumo Indevido
- Flutter (local 3.44.7 / Dart 3.12.2): mobile_scanner 7.4.0 (sdk ^3.7.0, flutter >=3.29.0) — compatível. Alternativas: google_mlkit_barcode_scanning 0.15.0, flutter_zxing 2.3.0
- Python: erpbrasil.edoc 3.1.1, PyNFe 0.6.5, brutils 2.5.0 (validação CPF/CNPJ), python-barcode 0.16.1
- Endpoint público não-documentado observado: GET https://menorpreco.notaparana.pr.gov.br/api/v1/produtos?local=<lat>,<lon>&termo=<str>&raio=<km>&offset=<int> → JSON {tempo, local, produtos:[{id, local, desc, ncm, cdanp, valor_desconto, valor_tabela, valor, datahora, tempo, distkm, gtin, nrdoc, estabelecimento:{codigo, nm_fan, nm_emp, tp_logr, nm_logr, nr_logr, complemento, bairro, mun, uf, mesoreg, microreg}}]}
- Portal Nacional consulta resumida (com reCAPTCHA, sem certificado): https://www.nfe.fazenda.gov.br/portal/consultaRecaptcha.aspx?tipoConsulta=resumo
- Tabelas oficiais de URL por UF: QR Code → http://nfce.encat.org/desenvolvedor/qrcode/ ; consulta por chave → Portal Nacional NFC-e, seção Consumidor > Consulte sua Nota (http://nfce.encat.org/)

## RECOMENDACOES
- Trate o QR Code como IDENTIFICADOR, não como conteúdo. Pipeline: QR → chave 44 → valida DV mod 11 → deriva UF (chave[0:2]), AAMM (chave[2:6]), CNPJ emitente (chave[6:20]), modelo (chave[20:22]) → esses 4 metadados já permitem deduplicar, geolocalizar a loja (via CNPJ) e datar a compra ANTES de qualquer OCR.
- Escreva UM parser tolerante que aceite os 4 formatos: (a) v2/v3 NFC-e — extrai o valor do parâmetro `p` e faz split por `|` (aceitar tanto `|` cru quanto `%7C`); (b) v1.00 NFC-e — parse de query string com `chNFe=`; (c) CF-e-SAT — string sem `http`, split por `|` em 5 campos, campo[0] pode vir com prefixo `CFe`; (d) fallback universal — regex `(?<!\d)\d{44}(?!\d)` sobre o payload bruto. Determine a versão pelo campo 2 do split (`1`/`2`/`3`) e NÃO pelo domínio.
- Faça o backend armazenar o payload BRUTO do QR (raw_qr text) além dos campos parseados. Formatos mudam (v1→v2 em 2018, v2→v3 em 2025) e você vai querer reprocessar histórico sem pedir novo scan ao usuário.
- Modele a chave natural, não a chave de acesso, como unique constraint de nota: UNIQUE(cuf, cnpj_emitente, modelo, serie, nnf, tpemis). A chave de 44 dígitos contém cNF aleatório e é frágil para dedupe entre origens (QR vs OCR com erro de dígito).
- Obtenha os ITENS por OCR do DANFE fotografado, não por consulta à SEFAZ. Modele o extrator sobre as 9 divisões do Manual v6.0: âncore o bloco de itens entre a linha de cabeçalho de colunas (Código/Descrição/Qtde/UN/Vl Unit/Vl Total) e a linha 'Qtde. Total de Itens' ou 'Valor total R$'. Use o cruzamento aritmético qCom × vUnCom = vProd e Σ vProd = vNF como validação automática de OCR (rejeite a extração se o erro > R$ 0,02).
- Trate decimais brasileiros no OCR: vírgula decimal e ponto de milhar (regra explícita do manual). Já no QR (v2/v3 offline) o vNF vem com PONTO decimal e sem milhar. São convenções OPOSTAS no mesmo documento — normalize em camadas separadas.
- Aceite e priorize o upload de XML pelo usuário. O manual estabelece que o emitente é obrigado a fornecer o XML ao consumidor se este solicitar ANTES de iniciada a emissão. XML dá GTIN (cEAN/cEANTrib), NCM, CFOP, CST e valores exatos — elimina o OCR e resolve a normalização de produto.
- Para normalização de produtos sem GTIN, adote chave composta (cnpj_emitente_raiz8, cProd) como identidade estável dentro de uma rede, e faça o cross-rede por embedding/fuzzy de xProd + NCM + faixa de preço. Não tente casar descrições de redes diferentes só por string.
- Para reduzir OCR ruim, oriente o app a capturar o DANFE inteiro em uma foto e o QR em outra (ou detecte ambos no mesmo frame com mobile_scanner 7.4.0). O QR corrige a identidade da nota mesmo quando o OCR dos itens degrada.
- Se quiser dados de preço em escala legitimamente, o caminho é institucional: (1) pedido formal via LAI (Lei 12.527/2011) à SEFAZ da UF alvo; (2) convênio/termo de cooperação com SEFAZ ou com o ENCAT (que coordena o Menor Preço Brasil); (3) parceria direta com redes de supermercado para receber encartes/catálogos. Orce isso como trabalho jurídico-comercial, não de engenharia.
- Para encartes: baixe apenas o que o site do varejista permita (respeite robots.txt e ToS de cada domínio, verifique caso a caso e registre a verificação em código/config), prefira feeds/catálogos oficiais e negocie autorização. Guarde a evidência (data, robots.txt lido, ToS) por domínio.
- Instrumente o classificador de documento antes do parser: NFC-e (contém 'Documento Auxiliar da Nota Fiscal de Consumidor Eletrônica' + chave 44 em 11 blocos de 4 + 'Protocolo de autorização'), CF-e-SAT (contém 'CUPOM FISCAL ELETRÔNICO - SAT' + 'No. Série do SAT'), NF-e/DANFE (retrato A4, 'DANFE', campos de destinatário/transportadora), comprovante TEF/POS (NSU, bandeira, últimos 4 dígitos do cartão, 'VIA CLIENTE', SEM chave de 44 dígitos), ECF legado ('CUPOM FISCAL', 'COO', 'ECF'). Só os três primeiros geram preços confiáveis.
- Instale o pipeline em Python com erpbrasil.edoc 3.1.1 se e quando você tiver certificado ICP-Brasil próprio (útil para os documentos onde a SUA empresa é participante, ex.: compras B2B). Não é solução para dados de terceiros.
- Guarde a data-hora de emissão do cupom (dhEmi) e não a data do upload. Preço de supermercado é série temporal; um cupom de 3 semanas atrás não vale como preço 'de hoje'. Defina TTL de validade de preço (sugestão: 7 dias para exibir como 'atual', 30 dias como 'histórico').

## NAO FAZER
- NÃO implemente scraping, headless browser, solver de CAPTCHA ou rotação de proxy/IP contra as páginas de consulta pública das SEFAZ. Confirmado hoje: RS=hCaptcha, SP/MG=reCAPTCHA, SC=Turnstile, GO=403 WAF, RJ=bloqueio por reputação de IP, Portal Nacional=reCAPTCHA. Contornar qualquer um deles está fora do escopo permitido e é o mecanismo explícito de controle de acesso das administrações tributárias.
- NÃO assuma que o QR Code traz os itens. Nenhuma versão (1.00, 2.00, 3.00) nem o CF-e-SAT carregam produto, quantidade ou preço unitário. O único valor monetário no QR é vNF, e só em contingência offline. Qualquer plano de produto baseado em 'ler o QR e ter a lista de compras' está errado na premissa.
- NÃO faça hardcode da URL de consulta por UF nem derive a UF a partir do domínio lido no QR. Derive de chave[0:2] e mantenha a tabela ENCAT em configuração versionada com data de vigência (várias UFs têm URL antiga e nova convivendo com datas de corte).
- NÃO use as chaves de exemplo do Manual do QR Code (2817080015622500013165011000015134156204082 4 / ...9562040824) como test vector de dígito verificador — verifiquei e o DV delas é inválido (calculado 8 e 3, informado 4 nas duas). Use o exemplo do MOC 7.0 (soma 644 → DV 5) e a chave real de CF-e-SAT 35111202767579000148598583801050151865833992 (DV 2).
- NÃO trate NFC-e e CF-e-SAT com o mesmo parser de chave: as posições após o modelo divergem (NFC-e: serie 3 + nNF 9 + tpEmis 1 + cNF 8; SAT: nserieSAT 9 + nCF 6 + cNF 6). Extrair 'série' e 'número' com offsets de NF-e em uma chave modelo 59 produz lixo silencioso.
- NÃO tente validar autenticidade do cupom recalculando o cHashQRCode. Você não tem e não pode ter o CSC do emitente (16–36 chars, segredo entre SEFAZ e contribuinte). Não construa feature de 'cupom verificado' sobre isso.
- NÃO conte com o web service NFeDistribuicaoDFe como fonte de dados de terceiros: ele só devolve documentos em que o portador do certificado é destinatário, transportador ou terceiro autorizado (autXML), retém 90 dias e devolve no máximo 50 documentos por chamada. Usar em loop dispara rejeição 656 'Consumo Indevido' com possibilidade de penalidade estadual.
- NÃO conte com GTIN vindo do DANFE impresso. cEAN/cEANTrib existem no XML e são validados contra o CCG, mas o layout obrigatório de impressão exige apenas cProd (código interno da loja), xProd, qCom, uCom, vUnCom e vProd. Planejar a normalização de produtos pressupondo código de barras no cupom é furado.
- NÃO construa a arquitetura assumindo 'NFC-e é sempre para CPF'. A vedação de destinatário CNPJ foi instituída, adiada três vezes e, segundo fontes secundárias, revogada pelo Ajuste SINIEF 12/2026 — não confirmei o texto oficial. Aceite CPF, CNPJ e idEstrangeiro no campo destinatário.
- NÃO trate a API do menorpreco.notaparana.pr.gov.br como 'dado aberto oficial'. Ela responde 200 sem auth e o site não tem robots.txt, mas não há ToS de API publicado. Fazer disso uma dependência de produção sem autorização formal é risco jurídico e de disponibilidade.
- NÃO use o portal nacional (nfe.fazenda.gov.br) para consultar NFC-e modelo 65 — a consulta do consumidor é no portal da UF emitente e há mensagem de erro padronizada (247) exatamente para chave de UF divergente.

## RISCOS
- Ilegalidade/bloqueio: raspar as páginas de consulta pública das UFs implica contornar hCaptcha (RS), reCAPTCHA (SP, MG, Portal Nacional), Cloudflare Turnstile (SC), WAF (GO) e bloqueio por reputação de IP (RJ). Isso é vedado pelo escopo do projeto, viola ToS e expõe a empresa a responsabilização. Confirmado por teste HTTP em 2026-07-22.
- O cHashQRCode (v2) só é verificável com o CSC do contribuinte, que é segredo compartilhado entre a SEFAZ e o emitente. O app NUNCA poderá validar autenticidade do cupom pelo QR — só pode validar o DV da chave e a coerência aritmética. Fraude por QR forjado é possível: um QR gerado com chave sintática válida passa na sua validação local.
- Ataque de envenenamento de dados: como qualquer usuário pode enviar foto/QR, um concorrente pode injetar preços falsos. Sem validação na SEFAZ, você precisa de defesa estatística (mediana por (produto, loja, janela), reputação de usuário, rejeição de outliers > k·MAD) e não criptográfica.
- LGPD: DANFE NFC-e pode conter CPF do consumidor e, em entrega em domicílio, nome e endereço completo obrigatórios. Fotos de cupons são dado pessoal. Precisa de base legal, minimização (descartar/mascarar CPF na ingestão), retenção definida e DPIA.
- Volatilidade regulatória alta: as URLs de consulta por UF mudaram em 2022 (MG), 2023/24 (RJ), 2025 (GO) e 2026 (RN); o leiaute do QR mudou em 2018 (v1→v2) e 2025 (v3); o regime de destinatário CNPJ da NFC-e mudou pelo menos 4 vezes entre abril/2025 e abril/2026. Qualquer regra hardcoded vira dívida técnica em meses.
- Coexistência de 3 leiautes de QR em campo simultaneamente (v1 em cupons arquivados, v2 majoritário, v3 crescendo desde 01/09/2025) + CF-e-SAT em SP/CE. Um parser que assuma v2 quebra silenciosamente em v3 (3 campos em vez de 5) e em SAT (não é URL).
- Cobertura geográfica desigual: CF-e-SAT (mod. 59) é o documento do varejo paulista em boa parte dos casos; se o app nascer em SP e assumir NFC-e, perde a maior praça do país. Se nascer no Nordeste (BA/PB/PE), NFC-e cobre bem.
- Dependência de API não documentada (menorpreco.notaparana.pr.gov.br): pode ser bloqueada, rate-limitada ou receber captcha a qualquer momento sem aviso, e sem ToS publicado o uso comercial é juridicamente incerto. Não construa a proposta de valor central em cima disso.
- OCR de bobina térmica é hostil: fonte matricial condensada, desbotamento (o manual só garante legibilidade por 6 meses), amassados, descrições truncadas/abreviadas ('REFRIG COCA 2L PET'). Espere taxa de erro relevante em qCom/vUnCom mesmo com bons modelos.
- DANFE 'resumido/ecológico' é permitido por várias UFs: o cupom pode legalmente NÃO ter os itens impressos. Nesse caso, sobra só a chave + total. Precisa de fluxo de fallback no produto.

## EM ABERTO
- A NFC-e (modelo 65) é distribuída pelo web service NFeDistribuicaoDFe para o CPF do consumidor destinatário? O MOC 7.0 descreve o serviço em termos de NF-e e exige vínculo como destinatário/transportador/terceiro, mas não achei confirmação explícita para o modelo 65. Se FOR, abre um caminho legítimo poderoso: usuário com e-CPF autoriza o app a puxar as próprias notas. Verificar no MOC Anexo I/II e no schema distDFeInt.
- Qual a situação jurídica EXATA em 22/07/2026 da vedação de emissão de NFC-e para destinatário CNPJ? Encontrei referências a Ajuste SINIEF 11/2025 (efeito 03/11/2025), 30/2025 (adia p/ 05/01/2026), 43 ou 44/2025 (adia p/ 04/05/2026) e 12/2026 (revoga). Só fontes secundárias. Buscar o texto oficial em confaz.fazenda.gov.br.
- O que exatamente é o 'DANFE Simplificado – Tipo 2' (Ajustes SINIEF 10/11/12/13 de abril/2026, início citado 03/08/2026) e quais campos ele torna facultativos na impressão? Isso pode invalidar parte do mapa de OCR da Divisão II/III em poucos meses. Buscar o Manual de Especificações Técnicas atualizado (v7.0+) no Portal Nacional.
- Existe versão do Manual de Especificações Técnicas do DANFE NFC-e e QR Code posterior à v6.0 (março/2025)? Confirmei a v6.0; a busca sugeriu que a v5.0/v5.1 ainda estão publicadas em portais estaduais, o que indica desatualização de espelhos. Checar https://www.nfe.fazenda.gov.br/portal/exibirArquivo.aspx?conteudo=8NH4MwSYr6A%3D (não consegui baixar por erro de cadeia de certificados).
- Quais UFs já exigem/aceitam QR v3.00 em produção e qual a fração real do parque emissor que migrou? A NT diz que 'todas as UF irão disponibilizar o layout do qrCode v3', mas a adoção por PJ é opcional. Impacta o peso relativo de cada branch do parser.
- Existe alguma UF com portal de consulta NFC-e SEM CAPTCHA e com termos que permitam consulta programática autorizada? BA, PR, CE e PE não apresentaram marcador de captcha na página inicial nos testes — mas não testei a submissão real com uma chave válida (não tenho uma). Vale um teste manual com cupom real antes de descartar.
- O ENCAT publica dados de preço agregados (não-identificados) sob alguma licença aberta, ou existe base no dados.gov.br derivada de NFC-e? Não localizei. Vale consulta formal ao ENCAT — seria a fonte de escala ideal e legítima para o melhor_mercado.
- Qual o formato de retorno exato da consulta pública das UFs quando bem-sucedida (HTML do DANFE completo, JSON, abas)? O manual diz que deve apresentar 'o DANFE NFC-e completo (com itens de mercadoria)' e opção de visualização por abas, mas cada UF implementa. Irrelevante se não houver acesso autorizado — só investigar após obter convênio.


################################################################
# TOPICO: Prior art e fontes oficiais de preços de supermercado no Brasil (SEFAZ/NFC-e), licenciamento para reuso comercial e concorrentes — insumo de arquitetura para o app "melhor_mercado"
################################################################

## RESUMO EXECUTIVO
Existem SIM fontes oficiais estaduais de preços extraídos de NFC-e, e várias respondem hoje (22/07/2026). Testei os endpoints ao vivo. Porém a conclusão estratégica é o inverso da esperança inicial: quase todas proíbem explicitamente uso comercial, e a única com API pública documentada e programa de parceiros é Alagoas.

Mapa real: (1) PARANÁ — API REST pública, sem autenticação, CORS `*`, respondeu 200 com JSON rico nos meus testes; MAS o Termo de Uso da CELEPAR proíbe literalmente uso comercial, robôs/spiders, aplicações de "Pricing" e "utilizar os serviços da Plataforma em outro aplicativo ou site", com bloqueio por IP/ASN/CPF. Inutilizável legalmente. (2) BAHIA (Preço da Hora) — API interna responde sem token em alguns paths, mas os Termos e Condições (cláusulas 3.1/3.3/3.7) restringem a "uso pessoal e não comercial" e vedam retransmissão. Inutilizável. (3) MENOR PREÇO BRASIL (Procergs/SEFAZ-RS + ENCAT, ~16-21 UFs) — exige login gov.br obrigatório, adotado justamente para barrar raspagem por empresas. Inutilizável. (4) ALAGOAS (Economiza Alagoas) — ÚNICO com API REST pública oficial, manual do desenvolvedor, token por e-mail e uma página de "Parceiros" que convida terceiros a construir apps e sites sobre a API. É o único caminho institucional viável, e cobre só AL.

Não há API nacional agregadora aberta. Não há dataset de preços de NFC-e em nenhum portal dados.xx.gov.br (busquei via CKAN em BA, RS, PE, PB: zero resultados). O dado existe, mas é servido por aplicativo, não como dado aberto licenciado.

Consequência arquitetural: o produto NÃO pode se apoiar em fonte oficial como pilar nacional. O núcleo tem de ser colaborativo (QR Code da NFC-e do próprio usuário, que é documento dele) + encartes com autorização. Alagoas entra como piloto opcional de enriquecimento, mediante token e confirmação escrita sobre uso comercial.

Concorrência direta já existiu e definhou: Economiza Club (Porto Alegre, 2015) fez exatamente "QR Code da nota → base colaborativa" em RS/PR/SP e hoje só responde em HTTP puro, sem HTTPS — sinal de abandono. Isso é ao mesmo tempo validação do modelo e alerta de que o gargalo não é técnico, é densidade de cobertura.

## ACHADOS

### [confirmada] Paraná expõe uma API REST pública sem autenticação que responde hoje, mas cujo Termo de Uso proíbe expressamente uso comercial e uso em outro aplicativo
GET https://menorpreco.notaparana.pr.gov.br/api/v1/produtos?local={lat},{lon}&termo={texto}&raio={km}&offset={n} — testado 22/07/2026: HTTP 200, `content-type: application/json; charset=utf-8`, `access-control-allow-origin: *`, `Server: Apache`, sem token/cookie. Resposta: {tempo, local, produtos[], total, precos:{min,max}}. Cada produto: id, local (geohash, ex '6gkzx9gy6k0'), desc, ncm, cdanp, valor_desconto, valor_tabela, valor, datahora (ISO8601 Z), tempo ('há um dia'), distkm, gtin, nrdoc, estabelecimento{codigo, nm_fan, nm_emp, tp_logr, nm_logr, nr_logr, complemento, bairro, mun, uf, mesoreg, microreg}. 'leite' raio=10 em Curitiba: total=58734, 35-44 itens/página. raio=1..15 OK; raio>=30 deu timeout (>25s). TERMO DE USO (extraído do bundle Angular main.1b9553e267b0dee875f3.bundle.js, titular CELEPAR CNPJ 76.545.011/0001-19): 3.1 'se compromete a NÃO utilizar comercialmente os dados obtidos pela Plataforma'; 1.2 'apenas para fins informativos e de uso próprio, excluindo qualquer utilização comercial ou publicitária'; 3.2 proíbe 'robôs', 'spiders' ou 'agentes automatizados'; 3.2.1 'É vedada também a utilização da Plataforma para aplicações de "Pricing"'; 3.3(c) 'Utilizar da plataforma para obter vantagem comercial'; 3.3(g) 'Utilizar os serviços da Plataforma em outro aplicativo ou site'; 3.2.2 bloqueio 'por IP, ASN, CPF, conta do Google ou Facebook'.
FONTE: https://menorpreco.notaparana.pr.gov.br/termo

### [confirmada] Alagoas é o único estado com API oficial pública documentada e programa formal de parceiros — é a única fonte oficial institucionalmente viável
Página do desenvolvedor (https://economizaalagoas.sefaz.al.gov.br/desenvolvedor.htm, viva, HTTP 200): 'A Secretaria da Fazenda de Alagoas disponibiliza um conjunto de serviços de pesquisa de preços na forma de uma API. Atualmente, somos o único Estado brasileiro a oferecer esse tipo de serviço. Todas os métodos da API são públicos e, atualmente, sem qualquer custo.' Token via e-mail api@sefaz.al.gov.br informando nome completo, CPF e nome do projeto. Contato geral: economizaalagoas@sefaz.al.gov.br. Manual: https://gcs.sefaz.al.gov.br/documentos/visualizarDocumento.action?key=ltOvHx2smR4%3D (redireciona 301 para gcs2.sefaz.al.gov.br; NÃO consegui baixar — retorna 403 de WAF/edge nesta sessão; conteúdo do manual NÃO confirmado). Página /parceria_aplicativos.htm lista apps de terceiros construídos sobre a API (ex.: Dedura Preço, https://dedurapreco.com/, Play Store com.danilo.santos.precocombustivel) e convida: 'A SEFAZ disponibiliza esse espaço para divulgação do portifólio dos aplicativos, sites, ferramentas e trabalhos produzidos por terceiros com o uso de nossa API'.
FONTE: https://economizaalagoas.sefaz.al.gov.br/desenvolvedor.htm

### [confirmada] Especificação técnica da API de Alagoas (endpoint, método, header, corpo e resposta) está documentada em artigo dos próprios auditores da SEFAZ/AL no SBSI 2023
Artigo 'Economiza Alagoas: Plataforma de pesquisa de preços da SEFAZ/AL', Eduardo Calheiros Barbosa e Marcelo Tenório Malta (Superintendência de TI, SEFAZ/AL), Anais Estendidos do XIX SBSI 2023, p.84-86. Endpoint base: http://api.sefaz.al.gov.br/sfz-economiza-alagoas-api/api/public/ — método POST; header obrigatório `AppToken` (fornecido pela SEFAZ no cadastro); body JSON. Path do exemplo (screenshot Postman, Figura 1): /produto/pesquisa. Request: {"produto":{"gtin":"..."},"estabelecimento":{"individual":{"codigoIBGE":2704302}},"dias":7,"pagina":1,"registrosPorPagina":9999}. Response: {totalPaginas, totalRegistros (ex. 27297), pagina, registrosPorPagina, registroCorrente, totalizarPagina, ultimaPagina, conteudo:[{produto:{codigo, descricao, ncm, gtin, unidadeMedida, venda:{dataVenda, valorDeclarado, valorVenda}}, estabelecimento:{cnpj, razaoSocial, nomeFantasia, endereco:{nomeLogradouro, numeroImovel, bairro, cep, codigoIBGE, municipio, latitude, longitude}}}]}. Dois métodos: preços de produtos em geral e preços de combustível. Backend Oracle com materialized view; front web é PWA. Métricas: 7 milhões+ de preços disponíveis, média 417 mil requisições/dia. Testei o endpoint: retorna HTTP 403 (página HTML de erro de WAF, ~13,7 KB, headers X-Frame-Options/X-XSS-Protection/CSP) tanto sem token quanto com token fictício — não consegui distinguir bloqueio de borda de rejeição de token.
FONTE: https://sol.sbc.org.br/index.php/sbsi_estendido/article/view/24590

### [confirmada] Parâmetros operacionais do Economiza Alagoas: janela de atualização de 3 horas e retenção de apenas 10 dias
Do artigo SBSI 2023: 'A janela de atualização dos preços ocorre a cada 3 horas, com um período de retenção de 10 dias, contendo informações do código de barras, da descrição do produto e do último preço praticado pelo estabelecimento.' Página /ajudaEconomizaAlagoas.htm confirma: 'Os preços apresentados refletem o valor SEM DESCONTO e o da ÚLTIMA VENDA realizada pelo estabelecimento no período de até 10 dias e não significa que são ofertas.' Também: 'Cada estabelecimento define e informa sua própria descrição do produto' e 'Caso o estabelecimento não informe o código de barras na NFC-e, o produto poderá ser encontrado apenas pela sua descrição' — ou seja, GTIN é opcional/ausente em parte relevante da base, o que obriga normalização por descrição.
FONTE: https://economizaalagoas.sefaz.al.gov.br/ajudaEconomizaAlagoas.htm

### [confirmada] Os Termos e Condições de Uso do Preço da Hora Bahia restringem o uso a pessoal e não comercial e vedam retransmissão — bloqueio jurídico direto
PDF oficial https://precodahora.ba.gov.br/termos/termosecondicoes.pdf (7 páginas, baixado e extraído). Cláusula 3.1: 'você tem o direito não exclusivo, intransferível, não sub-licenciável e limitado de entrar, acessar e usar os serviços, unicamente para uso pessoal e não comercial.' 3.3: 'Você não tem direitos de cópia ou reprodução no todo ou em parte, de qualquer parte dos serviços da plataforma.' 3.7: 'Você não deve distribuir, intercambiar, modificar, vender ou revender ou retransmitir a qualquer pessoa qualquer parte dos serviços... para qualquer finalidade empresarial comercial ou pública.' 4.9(c): veda 'carga excessivamente pesada... na infraestrutura da plataforma'. Política de privacidade separada em /termos/politicadeprivacidade.pdf (2 páginas).
FONTE: https://precodahora.ba.gov.br/termos/termosecondicoes.pdf

### [confirmada] A API do Preço da Hora Bahia está viva e parte dela responde sem token algum, mas isso não cria licença de uso
Testado 22/07/2026: GET https://api.precodahora.ba.gov.br/v1/produtos → HTTP 200, {"codigo":85,"descricao":"Nenhum produto foi informado!"} (envelope de erro JSON). GET /v1/estabelecimentos → HTTP 200 com dados reais: {"dataConsulta":"2026-07-22 17:36:53.419096","totalRegistros":10,"resultado":[{"cnpj":"58407232000149","estabelecimento":"EVM PREMOLDADOS","razao_social":...}]}. GET /v1/images/{gtin} → PNG binário. POST /v1/produtos → 405. A busca de produtos, porém, exige um token CSRF: a home https://precodahora.ba.gov.br/ traz `<meta id="validate" data-id="ImZhYWY4NmFjMjgxMmMwYzJhMGY3MjdkMDBlY2YyZGQwMDM0MTU1NmIi.amD7kg...">` que os wrappers não oficiais extraem da página. Extrair esse token é contornar mecanismo de proteção — vedado pelo escopo do projeto.
FONTE: https://api.precodahora.ba.gov.br/v1/estabelecimentos

### [confirmada] O Menor Preço Brasil (agregador multiestadual, o mais próximo de uma 'API nacional') tornou login gov.br obrigatório justamente para impedir raspagem por empresas
Desenvolvido por Procergs/SEFAZ-RS em parceria com o ENCAT, com apoio do BID. SEFAZ-ES: a mudança para login gov.br obrigatório ocorreu em 13/11/2020, substituindo o app 'Menor Preço' feito pela Celepar (PR); notícia atribui a exigência à necessidade de 'prevent unauthorized data scraping by companies'. Auditor da Sefaz-RS relatou detecção de empresas raspando dados para inferir hábitos de consumo. Play Store: br.gov.rs.procergs.mpbr; App Store id1483644418. SEF-SC lista 'Login GOV.BR' em 'Requisitos Exigidos do Usuário'. Métricas 2026: 581,6 milhões de NFC-e processadas no ano; 41,7 bilhões de documentos desde o lançamento; 56,6 mil usuários ativos no último mês. Lista de compras (lançada 2024) aceita até 10 itens, raio de até 5 km. NÃO há endpoint público documentado. Não existe API nacional agregadora aberta.
FONTE: https://sefaz.es.gov.br/menor-preco-brasil-passa-ser-unico-aplicativo

### [provavel] Base legal multiestadual do Menor Preço Brasil é um convênio CONFAZ de 2019 que cobre 21 estados + DF
Página oficial do CONFAZ: 'Convênio de Cooperação Técnica nº 03/19', firmado na 174ª reunião do CONFAZ em Recife, com 21 estados + DF listados: AC, AL, AP, AM, BA, CE, ES, MA, MT, MG, PA, PE, PI, RJ, RN, RO, RR, SC, SE, TO + DF. ATENÇÃO — há divergência de data entre fontes: a página do CONFAZ indica 27/09/2019 e outra fonte secundária indica 27/11/2019; não consegui abrir o texto do convênio em si. A adesão formal ao convênio não equivale a operação: em 2025 as fontes da SEFAZ-RS falavam em 16 UFs efetivamente operando (AC, AL, AP, CE, DF, ES, PA, PE, PI, RJ, RN, RO, RR, SE, TO + RS), e SC aderiu depois.
FONTE: https://www.confaz.fazenda.gov.br/noticias-do-confaz/confaz-lanca-aplicativo-menor-preco-brasil-destinado-a-ajudar-o-cidadao-a-encontrar-os-melhores-valores-no-comercio

### [confirmada] NÃO existe dataset de preços de NFC-e em nenhum portal estadual de dados abertos — o dado é servido por app, nunca como dado aberto licenciado
Consultei as APIs CKAN (/api/3/action/package_search) de dados.ba.gov.br, dados.rs.gov.br, dados.pe.gov.br e dados.pb.gov.br com as queries 'preco', 'nfce' e 'nota+fiscal' em 22/07/2026. Resultado: BA count=0 nas três; PE count=0 para preco/nfce e 1 irrelevante ('doacoes-para-o-combate-a-covid-19'); PB count=0; RS count=5 para 'preco' mas todos são séries macroeconômicas do DEE/SPGG (ex. 'dee-2983' = 'Contabilidade Social - Série 1999 a 2001 - Valor Adicionado Bruto a Preços Básicos', licença CC-BY-4.0) — nada de NFC-e. www.dados.pr.gov.br, dados.al.gov.br e dados.df.gov.br responderam 200 mas não expõem CKAN nesse path. dados.mg.gov.br → 403; dados.sp.gov.br e dados.ce.gov.br → sem resposta. Conclusão: a hipótese de ingerir bulk de dado aberto estadual não se sustenta.
FONTE: https://dados.ba.gov.br

### [confirmada] Nenhum dos portais oficiais de preços publica robots.txt — mas a ausência de robots.txt não gera permissão, porque os Termos de Uso governam
Testado 22/07/2026: menorpreco.notaparana.pr.gov.br/robots.txt → 404 JSON {"statusCode":404}; buscapreco.sefaz.am.gov.br/robots.txt → 404 Tomcat 9.0.115; nfg.sefaz.rs.gov.br/robots.txt → 404 IIS 10.0; economizaalagoas.sefaz.al.gov.br/robots.txt → devolve página de login (catch-all); precodahora.ba.gov.br/robots.txt → devolve o shell HTML do SPA (catch-all). Apenas www.notaparana.pr.gov.br tem robots.txt real (padrão Drupal). Ou seja: a restrição efetiva está 100% nos Termos, não em robots.txt.
FONTE: https://menorpreco.notaparana.pr.gov.br/api/v1/produtos

### [confirmada] O Preço da Hora nasceu na Paraíba (TCE-PB + UFPB + Codata) e foi transferido à Bahia por convênio de 16/09/2019 — a mesma base de código roda em dois estados
Texto literal dos Termos da Bahia: 'a partir do Convênio de Cooperação Técnica assinado entre o Governo da Paraíba, o Tribunal de Contas da Paraíba e o Governo do Estado da Bahia em 16/09/2019'. Versão PB: precodahora.pb.gov.br (não resolveu no meu teste), precodahora.tcepb.tc.br (HTTP 403 para acesso programático), precodahora.tce.pb.gov.br (sem resposta). PB: ~739 mil itens, até 121.590 estabelecimentos, 223 municípios, atualização a cada 5 minutos. BA: 417 municípios, 180-200 mil estabelecimentos, 500 mil+ produtos, atualização a cada 5 minutos (preços com defasagem de ~1 hora), 3,2 milhões de NFC-e/dia com picos acima de 4,4 milhões. Operado por SEFAZ-BA + PRODEB.
FONTE: https://precodahora.ba.gov.br/termos/termosecondicoes.pdf

### [confirmada] Os Termos da Bahia revelam o playbook de compliance de sigilo fiscal que o melhor_mercado deve copiar: exclusão de CNAEs voláteis e remoção de PII da descrição do item
Cláusula 2.5 — não são exibidos registros de fornecedores cujo CNAE principal seja: 5611201 (restaurantes), 5620101, 5611202 (bares), 5611203 (lanchonetes), 5620104, 5612100, 5510801 (hotéis), 5590603, 5620103, 5620102 (buffet), 5590699, 5510803 (motéis), 5510802 (apart-hotéis), 5590601 (albergues), 5590602 (campings). Cláusula 2.7 — são removidos da descrição do item antes da exibição: CPF, CNPJ, IMEI, telefone fixo/móvel, chassi de veículo e data de nascimento. Cláusula 2.4 — fontes auxiliares usadas: GTIN, IBGE/CONCLA (Divisão Territorial), cadastro ICMS SEFAZ-BA, códigos de produto da ANP, tabelas NCM (MDIC), geodados do Google Maps, CMED/ANVISA para medicamentos. Isso é diretamente reaproveitável como regra de negócio.
FONTE: https://precodahora.ba.gov.br/termos/termosecondicoes.pdf

### [confirmada] Existem programas equivalentes em RS, AM e PR com parâmetros operacionais distintos, úteis como benchmark de UX
RS — Menor Preço Nota Gaúcha (https://nfg.sefaz.rs.gov.br/site/MenorPreco.aspx, HTTP 200): raio máximo 30 km, padrão 5 km; +200 mil (algumas fontes: 300 mil) estabelecimentos credenciados ao programa NFG; atualização em tempo real na emissão; App Store id1350542444. AM — Busca Preço AM (https://buscapreco.sefaz.am.gov.br/sobre): janela padrão 48 horas, ajustável de 1 a 7 dias; ~700 mil NFC-e/dia; ~20 milhões de itens coletados em uma semana; busca por nome/palavra-chave e leitura de código de barras; App Store id6504370036; sem API nem dado aberto documentado. PR — 60 mil+ estabelecimentos, 3,8 milhões de produtos, +10 milhões de preços atualizados por semana, raio padrão até 20 km no app.
FONTE: https://nfg.sefaz.rs.gov.br/site/duvidas_menor_preco.html

### [confirmada] O concorrente com modelo idêntico ao melhor_mercado (QR Code de NFC-e + base colaborativa) existe desde 2015 e aparenta estar abandonado
Economiza Club — startup de Porto Alegre, origem 2015/2016. Modelo: 'É necessário apenas ler o QR Code da nota/cupom fiscal com o aplicativo e todos os preços dos produtos são cadastrados automaticamente'; registros de compra privados por usuário; cada compra cadastrada alimenta a base coletiva de PDV e produtos; cobertura RS, PR e SP; não exige CPF no cadastro. App Store id1113607971. Sinal de abandono: http://economiza.club/ responde 200 apenas em HTTP puro; https://economiza.club/ falha na conexão (sem TLS válido) — teste de 22/07/2026. É simultaneamente validação do modelo e alerta de que o gargalo é densidade de cobertura, não tecnologia.
FONTE: https://apps.apple.com/br/app/economiza-club/id1113607971

### [confirmada] O mercado brasileiro tem três camadas de concorrentes com modelos de dados distintos, e nenhuma delas usa fonte oficial de NFC-e sob licença
(a) COLABORATIVO POR NFC-e: Economiza Club (RS/PR/SP, aparentemente abandonado); Busca Preço (https://buscapreco.net/, HTTP 200 — 'aponta a câmera do app para o QR code da nota fiscal', histórico por item). (b) ENCARTES/FOLHETOS via parceria com o varejo: ShopFully (https://www.shopfully.com.br/, HTTP 200; adquiriu a espanhola Tiendeo em 2022), Tiendeo (https://www.tiendeo.com.br/, Play Store com.geomobile.tiendeo), Super Panfletos/EconomizeBr (App Store id1074495041), portafolhetos.com.br, catalogosofertas.com.br, seusfolhetos.com.br. Obtêm PDFs/imagens por acordo comercial com as redes, não por raspagem. (c) B2B PRICING: InfoPrice (https://www.infoprice.co/, fundada 2013, +10 bilhões de pontos de preço, +2 milhões de produtos, clientes Carrefour, Via Varejo, Magazine Luiza; produtos ISA-InfoPanel e IPA). Outros menores: CompraMais.app (https://compramais.app/ → HTTP 406), Compara Compra (App Store id1567071081), Super Save Preços (id1622452340), Meus Preços.
FONTE: https://www.infoprice.co/blog/6-sites-apps-para-comparar-precos/

### [provavel] Não existe padrão aberto para encartes de supermercado — são PDFs/imagens sem esquema, distribuídos por acordo comercial
Verifiquei os agregadores existentes (ShopFully, Tiendeo, Super Panfletos, portafolhetos.com.br, catalogosofertas.com.br, seusfolhetos.com.br): todos publicam o encarte como PDF ou imagem paginada, sem qualquer marcação estruturada de item/preço, sem feed, sem schema.org, sem API pública. A obtenção é por parceria com a rede varejista. Não encontrei nenhuma iniciativa de padronização (nem GS1 Brasil, nem ABRAS) para encarte estruturado. Consequência: ingestão de encarte é obrigatoriamente OCR/visão computacional sobre layout livre, e a autorização é contratual, caso a caso, com cada rede.
FONTE: https://www.shopfully.com.br/

### [confirmada] Wrappers não oficiais da API do Preço da Hora existem no GitHub, e todos dependem de extrair o token CSRF da página — são prior art tecnicamente útil e juridicamente inutilizável
Repositórios: igorpereirag/precodahora_api (Java; documenta parâmetros gtin [obrigatório], latitude [obrigatório], longitude [obrigatório], horas, raio, ordenar ex. 'preco.asc', pagina, processo='carregar', totalRegistros=0, totalPaginas=0, pageview='lista'; base inferida https://api.precodahora.ba.gov.br/v1/, imagens em /v1/images/{gtin}); Pedneri1/precodahora-api (Node, README diz literalmente 'API Privada para o Preço da Hora Bahia', expõe client.sugestao({item}) e client.produto({gtin})); danielmark/precodahora. O próprio autor classifica como API PRIVADA. Também existe ypereirars/nfcescrapper (scraper Python de NFC-e). Servem como referência de forma dos dados, não como caminho de integração.
FONTE: https://github.com/igorpereirag/precodahora_api

### [confirmada] O portal do Menor Preço PR NÃO está fora do ar — a mensagem de indisponibilidade é markup morto dentro de comentário HTML
Verificação importante contra falso positivo: o shell HTML de menorpreco.notaparana.pr.gov.br contém o texto 'Portal temporariamente indisponível. Voltaremos assim que possível. Utilize nosso app para continuar economizando.' Inspecionando o HTML cru, esse bloco está DENTRO de um comentário `<!-- ... -->`, após `<script src="libs/scripts.min.js"></script>` — é um banner de manutenção desativado. O site é um SPA Angular (bundles inline/polyfills/scripts/vendor/main .bundle.js) que renderiza no cliente; por isso ferramentas server-side leem só o shell. Snapshots do Wayback de 2021 a 2026 mostram o mesmo comentário. O portal e a API estão operacionais.
FONTE: https://menorpreco.notaparana.pr.gov.br/

### [provavel] O arcabouço federal de dados abertos (LAI + Decreto 8.777/2016) NÃO se aplica automaticamente a esses dados estaduais
Decreto nº 8.777, de 11/05/2016, institui a Política de Dados Abertos do PODER EXECUTIVO FEDERAL — define dado aberto como aquele 'disponibilizado sob licença aberta que permita sua livre utilização, consumo ou cruzamento, limitando-se a creditar a autoria ou a fonte'. Lei 12.527/2011 (LAI) garante acesso à informação. Porém: (a) o Decreto 8.777 alcança o Executivo federal, não SEFAZs estaduais; (b) nenhuma SEFAZ publicou esses preços COMO dado aberto sob licença aberta — publicou como serviço de aplicativo sob Termos de Uso restritivos; (c) o contrapeso é o art. 198 do CTN (Lei 5.172/1966), que veda à Fazenda divulgar informação sobre a situação econômica ou financeira do sujeito passivo. Os programas contornam isso publicando apenas preço/produto/estabelecimento (dado de pessoa jurídica em operação de varejo) e removendo PII da descrição. Não localizei parecer jurídico público consolidando essa tese — trate como inferência.
FONTE: https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2016/decreto/d8777.htm

## ESPECIFICACOES CONCRETAS
- PR (NÃO USAR — termo proíbe) — GET https://menorpreco.notaparana.pr.gov.br/api/v1/produtos?local={lat},{lon}&termo={texto}&raio={km}&offset={n} | sem auth | CORS access-control-allow-origin: * | 200 application/json | ~35-44 itens/página | raio 1-15 km OK, >=30 km timeout >25s | resposta {tempo,local,produtos[],total,precos{min,max}}
- PR campos por item: id, local(geohash 11 chars), desc, ncm(8 díg), cdanp, valor_desconto, valor_tabela, valor, datahora(ISO8601 Z), tempo(humanizado), distkm, gtin(pode ser ""), nrdoc(8 díg), estabelecimento{codigo,nm_fan,nm_emp,tp_logr,nm_logr,nr_logr,complemento,bairro,mun,uf,mesoreg,microreg}
- AL (ÚNICA VIA LEGÍTIMA) — POST http://api.sefaz.al.gov.br/sfz-economiza-alagoas-api/api/public/produto/pesquisa | header AppToken: {uuid} | body {"produto":{"gtin":"..."},"estabelecimento":{"individual":{"codigoIBGE":<7 díg>}},"dias":<int>,"pagina":<int>,"registrosPorPagina":<int>}
- AL resposta: {totalPaginas,totalRegistros,pagina,registrosPorPagina,registroCorrente,totalizarPagina,ultimaPagina,conteudo:[{produto:{codigo,descricao,ncm,gtin,unidadeMedida,venda:{dataVenda,valorDeclarado,valorVenda}},estabelecimento:{cnpj,razaoSocial,nomeFantasia,endereco:{nomeLogradouro,numeroImovel,bairro,cep,codigoIBGE,municipio,latitude,longitude}}}]}
- AL solicitação de token: e-mail api@sefaz.al.gov.br com nome completo + CPF + nome do projeto. Manual: https://gcs.sefaz.al.gov.br/documentos/visualizarDocumento.action?key=ltOvHx2smR4%3D (301 → gcs2.sefaz.al.gov.br; conteúdo NÃO obtido, 403)
- AL parâmetros de dado: atualização a cada 3 h; retenção 10 dias; valor = última venda SEM desconto; 7 mi+ preços; ~417 mil req/dia; 2 métodos (produtos gerais e combustíveis); backend Oracle + materialized view
- BA (NÃO USAR) — https://api.precodahora.ba.gov.br/v1/produtos (envelope de erro {"codigo":85,"descricao":"..."}), /v1/estabelecimentos (retorna cnpj, estabelecimento, razao_social sem token), /v1/images/{gtin} (PNG). Busca de produto exige token CSRF do <meta id="validate" data-id="..."> da home
- BA parâmetros dos wrappers: gtin, latitude, longitude, horas, raio, ordenar=preco.asc, pagina, processo=carregar, totalRegistros=0, totalPaginas=0, pageview=lista
- Janelas de retenção por programa (crítico para modelagem de TTL): AL 10 dias | AM padrão 48 h, ajustável 1-7 dias | Menor Preço Brasil filtro de data até 7 dias | BA/PB atualização a cada 5 min
- Raios suportados nos programas oficiais: RS 1-30 km (padrão 5) | PR até 20 km no app | Menor Preço Brasil até 30 km, lista de compras até 5 km | usar 5 km como padrão de UX e 20 km como teto
- CNAEs a excluir da base de preços (copiado dos Termos BA cl. 2.5): 5611201, 5620101, 5611202, 5611203, 5620104, 5612100, 5510801, 5590603, 5620103, 5620102, 5590699, 5510803, 5510802, 5590601, 5590602
- PII a remover da descrição do item antes de exibir (Termos BA cl. 2.7): CPF, CNPJ, IMEI, telefone fixo/móvel, chassi de veículo, data de nascimento
- Tabelas de referência para normalização (Termos BA cl. 2.4): GTIN, IBGE/CONCLA, cadastro ICMS estadual, códigos de produto ANP (combustíveis), NCM/MDIC, CMED-ANVISA (medicamentos), geodados
- Menor Preço Brasil: Play Store br.gov.rs.procergs.mpbr | App Store id1483644418 | login gov.br OBRIGATÓRIO desde 13/11/2020 | Convênio de Cooperação Técnica CONFAZ nº 03/19 (21 UFs + DF) | 41,7 bi de documentos processados; 581,6 mi em 2026; 56,6 mil MAU
- Portais oficiais vivos em 22/07/2026: precodahora.ba.gov.br (200) | economizaalagoas.sefaz.al.gov.br (200) | menorpreco.notaparana.pr.gov.br/api (200) | nfg.sefaz.rs.gov.br/site/MenorPreco.aspx (200) | buscapreco.sefaz.am.gov.br (200). Fora: precodahora.pb.gov.br (sem resposta), precodahora.tcepb.tc.br (403)
- Concorrentes — status HTTP em 22/07/2026: economiza.club 200 só em HTTP (HTTPS falha) | buscapreco.net 200 | infoprice.co 200 | shopfully.com.br 200 | tiendeo.com.br 200 | compramais.app 406
- Nenhum dataset de NFC-e em CKAN estadual: dados.ba.gov.br count=0, dados.pb.gov.br count=0, dados.pe.gov.br count=0, dados.rs.gov.br só séries DEE/SPGG (CC-BY-4.0, macroeconomia)

## RECOMENDACOES
- Trate o núcleo do produto como 100% colaborativo. O QR Code/chave de acesso da NFC-e pertence ao consumidor que fez a compra; ele pode consultar e contribuir com o próprio cupom. Esse é o único fluxo com base jurídica sólida e cobertura nacional. Nenhuma fonte oficial estadual pode ser o pilar.
- Abra uma única frente institucional: Alagoas. Envie e-mail para api@sefaz.al.gov.br com nome completo, CPF e nome do projeto, e no MESMO e-mail pergunte explicitamente por escrito: (a) o uso é permitido em aplicativo com monetização/fins comerciais? (b) há limite de requisições? (c) qual a atribuição exigida? Guarde a resposta como artefato de compliance. Só integre depois do 'sim' escrito.
- Peça também à SEFAZ-AL o 'Manual de Orientação do Desenvolvedor – versão 1.0' anexado por e-mail, já que o link em gcs.sefaz.al.gov.br devolve 403 para acesso programático. Não modele o cliente HTTP definitivo antes de ler o manual: minha especificação de endpoint vem de artigo acadêmico dos auditores (SBSI 2023), não do manual.
- Replique a solicitação institucional para SEFAZ-BA/PRODEB, SEFAZ-PB/TCE-PB e SEFAZ-AM. O precedente de Alagoas (API pública + página de parceiros) é seu melhor argumento. Convênio, não raspagem: é o caminho que escala e que sobrevive a due diligence de investidor.
- Desenhe a camada de fontes como um driver plugável por UF: interface `PriceSource` com `search(term|gtin, lat, lon, radius_km, days)` e implementações `CollaborativeSource` (default, nacional) e `AlagoasSefazSource` (condicional a token). Guarde `source_id`, `license_ok: bool` e `retention_days` por registro para poder desligar uma fonte por flag sem migração.
- Copie o playbook de compliance da Bahia diretamente para o seu pipeline: exclua os 15 CNAEs de food service/hospedagem listados (preço por refeição polui a base) e faça strip de CPF, CNPJ, IMEI, telefone, chassi e data de nascimento da descrição do item antes de persistir. Isso é regex determinístico, roda no worker de ingestão.
- Modele TTL de preço explicitamente e mostre a idade do dado na UI. Os programas oficiais convergem em 7-10 dias de retenção e o RS/AM destacam que quanto mais recente a nota, maior a chance do preço valer. Preço sem timestamp visível destrói confiança.
- Assuma GTIN ausente como caso comum, não exceção. Nos meus testes no PR, vários itens vieram com `gtin: ""`, e a SEFAZ-AL avisa que sem código de barras o produto só é achável por descrição. A normalização por descrição (fuzzy + NCM + unidade de medida) é caminho crítico do produto, não um refinamento posterior.
- Para encartes, negocie autorização por rede varejista e ofereça contrapartida (destaque, analytics de visualização). É exatamente como ShopFully/Tiendeo operam. Não construa raspador de agregador de encarte: você estaria raspando um concorrente, não uma fonte pública.
- Use os campos do Menor Preço PR e do Economiza Alagoas como referência de esquema para seu próprio modelo de dados (produto/venda/estabelecimento/endereço com lat-lon e codigoIBGE). Copiar a FORMA do dado é livre; copiar o dado não é.
- Adote raio padrão de 5 km e teto de 20 km na busca, alinhado ao consenso dos apps oficiais. E paginação por offset com página de ~40 itens — é o que a infraestrutura estadual comprovadamente suporta.
- Registre desde já no repositório um ADR de 'fontes de dados e licenças', com a citação literal das cláusulas do PR e da BA. Isso protege o projeto quando alguém no futuro sugerir 'só puxar do Preço da Hora'.

## NAO FAZER
- NÃO integre a API do Menor Preço Nota Paraná (menorpreco.notaparana.pr.gov.br/api/v1/produtos), mesmo estando aberta e sem token. O Termo de Uso proíbe nominalmente uso comercial, robôs, aplicações de Pricing e uso dos serviços em outro app ou site. Endpoint aberto não é licença aberta.
- NÃO extraia o token do <meta id="validate"> da home do Preço da Hora para chamar a API de produtos. É contornar mecanismo de proteção — proibido pelo escopo do projeto, além de violar os Termos da SEFAZ-BA.
- NÃO copie os wrappers do GitHub (igorpereirag/precodahora_api, Pedneri1/precodahora-api, danielmark/precodahora) como caminho de integração. Os próprios autores os descrevem como wrappers de 'API Privada'. Use-os no máximo como referência de forma de dados.
- NÃO automatize login gov.br para acessar o Menor Preço Brasil. A exigência de gov.br foi criada especificamente para bloquear raspagem por empresas; automatizá-la é burla de autenticação.
- NÃO interprete a ausência de robots.txt como permissão. Nenhum dos portais oficiais publica robots.txt válido, mas todos os que têm Termos de Uso os têm restritivos. O contrato prevalece.
- NÃO planeje ingestão de dados abertos estaduais de NFC-e. Verifiquei via CKAN em BA, RS, PE e PB: não existe. Qualquer plano de arquitetura que pressuponha esse dataset está construído sobre premissa falsa.
- NÃO prometa 'fonte oficial' no marketing com base apenas em Alagoas. Cobre um estado e depende de token não confirmado para uso comercial. Seria promessa que o produto não sustenta.
- NÃO raspe ShopFully, Tiendeo, portafolhetos.com.br, catalogosofertas.com.br ou seusfolhetos.com.br para obter encartes. São empresas privadas concorrentes, com Termos próprios; o conteúdo delas é licenciado pelas redes varejistas a elas, não a você.
- NÃO trate GTIN como chave primária confiável de produto. Ele vem vazio em parte relevante dos registros oficiais e a própria SEFAZ-AL avisa disso. Um modelo de dados que assuma GTIN sempre presente vai precisar de refactor caro.
- NÃO exponha publicamente o histórico de compras vinculado ao usuário. Além do risco LGPD, o concorrente mais próximo (Economiza Club) tratou histórico como estritamente privado — é o padrão esperado no nicho.
- NÃO escreva o cliente HTTP definitivo da API de Alagoas com base na minha especificação. Ela vem de artigo acadêmico de 2023, não do manual oficial (que não consegui abrir). Valide contra o manual e contra uma resposta 200 real antes de congelar contratos.

## RISCOS
- JURÍDICO CRÍTICO: usar a API do Menor Preço PR viola cláusulas expressas do Termo da CELEPAR — proibição de uso comercial, de agentes automatizados, de aplicações de 'Pricing' e, textualmente, de 'utilizar os serviços da Plataforma em outro aplicativo ou site'. A CELEPAR se reserva bloqueio por IP, ASN e CPF. O fato de a API responder 200 sem token NÃO é permissão.
- JURÍDICO CRÍTICO: usar dados do Preço da Hora Bahia em produto comercial viola as cláusulas 3.1, 3.3 e 3.7 dos Termos e Condições (uso pessoal e não comercial, sem cópia, sem retransmissão para finalidade empresarial).
- JURÍDICO CRÍTICO: o Menor Preço Brasil exige login gov.br justamente como antiraspagem. Automatizar login gov.br para coletar dados seria burla de autenticação — fora do escopo permitido e com exposição penal e reputacional desproporcional.
- DEPENDÊNCIA DE FONTE ÚNICA: se Alagoas for a única fonte oficial, o benefício cobre ~1,6% da população brasileira. Não sustenta posicionamento de 'app com fonte oficial' em escala nacional. Não construa marketing em cima disso.
- API DE ALAGOAS NÃO VALIDADA DE PONTA A PONTA: não consegui nem baixar o manual (403) nem obter resposta do endpoint (403 de WAF, com e sem token fictício). A especificação que forneci vem do artigo SBSI 2023, publicado em 2023 — pode ter mudado. Só considere a integração viável após o token chegar e um GET/POST real retornar 200.
- TERMOS DE USO DE ALAGOAS NÃO LOCALIZADOS: não encontrei documento de licença ou termo que autorize ou proíba uso comercial. A página de parceiros sugere fortemente que é permitido, mas 'sugere' não é licença. Não escreva código de produção contra essa API antes da confirmação escrita.
- VOLATILIDADE INSTITUCIONAL: o PR já migrou de app próprio (Celepar) para Menor Preço Brasil e voltou a operar o próprio; o ES declarou o Menor Preço Brasil como único app oficial. Endpoints estaduais podem ser descontinuados sem aviso nem versionamento. Qualquer integração oficial precisa de circuit breaker e degradação graciosa.
- API NÃO VERSIONADA E SEM SLA: o /api/v1/produtos do PR e o /v1/ da BA são backends internos de app, sem contrato público, sem changelog, sem deprecation policy. Mesmo que fossem legais, quebrariam sem aviso.
- QUALIDADE DO DADO NA ORIGEM: a CELEPAR se isenta em letras maiúsculas da fidedignidade de preços de notas preenchidas sem veracidade, 'inclusive em virtude da simulação de uma compra'. Sua base colaborativa herda esse risco de forma amplificada — é vetor de fraude por lojista ou por usuário. Precisa de detecção de outlier e reputação de contribuinte desde o MVP.
- SIGILO FISCAL (art. 198 do CTN): você agrega dados de compra reais de pessoas físicas. Mesmo lícito, é área sensível; some LGPD (dado de consumo é comportamental). Histórico de compra deve ser privado por padrão, como fez o Economiza Club, e a base pública deve ser agregada e sem vínculo ao CPF.
- MERCADO: o modelo exato já foi tentado (Economiza Club, 2015, RS/PR/SP) e aparenta ter definhado — o site nem mantém HTTPS. O risco dominante é o problema do ovo e da galinha: sem densidade de notas por loja, a resposta 'onde sai mais barato' é ruim, e sem resposta boa não há usuário enviando nota. Estratégia de bootstrap geográfico concentrado é obrigatória.
- CONCORRÊNCIA ASSIMÉTRICA: InfoPrice tem +10 bilhões de pontos de preço e contratos com Carrefour, Via e Magalu; ShopFully/Tiendeo detêm os relacionamentos de encarte com as grandes redes. Entrar por encarte é entrar no terreno mais defendido do mercado.
- ENCARTE SEM PADRÃO: PDFs de layout livre, sem esquema, sem feed. O custo de OCR/visão computacional por encarte é recorrente e não amortiza como uma integração de API. Dimensione isso no orçamento de infraestrutura desde o início.

## EM ABERTO
- A API do Economiza Alagoas permite uso comercial? Não localizei termo de uso, licença ou cláusula alguma. A página de parceiros convida terceiros a desenvolver 'aplicativos, sites e ferramentas', mas isso não é licença. SÓ resolve por e-mail a api@sefaz.al.gov.br com a pergunta explícita.
- Qual o conteúdo real do 'Manual de Orientação do Desenvolvedor – versão 1.0' da SEFAZ-AL? O link (gcs.sefaz.al.gov.br → gcs2) devolve 403 a acesso programático. Endpoints adicionais, limites de paginação, rate limit e política de atribuição permanecem desconhecidos.
- O endpoint de Alagoas ainda é http://api.sefaz.al.gov.br/sfz-economiza-alagoas-api/api/public/ em 2026? A especificação é de artigo de 2023. Recebi 403 de WAF em HTTP e nenhuma resposta em HTTPS — não consegui confirmar se o serviço segue nesse host nem se há TLS.
- Há rate limit numérico na API de Alagoas? O artigo cita 417 mil requisições/dia no agregado e ~300 usuários cadastrados de API, mas nenhum limite por token foi publicado.
- A data exata do Convênio de Cooperação Técnica CONFAZ nº 03/19 é 27/09/2019 (174ª reunião, Recife) ou 27/11/2019? As fontes divergem e não consegui abrir o texto do convênio.
- Quantas UFs operam o Menor Preço Brasil HOJE (jul/2026)? O convênio lista 21 + DF, notícias de 2025 falam em 16 UFs efetivas, e SC aderiu depois. Não achei lista oficial atualizada de 2026.
- O Preço da Hora Paraíba (precodahora.pb.gov.br / precodahora.tcepb.tc.br) continua no ar? Um host não resolveu, o outro deu 403. Não consegui determinar se é bloqueio a acesso programático ou descontinuação.
- SP, MG, GO, MT, MS e MA têm algum portal público de preços de NFC-e? Não encontrei nenhum, e SP notoriamente não aderiu ao Menor Preço Brasil. Não posso afirmar que não existe — apenas que não localizei.
- Existe parecer jurídico público de alguma SEFAZ conciliando a divulgação de preços com o art. 198 do CTN? Seria a peça mais forte para fundamentar pedidos de convênio, mas não localizei.
- Qual o status real do Economiza Club? O domínio responde só em HTTP e o app segue listado na App Store. Não consegui determinar se opera, foi vendido ou está descontinuado — vale checar antes de assumir que o nicho está vago.
- Os apps oficiais (BA, AL, AM) impõem restrição a uso comercial nas lojas de aplicativos além do termo do site? Não revisei os EULAs das versões iOS/Android.
- Existe alguma iniciativa federal em curso (ex.: o app de preços de medicamentos que teria o Preço da Hora Bahia como referência) que possa virar uma fonte nacional legítima? Vi menção em notícia da SEFAZ-BA, mas não consegui confirmar nome, órgão nem status.


################################################################
# TOPICO: Pipeline de OCR + extração estruturada para cupons fiscais brasileiros em bobina térmica (melhor_mercado)
################################################################

## RESUMO EXECUTIVO
Em 2026-07-22 o estado da arte para cupom térmico degradado NÃO é mais "OCR clássico + regex". A recomendação central é um pipeline híbrido de 3 estágios: (1) pré-processamento OpenCV determinístico no backend (four-point transform → deskew → correção de iluminação → binarização/upscale) com gate de qualidade no app antes do upload; (2) OCR de layout com PaddleOCR 3.7 / PP-OCRv6 (auto-hospedado, CPU-viável via ONNX/OpenVINO) OU um provedor gerenciado; (3) extração estruturada por LLM multimodal com JSON Schema forçado, recebendo imagem + texto OCR + bounding boxes juntos. Tesseract 5.5.x é o pior candidato aqui: seu LSTM assume linhas contínuas e falha em fonte matricial descontínua e papel desbotado (relatos de ~60% de acurácia de caractere em cupom térmico). Para pt-BR entre gerenciados: AWS Textract AnalyzeExpense (US$10/1k páginas, PT suportado, retorna line items ITEM/QUANTITY/PRICE com confiança 0-100) e Azure prebuilt-receipt v4.0 (US$10/1k, tabela explícita de "thermal receipts" incluindo `pt`, retorna Items[].Description/Quantity/Price/TotalPrice) são os mais aderentes; Google Document AI Expense Parser custa o mesmo (US$0.10/10 páginas) mas a otimização declarada é EN/FR/NL/JA — pt-BR não confirmado. Custo por documento com LLM multimodal fica ~1-2 ordens de grandeza ABAIXO dos parsers de recibo (estimativa: Gemini 3.5 Flash-Lite ~US$0.005/cupom vs US$0.010 do AnalyzeExpense), o que inverte a lógica econômica clássica. O diferencial competitivo real do melhor_mercado não está no OCR e sim na (a) reconciliação aritmética (qtde×unit−desc=total; Σitens=subtotal) usada como sinal de confiança auto-supervisionado e (b) arquitetura port/adapter com medição de taxa de erro por provedor. Não existe dataset público de cupom fiscal brasileiro com anotação de line items — isso precisa ser construído (o gold set interno é ativo estratégico). Nada no pipeline exige burlar CAPTCHA/robots.txt: o QR Code da NFC-e é dado entregue ao próprio consumidor.

## ACHADOS

### [confirmada] PaddleOCR 3.7.0 é a versão atual e traz PP-OCRv6 como modelo padrão; PP-OCRv5 não é mais o topo de linha
Release v3.7.0 em 2026-06-11 (PyPI `paddleocr==3.7.0`, requires_python >=3.8, depende de `paddlex[ocr-core]>=3.7.0,<3.8.0`). PP-OCRv6 em 3 tiers: tiny 1.5M params (det Hmean 80.6 / rec 73.5), small 7.7M (84.1 / 81.3), medium 34.5M (86.2 / 83.2). Medium supera PP-OCRv5_server em +4.6pp detecção e +5.1pp reconhecimento. Suporta 50 idiomas em modelo único (chinês simpl./trad., inglês, japonês + 46 de escrita latina — português incluído no grupo latino). Releases anteriores: 3.6.0 (2026-05-28, PaddleOCR-VL-1.6), 3.5.0 (2026-04-21, PaddleOCR.js browser SDK), 3.4.0 (2026-01-29), 3.3.0 (2025-10-16, PaddleOCR-VL-0.9B).
FONTE: https://github.com/PaddlePaddle/PaddleOCR/releases

### [confirmada] PP-OCRv6 é 5.2× mais rápido em CPU com OpenVINO — viabiliza OCR self-hosted sem GPU
PP-OCRv6_medium: 1.40s vs 7.30s do PP-OCRv5_server em Intel Xeon + OpenVINO. PP-OCRv6_tiny: 0.20s vs 0.78s (3.9×). Em NVIDIA V100 + ONNX Runtime: medium 0.67s vs 0.77s do v5_server. Não confirmei consumo de RAM/VRAM por modelo — a documentação oficial não publica esse número. Inferência: com 34.5M params em fp32, o modelo medium ocupa ~140MB de pesos; um worker CPU com 2 vCPU/2GB RAM é suficiente para 1 cupom por vez (INFERÊNCIA MINHA, não confirmada).
FONTE: https://huggingface.co/blog/PaddlePaddle/pp-ocrv6

### [confirmada] Português no PaddleOCR PP-OCRv5 usa o pacote de reconhecimento latino compartilhado
Modelo `latin_PP-OCRv5_mobile_rec` cobre 45+ idiomas de escrita latina incluindo português explicitamente. Seleção via construtor: `PaddleOCR(lang="pt")`. Outros packs: `korean_`, `eslav_`, `th_`, `el_`, `en_`, `cyrillic_`, `arabic_`, `devanagari_`, `ta_`, `te_`. A documentação NÃO publica tamanhos de arquivo em MB desses modelos. No PP-OCRv6 o modelo é unificado (50 idiomas em um só), eliminando a escolha de pack.
FONTE: http://www.paddleocr.ai/main/en/version3.x/algorithm/PP-OCRv5/PP-OCRv5_multi_languages.html

### [provavel] Tesseract 5.x é a escolha errada para bobina térmica — falha estrutural, não de tuning
Última estável 5.5.1 (2025-05-25); há indicação de 5.5.2 (dezembro) que NÃO consegui confirmar em fonte primária. O motor LSTM trata a linha de texto como sequência contínua, premissa quebrada por fonte matricial (caracteres com descontinuidades inerentes ao processo de impressão por pontos) e por fade térmico. Relato de campo citado: equipe processando 40.000 recibos/mês (impressões térmicas de supermercado alemão) com piso de ~60% de acurácia de caractere. Comunidade reporta que só melhora com `--psm 8` (palavra única) após segmentar linhas manualmente — inviável para 40+ itens.
FONTE: https://github.com/tesseract-ocr/tesseract/releases

### [confirmada] EasyOCR está estagnado desde 2024 — descartar para projeto novo
Última release PyPI `easyocr==1.7.2` em 2024-09-24, sem `requires_python` declarado. 80+ idiomas. Em 2026 está ~2 anos atrás do PP-OCRv6/Surya em acurácia e em manutenção.
FONTE: https://pypi.org/pypi/easyocr/json

### [confirmada] Surya 0.17.1 é a alternativa Apache-2.0 mais forte mas exige GPU para throughput
`surya-ocr==0.17.1` (2026-01-30), Apache-2.0, Python >=3.10,<4.0. OCR + layout + reading order + table recognition em 90+ idiomas. Benchmark reportado: 87.2% médio em 91 idiomas; espanhol 90.7%, italiano 93.0%, inglês 92.3% (português NÃO listado nos números divulgados). Throughput: ~5.35 páginas/s em RTX 5090 32GB com concorrência 128; ~0.108 páginas/s em Apple Silicon com 8 processos. Faz auto-spawn de servidor de inferência (vllm ou llama.cpp) no primeiro uso — isso é um custo operacional relevante em Docker Compose.
FONTE: https://pypi.org/pypi/surya-ocr/json

### [confirmada] RapidOCR 3.9.2 é o wrapper multi-backend mais adequado para deploy CPU em container
`rapidocr==3.9.2` publicado em 2026-07-21 (ontem, em relação a hoje) — projeto muito ativo. Python >=3.8,<4.0. Backends: ONNX Runtime, OpenVINO, Paddle, PyTorch. Serve modelos PP-OCR sem trazer a dependência pesada do PaddlePaddle — é a via prática para rodar PP-OCRv5/v6 em imagem Docker slim.
FONTE: https://pypi.org/pypi/rapidocr/json

### [confirmada] docTR 1.0.1 é maduro mas menos competitivo em documento degradado
`python-doctr==1.0.1` (2026-02-04), Apache-2.0, Python >=3.10,<4.0. Pipeline de 2 estágios (detecção + reconhecimento) sobre PyTorch/TF. Bom para documento limpo e para pipelines onde se quer treinar o reconhecedor no próprio domínio (fine-tune em cupom térmico brasileiro seria viável). Não vi benchmark público dele em recibo térmico.
FONTE: https://pypi.org/pypi/python-doctr/json

### [provavel] A geração VLM-OCR (PaddleOCR-VL, dots.ocr, MinerU2.5, olmOCR, DeepSeek-OCR) domina os benchmarks de 2026, mas com números auto-reportados
OmniDocBench v1.6: PaddleOCR-VL-1.6 composite 96.33; MinerU2.5-Pro 95.69 — ambos auto-reportados pelo fornecedor, não reproduzidos de forma independente. Para layouts bagunçados e manuscrito, olmOCR e modelos classe Qwen2.5-VL são citados como melhores, ao custo de mais compute. Houve correção de benchmark em maio/2026 que mudou scores de tabela de dots.ocr 1.5, GLM-OCR, PaddleOCR-VL-1.6 e outros. TRATAR ESSES NÚMEROS COMO MARKETING até validar no gold set próprio.
FONTE: https://github.com/opendatalab/OmniDocBench

### [confirmada] AWS Textract suporta português nativamente e AnalyzeExpense retorna line items estruturados com confiança por campo
Idiomas de detecção de texto: inglês, francês, alemão, italiano, PORTUGUÊS e espanhol (Queries só em inglês; manuscrito só em inglês). Estrutura de resposta: `ExpenseDocuments[]` → `SummaryFields[]` + `LineItemGroups[]` → `LineItems[]` → `LineItemExpenseFields[]`. Cada campo tem `Type` (normalizado), `LabelDetection` (opcional, só quando o rótulo está impresso) e `ValueDetection`, cada um com `Confidence` (0-100) e `Geometry` (BoundingBox + Polygon). Tipos normalizados de line item: ITEM, QUANTITY, PRICE; texto extra da linha (SKU, descrição longa) vem como EXPENSE_ROW com o texto bruto da linha inteira. `ExpenseGroupProperties` distingue VENDOR_REMIT_TO / RECEIVER_SHIP_TO / RECEIVER_SOLD_TO / RECEIVER_BILL_TO / VENDOR_SUPPLIER. Também retorna `Block` objects (mesmo output do DetectDocumentText).
FONTE: https://docs.aws.amazon.com/textract/latest/dg/expensedocuments.html

### [confirmada] Preços AWS Textract (us-west-2, 2026-07-22) confirmados na página oficial
DetectDocumentText: US$1.50/1.000 páginas (primeiro 1M/mês), US$0.60/1.000 acima. AnalyzeExpense: US$10.00/1.000 páginas (primeiro 1M/mês), US$8.00/1.000 acima. AnalyzeDocument Tables US$15/1k; Forms US$50/1k; Queries US$15/1k; Layout incluso. Free tier (3 meses, conta nova): AnalyzeExpense 100 páginas/mês; DetectDocumentText 1.000 páginas/mês.
FONTE: https://aws.amazon.com/textract/pricing/

### [confirmada] Limites duros do Textract que impactam o design de upload
Formatos: JPEG, PNG, PDF, TIFF (JPEG2000 dentro de PDF ok; XFA não suportado). Síncrono: 10MB em memória; PDF/TIFF limitado a 1 página. Assíncrono: JPEG/PNG 10MB; PDF/TIFF 500MB e 3.000 páginas. Resolução máxima 10.000 px em qualquer lado. Altura mínima de texto detectável: 15 px (equivale a fonte 8pt a 150 DPI). Rotação in-plane de qualquer ângulo suportada; texto vertical NÃO suportado. PDF: máx 40 polegadas / 9000 pontos, sem senha.
FONTE: https://docs.aws.amazon.com/textract/latest/dg/limits-document.html

### [confirmada] Azure prebuilt-receipt v4.0 é o único gerenciado que documenta explicitamente 'thermal receipts' com português na lista
Model ID `prebuilt-receipt`, API v4.0 GA (versão `2024-11-30`). A tabela de idiomas tem uma aba dedicada 'Thermal receipts' com ~110 idiomas, incluindo Portuguese (`pt`). (A aba 'Hotel receipts' é restrita a en-US, fr-FR, de-DE, it-IT, ja-JP, pt-PT, es-ES — não confundir.) Campos: `Items[]` com Description (renomeado de Name na v2022-06-30), Quantity, Price (unitário), TotalPrice; além de Total, Subtotal, TotalTax (renomeado de Tax), Tip, TransactionDate (yyyy-mm-dd), TransactionTime (hh-mm-ss 24h), MerchantName/Address/PhoneNumber. v4.0 GA adiciona ReceiptType, TaxDetails.NetAmount/Description/Rate e CountryRegion.
FONTE: https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/language-support/prebuilt

### [confirmada] Limites de input do Azure Document Intelligence v4.0
Formatos prebuilt: PDF, JPEG/JPG, PNG, BMP, TIFF, HEIF (Office só em Read/Layout/classificação). Tamanho de arquivo: 500 MB no tier pago S0, 4 MB no gratuito F0. PDF/TIFF até 2.000 páginas (F0 processa só as 2 primeiras). Dimensões da imagem: mínimo 50×50 px, máximo 10.000×10.000 px. Altura mínima de texto: 12 px numa imagem 1024×768 (~fonte 8pt a 150 DPI). PDFs com senha precisam ser destravados antes.
FONTE: https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/prebuilt/receipt

### [provavel] Preço Azure prebuilt-receipt: US$10 por 1.000 páginas — NÃO confirmado em fonte primária
A página oficial azure.microsoft.com/pricing/details/ai-document-intelligence deu timeout no fetch. Múltiplas fontes secundárias de 2026 convergem em: Read (OCR) US$1.50/1k, Layout US$10/1k, Prebuilt (receipt/invoice/ID) US$10/1k, Custom Extraction US$30/1k (com desconto para US$20/1k acima de 1M/mês). Free tier F0: 500 páginas/mês, processa só as 2 primeiras páginas de cada requisição — serve só para avaliação. VERIFICAR NA PÁGINA OFICIAL ANTES DE FECHAR ORÇAMENTO.
FONTE: https://azure.microsoft.com/en-us/pricing/details/document-intelligence/

### [provavel] Google Document AI: Expense Parser custa o mesmo que os concorrentes, mas suporte a pt-BR não é documentado
Preços oficiais: Enterprise Document OCR US$1.50/1.000 páginas (1–5M/mês), US$0.60/1.000 acima; OCR add-ons US$6/1.000 (flat). Expense Parser (recibo) e Invoice Parser: US$0.10 por 10 páginas = US$10/1.000 páginas. Form Parser US$30/1k (US$20 acima de 1M). Layout Parser US$10/1k. Custom Extractor US$30/1k. Summarizer US$25/1k. Sem free tier declarado. LIMITES: requisição síncrona até 10 páginas; batch até 200 páginas por documento; processadores especializados (Expense/Invoice) limitados a 10 páginas. Sobre idioma: as release notes citam melhorias de qualidade do Expense Parser para inglês, francês, holandês e japonês. Português do Brasil NÃO aparece como idioma otimizado — não confirmei suporte.
FONTE: https://cloud.google.com/document-ai/pricing

### [confirmada] Google Cloud Vision: TEXT_DETECTION e DOCUMENT_TEXT_DETECTION têm o MESMO preço; a diferença é só o modelo
Ambas: primeiras 1.000 unidades/mês grátis; 1.001–5.000.000 US$1.50/1.000 unidades; acima de 5M US$0.60/1.000. 1 unidade = 1 imagem OU 1 página de PDF POR FEATURE aplicada (aplicar as duas features na mesma imagem = 2 unidades). DOCUMENT_TEXT_DETECTION é o modelo denso, explicitamente recomendado para 'documentos escaneados, páginas de livro e RECIBOS' — é o correto para cupom. Não retorna line items estruturados: só texto + hierarquia page/block/paragraph/word/symbol com bounding boxes.
FONTE: https://cloud.google.com/vision/pricing

### [confirmada] Limites e resolução recomendada do Cloud Vision
Arquivo até 20 MB. Imagens de OCR não podem exceder 75 megapixels. Resolução RECOMENDADA para TEXT_DETECTION/DOCUMENT_TEXT_DETECTION: 1024×768 px — abaixo disso a acurácia cai. Para cupom térmico com fonte pequena isso é baixo demais: usar 1600–2400 px no lado longo (INFERÊNCIA MINHA, baseada na altura mínima de caractere exigida pelos outros provedores).
FONTE: https://docs.cloud.google.com/vision/docs/supported-files

### [confirmada] Claude: modelos e preços atuais para extração multimodal com JSON garantido
claude-opus-4-8 US$5/US$25 por MTok (in/out), 1M contexto, 128K output. claude-sonnet-5 US$3/US$15 (promocional US$2/US$10 até 2026-08-31). claude-haiku-4-5 US$1/US$5, 200K contexto. JSON estrito por duas vias: (a) `output_config: {format: {type: "json_schema", schema: {...}}}` no `messages.create()` — o parâmetro antigo `output_format` está deprecado; (b) tool use com `strict: true` no nível da tool (exige `additionalProperties: false` + `required`). Python: `client.messages.parse(..., output_format=PydanticModel)` valida automaticamente. LIMITAÇÕES DO SCHEMA: não suporta schemas recursivos, `minimum`/`maximum`/`multipleOf`, `minLength`/`maxLength`, nem `additionalProperties` diferente de `false` — ou seja, VALIDAÇÃO NUMÉRICA DE PREÇO TEM QUE SER FEITA NO SEU CÓDIGO. Primeira requisição com schema novo paga custo de compilação; cache de schema de 24h.


### [confirmada] Visão de alta resolução no Claude Opus 4.7+ muda a economia de imagem de cupom
Resolução máxima subiu para 2.576 px no lado longo (era 1.568 px até Opus 4.6). Coordenadas retornadas mapeiam 1:1 com pixels reais — não precisa de fator de escala. Custo: até ~4.784 tokens de imagem por imagem em resolução plena (~3× o teto anterior de ~1.600 tokens). Para cupom de bobina longa isso é exatamente o que se quer (fonte de 8pt precisa de resolução), mas encarece: fazer downsample só se a fidelidade não for necessária.


### [confirmada] Prompt caching do Claude não ajuda muito neste caso de uso — o prefixo útil é pequeno
Cache write custa 1.25× (TTL 5min) ou 2× (TTL 1h); cache read custa ~0.1×. Prefixo mínimo cacheável: 4.096 tokens em Opus 4.8/4.7/4.6/Haiku 4.5; 2.048 em Sonnet 4.6/Fable 5; 1.024 em Sonnet 4.5. O system prompt + JSON schema de um extrator de cupom raramente passa de 1.500–2.500 tokens, então NO OPUS ELE SIMPLESMENTE NÃO CACHEIA (falha silenciosa: `cache_creation_input_tokens: 0`). A imagem, que é o grosso do custo, muda a cada documento e é incacheável. Batches API dá 50% de desconto e é a alavanca real para lotes de encartes.


### [confirmada] Gemini é a opção multimodal mais barata por documento em 2026-07-22
Preços pagos por 1M tokens (in/out): Gemini 3.6 Flash US$1.50/US$7.50; Gemini 3.5 Flash US$1.50/US$9.00; Gemini 3.5 Flash-Lite US$0.30/US$2.50; Gemini 3.1 Flash-Lite US$0.25/US$1.50 (texto/imagem/vídeo; áudio US$0.50). Imagem e vídeo são cobrados NA MESMA TARIFA do texto. Context caching US$0.15/1M (Flash) ou US$0.03/1M (Flash-Lite) + US$1.00/hora de armazenamento. Todos com free tier de quota limitada. Suportam structured output com JSON schema e thinking levels (minimal/low/medium/high).
FONTE: https://ai.google.dev/gemini-api/docs/pricing

### [baixa] OpenAI GPT-5.6: preços em fontes secundárias apenas
Família GPT-5.6: Sol US$5/US$30 por 1M tokens (in/out), Terra US$2.50/US$15, Luna US$1/US$6; GPT-5.5 US$5/US$30. Cached input a 10% da tarifa; Batch API com 50% de desconto flat. Structured outputs (`response_format: {type: "json_schema", strict: true}`) e function calling disponíveis em toda a linha. NÃO consegui abrir a página oficial de pricing da OpenAI nesta pesquisa — todos esses números vêm de agregadores de terceiros. VERIFICAR antes de decidir.


### [baixa] Estimativa de custo por cupom: LLM multimodal é 2–20× mais barato que parser de recibo gerenciado
INFERÊNCIA MINHA (aritmética sobre os preços confirmados acima, não medida). Cupom fotografado a 1600×2400 px, JSON de saída com 40 itens ≈ 1.500–2.500 tokens. Claude Opus 4.8: ~4.700 tok imagem × US$5/M + 2.000 tok out × US$25/M ≈ US$0.073/cupom. Claude Sonnet 5: ≈ US$0.044. Claude Haiku 4.5: ≈ US$0.015. Gemini 3.5 Flash-Lite (imagem ~1.550 tok em tiles de 768px): ≈ US$0.0055. AWS AnalyzeExpense: US$0.010 fixo. Azure prebuilt-receipt: US$0.010. Google Expense Parser: US$0.010. Vision DOCUMENT_TEXT_DETECTION (só texto): US$0.0015. Conclusão: OCR barato (Vision/Textract DetectDocumentText/PaddleOCR self-host) + LLM barato (Flash-Lite/Haiku) sai por US$0.006–0.017 e entrega line items melhores que os parsers genéricos em cupom brasileiro.


### [confirmada] OpenCV Stitcher tem modo SCANS (afim) específico para o caso de bobina longa fotografada em partes
`cv.Stitcher.create(cv.Stitcher_SCANS)` usa modelo AFIM (6 DOF ou 4 DOF) via AffineBestOf2NearestMatcher + AffineBasedEstimator + BundleAdjusterAffine/AffinePartial + AffineWarper, em vez da homografia projetiva do modo PANORAMA. É explicitamente o modo para 'câmera transladando' (movimento em trilho, fachada vertical, scans) e é menos propenso a artefato de warp quando a textura é repetitiva — exatamente o caso de uma bobina com muitas linhas paralelas de texto.
FONTE: https://docs.opencv.org/4.x/d5/d48/samples_2python_2stitching_8py-example.html

### [confirmada] Não existe threshold universal de variância do Laplaciano — precisa ser calibrado no próprio dataset
Método: converter para cinza, `cv2.Laplacian(gray, cv2.CV_64F).var()`. O valor é fortemente dependente de RESOLUÇÃO e do dispositivo de captura; a literatura e a prática (PyImageSearch, cvexplained) são unânimes que o corte deve ser calibrado por dataset: coletar algumas dezenas de amostras nítidas e borradas, plotar as duas distribuições e escolher o ponto entre os clusters. O Laplaciano também é muito sensível a ruído — aplicar um blur leve ANTES de medir distorce o valor, então o pipeline de medição precisa ser idêntico ao de calibração.
FONTE: https://pyimagesearch.com/2015/09/07/blur-detection-with-opencv/

### [confirmada] Parâmetros de referência do Sauvola para documento degradado
Sauvola tem 3 hiperparâmetros: `w` (janela quadrada, inteiro ímpar), `k` (nível estimado de degradação) e `R` (faixa dinâmica). Faixa útil de k: [0.2, 0.5]; os autores sugerem k=0.2 e R=125. Sauvola é descrito como adequado a documentos mal iluminados ou manchados — perfil do cupom térmico amassado. Limitação conhecida: exige tuning prévio do tamanho de janela. Disponível em `skimage.filters.threshold_sauvola`. Não encontrei estudo comparativo publicado Sauvola vs adaptive-Gaussian especificamente em papel térmico.
FONTE: https://arxiv.org/pdf/2105.05521

### [provavel] Não existe dataset público de cupom fiscal brasileiro com anotação de itens
Buscas em português e inglês retornaram apenas serviços comerciais (Taggun, BigDataCorp, Escotta, EVT) e um trabalho acadêmico da Mackenzie. O único ativo público próximo encontrado é o dataset HuggingFace `sc0v0ne/BrazilianPortugueseOCR`, que contém imagens de três tipos de documentos brasileiros incluindo NF-e, destinado a OCR — mas NÃO confirmei tamanho, licença, nem se traz anotação de line items. Datasets internacionais utilizáveis como proxy: SROIE (ICDAR 2019, 1.000 recibos anotados, 3 tarefas: localização, OCR, extração de informação-chave), CORD (milhares de recibos indonésios, box-level + 8 superclasses semânticas: Store, Payment, Menu, Subtotal, Total), ReceiptSense (arXiv 2406.04493). NÃO consegui confirmar existência/licença do 'ExpressExpense' como dataset acadêmico nesta pesquisa.
FONTE: https://huggingface.co/datasets/sc0v0ne/BrazilianPortugueseOCR

### [baixa] Ordem correta das operações de pré-processamento (recomendação de engenharia)
INFERÊNCIA MINHA, consolidando prática de visão computacional documental: 1) downscale para ~1000px de lado longo APENAS para detectar contorno (rápido) e guardar o fator de escala; 2) grayscale → bilateralFilter(d=9, sigmaColor=75, sigmaSpace=75) → Canny(50,150) ou threshold adaptativo → findContours → approxPolyDP(epsilon=0.02*perimeter) buscando 4 vértices; 3) four-point transform aplicado na IMAGEM ORIGINAL em resolução plena (nunca na reduzida); 4) deskew fino por minAreaRect sobre pixels de texto OU por transformada de Hough, corrigindo ±15°; 5) correção de iluminação: divisão pelo background estimado com morphологia (cv2.morphologyEx MORPH_CLOSE com kernel elíptico 25×25) ou CLAHE(clipLimit=2.0, tileGridSize=(8,8)); 6) upscale para altura de caractere >= 20-25 px (INTER_CUBIC ou LANCZOS4, ou super-resolução ESPCN/FSRCNN ×2 se disponível); 7) denoise SÓ SE necessário (fastNlMeansDenoising h=7..10) — denoise agressivo apaga fonte matricial fina; 8) binarização por ÚLTIMO e OPCIONAL — PP-OCRv6/VLM funcionam melhor em grayscale corrigido do que em binário. Se binarizar: Sauvola w=25..31, k=0.2, R=128 para papel manchado; adaptiveThreshold GAUSSIAN blockSize=31..41, C=10..15 para iluminação irregular simples.


### [baixa] Reconciliação aritmética é o sinal de confiança mais barato e mais forte do sistema
INFERÊNCIA MINHA (não há fonte publicada com tolerâncias para cupom brasileiro). Regras: (R1) por item: |qCom × vUnCom − vDesc − vProd| <= tol_item; (R2) Σ vProd == vSubtotal; (R3) vSubtotal − Σ descontos + acréscimos == vTotal. Tolerâncias práticas: itens vendidos por peso trazem qCom com 3 (kg) e o layout NF-e admite até 4 casas em qCom e até 10 em vUnCom, com vProd sempre em 2 casas — logo tol_item = max(R$0,02; 0,5 centavo × número de itens do mesmo produto). Para R2 o erro de arredondamento acumula: tol_subtotal = max(R$0,05; n_itens × R$0,01). Se R1 falha para exatamente 1 item, o campo com menor confiança OCR daquele item é o suspeito → resolver algebricamente (ex.: se qtde e unit são confiáveis, recalcular total) em vez de descartar o cupom. Se R2 falha por valor igual ao vProd de um item, provavelmente houve item DUPLICADO ou OMITIDO na leitura — buscar linha faltante entre as bounding boxes.


### [baixa] Confiança por campo: as confianças brutas de OCR são mal calibradas e não devem ir direto para a UI
INFERÊNCIA MINHA. Textract retorna Confidence 0-100 por Type/Label/Value; PaddleOCR retorna score por linha; LLM não retorna confiança nenhuma. Recomendação: definir p_field = sigmoide de uma combinação linear de (a) confiança OCR normalizada, (b) flag de consistência aritmética do item, (c) match do nome do produto contra o catálogo interno/GTIN, (d) plausibilidade do preço vs distribuição histórica daquele produto naquele mercado (z-score), (e) concordância entre provedores quando houver fallback. Calibrar os pesos com regressão logística sobre um gold set anotado à mão (500–1.000 cupons) e VALIDAR com curva de calibração (reliability diagram) + Brier score, não só com acurácia. Só campos com p_field abaixo do corte vão para revisão humana — o corte define diretamente o custo de moderação.


### [confirmada] Restrição legal: nada no pipeline exige burlar proteção — mas há uma armadilha adjacente
O QR Code da NFC-e contém a chave de acesso e é entregue AO PRÓPRIO CONSUMIDOR no cupom; usá-la com consentimento do usuário é legítimo. O que NÃO é legítimo: raspar portais estaduais da SEFAZ em volume, contornar CAPTCHA, reusar sessão autenticada de terceiro ou ignorar robots.txt/termos de uso desses portais para enriquecer dados. Para encartes: importar apenas de fontes que autorizem (feed/API oficial do varejista, PDF publicado abertamente, ou upload manual por administrador). Se a ÚNICA forma de obter um dado for burlando proteção, o dado não entra no produto — a alternativa legítima é (a) parceria/API com o varejista, (b) contribuição colaborativa dos próprios usuários, que é justamente a tese do melhor_mercado.


## ESPECIFICACOES CONCRETAS
- paddleocr==3.7.0 (PyPI, 2026-06-11), requires_python>=3.8, depende de paddlex[ocr-core]>=3.7.0,<3.8.0
- PP-OCRv6: tiny 1.5M params / small 7.7M / medium 34.5M; det Hmean 80.6 / 84.1 / 86.2; rec acc 73.5 / 81.3 / 83.2; 50 idiomas (46 de escrita latina)
- PP-OCRv6_medium: 1.40s por imagem em Intel Xeon + OpenVINO (vs 7.30s do PP-OCRv5_server); 0.67s em NVIDIA V100 + ONNX Runtime
- PP-OCRv5 multilíngue: modelo `latin_PP-OCRv5_mobile_rec` cobre português; seleção via PaddleOCR(lang="pt")
- rapidocr==3.9.2 (2026-07-21), Python >=3.8,<4.0; backends: onnxruntime, openvino, paddle, torch
- surya-ocr==0.17.1 (2026-01-30), Apache-2.0, Python >=3.10,<4.0; 90+ idiomas; 5.35 pág/s em RTX 5090 32GB @ concorrência 128
- python-doctr==1.0.1 (2026-02-04), Apache-2.0, Python >=3.10,<4.0
- easyocr==1.7.2 (2024-09-24) — sem release há ~22 meses
- tesseract 5.5.1 (2025-05-25) estável; indício não confirmado de 5.5.2
- AWS Textract DetectDocumentText: US$1.50/1.000 páginas até 1M/mês, US$0.60/1.000 acima
- AWS Textract AnalyzeExpense: US$10.00/1.000 páginas até 1M/mês, US$8.00/1.000 acima; free tier 100 páginas/mês por 3 meses
- AWS Textract limites: sync 10MB e 1 página (PDF/TIFF); async 500MB e 3.000 páginas; máx 10.000 px por lado; altura mínima de texto 15 px (~8pt @150 DPI); idiomas EN/FR/DE/IT/PT/ES
- AWS AnalyzeExpense JSON: ExpenseDocuments[].{ExpenseIndex, SummaryFields[], LineItemGroups[].LineItems[].LineItemExpenseFields[]}; cada campo tem Type{Text,Confidence}, ValueDetection{Text,Confidence,Geometry{BoundingBox,Polygon}}, LabelDetection opcional
- AWS AnalyzeExpense tipos normalizados de item: ITEM, QUANTITY, PRICE; sobras da linha vêm como EXPENSE_ROW com o texto bruto completo
- AWS ExpenseGroupProperties: VENDOR_REMIT_TO | RECEIVER_SHIP_TO | RECEIVER_SOLD_TO | RECEIVER_BILL_TO | VENDOR_SUPPLIER
- Azure Document Intelligence v4.0 GA, API version 2024-11-30, model id `prebuilt-receipt`
- Azure prebuilt-receipt campos: Items[].{Description, Quantity, Price, TotalPrice}; Total, Subtotal, TotalTax, Tip, TransactionDate (yyyy-mm-dd), TransactionTime (hh-mm-ss 24h), MerchantName/Address/PhoneNumber, ReceiptType, TaxDetails.{NetAmount,Description,Rate}, CountryRegion
- Azure prebuilt-receipt idiomas 'thermal receipts' incluem `pt` (aba separada de 'hotel receipts', que só tem pt-PT)
- Azure input: PDF/JPEG/PNG/BMP/TIFF/HEIF; 500 MB (S0) / 4 MB (F0); até 2.000 páginas; 50×50 a 10.000×10.000 px; altura mínima de texto 12 px em imagem 1024×768
- Azure prebuilt (receipt/invoice/ID): US$10/1.000 páginas; Read US$1.50/1k; Layout US$10/1k; Custom Extraction US$30/1k; F0 grátis 500 páginas/mês (só 2 primeiras páginas) — NÃO confirmado em fonte primária
- Google Document AI Enterprise OCR: US$1.50/1.000 páginas (1–5M/mês), US$0.60/1.000 acima; add-ons US$6/1.000
- Google Document AI Expense Parser e Invoice Parser: US$0.10 por 10 páginas (= US$10/1.000 páginas); máx 10 páginas por documento
- Google Document AI limites: síncrono ≤10 páginas; batch ≤200 páginas por documento; Form Parser US$30/1k; Layout Parser US$10/1k; Custom Extractor US$30/1k; Summarizer US$25/1k; sem free tier
- Google Cloud Vision TEXT_DETECTION e DOCUMENT_TEXT_DETECTION: 1.000 unidades/mês grátis; US$1.50/1.000 (1.001–5M); US$0.60/1.000 acima de 5M; 1 unidade = 1 imagem OU 1 página PDF POR FEATURE
- Google Cloud Vision limites: arquivo ≤20 MB; imagem OCR ≤75 megapixels; resolução recomendada 1024×768 px
- claude-opus-4-8: US$5/US$25 por MTok, 1M contexto, 128K output; claude-sonnet-5: US$3/US$15 (intro US$2/US$10 até 2026-08-31); claude-haiku-4-5: US$1/US$5, 200K contexto
- Claude JSON estrito: output_config={"format":{"type":"json_schema","schema":{...}}} (o parâmetro `output_format` está deprecado); ou tool com strict:true + additionalProperties:false + required completo
- Claude JSON Schema NÃO suporta: schemas recursivos, minimum/maximum/multipleOf, minLength/maxLength, additionalProperties != false
- Claude visão Opus 4.7+: máx 2.576 px no lado longo; até ~4.784 tokens por imagem; coordenadas 1:1 com pixels
- Claude prompt caching: write 1.25× (TTL 5min) / 2× (TTL 1h), read 0.1×; prefixo mínimo 4.096 tokens em Opus 4.8/4.7/4.6 e Haiku 4.5, 2.048 em Sonnet 4.6/Fable 5, 1.024 em Sonnet 4.5; máx 4 breakpoints por requisição
- Claude Batches API: 50% de desconto; até 100.000 requisições ou 256 MB por batch; resultados por 29 dias
- Gemini 3.6 Flash US$1.50/US$7.50 por 1M; Gemini 3.5 Flash US$1.50/US$9.00; Gemini 3.5 Flash-Lite US$0.30/US$2.50; Gemini 3.1 Flash-Lite US$0.25/US$1.50 — imagem cobrada na mesma tarifa do texto
- Gemini context caching: US$0.15/1M (Flash) ou US$0.03/1M (Flash-Lite) + US$1.00/hora de armazenamento
- OpenCV stitching de bobina: cv.Stitcher.create(cv.Stitcher_SCANS) → modelo afim 6/4 DOF, AffineBestOf2NearestMatcher + BundleAdjusterAffinePartial + AffineWarper
- Sauvola: k ∈ [0.2, 0.5], sugerido k=0.2 e R=125, janela w ímpar (25–31 para cupom em ~2000px — inferência minha)
- adaptiveThreshold sugerido (inferência minha): cv2.ADAPTIVE_THRESH_GAUSSIAN_C, blockSize 31–41 (ímpar), C 10–15
- Blur gate: cv2.Laplacian(gray, cv2.CV_64F).var(); SEM valor universal — calibrar com ≥50 amostras nítidas e ≥50 borradas do hardware-alvo
- Reconciliação (inferência minha): tol_item = max(R$0,02; 0,005 × qtde_arredondada); tol_subtotal = max(R$0,05; n_itens × R$0,01); qCom até 4 casas decimais e vUnCom até 10 no layout NF-e, vProd sempre 2
- Datasets públicos de recibo: SROIE (ICDAR 2019, 1.000 imagens, 3 tarefas), CORD (recibos indonésios, box-level + 8 superclasses), ReceiptSense (arXiv 2406.04493); pt-BR: apenas HuggingFace `sc0v0ne/BrazilianPortugueseOCR` (contém NF-e; licença e anotação não verificadas)

## RECOMENDACOES
- ARQUITETURA DE 3 ESTÁGIOS, não 1: (A) pré-processamento OpenCV determinístico → (B) OCR de layout produzindo texto + bounding boxes + confiança por linha → (C) extração estruturada por LLM multimodal recebendo IMAGEM CORRIGIDA + TEXTO OCR + BOXES juntos no mesmo prompt. O híbrido supera tanto 'OCR+regex' quanto 'imagem crua no LLM': o texto OCR ancora números e evita alucinação de dígito; a imagem resolve o que o OCR errou e dá o layout de colunas.
- GATE DE QUALIDADE NO APP FLUTTER, ANTES DO UPLOAD: rodar detecção de borda + variância do Laplaciano no frame ao vivo e só permitir a captura quando (i) 4 cantos detectados, (ii) variância acima do threshold calibrado, (iii) lado longo >= 1600px. Isso corta o custo de reprocessamento e a taxa de erro na origem, e é a única otimização que melhora TODOS os provedores ao mesmo tempo. Calibrar o threshold com >= 50 fotos nítidas e >= 50 borradas tiradas com aparelhos reais dos usuários-alvo (Android de baixo custo), não com fotos de teste do desenvolvedor.
- PROVEDOR PADRÃO RECOMENDADO PARA MVP: PaddleOCR 3.7 / PP-OCRv6_medium servido via RapidOCR + ONNX Runtime/OpenVINO em container CPU (custo marginal ~zero, sem vendor lock-in, latência ~1.4s/imagem em Xeon), seguido de Gemini 3.5 Flash-Lite ou Claude Haiku 4.5 com JSON Schema estrito para a extração. Custo estimado US$0.006–0.015/cupom vs US$0.010 fixo do AnalyzeExpense, com controle total do schema (o schema de cupom brasileiro tem campos que nenhum parser genérico modela: CNPJ, chave de acesso, código do produto interno, unidade UN/KG/L, desconto por item).
- FALLBACK GERENCIADO: quando a reconciliação aritmética falhar ou a confiança agregada ficar abaixo do corte, reprocessar com Azure prebuilt-receipt (única API que documenta 'thermal receipts' com `pt` na lista) ou AWS AnalyzeExpense (PT confirmado, line items com confiança por campo). Comparar os dois outputs e escalar para revisão humana só quando divergirem.
- FORÇAR JSON VÁLIDO POR SCHEMA, NUNCA POR PROMPT: Claude → `output_config: {format: {type: "json_schema", schema: {...}}}` ou tool com `strict: true` + `additionalProperties: false` + `required` completo. Gemini → `response_schema` + `response_mime_type: application/json`. OpenAI → `response_format: {type: "json_schema", strict: true}`. E, criticamente: o schema NÃO valida faixa numérica (Claude ignora minimum/maximum/multipleOf/minLength) — toda validação de preço, quantidade e data tem que rodar em Pydantic no backend depois do parse.
- ESTRATÉGIA PARA BOBINA DE 60cm: preferir 'multi-página lógica' a stitching de pixels. Instruir o usuário a fotografar em N trechos com ~20% de sobreposição vertical, rodar OCR em cada trecho independentemente, e deduplicar linhas por (a) similaridade de texto normalizado + (b) proximidade de coordenada Y projetada. O stitching de pixels (cv.Stitcher_SCANS, modelo afim) fica como caminho secundário para os casos em que a dedupe falhar, porque falha com frequência em textura repetitiva de linhas de texto. Sinal de fechamento: a reconciliação Σitens==subtotal só valida quando TODOS os trechos foram capturados — usar isso para pedir a foto faltante ao usuário.
- MEDIR TAXA DE ERRO POR PROVEDOR EM PRODUÇÃO com 5 métricas por documento: (1) taxa de sucesso de parse do JSON, (2) taxa de consistência aritmética (R1/R2/R3 passando sem correção), (3) CER dos campos numéricos contra gold set, (4) taxa de correção humana por campo, (5) p95 de latência e custo/doc. Persistir provider_id + provider_version + prompt_version + preprocess_version em cada extração para permitir análise retroativa quando um provedor regredir silenciosamente.
- CONSTRUIR O GOLD SET INTERNO DESDE O DIA 1: 500–1.000 cupons brasileiros reais anotados campo a campo (CNPJ, data, itens com descrição/qtde/unidade/vl_unit/vl_total, descontos, subtotal, total). Não existe equivalente público. Esse dataset é (a) o único jeito honesto de escolher entre provedores, (b) a base para calibrar confiança, (c) potencialmente material de fine-tune de docTR/PP-OCR no domínio, e (d) ativo defensável do produto.
- PORT/ADAPTER: definir dois Protocols Python separados — `OcrProvider.recognize(image_bytes) -> OcrResult(lines[text, bbox, confidence], full_text, provider_meta)` e `ReceiptExtractor.extract(image_bytes, ocr_result | None) -> ReceiptDraft`. Adapters: PaddleOcrProvider, TextractOcrProvider, VisionOcrProvider; ClaudeExtractor, GeminiExtractor, TextractExpenseExtractor, AzureReceiptExtractor. Registry com política declarativa (ordem, circuit breaker por taxa de erro em janela de 5min, timeout por provedor, orçamento diário em USD). Nenhum código de domínio importa SDK de fornecedor.
- USAR BATCH APIs PARA ENCARTES, NÃO PARA CUPONS: encartes importados por administrador não são latency-sensitive — Claude Batches e OpenAI Batch dão 50% de desconto; Textract assíncrono (StartExpenseAnalysis/GetExpenseAnalysis) suporta PDF de até 500MB e 3.000 páginas, contra 1 página no modo síncrono. Cupom de usuário vai pelo caminho síncrono/fila rápida.

## NAO FAZER
- NÃO usar Tesseract 5.x como motor primário de cupom térmico. Não é questão de tuning: a arquitetura LSTM assume linha contínua e a fonte matricial é descontínua por construção. Piso relatado de ~60% de acurácia de caractere em papel térmico desbotado. Ele pode ficar como baseline offline de comparação, nada além.
- NÃO adotar EasyOCR: sem release desde 2024-09-24, defasado ~2 anos em relação a PP-OCRv6/Surya.
- NÃO binarizar antes de mandar para PP-OCRv6 ou para um VLM. Esses modelos foram treinados em imagens naturais/grayscale; a binarização apaga informação de traço fino de fonte matricial e costuma PIORAR o resultado. Binarização é útil para Tesseract, que não é o motor recomendado aqui.
- NÃO aplicar denoise agressivo (fastNlMeansDenoising com h alto) em cupom térmico — remove os pontos que formam a própria fonte matricial.
- NÃO medir variância do Laplaciano depois de um blur do pipeline: o valor fica sem sentido. A medição tem que ocorrer no mesmo ponto do pipeline usado na calibração, sobre a imagem grayscale sem suavização adicional.
- NÃO confiar na confiança bruta do OCR como probabilidade. Textract retorna Confidence 0-100 mas ela não é calibrada; e LLM multimodal não retorna confiança nenhuma. Calibrar com regressão logística sobre gold set e validar com reliability diagram/Brier score.
- NÃO fazer stitching de pixels como caminho principal para bobina longa. Textura repetitiva de linhas de texto é o pior caso para matching de features; a dedupe lógica por texto+coordenada é mais robusta e mais barata.
- NÃO usar Claude Opus 4.8 com effort alto no caminho quente de extração de cupom. É caro (US$5/US$25 por MTok), tem turnos longos por adaptive thinking, e a tarefa não exige raciocínio de longo horizonte. Haiku 4.5 / Sonnet 5 / Gemini Flash-Lite resolvem.
- NÃO colocar cache_control 'por precaução' no prompt do extrator: com prefixo abaixo de 4.096 tokens no Opus/Haiku 4.5 o cache não é criado e paga-se 1.25× de write sem nenhum read. Verificar cache_read_input_tokens antes de manter.
- NÃO usar Google Document AI Expense Parser sem teste em cupom brasileiro: pt-BR não consta como idioma otimizado e o preço é idêntico ao de Textract/Azure, que documentam PT.
- NÃO enviar PDF multipágina de encarte pelo caminho síncrono do Textract — o limite é 1 página. Rotear para StartExpenseAnalysis/StartDocumentTextDetection.
- NÃO acoplar o domínio a SDK de fornecedor. Se `boto3` ou `anthropic` aparecer importado dentro do módulo de normalização de produto, a troca de provedor vira refatoração de semanas em vez de troca de config.
- NÃO projetar nenhuma coleta que dependa de contornar CAPTCHA, rate limit, autenticação ou robots.txt de portais SEFAZ ou de sites de varejo. Se um dado só for obtível assim, ele fica fora do produto; a alternativa legítima é parceria/API oficial, PDF público ou contribuição do próprio usuário.
- NÃO tratar SROIE/CORD como validação suficiente. São recibos ingleses e indonésios, com layout, moeda e vocabulário diferentes. Servem para pré-treino e sanity check, não para decidir provedor.

## RISCOS
- Números de OmniDocBench dos modelos VLM (PaddleOCR-VL-1.6 96.33, MinerU2.5-Pro 95.69) são AUTO-REPORTADOS pelos fornecedores e houve correção de benchmark em maio/2026 que mexeu em scores de tabela. Adotar qualquer um deles com base nesses números sem validar no gold set próprio é risco de regressão silenciosa.
- Preço do Azure prebuilt-receipt (US$10/1k) NÃO foi confirmado em página oficial nesta pesquisa (timeout). Preços de OpenAI GPT-5.6 vieram só de agregadores. Ambos precisam de verificação antes de virar linha de orçamento.
- Suporte a pt-BR no Google Document AI Expense Parser não é documentado. Se for adotado sem teste, a qualidade em cupom brasileiro pode ser muito pior que a de Textract/Azure — e o preço é o mesmo (US$10/1k), então não há upside.
- Latência do caminho híbrido: OCR (1.4s CPU) + LLM multimodal (2–15s dependendo do modelo e do effort) pode passar de 20s por cupom. Modelos com adaptive thinking (Claude Opus 4.8, Fable 5) têm turnos de MINUTOS em tarefas difíceis — usar effort low/medium e Haiku/Flash-Lite para extração, nunca Opus com effort alto no caminho quente.
- Risco de alucinação numérica do LLM: um modelo multimodal pode inventar um dígito plausível em campo desbotado sem sinalizar. Sem a reconciliação aritmética como rede de segurança, dados falsos entram no banco de preços e contaminam o núcleo do produto (comparação de cestas). A reconciliação é requisito, não feature.
- Surya faz auto-spawn de servidor de inferência (vllm/llama.cpp) no primeiro uso — em Docker Compose isso significa imagem gigante, cold start longo e dependência de GPU para throughput útil (0.108 páginas/s em Apple Silicon é inviável). Não é boa escolha para o container de API.
- Prompt caching do Claude falha SILENCIOSAMENTE quando o prefixo tem menos de 4.096 tokens (Opus/Haiku 4.5): `cache_read_input_tokens` fica 0 e paga-se 1.25× de write sem nunca ler. Se o time colocar cache_control 'por precaução', o custo SOBE.
- Textract síncrono aceita PDF/TIFF de apenas 1 página — se o app permitir upload de PDF de encarte multipágina no caminho síncrono, ele quebra. Precisa de roteamento explícito para o caminho assíncrono.
- Fotos de cupom contêm CPF do consumidor, CNPJ do estabelecimento e chave de acesso. Enviar essas imagens para provedor gerenciado estrangeiro tem implicação de LGPD (transferência internacional + base legal + retenção). Claude Fable 5, por exemplo, EXIGE retenção de 30 dias e não opera sob zero data retention. Isso precisa entrar no DPA e na política de privacidade — ou motivar o self-hosting do OCR.
- Modelos térmicos de impressora variam por rede de supermercado (largura 58mm vs 80mm, fonte, densidade). Um threshold de blur e um conjunto de parâmetros de binarização calibrados em uma rede podem não generalizar. Calibrar por 'perfil de layout' detectado (CNPJ → rede → perfil) é mais robusto que um único conjunto global.

## EM ABERTO
- Preço oficial atual do Azure AI Document Intelligence prebuilt-receipt: a página de pricing deu timeout; confirmar US$10/1.000 páginas e a existência (ou não) de desconto por volume nos prebuilt.
- Preços oficiais da família GPT-5.6/5.5 e limites de imagem: não consegui abrir fonte primária da OpenAI. Todos os números citados são de agregadores.
- Google Document AI Expense Parser suporta pt-BR com qualidade utilizável? A documentação cita otimização para EN/FR/NL/JA. Precisa de teste empírico com 50 cupons brasileiros.
- Consumo de RAM/VRAM e latência real do PP-OCRv6_medium em uma imagem de cupom de 2400px (não em imagem de benchmark). Os números publicados são por imagem genérica de documento.
- Tamanho em MB dos modelos PP-OCRv6 tiny/small/medium (detecção e reconhecimento separados) — não publicado; afeta diretamente o tamanho da imagem Docker e o cold start.
- Acurácia do PP-OCRv6 especificamente em português — os 50 idiomas incluem 46 de escrita latina mas não há breakdown por idioma publicado. Surya publica breakdown mas não lista português.
- Licença, tamanho e presença de anotação de line items no dataset `sc0v0ne/BrazilianPortugueseOCR` — só a descrição foi vista, não o dataset card completo.
- Existe realmente um 'ExpressExpense' como dataset acadêmico citável, ou é apenas um produto comercial? Não consegui confirmar nesta pesquisa.
- Qual a distribuição real de larguras de bobina (58mm vs 80mm) e de layout entre as redes de supermercado do mercado-alvo? Isso determina se um perfil de pré-processamento global é suficiente ou se é preciso perfil por rede.
- O layout NF-e admite qCom com até 4 casas e vUnCom com até 10 — mas na prática o que os PDVs brasileiros imprimem no cupom (DANFE NFC-e) é 3 casas para peso e 2 para valor? Precisa de verificação no manual de orientação do contribuinte antes de fixar as tolerâncias de reconciliação.
- Implicação de LGPD de enviar imagens com CPF/CNPJ/chave de acesso a provedores estrangeiros — exige parecer jurídico, base legal explícita e cláusula de transferência internacional no DPA. Claude Fable 5 exige retenção de 30 dias e não opera sob zero data retention.
- Versões e qualidade de pacotes Flutter de OCR/detecção de borda on-device (ML Kit, etc.) — não pesquisadas nesta rodada; necessário para especificar o gate de qualidade no app.


################################################################
# TOPICO: Normalização e matching de produtos de supermercado a partir de descrições truncadas de cupom fiscal brasileiro (NFC-e/NF-e)
################################################################

## RESUMO EXECUTIVO
O problema tem duas camadas independentes: (a) identificação forte por GTIN, (b) identificação fraca por texto truncado. A camada (a) resolve a maior parte dos casos com precisão ~1.0, MAS só quando o GTIN não é um RCN (Restricted Circulation Number): GTIN-13 iniciado em "2" (faixas 200-299 e 020-029) e GTIN-8 iniciado em 0 ou 2 são códigos internos de loja/região — NÃO são chave global e colidem entre redes. Detectar e descartar RCN como chave é o requisito de correção nº1 do sistema. O layout da NF-e permite ainda cEAN vazio ou o literal "SEM GTIN", e a NT 2020.005 criou cBarra/cBarraTrib para códigos de barras não-GTIN — ou seja, uma fração relevante dos itens chegará sem chave forte.
A camada (b) deve ser uma pipeline determinística-primeiro: normalização (uppercase, unaccent, expansão de abreviações via dicionário, extração de embalagem) → blocking (pg_trgm GIN + tokens de marca) → scoring (RapidFuzz token_set_ratio + TF-IDF char_wb 3-4gram) → gates determinísticos (marca, quantidade, unidade, sabor, variante) → banda de confiança (auto-link / fila humana / novo produto). Embeddings (multilingual-e5-small ou paraphrase-multilingual-MiniLM-L12-v2, ambos 384 dims, pgvector 0.8.5) só compensam depois que o recall léxico medido estabilizar; o benchmark WDC Products mostra baseline simbólico batendo RoBERTa fine-tuned em datasets pequenos/médios.
Fontes de enriquecimento por GTIN: Open Food Facts é a única livre, cacheável e comercialmente utilizável (ODbL, com share-alike), mas tem só ~35 mil produtos BR. Cosmos/Bluesoft tem a maior base BR (>18M itens declarados) e preço acessível (R$499,99–R$1.999,99/mês por 100–500 consultas/dia), porém os Termos de Uso vedam expressamente uso "no contexto de quaisquer atividades empresariais e/ou profissionais" sem acordo comercial específico — exige contrato antes de qualquer uso em produção. GS1 Brasil (Verified by GS1) é a fonte oficial mas exige associação; a versão web gratuita é limitada a 30 consultas/dia. O web service oficial ccgConsGTIN da SEFAZ (NT 2022.001) exige certificado ICP-Brasil de CNPJ com autenticação mútua — inviável para um app de consumidor sem PJ emissora.
NCM/CEST servem para gating fiscal e categorização grosseira, nunca para identificar produto: NCM 0901.21.00 cobre todo café torrado não-descafeinado, de qualquer marca ou tamanho. Use NCM apenas como bloqueio negativo (capítulo diferente ⇒ nunca unir) e como facet de categoria.
Regra de ouro anti-falso-positivo: nunca unir automaticamente sabores, versões (tradicional/extra forte, integral/desnatado, zero/normal) ou tamanhos diferentes. Modele produto canônico ≠ pacote (SKU/GTIN) ≠ alias (descrição crua por varejista), com toda ligação reversível e auditada.

## ACHADOS

### [confirmada] GTIN-13 começando com 2 (faixa 200-299) é Restricted Circulation Number regional — código interno de loja, NÃO globalmente único
Tabela oficial de prefixos GS1: 200-299 = 'Used to issue GS1 restricted circulation number within a geographic region'; 020-029 = mesma finalidade em faixa UPC-A compatible; 040-049 = 'restricted circulation numbers within a company'. Regra de detecção: gtin13[0]=='2' OR gtin13[:2]=='02' OR gtin13[:2]=='04' ⇒ RCN ⇒ NUNCA usar como chave global; guardar como (retailer_id, rcn) e só resolver por texto. Padrão típico BR em balança: 2 + código-do-item (5-6 díg.) + peso-ou-preço (5-6 díg.) + DV, ou seja o código MUDA a cada etiqueta — usar como chave gera colisão e vazamento de preço entre lojas.
FONTE: https://en.wikipedia.org/wiki/List_of_GS1_country_codes

### [confirmada] GTIN-8 iniciado em 0 ou 2 também é RCN-8 (uso interno, não global)
GS1: 'RCN-8s are a subset of GTIN-8 which begin with a first digit of 0 or 2'; o prefixo indica que a numeração está sob controle exclusivo da empresa que atribui. Regra: len==8 and gtin8[0] in {'0','2'} ⇒ RCN.
FONTE: https://www.gs1.org/standards/id-keys/company-prefix

### [confirmada] Prefixos 789 e 790 = GS1 Brasil (registro, não origem de fabricação)
789-790 são atribuídos à GS1 Brasil. Importante para o produto: o prefixo indica onde a empresa se REGISTROU, não onde o produto foi fabricado — não usar como 'produto nacional'. Outros prefixos úteis para descarte: 977 (ISSN), 978-979 (ISBN/ISMN), 980 (refund receipts), 981-983 e 990-999 (cupons GS1) — nenhum é produto de supermercado.
FONTE: https://en.wikipedia.org/wiki/List_of_GS1_country_codes

### [confirmada] GTIN-14 com dígito indicador 9 = item de medida variável (peso variável), não escaneável em PDV
GS1 US: variable measure trade items usam GTIN-14 com indicator digit 9 na primeira posição, sinalizando 'variable measure trade item that cannot be scanned at retail checkout/Point-of-Sale'. Indicadores 1-8 = níveis de agrupamento fixo (DUN-14 / fardo / caixa). Consequência prática: de um DUN-14 com indicador 1-8 dá para derivar a unidade de consumo — strip do indicador, pegar os 12 dígitos do meio, recalcular DV mod-10 ⇒ GTIN-13 da unidade; com indicador 9, NÃO derivar.
FONTE: https://www.help.gs1us.org/is-this-item-variable-measure

### [confirmada] O layout da NF-e/NFC-e aceita cEAN vazio ou o literal 'SEM GTIN', e a NT 2020.005 criou cBarra/cBarraTrib para códigos não-GTIN
Campo cEAN: tamanhos aceitos 0, 8, 12, 13 ou 14; 'informar "SEM GTIN" quando o produto não possuir este código'. Mesmo para cEANTrib. NT 2020/005 acrescentou as tags cBarra e cBarraTrib para códigos de barras diferentes do padrão GTIN. Outros campos do grupo <prod> úteis: cProd (1-60, código interno do emitente), xProd (1-120, descrição), NCM (2 ou 8), CEST (7), uCom (1-6), qCom (15,4), vUnCom (21,10), uTrib/qTrib/vUnTrib, indEscala, CNPJFab.
FONTE: https://flexdocs.net/guiaNFe/gerarNFe.detalhe.pro.produto400.html

### [confirmada] A SEFAZ valida o prefixo do GTIN contra a tabela GS1 e rejeita códigos com prefixo inválido (Rejeição 884 / 612)
Rejeição 884 = 'GTIN da unidade tributável (cEANTrib) com prefixo inválido'; a nota de referência declara: 'Validação efetuada conforme prefixos e orientações constantes na Tabela Prefixo GS1 publicada no Portal Nacional da NFe' apontando para gs1.org/standards/id-keys/company-prefix (NT 2017.001 v1.20). Isso significa que GTINs que chegam via XML já passaram por validação de DV e prefixo — mas RCNs continuam válidos e passam.
FONTE: https://oobj.com.br/bc/rejeicao-884-como-resolver/

### [confirmada] Open Food Facts tem ~35.004 produtos para o Brasil (medido em 2026-07-22) — cobertura baixa para o varejo alimentar brasileiro
Página br.openfoodfacts.org exibe '35.004 produtos'. Cobertura é enviesada para itens industrializados com rótulo nutricional; não cobre hortifrúti, açougue, padaria, limpeza/higiene (esses ficam em Open Beauty/Products Facts, com cobertura BR ainda menor). Usar como enriquecimento oportunista, nunca como fonte primária de catálogo.
FONTE: https://br.openfoodfacts.org/

### [confirmada] Open Food Facts API v2: limites de 15 req/min/IP (produto) e 10 req/min/IP (busca), User-Agent obrigatório, dumps CSV/JSONL disponíveis
Base: https://world.openfoodfacts.org/api/v2/ . User-Agent no formato 'AppName/Version (ContactEmail)'. 'If you need to fetch more than a few hundred products, we ask you to download the data as a CSV or JSONL file directly' em https://world.openfoodfacts.org/data . Licenças: base = ODbL, conteúdos = DbCL, imagens = CC-BY-SA. Estratégia correta: baixar o dump, filtrar countries_tags=en:brazil, carregar em tabela local, e usar a API só para GTINs ausentes (com cache + backoff).
FONTE: https://openfoodfacts.github.io/openfoodfacts-server/api/

### [provavel] ODbL impõe share-alike ao banco derivado: a arquitetura precisa isolar atributos de origem OFF
Condições da ODbL: atribuição + share-alike; se você combina OFF com outro banco, o banco resultante deve ser publicado como open data. Mitigação de arquitetura: manter colunas/tabela separada (product_attributes_off) com source='off', nunca mesclar no registro canônico, e publicar como ODbL apenas esse subconjunto se/quando for distribuído. Uso interno sem distribuição pública do banco não dispara o share-alike (interpretação jurídica — validar com advogado).
FONTE: https://support.openfoodfacts.org/help/en-gb/12-api-data-reuse/94-are-there-conditions-to-use-the-api

### [confirmada] Cosmos/Bluesoft: preços confirmados — Basic grátis 25 consultas/dia; Simple R$499,99/mês (100/dia); Standard R$999,99/mês (200/dia); Pro R$1.999,99/mês (500/dia); Enterprise sob consulta
Cobrança por CONSULTA/DIA, não por mês — 500/dia no plano mais caro é MUITO pouco para ingestão em massa de cupons (um único cupom pode ter 40 itens). A própria página avisa: 'não há garantia que os dados estejam corretos e atualizados, e nem todos os produtos estão com o cadastro completo (alguns podem estar sem NCM ou sem foto)'.
FONTE: https://api.cosmos.bluesoft.com.br/api-pricings

### [confirmada] Os Termos de Uso do Cosmos VEDAM uso do serviço em atividade empresarial/profissional sem acordo comercial específico
Cláusula RESTRIÇÕES DE UTILIZAÇÃO: 'O SERVIÇO Bluesoft Cosmos é de caráter restrito, para uso exclusivamente do usuário previamente cadastrado, sendo vedada a sua utilização para promover propaganda, anunciar e ofertar produtos e serviços próprios ou de terceiros, para a prestação de serviços ou no contexto de quaisquer atividades empresariais e/ou profissionais, sem prévia anuência da Bluesoft ou acordo comercial específico entre as partes.' Plano pago tem vigência de 12 meses com renovação automática. Consequência: usar o tier Basic gratuito para alimentar o melhor_mercado é violação de termos; é preciso contrato assinado antes de qualquer uso produtivo, inclusive para decidir se pode cachear.
FONTE: https://api.cosmos.bluesoft.com.br/termos_de_servico

### [provavel] Cosmos API: header X-Cosmos-Token, endpoint GET /gtins/{gtin}.json, campos retornados incluem ncm{code,description,full_description} e gpc{code,description}
Host observado: https://api.cosmos.bluesoft.io/gtins/{gtin}.json . Campos: gtin, description, thumbnail, brand{name,picture}, gpc{code,description}, ncm{code,description,full_description}, avg_price, max_price, min_price, width, height, length, net_weight, gross_weight. O campo GPC (GS1 Global Product Classification) é o mais útil para categorização — melhor que NCM para agrupar produto de consumo.
FONTE: https://github.com/matheuscas/bluesoft-cosmos-api/blob/master/README.md

### [confirmada] GS1 Brasil / Verified by GS1: consulta web gratuita limitada a 30 consultas/dia e 7 campos; API exige ser associado GS1 Brasil
Texto do site: 'Esta versão do Verified by GS1 está limitada a 30 consultas diárias e apresenta as 7 principais informações de um produto.' Dados cadastrais: Descrição do Produto, Marca, Conteúdo Líquido + Unidade de Medida, Peso Bruto + Unidade, Imagem, GPC (código e descrição). NCM e CEST só com plano contratado. Status de sincronização com o CCG (base usada pelas SEFAZ) só após contratar plano. Condição para integrar a API do Cadastro Nacional de Produtos: ser empresa associada à GS1 Brasil. Preço não divulgado publicamente — exige contato comercial.
FONTE: https://www.gs1br.org/consulta-gtin

### [confirmada] O web service oficial de consulta GTIN da SEFAZ (ccgConsGTIN, NT 2022.001) exige certificado ICP-Brasil com CNPJ/CPF e autenticação mútua — inacessível a um app de consumidor
Método 'ccgConsGTIN', síncrono, hospedado no ambiente SVRS. Padrões: XML, SOAP 1.2, TLS v1.2 com autenticação mútua, certificado digital ICP-Brasil (X.509). 'Informação só pode ser enviada com certificado digital contendo o CPF ou CNPJ do contribuinte emissor da NFC-e ou NF-e.' Ou seja: só emissores de documento fiscal têm acesso legítimo. Não existe rota pública equivalente.
FONTE: https://www.nfe.fazenda.gov.br/portal/exibirArquivo.aspx?conteudo=WpIPyTpmMsM%3D

### [confirmada] Tabela NCM oficial: download JSON direto sem CAPTCHA no Portal Único Siscomex
URL direta: https://portalunico.siscomex.gov.br/classif/api/publico/nomenclatura/download/json . Também XLSX (com e sem descrição concatenada). Portal navegável: https://portalunico.siscomex.gov.br/classif/#/nomenclatura/tabela?perfil=publico ; histórico/futuro em .../nomenclatura/avancada?perfil=publico . O arquivo contém apenas a NCM vigente (exclui expiradas e futuras) — agendar sync mensal e versionar.
FONTE: https://www.gov.br/receitafederal/pt-br/assuntos/aduana-e-comercio-exterior/classificacao-fiscal-de-mercadorias/download-ncm-nomenclatura-comum-do-mercosul

### [confirmada] NCM tem 8 dígitos hierárquicos e identifica CATEGORIA FISCAL, jamais produto
Estrutura: dígitos 1-2 = capítulo, 3-4 = posição, 5-6 = subposição, 7 = item, 8 = subitem. TIPI: 21 seções, 97 capítulos. Total de códigos vigentes: fontes divergem (10.513 / 11.364 / ~12.000) — tratar como ~10-11 mil e contar do arquivo oficial. Exemplo do porquê não serve como identidade: 0901.21.00 = café torrado não descafeinado ⇒ cobre Pilão, Melitta, 3 Corações, 250g e 500g, todos no mesmo código. Uso correto: (a) bloqueio negativo — capítulos NCM diferentes ⇒ nunca unir; (b) facet de categoria grosseira; (c) validação de plausibilidade.
FONTE: https://www.gov.br/receitafederal/pt-br/assuntos/aduana-e-comercio-exterior/classificacao-fiscal-de-mercadorias/download-ncm-nomenclatura-comum-do-mercosul

### [confirmada] CEST tem 7 dígitos (2 segmento + 3 item + 2 especificação) e vem dos Anexos II a XXVI do Convênio ICMS 142/2018 (CONFAZ)
Fonte oficial: https://www.confaz.fazenda.gov.br/legislacao/convenios/2018/CV142_18 (Anexos II a XXVI relacionam CEST + NCM/SH + descrição). CEST só existe para mercadorias sujeitas a substituição tributária — cobertura parcial do supermercado (bebidas, higiene, limpeza, alimentos ST) e ausente em boa parte da mercearia. Granularidade um pouco melhor que NCM (o item/especificação distingue, ex., 'refrigerante em garrafa PET' de 'refrigerante em lata'), mas ainda categoria, não produto. Não existe download CSV oficial estruturado — os anexos são PDF/HTML; será necessário parse e versionamento manual.
FONTE: https://www.confaz.fazenda.gov.br/legislacao/convenios/2018/CV142_18

### [confirmada] Brasil API expõe NCM (MIT), mas NÃO expõe produto/GTIN
Endpoints: GET /ncm/v1 (todos), GET /ncm/v1/{code}, e busca por código/descrição. Licença do projeto: MIT; docs em https://brasilapi.com.br/docs . Não há qualquer endpoint de produto/GTIN/EAN. Serve como fallback conveniente de descrição de NCM, mas prefira o arquivo oficial do Siscomex como fonte de verdade (Brasil API é projeto comunitário sem SLA).
FONTE: https://brasilapi.com.br/docs

### [provavel] Datakick (gtinsearch.org) oferece API REST gratuita sem rate limit; UPCitemdb tem tier grátis de 100 req/dia
Datakick: GET https://www.gtinsearch.org/api/items/{gtin}; 'there is no rate limit and authentication is optional'; código de teste 000000000000; imagens sob CC-BY-SA 3.0. UPCitemdb: plano EXPLORER grátis com 100 requisições/dia sem cadastro; Basic a partir de US$49/mês. ATENÇÃO: o antigo datakick.org foi desligado em março/2020; gtinsearch.org é o sucessor. Cobertura de produtos brasileiros em ambos: NÃO verificada, presumivelmente muito baixa (bases centradas em US/EU).
FONTE: https://gtinsearch.org/api

### [confirmada] pg_trgm: thresholds padrão são 0.3 (similarity), 0.6 (word_similarity), 0.5 (strict_word_similarity)
GUCs: pg_trgm.similarity_threshold=0.3, pg_trgm.word_similarity_threshold=0.6, pg_trgm.strict_word_similarity_threshold=0.5. Operadores: % <% %> <<% %>> e distâncias <-> <<-> <->> <<<-> <->>>. Funções: similarity, word_similarity, strict_word_similarity, show_trgm. gin_trgm_ops = busca rápida / update lento (ideal para catálogo canônico, que muda pouco); gist_trgm_ops = siglen padrão 12 (1-2024) e suporta KNN eficiente com ORDER BY <->. Limitação crítica: palavras com menos de 3 caracteres geram poucos/nenhum trigrama — tokens como 'LT','KG','UN','2L' são praticamente invisíveis ao trigram, por isso a extração de embalagem precisa ser feita por regex ANTES e comparada como campo estruturado.
FONTE: https://www.postgresql.org/docs/current/pgtrgm.html

### [confirmada] Versões atuais das bibliotecas Python de matching (jul/2026)
RapidFuzz 3.14.5 (lançada 2026-04-07), MIT, requer Python>=3.10 — usar rapidfuzz.process.cdist() com score_cutoff em vez de loops; fuzz.token_set_ratio retorna 100.0 quando uma string é subconjunto da outra (armadilha: 'CAFE PILAO 500G' vs 'CAFE PILAO' dá 100). scikit-learn 1.9.0 (Python>=3.11) para TfidfVectorizer(analyzer='char_wb', ngram_range=(3,4)). sparse-dot-topn 1.2.0 (ING Bank) para top-N cosseno esparso sem materializar a matriz completa. sentence-transformers 5.6.0 (Apache-2.0). pgvector extensão 0.8.5 (2026-07-08, suporta Postgres 13+, halfvec, HNSW, iterative index scans); cliente Python pgvector 0.5.0.
FONTE: https://pypi.org/project/RapidFuzz/

### [confirmada] Modelos de embedding multilíngues pequenos viáveis: ambos 384 dimensões
sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2: 384 dims, 12 camadas, max_seq_length 128 tokens, 50+ idiomas. intfloat/multilingual-e5-small: 118M parâmetros, 12 camadas, 384 dims (exige prefixos 'query: ' e 'passage: ' — esquecer isso degrada muito o resultado). Custo de armazenamento em pgvector: 384*4 = 1.536 bytes/vetor em vector, ou 768 bytes em halfvec. Para 500 mil produtos canônicos: ~768 MB em vector, ~384 MB em halfvec.
FONTE: https://huggingface.co/intfloat/multilingual-e5-small

### [confirmada] Benchmark WDC Products: baseline simbólico de ocorrência de palavras supera RoBERTa fine-tuned em datasets pequenos/médios de product matching
'The simple symbolic word occurrence baseline is able to significantly beat the fine-tuned RoBERTa model for small and medium-size datasets for multi-class matching.' Modelos multi-classe transformer precisam de ~3-4 ofertas por classe para funcionar. Implicação direta: começar por regras + léxico é a decisão tecnicamente correta, não uma limitação; embeddings só depois de medir onde o recall léxico trava.
FONTE: https://arxiv.org/html/2301.09521

### [confirmada] Open Prices (Open Food Facts) é o precedente open source mais próximo, com endpoints de recibo já modelados
Backend Django REST (Python 3.11, PostgreSQL), repo openfoodfacts/open-prices, licença compatível com reuso; API em https://prices.openfoodfacts.org/api/docs com grupos: prices, proofs (POST /api/v1/proofs/upload, /proofs/drafts/upload, /proofs/{id}/anonymize, /proofs/process-with-gemini), receipt-items (CRUD completo), price-tags (com PriceTagPrediction), locations (integração OpenStreetMap, /locations/nearby, /locations/compare), moderation (flags), challenges/badges (gamificação). Modelagem a copiar: separação Proof (a foto/cupom) → PriceTag/ReceiptItem (a linha extraída, com status) → Price (o fato normalizado) → Product (canônico). Exige contribuir de volta os produtos adicionados e cumprir ODbL.
FONTE: https://prices.openfoodfacts.org/api/docs

### [confirmada] Precedentes brasileiros open source relevantes (e limitados)
(1) WolkerDias/gestao-simples — MIT, Python 3.11 + Streamlit, lê QR Code de NFC-e, faz web scraping na SEFAZ-MS, tem 'associação inteligente de produtos'; o README documenta exatamente nosso problema ('Tomate Salada' vs 'Tomate Vermelho', unidades kg/un/pacote divergentes). (2) eliel2703/tcc-ifprcascavel... (GenTracker, React Native+Firebase) — usa 'keyword matching com índice invertido' contra base de 1000+ produtos predefinidos, alega ~100x mais rápido que métodos tradicionais; licença NOASSERTION (uso acadêmico). (3) brunopenso/python-nfce-get — extrai NFC-e para JSON. (4) TadaSoftware/PyNFe — LGPL, interface com webservices da NF-e. (5) puppe1990/escanou — comparador de preços com scan de código de barras (jul/2026). Nenhum resolve normalização em escala; todos são ponto de partida de parsing, não de matching.
FONTE: https://github.com/WolkerDias/gestao-simples

### [provavel] Preço da Hora Bahia NÃO tem API pública/documentada; as libs de 'API privada' no GitHub contornam proteção do site
O FAQ de precodahora.ba.gov.br não menciona API pública nem download de dados abertos; existem Termos (/termos/termosecondicoes.pdf) e Política de Privacidade. Os repositórios Pedneri1/precodahora-api e igorpereirag/precodahora_api se autodescrevem como implementações da 'API Privada'/não documentada — o padrão conhecido dessas implementações envolve obter token/cookie de sessão do site. Usar isso configura acesso não autorizado a interface privada e provável violação dos termos. Rota legítima: solicitar convênio/dados abertos à SEFAZ-BA via pedido formal (LAI) ou parceria institucional.
FONTE: https://precodahora.ba.gov.br/faq

### [provavel] 'Menor Preço Brasil' é o app oficial unificado do CONFAZ (Convênio de Cooperação Técnica 03/19, 21 estados + DF), mas sem API pública documentada
Desenvolvido pela Procergs/SEFAZ-RS; consolidou o 'Menor Preço' (Celepar/SEFAZ-PR+ES). Alimentado por NF-e/NFC-e em tempo quase real. Não foi encontrada documentação de API, termos para desenvolvedores ou dataset aberto. Caminho legítimo: pedido formal via LAI / convênio com CONFAZ ou SEFAZ estadual — não scraping.
FONTE: https://www.confaz.fazenda.gov.br/noticias-do-confaz/confaz-lanca-aplicativo-menor-preco-brasil-destinado-a-ajudar-o-cidadao-a-encontrar-os-melhores-valores-no-comercio

### [confirmada] Não existe dicionário público consolidado de abreviações de cupom fiscal brasileiro
Buscas específicas (pt-BR e en) em web, GitHub e repositórios linguísticos brasileiros (EticaAI/linguistic-datasets-portuguese, br.ispell, pythonprobr/palavras) não retornaram nenhuma tabela de abreviações de descrição de produto de PDV/ECF. Consequência de arquitetura: a tabela precisa ser AUTORAL, versionada em migration/seed, e construída empiricamente — minerar os tokens mais frequentes do próprio corpus de xProd ingerido (top-2000 tokens por frequência) e rotular manualmente em lotes. Prever tabela abbreviation(token, expansion, kind, confidence, added_by, added_at) editável por admin, não constante hardcoded.
FONTE: https://github.com/EticaAI/linguistic-datasets-portuguese

### [confirmada] Postgres oferece unaccent como extensão contrib oficial — normalizar acentos no banco, não só na aplicação
CREATE EXTENSION unaccent; unaccent(text) remove diacríticos e pode ser usado fora de contexto de full-text search. Combinar em coluna gerada: description_norm = upper(unaccent(xProd)) com índice GIN gin_trgm_ops sobre ela. No lado Python, Unidecode (GPL — atenção à licença!) ou text-unidecode (Artistic License) ou unicodedata.normalize('NFKD') puro, que é stdlib e sem risco de licença.
FONTE: https://www.postgresql.org/docs/current/unaccent.html

### [baixa] Dicionário de abreviações de cupom fiscal brasileiro (construção autoral a validar contra corpus real)
CATEGORIAS: ACHOC=achocolatado; REFRIG/REFR/RFG=refrigerante; BISC/BOLACHA=biscoito; MARG=margarina; MANT/MTG=manteiga; DET/DETERG=detergente; SAB PO/SABAO PO=sabão em pó; SABON=sabonete; AMAC=amaciante; DESINF=desinfetante; LIMP=limpador; PAPEL HIG/P HIG/PH=papel higiênico; CR DENT/CREM DENT=creme dental; SH/SHAMP=shampoo; COND=condicionador; DESOD/DEO=desodorante; ABS=absorvente; FRALD=fralda; LT COND=leite condensado; CR LEITE/CREM LEITE=creme de leite; IOG=iogurte; REQ=requeijão; QJ/QJO=queijo; MUSS=mussarela; PRES=presunto; MORT=mortadela; LING=linguiça; SALS=salsicha; FRG/FGO=frango; ARR=arroz; FJ/FEIJ=feijão; MAC/MACARR=macarrão; FAR=farinha; ACUC/ACUC REF=açúcar refinado; OL=óleo; AZ=azeite; VIN=vinagre; TEMP=tempero; EXTR TOM=extrato de tomate; MOL=molho; MAION=maionese; MOST=mostarda; CAF=café; AG MIN=água mineral; CERV=cerveja; ENERG=energético; ISOT=isotônico; CHOC=chocolate; SORV=sorvete; CONG=congelado; EMPAN=empanado; PAO FORMA=pão de forma; TORR=torrada; CER MAT=cereal matinal; GRAN=granola; LT PO=leite em pó; FORM INF=fórmula infantil; RAC=ração; INSET=inseticida; ALV=alvejante; ESP ACO=esponja de aço; SAC LIXO=saco de lixo; PAP TOALHA=papel toalha; GUARD=guardanapo; FOSF=fósforo; LAMP=lâmpada. ATRIBUTOS/VARIANTES: TRAD=tradicional; ORIG=original; EXT FT/EX FORTE=extra forte; FT=forte; SUAV=suave; INT=integral; DESN/DESNAT=desnatado; SEMI/SEMIDESN=semidesnatado; ZERO/ZR=zero; DIET; LIGHT; S/=sem; C/=com; S/LAC=sem lactose; S/GLU=sem glúten; S/ACUC=sem açúcar; S/OSSO=sem osso; RESFR=resfriado; DEFUM=defumado; COZ=cozido; PIC=picante; NAT=natural; CONC=concentrado; REF=refinado (ou refil! ambíguo); MOR=morango; BAUN=baunilha; LIM=limão; LAR=laranja; MARAC=maracujá; ABAC=abacaxi; PESS=pêssego; GOI=goiaba. EMBALAGEM: PCT/PC/PCTE=pacote; CX=caixa; LT=lata OU litro (AMBÍGUO); GF/GFA=garrafa; PET=garrafa PET; VD=vidro; SCH=sachê; TP=Tetra Pak; UN/UND/UNID=unidade; FD=fardo; BDJ/BJ=bandeja; PT=pote; RF=refil; BISN=bisnaga; TB=tubo; EMB=embalagem; DP=display; KIT; L3P2=leve 3 pague 2. UNIDADES: G/GR/GRS=grama; KG; MG; ML; L/LT/LTS=litro; DZ=dúzia; M/MT=metro; CM; FL=folhas; R/ROL=rolo. uCom típicos do XML: UN, KG, PC, CX, LT, ML, PT, FD, DZ, MT, M2, M3, TON, SC, GL, BD, BJ, CJ, FR, GF, JG, KT, PA, PR, RL, TB, VD.
FONTE: 

### [provavel] Splink 4 é a referência open source para record linkage probabilístico, mas é overkill para o caso inicial
Splink 4 (Ministry of Justice UK): modelo Fellegi-Sunter não supervisionado, backends DuckDB/Spark/Athena, ~1 milhão de registros em ~1 minuto em laptop; dá match weights e term-frequency adjustments interpretáveis. Alternativas: dedupe (active learning, treinado por humano) e Python Record Linkage Toolkit (prototipagem modular). Recomendação: NÃO adotar no MVP — o ganho vem de features de domínio (marca, quantidade, sabor) que já são determinísticas; considerar Splink na fase 2 para deduplicar o catálogo canônico contra si mesmo.
FONTE: https://moj-analytical-services.github.io/splink/index.html

## ESPECIFICACOES CONCRETAS
- Prefixos GS1: 789-790 = Brasil; 200-299 e 020-029 = RCN regional (loja/balança); 040-049 = RCN interno de empresa; 000-019/030-039/050-059/060-139 = UPC-A US; 977 = ISSN; 978-979 = ISBN/ISMN; 980 = refund receipts; 981-983 e 990-999 = cupons GS1
- GTIN-8: RCN-8 = primeiro dígito 0 ou 2. GTIN-14: indicador 1-8 = agrupamento de medida fixa (DUN-14); indicador 9 = medida variável, não escaneável em PDV
- Dígito verificador GTIN (mod-10): da direita para a esquerda ignorando o DV, pesos alternados 3,1,3,1...; DV = (10 - (soma mod 10)) mod 10. Aplicar a GTIN-8/12/13/14
- Campo cEAN/cEANTrib da NF-e: tamanhos permitidos 0, 8, 12, 13, 14 ou o literal 'SEM GTIN'. cBarra/cBarraTrib (NT 2020.005) carregam códigos de barras não-GTIN
- Campos do grupo <prod>: cProd (1-60), xProd (1-120), NCM (2 ou 8), CEST (7), CFOP (4), uCom (1-6), qCom (15,4), vUnCom (21,10), vProd (15,2), uTrib, qTrib, vUnTrib, indEscala (S/N), CNPJFab (14)
- SEFAZ Consulta GTIN: método ccgConsGTIN, ambiente SVRS, SOAP 1.2, TLS 1.2 com autenticação mútua, certificado ICP-Brasil X.509 com CPF/CNPJ do emitente (NT 2022.001)
- Open Food Facts API v2 base: https://world.openfoodfacts.org/api/v2/ | limites 15 req/min/IP (produto) e 10 req/min/IP (busca) | User-Agent obrigatório 'AppName/Version (ContactEmail)' | dumps CSV/JSONL em https://world.openfoodfacts.org/data | staging https://world.openfoodfacts.net (basic auth off/off) | licença ODbL + DbCL + imagens CC-BY-SA | Brasil: 35.004 produtos (br.openfoodfacts.org, 2026-07-22)
- Open Prices API: https://prices.openfoodfacts.org/api/docs — endpoints /api/v1/prices, /api/v1/proofs, /api/v1/proofs/upload, /api/v1/proofs/drafts/upload, /api/v1/proofs/process-with-gemini, /api/v1/receipt-items, /api/v1/price-tags, /api/v1/locations/nearby, /api/v1/flags. Stack: Python 3.11 + Django REST + PostgreSQL
- Cosmos/Bluesoft: Basic grátis 25 consultas/dia; Simple R$499,99/mês 100/dia; Standard R$999,99/mês 200/dia; Pro R$1.999,99/mês 500/dia; Enterprise sob consulta. Contrato de 12 meses com renovação automática. Auth: header X-Cosmos-Token. Endpoint: GET https://api.cosmos.bluesoft.io/gtins/{gtin}.json. Campos: gtin, description, thumbnail, brand{name,picture}, gpc{code,description}, ncm{code,description,full_description}, avg_price, max_price, min_price, width, height, length, net_weight, gross_weight
- Verified by GS1 Brasil: versão web gratuita = 30 consultas/dia e 7 campos; API do Cadastro Nacional de Produtos exige associação à GS1 Brasil; NCM/CEST e status de sincronização com o CCG só em plano pago. Consulta em lote aceita .xlsx/.csv/.txt (UTF-8, coluna GTIN como Texto para preservar zeros à esquerda)
- Datakick: GET https://www.gtinsearch.org/api/items/{gtin} — grátis, sem rate limit, auth opcional, código de teste 000000000000, imagens CC-BY-SA 3.0. UPCitemdb: plano EXPLORER grátis 100 req/dia sem cadastro; Basic a partir de US$49/mês
- Tabela NCM oficial (JSON, sem CAPTCHA): https://portalunico.siscomex.gov.br/classif/api/publico/nomenclatura/download/json | portal: https://portalunico.siscomex.gov.br/classif/#/nomenclatura/tabela?perfil=publico | também XLSX com e sem descrição concatenada | contém só a NCM vigente
- NCM: 8 dígitos = 2 (capítulo) + 2 (posição) + 2 (subposição) + 1 (item) + 1 (subitem); TIPI com 21 seções e 97 capítulos; ~10.500-11.400 códigos vigentes (fontes divergem)
- CEST: 7 dígitos = 2 (segmento) + 3 (item) + 2 (especificação); fonte oficial Convênio ICMS 142/2018, Anexos II a XXVI, em https://www.confaz.fazenda.gov.br/legislacao/convenios/2018/CV142_18 (sem download CSV oficial — exige parse dos anexos)
- Brasil API (MIT): GET /ncm/v1, GET /ncm/v1/{code}, busca por código ou descrição — https://brasilapi.com.br/docs . Não possui endpoint de produto/GTIN
- pg_trgm: pg_trgm.similarity_threshold=0.3, pg_trgm.word_similarity_threshold=0.6, pg_trgm.strict_word_similarity_threshold=0.5. Operadores % <% %> <<% %>> <-> <<-> <->> <<<-> <->>>. gin_trgm_ops (busca rápida, update lento) vs gist_trgm_ops(siglen=12, 1..2024, suporta KNN). Palavras <3 chars geram poucos trigramas
- Versões pinadas (jul/2026): rapidfuzz==3.14.5 (MIT, py>=3.10), scikit-learn==1.9.0 (py>=3.11), sparse-dot-topn==1.2.0, sentence-transformers==5.6.0, pgvector (python client)==0.5.0, extensão pgvector 0.8.5 (Postgres 13+), splink 4.x, Unidecode (GPL) ou text-unidecode (Artistic)
- Embeddings: sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2 = 384 dims, 12 camadas, max_seq_length 128, 50+ idiomas | intfloat/multilingual-e5-small = 118M params, 384 dims, exige prefixos 'query: ' / 'passage: '. Armazenamento pgvector: vector(384)=1.536 B/linha, halfvec(384)=768 B/linha
- TF-IDF para nomes: TfidfVectorizer(analyzer='char_wb', ngram_range=(3,4), min_df=1) + sparse_dot_topn para top-N cosseno esparso com threshold
- Bandas de decisão propostas: auto-link >= 0.92 (com todos os gates verdes e marca identificada); revisão humana 0.75-0.92; novo candidato < 0.75. Meta de aceite: precisão do auto-link >= 0.99 medida em golden set de 1.500-2.000 pares
- Normalização de unidades: KG→G (×1000), L/LT→ML (×1000), DZ→UN (×12). Persistir quantity_value INT, quantity_unit ENUM('G','ML','UN','M','FL'), pack_count INT DEFAULT 1, total_quantity INT GENERATED, is_variable_weight BOOLEAN
- Regex de multiplicador: (?P<n>\d{1,3})\s*[xX×*]\s*(?P<v>\d+(?:[.,]\d+)?)\s*(?P<u>KG|G|GR|GRS|ML|L|LT|UN|UND)\b — ex.: '12X350ML' → pack_count=12, quantity_value=350, unit=ML, total=4200 ML
- Regex de promoção (não altera embalagem): LEVE\s*(?P<leve>\d+)\s*PAG(?:UE)?\s*(?P<pague>\d+) — grava promo_type='LEVE_PAGUE', afeta preço efetivo, nunca o produto canônico

## RECOMENDACOES
- Modelo de dados em 4 níveis, obrigatório: brand → product (produto canônico: marca + linha + variante + tamanho da unidade de consumo) → package (SKU físico: gtin14 normalizado, pack_count, indicator_digit, is_rcn) → item_alias (retailer_id, raw_description, cProd, gtin_raw, product_id, package_id, score, matcher_version, decided_by, decided_at). Preço sempre se liga a package + loja + data, nunca direto ao product.
- Armazenar TODO GTIN em campo CHAR(14) preenchido com zeros à esquerda (GTIN-8/12/13 → GTIN-14). Isso torna a chave uniforme e permite JOIN entre unidade de consumo e agrupamento. Guardar também o formato original em gtin_format enum {GTIN_8, GTIN_12, GTIN_13, GTIN_14, SEM_GTIN, CBARRA}.
- Implementar is_rcn(gtin) como função pura, testada e usada como gate ANTES de qualquer indexação: RCN se (len13 e primeiro dígito=='2') ou (len13 e prefixo em 020-029 ou 040-049) ou (len8 e primeiro dígito in {'0','2'}) ou (len14 e indicator=='9'). Quando is_rcn, gravar em rcn_code(retailer_id, code) e forçar o caminho de matching textual. Nunca criar package global a partir de RCN.
- Validar dígito verificador mod-10 (pesos 3/1 da direita para a esquerda, exceto o DV) em toda ingestão e rejeitar/quarentenar GTIN inválido, mesmo vindo de XML — protege contra erro de OCR em fotos de cupom.
- Pipeline de normalização determinística em 6 passos, versionada (matcher_version): (1) upper + unaccent + colapsar espaços + remover pontuação exceto / e vírgula decimal; (2) remover ruído de PDV (códigos numéricos isolados no início, marcadores fiscais 'F','T','*' no fim); (3) extrair embalagem por regex e REMOVER da string de texto; (4) expandir abreviações via tabela abbreviation; (5) extrair marca por dicionário de marcas (maior match, com trie); (6) ordenar tokens restantes para gerar description_key. Guardar cada saída intermediária para auditoria.
- Blocking em Postgres: coluna gerada description_norm + índice GIN gin_trgm_ops; candidate generation com `WHERE description_norm % :q ORDER BY similarity(description_norm, :q) DESC LIMIT 50`, unida (UNION) a candidatos por brand_id igual e por quantity_value/unit igual. Ajustar pg_trgm.similarity_threshold para 0.25-0.30 em nível de sessão para priorizar recall no blocking (a precisão vem no re-scoring).
- Re-scoring em Python com rapidfuzz.process.cdist(queries, candidates, scorer=fuzz.token_set_ratio, score_cutoff=60, workers=-1). Combinar em score final ponderado: 0.45*token_set_ratio + 0.25*cosine(TF-IDF char_wb 3-4gram) + 0.20*brand_match + 0.10*jaro_winkler(primeiro token). Calibrar os pesos contra o golden set, não por intuição.
- Gates determinísticos que ANULAM o score (retornam 'no match' independente da similaridade): marca diferente e ambas conhecidas; quantity_value/unit normalizados diferentes com tolerância 0; capítulo NCM (2 primeiros dígitos) diferente; token de sabor presente em um e ausente no outro; token de variante em conflito (TRAD vs EXTRA FORTE, INT vs DESN, ZERO vs sem marcação, S/LACTOSE vs sem marcação).
- Bandas de confiança: score >= 0.92 E todos os gates ok E marca identificada ⇒ auto-link; 0.75 <= score < 0.92 ⇒ review_queue com status='pending'; score < 0.75 ⇒ criar product_candidate isolado (nunca descartar o dado de preço; ele só não entra na comparação até ser resolvido). Publicar comparação de preço apenas com aliases em status='confirmed'.
- Fila de revisão humana desenhada para throughput: agrupar por cluster de candidatos (1 tela = 1 descrição crua + top-5 canônicos + preço + loja + foto do cupom se houver), atalhos de teclado (1-5 para escolher, N para novo produto, S para pular), lote de 50. Exigir 2 aprovações independentes quando o merge afetar mais de 100 registros de preço ou quando envolver produtos de marcas diferentes. Toda decisão gravada e REVERSÍVEL (soft-link com histórico).
- Golden set obrigatório antes do primeiro deploy: 1.500-2.000 pares rotulados manualmente (positivos e hard negatives: mesmo produto tamanhos diferentes, mesma marca sabores diferentes, marcas concorrentes mesma categoria). Métrica de aceite: precisão do auto-link >= 0.99 e cobertura (fração de itens auto-resolvidos) como métrica secundária. Rodar como teste de regressão em CI a cada mudança de matcher_version.
- Enriquecimento por GTIN em cascata com cache agressivo em Postgres (tabela gtin_lookup com source, fetched_at, raw_payload JSONB, TTL 180 dias): 1º catálogo interno, 2º dump local do Open Food Facts filtrado por countries_tags=en:brazil, 3º API OFF respeitando 15 req/min e User-Agent 'MelhorMercado/1.0 (contato@dominio.com.br)', 4º (somente com contrato assinado) Cosmos. Fila assíncrona com rate limiter por fonte.
- Baixar e versionar a tabela NCM oficial mensalmente do JSON do Portal Único Siscomex, e os anexos CEST do Convênio ICMS 142/2018, em tabelas ncm(codigo, descricao, descricao_concatenada, vigencia_inicio) e cest(codigo, ncm, descricao, anexo). Usar NCM apenas como gate negativo e facet — documentar isso no código para evitar que alguém use como chave depois.
- Parsing de embalagem por regex ordenada (primeira que casar vence), com testes de tabela: (a) multiplicador `(?P<n>\d{1,3})\s*[xX×*]\s*(?P<v>\d+(?:[.,]\d+)?)\s*(?P<u>KG|G|GR|GRS|ML|L|LT|UN|UND)\b` → pack_count=n, unit_value=v; (b) simples `(?P<v>\d+(?:[.,]\d+)?)\s*(?P<u>KG|G|GR|GRS|MG|ML|L|LT|LTS|UN|UND|UNID|FL|M|MT|R|ROLOS?)\b`; (c) contagem `\b(?:PACK|LEVE|C/|CX|FD|PCT)\s*(?P<n>\d{1,3})\b`; (d) promo `LEVE\s*(\d+)\s*PAG(?:UE)?\s*(\d+)` → NÃO altera o pacote, grava em promo_type/promo_params. Normalizar sempre para base: KG→G (×1000), L→ML (×1000); persistir quantity_value (int, em G ou ML ou UN), quantity_unit enum {G, ML, UN, M, FL}, pack_count int default 1, total_quantity = quantity_value*pack_count.
- Tratar item vendido a peso como classe própria: se uCom/uTrib ∈ {KG, G, KGS} ou qCom não inteiro ou is_rcn(gtin) ⇒ marcar package.is_variable_weight=true, definir quantity_unit='G' com quantity_value nulo e comparar SEMPRE por preço por quilo (vProd/qCom). Nunca comparar 'Tomate 0,732 KG' com 'Tomate UN'.
- Adiar embeddings: instrumentar a taxa de itens que caem em 'sem candidato' pelo caminho léxico; só introduzir pgvector 0.8.5 + multilingual-e5-small (halfvec 384d, índice HNSW) quando essa taxa se estabilizar acima de ~10% e a análise mostrar que a falha é semântica (sinônimo) e não de abreviação faltante no dicionário. Adicionar abreviação ao dicionário é 100x mais barato que rodar um modelo.
- Mineração contínua do dicionário: job semanal que conta tokens não reconhecidos em description_norm, ranqueia por frequência × valor de preço afetado, e apresenta os top-100 numa tela de admin para rotulagem. Isso transforma a tabela de abreviações num ativo que melhora sozinho — é a maior alavanca de qualidade do sistema.
- Copiar a modelagem de proveniência do Open Prices: Proof (arquivo original: QR, foto, PDF) → ExtractedLine (linha crua com status e predições) → Price (fato normalizado). Manter o arquivo original em S3 com hash de conteúdo e permitir reprocessar todo o histórico quando matcher_version subir (backfill idempotente).

## NAO FAZER
- NÃO usar GTIN iniciado em 2 (ou GTIN-8 iniciado em 0/2, ou GTIN-14 com indicador 9) como chave global de produto. É a decisão que mais silenciosamente corrompe o banco.
- NÃO usar NCM ou CEST como identificador de produto nem como critério suficiente de merge. NCM 0901.21.00 é 'café torrado' inteiro — todas as marcas e todos os tamanhos.
- NÃO integrar com precodahora.ba.gov.br, Menor Preço Brasil ou qualquer portal SEFAZ via as bibliotecas de 'API privada' do GitHub, nem via scraping com token/cookie extraído do site. Não há API pública documentada; a integração exigiria contornar proteção e violar termos. Alternativa legítima: pedido formal via LAI / convênio institucional com a SEFAZ estadual ou o CONFAZ, e enquanto isso operar 100% com dados enviados pelos próprios usuários.
- NÃO usar o tier gratuito do Cosmos/Bluesoft em produção comercial: os Termos vedam uso 'no contexto de quaisquer atividades empresariais e/ou profissionais' sem acordo prévio.
- NÃO tentar acessar o web service ccgConsGTIN da SEFAZ sem ser emissor de documento fiscal — ele exige certificado ICP-Brasil com o CNPJ do emitente e autenticação mútua. Não há como 'contornar' isso legitimamente.
- NÃO fazer auto-merge baseado apenas em similaridade de string, por mais alto que seja o score. Sem os gates de marca/quantidade/sabor/variante, score 0.97 ainda une produtos diferentes.
- NÃO usar fuzz.token_set_ratio isolado como decisor (retorna 100 para subconjuntos).
- NÃO começar por embeddings/LLM para o matching. O benchmark WDC Products mostra baseline simbólico batendo transformer fine-tuned em datasets pequenos/médios, e cada abreviação adicionada ao dicionário rende mais que uma rodada de fine-tuning.
- NÃO confiar em pg_trgm para comparar tokens curtos ('2L','LT','KG','UN'): palavras com menos de 3 caracteres quase não geram trigramas. Embalagem tem que ser campo estruturado, não texto.
- NÃO usar o pacote Python Unidecode sem checar licença (GPL) se o backend for distribuído; preferir unicodedata.normalize('NFKD') (stdlib) ou text-unidecode (Artistic), e unaccent no Postgres.
- NÃO descartar itens sem match — guardar o preço vinculado ao alias não resolvido. Descartar destrói dado que poderia ser recuperado quando o dicionário melhorar.
- NÃO hardcodar a tabela de abreviações em constante Python. Ela precisa ser dado versionado e editável por admin, porque vai mudar toda semana.

## RISCOS
- FALSO POSITIVO SILENCIOSO: unir 'CAFE PILAO TRAD 500G' com 'CAFE PILAO TRAD 250G' produz uma comparação de preço errada que o usuário lê como 'metade do preço'. É o risco nº1 do produto — destrói confiança e é difícil de detectar depois. Mitigação: gate de quantidade sem tolerância.
- token_set_ratio retorna 100.0 quando uma string é subconjunto da outra: 'CAFE PILAO' vs 'CAFE PILAO EXTRA FORTE 500G' pontua 100. Usar token_set_ratio isolado como critério de auto-link garante falsos positivos em massa. Sempre combinar com WRatio/token_sort_ratio e com os gates estruturados.
- COLISÃO DE RCN: dois supermercados diferentes usam o mesmo código 2xxxxxxxxxxxx para produtos completamente distintos. Se o GTIN for usado como chave global, o app mistura preço de queijo de uma rede com preço de frios de outra. Risco alto e recorrente porque esses códigos são a maioria em açougue/hortifrúti/padaria/frios.
- GTIN de balança com preço embutido muda a cada etiqueta: o mesmo produto gera milhares de 'GTINs' distintos, inflando o catálogo e destruindo métricas. Detectar por (a) prefixo 2, (b) alta cardinalidade de códigos com prefixo comum na mesma loja, e agrupar pelo prefixo de item, nunca pelo código completo.
- JURÍDICO — Cosmos: usar o tier gratuito (25 consultas/dia) para alimentar um app comercial viola expressamente a cláusula de RESTRIÇÕES DE UTILIZAÇÃO dos Termos. Consequência possível: bloqueio de conta e exposição contratual. Precisa de acordo comercial assinado antes de qualquer uso produtivo, incluindo o direito de cachear/persistir.
- JURÍDICO — ODbL do Open Food Facts: se atributos do OFF forem mesclados no registro canônico e o banco derivado for distribuído/publicado (inclusive via API pública ampla), o share-alike pode alcançar o banco inteiro. Mitigação estrutural: isolar em tabela própria com source='off'.
- JURÍDICO — Preço da Hora BA / Menor Preço Brasil: as bibliotecas de 'API privada' no GitHub acessam endpoints não documentados e protegidos. Usar isso é violação de termos e potencialmente de acesso não autorizado. Não integrar. A alternativa legítima (convênio/LAI) tem prazo longo e resultado incerto — planejar sem depender dessas fontes.
- Cobertura do Open Food Facts no Brasil (~35 mil produtos) é insuficiente e concentrada em alimentos industrializados com rótulo. Contar com ela para resolver GTINs de higiene, limpeza, bebidas ou marca própria vai frustrar a expectativa.
- Rate limits reais e baixos: OFF 15 req/min/IP (produto) e 10 req/min/IP (busca); Cosmos 25-500 consultas/DIA; Verified by GS1 web 30/dia; UPCitemdb 100/dia grátis. Um único cupom de 40 itens já estoura o tier gratuito do Cosmos. Qualquer design que enriqueça sincronamente no momento do upload vai falhar — precisa ser fila com backoff e cache.
- Ambiguidade 'LT' (lata vs litro) e 'REF' (refinado vs refil vs refrigerante) gera erro sistemático de parsing de embalagem. Sem desambiguação por contexto (categoria + presença de número antes do token), o campo quantity fica errado numa classe inteira de produtos.
- Descrição truncada perde justamente o discriminante: em campos legados de PDV com 30-40 caracteres, 'CAFE PILAO TRADICIONAL 500G' vira 'CAFE PILAO TRAD 500G' e 'REFRIG COCA COLA ZERO 2L PET' pode virar 'REFRIG COCA COLA 2L PET' — o token 'ZERO' some. Nesses casos NENHUM algoritmo consegue distinguir; a resposta correta é marcar ambiguidade e mandar para revisão, não escolher o mais provável.
- Reprocessamento não idempotente: quando o matcher_version mudar e o backfill rodar, links já confirmados por humanos podem ser sobrescritos. Regra: decisão humana sempre tem precedência sobre decisão automática, com flag decided_by='human'.
- Gargalo humano: a fila de revisão vira o limitante de crescimento. Se cada 1.000 cupons gerar 200 itens em revisão e cada revisão levar 15s, são ~50 min de trabalho humano por 1.000 cupons — inviável em escala sem gamificação/crowdsourcing (modelo do Open Prices com badges e challenges) ou sem elevar a cobertura automática.

## EM ABERTO
- Qual a fração real de itens com cEAN='SEM GTIN' ou vazio nos cupons brasileiros de supermercado? Não encontrei medição pública. Isso determina o peso relativo do caminho textual e precisa ser medido nos primeiros 10 mil cupons ingeridos antes de dimensionar a fila de revisão.
- Qual a fração de itens com GTIN de prefixo 2 (RCN de balança)? Também não medido publicamente; hipótese: alta em hortifrúti, açougue, frios e padaria. Medir por categoria.
- Preço da API do Verified by GS1 / Cadastro Nacional de Produtos da GS1 Brasil não é público. Exige contato comercial (e associação). Não confirmei valores nem se o contrato permite cachear/redistribuir atributos.
- Não verifiquei os Termos de Uso completos do Preço da Hora BA (/termos/termosecondicoes.pdf) nem o robots.txt do domínio. A conclusão de 'não integrar' é conservadora e baseada na ausência de API pública documentada + natureza privada dos endpoints usados pelas libs comunitárias.
- Nielsen: não consegui verificar cobertura, custo, licença ou existência de API acessível para startups. Tratar como fora de escopo até prova em contrário — é oferta enterprise de pesquisa de mercado, não catálogo por GTIN.
- Cobertura real de GTINs brasileiros em Datakick (gtinsearch.org) e UPCitemdb: não medida. Testar com uma amostra de 500 GTINs 789/790 antes de investir integração.
- Se o Cosmos permite persistir/cachear os dados retornados após contrato — os Termos públicos não tratam explicitamente de cache/retenção; precisa ser cláusula negociada por escrito.
- Não confirmei em fonte primária GS1 (o PDF GSCN-23-006-RCN e as GenSpecs retornaram 403/404 para fetch) o texto exato das seções sobre RCN-13/RCN-12/RCN-8. As faixas citadas vêm da página GS1 Company Prefix e da tabela consolidada de prefixos — recomendo confirmar com o PDF oficial das GS1 General Specifications antes de codificar constantes.
- A recomendação de armazenar GTIN como CHAR(14) zero-preenchido é prática consolidada de indústria, mas não confirmei a citação literal da seção correspondente nas GS1 General Specifications.
- O dicionário de abreviações apresentado é construção autoral (nenhuma tabela pública existe). Precisa ser validado e expandido empiricamente contra o corpus real de xProd — tratar os itens como hipóteses, não como fatos.
- Precisão/recall esperados por técnica não foram medidos para este domínio (descrições curtas em pt-BR truncadas). Os números do WDC Products são de e-commerce em inglês com descrições longas — indicativos de direção, não transferíveis como metas.


################################################################
# TOPICO: Algoritmo do otimizador de lista de compras multi-mercado (melhor_mercado) — formalização, MILP exato, solvers Python em 2026-07, heurísticas, tratamento de idade/confiança de preço, explicabilidade e substituições
################################################################

## RESUMO EXECUTIVO
O problema é exatamente o Internet Shopping Optimization Problem (ISOP) de Blazewicz et al. (2010) acrescido de uma restrição de cardinalidade "no máximo K lojas". É NP-difícil no sentido forte (redução pseudo-polinomial de Exact Cover by 3-Sets) e não admite aproximação (c·ln n) a menos que P=NP — o caso especial com preços zero e custo de entrega unitário é literalmente Minimum Set Cover. Estruturalmente é um Uncapacitated Facility Location NÃO-métrico com cap de cardinalidade; por isso as aproximações métricas famosas (1.488 de Shi Li) NÃO se aplicam aqui.
A descoberta prática mais importante desta pesquisa: para o tamanho real do produto (15–40 itens, 8–30 lojas candidatas, K ≤ 4) você NÃO precisa de solver algum. Enumeração exaustiva vetorizada em numpy de todos os subconjuntos de lojas com |S| ≤ K resolve o ótimo exato em 0,3–3,2 ms — 10× a 30× mais rápido que CP-SAT no mesmo problema — e entrega de graça o ranking completo, a fronteira de K, a atribuição marginal por loja e a simulação Monte Carlo de incerteza. Medi o pipeline completo (ótimo + ranking + fronteira + atribuição leave-one-out + 300 amostras Monte Carlo) em 19–26 ms para 40 itens × 25 lojas, contra um SLA de 1–2 s.
O ponto de virada medido: enumeração deixa de ser viável quando C(m,1..K) passa de ~200 mil subconjuntos (~50 ms); aí entra CP-SAT (ortools 9.15.6755, Apache-2.0), que resolveu 80×60 K=4 em 196 ms e 120×100 K=5 em 841 ms com 8 workers. Com 1 worker CP-SAT degrada catastroficamente (2 s sem provar ótimo em 80×60) — relevante para containers de 1 vCPU. HiGHS via PuLP é 2–7× mais lento que CP-SAT e, pior, PuLP 3.3.2 reporta `LpStatus == "Optimal"` mesmo quando o time limit foi atingido com solução 2× pior (só `prob.sol_status` distingue). CBC é inviável (1,5 s no caso de 30×20).
Para preços com idade e confiança diferentes: usar preço efetivo p̂ = média/mediana ponderada por w = confiança_da_fonte × 0,5^(idade/meia-vida), com meia-vidas por fonte (NFC-e 7 d, encarte oficial expira na data-fim, encarte OCR 4 d, input manual 3 d — encartes brasileiros valem tipicamente 5–7 dias), e otimizar sobre um limite superior de confiança p = p̂·(1+λσ). Medi que a IDENTIDADE do conjunto ótimo é frágil (com σ=5% ela só se mantém em 56% das simulações), mas o CUSTO do conjunto recomendado é robusto (arrependimento médio 0,33%, p95 1,54%). Isso define a linguagem honesta obrigatória: "esta combinação está entre as melhores", nunca "esta é a mais barata", e economia sempre como faixa p10–p90.

## ACHADOS

### [confirmada] O problema núcleo é exatamente o Internet Shopping Optimization Problem (ISOP) e é NP-difícil no sentido FORTE mesmo com todos os preços iguais a zero e todos os custos de deslocamento iguais a 1
Blazewicz, Kovalyov, Musial, Urbanski, Wojciechowski, 'Internet Shopping Optimization Problem', Int. J. Appl. Math. Comput. Sci. Formalização: n produtos, m lojas, N_l = multiset disponível na loja l, c_jl = custo do produto j na loja l (c_jl = infinito se j nao pertence a N_l), d_l = custo de entrega/deslocamento da loja l. Objetivo F(X) = soma_{l=1..m} ( delta(|X_l|)*d_l + soma_{j in X_l} c_jl ), onde delta(x)=0 se x=0 e 1 se x>0. Theorem 1 (texto literal do PDF): 'Problem ISOP is NP-hard in the strong sense even if all costs of the available products are equal to zero and all the delivery costs are equal to one.' Prova: transformação pseudo-polinomial de EXACT COVER BY 3-SETS (X3C). Verificado lendo o PDF original página a página.
FONTE: http://www.cs.put.poznan.pl/jblazewicz/FNP/BKMUW_amcs10.pdf

### [confirmada] Não existe algoritmo de aproximação polinomial (c·ln n) para o ISOP a menos que P = NP
Statement 1 do mesmo paper, texto literal: 'There exists no polynomial (c · ln n)-approximation algorithm for problem ISOP, unless P = NP.' Justificativa: o caso especial com custo de produto zero em qualquer loja e custo de entrega 1 é equivalente a MINIMUM SET COVER, e Raz & Safra (1997) provaram inaproximabilidade de Set Cover dentro de c·ln|S|. Consequência prática: qualquer garantia teórica que você prometer para a heurística será, no pior caso, logarítmica — não constante. Não prometa 'ótimo garantido' via heurística.
FONTE: http://www.cs.put.poznan.pl/jblazewicz/FNP/BKMUW_amcs10.pdf

### [provavel] Com o cap de K lojas, até DECIDIR viabilidade (existe conjunto de ≤K lojas que cobre todos os itens?) é NP-completo
Inferência direta minha (não é teorema citado): tome preços = 0 e custos de deslocamento = 0; a pergunta 'existe S com |S| ≤ K tal que todo item i tem A_i ∩ S ≠ vazio' é literalmente a versão de decisão de Set Cover com universo = itens e conjuntos = lojas. Logo NP-completo. Implicação de engenharia: NÃO modele cobertura como restrição dura sem válvula de escape — use variável de folga u_i com penalidade M_i, senão o modelo vira infactível e o endpoint devolve erro em vez de 'faltam 3 itens'.


### [provavel] As aproximações métricas famosas de Facility Location (fator 1.488) NÃO se aplicam a este problema
O resultado 1.488 de Shi Li (ICALP 2011) é para METRIC Uncapacitated Facility Location, onde os custos de conexão satisfazem desigualdade triangular. Aqui o 'custo de conexão' cliente-facilidade é o PREÇO do item na loja, que não é métrico (não há desigualdade triangular entre preços). O benchmark teórico correto é o guloso de Set Cover, H_n = ln n + 1. Cuidado ao citar 1.488 em documento de arquitetura — seria incorreto.
FONTE: https://tcs.nju.edu.cn/shili/papers/UFL-ICALP2011.pdf

### [provavel] Se você algum dia incluir a ROTA (ordem de visita) dentro do modelo, o problema vira Traveling Purchaser Problem, que contém UFL, Set Cover e Group Steiner Tree como casos especiais
Recomendação decorrente: NÃO coloque roteamento dentro do MILP. Use custo aditivo por loja f_s = 2*d(casa,s)*kappa + tau na etapa 1, e re-precifique a rota exata (TSP sobre {casa} ∪ S ∪ {casa}) apenas para os top-N conjuntos candidatos na etapa 2. Com K ≤ 5 são no máximo 5! = 120 permutações por conjunto → microssegundos.
FONTE: https://en.wikipedia.org/wiki/Traveling_purchaser_problem

### [confirmada] MEDIÇÃO PRÓPRIA: enumeração exaustiva vetorizada em numpy resolve o ÓTIMO EXATO mais rápido que qualquer solver nos tamanhos reais do produto
Bancada: Apple M5 Pro (5 P-cores + 10 E-cores, 15 lógicos), 24 GB, macOS 26.5.2, Python 3.12.7, numpy 2.5.1. Média de 5 instâncias sintéticas, densidade de disponibilidade 0,65. Resultados (todos batem exatamente com CP-SAT com 10 s de limite): 30 itens x 20 lojas K=3 → 1.350 subconjuntos, 0,3 ms; 30x20 K=4 → 6.195, 1,2 ms; 40x25 K=4 → 15.275, 3,2 ms; 30x20 K=5 → 21.699, 4,8 ms; 50x40 K=4 → 102.090, 24,1 ms; 40x30 K=5 → 174.436, 41,7 ms; 40x25 K=6 → 245.505, 68,1 ms; 60x40 K=5 → 760.098, 217 ms; 80x60 K=5 → 5.985.197, 2.097 ms. Núcleo: matriz densa P (n x m) em centavos com +inf onde indisponível; para um lote de conjuntos C (B x k): line = min(P[:,C], axis=2), clamp com M_i, custo = line.sum(0) + f[C].sum(1).


### [confirmada] MEDIÇÃO PRÓPRIA: o PONTO DE VIRADA para abandonar enumeração exata é ~200.000 subconjuntos (~50 ms)
Fórmula operacional: N_sub = soma_{k=1..K} C(m,k). Se N_sub <= 200.000 → enumeração exata (numpy). Se 200.000 < N_sub <= 5.000.000 → CP-SAT com time limit. Se N_sub > 5.000.000 ou m > 80 → guloso incremental + busca local, sem solver. Casos práticos: C(20,1..3)=1.350; C(25,1..4)=15.275; C(30,1..3)=4.525; C(40,1..4)=102.090; C(60,1..5)=6.0M. Como no produto real m (lojas no raio) raramente passa de 30 e K raramente passa de 3, você fica permanentemente na faixa de enumeração exata.


### [confirmada] MEDIÇÃO PRÓPRIA: CP-SAT (ortools 9.15.6755) com 8 workers resolve 30 itens x 20 lojas K=3 em p50 12,5 ms / p95 22,5 ms, incluindo construção do modelo
40 instâncias por configuração, time limit 1,0 s, 100% status OPTIMAL. Latências (p50/p95/max, ms, incluindo build do modelo em Python): 15x8 K=3 → 3,9/8,7/284; 30x20 K=3 → 12,5/22,5/26,0; 40x25 K=4 → 18,2/28,0/32,2; 60x40 K=4 → 59,6/112,8/137,2. O max de 284 ms em 15x8 é o warm-up de carregamento da libortools no primeiro solve do processo — faça um solve dummy no startup do worker FastAPI. Tempo de construção do modelo em Python: 3,2 ms para 435 binárias; 134 ms para 26.287 binárias (o build vira gargalo antes do solver).
FONTE: https://pypi.org/project/ortools/

### [confirmada] MEDIÇÃO PRÓPRIA: CP-SAT com num_workers=1 degrada catastroficamente — risco direto para containers de 1 vCPU
Mesmas instâncias, time limit 1 s: 60x40 K=4 com 1 worker → p50 1.008 ms e apenas 42,5% das instâncias provadas ótimas; com 8 workers → p50 59,6 ms e 100% ótimas. 50x40 K=4 com 1 worker: 642 ms (vs 29 ms com 8). Em 80x60 K=4, 1 worker estoura 2 s com gap de 0,76%. Causa documentada: CP-SAT é um portfólio — com 1 worker só o subsolver default roda; com >=2 entram LNS; com >=5 entra o first-solution subsolver; com 32 rodam todos os 15 full-problem subsolvers. Se o container tiver 1-2 vCPU, NÃO conte com CP-SAT: use enumeração numpy (single-thread e determinística).
FONTE: https://d-krupke.github.io/cpsat-primer/parameters.html

### [confirmada] ARMADILHA CRÍTICA MEDIDA: PuLP 3.3.2 + HiGHS reporta LpStatus == 'Optimal' mesmo quando o time limit foi atingido, com solução 2x pior que o ótimo
Reproduzido: instância 200 itens x 200 lojas K=5 com pulp.HiGHS(msg=False, timeLimit=0.5) → prob.status == 1 e pulp.LpStatus[prob.status] == 'Optimal', objetivo R$18.825,81, wall clock real 1,915 s (o timeLimit NÃO limita build/presolve). A mesma instância com timeLimit=30 → R$9.423,22. O campo que distingue é prob.sol_status: 1 = LpSolutionOptimal ('Optimal Solution Found') quando realmente provado, 2 = LpSolutionIntegerFeasible ('Solution Found') quando só factível. Mapa completo medido: {0:'No Solution Found', 1:'Optimal Solution Found', 2:'Solution Found', -1:'No Solution Exists', -2:'Solution is Unbounded'}. REGRA: se usar PuLP, cheque prob.sol_status == 1, nunca prob.status == 1.
FONTE: https://pypi.org/project/PuLP/

### [confirmada] ARMADILHA CRÍTICA MEDIDA: ortools 9.15.6755 e highspy 1.15.1 NÃO carregam no mesmo processo Python (colisão de símbolos do HiGHS embutido na libortools)
Em macOS arm64 (Python 3.12.7): importar ortools primeiro e depois highspy → SIGSEGV (exit 139). Importar highspy primeiro e depois ortools → ImportError: dlopen(.../ortools/sat/python/cp_model_helper.so): Symbol not found: __Z19setLocalOptionValueRK15HighsLogOptionsRK...basic_string...; Referenced from libortools.9.dylib; Expected in highspy/libhighs.1.dylib. Causa: OR-Tools empacota sua própria cópia do HiGHS. Consequência: escolha UM dos dois no requirements.txt do serviço, ou isole em processos/containers separados. Em Linux/glibc o comportamento pode diferir (RTLD_LOCAL) — testar antes de assumir.


### [confirmada] MEDIÇÃO PRÓPRIA: qualidade das heurísticas — guloso incremental fica 0,1% a 2,0% acima do ótimo; guloso + busca local fica 0,0% a 0,2%
Gaps médios (5 seeds) vs ótimo do CP-SAT. Guloso incremental: 20x10K3 +0,24%; 30x20K3 +1,12%; 50x40K4 +1,30%; 80x60K4 +1,96%; 120x100K5 +1,11%; 200x200K5 +0,13%. Guloso + busca local (drop/swap/add): +0,24%, +0,19%, +0,09%, +0,08%, +0,01%, -0,80% (em 200x200 a heurística BATE o CP-SAT truncado em 2 s). Beam search W=8: +0,00% a +0,48%. Baseline 'melhor loja única': +20,2% a +47,0% (é a referência para o número de economia, não uma solução). Tempos em Python puro: guloso 0,1–41,7 ms; guloso+LS 0,2–206 ms; beam 0,4–314 ms; single 0,03–4,7 ms.


### [confirmada] BUG DE DESIGN que eu encontrei implementando: o guloso incremental NUNCA arranca se cost(S) for +infinito quando S não cobre todos os itens
Com cobertura dura, cost([s]) = +inf para toda loja única (nenhuma loja tem todos os 30 itens), então nenhum candidato é 'melhor que o incumbente +inf' e o guloso retorna conjunto vazio. Correção obrigatória: definir cost(S) com penalidade de falta M_i por item não coberto, exatamente a mesma variável u_i do MILP. M_i sugerido = 1,6 * q_i * max_s p_is (o custo de comprar em outro lugar depois). Isso torna a função monotonicamente avaliável desde S = vazio.


### [confirmada] MEDIÇÃO PRÓPRIA: sob incerteza de preço, a IDENTIDADE do conjunto ótimo é frágil mas o CUSTO da recomendação é robusto
Monte Carlo, 30 itens x 20 lojas K=3, 8 instâncias x 200 sorteios, ruído multiplicativo gaussiano de desvio sigma sobre cada preço, ótimo recalculado por força bruta exata a cada sorteio. Resultados (sigma → P(conjunto recomendado continua ótimo) / arrependimento médio / arrependimento p95): 2% → 86,9% / 0,04% / 0,30%; 5% → 56,2% / 0,33% / 1,54%; 10% → 26,2% / 1,41% / 4,40%; 20% → 7,9% / 5,43% / 13,38%. Interpretação para o produto: mesmo com dados de 5% de ruído a recomendação custa apenas ~0,3% a mais que o ótimo verdadeiro, mas há quase 44% de chance de existir outro conjunto empatado ou melhor. Por isso a copy correta é 'entre as melhores combinações', e por isso vale mostrar 2-3 alternativas.


### [confirmada] MEDIÇÃO PRÓPRIA: o pipeline COMPLETO do request (ótimo exato + ranking top-20 + fronteira de K + atribuição leave-one-out + 300 amostras Monte Carlo) roda em 19–26 ms para 40 itens x 25 lojas
Medido: 15x8 K=3 → 22,3 ms média / 35,6 ms max; 30x20 K=3 → 19,2/19,9 ms; 40x25 K=3 → 22,0/26,2 ms; 40x25 K=4 → 25,3/26,0 ms; 50x40 K=4 → 62,2/97,0 ms. Tudo em numpy puro, single-thread, sem solver. Exemplo de saída para 40x25 K=4: fronteira K=1: R$2.684,05; K=2: R$2.155,21; K=3: R$2.047,77; K=4: R$2.005,16 — mostra visualmente que a 4a loja só economiza R$42,61 e deixa o usuário decidir. Atribuição leave-one-out do conjunto vencedor: loja4 +R$78,57, loja12 +R$121,49, loja18 +R$110,72, loja19 +R$130,66. Economia reportada como faixa p10..p90 = R$647,36..R$735,34 (p50 R$693,99).


### [provavel] Encartes de supermercado no Brasil valem tipicamente 5 a 7 dias — âncora empírica para a meia-vida de frescor
Exemplo concreto observado: Supermercados Guanabara com encarte válido de 18/07/2026 a 22/07/2026 (5 dias). O padrão dominante no varejo alimentar brasileiro é tabloide semanal, frequentemente 'quinta a domingo'. Isso justifica: encarte com data-fim explícita NÃO decai — ele EXPIRA (peso 1,0 até a data-fim, 0 depois); encarte sem data-fim → meia-vida 4 dias. Não confirmei estatística agregada de duração média por fonte oficial (ABRAS/Nielsen); tratar o número como calibração inicial a ser ajustada com os próprios dados.
FONTE: https://www.supermercadosguanabara.com.br/encarte

### [confirmada] CP-SAT exige coeficientes INTEIROS em restrições; aceita float apenas no objetivo, e internamente usa aritmética int64
Consequência de implementação obrigatória: armazenar e otimizar todos os preços em CENTAVOS como int (Postgres NUMERIC(12,2) na tabela, mas int64 no otimizador). Se você multiplicar q_i (até ~24 unidades) por p_is (até ~50.000 centavos) e somar 200 itens, o objetivo chega a ~2,4e8 — muito longe do overflow de int64, seguro. Evite escalar preços por fatores de confiança em float e passar direto: arredonde para centavo inteiro (round-half-up) ANTES de montar o modelo, e mantenha o float só para exibição.
FONTE: https://github.com/google/or-tools/blob/stable/ortools/sat/sat_parameters.proto

### [confirmada] Versões e licenças confirmadas em 2026-07-22 dos solvers candidatos
ortools 9.15.6755, PyPI 2026-01-14, tag GitHub v9.15 publicada 2026-01-12, licença Apache-2.0, Python 3.9–3.14. highspy 1.15.1, PyPI e GitHub 2026-07-02, licença MIT, Python >=3.9. PuLP 3.3.2, PyPI 2026-05-25, licença MIT, Python >=3.10 — ATENÇÃO: existem prereleases 4.0.0a10/a11/a12 (2026-06-19) no GitHub; não pinar alpha. python-mip ('mip') 1.17.6, 2026-03-23, licença EPL-2.0 (copyleft fraco — verificar compatibilidade jurídica antes de embarcar), Python 3.10–3.13. CBC via PuLP: medido 1.512 ms para 30x20 K=3 (roda como subprocesso com I/O de arquivo LP) — inviável para SLA de 1-2 s.
FONTE: https://github.com/ERGO-Code/HiGHS/releases

### [confirmada] MEDIÇÃO PRÓPRIA: HiGHS via PuLP é 2–7x mais lento que CP-SAT nas mesmas instâncias
Tempos de solve (média de 5 seeds, time limit 2 s): 30x20 K=3 → HiGHS 15,4 ms vs CP-SAT 9,0 ms; 30x20 K=4 → 19,2 vs 8,5; 50x40 K=4 → 68,7 vs 29,3; 80x60 K=4 → 1.319,8 vs 196,0; 120x100 K=5 → 2.187,6 (estourou limite, resultado +39,5% pior) vs 841,4 (ótimo). Parte da lentidão é o overhead de montar o modelo via objetos PuLP; a API nativa highspy provavelmente reduz isso, mas não medi highspy nativo (bloqueado pela colisão com ortools no mesmo processo).


### [provavel] Art. 37 do CDC (Lei 8.078/1990) define publicidade enganosa incluindo enganosidade POR OMISSÃO — isso alcança diretamente como o app apresenta economia e frescor de preço
Art. 37, §1º: enganosa é qualquer modalidade de informação ou comunicação de caráter publicitário, inteira ou parcialmente falsa, ou, por qualquer outro modo, mesmo por omissão, capaz de induzir em erro o consumidor a respeito da natureza, características, qualidade, quantidade, propriedades, origem, PREÇO e quaisquer outros dados sobre produtos e serviços. §3º: é enganosa por omissão a publicidade que deixar de informar sobre dado essencial do produto ou serviço. Art. 30: toda informação ou publicidade suficientemente precisa obriga o fornecedor e integra o contrato. Não consegui buscar o planalto.gov.br diretamente (ECONNRESET repetido); texto confirmado por fontes secundárias brasileiras incluindo material do Procon-SP e do TJDFT. Implicação: exibir preço de 20 dias atrás sem sinalizar a data é omissão de dado essencial; o app não é fornecedor do produto, mas responde pelo que ele próprio publica.
FONTE: https://www.procon.sp.gov.br/wp-content/uploads/2025/02/CDC_2025.pdf

### [confirmada] A formulação DESAGREGADA (y_is <= x_s) é obrigatória; a agregada (soma_i y_is <= n·x_s) tem relaxação linear muito mais fraca
Resultado clássico de Facility Location confirmado em múltiplas fontes: a relaxação LP da formulação com restrições de ligação individuais y_is <= x_s é muito mais forte que a da versão agregada, porque a agregada admite x_s fracionário arbitrariamente pequeno (x_s = 1/n basta para liberar um item). Custo: soma_i |A_i| restrições em vez de m. Para 30x20 com densidade 0,65 isso é ~390 restrições — irrelevante. NUNCA use a versão agregada aqui.
FONTE: https://scipbook.readthedocs.io/en/latest/flp.html

### [provavel] Variante com múltiplas unidades por item (ISHOP-U) e variante com descontos por limiar (Clever Shopper) também são NP-difíceis, com casos FPT conhecidos
The Clever Shopper Problem (CSR 2018 / Theory of Computing Systems 2019, arXiv 1802.07944): variante do Internet Shopping com descontos por limiar de gasto; NP-difícil no caso geral; algoritmos exatos para instâncias em que cada loja vende só dois itens; FPT no número de itens e FPT no número de lojas quando todos os preços são uniformes; apresenta algoritmo de aproximação e resultados de dureza para o problema de maximizar a soma de descontos. ISHOP-U (Mathematics 10(14):2513, 2022) trata múltiplas unidades por item com prova de NP-completude e otimização evolutiva — não consegui abrir o PDF (MDPI devolveu 403), então os detalhes da formulação vêm de snippet de busca.
FONTE: https://arxiv.org/abs/1802.07944

## ESPECIFICACOES CONCRETAS
- FORMULAÇÃO MILP COMPLETA (usar esta, textualmente, no doc de arquitetura).

CONJUNTOS E PARÂMETROS
  I  = itens da lista, i ∈ I, n = |I|
  S  = lojas candidatas dentro do raio, s ∈ S, m = |S|
  A_i ⊆ S = lojas com preço VÁLIDO (não expirado, confiança >= theta_min) para o item i  [esparsidade]
  q_i ∈ Z+   = quantidade desejada do item i
  p_is ∈ Z+  = preço efetivo esperado UNITÁRIO do item i na loja s, em CENTAVOS INTEIROS (já ajustado por frescor/confiança)
  f_s ∈ Z+   = custo fixo de visitar a loja s (deslocamento + tempo), centavos
  M_i ∈ Z+   = penalidade por não conseguir comprar o item i, centavos
  K ∈ Z+     = número máximo de lojas visitadas
  c_s ∈ Z+   = ticket mínimo da loja s (opcional, 0 se não houver)

VARIÁVEIS
  x_s   ∈ {0,1}   loja s é visitada
  y_is  ∈ {0,1}   item i (quantidade inteira) é comprado na loja s   — DEFINIDA APENAS PARA s ∈ A_i
  u_i   ∈ {0,1}   item i não foi comprado em nenhuma loja escolhida

OBJETIVO
  min Z = Σ_{i∈I} Σ_{s∈A_i} q_i · p_is · y_is   +   Σ_{s∈S} f_s · x_s   +   Σ_{i∈I} M_i · u_i

RESTRIÇÕES
  (C1) Σ_{s∈A_i} y_is + u_i = 1                     ∀ i ∈ I          [cobertura com folga]
  (C2) y_is ≤ x_s                                    ∀ i ∈ I, ∀ s ∈ A_i [ativação DESAGREGADA]
  (C3) Σ_{s∈S} x_s ≤ K                                                [cap de lojas]
  (C4) Σ_{i∈I} q_i · p_is · y_is ≥ c_s · x_s         ∀ s ∈ S          [ticket mínimo, opcional]
  (C5) x_s, y_is, u_i ∈ {0,1}

TAMANHO
  binárias  = m + n + Σ_i |A_i| ≈ m + n + n·m·ρ  (ρ = densidade de disponibilidade)
  restrições = n + Σ_i |A_i| + 1 (+ m se C4)
  Para n=30, m=20, ρ=0,65 → 435 binárias, 421 restrições (medido).

EXTENSÕES ÚTEIS
  (E1) uma loja por bandeira/rede r:  Σ_{s ∈ rede r} x_s ≤ 1
  (E2) loja obrigatória (usuário fixou):  x_s = 1
  (E3) item essencial (não pode faltar):  u_i = 0
  (E4) permitir dividir a quantidade de um item entre lojas: trocar y_is binário por w_is ∈ Z, 0 ≤ w_is ≤ q_i, com Σ_s w_is + q_i·u_i = q_i e w_is ≤ q_i·x_s. NÃO RECOMENDADO (UX ruim, modelo maior).
  (E5) NÃO coloque a rota no modelo — vira Traveling Purchaser Problem.
- PSEUDOCÓDIGO 1 — AVALIAÇÃO EXATA DE UM CONJUNTO DE LOJAS (base de todas as heurísticas)

def cost(S, price, q, f, M, n):
    # S: lista/conjunto de índices de loja. Retorna (custo_em_centavos, assign)
    if not S:
        return sum(M), {}                       # nada comprado: paga toda a penalidade
    total = sum(f[s] for s in S)
    assign = {}
    for i in range(n):
        best, bs = M[i], None                   # opção 'não comprar' é sempre viável
        for s in S:
            p = price.get((i, s))
            if p is not None:
                c = q[i] * p
                if c < best:
                    best, bs = c, s
        total += best
        if bs is not None:
            assign[i] = bs
    return total, assign

# Complexidade O(n·|S|). CRÍTICO: o fallback M[i] é o que permite avaliar conjuntos
# que não cobrem a cesta inteira. Sem ele o guloso trava em S = vazio.
- PSEUDOCÓDIGO 2 — GULOSO INCREMENTAL POR GANHO MARGINAL (gap medido: +0,1% a +2,0%; 0,1–42 ms)

def greedy_incremental(stores, K):
    S = []
    best, _ = cost(S)
    while len(S) < K:
        cand, cbest = None, best
        for s in stores:
            if s in S: continue
            c, _ = cost(S + [s])
            if c < cbest - 1:                    # -1 centavo = epsilon anti-empate
                cbest, cand = c, s
        if cand is None:
            break                                # nenhuma loja adicional compensa o próprio f_s
        S.append(cand); best = cbest
    return S, best

# Complexidade O(K² · m · n). Para n=30,m=20,K=3 ≈ 5.400 avaliações de item → sub-ms em C, ~0,3 ms em Python.
# Propriedade: a parada natural (cand is None) já respeita o trade-off custo de deslocamento vs economia.
- PSEUDOCÓDIGO 3 — BUSCA LOCAL DROP / SWAP / ADD (gap medido: +0,0% a +0,2%; 0,2–206 ms)

def local_search(S, stores, K, max_iter=200):
    best, _ = cost(S)
    for _ in range(max_iter):
        improved = False
        # 1) DROP: tirar uma loja compensa? (economiza f_s, encarece itens)
        for s in list(S):
            T = [z for z in S if z != s]
            c, _ = cost(T)
            if c < best - 1: S, best, improved = T, c, True; break
        if improved: continue
        # 2) SWAP 1-1: trocar uma loja de dentro por uma de fora
        for s in list(S):
            for t in stores:
                if t in S: continue
                T = [z for z in S if z != s] + [t]
                c, _ = cost(T)
                if c < best - 1: S, best, improved = T, c, True; break
            if improved: break
        if improved: continue
        # 3) ADD: cabe mais uma loja dentro do cap?
        if len(S) < K:
            for t in stores:
                if t in S: continue
                T = S + [t]
                c, _ = cost(T)
                if c < best - 1: S, best, improved = T, c, True; break
        if not improved:
            return S, best                       # ótimo local em 1-vizinhança
    return S, best
- PSEUDOCÓDIGO 4 — BEAM SEARCH (largura W=8; gap medido +0,0% a +0,5%; 0,4–314 ms)

def beam_search(stores, K, W=8):
    beam = [((), cost([])[0])]
    best = beam[0]
    for _ in range(K):
        cands = {}
        for (S, _) in beam:
            for s in stores:
                if s in S: continue
                T = tuple(sorted(S + (s,)))
                if T in cands: continue
                cands[T] = cost(list(T))[0]
        if not cands: break
        beam = sorted(cands.items(), key=lambda kv: kv[1])[:W]
        if beam[0][1] < best[1]: best = beam[0]
    return list(best[0]), best[1]
- PSEUDOCÓDIGO 5 — ENUMERAÇÃO EXATA VETORIZADA (RECOMENDADA como caminho principal; 0,3–3,2 ms nos tamanhos reais)

import itertools, numpy as np

def enumerate_exact(P, M, f, m, K, batch=4096):
    # P: (n, m) float32/float64 com CUSTO DE LINHA q_i*p_is em centavos, +inf onde indisponível
    # M: (n,) penalidade de falta por item;  f: (m,) custo fixo por loja
    best, bS = float(M.sum()), ()
    for k in range(1, K + 1):
        C = np.fromiter(itertools.chain.from_iterable(itertools.combinations(range(m), k)),
                        dtype=np.int32).reshape(-1, k)
        for a in range(0, C.shape[0], batch):
            B = C[a:a+batch]                      # (b, k)
            line = P[:, B].min(axis=2)            # (n, b)  custo do item na melhor loja do conjunto
            np.minimum(line, M[:, None], out=line)# permite 'não comprar'
            tot = line.sum(axis=0) + f[B].sum(axis=1)
            j = int(tot.argmin())
            if tot[j] < best: best, bS = float(tot[j]), tuple(B[j])
    return best, bS

# Memória do lote: n · batch · k · 8 bytes. Para n=80, batch=4096, k=5 → 13 MB. Use float32 para metade disso.
# Guardando tot inteiro em vez de só o argmin você ganha DE GRAÇA: ranking top-N, fronteira de K,
# alternativas para o Monte Carlo e explicação — que é exatamente o que a UX honesta precisa.
- FÓRMULA DE PREÇO EFETIVO ESPERADO (frescor × confiança) — proposta calibrável

Para cada observação o de preço do par (item i, loja s):
  v_o     = valor observado (centavos)
  Δ_o     = idade em dias (agora - t_observação)
  src_o   = fonte

1) FRESCOR — decaimento exponencial com meia-vida H_src:
     F_o = 0,5 ^ (Δ_o / H_src)
   Meia-vidas iniciais (calibrar com dados próprios):
     NFC-e via QR Code (preço efetivamente pago)   H = 7 dias
     Nota fiscal fotografada + OCR                 H = 7 dias
     Encarte oficial COM data-fim                  F = 1,0 até data-fim; 0 depois (EXPIRA, não decai)
     Encarte importado sem data-fim                H = 4 dias
     Preço digitado manualmente pelo usuário       H = 3 dias
   Âncora empírica: encartes brasileiros valem tipicamente 5–7 dias.

2) CONFIANÇA DA FONTE C_src ∈ [0,1]:
     NFC-e autenticada (chave de acesso validada)  0,98
     OCR de cupom com CNPJ + chave legíveis        0,90
     Encarte oficial de fonte institucional        0,85
     OCR de foto de encarte                        0,70
     Input manual do usuário                       0,50

3) PESO DA OBSERVAÇÃO:  w_o = C_src(o) · F_o

4) PREÇO PONTUAL — mediana ponderada (mais robusta a outlier de OCR que a média):
     p̂_is = weighted_median({v_o}, {w_o})
   (se houver < 3 observações, use média ponderada Σ w_o·v_o / Σ w_o)

5) CONFIANÇA AGREGADA DO PAR:
     θ_is = min(0,99 , 1 - Π_o (1 - w_o))

6) INCERTEZA RELATIVA:
     σ_is = clamp( σ0 + β·(1 - θ_is) + γ·(Δ̄_is / H_src) , 0,02 , 0,35 )
     com σ0 = 0,02 ; β = 0,15 ; γ = 0,03 ; Δ̄ = idade média ponderada.

7) PREÇO USADO NO OTIMIZADOR (upper confidence bound — penaliza incerteza):
     p_is = round_half_up( p̂_is · (1 + λ · σ_is) )      [centavos inteiros]
     λ = 1,0 padrão (≈1 desvio). λ = 0 → ingênuo. λ = 1,65 → percentil 95 (muito conservador).

8) PORTÃO DE DESCARTE (não entra em A_i, não aparece na UI):
     θ_is < 0,25  OU  Δ_o > 30 dias  OU  encarte com data-fim vencida  OU  |v_o - mediana| > 3·MAD

9) RÓTULO EXIBIDO:  θ ≥ 0,80 → 'confirmado' ; 0,50–0,80 → 'provável' ; 0,25–0,50 → 'estimado'
   SEMPRE junto com a data: 'R$ 24,90 — cupom fiscal de 2 dias atrás'.

Nota de honestidade: σ0, β, γ e as meias-vidas são PROPOSTA MINHA, não valores validados por fonte.
Calibre medindo, no seu próprio banco, o erro |preço previsto - preço observado no próximo cupom|
em função da idade e da fonte, e ajuste H e σ por regressão. Guarde os parâmetros em tabela, não em código.
- ECONOMIA HONESTA — procedimento executável (medido: 300 amostras custam <20 ms)

1) Calcule o baseline B = melhor loja ÚNICA (custo total comprando tudo em uma loja só, incluindo f_s).
   É o que o usuário faria sem o app — é a referência justa. (Medido: 20% a 47% pior que o ótimo nas instâncias sintéticas;
   no mundo real espere bem menos, esse número está inflado pelo ruído sintético.)
2) Guarde os top-N conjuntos (N = 20) do ranking exato.
3) Monte Carlo, T = 300 sorteios: para cada sorteio t, perturbe cada preço
     v_is^(t) = p̂_is · max(0,5, 1 + N(0, σ_is))
   e reavalie APENAS o conjunto recomendado S* e o baseline B (O(T·n·K), microssegundos).
4) Economia_t = custo(B, v^(t)) - custo(S*, v^(t)). Ordene e reporte p10, p50, p90.
5) EXIBIR: 'Economia estimada entre R$ 647 e R$ 735 comparado a comprar tudo no <loja B>.'
   NUNCA: 'Você economiza R$ 693,99.'
6) Regra de supressão: se σ médio ponderado da cesta > 0,10, esconda o número e mostre só
   'os preços desta cesta estão desatualizados — a economia pode variar bastante' (evidência: com σ=10%
   o arrependimento p95 já é 4,4% e a identidade do conjunto ótimo só se sustenta em 26% dos cenários).
7) Rodapé obrigatório: 'Comparação limitada às lojas e aos preços que temos na base, coletados em <datas>.
   Preços podem ter mudado.' (mitiga enganosidade por omissão — CDC art. 37 §3º).
- EXPLICAÇÃO LEGÍVEL — determinística, por template, SEM LLM no request

Bloco A — Fronteira de K (o mais valioso; sai de graça da enumeração):
  'Com 1 loja: R$ 2.684,05 · Com 2: R$ 2.155,21 (−R$ 528,84) · Com 3: R$ 2.047,77 (−R$ 107,44) · Com 4: R$ 2.005,16 (−R$ 42,61)'
  → deixa o usuário decidir se a 4ª parada vale R$ 42,61. Isto é honestidade estrutural, não copy.

Bloco B — Valor marginal por loja (leave-one-out exato, K avaliações):
  Δ_s = custo(S* \ {s}) − custo(S*)
  'Ir ao Assaí Centro economiza R$ 121,49 a mais do que não ir. Ele carrega 11 dos 30 itens.'

Bloco C — Justificativa por item (só para os 5 maiores Δ absolutos, senão vira ruído):
  'Arroz tipo 1 5 kg — R$ 24,90 no Assaí. R$ 3,10 abaixo da média das lojas próximas (R$ 4,98/kg vs R$ 5,60/kg).
   Preço de cupom fiscal de 2 dias atrás. [confirmado]'

Bloco D — O que ficou de fora e por quê:
  'Não incluímos o Extra Norte: economizaria R$ 18 em produtos, mas o deslocamento custa R$ 27.'
  'Fermento em pó: nenhuma das 3 lojas escolhidas tem preço recente. Sugerimos comprar junto.'

Bloco E — Alternativas empatadas (usa o ranking, evita falsa precisão):
  'Outras 2 combinações ficam a menos de 1% deste custo: [Assaí+Bompreço] R$ 2.011 · [Assaí+Atacadão] R$ 2.018.'

REGRAS DE COPY (proibições duras):
  - Proibido: 'o mais barato da cidade', 'o menor preço do Brasil', 'garantimos'.
  - Obrigatório: 'entre as lojas que conhecemos', 'com base em preços de <data mais antiga> a <data mais recente>'.
  - Todo preço exibido com a idade ao lado. Idade > 7 dias → badge visual de alerta.
- SUBSTITUIÇÕES / EQUIVALENTES — modelo e trilhos de segurança

MODELO (extensão do MILP):
  G_i = conjunto de variantes aceitáveis para o item i (curado, ver abaixo). g ∈ G_i.
  π_ig ∈ Z+ = penalidade de troca em centavos (desutilidade de aceitar a variante g no lugar do pedido).
  Variável: y_{i,g,s} ∈ {0,1}, definida para g ∈ G_i e s ∈ A_g.
  (C1') Σ_{g∈G_i} Σ_{s∈A_g} y_{i,g,s} + u_i = 1     ∀ i
  (C2') y_{i,g,s} ≤ x_s                              ∀ i,g,s
  Objetivo += Σ_{i,g,s} ( q_i · p_gs + π_ig ) · y_{i,g,s}

CALIBRAÇÃO DE π (proposta):
  variante exata (mesmo GTIN)                       π = 0
  mesma marca, gramatura diferente                  π = 0,10 · p̂  (e SEMPRE comparar por R$/kg ou R$/L)
  marca diferente, mesma categoria e tipo           π = 0,25 · p̂
  qualquer outra coisa                              variante EXCLUÍDA de G_i (não é π alto, é ausência)

TRILHOS DE SEGURANÇA (não negociáveis — 'nunca trocar por algo pior em silêncio'):
  1. Opt-in POR LINHA da lista: campo substitutable ∈ {'exact','same_brand','any_equivalent'}.
     Default = 'exact' para itens vindos de cupom fiscal escaneado. 'any_equivalent' só com ação explícita.
  2. Comparação obrigatória por PREÇO POR UNIDADE PADRÃO (R$/kg, R$/L, R$/un). Sem isso, 'mais barato'
     vira mentira de embalagem menor — o erro mais comum e mais indefensável deste tipo de produto.
  3. Taxonomia de equivalência CURADA (tabela no banco, revisada por humano). Embeddings/LLM podem
     SUGERIR candidatos para uma fila de revisão; NUNCA decidir equivalência em runtime.
  4. Bloqueios duros — nunca substituir automaticamente quando diferir em: teor (integral/desnatado/zero/diet),
     restrição alimentar declarada (sem glúten, sem lactose), alergênico, princípio ativo ou dosagem
     (qualquer item de farmácia), tipo/classificação declarada (arroz tipo 1 vs tipo 2), ou item para bebê.
  5. Toda substituição aplicada aparece no resultado com nome completo, preço unitário normalizado,
     delta em reais e botão [Desfazer]:
     'Trocamos Arroz Tio João 5 kg (R$ 27,90 / R$ 5,58 por kg) por Arroz Camil 5 kg (R$ 24,50 / R$ 4,90 por kg)
      — economia R$ 3,40. [Manter original]'
  6. Persistir substitution_reason e o π aplicado, para auditoria e para aprender a preferência do usuário.
  7. Se o total de substituições > 30% dos itens, mostrar aviso agregado antes do resultado, não depois.
- ARQUITETURA DO SERVIÇO — decisão recomendada

Caminho A (padrão, 99% dos requests): enumeração exata numpy.
  Gatilho: N_sub = Σ_{k=1..K} C(m,k) ≤ 200.000.
  Dependência: apenas numpy (>=2.0). Single-thread, determinística, sem processo externo, sem licença adicional.
  Latência medida ponta a ponta (com ranking, fronteira, atribuição e Monte Carlo): 19–26 ms até 40 itens × 25 lojas.

Caminho B (cauda longa): CP-SAT.
  Gatilho: 200.000 < N_sub ≤ 5.000.000.
  pip install ortools==9.15.6755 (Apache-2.0).
  solver.parameters.max_time_in_seconds = 0.8
  solver.parameters.num_workers = min(8, os.cpu_count())
  solver.parameters.relative_gap_limit = 0.005   # 0,5% já é ruído perto da incerteza de preço
  solver.parameters.log_search_progress = False
  model.add_hint(...) com a solução do guloso (custo ~0, ajuda quando o limite aperta)
  Aceite APENAS status OPTIMAL ou FEASIBLE; se FEASIBLE, marque a resposta como 'aproximada' na UI.
  Faça um solve dummy no startup do worker (warm-up medido: primeiro solve custa até 284 ms extras).

Caminho C (degradação): guloso incremental + busca local.
  Gatilho: N_sub > 5.000.000, m > 80, ou timeout do caminho B.
  Gap medido: 0,0% a 0,2% após busca local — indistinguível do ótimo dado o ruído dos dados.

REDUÇÃO DE m ANTES DE TUDO (pré-filtro, sempre):
  - manter apenas lojas com cobertura ≥ 40% da cesta OU que sejam a mais barata em ≥ 1 item;
  - manter no máximo 30 lojas, ordenadas por (cobertura, −distância);
  - descartar loja dominada: se existe t com p_it ≤ p_is ∀i e f_t ≤ f_s, remova s. Isso é exato (não perde ótimo)
    e derruba m drasticamente em cidades com muitas lojas da mesma rede.

CACHE: chave = hash(lista_normalizada_de_itens + K + célula H3 do usuário + versão do snapshot de preços).
  TTL curto (15 min) no Redis. O snapshot de preços deve ser versionado para que o cache invalide sozinho
  quando entrarem preços novos.
- PRECISÃO NUMÉRICA E TIPOS
  - Banco: preco NUMERIC(12,2). Otimizador: INTEIRO EM CENTAVOS (int64).
  - Converter com round-half-up explícito, uma única vez, ao montar o snapshot. Nunca deixar float chegar
    no CP-SAT em restrição (só o objetivo aceita float; restrições exigem coeficiente inteiro).
  - Magnitude do objetivo: n=200 itens × q=24 × p=50.000 centavos ≈ 2,4e8 — três ordens de grandeza abaixo
    de qualquer risco de overflow int64. Seguro.
  - Epsilon de comparação: 1 centavo. Não use tolerância relativa em dinheiro.
  - f_s: parametrize como f_s = 2 · dist_km(casa, s) · custo_por_km + custo_fixo_de_parada.
    Valores iniciais sugeridos e EXPOSTOS AO USUÁRIO (não escondidos): custo_por_km R$ 1,10; custo_fixo_de_parada R$ 3,00.
    Se o usuário for a pé / de ônibus, troque por (tarifa × 2) + tempo. Nunca use um f_s oculto que o usuário
    não consegue auditar — ele é o parâmetro que mais muda a resposta.

## RECOMENDACOES
- Adote a ENUMERAÇÃO EXATA VETORIZADA (numpy) como caminho principal, não o solver. Medido: 0,3 ms para 30 itens × 20 lojas K=3, batendo exatamente o ótimo do CP-SAT, contra 9–12 ms do CP-SAT. Ela é single-thread, determinística, sem dependência pesada, e entrega de graça o ranking completo — que é precisamente o insumo da explicação honesta e do intervalo de economia.
- Implemente o gatilho N_sub = Σ_{k=1..K} C(m,k) e três caminhos: ≤200k → enumeração exata; ≤5M → CP-SAT 9.15.6755 com num_workers=min(8,cpu_count) e time limit 0,8 s; >5M → guloso + busca local. Meça N_sub antes de decidir, no próprio request; é uma conta de microssegundos.
- Modele cobertura como RESTRIÇÃO SUAVE com variável u_i e penalidade M_i = 1,6 · q_i · max_s p_is. Sem isso: (a) o MILP fica infactível quando nenhum conjunto de K lojas cobre a cesta e o endpoint devolve 500 em vez de 'faltam 3 itens'; (b) o guloso incremental trava em conjunto vazio (bug que reproduzi).
- Use a formulação DESAGREGADA y_is ≤ x_s. Nunca a agregada Σ_i y_is ≤ n·x_s — a relaxação linear desta última é muito fraca e o branch-and-bound explode.
- Aplique o pré-filtro de dominância de lojas antes de otimizar: se existe loja t com p_it ≤ p_is para todo item e f_t ≤ f_s, remova s. É exato (não perde o ótimo) e derruba m em cidades com muitas lojas da mesma bandeira, mantendo você permanentemente na faixa da enumeração exata.
- Mostre a FRONTEIRA DE K na UI (custo com 1, 2, 3, 4 lojas e o delta de cada parada adicional). Sai de graça da enumeração, custa zero, e transfere a decisão de 'vale a pena a 3ª parada?' para quem tem a informação (o usuário conhece o próprio tempo e transporte).
- Reporte economia SEMPRE como faixa p10–p90 de um Monte Carlo de 300 sorteios sobre a incerteza σ_is, comparada ao baseline 'comprar tudo na loja única mais barata'. Custo medido: <20 ms. Suprima o número inteiro quando o σ médio ponderado da cesta passar de 10%.
- Adote a linguagem 'esta está entre as melhores combinações' e mostre 2–3 alternativas dentro de 1% do custo. Justificativa medida: com σ=5% de incerteza, o conjunto recomendado só continua sendo o ótimo verdadeiro em 56% dos cenários, embora custe apenas 0,33% a mais em média.
- Exiba a IDADE e a FONTE de todo preço mostrado, ao lado do valor. É defesa direta contra enganosidade por omissão (CDC art. 37 §3º) e é o que diferencia um comparador colaborativo honesto de um agregador de preços podres.
- Otimize sobre o limite superior de confiança p_is = p̂_is · (1 + λ·σ_is) com λ=1,0, e não sobre p̂ cru. Efeito: o otimizador prefere naturalmente preços recentes e confirmados, e para de recomendar desvios de rota baseados em um OCR de encarte de 3 semanas atrás.
- Trate encarte com data-fim como EXPIRAÇÃO (peso 1,0 até a data, 0 depois), não como decaimento exponencial. Só use meia-vida para fontes sem validade declarada. Encartes brasileiros valem tipicamente 5–7 dias.
- Guarde meias-vidas, C_src, σ0, β, γ e λ em TABELA de configuração versionada, não em código. Eles são hipóteses a calibrar contra o erro real medido (|preço previsto − próximo preço observado|) por fonte e por idade, e vão mudar nos primeiros meses de operação.
- Escolha UM entre ortools e highspy no mesmo serviço Python. Eles não coexistem no mesmo processo (SIGSEGV ou ImportError por colisão de símbolos do HiGHS embutido na libortools, reproduzido em macOS arm64). Dado que o caminho principal é numpy, a escolha natural é ortools apenas no caminho B.
- Se apesar de tudo usar PuLP, teste prob.sol_status == pulp.LpSolutionOptimal (1), NUNCA prob.status == pulp.LpStatusOptimal. Reproduzi PuLP 3.3.2 + HiGHS reportando 'Optimal' para uma solução 2× pior obtida por estouro de time limit.
- Faça um solve dummy no startup de cada worker FastAPI (warm-up). Medido: o primeiro solve em processo novo pagou até 284 ms de carregamento de biblioteca, o que estoura o p99 do endpoint sem motivo.
- Substituição: default 'exact' por item, opt-in explícito para equivalentes, taxonomia curada por humano (LLM só sugere candidatos para fila de revisão), comparação obrigatória por preço por unidade padrão (R$/kg, R$/L), bloqueio duro para teor/alergênico/restrição alimentar/medicamento, e exibição sempre visível da troca com botão Desfazer.
- Cacheie no Redis com chave = hash(itens normalizados + K + célula geográfica + versão do snapshot de preços) e TTL de 15 min. Versione o snapshot para que a entrada de preços novos invalide o cache sozinha.

## NAO FAZER
- NÃO comece pelo solver. Colocar CP-SAT ou HiGHS no caminho crítico para 30 itens × 20 lojas é 10–30× mais lento que enumerar tudo em numpy, adiciona uma dependência de ~100 MB, introduz não-determinismo (portfólio paralelo) e ainda te obriga a lidar com status de time limit. Só entre no solver depois que C(m,1..K) passar de 200.000.
- NÃO use CBC (PULP_CBC_CMD) em request síncrono. Medido: 1.512 ms para uma instância de 30 itens × 20 lojas que o CP-SAT resolve em 9 ms — ele roda como subprocesso escrevendo arquivo LP em disco.
- NÃO confie em pulp.LpStatus[prob.status] == 'Optimal'. Reproduzi PuLP 3.3.2 + HiGHS retornando 'Optimal' com objetivo 2× pior por estouro de time limit. Use prob.sol_status.
- NÃO instale ortools e highspy no mesmo ambiente Python. Colisão de símbolos do HiGHS embutido na libortools causa SIGSEGV ou ImportError, dependendo da ordem de import.
- NÃO use a restrição de ativação agregada (Σ_i y_is ≤ n·x_s). A relaxação linear fica muito fraca e o solver passa a explorar árvores enormes por nada.
- NÃO modele cobertura como restrição dura sem variável de folga. O modelo fica infactível justamente nos casos em que o usuário mais precisa de resposta (cesta com item raro), e infactível não é uma resposta útil.
- NÃO coloque a rota (TSP) dentro do MILP. Use custo aditivo por loja e re-precifique a rota exata só para os top-N conjuntos (K ≤ 5 → ≤ 120 permutações).
- NÃO exiba economia como número único ('você economiza R$ 693,99'). É falsa precisão sobre dados que têm σ de 2% a 20%, e é exatamente o tipo de afirmação que o art. 37 §1º do CDC alcança.
- NÃO afirme 'o mais barato da cidade' / 'o menor preço'. Você compara apenas as lojas e os preços que estão na sua base. Diga isso.
- NÃO deduza equivalência de produtos com LLM ou embedding em runtime para trocar automaticamente. Use taxonomia curada; LLM só popula fila de revisão humana. Trocar leite integral por desnatado, ou glúten por sem-glúten, silenciosamente, é falha de produto e potencialmente de segurança.
- NÃO compare preços de embalagens de tamanhos diferentes sem normalizar para R$/kg, R$/L ou R$/unidade. É a forma mais fácil e mais indefensável de o app mentir sem querer.
- NÃO tente contornar CAPTCHA, autenticação, rate limit, robots.txt ou termos de uso de nenhum site de supermercado ou portal para obter preços. Se a única forma de obter um dado for burlando qualquer um desses, o dado não deve ser obtido. Alternativas legítimas: (a) QR Code de NFC-e enviado pelo próprio consumidor, que é dado dele; (b) portais estaduais de transparência de preços que ofereçam API pública documentada, respeitando os termos e o rate limit publicados; (c) acordo comercial ou convênio direto com a rede ou com a associação de supermercados; (d) contribuição manual e foto de encarte enviada pelo usuário. Não projetei nem devo projetar nenhuma rota que dependa de burla.
- NÃO reotimize a cada renderização de tela. A identidade do conjunto ótimo é instável sob ruído pequeno e a recomendação vai 'piscar'. Fixe por snapshot versionado.
- NÃO pine PuLP 4.0.0aX. As versões 4.0.0a10/a11/a12 (junho/2026) são prereleases; a estável é 3.3.2 (2026-05-25).

## RISCOS
- Números de economia inflados: nas minhas instâncias sintéticas a dispersão de preços loja-a-loja foi de ±18% por item mais ±13% por loja, o que produziu 'economia vs loja única' de 20% a 47%. A dispersão real no varejo alimentar brasileiro é menor e o custo de deslocamento real é maior — espere algo na faixa de 5–15%. Meus benchmarks validam TEMPO e CORREÇÃO do algoritmo, NÃO a magnitude da economia. Não copie 25% para o material de marketing.
- Bancada otimista: todas as medições são em Apple M5 Pro (5 P-cores) com macOS. Um container Linux x86 de 1–2 vCPU será substancialmente mais lento em single-thread e, no caso do CP-SAT, catastroficamente mais lento por falta de workers (medido: 1 worker leva 60x40 K=4 a estourar 1 s em 57% das instâncias). Refaça a medição no ambiente de produção antes de fixar o SLA.
- Risco jurídico de publicidade enganosa (CDC art. 37, §1º e §3º) se o app exibir preço desatualizado sem sinalizar a data, ou anunciar 'menor preço' sem qualificar o universo comparado. Enganosidade por omissão é expressamente prevista. O app não é o fornecedor do produto, mas responde pelo que ele mesmo publica.
- Risco de dados: preços de NFC-e refletem o que UMA pessoa pagou em UM momento, podendo incluir promoção de clube de fidelidade, preço de leve-3-pague-2 rateado, ou item em liquidação por vencimento. Recomendar rota baseada num preço não repetível gera frustração e denúncia. Marque e exclua padrões suspeitos (preço < 60% da mediana histórica do par item-loja) até revisão.
- Manipulação por parte de lojas ou concorrentes: um ator malicioso pode enviar preços falsamente baixos para atrair usuários a uma loja, ou falsamente altos para afundar concorrentes. A média ponderada por confiança mitiga parcialmente; é indispensável ter reputação por usuário, limite de contribuições por dia, e mediana robusta (não média) com corte por MAD.
- Deriva silenciosa de qualidade: se a base envelhecer (menos contribuições), o σ médio sobe, o portão de descarte (θ<0,25) elimina pares, A_i encolhe, u_i sobe e o otimizador passa a devolver 'não encontramos preço para 12 dos 30 itens'. Isso precisa de alarme operacional (métrica: fração média de itens cobertos por request), não só de um fallback visual.
- Instabilidade percebida: com σ=5% a identidade do conjunto ótimo muda entre execuções em 44% dos cenários. Se você recalcular a cada abertura de tela com dados ligeiramente diferentes, o usuário verá a recomendação 'pular' e perderá confiança. Mitigação: fixe o resultado por sessão/lista (com snapshot versionado) e só recalcule com ação explícita ou mudança material (>2% de custo).
- Explosão do modelo com substituições: cada item com |G_i| variantes multiplica o número de variáveis y por |G_i|. Com 30 itens × 4 variantes × 20 lojas × densidade 0,65 já são ~1.560 binárias e a enumeração exata continua funcionando (o conjunto de LOJAS não cresce), mas o CP-SAT sim. Vantagem adicional da enumeração: o custo dela depende de C(m,K), que é INDIFERENTE ao número de itens e variantes.
- Licença EPL-2.0 do python-mip é copyleft fraco; embora não contamine código que apenas usa a biblioteca, exige atenção jurídica em distribuição. ortools (Apache-2.0), HiGHS/highspy (MIT) e PuLP (MIT) são mais simples. Prefira essas.
- Se o produto algum dia colocar rota/ordem de visita dentro da otimização, ele vira Traveling Purchaser Problem, que contém UFL, Set Cover e Group Steiner Tree como casos especiais — salto de dificuldade que invalida todo o dimensionamento de latência deste documento.

## EM ABERTO
- Qual a dispersão REAL de preços entre supermercados da mesma cidade para uma cesta de 30 itens no Brasil? Todo o dimensionamento de 'quanto o usuário economiza' depende disso e eu só tenho dados sintéticos. Precisa ser medido com os primeiros milhares de cupons reais antes de qualquer promessa em marketing.
- Qual a meia-vida empírica de um preço de NFC-e? Proponho 7 dias, mas isso deve sair de uma regressão do erro |preço previsto − próximo preço observado| contra idade, por categoria (hortifruti muda muito mais rápido que mercearia seca — provavelmente é preciso meia-vida POR CATEGORIA, não por fonte apenas).
- Qual K os usuários realmente aceitam? Se a resposta empírica for K ≤ 2, o problema fica trivial (C(30,1..2) = 465 subconjuntos, microssegundos) e boa parte da complexidade deste documento é desnecessária. Vale instrumentar isso cedo.
- Como calibrar f_s (custo de deslocamento) para usuários sem carro? A parametrização km × R$/km não vale para ônibus, bicicleta ou a pé. Precisa de um seletor de modal e possivelmente de um custo de TEMPO explícito, que é o que realmente limita a maioria das pessoas.
- Existe API pública documentada de preços de NFC-e em portais estaduais brasileiros com termos que permitam este uso, e com qual rate limit e cobertura geográfica? Não pesquisei isso neste tópico — é escopo de outro agente, mas afeta diretamente a densidade de A_i e portanto a viabilidade do otimizador.
- O comportamento de colisão ortools × highspy se reproduz em Linux/glibc, ou é específico do dyld do macOS? Testar em contêiner python:3.12-slim antes de assumir a restrição na arquitetura.
- Vale a pena calcular o resultado de forma incremental conforme o usuário adiciona itens à lista (mantendo o ranking e atualizando por delta), em vez de reotimizar do zero? Com 0,3 ms por otimização completa, provavelmente NÃO vale a complexidade — mas se m crescer muito em capitais, pode passar a valer.
- Como tratar promoções condicionais (leve 3 pague 2, desconto no app da rede, clube de fidelidade)? Isso transforma o problema na variante 'Clever Shopper' com descontos por limiar, que tem resultados de dureza próprios. Fica fora do escopo desta rodada mas é o próximo salto de modelagem.
- Qual o valor exato de λ (o coeficiente do limite superior de confiança) que maximiza a satisfação real do usuário? λ alto evita recomendações baseadas em dado ruim mas perde economia real. Só um A/B com feedback pós-compra ('o preço estava certo?') resolve.


################################################################
# TOPICO: Stack backend Python de produção para o melhor_mercado — versões reais verificadas em 2026-07-22 (FastAPI, SQLAlchemy/PostGIS, fila OCR, storage S3, auth mobile, observabilidade, testes, tooling)
################################################################

## RESUMO EXECUTIVO
Todas as versões abaixo foram lidas da API JSON do PyPI, Docker Hub e GitHub em 2026-07-22 (não de memória). O stack de referência: Python 3.13.14 (3.14.6 aceitável), FastAPI 0.139.2 + Starlette 1.3.1 (Starlette chegou a 1.x) + Pydantic 2.13.4, uvicorn 0.51.0, SQLAlchemy 2.0.51 (2.1 ainda em beta: 2.1.0b3), Alembic 1.18.5, GeoAlchemy2 0.20.0, PostgreSQL 18.4 + PostGIS 3.6 via `postgis/postgis:18-3.6`, pgvector 0.8.5.
Três decisões arquiteturais que fogem do "default de 2024" e importam muito aqui: (1) **MinIO está morto para deploys novos** — o repo `minio/minio` no GitHub está `archived=true`, o último push no Docker Hub é RELEASE.2025-09-07 e a release de segurança RELEASE.2025-10-15 nunca foi publicada como imagem (404 no Docker Hub). Use SeaweedFS 4.40 ou Garage v2.3.0 para dev/self-host. (2) **Escolha o driver Postgres pela fila, não pelo micro-benchmark**: Procrastinate (fila em Postgres) só fala psycopg3/psycopg2/aiopg — asyncpg não é suportado. Como o enfileiramento transacional (gravar o documento e o job na MESMA transação) é a resposta mais limpa para idempotência de NFC-e reenviada, recomendo `psycopg[binary,pool]` 3.3.4 com `postgresql+psycopg://` para todo o app, o que também elimina a armadilha asyncpg+PgBouncer (`prepared statement __asyncpg_stmt_X already exists`). (3) **Fila: Procrastinate 3.9.0** atende nativamente os 4 requisitos (retry com exponential_wait, "dead letter" = status `failed` persistido em tabela e re-executável por SQL, prioridade inteira nativa por job, idempotência via `queueing_lock` com exceção `AlreadyEnqueued`) sem infra nova. Risco: projeto pequeno (1.3k estrelas) — mitigue com uma porta `TaskQueue` abstraindo o enqueue.
Tooling: uv 0.11.31 é o gerenciador padrão (ainda 0.x, sem 1.0), ruff 0.15.22 substitui black+isort+flake8 (formatter + regra `I` do isort), mypy virou 2.x (2.3.0) com três flags viradas por default que quebram código que passava no 1.x. pytest 9.1.1 + pytest-asyncio 1.4.0 (fixture `event_loop` REMOVIDA na 1.0.0). httpx continua em 0.28.1 estável (1.0 só em dev3) e `AsyncClient(app=...)` foi removido — use `ASGITransport`.

## ACHADOS

### [confirmada] Python 3.13 e 3.14 estão ambos em fase 'bugfix'; 3.12 e 3.11 já são security-only; 3.10 morre em 2026-10
devguide.python.org/versions: 3.14 (first 2025-10-07, EOL 2030-10, status bugfix), 3.13 (first 2024-10-07, EOL 2029-10, status bugfix), 3.12 (security, EOL 2028-10), 3.11 (security, EOL 2027-10), 3.10 (security, EOL 2026-10 — ou seja, expira em ~3 meses). Últimos releases: 3.14.6 (2026-06-10) e 3.13.14 (2026-06-10). Recomendação: pinar 3.13.14 (`python:3.13-slim-trixie`), pois é a linha com maior cobertura de wheels nativas para o lado de OCR/imagem (opencv, pyzbar, pillow) — 3.14.6 funciona e é aceitável.
FONTE: https://devguide.python.org/versions/

### [confirmada] FastAPI 0.139.2 (2026-07-16) exige Python >=3.10, Starlette >=0.46.0 (sem upper bound) e Pydantic >=2.9.0
requires_dist exato da API do PyPI: ['starlette>=0.46.0', 'pydantic>=2.9.0', 'typing-extensions>=4.8.0', 'typing-inspection>=0.4.2', 'annotated-doc>=0.0.2']. Classifiers cobrem 3.10–3.14. O extra [standard] inclui fastapi-cli[standard]>=0.0.8, fastar>=0.9.0, httpx<1.0.0,>=0.23.0, jinja2>=3.1.5, python-multipart>=0.0.18, email-validator>=2.0.0, uvicorn[standard]>=0.12.0, pydantic-settings>=2.0.0, pydantic-extra-types>=2.0.0. NOTA: `fastar` (0.11.0) é um binding Rust do crate tar — dependência nova e surpreendente do extra [standard]; se não quiser, instale `fastapi` puro em vez de `fastapi[standard]`.
FONTE: https://pypi.org/pypi/fastapi/json

### [confirmada] Starlette saltou para 1.x — versão atual 1.3.1 (2026-06-12)
Starlette 1.3.1, requires_python >=3.10. Como FastAPI declara apenas `starlette>=0.46.0` sem teto, um `uv lock` sem pin explícito trará 1.3.1. Isso é seguro em teoria mas é uma major bump silenciosa: PINE `starlette==1.3.1` explicitamente no pyproject e valide middlewares customizados (BaseHTTPMiddleware, TestClient) no upgrade.
FONTE: https://pypi.org/pypi/starlette/json

### [provavel] Pydantic 2.13.4 (2026-05-06); pydantic-core foi absorvido no repositório principal do pydantic
pydantic 2.13.4, requires_python >=3.9. O changelog de 2.13.0b1 indica que o repositório pydantic-core foi mesclado dentro do repo principal do pydantic (jiter atualizado para v0.14.0 em 2.13.4). pydantic-settings 2.14.2 (2026-06-19, py>=3.10) — use `BaseSettings` com `model_config = SettingsConfigDict(env_file='.env', env_nested_delimiter='__')`.
FONTE: https://pypi.org/pypi/pydantic/json

### [confirmada] SQLAlchemy estável é 2.0.51 (2026-06-15); 2.1 ainda está em beta (2.1.0b3, 2026-06-27) — NÃO usar em produção
2.0.51 declara requires_python >=3.7 (metadado legado; na prática rode 3.10+). Mudança operacional crítica: o greenlet (necessário para asyncio) NÃO é mais instalado por default — é obrigatório declarar o extra `sqlalchemy[asyncio]` (extras disponíveis incluem: asyncio, postgresql-psycopg, postgresql-psycopgbinary, postgresql-asyncpg, mypy).
FONTE: https://pypi.org/pypi/sqlalchemy/json

### [confirmada] asyncpg 0.31.0 é de 2025-11-24 (~8 meses sem release); psycopg 3.3.4 é de 2026-05-01 e tem cadência muito maior
asyncpg 0.31.0 (2025-11-24, py>=3.9.0). psycopg 3.3.4 + psycopg-pool 3.3.1 (ambos 2026-05-01, py>=3.10). URL SQLAlchemy: `postgresql+psycopg://` (o mesmo prefixo serve para create_engine sync e create_async_engine — o dialeto detecta o modo), contra `postgresql+asyncpg://`. Com psycopg você usa UM único driver para FastAPI (async), Alembic (sync) e scripts de importação de encarte (COPY nativo do psycopg3, útil para bulk-insert de itens de cupom).
FONTE: https://pypi.org/pypi/psycopg/json

### [confirmada] asyncpg atrás de PgBouncer em transaction pooling quebra com DuplicatePreparedStatementError — psycopg3 não sofre disso
asyncpg cacheia por default as últimas 100 queries por conexão (statement_cache_size=100) gerando nomes tipo `__asyncpg_stmt_a1b2c3__`; com PgBouncer em pool_mode=transaction o erro é `prepared statement "__asyncpg_stmt_X__" already exists`. Workarounds necessários: `connect_args={'statement_cache_size': 0}` + `prepared_statement_cache_size=0` no create_async_engine (+ `prepared_statement_name_func` em SQLAlchemy 2.0) e/ou NullPool. Referência: sqlalchemy/sqlalchemy issue #6467 e discussion #10246.
FONTE: https://github.com/sqlalchemy/sqlalchemy/issues/6467

### [confirmada] Alembic 1.18.5 (2026-06-25) e GeoAlchemy2 0.20.0 (2026-05-12) suportam Python >=3.10 e SQLAlchemy 2.x
geoalchemy2 0.20.0 requires_dist = ['SQLAlchemy>=1.4', 'packaging', 'Shapely>=1.7; extra == "shapely"']. Instale `geoalchemy2` + `shapely==2.1.2` para converter WKB<->objetos Python. Cuidado clássico: no Alembic é preciso adicionar `import geoalchemy2` ao template de migração e filtrar as tabelas de sistema do PostGIS (spatial_ref_sys, geography_columns, geometry_columns, raster_columns, raster_overviews) no `include_object` do env.py, senão o autogenerate tenta dropá-las.
FONTE: https://pypi.org/pypi/geoalchemy2/json

### [confirmada] PostgreSQL estável é 18.4; 19 está em beta2. A imagem correta é postgis/postgis:18-3.6 (atualizada em 2026-07-20)
postgresql.org/support/versioning: 18 (minor 18.4, EOL 2030-11-14), 17 (17.10, EOL 2029-11-08), 16 (16.14), 15 (15.18), 14 (14.23, EOL 2026-11-12). PG 19 em Beta 2 (2026-07-16) — não usar. Tags reais do Docker Hub postgis/postgis atualizadas em 2026-07-20: `18-3.6`, `18-3.6-alpine`, `17-3.6-alpine`, `17-3.5`, `19beta1-3.6`. Imagem oficial `postgres:18.4-trixie` também existe (2026-07-19) mas SEM PostGIS.
FONTE: https://www.postgresql.org/support/versioning/

### [confirmada] pgvector 0.8.5 (2026-07-08); a imagem postgis/postgis NÃO inclui pgvector — é preciso construir uma imagem própria
CHANGELOG do pgvector: 0.8.5 (2026-07-08, memória em IVFFlat), 0.8.4 (2026-06-30), 0.8.3 (2026-06-17, corrige CORRUPÇÃO DE ÍNDICE com HNSW vacuuming e regressão de performance de Hamming/Jaccard no Postgres 18), 0.8.2 (2026-02-25, buffer overflow em build HNSW paralelo). PIN MÍNIMO OBRIGATÓRIO: >=0.8.3 se usar HNSW em PG18. Dockerfile: `FROM postgis/postgis:18-3.6` + apt-get build-essential postgresql-server-dev-18 + `git clone --branch v0.8.5 https://github.com/pgvector/pgvector && make && make install`.
FONTE: https://github.com/pgvector/pgvector/blob/master/CHANGELOG.md

### [confirmada] MinIO está efetivamente descontinuado como open source: repositório GitHub ARQUIVADO e imagem Docker congelada há ~10 meses
GitHub API para minio/minio em 2026-07-22: archived=true, pushed_at=2026-04-24, 61.371 stars, licença AGPL-3.0. Docker Hub minio/minio: tag mais recente = RELEASE.2025-09-07T16-13-09Z (e `latest` aponta para ela, 2025-09-07). A release RELEASE.2025-10-15T17-29-55Z do GitHub está rotulada 'Security/CVE' e a consulta ao Docker Hub por essa tag retorna HTTP 404 — ou seja, a imagem oficial mais recente do Docker Hub NÃO contém o fix de segurança de outubro/2025. Em quay.io/minio/minio existem builds `.hotfix.` até 2026-04-01, mas fora do canal público padrão. Contexto: o console web administrativo foi removido do Community Edition (commit de fev/2025, release 'Breaking' 2025-05-24); o fork OpenMaxIO surgiu em maio/2025 mas está dormente (sem push desde 2025-06-24).
FONTE: https://api.github.com/repos/minio/minio

### [confirmada] Alternativas S3-compatíveis vivas: SeaweedFS 4.40 (Apache-2.0) e Garage v2.3.0 (AGPL-3.0); RustFS ainda é beta
seaweedfs/seaweedfs: archived=false, pushed 2026-07-21, 33.644 stars, Apache-2.0; imagem chrislusf/seaweedfs tag 4.40 (2026-07-20). Garage: imagem dxflrs/garage, tags versionadas v2.3.0 (2026-04-16), v2.2.0 (2026-01-24), v2.0.0 (2025-06-14); builds por commit diários (último 2026-07-22). rustfs/rustfs: 30.099 stars, Apache-2.0, push 2026-07-22, MAS a release mais recente é 1.0.0-beta.10 (2026-07-17) marcada prerelease=true — não usar em produção. LocalStack serve só para testes, não para dev persistente.
FONTE: https://api.github.com/repos/seaweedfs/seaweedfs

### [confirmada] URL pré-assinada S3 SigV4: máximo 7 dias (604800s) com credencial de longa duração; 12h pelo console; menos ainda com credencial STS
Doc AWS: 'When you use the AWS CLI, the maximum expiration time for a presigned URL is 7 days from the time of creation' (`aws s3 presign --expires-in 604800`); pelo console o máximo é 12 horas. Se a URL for assinada com credenciais temporárias (STS/IAM role), ela EXPIRA JUNTO com a credencial, mesmo que ExpiresIn seja maior. `s3_client.generate_presigned_url(ClientMethod, Params, ExpiresIn)` é assinatura puramente local (sem I/O de rede), portanto pode ser chamada dentro de handler async do FastAPI sem run_in_threadpool. Para upload direto do app Flutter, prefira `generate_presigned_post` (POST policy) — permite restringir content-length-range e content-type, o que `generate_presigned_url(put_object)` não faz.
FONTE: https://docs.aws.amazon.com/AmazonS3/latest/userguide/ShareObjectPreSignedURL.html

### [confirmada] Fila: Procrastinate 3.9.0 é o único candidato que cobre retry + dead-letter + prioridade + idempotência nativamente
Versões reais: celery 5.6.3 (2026-03-26), dramatiq 2.2.0 (2026-06-17), arq 0.28.0 (2026-04-16), taskiq 0.12.4 (2026-05-08), rq 2.10.0 (2026-06-20), procrastinate 3.9.0 (2026-06-20). Procrastinate: Python 3.10+, PostgreSQL 13+; prioridade = inteiro nativo por job (maior = mais prioritário, default 0, `task.configure(priority=5).defer()`); retry = RetryStrategy(max_attempts, wait, linear_wait, exponential_wait 5/25/125s, retry_exceptions); idempotência = `queueing_lock` que levanta `AlreadyEnqueued` (bloqueia duplicata enquanto status='todo'; NÃO bloqueia se já está 'doing'); dead-letter = job persiste com status='failed' na tabela procrastinate_jobs indefinidamente e é re-executável (`JobManager.retry_job()` volta para 'todo'); heartbeat de worker a cada 10s, jobs travados detectados por `JobManager.get_stalled_jobs(seconds_since_heartbeat=30)`. Deps do procrastinate 3.9.0: asgiref, attrs, croniter, packaging, psycopg[pool], python-dateutil, typing-extensions.
FONTE: https://pypi.org/pypi/procrastinate/json

### [confirmada] Procrastinate NÃO suporta asyncpg — só psycopg3, psycopg2 e aiopg. Isso amarra a escolha do driver do SQLAlchemy
Connectors disponíveis: PsycopgConnector (async, psycopg v3), AiopgConnector (async, aiopg), SyncPsycopgConnector (psycopg v3), Psycopg2Connector, SQLAlchemyPsycopg2Connector. Para enfileirar DENTRO da transação da aplicação é preciso passar uma conexão psycopg existente ao `defer` — suportado por SyncPsycopgConnector, PsycopgConnector e SQLAlchemyPsycopg2Connector; 'the job INSERT will run on that connection instead of the connector's pool... the user is responsible for committing'. Consequência prática para o melhor_mercado: rode SQLAlchemy em `postgresql+psycopg://` para que o INSERT do documento e o INSERT do job de OCR estejam na mesma transação atômica.
FONTE: https://github.com/procrastinate-org/procrastinate/blob/main/docs/howto/basics/connector.md

### [confirmada] Dramatiq 2.2.0 é a alternativa mais forte se você preferir broker Redis — 2.0 adicionou asyncio, mas a prioridade é fraca e não há dedupe
Dramatiq: DLQ nativa ('once a message has exceeded its retry or age limits, it gets moved to the dead letter queue where it's kept for up to 7 days and then automatically dropped' — retenção de apenas 7 dias, pior que a persistência em tabela do Procrastinate); retries com max_retries=20 default, min_backoff=15s, max_backoff=7 dias, `retry_when` e `throws`; prioridade é POR ACTOR e 'only takes effect when Dramatiq is choosing which message to run' depois do consumo — não é ordenação na fila, então prioridade real exige filas separadas + workers dedicados; 'Dramatiq assumes all actors are idempotent' e não oferece dedupe. Breaking changes da 2.0: Python 3.10+ mínimo, middleware Prometheus não vem mais por default (extra `prometheus`), `Results` exige argumento backend, `StubBroker.join()` com fail_fast=True. Saúde do repo: Bogdanp/dramatiq, 5.291 stars, push 2026-07-06.
FONTE: https://dramatiq.io/guide.html

### [confirmada] Celery 6.0 ainda não saiu; o suporte asyncio nativo está sendo desenvolvido como pacote separado 'celery-asyncio' em alpha
celery estável 5.6.3 (2026-03-26). Milestone 6.0 tinha due date 2026-05-30 e não foi entregue (28.715 stars, 787 issues abertas, push 2026-07-22 — projeto vivo). Existe `celery-asyncio` 6.0.0a3 (2026-04-09) 'Distributed Task Queue with native asyncio support', requires Python >=3.14 — alpha, não usar. Ponto negativo relevante: Flower (a UI de monitoramento de Celery) está em 2.0.1 desde 2023-08-13, ou seja ~3 anos sem release — o principal argumento 'ecossistema maduro' do Celery está enfraquecido.
FONTE: https://pypi.org/pypi/celery/json

### [confirmada] python-jose tem 2 advisories CRITICAL abertos e manutenção fraca — use PyJWT 2.13.0
GitHub Advisory Database (ecosystem=pip, python-jose): GHSA-6c5p-j8vq-pqhj (critical, 2024-04-26, 'algorithm confusion with OpenSSH ECDSA keys'), GHSA-w799-prg3-cx77 (critical, 2022-05-17, 'failure to use a constant time comparison for HMAC keys'), GHSA-cjwg-qfpm-7377 (medium, DoS via compressed JWE). python-jose está em 3.5.0 desde 2025-05-28 (repo mpdavis/python-jose, push 2026-04-14, 115 issues abertas). PyJWT 2.13.0 (2026-05-21, repo jpadilla/pyjwt, push 2026-07-20) — instale como `pyjwt[crypto]` para trazer `cryptography` 49.0.0 e suportar RS256/ES256/EdDSA.
FONTE: https://github.com/advisories?query=python-jose

### [confirmada] passlib está abandonado desde 2020 — substitua por pwdlib com Argon2
passlib 1.7.4 foi publicado em 2020-10-08 e não tem `requires_python` declarado (metadado pré-PEP 621). Além disso passlib 1.7.4 quebra com bcrypt>=4.1 (erro `AttributeError: module 'bcrypt' has no attribute '__about__'`) e bcrypt atual é 5.0.0 (2025-09-25). Alternativa mantida: pwdlib 0.3.0 (2025-10-25, repo frankie567/pwdlib — mesmo autor do FastAPI Users, push 2026-07-20), extras `argon2` e `bcrypt`; use `pwdlib[argon2]` que traz argon2-cffi 25.1.0. Argon2id é o algoritmo recomendado atual para hash de senha.
FONTE: https://pypi.org/pypi/passlib/json

### [confirmada] RFC 9700 (jan/2025) exige que refresh tokens de clientes públicos (= app mobile) sejam sender-constrained OU usem rotação
Texto do RFC 9700: 'Refresh tokens for public clients MUST be sender-constrained or use refresh token rotation as described in Section 4.14'; e 'Authorization and resource servers SHOULD use mechanisms for sender-constraining access tokens, such as mutual TLS [RFC8705] or OAuth 2.0 Demonstrating Proof of Possession (DPoP) [RFC9449]'. Rotação = a cada refresh emite-se um novo refresh token e invalida-se o anterior; a detecção de reuso de um refresh token já invalidado deve revogar toda a família de tokens daquele device.
FONTE: https://www.rfc-editor.org/info/rfc9700/

### [confirmada] App Store Guideline 4.8 NÃO exige Sign in with Apple especificamente — exige uma opção de login 'equivalente' com 3 propriedades de privacidade
Texto atual literal da guideline 4.8: 'Apps that use a third-party or social login service (such as Facebook Login, Google Sign-In, Log in with X, Sign In with LinkedIn, Login with Amazon, or WeChat Login) to set up or authenticate the user's primary account with the app must also offer as an equivalent option another login service with the following features: the login service limits data collection to the user's name and email address; the login service allows users to keep their email address private as part of setting up their account; and the login service does not collect interactions with your app for advertising purposes without consent.' Exceção explícita: 'Your app exclusively uses your company's own account setup and sign-in systems.' Consequência para o melhor_mercado: se você oferecer Google Sign-In, precisa oferecer também Sign in with Apple (ou outro serviço que atenda os 3 critérios). Se oferecer APENAS conta própria (email/senha ou telefone), 4.8 não se aplica.
FONTE: https://developer.apple.com/app-store/review/guidelines/

### [confirmada] OpenTelemetry Python: API/SDK/exporters em 1.44.0 e TODAS as instrumentações em 0.65b0 (ainda beta) — as duas linhas de versão devem casar
Publicados juntos em 2026-07-16: opentelemetry-api 1.44.0, opentelemetry-sdk 1.44.0, opentelemetry-exporter-otlp 1.44.0, opentelemetry-distro 0.65b0, opentelemetry-instrumentation-fastapi 0.65b0, -sqlalchemy 0.65b0, -psycopg 0.65b0, -asyncpg 0.65b0, -redis 0.65b0, -httpx 0.65b0, -celery 0.65b0, -logging 0.65b0. Todos requires_python >=3.10. Regra de pin: a instrumentação X.YbZ é acoplada à SDK 1.(Y+79) — nunca deixe o resolvedor escolher livremente; pine as duas famílias. Fluxo zero-code: `pip install opentelemetry-distro opentelemetry-exporter-otlp && opentelemetry-bootstrap -a install && opentelemetry-instrument --service_name melhor-mercado-api --traces_exporter otlp uvicorn app.main:app`.
FONTE: https://pypi.org/pypi/opentelemetry-instrumentation-fastapi/json

### [confirmada] pytest-asyncio 1.x removeu a fixture `event_loop` e exige pytest >= 8.4.0
pytest-asyncio 1.4.0 (2026-05-26), pytest 9.1.1 (2026-06-19). Breaking changes: 1.0.0 removeu a fixture `event_loop` (deprecada há muito) e passou a exigir pytest >=8.2.0; 1.3.0 dropou Python 3.9; 1.4.0 elevou o mínimo para pytest >=8.4.0 e depreciou a sobrescrita de `event_loop_policy` em favor do hook `pytest_asyncio_loop_factories`. Configuração atual correta em pyproject.toml: `asyncio_mode = "auto"` (default é `strict`, que exige @pytest.mark.asyncio em cada teste), `asyncio_default_fixture_loop_scope = "function"` e `asyncio_default_test_loop_scope = "function"` — declarar `asyncio_default_fixture_loop_scope` explicitamente elimina o DeprecationWarning emitido quando o valor está unset.
FONTE: https://pytest-asyncio.readthedocs.io/en/stable/reference/changelog.html

### [confirmada] httpx estável ainda é 0.28.1 (2024-12-06); `AsyncClient(app=...)` foi REMOVIDO na 0.28.0
Releases do httpx por data: 0.28.1 (2024-12-06), 1.0.dev3 (2025-09-15), 1.0.dev2 (2025-08-04), 1.0.dev1 (2025-07-02). Ou seja, httpx 1.0 continua em dev há mais de um ano e FastAPI pina `httpx<1.0.0`. O argumento `app=` foi removido em 0.28.0: use `httpx.ASGITransport()` explicitamente. Padrão correto de teste: `transport = ASGITransport(app=app); async with AsyncClient(transport=transport, base_url='http://test') as ac: ...`. CUIDADO: ASGITransport NÃO executa o lifespan do app — se você inicializa engine/pool no lifespan, envolva com `asgi_lifespan.LifespanManager(app)` (asgi-lifespan 2.1.0, último release 2023-03-28 — funciona mas está parado).
FONTE: https://github.com/encode/httpx/blob/master/CHANGELOG.md

### [confirmada] mypy virou 2.x (2.3.0, 2026-07-13) com três defaults invertidos que quebram código que passava no 1.x
mypy 2.0 lançado em 2026-05-06; atual 2.3.0 (2026-07-13, py>=3.10). Breaking: (1) `--python-version 3.9` não é mais aceito (mínimo 3.10); (2) `--local-partial-types` agora é DEFAULT, mudando a inferência de variáveis com mesmo nome em escopos diferentes; (3) `--strict-bytes` agora é DEFAULT (PEP 688) — passar bytearray/memoryview onde bytes é esperado deixa de type-checar. Feature principal: `--num-workers N` / `-nN` para type-checking paralelo, com até 5x de ganho com 8 workers (o ganho depende da estrutura de imports).
FONTE: https://mypy-lang.blogspot.com/2026/05/mypy-20-relased.html

### [confirmada] ruff 0.15.22 substitui black+isort+flake8, mas o formatter e o ordenador de imports são DOIS comandos separados
ruff 0.15.22 (2026-07-16, astral-sh/ruff 48.789 stars, push 2026-07-22 — ainda 0.x, sem 1.0). Doc oficial do formatter: '>99.9% of lines are formatted identically' a Black em projetos como Django e Zulip, mas 'the formatter is not intended to be used interchangeably with Black on an ongoing basis' (desvios conscientes: formata expressões dentro de f-strings, fluent layout de method chains em preview). Ordenação de imports NÃO é feita pelo formatter: é preciso rodar `ruff check --select I --fix` ANTES de `ruff format`. Para flake8, a cobertura vem das regras do linter (E, F, B, UP, SIM etc.).
FONTE: https://docs.astral.sh/ruff/formatter/

### [confirmada] uv 0.11.31 (2026-07-22) é o gerenciador de dependências recomendado, mas ainda não chegou a 1.0
uv 0.11.31, astral-sh/uv com 87.757 stars e push diário (2026-07-22). Comparativos de 2026 relatam ~3s vs ~11s do Poetry em cold install a partir do lockfile e ~8s vs ~22s na geração do lock; uv ultrapassou Poetry em downloads mensais no PyPI (~75M vs ~66M). Poetry está em 2.4.1 (2026-05-09) e continua válido para quem publica bibliotecas. pip-tools 7.6.0 (2026-07-18) segue mantido mas não gerencia venv nem versões de Python. Risco honesto do uv: continua em 0.x, então mudanças de comportamento entre minors são possíveis — pine a versão do uv no CI (`astral-sh/setup-uv@v6` com `version: 0.11.31`).
FONTE: https://pypi.org/pypi/uv/json

### [confirmada] Redis 8.8.0 é a estável atual (tri-licença AGPLv3/SSPLv1/RSALv2); Valkey 9.1.1 é BSD-3-Clause e é a escolha sem risco jurídico
Docker Hub library/redis: 8.8.0 / 8.8 / 8 / latest atualizados em 2026-07-16; 8.10-rc2 em RC (2026-07-22). Docker Hub valkey/valkey: 9.1.1 (2026-07-22), linha 9.0.5 também. Desde Redis 8.0 (maio/2025) a licença é tri-licença: AGPLv3 (aprovada pela OSI) OU SSPLv1 OU RSALv2. Para um app que NÃO revende Redis como serviço, AGPLv3 é aceitável; Valkey 9.1.1 (BSD) elimina a discussão. O protocolo é idêntico, então redis-py 8.0.1 funciona contra ambos sem alteração. AWS ElastiCache e GCP Memorystore já default para Valkey em clusters novos.
FONTE: https://hub.docker.com/v2/repositories/valkey/valkey/tags

### [confirmada] FastAPI não recomenda mais Gunicorn; a doc oficial de 2026 fala em `fastapi run --workers N` ou um único uvicorn por container
Doc fastapi.tiangolo.com/deployment/server-workers: mostra `fastapi run --workers 4 main.py` e `uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4` como equivalentes, e afirma 'when running on Kubernetes you will probably NOT want to use workers and instead run a single Uvicorn process per container'. Gunicorn não é mencionado nessa página. gunicorn continua vivo (26.0.0, 2026-05-05) mas deixou de ser a recomendação de referência. uvicorn 0.51.0 (2026-07-08, py>=3.10) — `uvicorn[standard]` traz uvloop 0.22.1, httptools 0.8.0 e watchfiles 1.2.0.
FONTE: https://fastapi.tiangolo.com/deployment/server-workers/

### [provavel] Granian 2.7.9 (Rust) é ~20-50% mais rápido em plaintext, mas a diferença some em carga I/O-bound como a do melhor_mercado
granian 2.7.9 (2026-07-03, py>=3.10). Benchmarks de 2026 reportam 20-50% mais throughput que uvicorn em cargas CPU-bound e ~35% em plaintext; para 'a typical CRUD API where each request blocks on a database query, the gap is much smaller — often within 10%'. Como o melhor_mercado é dominado por queries PostGIS/pg_trgm e por I/O de storage, o servidor ASGI não será o gargalo. Recomendação: uvicorn 0.51.0 agora, migrar para Granian só se o profiling apontar o servidor como bottleneck.
FONTE: https://pypi.org/pypi/granian/json

### [confirmada] testcontainers-python 4.14.2 tem extras para redis/localstack/minio, mas PostgresContainer está no core (não existe extra `postgres`)
testcontainers 4.14.2 (2026-03-18, py>=3.10). Extras publicados: arangodb, aws, azurite, chroma, clickhouse, cosmosdb, db2, generic, google, influxdb, k3s, keycloak, localstack, mailpit, minio, mongodb, mssql, mysql, nats, neo4j, openfga, opensearch, oracle, oracle-free, qdrant, rabbitmq, redis, registry, scylla, selenium, sftp, trino, weaviate. NÃO há extra `postgres` — `from testcontainers.postgres import PostgresContainer` vem no pacote base; você fornece o driver. Use `PostgresContainer('postgis/postgis:18-3.6', driver='psycopg')` para testar contra a mesma imagem de produção, com um fixture de escopo `session` e truncate por teste (não recriar o container por teste, sob pena de suíte de 20+ minutos).
FONTE: https://pypi.org/pypi/testcontainers/json

## ESPECIFICACOES CONCRETAS
- Bloco pronto para pyproject.toml (gerenciado por uv 0.11.31):

[project]
name = "melhor-mercado-api"
requires-python = ">=3.13,<3.14"
dependencies = [
  # web
  "fastapi==0.139.2",
  "starlette==1.3.1",
  "pydantic==2.13.4",
  "pydantic-settings==2.14.2",
  "uvicorn[standard]==0.51.0",
  "python-multipart==0.0.32",
  "email-validator==2.3.0",
  "orjson==3.11.9",
  # banco
  "sqlalchemy[asyncio]==2.0.51",
  "psycopg[binary,pool]==3.3.4",
  "alembic==1.18.5",
  "geoalchemy2==0.20.0",
  "shapely==2.1.2",
  # fila
  "procrastinate==3.9.0",
  # cache
  "redis[hiredis]==8.0.1",
  # storage
  "boto3==1.43.53",
  # auth
  "pyjwt[crypto]==2.13.0",
  "cryptography==49.0.0",
  "pwdlib[argon2]==0.3.0",
  "google-auth==2.56.2",
  "httpx==0.28.1",
  # resiliencia
  "tenacity==9.1.4",
  # observabilidade
  "structlog==26.1.0",
  "asgi-correlation-id==5.0.1",
  "sentry-sdk[fastapi]==2.66.1",
  "prometheus-client==0.25.0",
  "opentelemetry-sdk==1.44.0",
  "opentelemetry-exporter-otlp==1.44.0",
  "opentelemetry-instrumentation-fastapi==0.65b0",
  "opentelemetry-instrumentation-sqlalchemy==0.65b0",
  "opentelemetry-instrumentation-psycopg==0.65b0",
  "opentelemetry-instrumentation-redis==0.65b0",
  "opentelemetry-instrumentation-httpx==0.65b0",
  "opentelemetry-instrumentation-logging==0.65b0",
]

[dependency-groups]
dev = [
  "pytest==9.1.1",
  "pytest-asyncio==1.4.0",
  "pytest-cov==7.1.0",
  "pytest-mock==3.15.1",
  "testcontainers==4.14.2",
  "polyfactory==3.3.0",
  "respx==0.23.1",
  "time-machine==3.2.0",
  "dirty-equals==0.11",
  "asgi-lifespan==2.1.0",
  "ruff==0.15.22",
  "mypy==2.3.0",
  "pre-commit==4.6.1",
]
- Config de teste (pyproject.toml):
[tool.pytest.ini_options]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "function"
asyncio_default_test_loop_scope = "function"
addopts = "-q --strict-markers --strict-config"
(declarar asyncio_default_fixture_loop_scope explicitamente elimina o DeprecationWarning; sem isso o default ainda é o escopo da fixture e vai mudar para 'function' numa versão futura)
- Config ruff (pyproject.toml):
[tool.ruff]
target-version = "py313"
line-length = 100
[tool.ruff.lint]
select = ["E","F","W","I","N","UP","B","A","C4","T20","SIM","ASYNC","S","RUF"]
ignore = ["E501"]
[tool.ruff.lint.per-file-ignores]
"tests/**" = ["S101"]
Pipeline: `ruff check --select I --fix .` → `ruff format .` → `ruff check .`
- Config mypy (pyproject.toml):
[tool.mypy]
python_version = "3.13"
strict = true
plugins = ["pydantic.mypy"]
CLI: `mypy -n 8 app/` (flag --num-workers/-n é novidade da mypy 2.0; até 5x mais rápido com 8 workers)
- URLs de conexão SQLAlchemy: async = `postgresql+psycopg://user:pass@host:5432/melhor_mercado` usado com create_async_engine; sync (Alembic) = MESMA string usada com create_engine. Alternativa asyncpg (só se abandonar Procrastinate) = `postgresql+asyncpg://...` + sync separado `postgresql+psycopg2://...`.
- Versões de infra (Docker):
- postgis/postgis:18-3.6 (tag confirmada, atualizada 2026-07-20) → PostgreSQL 18.4 + PostGIS 3.6
- pgvector v0.8.5 compilado por cima (mínimo aceitável: v0.8.3)
- valkey/valkey:9.1.1 (BSD-3) OU redis:8.8.0 (tri-licença AGPLv3/SSPLv1/RSALv2)
- chrislusf/seaweedfs:4.40 (Apache-2.0) OU dxflrs/garage:v2.3.0 (AGPL-3.0) para S3 local
- python:3.13-slim-trixie como base da API/worker
- NÃO: minio/minio:latest (imagem congelada em RELEASE.2025-09-07T16-13-09Z)
- Extensões Postgres da migração 0001: CREATE EXTENSION IF NOT EXISTS postgis; pg_trgm; unaccent; btree_gin; citext; vector; pg_stat_statements. Índices-chave: GIST em geography(Point,4326) para ST_DWithin em metros; GIN com gin_trgm_ops sobre f_unaccent(lower(nome_produto)) para busca fuzzy PT-BR; HNSW (vector_cosine_ops) para matching semântico de produto.
- Parâmetros de tempo/limite sugeridos: access token TTL 900s (15 min); refresh token TTL 7.776.000s (90 dias), 32 bytes de entropia (secrets.token_urlsafe(32)), armazenado como SHA-256; presigned POST de upload expira em 900s com content-length-range 1..15728640 bytes (15 MB); presigned GET expira em 3600s; teto absoluto SigV4 = 604800s (7 dias). Retry de OCR: max_attempts=5, exponential_wait=5 → 5s/25s/125s/625s. Heartbeat do worker Procrastinate: 10s (default); detecção de stalled: usar seconds_since_heartbeat=120 (e não os 30s default) porque o OCR legítimo dura até 60s. Buckets do histograma ocr_job_duration_seconds: 1,2,5,10,20,30,60,120.
- Assinatura de enqueue idempotente (Procrastinate): `await ocr_task.configure(priority=10, queueing_lock=f"nfce:{chave_acesso}", schedule_in={"seconds": 0}).defer_async(document_id=str(doc.id), request_id=rid, traceparent=tp)` dentro do mesmo `async with session.begin()`; capturar `procrastinate.exceptions.AlreadyEnqueued` e retornar 200 com o documento existente (idempotência do endpoint).
- Comandos de worker: `procrastinate --app=app.tasks.app worker --queues=ocr_user --concurrency=4` e `procrastinate --app=app.tasks.app worker --queues=ocr_batch,normalize --concurrency=2`. Schema: `procrastinate --app=app.tasks.app schema --apply` (rodar antes do primeiro deploy; excluir tabelas procrastinate_* do autogenerate do Alembic).
- Auto-instrumentação OTel: `opentelemetry-bootstrap -a install` e depois `opentelemetry-instrument --service_name melhor-mercado-api --traces_exporter otlp --metrics_exporter otlp --logs_exporter otlp uvicorn app.main:app --host 0.0.0.0 --port 8000`. Regra de pin: família SDK 1.44.0 casa com família de instrumentação 0.65b0 — nunca deixe o resolvedor escolher independentemente.
- Extras verificados no PyPI (2026-07-22): sentry-sdk → fastapi, asyncio, asyncpg, celery, httpx, opentelemetry, opentelemetry-otlp, arq, huey, litestar (entre outros); pwdlib → argon2, bcrypt; pyjwt → crypto; redis → hiredis, otel, jwt, circuit-breaker, ocsp, xxhash; sqlalchemy → asyncio, postgresql-psycopg, postgresql-psycopgbinary, postgresql-asyncpg, mypy; testcontainers → redis, localstack, minio, rabbitmq, aws (NÃO existe extra 'postgres' — PostgresContainer está no core).

## RECOMENDACOES
- RUNTIME: pinar Python 3.13.14 (`FROM python:3.13-slim-trixie`) para a API e para os workers. 3.14.6 é uma alternativa legítima (EOL 2030-10 vs 2029-10) mas 3.13 tem cobertura de wheels nativas mais previsível para o lado de imagem/OCR. NÃO usar 3.10 (EOL em 2026-10, daqui a ~3 meses) nem 3.12 (já security-only).
- DRIVER POSTGRES — decisão central: usar `psycopg[binary,pool]==3.3.4` com URL `postgresql+psycopg://` para TUDO (FastAPI async, Alembic sync, workers, scripts de importação). Motivos: (a) é pré-requisito para o enqueue transacional do Procrastinate — asyncpg não é suportado por ele; (b) evita a armadilha `DuplicatePreparedStatementError` do asyncpg atrás de PgBouncer em transaction pooling; (c) um único driver em vez de asyncpg+psycopg2; (d) COPY nativo para bulk-insert de itens de encarte/cupom. Em produção use `psycopg[c,pool]` (compilado) em vez de `[binary]` se você controlar o build da imagem.
- FILA — recomendação única: **Procrastinate 3.9.0** sobre o mesmo PostgreSQL 18.4. Justificativa para o caso 'OCR de 5-60s': (1) RETRY nativo via `RetryStrategy(max_attempts=5, exponential_wait=5, retry_exceptions=(TransientOcrError,))` → 5s/25s/125s/625s; (2) DEAD-LETTER superior: o job falho fica para sempre em `procrastinate_jobs` com status='failed', consultável por SQL e reprocessável com `JobManager.retry_job()` — a DLQ do Dramatiq descarta após 7 dias e a do Celery não existe nativamente com broker Redis; (3) PRIORIDADE nativa por job (inteiro, maior=antes) → `priority=10` para foto de cupom enviada por usuário aguardando resposta, `priority=0` para importação em lote de encarte de admin; (4) IDEMPOTÊNCIA nativa via `queueing_lock=f'nfce:{chave_acesso}'` levantando `AlreadyEnqueued`, combinada com UNIQUE constraint em `documento.dedupe_key`; (5) ENQUEUE TRANSACIONAL: o INSERT do documento e o INSERT do job acontecem na MESMA transação psycopg — elimina os dois bugs clássicos (job enfileirado antes do commit → worker não acha a linha; commit feito e enqueue perdido → documento órfão); (6) zero infra nova, zero broker a operar/backupear.
- MITIGAR O RISCO DO PROCRASTINATE: definir uma porta `TaskQueue` (`enqueue_ocr(document_id, *, priority, dedupe_key) -> None`) em `app/ports/queue.py` com uma implementação `ProcrastinateTaskQueue`. Isso torna a troca por Dramatiq/Celery um trabalho de ~1 dia. Se a decisão for pelo caminho mais conservador em ecossistema, o segundo lugar é **Dramatiq 2.2.0 + Redis** (asyncio desde 2.0, DLQ nativa, retries com backoff) — nesse cenário a idempotência vira responsabilidade da aplicação (SETNX no Redis com TTL + UNIQUE no Postgres) e a prioridade vira 'filas separadas + workers dedicados'.
- OPERAÇÃO DA FILA: separar filas por natureza da carga — `ocr_user` (fotos/QR de usuário, latência importa), `ocr_batch` (encartes de admin), `normalize` (matching de produto). Rodar workers com `procrastinate worker --queues ocr_user --concurrency 4` em processos/containers distintos. OBRIGATÓRIO: jobs travados NÃO são recuperados automaticamente — registrar uma tarefa periódica `@app.periodic(cron='*/5 * * * *')` que chama `JobManager.get_stalled_jobs(seconds_since_heartbeat=120)` e faz `retry_job()`. Usar 120s (e não os 30s default) porque um OCR legítimo dura até 60s. Adicionar também um job de pruning (`procrastinate_jobs` com status succeeded > 30 dias) para não deixar a tabela inchar e pressionar o autovacuum do mesmo cluster que serve as buscas de preço.
- BANCO: imagem base própria `FROM postgis/postgis:18-3.6` + compilar pgvector v0.8.5 (>=0.8.3 é obrigatório: 0.8.3 corrigiu corrupção de índice HNSW e regressão de performance no PG18). Extensões a criar na migração inicial do Alembic: `postgis`, `pg_trgm` (busca fuzzy de nome de produto — GIN sobre `gin_trgm_ops`), `unaccent` (normalizar acentos de PT-BR; combinar em uma função IMMUTABLE `f_unaccent(text)` para poder indexar), `btree_gin` (índices compostos `GIN (mercado_id, nome_normalizado gin_trgm_ops)`), `citext` (emails/EAN case-insensitive), `vector` (embeddings para matching semântico de produtos), `pg_stat_statements` (obrigatório para tuning). Índice geoespacial: `GIST (localizacao)` com `geography(Point,4326)` — use geography, não geometry, para que `ST_DWithin(loc, ponto, 5000)` trabalhe em metros direto.
- ALEMBIC + POSTGIS: no `env.py`, adicionar `include_object` que retorna False para as tabelas/views de sistema do PostGIS (`spatial_ref_sys`, `geometry_columns`, `geography_columns`, `raster_columns`, `raster_overviews`, `topology`, `layer`) e para `procrastinate_*` (cujo schema é gerido pelo `procrastinate schema --apply`). Adicionar `import geoalchemy2` ao `script.py.mako`, senão as migrações geradas não importam o tipo `Geography`. Rodar Alembic em modo SÍNCRONO com `postgresql+psycopg://` — a mesma URL, sem async.
- STORAGE: NÃO usar `minio/minio:latest` em ambiente novo (repo arquivado, imagem congelada em 2025-09-07, sem o fix da release Security/CVE de 2025-10-15). Para dev/compose e self-host pequeno use **SeaweedFS 4.40** (`chrislusf/seaweedfs:4.40`, Apache-2.0, S3 gateway compatível) ou **Garage v2.3.0** (`dxflrs/garage:v2.3.0`, AGPL-3.0, single-binary, ótimo para 1-3 nós). Em produção real, prefira um provedor S3 gerenciado (Cloudflare R2 / Backblaze B2 / AWS S3) e mantenha o SeaweedFS só para o docker-compose de desenvolvimento — o código não muda, só o endpoint.
- UPLOAD: o app Flutter nunca deve enviar bytes de imagem através da API. Fluxo: POST /uploads/intent (o backend valida, cria `documento` com status='aguardando_upload' e devolve um `generate_presigned_post` com expiração de 900s, `content-length-range` de 1 a 15.728.640 bytes (15 MB) e Content-Type restrito a image/jpeg|image/png|image/heic|application/pdf) → app faz POST multipart direto no S3 → app chama POST /uploads/{id}/complete → backend faz HEAD no objeto para confirmar tamanho/ETag e só então enfileira o job de OCR na mesma transação. Para leitura, presigned GET com expiração de 3600s. Nunca ultrapassar 604800s (7 dias, limite SigV4) e lembrar que com credencial STS a URL morre junto com a credencial.
- AUTH — desenho concreto: (1) Access token JWT próprio, HS256 não — usar **EdDSA (Ed25519)** ou ES256 com `pyjwt[crypto]==2.13.0`, TTL de 15 minutos, claims `sub` (user_id UUID), `sid` (session/device id), `jti`, `typ='access'`, `exp`, `iat`, `iss`, `aud`. Publicar JWKS em /.well-known/jwks.json para permitir rotação de chave sem downtime. (2) Refresh token: NÃO é JWT — é 32 bytes de `secrets.token_urlsafe(32)`, armazenado no Postgres como hash SHA-256 na tabela `refresh_token(id, user_id, device_id, token_hash, family_id, parent_id, expires_at, revoked_at, user_agent, ip)`, TTL de 90 dias, com ROTAÇÃO a cada uso (RFC 9700 §4.14 exige para cliente público). Detecção de reuso: se chegar um refresh já rotacionado, revogar toda a `family_id` e forçar re-login. (3) Device binding: gerar um `device_id` no primeiro start do app, guardar em `flutter_secure_storage` (Keychain/Keystore), enviar como header `X-Device-Id`; o refresh token é emitido amarrado a esse device_id e o refresh é recusado se o header divergir. Não é DPoP completo (que exigiria prova de posse de chave), mas eleva bastante o custo de roubo de token — assumir isso explicitamente. (4) Login anônimo/convidado: criar `user` com `is_anonymous=true` e sem credencial, emitindo o par de tokens normalmente; o upgrade é um POST /auth/link que anexa a credencial (Google/Apple/email) ao MESMO user_id, preservando histórico de contribuições — implementar como operação idempotente e recusar o link se o provider já estiver ligado a outro user (nesse caso, oferecer merge explícito). (5) Sign in with Google: o app obtém o ID token nativamente; o backend valida com `google-auth==2.56.2` (`google.oauth2.id_token.verify_oauth2_token`) checando `aud` contra os client_ids Android/iOS/Web e `iss` in {accounts.google.com, https://accounts.google.com}. (6) Sign in with Apple: validar o identity token contra o JWKS de https://appleid.apple.com/auth/keys com PyJWT + PyJWKClient. ATENÇÃO à guideline 4.8: se você oferecer Google Sign-In, é OBRIGATÓRIO oferecer também Sign in with Apple (ou outro provedor que atenda os 3 critérios). Se oferecer só conta própria, 4.8 não se aplica.
- NÃO reimplementar OAuth server. Não há authorization server aqui — o backend é apenas Resource Server + emissor de sessão própria. Se em algum momento surgir necessidade de um IdP completo (multi-app, SSO de parceiros), aí sim avaliar Authlib 1.7.2 ou um Keycloak, mas não antecipe (YAGNI).
- OBSERVABILIDADE — correlação request_id → task_id: (1) `asgi-correlation-id==5.0.1` como middleware, lendo/gerando `X-Request-ID` e populando um ContextVar. (2) `structlog==26.1.0` com o processor `structlog.contextvars.merge_contextvars` para que TODO log da request carregue request_id automaticamente, e `structlog.processors.JSONRenderer()` (ou `orjson` renderer) em produção / `ConsoleRenderer` em dev. (3) Ao enfileirar, propagar explicitamente: passar `request_id` e o `traceparent` do OTel como argumentos do job (`ocr_task.configure(priority=10, queueing_lock=k).defer(document_id=..., request_id=..., traceparent=...)`); no worker, fazer `bind_contextvars(request_id=..., job_id=context.job.id)` e reconstruir o span pai com `TraceContextTextMapPropagator().extract({'traceparent': traceparent})`. Isso é o que fecha o loop request→task, e é manual — nenhuma auto-instrumentação faz isso para Procrastinate. (4) Instrumentar API e worker com opentelemetry-sdk 1.44.0 + instrumentações 0.65b0 (fastapi, sqlalchemy, psycopg, redis, httpx, logging). (5) `sentry-sdk[fastapi]==2.66.1` com `traces_sample_rate` baixo (0.05) e `send_default_pii=False`; ligar o `SentrySpanProcessor` para que os eventos do Sentry apontem o mesmo trace_id do OTel. (6) `prometheus-client==0.25.0` expondo /metrics em porta SEPARADA (ex.: 9090) e não na API pública. Métricas de negócio obrigatórias: `ocr_job_duration_seconds` (histogram com buckets 1,2,5,10,20,30,60,120), `ocr_job_failures_total{reason}`, `procrastinate_jobs_backlog{queue,status}` (via query SQL). (7) Endpoints separados: `GET /healthz` (liveness, retorna 200 sem tocar em nada) e `GET /readyz` (readiness: SELECT 1 no Postgres com timeout de 2s + PING no Redis + HEAD no bucket) — nunca colapse os dois, senão um blip do banco derruba o pod inteiro em vez de só tirá-lo do load balancer.
- TESTES: pytest 9.1.1 + pytest-asyncio 1.4.0 em `asyncio_mode='auto'`, com `asyncio_default_fixture_loop_scope='function'` e `asyncio_default_test_loop_scope='function'` declarados explicitamente. Banco de teste com `testcontainers==4.14.2` usando a MESMA imagem de produção (`postgis/postgis:18-3.6` com pgvector), container em fixture de escopo `session`, migrações Alembic rodadas UMA vez, e isolamento por teste via transação externa com SAVEPOINT (`connection.begin()` + `session = AsyncSession(bind=connection, join_transaction_mode='create_savepoint')` + rollback no teardown) — muito mais rápido que TRUNCATE. Cliente HTTP: `AsyncClient(transport=ASGITransport(app=app), base_url='http://test')` envolvido em `LifespanManager` (asgi-lifespan 2.1.0) para que o lifespan realmente rode. Fila em teste: `procrastinate.testing.InMemoryConnector` para asserção sobre jobs enfileirados sem worker. HTTP externo (Google/Apple JWKS): `respx==0.23.1`. Tempo: `time-machine==3.2.0` (não freezegun — time-machine é C-based, ~10x mais rápido e não quebra com asyncio timers). Fábricas: `polyfactory==3.3.0` (nativo para Pydantic v2 e SQLAlchemy, diferente do factory-boy que é sync/ORM-cêntrico). CUIDADO com event loop: nunca criar engine SQLAlchemy em escopo de módulo — o pool fica preso ao loop do primeiro teste; crie o engine dentro de uma fixture cujo loop scope case com o dos testes.
- QUALIDADE: `ruff==0.15.22` como linter + formatter, com pipeline em DUAS etapas (`ruff check --select I --fix` antes de `ruff format`, porque o formatter não ordena imports). Regras sugeridas: `select = ["E","F","W","I","N","UP","B","A","C4","T20","SIM","ASYNC","S","RUF"]` — `ASYNC` pega blocking calls em código async (crítico neste stack) e `S` (bandit) pega os problemas de segurança óbvios. `mypy==2.3.0` em `strict = true` com `-n 8` (paralelo, novidade da 2.0) — orçar 1 sprint para absorver as 3 flags viradas por default (local_partial_types, strict_bytes, drop de --python-version 3.9). Preferir mypy a pyright aqui porque o plugin do SQLAlchemy 2.0 e o suporte a Pydantic v2 são de primeira classe no mypy. `pre-commit==4.6.1` rodando ruff-check→ruff-format→mypy (nessa ordem).
- DEPENDÊNCIAS: adotar **uv 0.11.31** com `pyproject.toml` + `uv.lock` commitado. Usar `[dependency-groups]` (PEP 735) em vez de extras para dev/test. No Dockerfile, multi-stage com `COPY --from=ghcr.io/astral-sh/uv:0.11.31 /uv /bin/uv` e `uv sync --frozen --no-dev --no-install-project` antes de copiar o código (cache de camada). Pinar a versão do próprio uv no CI. Não misturar poetry e uv no mesmo repo.

## NAO FAZER
- NÃO usar `minio/minio:latest` em nenhum ambiente novo. O repositório está arquivado (archived=true), a última imagem do Docker Hub é de 2025-09-07 e a release de segurança RELEASE.2025-10-15T17-29-55Z NUNCA foi publicada como imagem lá (a consulta à tag retorna 404). Rodar `latest` significa rodar um binário sem o fix de CVE de outubro/2025. Também não adote o fork OpenMaxIO — sem push desde 2025-06-24.
- NÃO usar `python-jose`. Tem duas advisories CRITICAL (GHSA-6c5p-j8vq-pqhj, algorithm confusion com chaves ECDSA do OpenSSH; GHSA-w799-prg3-cx77, comparação não-constante de HMAC) e manutenção fraca. O tutorial de segurança do FastAPI historicamente citava python-jose — ignore esse trecho e use `pyjwt[crypto]==2.13.0`.
- NÃO usar `passlib`. Último release em 2020-10-08, sem `requires_python`, e quebra com bcrypt>=4.1 (`AttributeError: module 'bcrypt' has no attribute '__about__'`) — bcrypt atual é 5.0.0. Use `pwdlib[argon2]==0.3.0`.
- NÃO usar SQLAlchemy 2.1 — está em 2.1.0b3 (beta, 2026-06-27). Fique em 2.0.51. E NÃO esqueça o extra: a partir de jan/2026 o greenlet deixou de ser instalado por default; `sqlalchemy==2.0.51` sem `[asyncio]` falha em runtime com `MissingGreenlet`/ImportError no primeiro await.
- NÃO deixar `starlette` sem pin. FastAPI 0.139.2 declara apenas `starlette>=0.46.0` sem teto e o resolvedor trará a 1.3.1 (major nova). Pine explicitamente.
- NÃO combinar asyncpg com Procrastinate esperando enqueue transacional — Procrastinate não tem conector asyncpg (só psycopg3, psycopg2 e aiopg). Se você insistir em asyncpg, o enqueue vira uma segunda conexão fora da sua transação e você reintroduz exatamente a race que a fila em Postgres existe para eliminar.
- NÃO colocar asyncpg atrás de PgBouncer em pool_mode=transaction sem `statement_cache_size=0` + `prepared_statement_cache_size=0` — o erro `prepared statement "__asyncpg_stmt_X__" already exists` aparece de forma intermitente sob carga e é difícil de diagnosticar.
- NÃO usar pgvector < 0.8.3 no PostgreSQL 18. A 0.8.3 corrigiu 'possible index corruption with HNSW vacuuming' e uma regressão de performance de Hamming/Jaccard específica do PG18; a 0.8.2 corrigiu buffer overflow em build HNSW paralelo.
- NÃO depender da fixture `event_loop` do pytest-asyncio — foi REMOVIDA na 1.0.0. Qualquer tutorial que faça `@pytest.fixture def event_loop(): ...` é de 2023/2024 e vai quebrar.
- NÃO usar `httpx.AsyncClient(app=app)` — removido na httpx 0.28.0. E não assuma que `ASGITransport` roda o lifespan: ele não roda; sem `LifespanManager`, o engine/pool criado no lifespan simplesmente não existe nos testes e você vê `AttributeError: 'NoneType' object has no attribute 'begin'`.
- NÃO contar com o Flower como plano de observabilidade de fila: está em 2.0.1 desde 2023-08-13 (~3 anos sem release). Se escolher Celery por causa do ecossistema, saiba que essa parte do ecossistema está parada.
- NÃO esperar que o Procrastinate recupere sozinho os jobs travados. `get_stalled_jobs()` existe mas a recuperação exige que VOCÊ registre uma tarefa periódica chamando `retry_job()`. Sem isso, um worker morto (OOM durante o OCR) deixa o job em 'doing' para sempre.
- NÃO usar `--workers` do uvicorn dentro de container orquestrado. A própria doc do FastAPI de 2026 diz: 'when running on Kubernetes you will probably NOT want to use workers and instead run a single Uvicorn process per container'. Um processo por container, réplicas pelo orquestrador.
- NÃO deixar o /metrics do Prometheus na mesma porta/roteador público da API sem autenticação — expõe cardinalidade de rotas e volume de negócio. Porta separada + network policy.
- NÃO raspar sites de supermercado, portais de NFC-e ou APIs da SEFAZ contornando CAPTCHA, autenticação, rate limit, robots.txt ou termos de uso. Isso não é uma questão de dificuldade técnica: é ilegal/contratualmente vedado e não deve ser projetado. Se um dado só for obtenível dessa forma, a resposta correta é NÃO obtê-lo por essa via. As alternativas legítimas são: (a) o próprio usuário submeter o QR Code/cupom que ELE recebeu — que é exatamente o modelo colaborativo do produto; (b) convênio/API oficial com a SEFAZ estadual quando existir; (c) acordo comercial com a rede de supermercado para receber o encarte; (d) programas de afiliados/feeds públicos onde os termos permitem explicitamente. Documente no ADR qual base legal sustenta cada fonte.
- NÃO reinventar um authorization server OAuth 2.0. Aqui não existe terceiro pedindo autorização em nome do usuário — o backend é apenas emissor de sessão própria e Resource Server.

## RISCOS
- MinIO como ponto cego de segurança: qualquer tutorial, template ou docker-compose de 2024/2025 vai sugerir minio/minio. Se alguém no time copiar isso, o projeto sobe com um binário sem o patch de segurança de out/2025 e sem console administrativo. Mitigação: bloquear `minio/minio` no scan de imagem do CI e documentar a substituição no ADR de storage.
- Procrastinate é o elo mais frágil da recomendação: 1.341 stars, 89 issues abertas, base de mantenedores pequena. Se o projeto estagnar, a migração para Dramatiq/Celery é factível mas não trivial (tabela, admin, semântica de lock). Mitigação obrigatória: porta `TaskQueue` abstraindo o enqueue e nenhum import de `procrastinate` fora da camada de infraestrutura.
- Fila no mesmo cluster Postgres que serve as buscas de preço: `procrastinate_jobs` é uma tabela de alta rotatividade (INSERT/UPDATE/DELETE) e pressiona o autovacuum do mesmo banco que responde as queries PostGIS/pg_trgm dos usuários. Mitigação: schema separado, `autovacuum_vacuum_scale_factor=0.01` na tabela de jobs, job de pruning diário e monitoramento de bloat. Se o volume passar de ~1M jobs/dia, mover a fila para um Postgres dedicado ou trocar para Redis+Dramatiq.
- `queueing_lock` do Procrastinate garante unicidade apenas enquanto o job está em status 'todo' — 'it allows multiple jobs to be in doing status'. Ou seja, se o usuário reenviar a mesma NFC-e enquanto o primeiro job já está executando, um segundo job É criado. A idempotência real precisa de defesa em profundidade: UNIQUE constraint em `documento.dedupe_key` (chave de acesso da NFC-e, 44 dígitos) + a task começar com um SELECT do documento e abortar se já estiver processado.
- Starlette 1.x sem teto declarado no FastAPI: uma resolução de dependência descuidada pode trazer um major novo em qualquer `uv lock` futuro. Middlewares customizados baseados em `BaseHTTPMiddleware` são os primeiros a quebrar.
- Upgrade do mypy 1.x → 2.x vai gerar uma enxurrada de erros novos por causa das três flags viradas (local_partial_types, strict_bytes, drop de 3.9). Se o projeto começar já em 2.3.0, o custo é zero; se começar em 1.x e migrar depois, orce um sprint.
- httpx travado em 0.28.1 desde dez/2024 com 1.0 em dev há mais de um ano, e o repo encode/httpx com último push em 2026-03-29. Não é abandono, mas é estagnação — e o FastAPI pina `httpx<1.0.0`, então o dia em que a 1.0 sair haverá um período de incompatibilidade entre `fastapi[standard]` e a nova httpx.
- asgi-lifespan 2.1.0 é de 2023-03-28 (mais de 3 anos sem release) e é dependência de teste no caminho crítico. Se quebrar com uma Starlette futura, a alternativa é escrever manualmente o disparo dos eventos de lifespan (~30 linhas) ou usar `TestClient` síncrono do Starlette, que já roda o lifespan.
- Instrumentações OpenTelemetry ainda são 0.65b0 (BETA) — quebras de API entre minors são esperadas e as convenções semânticas de HTTP/DB ainda migram. Não construa dashboards/alertas acoplados a nomes de atributo sem uma camada de tradução.
- Conformidade com a guideline 4.8 da Apple: adicionar Google Sign-In sem adicionar Sign in with Apple gera rejeição na App Review. Isso não é opcional nem negociável, e o custo (Apple Developer + endpoint de callback + tratamento do email privado relay @privaterelay.appleid.com, que só vem no PRIMEIRO login) costuma ser subestimado.
- Device binding via header `X-Device-Id` NÃO é sender-constrained no sentido do RFC 9700 (não há prova de posse de chave, como em DPoP/mTLS). É uma mitigação de custo, não uma garantia criptográfica. Se o modelo de ameaça incluir malware no dispositivo, é preciso DPoP (RFC 9449) real — o que hoje não tem biblioteca Python madura de servidor pronta para uso, então seria implementação própria com todo o risco associado.
- LGPD: NFC-e contém CPF do consumidor quando informado na nota, além de localização de compra e padrão de consumo. O pipeline de OCR precisa redigir/descartar CPF e dados do emitente não necessários ANTES de persistir, e as imagens originais em S3 precisam de política de retenção e de resposta a pedido de eliminação. Isso muda o modelo de dados (separar `documento_raw` com TTL de `item_preco` que é o dado agregado) e é muito mais caro de retrofitar depois.
- uv ainda é 0.x (0.11.31). Mudanças de comportamento entre minors já aconteceram no passado do projeto. Pine a versão do uv no CI e no Dockerfile — não use `latest`.

## EM ABERTO
- Não confirmei a versão exata de patch do PostGIS na tag `postgis/postgis:18-3.6` (a tag é móvel). Busca web indicou PostGIS 3.6.4 lançado em 2026-06-08 e 3.6.3 em maio/2026, mas não verifiquei em fonte primária (postgis.net/news). Antes de fixar no ADR, rode `SELECT postgis_full_version();` na imagem puxada e registre o digest SHA da imagem em vez da tag móvel.
- Não confirmei se existe uma imagem Docker mantida que já combine PostgreSQL 18 + PostGIS 3.6 + pgvector (existe `imresamu/postgis` e derivados na comunidade, mas não verifiquei manutenção nem procedência). Assumi que será necessário um Dockerfile próprio. Vale 30 minutos de verificação antes de escrever o Dockerfile.
- Não medi o overhead real de psycopg3 async vs asyncpg neste workload. A afirmação de que 'a diferença é irrelevante para queries PostGIS/pg_trgm' é INFERÊNCIA minha, não fato verificado. Se a latência p99 da busca for crítica, faça um benchmark com o schema real antes de fechar a decisão do driver.
- Não verifiquei se o Sentry SDK 2.66.1 tem integração dedicada para Procrastinate (a lista de extras mostra celery, arq e huey, mas não procrastinate). Provavelmente será necessário um wrapper manual no `on_job_error` do worker para reportar exceções com contexto de job.
- Não verifiquei se existe pacote de auto-instrumentação OpenTelemetry para Procrastinate. Provavelmente não existe — a propagação de contexto request→job terá que ser manual (passar traceparent como argumento do job e reextrair no worker).
- Não pesquisei o lado de OCR propriamente dito (Tesseract vs PaddleOCR vs API de nuvem, e a leitura do QR Code da NFC-e). Isso é outro tópico, mas afeta diretamente o dimensionamento da fila: se o OCR for chamada a API externa, a concorrência do worker é limitada por rate limit do fornecedor, não por CPU.
- Não confirmei o estado atual de disponibilidade de APIs oficiais de consulta de NFC-e por SEFAZ estadual (varia por UF; algumas exigem certificado digital A1/A3 e credenciamento). Essa é a única via legítima de enriquecer dados além do que o usuário submete, e precisa de pesquisa jurídica/técnica dedicada por estado antes de virar requisito de arquitetura.
- Não verifiquei o suporte do Garage v2.3.0 a `generate_presigned_post` (POST policy) — nem todo servidor S3-compatível implementa POST policy com a mesma fidelidade do `PUT` pré-assinado. Teste isso antes de escolher Garage, porque o fluxo de upload direto do Flutter depende disso.
- pyzbar 0.1.9 é de 2022-03-15 e não declara requires_python — se a leitura de QR Code da NFC-e for feita no backend, essa dependência precisa ser reavaliada (alternativas: opencv `QRCodeDetector`, zxing-cpp). Não investiguei porque foge do escopo deste tópico.


################################################################
# TOPICO: Stack Flutter/Dart de producao para melhor_mercado — Flutter 3.44.7 stable / Dart 3.12.2 (verificado em 2026-07-22)
################################################################

## RESUMO EXECUTIVO
Ambiente local confirmado: Flutter 3.44.7 (rev 84fc5cbb22, 2026-07-17), Dart 3.12.2, Android SDK 36.1.0, Xcode 26.6, NDK 28.2.13676358.
NAO chutei versoes: consultei a API do pub.dev (https://pub.dev/api/packages/<nome>), montei um projeto-sonda real, rodei `flutter pub get`, `dart run build_runner build`, `flutter analyze` e `flutter build apk` com TODO o stack candidato. Tudo abaixo tem lastro empirico.
DESCOBERTA CRITICA #1: o ecossistema de codegen esta fraturado na transicao analyzer 12 -> 13. freezed estavel (3.2.5) exige analyzer >=9 <11; riverpod_generator 4.0.4 e riverpod_lint 3.1.4 exigem analyzer ^12; drift_dev >=2.34.1 e build_runner >=2.15.2 exigem analyzer ^13. NAO EXISTE conjunto que junte freezed estavel + riverpod codegen + drift codegen hoje. Provei os 3 conflitos com mensagens reais do pub solver.
SOLUCAO VALIDADA: abandonar freezed e usar sealed/final classes nativas do Dart 3.12 + pattern matching + json_serializable. Com isso o pipeline riverpod_generator 4.0.4 + json_serializable 6.14.0 + go_router_builder 4.4.0 + drift_dev 2.34.0 + build_runner 2.15.1 (analyzer 12.1.0) gera codigo e passa `flutter analyze` com "No issues found". Isso e exatamente a direcao do proprio freezed 3.x, que ja removeu map/when em favor de pattern matching.
DESCOBERTA CRITICA #2: sqlite3_flutter_libs esta EOL (0.6.0+eol, no-op). package:sqlite3 3.x carrega o nativo via build hooks. Setup atual de drift = drift + drift_flutter + drift_dev.
DESCOBERTA CRITICA #3: Google Play exige targetSdk 36 para apps novos a partir de 31/08/2026 — 40 dias. Flutter 3.44.7 ja entrega compileSdk 36 / targetSdk 36 / minSdk 24 por default. Build APK real produziu todos os .so com align 2**14 ou 2**16 => conforme ao requisito de 16 KB page size.
ALERTA DE PRAZO: Flutter 3.44 iniciou o desacoplamento de Material/Cupertino para os pacotes material_ui / cupertino_ui (0.0.2, publicados em 21-22/07/2026). Nao usar ainda; planejar migracao.
ALERTA DE BUILD: o build Android emitiu warning de que dynamic_color, flutter_image_compress_common, mobile_scanner, patrol e sentry_flutter ainda aplicam o Kotlin Gradle Plugin e vao QUEBRAR em versoes futuras do Flutter (Built-in Kotlin do AGP 9).

## ACHADOS

### [confirmada] Ambiente local confirmado: Flutter 3.44.7 stable, Dart 3.12.2, DevTools 2.57.0
`flutter --version`: Framework rev 84fc5cbb22 (2026-07-17), Engine hash 7076f47b1d1a (rev 69c8c61792, 2026-07-15). `flutter doctor`: Android SDK 36.1.0, Xcode 26.6, sem issues. NDK instalado 28.2.13676358.
FONTE: local: flutter --version / flutter doctor

### [confirmada] Riverpod: runtime na linha 3.x (3.3.2), mas annotation/generator na linha 4.x — nao e erro de digitacao
flutter_riverpod 3.3.2 e riverpod 3.3.2 (2026-06-10). riverpod_annotation 4.0.3 (depende de `riverpod: 3.3.2` EXATO). riverpod_generator 4.0.4 (analyzer ^12.0.0). riverpod_lint 3.1.4 (analyzer ^12.0.0). Resolvem juntos — verificado por pub get real.
FONTE: https://pub.dev/api/packages/riverpod_annotation

### [confirmada] riverpod_lint 3.x NAO usa mais custom_lint — migrou para analysis_server_plugin nativo
riverpod_lint 3.1.4 depende de analysis_server_plugin ^0.3.0 + analyzer_plugin ^0.14.0 e NAO de custom_lint. Resolveu analysis_server_plugin 0.3.14. Incluir custom_lint 0.8.1 (analyzer ^8.0.0) quebra a resolucao. Nao adicione custom_lint ao pubspec.
FONTE: https://pub.dev/api/packages/riverpod_lint

### [confirmada] API gerada pelo riverpod_generator 4.0.4: `Ref` unificado, providers NAO-const, sintaxe Family._()
Compilei `@riverpod Future<int> searchCount(Ref ref, {required String query})` -> gera `final searchCountProvider = SearchCountFamily._();` + `final class SearchCountProvider` com `FutureOr<int> create(Ref ref)`. `@riverpod class CartNotifier extends _$CartNotifier` -> `final cartProvider = CartNotifierProvider._();`. Breaking do 4.0.0: "Generated providers are no-longer constant".
FONTE: https://pub.dev/packages/riverpod_generator/changelog

### [confirmada] Riverpod 3.0 mudou semantica: comparacao por == para filtrar updates, instancias novas a cada rebuild, retry automatico
Retry exponencial automatico comeca em 200ms dobrando ate 6.4s (configuravel via `retry` no ProviderScope/ProviderContainer). autoDispose: AutoDisposeNotifier e FamilyNotifier fundidos em Notifier. Novos: Ref.mounted, ProviderException wrapping, subscription.pause()/resume(), pausa automatica via TickerMode. StateProvider/StateNotifierProvider/ChangeNotifierProvider movidos para package:riverpod/legacy.dart. Testing: ProviderContainer.test(), overrideWithBuild(), WidgetTester.container().
FONTE: https://riverpod.dev/docs/whats_new

### [confirmada] Riverpod 3.0 tem persistencia offline e Mutations, ambos EXPERIMENTAIS
`persist()` com riverpod_sqflite (0.4.3, 2026-06-10) para cache local de providers. `Mutation` para side-effects de UI (submits). Ambos marcados experimentais pela doc oficial. Para melhor_mercado prefira drift explicito no repositorio, nao persist() experimental.
FONTE: https://riverpod.dev/docs/whats_new

### [confirmada] go_router 17.3.0 e go_router_builder 4.4.0 (publicado 2026-07-21, ontem)
go_router 17.3.0 (2026-06-02), env sdk ^3.10.0 / flutter >=3.38.0. Breaking 17.0.0: mudancas em ShellRoute passam a notificar os observers do GoRouter por padrao, novo parametro `notifyRootObserver`. Breaking 16.0.0: GoRouteData ganhou .location/.go(context)/.push(context)/.pushReplacement(context)/.replace(context); exige go_router_builder >=3.0.0. Breaking 15.0.0: URLs case-sensitive por padrao (parametro `caseSensitive`, default true).
FONTE: https://pub.dev/packages/go_router/changelog

### [confirmada] go_router_builder 4.4.0 exige mixin com UM cifrao: `with $HomeRoute`, nao `_$HomeRoute`
Erro real do build: "Missing mixin clause `with $HomeRoute`" em `class HomeRoute extends GoRouteData with _$HomeRoute`. Trocando para `with $HomeRoute` o build passa. Pega diferente de freezed/riverpod que usam `_$`. Rotas tipadas geram tambem `.go(context)` a partir de GoRouteData.
FONTE: local: dart run build_runner build com go_router_builder 4.4.0

### [confirmada] CONFLITO REAL: freezed estavel e incompativel com riverpod codegen E com drift_dev atual
freezed 3.2.5 (ultima ESTAVEL, 2026-02-03) exige analyzer >=9.0.0 <11.0.0. As unicas versoes com analyzer 12 sao pre-release: freezed 3.2.6-dev.1 (analyzer >=12 <13) e 4.0.0-dev.1/2/3 (analyzer ^13). Com `freezed: ^3.2.5` o pub resolveu para 3.2.6-dev.1 (prerelease) — inaceitavel em producao.
FONTE: https://pub.dev/api/packages/freezed

### [confirmada] CONFLITO REAL: drift_dev >=2.34.1 exige analyzer ^13, incompativel com riverpod_generator/riverpod_lint (analyzer ^12)
Mensagem literal do solver: "Because drift_dev >=2.34.1+1 depends on analyzer ^13.0.0 and riverpod_lint >=3.1.4-dev.1 depends on analyzer ^12.0.0, drift_dev >=2.34.1+1 is incompatible with riverpod_lint". Ultima drift_dev com analyzer >=10 <13 e a 2.34.0 (2026-06-10). Solucao: pinar drift_dev em faixa ">=2.30.0 <2.34.1" (resolve 2.34.0); o runtime drift resolve normalmente para 2.34.2.
FONTE: local: flutter pub get output

### [confirmada] CONFLITO REAL: build_runner 2.15.2 exige analyzer >=13.3.0 <15.0.0 — precisa ficar em 2.15.1
Solver: "Because riverpod_generator >=4.0.4-dev.1 depends on analyzer ^12.0.0 and build_runner >=2.15.2 depends on analyzer >=13.3.0 <15.0.0...". build_runner 2.15.2 tambem exige Dart >=3.11.0. Use constraint ">=2.12.0 <2.15.2" -> resolve 2.15.1.
FONTE: https://pub.dev/packages/build_runner/changelog

### [confirmada] Pipeline de codegen SEM freezed funciona 100% — validado com build real e analyze limpo
Resolvido: analyzer 12.1.0, build_runner 2.15.1, source_gen 4.2.3, build 4.0.7, riverpod_generator 4.0.4, riverpod_lint 3.1.4, json_serializable 6.14.0, go_router_builder 4.4.0, drift_dev 2.34.0. `dart run build_runner build` gerou models.g.dart, providers.g.dart, db.g.dart, routes.g.dart em 3s. `flutter analyze` => "No issues found!".
FONTE: local: build_runner + flutter analyze no projeto-sonda

### [confirmada] build_runner 2.15 REMOVEU --delete-conflicting-outputs; AOT e o default desde 2.14
Warning literal: "These options have been removed and were ignored: --delete-conflicting-outputs". `--help` de 2.15.1 mostra apenas: --force-aot, --force-jit, --verbose-durations, -o/--output, --define, --symlink, --build-filter (aceita esquemas package: e asset:), --enable-experiment, --dart-jit-vm-arg, --workspace. 2.15.0 removeu --low-resources-mode, --log-performance, --track-performance. 2.14.0 adicionou o comando `dart run build_runner stop`. Atualize scripts de CI que ainda passam --delete-conflicting-outputs.
FONTE: local: dart run build_runner build --help (2.15.1)

### [confirmada] freezed 3.x ja removeu map/when — sealed classes nativas do Dart sao o caminho oficial
Breaking 3.0.0: "Removed map/when and variants. These have been discouraged since Dart got pattern matching" e "Freezed classes should now either be abstract, sealed, or manually implements _$MyClass". Introduziu 'mixed mode' com classes simples sem factory. Ou seja: abandonar freezed nao perde funcionalidade relevante para modelos de dominio.
FONTE: https://pub.dev/packages/freezed/changelog

### [confirmada] sqlite3_flutter_libs esta DESCONTINUADO (0.6.0+eol) — package:sqlite3 3.x usa build hooks
Aviso no pub.dev: "Not used anymore, update to version 3.x of package:sqlite3 instead" e "Starting from version 0.6.0, this package no longer does anything". Changelog do sqlite3 3.0.0: "Use build hooks to load SQLite instead of DynamicLibrary", "You should drop your dependencies on sqlite3_flutter_libs and sqlcipher_flutter_libs when upgrading", "You can also remove dependencies on sqlite3_native_assets". Deprecou dispose() em favor de close(); parametros de SqliteException agora sao nomeados.
FONTE: https://pub.dev/packages/sqlite3/changelog

### [confirmada] Setup atual de drift em Flutter: drift + drift_flutter + drift_dev + path_provider; abrir com driftDatabase()
Doc oficial: dependencies drift ^2.34.1, drift_flutter ^0.3.1-wip, path_provider ^2.1.6; dev drift_dev ^2.34.2+1, build_runner ^2.15.0. Abrir com `driftDatabase(name: 'x', native: const DriftNativeOptions(databaseDirectory: getApplicationSupportDirectory))`. drift_flutter 0.3.1 ainda lista sqlite3_flutter_libs ^0.6.0+eol e sqlcipher_flutter_libs ^0.7.0+eol como deps, mas sao no-ops. Confirmei libsqlite3.so (1.7 MB, arm64) no APK gerado.
FONTE: https://drift.simonbinder.eu/setup/

### [confirmada] Concorrentes de cache local: isar MORTO, hive MORTO, objectbox e sembast vivos, sqflite vivo
isar 3.1.0+1 parado desde 2023-04-25 com sdk >=2.17.0 <3.0.0 (nao compila em Dart 3); isar_flutter_libs idem. Fork isar_community 3.3.2 (2026-03-23, sdk <4.0.0) e a unica via. hive 2.2.3 parado em 2022; fork hive_ce 2.19.3 + hive_ce_flutter 2.3.4 ativos. objectbox 5.3.2 + objectbox_flutter_libs 5.3.2 (2026-05-20) ativos. sqflite 2.4.3 (2026-06-02, exige Dart ^3.12.0 e Flutter >=3.44.0). sembast 3.8.9+1. realm 20.2.0 (2025-09-24, sem release ha 10 meses).
FONTE: https://pub.dev/api/packages/isar

### [confirmada] mobile_scanner 7.4.0 e a escolha para QR de NFC-e; qr_code_scanner esta morto
mobile_scanner 7.4.0 (2026-07-20), sdk ^3.7.0, flutter >=3.29.0. qr_code_scanner 1.0.1 parado em 2022-08-15 com sdk >=2.17.0 <3.0.0 — nao compila em Dart 3. Breaking 7.0.0: MobileScannerController virou OBRIGATORIO no widget; removidos onDetect/onPermissionSet/onStart; removido autoStart (start() manual obrigatorio); overlay -> overlayBuilder; Android minSdk 21->23; iOS 12.0; iOS/macOS migraram de ML Kit para Vision API. Deteccao via stream `controller.barcodes` de BarcodeCapture.
FONTE: https://pub.dev/packages/mobile_scanner/changelog

### [confirmada] ML Kit bundled do mobile_scanner adiciona ~4.9 MB por ABI; flag de unbundled reduz para ~600 KB
No APK arm64 que construi: libbarhopper_v3.so = 4.946.720 bytes (modelo de barcode do ML Kit). Para usar a variante Google Play Services, adicionar em android/gradle.properties: `dev.steenbakker.mobile_scanner.useUnbundled=true` — reduz para ~600 KB, com download sob demanda via Play Services no primeiro uso.
FONTE: https://pub.dev/packages/mobile_scanner

### [confirmada] Ciclo de vida do mobile_scanner exige WidgetsBindingObserver manual
Padrao recomendado: criar controller com autoStart desabilitado; State com WidgetsBindingObserver; em didChangeAppLifecycleState -> resumed: start() + resubscribe; paused/inactive: stop() + cancel da subscription; dispose: removeObserver + cancel + controller.dispose(). Checar `controller.value.hasCameraPermission` antes das operacoes de ciclo de vida.
FONTE: https://pub.dev/packages/mobile_scanner

### [confirmada] camera 0.12.0+2 sem breaking changes de API vs 0.11.x; camerawesome estagnado
camera 0.12.0+2 (2026-07-13), sdk ^3.10.0, flutter >=3.38.0. 0.12.0 adicionou video stabilization; changelog nao lista breaking de API. Android API 24+. camerawesome 2.5.0 sem release desde 2025-06-13 (13 meses).
FONTE: https://pub.dev/packages/camera/changelog

### [confirmada] Scanner de documento: cunning_document_scanner 2.7.0 e a unica opcao viva e mantida
cunning_document_scanner 2.7.0 publicado 2026-07-21 (ontem), publisher verificado cunning.biz, sdk >=3.5.0 <4.0.0, flutter >=3.24.0, Android API 21+, iOS 13.0+. API: CunningDocumentScanner.getPictures(noOfPages:, asPdf:, scannerSource: camera|gallery|both, androidScannerMode:, IosScannerOptions(formato PNG/JPEG, compressao)). Usa ML Kit Document Scanner no Android e VisionKit no iOS — crop/perspectiva feitos NATIVAMENTE, sem custo Dart. Exige NSCameraUsageDescription no Info.plist. Alternativas mortas ou fracas: edge_detection 1.1.3 parado em 2023-10-17; flutter_doc_scanner 0.0.21 (versao 0.0.x, sem estabilidade).
FONTE: https://pub.dev/packages/cunning_document_scanner

### [provavel] opencv_dart 2.2.1+4 existe e e recente, mas e overkill e pesa muito
opencv_dart 2.2.1+4 (2026-02-26), sdk >=3.10.0, flutter >=3.38.1. opencv_core 1.4.5 (2025-11-18). Traz binarios OpenCV completos (dezenas de MB por ABI). Nao confirmei o tamanho exato no APK — nao testei. Para correcao de perspectiva de cupom, o ML Kit Document Scanner (via cunning_document_scanner) resolve sem esse custo.
FONTE: https://pub.dev/api/packages/opencv_dart

### [confirmada] flutter_image_compress 2.5.0 (nativo) supera o package image (Dart puro) para compressao
flutter_image_compress 2.5.0 (2026-07-17) usa Kotlin no Android e ObjC/Swift no Apple. package:image 4.9.1 (2026-05-30) e Dart puro — lento mesmo em release e mesmo dentro de isolate. Use flutter_image_compress para o pipeline de upload (resize + JPEG quality) e reserve package:image apenas para manipulacoes que o nativo nao cobre, sempre em isolate. ATENCAO: o build acusou que flutter_image_compress_common 1.1.0 ainda compila com source/target Java 8 ("source value 8 is obsolete").
FONTE: https://github.com/fluttercandies/flutter_image_compress

### [confirmada] background_downloader 9.5.6 faz UPLOAD em background que sobrevive ao app fechado — flutter_uploader esta morto
background_downloader 9.5.6 (2026-07-12), sdk ^3.7.0, flutter >=3.29.0. Suporta UploadTask (binario e multipart), FileDownloader().upload()/enqueue(), banco de persistencia via FileDownloader().start(), TaskQueue, retries por task, pause/resume/cancel, requiresWiFi, notificacoes. Android usa WorkManager/DownloadWorker; iOS usa URLSession background. LIMITES: Android timeout default de 9 minutos por task (use allowPause: true para tasks longas); iOS janela de 4 horas para completar tasks enfileiradas. Requer Kotlin 2.1.0+ no Android, iOS 14.0+, Android API 21+. flutter_uploader 1.2.1 parado em 2020-12-26 com sdk <3.0.0 — NAO USAR.
FONTE: https://pub.dev/packages/background_downloader

### [confirmada] workmanager 0.9.0+3 esta estagnado ha ~11 meses
workmanager 0.9.0+3 publicado 2025-08-31, sdk >=3.5.0 <4.0.0, flutter >=3.32.0. Resolve, mas nao teve release em 2026. Para fila de upload use background_downloader (mais ativo, dominio-especifico); reserve workmanager apenas para jobs periodicos genericos que nao sejam transferencia de arquivo.
FONTE: https://pub.dev/api/packages/workmanager

### [confirmada] Localizacao: geolocator 14.0.3, permission_handler 12.0.3, geocoding 5.0.0
geolocator 14.0.3 (2026-06-12, sdk ^3.5.0). permission_handler 12.0.3 (2026-06-01, sdk ^3.5.0, flutter >=3.24.0); breaking 12.0.0 = permission_handler_android 13.0.0 + compileSdk 35; iOS deployment target 12.0. geocoding 5.0.0 (2026-07-03, sdk >=3.3.0 <4.0.0). Permissoes Android: ACCESS_COARSE_LOCATION ou ACCESS_FINE_LOCATION; ACCESS_BACKGROUND_LOCATION so a partir do Android 10 e apenas se precisar de updates em background; FOREGROUND_SERVICE_LOCATION obrigatoria a partir do Android 14 (API 34) para servicos em foreground de localizacao.
FONTE: https://pub.dev/packages/permission_handler/changelog

### [baixa] NAO confirmei mudancas de permissao de localizacao especificas de Android 15/16
O changelog do permission_handler ate 12.0.3 nao menciona nada especifico de Android 14/15/16 alem do que ja existia (READ_MEDIA_* do Android 13). Nao encontrei fonte primaria descrevendo requisito NOVO de localizacao em Android 15 ou 16. Para melhor_mercado o caso de uso e foreground apenas ('onde minha compra sai mais barata perto de mim'), entao ACCESS_COARSE/FINE em foreground basta e evita a revisao de background location do Play.
FONTE: https://developer.android.com/develop/sensors-and-location/location/permissions

### [confirmada] flutter_secure_storage 10.3.1 abandonou EncryptedSharedPreferences (Jetpack Security depreciado)
v10 exige Android minSdk 23; substitui o EncryptedSharedPreferences depreciado por cifra propria RSA OAEP + AES-GCM. Construtores: AndroidOptions() (default, sem biometria), AndroidOptions.biometric(enforceBiometrics: false) e (true) — este ultimo exige API 28+. Migracao automatica via migrateOnAlgorithmChange (default true) e AndroidOptions(migrateWithBackup: true) para dados criticos. CUIDADO CLASSICO: backup do Google Drive causa InvalidKeyException — defina android:allowBackup="false" ou exclua as shared prefs do plugin do backup. iOS: IOSOptions(accessibility: KeychainAccessibility.first_unlock) recomendado para tokens usados por tasks em background.
FONTE: https://pub.dev/packages/flutter_secure_storage

### [confirmada] Flutter 3.44 CONGELOU material/cupertino no SDK e criou material_ui / cupertino_ui — ainda 0.0.2
material_ui 0.0.2 publicado HOJE (2026-07-22) e cupertino_ui 0.0.2 em 2026-07-21; ambos sdk ^3.12.0, flutter >=3.44.0, apenas 2 versoes cada. README do material_ui: "This package will contain the material library previously part of the Flutter framework itself (package:flutter/material.dart). It is being decoupled to allow for faster iteration", com status "Coming soon" e SEM cronograma, SEM guia de migracao e SEM deprecacao formal do in-SDK.
FONTE: https://pub.dev/packages/material_ui

### [confirmada] Material 3 Expressive NAO esta disponivel no Flutter 3.44 e nao esta em desenvolvimento no core
O time do Flutter declarou que nao esta desenvolvendo M3 Expressive no momento e nao aceita contribuicoes dessas features no core; todo o trabalho de M3 Expressive acontecera nos novos pacotes material_ui/cupertino_ui depois de estabelecidos. Disponivel HOJE no SDK: Material 3 padrao, ColorScheme.fromSeed, e o dynamic color via dynamic_color 1.8.1 (parado desde 2025-08-01, mas funcional).
FONTE: https://github.com/flutter/flutter/issues/168813

### [confirmada] Novidades reais de UI no Flutter 3.44 uteis para o app
RoundedSuperellipseInputBorder (novo border); DropdownMenu ganhou scrollPadding e integracao com form field; SearchAnchor com docs melhores de suggestionsBuilder; TabBar aceita TabBarScrollController; NavigationRail ganhou mainAxisAlignment; Carousel migrou para CustomScrollView com carrossel infinito via leadingIndex; MenuAnchor com animacoes; ScrollCacheExtent introduzido para performance de scroll; Impeller com filtragem bilinear para texto com escala nao-uniforme e SDF rendering; avaliacao de contraste de cor nao-textual para a11y.
FONTE: https://docs.flutter.dev/release/release-notes/release-notes-3.44.0

### [confirmada] Android 2026: Flutter 3.44.7 ja entrega os defaults exigidos — compileSdk 36, targetSdk 36, minSdk 24
Lido direto do SDK em disco, packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt: compileSdkVersion=36, minSdkVersion=24, targetSdkVersion=36, ndkVersion="28.2.13676358". Confirmado no manifest merged do APK real: android:minSdkVersion="24" android:targetSdkVersion="36".
FONTE: local: $FLUTTER/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt

### [confirmada] Google Play: targetSdk 36 obrigatorio para apps novos e updates a partir de 31/08/2026
Fonte oficial: "Starting August 31, 2026: New apps and app updates must target Android 16 (API level 36) or higher to be submitted to Google Play." Apps existentes precisam targetar no minimo API 35 para continuar visiveis a novos usuarios em devices com Android mais novo. Extensao possivel ate 01/11/2026. Wear OS/Automotive: API 35. Android TV/XR: API 34.
FONTE: https://support.google.com/googleplay/android-developer/answer/11926878

### [confirmada] Toolchain Android do Flutter 3.44.7: AGP 9.0.1, Gradle 9.1.0, Kotlin 2.3.20, JDK 17
Templates gerados por `flutter create`: settings.gradle.kts com com.android.application 9.0.1 e org.jetbrains.kotlin.android 2.3.20; gradle-wrapper distributionUrl gradle-9.1.0-all.zip; app/build.gradle.kts com sourceCompatibility/targetCompatibility VERSION_17 e jvmTarget JVM_17. Minimos do DependencyVersionChecker.kt: Gradle erro <8.7.0 / warn <8.14.0; Java erro e warn <17; AGP erro <8.6.0 / warn <8.11.1; KGP erro <2.0.0 / warn <2.2.20; warnMinSdkVersion=24.
FONTE: local: $FLUTTER/packages/flutter_tools/gradle/src/main/kotlin/DependencyVersionChecker.kt

### [confirmada] Requisito de 16 KB page size: ATENDIDO — verifiquei alinhamento real dos .so no APK construido
Requisito Play: desde 01/11/2025, apps novos e updates que targetam API 35+ devem suportar 16 KB page size em devices 64-bit. NDK r28+ compila 16KB-alinhado por default (Flutter 3.44.7 usa NDK 28.2.13676358). Rodei llvm-objdump -p em todos os .so de lib/arm64-v8a do APK: libbarhopper_v3, libdartjni, libdatastore_shared_counter, libimage_processing_util_jni, libsentry-android, libsentry, libsqlite3, libsurface_util_jni = align 2**14 (16 KB); libflutter e libVkLayer_khronos_validation = align 2**16. Todos conformes. Verificacao de zip: `zipalign -v -c -P 16 4 app.apk`.
FONTE: https://developer.android.com/guide/practices/page-sizes

### [confirmada] RISCO DE BUILD FUTURO: 5 plugins do stack ainda aplicam Kotlin Gradle Plugin e vao quebrar
Warning literal do `flutter build apk`: "Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): dynamic_color, flutter_image_compress_common, mobile_scanner, patrol, sentry_flutter. Future versions of Flutter will fail to build if your app uses plugins that apply KGP." AGP 9 tem Kotlin embutido e nao precisa mais do org.jetbrains.kotlin.android. Guia: docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin.
FONTE: local: flutter build apk --debug (saida do Gradle)

### [confirmada] iOS: deployment target 13.0, Xcode minimo 15 e recomendado 16
Projeto gerado por flutter create 3.44.7: IPHONEOS_DEPLOYMENT_TARGET = 13.0. Do SDK, macos/xcode.dart: xcodeRequiredVersion = Version(15), xcodeRecommendedVersion = Version(16). Ambiente local tem Xcode 26.6. Existe issue aberta no flutter/flutter (#187741) propondo subir o minimo de iOS 13 para 15 por causa do Xcode 27 — nao concluida.
FONTE: local: $FLUTTER/packages/flutter_tools/lib/src/macos/xcode.dart

### [confirmada] HTTP: dio 5.10.0 e a escolha; ecossistema de interceptors maduro mas dio_smart_retry esta velho
dio 5.10.0 (2026-06-29, sdk >=2.18.0 <4.0.0). http 1.6.0 (2025-11-10) — minimalista, sem interceptors nem CancelToken nativo. dio_cache_interceptor 4.0.7 (2026-06-26, ativo). native_dio_adapter 1.6.0 (2026-06-10) para usar Cronet (Android) e URLSession (iOS) via cronet_http 1.9.0 / cupertino_http 3.0.2. ATENCAO: dio_smart_retry 7.0.1 nao tem release desde 2024-10-22 — resolve, mas considere implementar o retry como Interceptor proprio para nao depender de pacote parado.
FONTE: https://pub.dev/api/packages/dio

### [confirmada] Testes: mocktail 1.0.5 preferivel a mockito 5.7.0 (evita mais codegen no analyzer travado)
mocktail 1.0.5 (2026-04-10) — sem codegen, sem dependencia de analyzer. mockito 5.7.0 (2026-05-19) exige build_runner e entra no mesmo inferno de analyzer. Golden: alchemist 0.14.0 (2026-03-13, ativo, sdk >=3.8.0) — golden_toolkit 0.15.0 esta MORTO (2023-02-21, sdk <3.0.0, nao compila em Dart 3). E2E: patrol 4.7.1 + patrol_finders 3.6.0 (2026-07-14/09, ativos) sobre integration_test do SDK.
FONTE: https://pub.dev/api/packages/alchemist

### [provavel] Play Integrity API para anti-abuso: 10.000 requisicoes/dia gratis, Standard requests e o recomendado
Standard requests sao o fluxo recomendado para novas integracoes e servem para validar qualquer acao ou chamada de servidor; Classic requests sao mais caros, devem ser esporadicos e exigem que voce mesmo proteja contra exfiltracao. Default de 10.000 requests/dia no total de todas as instalacoes, com aumento sob solicitacao. Existe plugin Flutter (app_attest) cobrindo Apple App Attest no iOS e Play Integrity no Android — NAO verifiquei versao nem manutencao desse plugin.
FONTE: https://developer.android.com/google/play/integrity/overview

### [provavel] Dart 3.12 (com Flutter 3.44): primary constructors experimental, private named parameters, dot shorthands maduros
Dot shorthands chegaram no Dart 3.10 e amadureceram no 3.12: permite `.foo` quando o tipo e inferivel do contexto (enums, static members, construtores). Null-aware elements em literais de List/Set/Map inserem o valor apenas se nao-nulo. Primary constructors sao PREVIEW EXPERIMENTAL no 3.12 — nao usar em producao. O style guide do Flutter foi atualizado para dot shorthands e extension methods.
FONTE: https://dart.dev/changelog

## ESPECIFICACOES CONCRETAS
- === BLOCO pubspec.yaml VALIDADO (resolveu, gerou codigo, analisou limpo e buildou APK real em 2026-07-22) ===

environment:
  sdk: ^3.12.0
  flutter: ">=3.44.0"

dependencies:
  flutter:
    sdk: flutter

  # Estado (resolve: flutter_riverpod 3.3.2 / riverpod 3.3.2 / riverpod_annotation 4.0.3)
  flutter_riverpod: ^3.3.2
  riverpod_annotation: ^4.0.3

  # Navegacao
  go_router: ^17.3.0

  # HTTP
  dio: ^5.10.0
  dio_cache_interceptor: ^4.0.7

  # Serializacao (SEM freezed - use sealed/final classes do Dart 3.12)
  json_annotation: ^4.12.0

  # Cache local / offline (sqlite3 3.5.0 traz o nativo via build hooks)
  drift: ^2.34.0
  drift_flutter: ^0.3.1
  sqlite3: ^3.5.0

  # Camera / QR / documento
  mobile_scanner: ^7.4.0
  camera: ^0.12.0+2
  cunning_document_scanner: ^2.7.0
  flutter_image_compress: ^2.5.0
  image: ^4.9.1

  # Localizacao
  geolocator: ^14.0.3
  geocoding: ^5.0.0
  permission_handler: ^12.0.3

  # Upload resiliente em background
  background_downloader: ^9.5.6

  # Seguranca / plataforma
  flutter_secure_storage: ^10.3.1
  dynamic_color: ^1.8.1
  path_provider: ^2.1.6
  shared_preferences: ^2.5.5
  connectivity_plus: ^7.3.0
  package_info_plus: ^10.2.1
  device_info_plus: ^13.2.0
  cached_network_image: ^3.4.1
  sentry_flutter: ^9.25.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter

  # PIN OBRIGATORIO: 2.15.2+ exige analyzer >=13.3 e quebra riverpod_generator (analyzer ^12)
  build_runner: ">=2.12.0 <2.15.2"

  json_serializable: ^6.14.0
  riverpod_generator: ^4.0.4
  riverpod_lint: ^3.1.4          # NAO adicionar custom_lint
  go_router_builder: ^4.4.0

  # PIN OBRIGATORIO: 2.34.1+ exige analyzer ^13 e quebra riverpod_generator/_lint
  drift_dev: ">=2.30.0 <2.34.1"

  mocktail: ^1.0.5
  alchemist: ^0.14.0
  patrol: ^4.7.1
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
- === VERSOES EXATAS RESOLVIDAS (pubspec.lock verificado) ===
Diretas: flutter_riverpod 3.3.2 | riverpod 3.3.2 | riverpod_annotation 4.0.3 | go_router 17.3.0 | dio 5.10.0 | dio_cache_interceptor 4.0.7 | json_annotation 4.12.0 | drift 2.34.2 | drift_flutter 0.3.1 | sqlite3 3.5.0 | mobile_scanner 7.4.0 | camera 0.12.0+2 | cunning_document_scanner 2.7.0 | flutter_image_compress 2.5.0 | image 4.9.1 | geolocator 14.0.3 | geocoding 5.0.0 | permission_handler 12.0.3 | background_downloader 9.5.6 | flutter_secure_storage 10.3.1 | dynamic_color 1.8.1 | path_provider 2.1.6 | shared_preferences 2.5.5 | connectivity_plus 7.3.0 | package_info_plus 10.2.1 | device_info_plus 13.2.0 | cached_network_image 3.4.1 | sentry_flutter 9.25.0
Dev: build_runner 2.15.1 | json_serializable 6.14.0 | riverpod_generator 4.0.4 | riverpod_lint 3.1.4 | go_router_builder 4.4.0 | drift_dev 2.34.0 | mocktail 1.0.5 | alchemist 0.14.0 | patrol 4.7.1 | flutter_lints 6.0.0
Transitivas-chave: analyzer 12.1.0 | source_gen 4.2.3 | build 4.0.7 | analysis_server_plugin 0.3.14 | sqlparser 0.44.5
sdks no lock: dart ">=3.12.0 <4.0.0", flutter ">=3.44.0"
- === ANDROID (defaults do Flutter 3.44.7, lidos de FlutterExtension.kt e confirmados no manifest merged) ===
compileSdk = 36 | targetSdk = 36 | minSdk = 24 | ndkVersion = "28.2.13676358"
AGP (settings.gradle.kts template) = com.android.application 9.0.1
Kotlin (template) = org.jetbrains.kotlin.android 2.3.20
Gradle wrapper = gradle-9.1.0-all.zip
Java = sourceCompatibility/targetCompatibility JavaVersion.VERSION_17, kotlin jvmTarget JVM_17
Minimos duros do DependencyVersionChecker.kt: Gradle erro <8.7.0 warn <8.14.0 | Java erro/warn <17 | AGP erro <8.6.0 warn <8.11.1 | KGP erro <2.0.0 warn <2.2.20 | warnMinSdkVersion 24
NOTA: app/build.gradle.kts do template NAO aplica mais org.jetbrains.kotlin.android (Built-in Kotlin do AGP 9); usa bloco `kotlin { compilerOptions { jvmTarget = JVM_17 } }`.
- === iOS (Flutter 3.44.7) ===
IPHONEOS_DEPLOYMENT_TARGET = 13.0 (projeto gerado por flutter create)
xcodeRequiredVersion = 15 | xcodeRecommendedVersion = 16 (xcode.dart)
Minimos dos plugins: mobile_scanner 7.x iOS 12.0 | cunning_document_scanner iOS 13.0 | background_downloader iOS 14.0 | permission_handler iOS 12.0
=> deployment target efetivo do app: 14.0 (limitado por background_downloader)
- === VERIFICACAO 16 KB PAGE SIZE (APK arm64 real, llvm-objdump do NDK 28.2.13676358) ===
libbarhopper_v3.so            align 2**14  (4.946.720 bytes - ML Kit barcode bundled)
libdartjni.so                 align 2**14
libdatastore_shared_counter.so align 2**14
libimage_processing_util_jni.so align 2**14
libsentry-android.so          align 2**14
libsentry.so                  align 2**14  (780.328 bytes)
libsqlite3.so                 align 2**14  (1.731.848 bytes)
libsurface_util_jni.so        align 2**14
libflutter.so                 align 2**16
libVkLayer_khronos_validation.so align 2**16
TODOS >= 2**14 (16384) => CONFORME.
Comandos de auditoria para o CI:
  unzip -q app.apk -d out && $NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-objdump -p out/lib/arm64-v8a/X.so | grep -m1 LOAD
  zipalign -v -c -P 16 4 app.apk
  adb shell getconf PAGE_SIZE   # deve retornar 16384 no device de teste
- === PRAZOS GOOGLE PLAY ===
2025-11-01: 16 KB page size obrigatorio para apps novos e updates que targetam API 35+ em devices 64-bit (JA EM VIGOR)
2026-08-31: targetSdk 36 obrigatorio para apps novos e updates (Wear OS/Automotive: 35; Android TV/XR: 34)
2026-11-01: prazo maximo de extensao mediante solicitacao
Apps existentes: precisam de targetSdk >= 35 para continuar visiveis a novos usuarios em Android mais novo que o target
- === SINTAXE OBRIGATORIA DOS GERADORES (validada em build real) ===
// go_router_builder 4.4.0 - UM cifrao
class HomeRoute extends GoRouteData with $HomeRoute { ... }
@TypedGoRoute<HomeRoute>(path: '/', routes: [TypedGoRoute<ProductRoute>(path: 'produto/:gtin')])

// riverpod_generator 4.0.4 - Ref unificado, providers NAO-const
@riverpod
Future<int> searchCount(Ref ref, {required String query}) async { ... }
// gera: final searchCountProvider = SearchCountFamily._();
@riverpod
class CartNotifier extends _$CartNotifier { @override List<String> build() => const []; }
// gera: final cartProvider = CartNotifierProvider._();

// Substituto de freezed - Dart 3.12 nativo
sealed class ImportResult { const ImportResult(); }
final class ImportOk extends ImportResult { const ImportOk(this.items); final List<PriceObservation> items; }
final class ImportFailed extends ImportResult { const ImportFailed(this.reason); final String reason; }
String describe(ImportResult r) => switch (r) {
  ImportOk(items: final i) => 'ok ${i.length}',
  ImportFailed(reason: final m) => 'fail $m',
};

// drift 2.34 + drift_flutter
@DriftDatabase(tables: [CachedSearches])
class AppDb extends _$AppDb { AppDb() : super(driftDatabase(name: 'melhor_mercado')); @override int get schemaVersion => 1; }
- === COMANDOS build_runner 2.15.1 (flags REAIS do --help) ===
dart run build_runner build            # AOT por default desde 2.14
dart run build_runner watch
dart run build_runner stop             # novo em 2.14
Flags validas: -c/--config, --force-aot, --force-jit, --verbose-durations, -o/--output, -v/--verbose, -r/--release, --define, --symlink, --build-filter (aceita package: e asset:), --enable-experiment, --dart-jit-vm-arg, --workspace
REMOVIDAS: --delete-conflicting-outputs (2.15), --low-resources-mode (2.15), --log-performance (2.15), --track-performance (2.15)
- === CONFIGS DE PLATAFORMA OBRIGATORIAS ===
android/gradle.properties:
  dev.steenbakker.mobile_scanner.useUnbundled=true   # 4,9 MB -> ~600 KB
AndroidManifest.xml (application):
  android:allowBackup="false"                        # evita InvalidKeyException do flutter_secure_storage
AndroidManifest.xml (permissoes):
  <uses-permission android:name="android.permission.CAMERA"/>
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  <uses-permission android:name="android.permission.INTERNET"/>
  <!-- NAO declarar ACCESS_BACKGROUND_LOCATION -->
ios/Runner/Info.plist:
  NSCameraUsageDescription (obrigatorio: mobile_scanner, camera, cunning_document_scanner)
  NSLocationWhenInUseUsageDescription
  NSPhotoLibraryUsageDescription (se permitir escolher foto de nota da galeria)
Dart:
  IOSOptions(accessibility: KeychainAccessibility.first_unlock)  # token legivel por upload em background
  driftDatabase(name: 'melhor_mercado', native: DriftNativeOptions(databaseDirectory: getApplicationSupportDirectory))
- === LIMITES NUMERICOS A RESPEITAR ===
background_downloader: 9 min por task no Android (allowPause:true para exceder) | 4 h de janela no iOS | requiresWiFi opcional
Riverpod 3.0 retry automatico: inicia em 200 ms, dobra ate 6.4 s
Play Integrity: 10.000 requests/dia gratis no total das instalacoes (aumentavel sob solicitacao); Standard requests recomendado, Classic requests esporadico
Upload de imagem sugerido (decisao de projeto, nao medida): lado maior 2000 px, JPEG quality 80, alvo <= 800 KB/pagina
Alinhamento ELF exigido: 2**14 = 16384 bytes
NDK: r28+ alinha 16 KB por default; r27- exige -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384
- === COMBO ALTERNATIVO B (validado, caso freezed seja inegociavel) ===
Sem riverpod_generator e sem riverpod_lint (Riverpod escrito a mao, sem @riverpod):
  freezed: ">=3.2.5 <3.2.6"   -> resolve 3.2.5 ESTAVEL
  freezed_annotation: ^3.1.0
  json_serializable: ^6.14.0  -> 6.14.0
  drift_dev: ">=2.28.0 <2.35.0" -> 2.34.0
  build_runner: ">=2.10.0 <3.0.0" -> 2.15.1
  go_router_builder: ^4.4.0   -> 4.4.0
analyzer resolvido: 10.2.0. Verificado por flutter pub get real.
CUSTO: perde @riverpod, perde os lints do Riverpod, e escreve todo provider manualmente. NAO recomendado.

## RECOMENDACOES
- ADOTE O BLOCO DE PUBSPEC VALIDADO (secao concrete_specs). Ele nao e teorico: foi resolvido por `flutter pub get`, gerou codigo com `dart run build_runner build`, passou `flutter analyze` com zero issues e produziu um APK arm64 real.
- ABANDONE FREEZED NESTE PROJETO. Nao ha versao estavel compativel com o resto do stack hoje. Use `sealed class` + `final class` nativas do Dart 3.12 com pattern matching (`switch (r) { ImportOk(items: final i) => ..., ImportFailed(reason: final m) => ... }`) para modelar ImportResult/ScanResult/PriceMatch, e json_serializable 6.14.0 (analyzer >=10 <14, o mais tolerante do ecossistema) para (de)serializacao. Isso e exatamente o que o freezed 3.x ja empurra como caminho.
- PINE AS TRES VERSOES QUE SUSTENTAM O EQUILIBRIO EM analyzer 12.1.0: build_runner ">=2.12.0 <2.15.2" (fica em 2.15.1) e drift_dev ">=2.30.0 <2.34.1" (fica em 2.34.0). Comente no pubspec.yaml POR QUE estao pinados, com link para este achado, senao alguem roda `flutter pub upgrade --major-versions` e quebra tudo.
- NAO ADICIONE custom_lint. riverpod_lint 3.1.4 migrou para analysis_server_plugin e custom_lint 0.8.1 (analyzer ^8) quebra a resolucao. Habilite os lints do Riverpod via analysis_options.yaml com o plugin nativo do analysis server.
- QR DE NFC-e: mobile_scanner 7.4.0 com controller explicito e `autoStart: false`. Implemente WidgetsBindingObserver com stop()+cancel em paused/inactive e start()+resubscribe em resumed; dispose completo (removeObserver + cancel + controller.dispose()). Ative `dev.steenbakker.mobile_scanner.useUnbundled=true` em android/gradle.properties para trocar 4,9 MB de libbarhopper_v3.so por ~600 KB — mas trate o caso de Play Services ausente/desatualizado com fallback de erro claro ao usuario.
- FOTO DE NOTA FISCAL: use cunning_document_scanner 2.7.0 (ML Kit Document Scanner no Android, VisionKit no iOS). Deteccao de borda e correcao de perspectiva saem de graca e NATIVAS. Nao reimplemente isso em Dart. Depois passe o resultado por flutter_image_compress 2.5.0 (nativo) para resize + JPEG antes do upload.
- PIPELINE DE IMAGEM: defina um teto duro no cliente, ex. lado maior 2000 px e JPEG quality 80, alvo <= 800 KB por pagina. Cupom fiscal e texto de alto contraste — resolucao acima disso so aumenta banda e latencia do OCR sem ganho de acuracia. Faca a compressao ANTES de enfileirar no background_downloader, nunca depois.
- FILA DE UPLOAD RESILIENTE: background_downloader 9.5.6 com FileDownloader().start() (habilita o banco de persistencia), enqueue() de UploadTask e TaskQueue. A fila sobrevive ao app fechado. RESPEITE OS LIMITES: 9 minutos por task no Android (use allowPause: true se um upload puder passar disso) e janela de 4 horas no iOS. Ofereca `requiresWiFi` como preferencia do usuario — publico brasileiro com franquia de dados vai agradecer.
- CACHE LOCAL: drift 2.34.2 + drift_flutter 0.3.1 + drift_dev 2.34.0. Cobre os tres casos do produto com uma unica tecnologia: cache de buscas (tabela com query como PK + payload + fetchedAt + TTL), listas de compras (relacional, precisa de JOIN e ordenacao) e fila de upload (estado + retry count + idempotency key). NAO misture Hive/Isar/ObjectBox no mesmo app — voce ja tem sqlite3 nativo embarcado (libsqlite3.so, 1,7 MB) via drift.
- ABRA O BANCO COM driftDatabase(name: 'melhor_mercado', native: DriftNativeOptions(databaseDirectory: getApplicationSupportDirectory)). getApplicationSupportDirectory (nao Documents) evita que o DB apareca em backups/iCloud e em file pickers do usuario.
- LOCALIZACAO: fique em FOREGROUND-ONLY. geolocator 14.0.3 + permission_handler 12.0.3 com ACCESS_COARSE_LOCATION e ACCESS_FINE_LOCATION apenas. NAO declare ACCESS_BACKGROUND_LOCATION — dispara revisao manual do Google Play com justificativa por escrito e nao e necessario para 'onde comprar mais barato perto de mim'. Se um dia precisar de servico em foreground, ai sim FOREGROUND_SERVICE_LOCATION (Android 14+).
- HTTP: dio 5.10.0. Interceptors para auth (Bearer + refresh), correlation-id, logging e retry. IMPLEMENTE O RETRY VOCE MESMO como Interceptor (backoff exponencial com jitter, apenas em 408/429/5xx e erros de rede, NUNCA em POST nao-idempotente sem chave de idempotencia) em vez de depender de dio_smart_retry, que esta sem release ha 21 meses. Use CancelToken atrelado ao ciclo de vida do provider Riverpod (ref.onDispose(() => token.cancel())).
- ROTEAMENTO: go_router 17.3.0 com StatefulShellRoute para a bottom nav (Buscar / Escanear / Listas / Perfil) e typed routes via go_router_builder 4.4.0. LEMBRE: mixin com UM cifrao (`with $MinhaRota`). Atencao ao breaking do 15.x: URLs sao case-sensitive por padrao — normalize slugs de produto/mercado para lowercase antes de gerar rotas, ou o deep link do usuario quebra.
- ESTADO: flutter_riverpod 3.3.2 com code generation (@riverpod). Use AsyncNotifier para busca de precos e Notifier para lista de compras. Aproveite o retry automatico do 3.0 (200ms dobrando ate 6.4s) para chamadas de busca, mas DESLIGUE-O explicitamente em mutacoes de envio de cupom — reenvio automatico gera duplicata de nota fiscal no backend.
- SEMPRE checar `ref.mounted` depois de gap assincrono antes de mexer em state — API nova do Riverpod 3.0, equivalente a BuildContext.mounted. Sem isso voce vai ter crashes intermitentes no fluxo de scan -> upload -> refresh.
- SEGURANCA: flutter_secure_storage 10.3.1 para refresh token. Obrigatoriamente `android:allowBackup="false"` no AndroidManifest (ou exclusao explicita das shared prefs do plugin) — senao restore de backup do Drive gera InvalidKeyException e o usuario e deslogado com erro incompreensivel. No iOS use KeychainAccessibility.first_unlock para que a fila de upload em background consiga ler o token com o device bloqueado.
- ANDROID BUILD: mantenha os defaults do Flutter 3.44.7 (compileSdk 36, targetSdk 36, minSdk 24, NDK 28.2.13676358, AGP 9.0.1, Gradle 9.1.0, Kotlin 2.3.20, JDK 17). Isso ja te poe em conformidade com o prazo de 31/08/2026 e com o requisito de 16 KB page size sem trabalho extra.
- ADICIONE AO CI um gate de conformidade 16 KB: extraia o AAB/APK e rode llvm-objdump -p em cada .so verificando `align 2**14` ou maior, e `zipalign -v -c -P 16 4`. Isso te protege quando alguem adicionar um plugin nativo novo (opencv_dart, um SDK de pagamento, etc) que ainda compile com NDK antigo.
- TESTES: mocktail 1.0.5 (zero codegen — nao adiciona pressao no analyzer travado), alchemist 0.14.0 para golden, patrol 4.7.1 + patrol_finders 3.6.0 para E2E dos fluxos criticos (escanear QR, fotografar cupom, comparar cesta). NAO use golden_toolkit nem mockito.
- MATERIAL: use `package:flutter/material.dart` do SDK com ColorScheme.fromSeed e dynamic_color 1.8.1. NAO adote material_ui/cupertino_ui agora (0.0.2, publicados ontem/hoje, sem guia de migracao). Mas ISOLE: crie src/theme/ e src/ui/ com seus proprios wrappers de Button/Card/Sheet, para que a migracao futura para material_ui seja localizada em vez de tocar 200 arquivos.
- ANTI-ABUSO (critico para app colaborativo de precos): Play Integrity API Standard requests no Android + App Attest no iOS, para garantir que envios de cupom vem do app genuino. Comece pelo tier gratuito de 10.000 req/dia; nao attestar TODA requisicao, apenas o submit de cupom/encarte. Combine com rate limit e deduplicacao por chave de acesso da NFC-e no backend — attestacao sozinha nao impede um usuario legitimo de enviar preco falso.
- MONITORAMENTO: sentry_flutter 9.25.0 (release 2026-07-21, muito ativo). Configure sampling de traces baixo (0.1-0.2) e scrub agressivo de PII — imagens de cupom fiscal contem CPF quando o consumidor pede nota; NUNCA anexe a imagem original a um evento de erro.

## NAO FAZER
- NAO use freezed neste projeto agora. `freezed: ^3.2.5` faz o pub resolver silenciosamente para o PRERELEASE 3.2.6-dev.1 (porque 3.2.5 exige analyzer <11 e o resto do stack pede 12). Voce vai ter um prerelease em producao sem perceber. Se insistir em freezed, e obrigatorio abrir mao de riverpod_generator e riverpod_lint (combo B validado: freezed 3.2.5 + drift_dev 2.34.0 + json_serializable 6.14.0 em analyzer 10.2.0, SEM codegen de Riverpod).
- NAO rode `flutter pub upgrade --major-versions` neste pubspec. Vai puxar drift_dev 2.34.4 (analyzer ^13) e build_runner 2.15.2 (analyzer >=13.3) e quebrar a resolucao com riverpod_generator/riverpod_lint. Os pins sao intencionais.
- NAO passe `--delete-conflicting-outputs` para o build_runner. A flag foi REMOVIDA no 2.15 e agora so gera warning ignorado. Scripts de CI copiados de tutoriais de 2024 vao poluir o log.
- NAO use isar nem hive. isar 3.1.0+1 e isar_flutter_libs 3.1.0+1 estao parados desde abril/2023 com `sdk: >=2.17.0 <3.0.0` — nao compilam em Dart 3, muito menos 3.12. hive 2.2.3 parou em 2022. Se alguem trouxer um tutorial recomendando qualquer um dos dois, o tutorial esta desatualizado. Forks (isar_community 3.3.2, hive_ce 2.19.3) existem, mas nao ha razao para preferi-los a drift/sqlite neste produto.
- NAO use qr_code_scanner (1.0.1, agosto/2022, sdk <3.0.0) nem flutter_uploader (1.2.1, dezembro/2020, sdk <3.0.0) nem golden_toolkit (0.15.0, fevereiro/2023, sdk <3.0.0). Os tres sao incompativeis com Dart 3 e nem resolvem.
- NAO adicione sqlite3_flutter_libs nem sqlcipher_flutter_libs ao seu pubspec. Estao EOL e sao no-ops; o nativo vem via build hooks do package:sqlite3 3.x. Aparecem transitivamente por drift_flutter 0.3.1 e isso e inofensivo.
- NAO adicione custom_lint. riverpod_lint 3.x nao precisa e a versao atual (0.8.1, analyzer ^8) torna o projeto irresolvivel.
- NAO declare ACCESS_BACKGROUND_LOCATION. O produto nao precisa e voce compra uma revisao manual do Google Play com video demonstrativo e justificativa por escrito, alem de piorar a taxa de aceite da permissao.
- NAO use opencv_dart para correcao de perspectiva de cupom. Voce estaria embarcando dezenas de MB de binarios OpenCV por ABI para fazer algo que o ML Kit Document Scanner (Android) e o VisionKit (iOS) ja fazem nativamente, de graca, com melhor UX.
- NAO faca compressao/resize pesado com package:image no isolate principal nem sequer em isolate secundario como caminho padrao — Dart puro e comprovadamente lento para isso mesmo em release. Use flutter_image_compress (nativo).
- NAO migre para material_ui/cupertino_ui agora. Versao 0.0.2, publicada em 21-22/07/2026, sem guia de migracao, sem cronograma, sem deprecacao formal do in-SDK. Migrar hoje e assinar contrato de retrabalho.
- NAO conte com Material 3 Expressive. O time do Flutter declarou explicitamente que nao esta desenvolvendo essas features no core e nao aceita contribuicoes. Se o design do produto depende de M3 Expressive, o design precisa mudar ou ser implementado a mao.
- RESTRICAO LEGAL — NAO PROJETE, no app ou no backend, nenhuma forma de: (a) automatizar navegacao nos portais estaduais de NFC-e para colher notas de terceiros; (b) resolver CAPTCHA dos portais SEFAZ, seja por OCR, servico de resolucao ou automacao de browser; (c) burlar rate limit, autenticacao, robots.txt ou termos de uso de sites de supermercado para coletar encartes. O caminho legitimo e o unico admissivel: o proprio consumidor escaneia o QR Code do cupom que ELE recebeu (a chave de acesso e o payload do QR sao dados dele), envia foto de nota que ELE possui, ou envia PDF/imagem de encarte publicamente distribuido. Para dados oficiais em escala, buscar convenio/API publica com a SEFAZ do estado ou parceria com o varejista. Se a unica forma de obter um dado for burlando controle de acesso, o dado NAO entra no produto.
- NAO envie imagem original de cupom fiscal para o Sentry nem para qualquer log. Cupom com CPF na nota contem dado pessoal; anexar a evento de erro e vazamento por descuido.

## RISCOS
- ALTO / PRAZO CURTO — Google Play exige targetSdk 36 para apps novos a partir de 31/08/2026 (40 dias). O default do Flutter 3.44.7 ja atende, mas QUALQUER downgrade de Flutter ou override manual de targetSdk no build.gradle.kts derruba a submissao. Extensao possivel ate 01/11/2026, mas depende de aprovacao.
- ALTO — Fratura do analyzer (12 vs 13) no ecossistema de codegen. O equilibrio validado (analyzer 12.1.0) e FRAGIL: qualquer atualizacao de drift_dev, build_runner ou de um gerador novo pode quebrar. Mitigacao: pins explicitos com comentario, `pubspec.lock` commitado, e um job de CI que roda `flutter pub get` em clean checkout. Reavalie mensalmente — quando riverpod_generator/riverpod_lint subirem para analyzer 13 e freezed 4.0.0 sair estavel, o conflito se resolve sozinho.
- ALTO — 5 plugins do stack (dynamic_color, flutter_image_compress_common, mobile_scanner, patrol, sentry_flutter) ainda aplicam Kotlin Gradle Plugin. O proprio Flutter avisa no build: "Future versions of Flutter will fail to build if your app uses plugins that apply KGP". Isso quebra em alguma versao futura do Flutter, sem data anunciada. Monitore os changelogs desses 5 e acompanhe o issue flutter/flutter#181383.
- MEDIO — Desacoplamento Material/Cupertino. material_ui/cupertino_ui em 0.0.2 sinalizam que o material dentro do SDK esta congelado: bugs de Material podem nao ser corrigidos no core, e correcoes irao para os pacotes novos. Mitigacao: camada de wrappers de UI propria para localizar a migracao futura.
- MEDIO — dio_smart_retry (out/2024) e dynamic_color (ago/2025) e workmanager (ago/2025) estao sem release ha muito tempo. Nenhum quebra hoje, mas sao pontos de bit-rot. Prefira retry proprio; tenha plano B para dynamic_color (fallback para ColorScheme.fromSeed puro).
- MEDIO — Tamanho do APK. Somente as libs nativas do stack minimo somam bastante por ABI: libbarhopper_v3 4,9 MB (ML Kit bundled), libsqlite3 1,7 MB, libsentry 0,8 MB, mais libflutter. Sem a flag de unbundled do mobile_scanner e sem split por ABI, o download vai incomodar o publico-alvo (usuario de supermercado, muitas vezes em aparelho de entrada com pouco espaco). Publique AAB com splits por ABI e ative o unbundled.
- MEDIO — background_downloader: 9 minutos de timeout por task no Android e janela de 4 horas no iOS. Se um lote de fotos de nota ficar preso em rede 3G ruim, tasks morrem. Precisa de retry persistente no lado do app + idempotency key no backend para nao gerar cupons duplicados quando a task reiniciar.
- MEDIO — flutter_secure_storage v10 mudou o esquema de cifra e faz migracao automatica (migrateOnAlgorithmChange). Migracao de cifra + restore de backup e a combinacao classica de perda de token / logout em massa. Trate falha de leitura do token como 'logout silencioso e re-login', nunca como crash.
- MEDIO — Riverpod 3.0 mudou semantica sutil: filtro de update por `==` e Notifiers criados frescos a cada rebuild (o comportamento de pseudo-singleton do 2.x acabou). Codigo portado de tutoriais 2.x vai ter bugs silenciosos de estado. Se precisar do comportamento antigo, sobrescreva updateShouldNotify.
- BAIXO/MEDIO — Riverpod persist() e Mutations sao EXPERIMENTAIS. Se alguem no time usar por acharem conveniente, voce herda API instavel no caminho critico de dados offline.
- BAIXO — go_router URLs case-sensitive desde a 15.0.0. Deep links compartilhados por usuarios (WhatsApp e o canal dominante no Brasil) com case diferente vao 404. Normalize slugs.
- BAIXO — Nao verifiquei o pacote app_attest (versao, manutencao, publisher). Antes de comprometer a arquitetura de anti-abuso com ele, valide no pub.dev ou implemente via platform channel proprio.

## EM ABERTO
- Quando riverpod_generator/riverpod_lint vao subir para analyzer 13? Isso destrava drift_dev 2.34.4 + build_runner 2.15.2 e resolve a fratura. Nao encontrei issue/roadmap com data. Recomendo checar https://pub.dev/api/packages/riverpod_generator mensalmente.
- Quando sai freezed 4.0.0 estavel (hoje em 4.0.0-dev.3, analyzer ^13)? Se sair antes do projeto congelar os modelos, vale reavaliar a decisao de abandonar freezed — mas so depois que o Riverpod tambem estiver em analyzer 13.
- Qual o cronograma real de migracao para material_ui/cupertino_ui e quando o material in-SDK sera formalmente depreciado? O README diz apenas "Coming soon". Acompanhar https://github.com/flutter/flutter/issues/168813.
- Em qual versao do Flutter os plugins que aplicam KGP passam de warning para erro fatal? O aviso diz "future versions" sem numero. Acompanhar flutter/flutter#181383.
- Nao verifiquei o pacote app_attest (versao, publisher, manutencao, se cobre Play Integrity Standard ou so Classic). Validar antes de fechar a arquitetura de anti-abuso, ou implementar via platform channel proprio.
- Nao medi o impacto real de opencv_dart 2.2.1+4 no tamanho do APK — descartei por analise, nao por medicao. Se houver requisito de visao computacional que o ML Kit nao cubra, medir antes de decidir.
- Nao confirmei requisitos NOVOS de permissao de localizacao especificos de Android 15 (API 35) ou Android 16 (API 36) alem do FOREGROUND_SERVICE_LOCATION do Android 14. Como o produto e foreground-only, o risco e baixo, mas vale conferir developer.android.com/about/versions/16/behavior-changes-16 antes do lancamento.
- cunning_document_scanner nao documenta comportamento no simulador iOS nem limite de paginas por sessao alem do parametro noOfPages. Testar em device fisico cedo — VisionKit tipicamente nao funciona em simulador.
- Nao testei o build iOS (apenas Android). Rodar `flutter build ios --no-codesign` com este pubspec para validar CocoaPods/SwiftPM, especialmente a coexistencia de mobile_scanner (Vision), cunning_document_scanner (VisionKit) e camera.
- Politica de retencao/PII das imagens de cupom (contem CPF quando o consumidor pede nota na compra) — decisao de produto e juridica (LGPD), fora do escopo deste topico, mas impacta o design do pipeline de upload e do Sentry.


################################################################
# TOPICO: Conformidade legal brasileira (LGPD, direito autoral, marcas, CDC, Marco Civil) para o app colaborativo de preços "melhor_mercado"
################################################################

## RESUMO EXECUTIVO
O produto é juridicamente viável e tem precedente estatal forte: o CONFAZ opera desde 2019 o "Menor Preço Brasil" (Convênio de Cooperação Técnica nº 03/19, 174ª reunião CONFAZ, 27/09/2019), que faz exatamente isso — publica preço por item, nominando o estabelecimento, a partir de NF-e/NFC-e, hoje em 21 estados + DF. Isso derruba a tese de que publicar preço praticado por supermercado nomeado é ilícito.

Arquitetura legal recomendada: separar dois fluxos. (1) PREÇO/ITEM/LOJA = fato comercial, não é dado pessoal e não é obra protegida (Lei 9.610/98, art. 8º) — publique livremente. (2) IDENTIDADE DO CONTRIBUINTE/CPF = dado pessoal — nunca persista. O CPF NÃO está no QR Code 2.0 da NFC-e (payload online = chNFe|nVersao|tpAmb|cIdToken|cHashQRCode); ele aparece no DANFE impresso e na tela de consulta da SEFAZ. Logo o risco concentra-se no fluxo de FOTO/OCR, não no fluxo de QR.

Base legal: art. 7º, IX (legítimo interesse) para extrair e publicar preços agregados, com teste de balanceamento de 3 fases (finalidade → necessidade → balanceamento e salvaguardas) documentado conforme o Guia Orientativo da ANPD v1.0 (fev/2024); art. 7º, I (consentimento) apenas para conta/e-mail/geolocalização e gamificação. NÃO use consentimento como base do banco de preços — revogação quebraria o produto. Para o CPF a resposta é "nenhuma base legal": descarte-o.

Decisão técnica crítica: redação (blur + tarja) do CPF ANTES da persistência, na borda, em memória; o original com CPF visível nunca toca o S3. Hash/HMAC de CPF NÃO é anonimização — o espaço de CPFs válidos é ~10^9, força bruta é trivial em GPU, logo continua dado pessoal (art. 12).

Prazos: art. 19 exige confirmação em formato simplificado imediatamente e declaração completa em até 15 dias. Como startup enquadrável na Resolução CD/ANPD nº 2/2022, os prazos dobram (30 dias) e o encarregado é dispensado — mas o canal de comunicação continua obrigatório. Exposição máxima: art. 52, II — 2% do faturamento, teto R$ 50.000.000,00 por infração.

Zonas vermelhas: republicar a IMAGEM do encarte (viola direito autoral sobre a arte); scraping atrás de login/CAPTCHA/rate limit; e obter microdados de NFC-e de terceiros fora do Convênio (esbarra em sigilo fiscal).

## ACHADOS

### [confirmada] Legítimo interesse (art. 7º, IX) é a base legal correta para extrair e publicar PREÇOS agregados; consentimento não é.
Art. 7º, IX LGPD: tratamento permitido "quando necessário para atender aos interesses legítimos do controlador ou de terceiro, exceto no caso de prevalecerem direitos e liberdades fundamentais do titular que exijam a proteção dos dados pessoais". Consentimento é inadequado porque o art. 18, IX + art. 8º §5º dão direito de revogação a qualquer tempo — revogar destruiria a base de preços já publicada. Preço/produto/loja/data, uma vez desvinculados do usuário, sequer são dado pessoal, então o legítimo interesse cobre apenas a etapa transitória em que a submissão ainda está ligada ao user_id.
FONTE: https://lgpd-brasil.info/capitulo_02/artigo_07

### [confirmada] A ANPD exige teste de balanceamento em 3 fases nomeadas para usar legítimo interesse, e ele deve ser documentado e refeito por finalidade.
Guia Orientativo "Hipóteses legais de tratamento de dados pessoais — LEGÍTIMO INTERESSE", ANPD, Versão 1.0, publicação digital fevereiro/2024, Brasília/DF. FASE 1 FINALIDADE (verificar natureza do dado; identificar e descrever o interesse); FASE 2 NECESSIDADE (art. 10 §1º — "somente os dados pessoais estritamente necessários"; privilegiar formas menos intrusivas); FASE 3 BALANCEAMENTO E SALVAGUARDAS (avaliar risco/impacto e adotar a perspectiva do titular). Texto literal do Guia: "O teste de balanceamento deve ser aplicado para cada finalidade específica" e "o que a LGPD exige não é o impacto zero, mas, sim, que eventuais impactos sejam minimizados". Anexo II traz modelo de teste simplificado (p. 45). Modelo da ANPD não é de uso obrigatório.
FONTE: https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/guia_orientativo_hipoteses_legais_tratamento_de_dados_pessoais_legitimo_interesse

### [confirmada] Interesse só é "legítimo" se cumprir 3 condições cumulativas definidas pela ANPD — critério direto para redigir o LIA do projeto.
Guia ANPD, p. 16: (i) compatibilidade com o ordenamento jurídico; (ii) lastro em situações concretas ("situações reais, claras e precisas", afastando interesses "abstratos ou meramente especulativos"); (iii) vinculação a finalidades legítimas, específicas e explícitas. Art. 10 caput: legítimo interesse só fundamenta tratamento "para finalidades legítimas, consideradas a partir de situações concretas".
FONTE: https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/copy_of_guia_legitimo_interesse.pdf/@@display-file/file

### [confirmada] Legítima expectativa (art. 10, II) é avaliada por 4 fatores explícitos da ANPD — o fator (b) favorece o app, porque o dado vem do próprio usuário.
Guia ANPD p. 23, fatores: (a) existência de relação prévia do controlador com o titular; (b) a fonte e a forma da coleta dos dados, isto é, se a coleta foi realizada diretamente pelo controlador, se os dados foram compartilhados por terceiros ou coletados de fontes públicas; (c) o contexto e o período de coleta; (d) a finalidade pretendida da coleta e sua compatibilidade com o tratamento baseado no legítimo interesse. No melhor_mercado o usuário envia voluntariamente seu próprio cupom para obter comparação de preço → relação prévia + coleta direta + finalidade óbvia e anunciada = expectativa legítima satisfeita.
FONTE: https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/copy_of_guia_legitimo_interesse.pdf/@@display-file/file

### [confirmada] Legítimo interesse NÃO se aplica a dados pessoais sensíveis — e cupons de farmácia/produtos de saúde podem revelar dado sensível.
Guia ANPD p. 8: "trata-se de uma hipótese legal não aplicável ao tratamento de dados pessoais sensíveis, haja vista a sua previsão apenas no art. 7º da LGPD, não tendo sido reproduzida no art. 11". Consequência de arquitetura: se o app aceitar cupons de farmácia, itens que revelem condição de saúde (medicamento tarja preta, teste de gravidez, insulina) ligados a um usuário identificável caem no art. 11 e o legítimo interesse morre. Mitigação: desvincular user_id do item na publicação, ou blocklist de NCM/GTIN de categoria sensível no fluxo de gamificação/histórico pessoal.
FONTE: https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/copy_of_guia_legitimo_interesse.pdf/@@display-file/file

### [provavel] O QR Code 2.0 da NFC-e NÃO contém o CPF do consumidor — o risco de CPF está no OCR de foto, não no scan de QR.
QR Code 2.0 (obrigatório desde outubro/2018, NFC-e 4.00). Modo online: 5 parâmetros separados por "|" — chNFe (44 dígitos) | nVersao | tpAmb (1=Produção, 2=Homologação) | cIdToken (identificador do CSC) | cHashQRCode. Contingência offline (tpEmis=9) acrescenta dhEmi | vNF | digVal. cHashQRCode = SHA-1 sobre a concatenação dos parâmetros + CSC, em hexadecimal (40 caracteres). O parâmetro cDest existia no QR Code 1.0 e foi removido no 2.0. Manual de Especificações Técnicas do DANFE NFC-e e QR Code, versão 6.0, março/2025.
FONTE: https://blog.oobj.com.br/qr-code-2-0-nfce-4-0

### [provavel] O CPF aparece impresso no DANFE NFC-e e na tela de consulta da SEFAZ — portanto a redação deve ocorrer no pipeline de imagem, antes de qualquer persistência.
Quando o consumidor solicita CPF na nota, o DANFE NFC-e imprime a identificação do destinatário (tipicamente linha "CONSUMIDOR - CPF: XXX.XXX.XXX-XX" no cabeçalho/rodapé). A consulta por chave de acesso nos portais estaduais retorna "todos os dados" da NFC-e, incluindo o bloco Destinatário. Não confirmei o layout exato do campo no Manual de Padrões v6.0 (março/2025) — tratar como requisito de detecção robusta, não como offset fixo.
FONTE: https://www.nfe.fazenda.gov.br/portal/exibirArquivo.aspx?conteudo=k/IuuaW4YiY%3D

### [confirmada] Hash ou HMAC de CPF NÃO é anonimização sob o art. 12 — continua dado pessoal e continua sob toda a LGPD.
Art. 12 LGPD: dado anonimizado não é dado pessoal "salvo quando o processo de anonimização ao qual foram submetidos for revertido, utilizando exclusivamente meios próprios, ou quando, com esforços razoáveis, puder ser revertido". O CPF tem 9 dígitos-base + 2 verificadores → ~10^9 valores válidos. Enumerar 10^9 candidatos contra SHA-256/HMAC é ordem de segundos a minutos em GPU comum, muito abaixo de qualquer limiar de "esforço razoável". Mesmo com pepper secreto, o vazamento do pepper reverte tudo instantaneamente: é pseudonimização, não anonimização. A ANPD colocou Estudo Preliminar sobre Anonimização e Pseudonimização em consulta pública em 30/01/2024, com abordagem de risco de reidentificação baseada em custo e tempo.
FONTE: https://www.gov.br/anpd/pt-br/centrais-de-conteudo/documentos-tecnicos-orientativos/estudo_tecnico_sobre_anonimizacao_de_dados_na_lgpd___analise_juridica.pdf/@@display-file/file

### [confirmada] Prazo de resposta ao titular: confirmação/acesso em formato simplificado IMEDIATAMENTE; declaração clara e completa em até 15 dias (art. 19).
Art. 19, I: "em formato simplificado, imediatamente". Art. 19, II: "por meio de declaração clara e completa, que indique a origem dos dados, a inexistência de registro, os critérios utilizados e a finalidade do tratamento, observados os segredos comercial e industrial, fornecida no prazo de até 15 (quinze) dias, contado da data do requerimento do titular". Isso vira dois endpoints distintos: um síncrono e um assíncrono com SLA.
FONTE: https://compliance.mspa.com.br/regulamentos/lgpd/artigo-19/

### [confirmada] Como startup/pequeno porte (Resolução CD/ANPD nº 2/2022) o app tem prazos EM DOBRO e dispensa de encarregado — mas canal de comunicação continua obrigatório.
Resolução CD/ANPD nº 2, de 27/01/2022. Art. 2º: abrange microempresas e EPP (limites da LC 123/2006), startups (critérios da LC 182/2021), pessoas jurídicas de direito privado inclusive sem fins lucrativos. Art. 11: "não são obrigados a indicar o encarregado", porém devem disponibilizar "um canal de comunicação com o titular de dados". Art. 14: prazos em dobro para atender requisições de titulares, comunicar incidentes à ANPD e aos titulares, e prestar informações à ANPD. Art. 9º: registro de operações de forma simplificada. Art. 3º/4º: EXCLUÍDO do regime quem faz tratamento de alto risco (larga escala, tecnologias emergentes, decisões automatizadas que afetam personalidade/crédito, dados sensíveis, dados de crianças) ou estoura os limites de receita.
FONTE: https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd/resolucao-cd-anpd-no-2-de-27-de-janeiro-de-2022

### [provavel] ATENÇÃO — o app provavelmente PERDE o regime de pequeno porte ao escalar, porque "tratamento em larga escala" é critério de alto risco.
Resolução CD/ANPD nº 2/2022, art. 3º c/c art. 4º: excluído do regime simplificado quem realiza tratamento de alto risco, que inclui operações em larga escala e uso de tecnologias emergentes. Um app nacional de preços com milhões de submissões e OCR/ML pode ser enquadrado. Consequência de arquitetura: projetar desde o dia 1 para os prazos ESTRITOS (15 dias) e para encarregado nomeado, tratando o regime de pequeno porte como folga operacional, não como premissa. Este enquadramento é inferência minha a partir dos critérios do art. 4º; não encontrei manifestação da ANPD sobre apps de preços.
FONTE: https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd/resolucao-cd-anpd-no-2-de-27-de-janeiro-de-2022

### [confirmada] Direitos do titular (art. 18) são 9 e todos gratuitos; o controlador ainda deve propagar correção/eliminação a terceiros com quem compartilhou.
Art. 18, I a IX: confirmação da existência de tratamento; acesso aos dados; correção de dados incompletos, inexatos ou desatualizados; anonimização, bloqueio ou eliminação de dados desnecessários, excessivos ou tratados em desconformidade; portabilidade a outro fornecedor mediante requisição expressa; eliminação dos dados tratados com consentimento; informação sobre entidades públicas e privadas com as quais houve uso compartilhado; informação sobre a possibilidade de não fornecer consentimento e suas consequências; revogação do consentimento. §2º: direito de OPOSIÇÃO quando o tratamento se der sem consentimento (é exatamente o caso do legítimo interesse). §5º: atendimento gratuito. §6º: dever de comunicar correção/eliminação/anonimização/bloqueio aos agentes com quem houve compartilhamento. §7º: portabilidade não abrange dados já anonimizados.
FONTE: https://lgpd-brasil.info/capitulo_03/artigo_18

### [confirmada] Retenção: art. 16 permite conservar após o término do tratamento apenas em 4 hipóteses fechadas — a que serve ao app é o inciso IV (uso exclusivo, anonimizado).
Art. 15 (término do tratamento): I – finalidade alcançada ou dados não mais necessários; II – fim do período de tratamento; III – comunicação do titular, inclusive revogação de consentimento. Art. 16: dados devem ser eliminados após o término, autorizada a conservação para: I – cumprimento de obrigação legal ou regulatória; II – estudo por órgão de pesquisa, garantida a anonimização sempre que possível; III – transferência a terceiro respeitados os requisitos da Lei; IV – uso exclusivo do controlador, vedado seu acesso por terceiro, e desde que anonimizados os dados. O inciso IV é a chave: a base de preços sobrevive indefinidamente PORQUE está desvinculada do titular.
FONTE: https://lgpd-brasil.info/capitulo_02/artigo_16

### [confirmada] Exposição sancionatória máxima: 2% do faturamento no Brasil, teto R$ 50.000.000,00 POR INFRAÇÃO, mais multa diária e suspensão do banco de dados.
Art. 52 LGPD: I – advertência com prazo para medidas corretivas; II – multa simples de até 2% do faturamento, limitada a R$ 50.000.000,00 por infração; III – multa diária, observado o limite do inciso II; IV – publicização da infração; V – bloqueio dos dados pessoais até regularização; VI – eliminação dos dados pessoais; X – suspensão parcial do funcionamento do banco de dados por até 6 meses, prorrogável por igual período; XI – suspensão do exercício da atividade de tratamento por até 6 meses, prorrogável; XII – proibição parcial ou total do exercício de atividades de tratamento. Incisos VII a IX foram vetados. Dosimetria regulada pela Resolução CD/ANPD nº 4, de 24/02/2023.
FONTE: https://lgpd-brasil.info/capitulo_08/artigo_52

### [confirmada] PRECEDENTE DECISIVO: 22 fiscos estaduais publicam preço por item nominando o estabelecimento, exatamente o que o app fará.
App "Menor Preço Brasil", lançado pelo CONFAZ com base no Convênio de Cooperação Técnica nº 03/19, aprovado na 174ª reunião do CONFAZ em 27/09/2019, em Recife. Desenvolvido pela PROCERGS no âmbito do SVRS (Sistema Visão Recursos Compartilhados) da SEFAZ-RS. Consulta NF-e e NFC-e, com preço atualizado "em tempo real, ou seja, assim que a nota fiscal é emitida". 21 estados + DF listados: AC, AL, AP, AM, BA, CE, ES, MA, MT, MG, PA, PE, PI, RJ, RN, RO, RR, SC, SE, TO, RS, DF. O serviço mostra "a relação dos preços e por qual estabelecimento foram praticados"; no RS há mais de 300.000 estabelecimentos participantes. O ES adotou o Menor Preço Brasil como aplicativo oficial único de consulta de preços.
FONTE: https://www.confaz.fazenda.gov.br/noticias-do-confaz/confaz-lanca-aplicativo-menor-preco-brasil-destinado-a-ajudar-o-cidadao-a-encontrar-os-melhores-valores-no-comercio

### [confirmada] O PREÇO não é dado pessoal e não é "dado do supermercado" em sentido proprietário — é fato comercial, e a lei brasileira já obriga sua exibição pública.
(a) LGPD art. 5º, I define dado pessoal como informação relacionada a pessoa natural identificada ou identificável — supermercado é pessoa jurídica, fora do escopo. (b) Lei 10.962/2004 (Lei de Afixação de Preços) + Decreto 5.903/2006 obrigam o varejo a afixar preços de forma ostensiva e legível; em autosserviço, por impressão/afixação na embalagem, código referencial ou código de barras, com leitores ópticos disponíveis na área de vendas. Um preço que a lei obriga a expor ostensivamente ao público não pode ser reivindicado como segredo de negócio. (c) Não localizei jurisprudência brasileira condenando comparador de preços por publicar preço praticado por estabelecimento nomeado.
FONTE: https://www.lexml.gov.br/urn/urn:lex:br:federal:lei:2004-10-11;10962

### [confirmada] Direito autoral: PREÇO é fato não protegido; a ARTE do encarte é expressão protegida. Extrair preços do encarte é lícito; republicar a imagem do encarte não é.
Lei 9.610/98, art. 8º — não são objeto de proteção como direitos autorais: I – ideias, procedimentos normativos, sistemas, métodos, projetos ou conceitos matemáticos como tais; II – esquemas, planos ou regras para realizar atos mentais, jogos ou negócios; III – formulários em branco para serem preenchidos por qualquer tipo de informação, científica ou não, e suas instruções; IV – textos de tratados ou convenções, leis, decretos, regulamentos, decisões judiciais e demais atos oficiais; V – informações de uso comum tais como calendários, agendas, cadastros ou legendas; VI – nomes e títulos isolados; VII – o aproveitamento industrial ou comercial das ideias contidas nas obras. "R$ 8,99 para arroz Tio João 5kg" é informação de uso comum / fato, não obra. Já o layout, diagramação, fotografia de produto, ilustração e composição gráfica do encarte são obra e a reprodução integral exige autorização.
FONTE: https://www.legjur.com/legislacao/art/lei_00096101998-8

### [confirmada] Marcas: o uso nominativo em comparador é defensável, mas o art. 132, IV tem a ressalva "sem conotação comercial" — o inciso I é a âncora mais segura.
Lei 9.279/96, art. 132: o titular da marca não pode impedir (I) que comerciantes ou distribuidores utilizem sinais distintivos que lhes são próprios, juntamente com a marca do produto, na sua promoção e comercialização; (IV) a citação da marca em discurso, obra científica ou literária ou qualquer outra publicação, desde que sem conotação comercial e sem prejuízo para seu caráter distintivo. Ponto de atenção real: doutrina brasileira sustenta que, a contrario sensu, a exigência de "sem conotação comercial" no inciso IV permitiria ao titular impedir o uso em peça publicitária, inclusive comparativa. Um app monetizado tem conotação comercial. Defesa: uso puramente descritivo/referencial (identificar de qual loja é o preço), sem imitar trade dress, sem sugerir patrocínio, sem denegrir.
FONTE: https://www.jusbrasil.com.br/topicos/10583622/art-132-da-lei-n-9279-de-14-de-maio-de-1996

### [confirmada] CDC: quem responde por preço anunciado é o FORNECEDOR que patrocina o anúncio, não o intermediário informacional — art. 38 é a peça central da defesa.
CDC art. 30: toda informação ou publicidade, veiculada por qualquer forma ou meio de comunicação com relação a produtos e serviços oferecidos, obriga o fornecedor que a fizer veicular ou dela se utilizar e integra o contrato. Art. 35: recusado o cumprimento da oferta, o consumidor pode exigir cumprimento forçado, aceitar produto equivalente ou rescindir com restituição e perdas e danos. Art. 38: "o ônus da prova da veracidade e correção da informação ou comunicação publicitária cabe a quem a patrocina". O app não é fornecedor do produto nem patrocinador da oferta; ele reporta observação histórica de preço. Exceção conhecida: erro grosseiro afasta a vinculação (preço evidentemente irreal).
FONTE: https://www.tjdft.jus.br/institucional/imprensa/noticias/2017/fevereiro/supermercado-e-condenado-por-cobrar-preco-distinto-do-anunciado-nas-prateleiras

### [provavel] Responsabilidade por conteúdo de terceiros mudou: o STF declarou o art. 19 do Marco Civil parcialmente inconstitucional.
RE 1.037.396/SP (Tema 987 de repercussão geral, rel. Min. Dias Toffoli) e RE 1.057.258 (Tema 533). O STF fixou que o art. 19 da Lei 12.965/2014 — que exige ordem judicial específica para responsabilizar provedor de aplicação por conteúdo de terceiro — é parcialmente inconstitucional por omissão parcial, sendo proteção insuficiente. Provedores passam a responder civilmente se não agirem imediatamente para remover conteúdo que configure crimes graves; para crimes contra a honra permanece a exigência de ordem judicial. Consequência prática: o app precisa de fluxo de notice-and-takedown operacional para preços falsos/difamatórios ("supermercado X cobra R$ 90 no arroz"), não pode esperar ordem judicial como regra. Não verifiquei a data exata do julgamento nem o texto final da tese.
FONTE: https://noticias.stf.jus.br/postsnoticias/stf-define-parametros-para-responsabilizacao-de-plataformas-por-conteudos-de-terceiros/

### [confirmada] Guarda de logs: 6 meses é obrigação legal, não escolha de produto — e é também o teto que se deve praticar.
Marco Civil da Internet (Lei 12.965/2014), art. 15: o provedor de aplicações de internet constituído na forma de pessoa jurídica, que exerça essa atividade de forma organizada, profissionalmente e com fins econômicos, deverá manter os respectivos registros de acesso a aplicações de internet, sob sigilo, em ambiente controlado e de segurança, pelo prazo de 6 (seis) meses. §1º: ordem judicial pode exigir guarda por prazo maior de provedores não abrangidos pelo caput. §2º: autoridade policial/administrativa ou MP pode requerer cautelarmente guarda por prazo superior. §3º: disponibilização dos registros mediante autorização judicial. Isso é uma hipótese do art. 16, I da LGPD (cumprimento de obrigação legal) — logo, guardar exatamente 6 meses e eliminar.
FONTE: https://jurishand.com/lei-12965-de-23-abril-2014/artigo-15

### [confirmada] Registro de operações (art. 37) e RIPD (art. 10, §3º) são exigíveis e devem ser artefatos versionados no repositório.
Guia ANPD p. 26: art. 37 LGPD impõe manutenção dos registros das operações de tratamento, "especialmente quando este for baseado no legítimo interesse". A documentação "poderá, ainda, conter a análise efetuada pelo controlador, em especial o teste de balanceamento". Art. 10, §3º: "a autoridade nacional poderá solicitar ao controlador relatório de impacto à proteção de dados pessoais, quando o tratamento tiver como fundamento seu interesse legítimo, observados os segredos comercial e industrial". Art. 6º, X (responsabilização e prestação de contas) é o princípio que sustenta a exigência.
FONTE: https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/copy_of_guia_legitimo_interesse.pdf/@@display-file/file

### [confirmada] Encarregado (DPO): identidade e contato devem ser públicos, preferencialmente no site — vira requisito de rota web e de tela no app.
Art. 41 LGPD: o controlador deverá indicar encarregado pelo tratamento de dados pessoais. §1º: "a identidade e as informações de contato do encarregado deverão ser divulgadas publicamente, de forma clara e objetiva, preferencialmente no sítio eletrônico do controlador". §2º: atribuições — aceitar reclamações e comunicações dos titulares, prestar esclarecimentos e adotar providências; receber comunicações da ANPD e adotar providências; orientar funcionários e contratados; executar demais atribuições. §3º: a ANPD pode dispensar a indicação conforme natureza, porte e volume (é o que fez na Resolução nº 2/2022).
FONTE: https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd/resolucao-cd-anpd-no-2-de-27-de-janeiro-de-2022

### [confirmada] Os 10 princípios do art. 6º viram checklist de arquitetura; "qualidade dos dados" é o que juridicamente obriga a exibir data e fonte do preço.
Art. 6º LGPD: I finalidade; II adequação; III necessidade ("limitação do tratamento ao mínimo necessário para a realização de suas finalidades, com abrangência dos dados pertinentes, proporcionais e não excessivos"); IV livre acesso; V qualidade dos dados ("garantia, aos titulares, de exatidão, clareza, relevância e atualização dos dados, de acordo com a necessidade e para o cumprimento da finalidade de seu tratamento"); VI transparência; VII segurança; VIII prevenção; IX não discriminação; X responsabilização e prestação de contas. O inciso V é o gancho normativo direto para o requisito de UI "preço observado em DD/MM/AAAA, fonte: cupom fiscal enviado por usuário".
FONTE: https://compliance.mspa.com.br/regulamentos/lgpd/artigo-6/

### [baixa] A ANPD tem atividade fiscalizatória concreta sobre coleta de CPF no varejo (setor farmacêutico) — o tema não é teórico.
Existe Nota Técnica pública da ANPD identificada como NT 6/2025 (SEI 00261.001371/2023-32), arquivo publicado em 13/02/2025 no repositório de documentos técnicos orientativos da ANPD, no contexto de fiscalizações envolvendo proteção de dados no setor farmacêutico e coleta de CPF. O Idec enviou ofício a Senacon, ANPD e Defensoria Pública de SP sobre CPF nas farmácias. NÃO consegui extrair o conteúdo do PDF (o fetch retornou apenas metadados da página) — não confirmei o teor, as conclusões nem eventuais determinações. Tratar como sinal de risco regulatório, não como fundamento.
FONTE: https://www.gov.br/anpd/pt-br/centrais-de-conteudo/documentos-tecnicos-orientativos/nt-6_2025-fis_cgf_anpd_nota_tecnica__pub__6.pdf

### [provavel] A coleta de CPF na NFC-e pelo COMERCIANTE tem base legal própria (obrigação legal), mas isso NÃO se transfere ao app.
A inclusão do CPF na NFC-e/CF-e-SAT pelo emitente é enquadrada como cumprimento de obrigação legal ou regulatória (art. 7º, II LGPD). O melhor_mercado não é o emitente nem tem obrigação fiscal alguma sobre esse dado: para ele o CPF é dado excedente, sem finalidade, e reter esse dado viola diretamente o art. 6º, III (necessidade). Não há base legal disponível ao app para persistir CPF de cupom — a resposta correta é descartar, não escolher base.
FONTE: https://www.conjur.com.br/2022-abr-28/avila-menke-exigencia-cpf-nota-protecao-dados/

### [baixa] Obter microdados de NFC-e de terceiros fora do Convênio esbarra em sigilo fiscal — a via legítima é convênio/parceria com SEFAZ, não requisição ou coleta.
O CTN veda a divulgação, por parte da Fazenda Pública, de informação obtida em razão do ofício sobre a situação econômica ou financeira do sujeito passivo (dispositivo referido na doutrina como art. 198 do CTN — NÃO verifiquei o texto na fonte primária nesta pesquisa). É por isso que a publicação item-a-item pelos fiscos precisou de um instrumento formal (Convênio de Cooperação Técnica nº 03/19 / CONFAZ). Conclusão prática: pedido via LAI (Lei 12.527/2011) para microdados de NFC-e de terceiros tende a ser negado por sigilo fiscal. A via legítima para o app é (a) o QR/cupom do PRÓPRIO usuário, (b) convênio/API formal com SEFAZ, (c) dados abertos já publicados.
FONTE: https://www.confaz.fazenda.gov.br/noticias-do-confaz/confaz-lanca-aplicativo-menor-preco-brasil-destinado-a-ajudar-o-cidadao-a-encontrar-os-melhores-valores-no-comercio

### [provavel] Scraping: não existe imunidade legal genérica no Brasil; a defensabilidade cai a zero quando há barreira técnica ou contratual contornada.
Não localizei precedente do STJ que autorize ou proíba scraping de preços de forma geral. O consenso doutrinário brasileiro (ConJur, Data Privacy Brasil e afins) é que a análise passa por: termos de uso (natureza contratual), robots.txt (manifestação de vontade do titular do site), LGPD quando há dado pessoal envolvido, concorrência desleal (Lei 9.279/96) e abuso quando a carga degrada o serviço alheio. Coleta de página pública, sem login, respeitando robots.txt e com rate limit conservador, é a zona defensável. Contornar CAPTCHA, autenticação, rate limit ou cláusula expressa de proibição sai da zona defensável e pode configurar, além de ilícito civil, discussão penal de acesso não autorizado.
FONTE: https://www.conjur.com.br/2022-set-18/igor-rocha-web-crawlers-web-scrapers-direito/

### [provavel] O próprio Menor Preço Brasil não publica disclaimer de acurácia visível — o melhor_mercado deve ir além do padrão estatal, não igualar-se a ele.
A página oficial do Menor Preço (NFG/SEFAZ-RS) descreve que mostra "a relação dos preços e por qual estabelecimento foram praticados" e que atualiza "em tempo real, ou seja, assim que a nota fiscal é emitida", mas não apresenta disclaimer explícito de acurácia nem janela temporal declarada no conteúdo que consegui recuperar. Como ente privado sem a blindagem institucional de um fisco, o app deve exibir data/hora da observação, fonte e aviso de não-vinculação em toda superfície de preço.
FONTE: https://nfg.sefaz.rs.gov.br/site/MenorPreco.aspx

## ESPECIFICACOES CONCRETAS
- PIPELINE DE REDAÇÃO DE CPF (ordem obrigatória): bytes recebidos -> antivírus/validação MIME -> OCR em memória (buffer, nunca em disco não-cifrado) -> detecção de PII -> redação destrutiva (pixels sobrescritos, não overlay) -> só então PUT no S3. O objeto original NUNCA recebe chave no bucket. Implementar como uma única função pura `redact_receipt(bytes) -> (redacted_bytes, extracted_items)` que não expõe o buffer original ao chamador.
- REGEX DE DETECÇÃO DE CPF (aplicar sobre texto OCR e sobre bounding boxes): `(?<!\d)(\d{3})[.\s]?(\d{3})[.\s]?(\d{3})[-\s]?(\d{2})(?!\d)`. Validar dígitos verificadores (módulo 11) antes de tratar como CPF, para reduzir falso-positivo com códigos de barras e chave de acesso. Detectar também os rótulos âncora: 'CPF', 'CNPJ/CPF', 'CONSUMIDOR', 'DOCUMENTO', 'CPF/CNPJ do Consumidor'. Sempre redigir a região do rótulo + 60px à direita, mesmo quando o OCR falhar em ler os dígitos.
- REGEX DE CHAVE DE ACESSO (NÃO é PII, preservar): `(?<!\d)\d{44}(?!\d)`. Cuidado: a chave contém o CNPJ do EMITENTE (posições 7-20), que é pessoa jurídica e portanto fora da LGPD — não redigir.
- PARSING DO QR CODE 2.0 (NFC-e 4.00): payload = `<URL_UF>?p=chNFe|nVersao|tpAmb|cIdToken|cHashQRCode` para emissão online; contingência offline (tpEmis=9) = `chNFe|nVersao|tpAmb|dhEmi|vNF|digVal|cIdToken|cHashQRCode`. Separador `|`. tpAmb: 1=Produção, 2=Homologação — REJEITAR tpAmb=2 na ingestão. cHashQRCode = SHA-1 hex, 40 caracteres. chNFe = 44 dígitos numéricos. NÃO há campo de CPF neste payload.
- MODELO DE RETENÇÃO (proposta concreta, por artefato): (1) imagem original com PII = 0 dias, nunca persistida; buffer em memória com TTL de processamento máx 300s. (2) imagem redigida do cupom = 180 dias, depois DELETE via lifecycle rule do bucket. Justificativa: prova em caso de contestação do estabelecimento sobre preço publicado + janela de antifraude; art. 16 LGPD não autoriza retenção indefinida sem finalidade. (3) fila de quarentena para falha de OCR = 7 dias, depois purge automático. (4) vínculo submission.user_id -> NULL após 90 dias (a observação de preço vira dado anonimizado, art. 12/art. 16, IV, e sai do escopo da LGPD). (5) tupla de preço {gtin, store_id, price_cents, observed_at} = retenção indefinida APÓS a desvinculação. (6) registros de acesso à aplicação = exatamente 180 dias (Marco Civil art. 15), nem mais nem menos. (7) conta de usuário e PII de cadastro = até 15 dias após pedido de eliminação (30 se enquadrado como pequeno porte).
- SCHEMA POSTGRESQL — separação física obrigatória: schema `public` (preços, lojas, produtos, sem PII) e schema `pii` (users, emails, tokens de device) com ROLE distinta. A app de leitura/consulta de preços conecta com um role que NÃO tem GRANT em `pii`. Isso torna a exposição de PII por SQL injection na rota de busca estruturalmente impossível.
- TABELA `price_observations` (sem PII, publicável): id BIGSERIAL, gtin VARCHAR(14) NULL, product_id BIGINT, store_id BIGINT NOT NULL, price_cents INTEGER NOT NULL CHECK (price_cents > 0), observed_at TIMESTAMPTZ NOT NULL, source ENUM('nfce_qr','receipt_ocr','flyer_ocr','admin_import','sefaz_api'), confidence NUMERIC(3,2), nfce_key CHAR(44) NULL, submitted_by BIGINT NULL (setado para NULL por job após 90 dias), redacted_image_key TEXT NULL, expires_at TIMESTAMPTZ (para lifecycle).
- ENDPOINTS DE DIREITOS DO TITULAR (FastAPI): `GET /api/v1/privacy/confirmation` -> síncrono, responde art. 19, I (formato simplificado, imediato), meta de p95 < 300ms, payload {has_data: bool, categories: [...], purposes: [...], legal_bases: [...]}. `POST /api/v1/privacy/requests` -> body {type} com enum EXATA: CONFIRMACAO | ACESSO | CORRECAO | ANONIMIZACAO | BLOQUEIO | ELIMINACAO | PORTABILIDADE | INFO_COMPARTILHAMENTO | INFO_NAO_CONSENTIMENTO | REVOGACAO_CONSENTIMENTO | OPOSICAO (11 tipos: os 9 incisos do art. 18 + oposição do §2º + revogação). `GET /api/v1/privacy/requests/{id}` -> status + deadline_at. `GET /api/v1/privacy/export` -> art. 18, V, formato JSON + CSV, legível por máquina. `DELETE /api/v1/account`. TODOS gratuitos (art. 18, §5º) — nenhum atrás de paywall.
- SLA EM CÓDIGO: constante `TITULAR_REQUEST_SLA_DAYS = 15` e `TITULAR_REQUEST_SLA_DAYS_SMALL_AGENT = 30`. Persistir `deadline_at = created_at + SLA` no momento da criação do pedido; alerta operacional em D+10 (ou D+20). Nunca calcular o prazo no momento da leitura.
- TELA FLUTTER OBRIGATÓRIA em toda exibição de preço: linha com `observed_at` formatado (dd/MM/yyyy HH:mm), badge de `source` ('cupom fiscal' | 'encarte' | 'importação oficial'), e texto fixo: 'Preço observado nesta data. Pode ter mudado. Confirme no estabelecimento.' Não colocar isso só nos Termos — o art. 6º, V (qualidade dos dados) e o CDC exigem a informação no ponto de decisão.
- STALENESS: marcar visualmente preço com `observed_at` > 7 dias como 'desatualizado' e > 30 dias como 'histórico'; não usar preço > 30 dias no ranking principal 'onde sai mais barato'. Números propostos, não impostos por lei.
- ENCARTES — o que persistir e o que não: PERSISTIR {store_id, gtin/nome do produto, price_cents, valid_from, valid_to, source_url, imported_at}. NÃO PERSISTIR nem servir: o arquivo PDF/JPG do encarte, crops da arte, fotos de produto do encarte, logo composto. Se precisar de prova de origem, guardar hash SHA-256 do arquivo + URL + timestamp, em vez do arquivo.
- SCRAPING — configuração defensável: respeitar robots.txt via `urllib.robotparser` ou `protego` (Python), User-Agent identificável com URL de contato (ex.: 'MelhorMercadoBot/1.0 (+https://.../bot)'), rate limit <= 1 req/s por host e concorrência 1 por host, `Crawl-delay` do robots.txt honrado quando presente, backoff exponencial em 429/503, e circuit breaker que desativa o host permanentemente após bloqueio explícito. Manter allowlist de hosts revisada juridicamente — nunca crawl aberto.
- POLÍTICA DE PRIVACIDADE — itens obrigatórios derivados do art. 9º e art. 41, §1º: (1) finalidade específica de cada tratamento; (2) forma e duração do tratamento; (3) identificação e CNPJ do controlador; (4) informações de contato do controlador; (5) uso compartilhado e finalidade; (6) responsabilidades dos agentes; (7) direitos do titular do art. 18 listados um a um com o canal de exercício; (8) base legal declarada POR FINALIDADE (tabela, não prosa); (9) nome e e-mail do encarregado publicados; (10) menção ao direito de oposição do art. 18, §2º quando a base for legítimo interesse; (11) direito de peticionar à ANPD (art. 18, §1º) e aos organismos de defesa do consumidor (art. 18, §8º); (12) política de retenção por categoria de dado.
- ARTEFATOS DE COMPLIANCE VERSIONADOS NO REPO (não em Notion): `/compliance/lia-precos.md` (teste de balanceamento 3 fases da ANPD, uma versão por finalidade), `/compliance/ropa.yaml` (registro de operações, art. 37, formato simplificado se pequeno porte), `/compliance/ripd.md` (art. 10, §3º — a ANPD pode solicitar), `/compliance/retencao.yaml` (fonte da verdade das lifecycle rules do S3, gerada por código).
- NOMENCLATURA DE UI PARA MARCAS: usar o nome do estabelecimento em texto puro, mesma tipografia do resto do app. Nunca renderizar o logotipo/SVG da rede, nunca usar a cor institucional da rede como fundo do card, nunca usar 'Parceiro' / 'Oficial'. Rodapé fixo: 'Marcas citadas pertencem a seus respectivos titulares. Este app não é afiliado a nenhum estabelecimento.'
- NOTICE-AND-TAKEDOWN (exigência prática pós-STF sobre o art. 19 do MCI): endpoint `POST /api/v1/reports` aberto a estabelecimentos e usuários, com tipos PRECO_INCORRETO | LOJA_INEXISTENTE | CONTEUDO_ABUSIVO; SLA interno de 48h para triagem; ação de despublicação reversível (soft delete com `unpublished_at` + `unpublish_reason`), nunca DELETE físico, para preservar trilha de auditoria.
- TETO DE EXPOSIÇÃO A MODELAR NO RISCO: art. 52, II — 2% do faturamento no Brasil, limitado a R$ 50.000.000,00 por infração; art. 52, III — multa diária dentro do mesmo teto; art. 52, X/XI — suspensão do banco de dados ou da atividade por até 6 meses, prorrogável por igual período.

## RECOMENDACOES
- Adotar o Menor Preço Brasil (CONFAZ, Convênio de Cooperação Técnica nº 03/19, 21 estados + DF) como argumento central de defesa e como referência de escopo: se 22 fiscos publicam preço por item nominando o estabelecimento a partir de NFC-e, o mesmo ato praticado por ente privado sobre dado que a Lei 10.962/2004 já obriga a expor publicamente não é ilícito. Citar isso explicitamente na Política de Privacidade e nos Termos.
- Declarar bases legais POR FINALIDADE, em tabela, não em bloco: (a) imagem do cupom -> art. 7º, IX (legítimo interesse), com LIA documentado; (b) preços agregados publicados -> art. 7º, IX na etapa transitória e fora do escopo da LGPD após desvinculação (art. 12/art. 16, IV); (c) CPF no cupom -> NENHUMA base, descarte na ingestão; (d) conta, e-mail, push token -> art. 7º, I ou V; (e) geolocalização precisa -> art. 7º, I (consentimento granular, revogável, com o app funcionando sem ela).
- Redigir o CPF ANTES da persistência, nunca depois. O arquivo original com CPF legível jamais deve receber uma chave no S3. A redação deve ser destrutiva (sobrescrever pixels), não overlay em camada, e aplicada por região do rótulo mesmo quando o OCR não conseguir ler os dígitos — falha de OCR não pode virar vazamento.
- Não armazenar CPF em nenhuma forma, inclusive hash ou HMAC. Se surgir requisito de deduplicação por consumidor, resolvê-lo por chave de acesso da NFC-e (44 dígitos, identifica a NOTA, não a pessoa) — que já serve como chave natural de idempotência e é estritamente melhor para o propósito.
- Elaborar e versionar o teste de balanceamento nas 3 fases nomeadas pela ANPD (finalidade / necessidade / balanceamento e salvaguardas), usando o Anexo II do Guia v1.0 de fev/2024 como modelo, e refazê-lo a cada nova finalidade (ex.: quando surgir recomendação personalizada, publicidade ou venda de insights de mercado — esta última certamente exige novo teste e provavelmente nova base legal).
- Projetar para os prazos ESTRITOS do art. 19 (imediato + 15 dias) desde o dia 1, mesmo estando enquadrado na Resolução CD/ANPD nº 2/2022, porque 'tratamento em larga escala' é critério de alto risco que expulsa o app do regime de pequeno porte assim que ele escalar. Persistir o deadline no registro do pedido, não calculá-lo na leitura.
- Indicar encarregado e publicar nome + e-mail no site e numa tela do app, mesmo estando dispensado pelo art. 11 da Resolução nº 2/2022. O custo é zero e a dispensa da ANPD não dispensa o canal de comunicação com o titular — que continua obrigatório.
- Implementar direito de oposição (art. 18, §2º) como funcionalidade real, não como e-mail: um toggle 'não usar minhas submissões' que faz o usuário parar de alimentar o banco. Isso é a salvaguarda mais forte para sustentar o legítimo interesse no teste de balanceamento, e o Guia da ANPD diz literalmente que a existência de mecanismos de exercício de direitos é critério de avaliação.
- Extrair preços de encartes e descartar a arte. Persistir {loja, produto, preço, validade, URL de origem, hash SHA-256 do arquivo, timestamp} e nunca o arquivo nem crops. Isso mantém o produto do lado do fato (art. 8º da Lei 9.610/98) e fora do lado da expressão.
- Exibir data/hora de observação e fonte em TODA superfície onde um preço aparece — card, lista, comparação, resultado de busca, notificação push. Isso não é polimento de UX: o art. 6º, V (qualidade dos dados) e a defesa contra o CDC dependem disso, e um disclaimer enterrado nos Termos não cumpre a função.
- Enquadrar o app explicitamente como reporte histórico de observação, nunca como oferta: usar 'preço observado em', jamais 'preço' ou 'de/por'. Nunca gerar chamada tipo 'Aproveite: arroz por R$ 8,99 no Mercado X', que aproxima o app de publicidade e ativa o art. 30 do CDC.
- Restringir coleta automatizada a páginas públicas, sem login, com allowlist de hosts revisada juridicamente, robots.txt honrado, User-Agent identificável com URL de contato, rate limit <= 1 req/s por host e circuit breaker permanente em caso de bloqueio. Preferir sempre, nesta ordem: (1) QR/cupom do próprio usuário, (2) convênio ou API formal com SEFAZ, (3) dados abertos publicados, (4) feed/API oficial do varejista, (5) scraping de página pública — e só chegar ao (5) quando (1)-(4) forem inviáveis.
- Buscar formalmente convênio ou acesso a dados abertos junto a uma SEFAZ estadual (RS/PROCERGS é a origem técnica do SVRS e do Menor Preço) como caminho legítimo de bootstrap da base, em vez de tentar obter microdados de NFC-e de terceiros por coleta — que colide com sigilo fiscal.
- Implementar notice-and-takedown operacional com SLA de 48h e despublicação reversível, dado que o STF declarou o art. 19 do Marco Civil parcialmente inconstitucional e a inércia diante de conteúdo lesivo passou a gerar responsabilidade sem necessidade de ordem judicial prévia em parte dos casos.
- Separar fisicamente PII e preços em schemas PostgreSQL distintos com roles distintas, de modo que a rota pública de busca de preços não tenha permissão sequer de ler a tabela de usuários. Isso converte uma classe inteira de vazamento em impossibilidade estrutural.
- Fazer um job diário que zera submission.user_id após 90 dias, transformando a observação de preço em dado efetivamente anonimizado (art. 12) e retirando a base histórica do escopo da LGPD — o que resolve simultaneamente retenção, portabilidade e eliminação para o acervo antigo.

## NAO FAZER
- NÃO usar consentimento (art. 7º, I) como base legal do banco de preços. O art. 18, IX e o art. 8º, §5º garantem revogação a qualquer tempo; se a base for consentimento, cada revogação obriga a remover contribuições já publicadas e o produto se torna operacionalmente insustentável. Legítimo interesse com direito de oposição é a construção correta.
- NÃO armazenar o CPF hasheado, HMAC-ado ou 'pseudonimizado' e chamar isso de anonimização. Existem ~10^9 CPFs válidos; enumerá-los contra qualquer hash é trivial em GPU. Sob o art. 12, isso permanece dado pessoal com todas as obrigações — e ainda cria a falsa sensação de conformidade que atrasa a correção.
- NÃO mascarar o CPF apenas na exibição (ex.: ***.456.789-**) mantendo o valor completo no banco ou na imagem original. Mascaramento de apresentação não é medida de proteção de dados; o dado continua tratado, armazenado e vazável.
- NÃO fazer a redação DEPOIS do OCR e da persistência ('salva primeiro, limpa depois num job'). Entre o PUT e o job existe uma janela em que o bucket contém CPFs legíveis, e backups/replicação capturam justamente esse estado. A redação tem de ser pré-condição da persistência.
- NÃO republicar a imagem, o PDF, crops, thumbnails ou previews do encarte promocional. A arte, diagramação e fotos são obra protegida pela Lei 9.610/98; apenas os PREÇOS são fato livre (art. 8º). Isso vale inclusive para telas internas de admin e para caches de revisão.
- NÃO usar logotipos, trade dress, cores institucionais ou qualquer elemento visual das redes de supermercado nos cards do app, e NÃO usar rótulos como 'Parceiro', 'Oficial' ou 'Verificado pela rede'. Uso nominativo em texto puro é o limite defensável do art. 132 da Lei 9.279/96; qualquer coisa que sugira associação convida ação por uso indevido de marca.
- NÃO contornar CAPTCHA, autenticação, rate limit, robots.txt ou cláusula expressa de termos de uso para obter dados de nenhum site — varejista, marketplace ou SEFAZ. Não existe desenho técnico que torne isso aceitável, e eu não vou propor um. Se o dado só for obtenível assim, a resposta é: esse dado não entra no produto; use as alternativas legítimas (cupom do próprio usuário, convênio com SEFAZ, dados abertos, feed autorizado do varejista, parceria comercial).
- NÃO tratar 'o dado é público / está no site deles' como autorização. O art. 7º, §3º da LGPD exige que o tratamento de dados de acesso público respeite a finalidade, a boa-fé e o interesse público que justificaram sua disponibilização — publicidade do dado não é licença aberta.
- NÃO exibir preço sem data e sem fonte, nem enterrar o disclaimer nos Termos de Uso. O aviso precisa estar no mesmo componente visual do preço; caso contrário ele não cumpre o art. 6º, V da LGPD nem funciona como defesa perante o CDC.
- NÃO usar linguagem de oferta ('por apenas', 'aproveite', 'promoção') nem enviar push de preço como se fosse anúncio. Isso desloca o app de intermediário informacional para veiculador de publicidade e aproxima a aplicação dos arts. 30 e 38 do CDC, invertendo o ônus da prova sobre a correção da informação.
- NÃO tratar a dispensa de encarregado da Resolução CD/ANPD nº 2/2022 como dispensa de canal de atendimento ao titular. O art. 11 dispensa a INDICAÇÃO do encarregado, mas mantém obrigatório o canal de comunicação com o titular.
- NÃO cobrar, exigir plano pago, ou impor fricção artificial (como envio de documento por e-mail) para o exercício dos direitos do art. 18. O §5º determina atendimento gratuito, e barreira de acesso a direito é ela própria uma infração.
- NÃO reter os registros de acesso à aplicação por mais de 6 meses 'por precaução'. O art. 15 do Marco Civil fixa 6 meses; guardar além disso perde a cobertura do art. 16, I da LGPD (obrigação legal) e vira retenção sem base legal.
- NÃO pedir permissão de localização em background nem coletar geolocalização precisa continuamente para 'melhorar recomendações'. É desproporcional ao art. 6º, III (necessidade) e falha na fase 2 (necessidade) do teste de balanceamento da ANPD. Localização aproximada, sob demanda, no momento da busca.

## RISCOS
- Dado sensível por inferência: cupons de farmácia e itens como medicamento de uso contínuo, teste de gravidez ou insulina, ligados a um usuário identificável, caem no art. 11 — e o Guia da ANPD é explícito em que o legítimo interesse NÃO se aplica a dado sensível. Isso pode invalidar a base legal do fluxo pessoal (histórico de compras, gamificação) sem invalidar o fluxo agregado. Mitigar com blocklist de categoria e desvinculação agressiva.
- Perda do regime de pequeno porte por escala: a Resolução CD/ANPD nº 2/2022 exclui do regime quem faz tratamento de alto risco, e 'larga escala' + 'tecnologias emergentes' (OCR/ML) são critérios listados. Um app que planeje operar nacionalmente provavelmente já nasce fora do regime — construir assumindo os prazos dobrados é uma armadilha de dívida jurídica.
- Falha silenciosa de redação de CPF: o modo de falha mais provável não é o OCR ler o CPF e ignorá-lo, é o OCR NÃO ler o CPF (foto tremida, cupom térmico desbotado, ângulo) e o pipeline concluir 'não há PII' e persistir a imagem intacta. Um único bucket com milhares de cupons contendo CPF legível é exatamente o cenário do art. 52, II (2% do faturamento, teto R$ 50 milhões por infração).
- Contra-ataque de varejista por concorrência desleal ou uso de marca: o art. 132, IV da Lei 9.279/96 condiciona a citação livre da marca a 'sem conotação comercial', e um app monetizado tem conotação comercial. O risco não é perder no mérito — é a liminar. Uma ordem para remover uma rede grande da base degrada o produto durante meses.
- Erro de preço com dano concreto: usuário se desloca a um mercado distante confiando em preço desatualizado do app. O app não é fornecedor (CDC art. 30/38 apontam para quem patrocina a oferta), mas a distribuição do ônus da prova em relação de consumo e a tendência pró-consumidor tornam o litígio de baixo valor e alto volume um risco operacional real. A defesa depende inteiramente de a data/fonte estarem visíveis no ponto de decisão.
- Ingestão de dado envenenado: sendo colaborativo, o app é vulnerável a submissões falsas — inclusive maliciosas contra um concorrente ('mercado X cobra R$ 90 no arroz'). Isso combina risco reputacional do estabelecimento (dano à imagem de pessoa jurídica é indenizável no Brasil) com a nova exposição pós-STF sobre o art. 19 do MCI. Exige validação cruzada por chave de NFC-e e detecção de outlier antes de publicar.
- Sigilo fiscal como bloqueio de bootstrap: a estratégia de popular a base rapidamente via microdados de NFC-e de terceiros provavelmente é inviável juridicamente, e descobrir isso tarde compromete o plano de produto. O caminho de convênio com SEFAZ é lento e político, não técnico — deve entrar no cronograma como trilha paralela de longo prazo, não como dependência de lançamento.
- Republicação de encarte por caminho indireto: mesmo com a política de 'não guardar a arte', é comum um dev implementar preview/thumbnail do PDF enviado, ou cache de imagem para revisão de admin. Isso reintroduz a reprodução da obra protegida pela porta dos fundos. Precisa de teste automatizado que falhe se qualquer artefato derivado do encarte persistir além do processamento.
- Retenção por acúmulo silencioso: buckets S3 sem lifecycle rule, backups de banco com PII, logs de aplicação que registram o payload do OCR, e a fila assíncrona (Redis/broker) que retém mensagens com dados brutos. A política de retenção só é real se estiver aplicada nos 5 lugares, e o broker é o mais esquecido.
- Não confirmei o teor da Nota Técnica NT 6/2025 da ANPD sobre coleta de CPF no varejo (o PDF não retornou conteúdo). Se ela contiver entendimento restritivo sobre CPF em documento fiscal, pode haver requisito adicional não capturado aqui.

## EM ABERTO
- Qual é o teor efetivo da Nota Técnica ANPD NT 6/2025 (SEI 00261.001371/2023-32, publicada em 13/02/2025)? Não consegui extrair o PDF. Precisa ser lida antes de fechar a política de CPF — pode conter determinações aplicáveis por analogia ao varejo.
- Qual a data exata do julgamento e o texto final da tese fixada pelo STF nos Temas 987 (RE 1.037.396) e 533 (RE 1.057.258)? O regime de responsabilidade por conteúdo de terceiro determina o desenho do notice-and-takedown, e eu confirmei apenas a inconstitucionalidade parcial, não a redação da tese.
- Existe API pública oficial do Menor Preço Brasil / SVRS, ou o acesso é exclusivamente por convênio entre entes federativos? Não localizei documentação de desenvolvedor. Se houver via legítima de acesso programático, muda completamente a estratégia de bootstrap da base.
- O CTN art. 198 (sigilo fiscal) foi verificado apenas por referência doutrinária indireta, não na fonte primária. Confirmar o texto e checar se há exceção que permita a ente privado obter dados de preço agregados por estabelecimento.
- Qual a janela temporal de preços praticada pelos apps estaduais de Menor Preço (3 dias? 10 dias? 30 dias?)? Não consegui recuperar esse parâmetro. É a melhor referência disponível para calibrar o corte de staleness do melhor_mercado e sustentar que a escolha é razoável.
- A empresa se enquadra hoje em microempresa/EPP (LC 123/2006) ou startup (LC 182/2021)? A resposta define se o SLA é 15 ou 30 dias e se o encarregado é obrigatório — mas a recomendação é implementar 15 dias independentemente.
- O app terá usuários menores de 18 anos? Se sim, o Enunciado ANPD nº 1, de 22/05/2023 e o art. 14 da LGPD entram, o melhor interesse da criança precisa ser demonstrado no teste de balanceamento, e o tratamento vira alto risco com RIPD obrigatório.
- Haverá monetização por publicidade, venda de insights de mercado a indústria/varejo, ou lead para os próprios supermercados? Cada uma dessas é uma finalidade NOVA que exige teste de balanceamento próprio e provavelmente base legal diferente — e a venda de insights é a que mais tensiona o legítimo interesse.
- O admin importará encartes de 'fontes oficiais' — quais exatamente? Se for feed/API autorizado pelo varejista, o risco autoral cai a quase zero; se for download de PDF do site público do varejista, mantém-se o risco sobre a arte e aplica-se a política de extrair-e-descartar.


################################################################
# TOPICO: Publicação e operação na Google Play (e implicações iOS) em 2026-07-22 para o app melhor_mercado (Flutter, UGC de fotos de cupom, localização, conta de usuário)
################################################################

## RESUMO EXECUTIVO
Em 22/07/2026 o caminho de publicação está mais estreito do que em anos anteriores e três prazos batem diretamente no cronograma do melhor_mercado. (1) A partir de 31/08/2026 novos apps e updates precisam de targetSdk 36 (Android 16) — logo, nasça já em 36; extensão possível só até 01/11/2026. (2) Desde 01/11/2025, qualquer app com código nativo alvo de API 35+ precisa suportar páginas de 16 KB — Flutter empacota libflutter.so/libapp.so, então o risco real são plugins nativos de terceiros (ML Kit, TFLite, sqlite3, zxing, ffmpeg). (3) O Brasil está na PRIMEIRA onda do Android developer verification: a partir de 30/09/2026 apps não registrados no Play Console ficam indisponíveis para nova instalação em dispositivos Android certificados no BR (7 lojas, incluindo Google Play, Galaxy Store, OPPO, HONOR, Palm, V-Appstore, GetApps). Do lado de produto, fotos de cupom enviadas por usuários e visíveis a terceiros SÃO User Generated Content pela definição do Google, o que obriga: aceite de termos antes do upload, definição de conteúdo censurável, moderação contínua, denúncia in-app de conteúdo E de usuário, e bloqueio de usuário. Exclusão de conta exige DOIS caminhos: in-app proeminente e uma URL web pública que funcione sem o app. Sobre permissões, a arquitetura deve nascer minimalista: zero READ_MEDIA_IMAGES (usar Android photo picker), zero ACCESS_BACKGROUND_LOCATION, e preferir ACCESS_COARSE_LOCATION — porque desde 15/04/2026 o "location button" virou escopo mínimo para localização precisa transacional, com enforcement previsto para fins de outubro/2026 em apps targetSdk 37. Por fim: use conta de ORGANIZAÇÃO (CNPJ + D-U-N-S) e não pessoal, para evitar o gargalo de 12 testadores por 14 dias corridos antes de liberar produção.

## ACHADOS

### [confirmada] A partir de 31/08/2026, novos apps e updates na Google Play devem ter targetSdkVersion >= 36 (Android 16)
Texto oficial: 'Starting August 31, 2026 ... new apps and app updates must target Android 16 (API level 36) or higher'. Exceções: Wear OS e Android Automotive OS = API 35+; Android TV e Android XR = API 34+. Extensão solicitável até 01/11/2026. Apps permanentemente privados (distribuição interna a uma organização) são isentos. Decisão para melhor_mercado: nascer com compileSdk=36 e targetSdk=36 já no primeiro AAB, evitando um segundo ciclo de compatibilidade em ~40 dias.
FONTE: https://developer.android.com/google/play/requirements/target-sdk

### [confirmada] Apps existentes precisam de targetSdk >= 35 para continuar disponíveis a NOVOS usuários em dispositivos com Android mais novo que o target
Apps com target API 34 ou menor 'will only be available on devices running Android OS that are the same or lower than the app's target API level'. Ou seja, o app não some da Play, mas fica invisível para novos aparelhos. Consequência prática: nunca deixar o targetSdk envelhecer mais de uma geração; incluir bump anual de targetSdk no roadmap de agosto de cada ano.
FONTE: https://developer.android.com/google/play/requirements/target-sdk

### [provavel] Hoje (22/07/2026), o piso vigente para novos envios ainda é targetSdk 35; o salto para 36 é em 31/08/2026
Inferência a partir da página oficial, que descreve API 35 como o piso de disponibilidade atual e API 36 como o requisito 'starting August 31, 2026'. NÃO confirmei uma página separada declarando explicitamente o requisito de 2025 (API 35). Recomendação neutraliza a dúvida: ir direto para 36.
FONTE: https://developer.android.com/google/play/requirements/target-sdk

### [confirmada] Requisito de 16 KB page size vale desde 01/11/2025 para apps com código nativo que miram Android 15+ (API 35+)
Texto oficial: 'Starting November 1st, 2025, all new apps and updates to existing apps submitted to Google Play and targeting Android 15+ devices must support 16 KB page sizes on 64-bit devices.' Como o melhor_mercado obrigatoriamente terá targetSdk >= 35, o requisito é inescapável.
FONTE: https://developer.android.com/guide/practices/page-sizes

### [confirmada] O que quebra sem 16 KB: rejeição no upload do Play e falha de instalação em dispositivos de 16 KB
Segmentos LOAD dos .so precisam de alinhamento >= 2**14 (16384 bytes). Ferramentas mínimas: AGP >= 8.5.1 (alinha bibliotecas descomprimidas por padrão) e NDK >= r28 (compila 16 KB-aligned por padrão). Para NDK r27 ou menor: '-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384'. Verificação: 'llvm-objdump -p LIB.so | grep LOAD' (valores 2**13/2**12 = não conforme) e 'zipalign -v -c -P 16 4 APP.apk'. Apps 100% Java/Kotlin (ou Dart puro sem plugin nativo) já são compatíveis.
FONTE: https://developer.android.com/guide/practices/page-sizes

### [provavel] Para Flutter, o engine já é 16 KB-aligned; o risco concentra-se nos plugins nativos de terceiros
libflutter.so e libapp.so vêm alinhados nas versões modernas do SDK (relatos consistentes apontam Flutter >= 3.32.x como seguro; o ambiente local tem 3.44.7, bem acima). Plugins de risco para este produto: google_mlkit_* / ML Kit, tflite_flutter, sqlite3_flutter_libs, opencv, ffmpeg_kit, mobile_scanner (usa ZXing/MLKit nativo), qualquer SDK de OCR on-device. Ação: rodar APK Analyzer e conferir a coluna Alignment de TODOS os .so em lib/arm64-v8a. Confiança 'provavel' porque a correlação versão-do-Flutter -> alinhamento veio de fontes secundárias (Medium/DEV), não do changelog oficial do Flutter.
FONTE: https://developer.android.com/guide/practices/page-sizes

### [confirmada] Exclusão de conta exige DOIS caminhos: in-app e uma URL web pública
O Google exige (a) 'an in-app path to delete their app accounts and associated data', proeminente (ex.: dentro das configurações de conta), e (b) 'a web link resource where users can request app account deletion and associated data deletion'. A URL web precisa: carregar sem erro; ter o caminho de exclusão proeminente e fácil de achar NA PRÓPRIA PÁGINA; referenciar o nome do app ou do desenvolvedor exatamente como aparece na ficha da loja; e permitir concluir o pedido SEM redirecionar o usuário de volta para o app. Declaração no Play Console: App content -> Data safety -> Data deletion questions.
FONTE: https://support.google.com/googleplay/android-developer/answer/13327111

### [confirmada] A exclusão deve apagar todos os dados declarados como coletados no Data safety; retenção só com base legal e com aviso explícito
Deve apagar 'all user data indicated as collected in your data safety section' (dados pessoais, financeiros, autenticação, localização, saúde, uso do dispositivo). Pode reter 'for legitimate reasons such as security, fraud prevention or regulatory compliance', mas é obrigatório 'clearly inform users about your data retention practices, for example, within your privacy policy'. Implicação de arquitetura: separar contribuicao_preco (fato de mercado, anonimizável) de upload_bruto (foto do cupom = dado do usuário, deve ser destruída). Modelar contributor_id como chave surrogate para permitir tombstone/anonimização em vez de cascade delete que destruiria o histórico de preços.
FONTE: https://support.google.com/googleplay/android-developer/answer/13327111

### [confirmada] Fotos de cupom enviadas por usuários SÃO User Generated Content pela definição do Google
Definição oficial de UGC: 'Content that users contribute to an app, and which is visible to or accessible by at least a subset of the app's users.' Preço contribuído + foto + comentário sobre o mercado se encaixam. Mesmo que a imagem crua nunca seja exibida, o preço extraído contribuído por um usuário e exibido a outros já é UGC.
FONTE: https://support.google.com/googleplay/android-developer/answer/9876937

### [confirmada] Obrigações de UGC: aceite de termos antes do upload, definição de conteúdo censurável, moderação, denúncia in-app e bloqueio de usuário
A política exige literalmente: 'Requires users accept the app's terms of use and/or user policy before users can create or upload UGC'; 'Defines objectionable content and behaviors ... and prohibits them'; 'Conducts UGC moderation, as is reasonable and consistent with the type of UGC hosted'. Tier aplicável ao melhor_mercado: apps que dão acesso a UGC publicamente acessível 'must implement in-app functionality to report users and content, and to block users' — ou seja, DENÚNCIA (de conteúdo e de usuário) E BLOQUEIO, ambos. Exige também salvaguardas para que a monetização in-app não incentive comportamento censurável, e respostas corretas no questionário de content rating sobre presença de UGC.
FONTE: https://support.google.com/googleplay/android-developer/answer/9876937

### [confirmada] Data safety: categorias e tipos exatos que o melhor_mercado terá de declarar
Location -> Approximate location (área >= 3 km2) e/ou Precise location (< 3 km2). Personal info -> Email address, User IDs, Name. Financial info -> Purchase history (ARMADILHA: itens de cupom vinculados à conta = histórico de compra). Photos and videos -> Photos. App activity -> Other user-generated content (contribuições de preço). Device or other IDs -> Device or other IDs (Firebase/FCM/Crashlytics). App info and performance -> Crash logs, Diagnostics. Por tipo declara-se: coletado e/ou compartilhado; efêmero ou não; obrigatório ou opcional; e finalidades entre App functionality, Analytics, Developer communications, Advertising or marketing, Fraud prevention/security/compliance, Personalization, Account management.
FONTE: https://support.google.com/googleplay/android-developer/answer/10787469

### [confirmada] Processamento 'efêmero' dispensa declaração, mas só se o dado ficar apenas em memória
Definição oficial: 'accessing and using it while data is only stored in memory and retained for no longer than necessary to service the specific request'. Se a foto do cupom for gravada em S3/MinIO para OCR assíncrono, NÃO é efêmera e deve ser declarada. Se você fizer OCR síncrono em memória e descartar, pode ser efêmera — mas isso conflita com fila assíncrona. Também obrigatório declarar: 'Data is encrypted in transit' (Sim, TLS) e 'Users can request that data be deleted' (Sim). Badge opcional: Independent security review (MASA / OWASP MASVS).
FONTE: https://support.google.com/googleplay/android-developer/answer/10787469

### [confirmada] Política de fotos: READ_MEDIA_IMAGES/READ_MEDIA_VIDEO só para quem tem necessidade ampla e persistente; uso pontual deve usar o Android photo picker
'Only apps with a need for broad access to photos will be allowed to maintain the READ_MEDIA_IMAGES and READ_MEDIA_VIDEO permissions. Apps with a one-time or limited use ... are requested to use a system picker such as the Android photo picker.' Broad access exige access review + demonstração de caso de uso core. O photo picker 'integrates into your app without requiring you to acquire additional photo or video storage permissions'. Prazo de conformidade foi 22/01/2025, com extensão até 28/05/2025 — ambos já vencidos. Decisão: melhor_mercado declara ZERO permissões de mídia.
FONTE: https://support.google.com/googleplay/android-developer/answer/14115180

### [confirmada] Android 14+ tem acesso parcial a fotos via READ_MEDIA_VISUAL_USER_SELECTED, com grant temporário por sessão
Se o usuário escolhe 'Select photos and videos', as permissões são concedidas apenas durante a sessão do app; quando o app vai para background ou é morto, 'the system eventually denies these permissions'. Isso quebra qualquer suposição de acesso persistente ao arquivo — outra razão para copiar o byte stream imediatamente e não guardar content:// URIs.
FONTE: https://developer.android.com/about/versions/14/changes/partial-photo-video-access

### [confirmada] Localização: escopo mínimo obrigatório, background exige declaração no Console e é vetor forte de rejeição
Política: 'should request the minimum scope necessary (for example, coarse instead of fine, and foreground instead of background)'. Sobre background: 'we may reject apps that request or access background location without compelling justification' e é obrigatório 'Complete the Console declaration for background location'. Proibido usar localização 'solely for advertising or analytics purposes'. Permissões que exigem Declaration Form: background location, SMS/Call Log, QUERY_ALL_PACKAGES, MANAGE_EXTERNAL_STORAGE, REQUEST_INSTALL_PACKAGES, AccessibilityService API.
FONTE: https://support.google.com/googleplay/android-developer/answer/13986130

### [confirmada] Desde 15/04/2026 o 'location button' é o escopo mínimo para localização precisa transacional; enforcement previsto para fins de outubro/2026
Para apps com targetSdk 37 (Android 17), o location button é 'the required minimum scope method' para uso one-time. Casos que EXIGEM o botão: buscar lojas/restaurantes próximos, compartilhar localização uma vez, taggear UGC com localização, autofill de endereço — exatamente os casos do melhor_mercado. Casos isentos (podem manter ACCESS_FINE_LOCATION persistente): navegação turn-by-turn, fitness tracking ao vivo, monitoramento contínuo com app visível. Data efetiva citada: 28/10/2026, enforcement 'late October 2026'.
FONTE: https://support.google.com/googleplay/android-developer/answer/17033915

### [provavel] Location button: API é Compose-only hoje, o que é um problema direto para Flutter
Introduzido no Android 17 (API 37). Artefato: 'androidx.core:core-locationbutton:1.0.0-alpha01', classe androidx.core.locationbutton.compose.LocationButton (composable). Manifesto: <uses-permission android:name="android.permission.USE_LOCATION_BUTTON" /> e, para restringir acesso ao botão, ACCESS_FINE_LOCATION com android:usesPermissionFlags="onlyForLocationButton". A lib Jetpack faz fallback automático em Android 16 e inferior. Status: 'Experimental library subject to change'. Impacto Flutter: exigirá AndroidView/PlatformView hospedando um ComposeView, ou plugin próprio. Confiança 'provavel' quanto ao caminho de integração em Flutter — isso é inferência minha, não há guia oficial Flutter.
FONTE: https://developer.android.com/guide/topics/permissions/private-alternatives/location-button

### [confirmada] Prominent disclosure é obrigatória e tem forma prescrita: tela in-app imediatamente antes do runtime permission
Deve descrever o dado acessado, como será usado e/ou compartilhado; deve estar DENTRO do app (não só na descrição da loja ou site); deve aparecer no uso normal, sem exigir navegar até menus/configurações; NÃO pode estar apenas na política de privacidade ou nos termos; não pode ser misturada com outras divulgações não relacionadas. O consentimento exige ação afirmativa (tap para aceitar, checkbox). Para localização, a disclosure deve preceder o prompt de runtime e dizer QUAIS features usarão a localização.
FONTE: https://support.google.com/googleplay/android-developer/answer/11150561

### [confirmada] Contas pessoais novas: 12 testadores em closed testing, opt-in contínuo por 14 dias, antes de pedir acesso a produção
'At least 12 testers must be opted-in to your closed test when you apply for production access. They must have been opted-in for the last 14 days continuously.' Os 14 dias precisam ser CONSECUTIVOS: 'We won't count testers who opted in, tested for less than 14 days, and then opted out.' Aplica-se a contas pessoais criadas após 13/11/2023 (regra original era 20 testadores; reduzida para 12 em dezembro/2024). Fluxo: Dashboard -> 'Apply for production' -> 3 seções de perguntas -> análise tipicamente em até 7 dias.
FONTE: https://support.google.com/googleplay/android-developer/answer/14151465

### [confirmada] AAB obrigatório para apps novos desde agosto/2021; Play App Signing acoplado; limites de tamanho generosos
Novos apps só entram como Android App Bundle. Chave de upload: RSA >= 2048 bits, keystore .jks/.keystore. Chave de assinatura gerada pelo Google: RSA 4096; chave própria enviada: RSA >= 2048. Rotação: 'annual key upgrade for all installs on Android N (API level 24) and above'. Limites (download comprimido, calculado pelo Play no upload): base module 500 MB; cada feature module 500 MB; cada asset pack 1.5 GB; todos os módulos + install-time asset packs 4 GB; on-demand/fast-follow 30 GB; total 34 GB; APK legado 100 MB. Máx. 100 feature modules (API 26+) e 100 asset packs. Um app Flutter típico deste porte fica em 15-35 MB — folga enorme.
FONTE: https://support.google.com/googleplay/android-developer/answer/9859372

### [provavel] Existe um limiar de 200 MB que dispara aviso de download em dados móveis (não é bloqueio)
Acima de 200 MB o usuário em rede móvel vê um diálogo não-bloqueante avisando do tamanho. Confiança 'provavel': número veio do resumo de busca, não do texto que consegui extrair da página primária (que traz 500 MB como limite do base module).
FONTE: https://support.google.com/googleplay/android-developer/answer/9859372

### [confirmada] Política de privacidade: URL ativa obrigatória na ficha da loja E link in-app quando há permissões sensíveis
Deve estar linkada 'on your app's store listing page and within your app' para apps que acessam permissões sensíveis ou miram crianças — melhor_mercado (câmera, fotos, localização) cai nessa regra. Deve 'comprehensively disclose how your app collects, uses, and shares user data. This includes the types of parties with whom it's shared', estar em 'an active URL', aplicar-se ao app e cobrir especificamente privacidade do usuário. Requisito de consistência: divergência entre política e Data safety é motivo de rejeição/remoção.
FONTE: https://support.google.com/googleplay/android-developer/answer/9859455

### [confirmada] Página 'App content' do Play Console: lista completa de declarações obrigatórias antes de publicar
Privacy policy (URL); Ads (contém anúncios? gera selo 'Contains ads'); App access / sign-in details (até 5 conjuntos de credenciais e instruções para o revisor e para o crawler do pre-launch report); Target audience and content (faixa etária; se mirar crianças, Families policy); Content ratings (questionário IARC — 'we don't allow unrated apps on Google Play', apps sem rating podem ser removidos; no Brasil o rating é ClassInd); Data safety; Permissions declaration (para permissões de alto risco); News/magazine apps; COVID-19 apps; Government apps; Financial features; Health apps.
FONTE: https://support.google.com/googleplay/android-developer/answer/9859455

### [confirmada] Pre-launch report roda automaticamente e cobre estabilidade, performance, acessibilidade, screenshots e compatibilidade
Testa: crashes, ANRs, bibliotecas defeituosas, APIs não suportadas; CPU, memória, rede, frame rate; acessibilidade (rótulos de conteúdo, tamanho de alvo de toque, layout, contraste de cor); screenshots por device e idioma; uso de interfaces não-SDK. Para apps com login (o caso), é preciso preencher App access com credenciais, senão o crawler não passa da tela de autenticação e o relatório fica vazio.
FONTE: https://support.google.com/googleplay/android-developer/answer/9844487

### [confirmada] Taxa de conta de desenvolvedor Google Play: US$ 25, cobrança única
'There is a US$25 one-time registration fee' pagável com MasterCard, Visa, American Express, Discover (só EUA), Visa Electron (fora dos EUA). Pode ser exigido documento de identidade governamental válido e cartão de crédito, ambos no nome legal do titular.
FONTE: https://support.google.com/googleplay/android-developer/answer/6112435

### [confirmada] Verificação de identidade: conta pessoal exige documento oficial; conta de organização exige D-U-N-S + documentos societários + ID do representante
Organização: número D-U-N-S de nove dígitos da Dun & Bradstreet (exceto órgão governamental), 2 tipos de documentação (registro da organização + foto de ID governamental de representante autorizado), e o nome legal e endereço no perfil de pagamentos do Google devem BATER com o perfil na Dun & Bradstreet. Endereço e nome vêm do Google Payments profile vinculado na criação da conta.
FONTE: https://support.google.com/googleplay/android-developer/answer/10841920

### [confirmada] CRÍTICO PARA O BRASIL: Android developer verification entra em vigor em 30/09/2026 e o Brasil está na primeira onda
A partir de 30/09/2026 a exigência vale em Brasil, Indonésia, Singapura e Tailândia, em 7 lojas: Google Play, HONOR App Market, OPPO App Market, Galaxy Store, Palm Store, V-Appstore e GetApps. Apps de desenvolvedores não verificados/não registrados ficam indisponíveis para nova instalação em dispositivos Android certificados nesses países. Marcos: junho/2026 rollout do system service; julho/2026 Android Developer ID Status API global; agosto/2026 contas de distribuição limitada globais; 2027 expansão global. Mais de 99% dos apps já na Play foram registrados automaticamente, MAS 'check your Play Console Home page to see your app's verification status'. Publicar na Play NÃO satisfaz automaticamente a verificação.
FONTE: https://android-developers.googleblog.com/2026/06/android-developer-verification.html

### [confirmada] Existe uma conta gratuita de 'limited distribution' limitada a 20 dispositivos, útil para beta interno via sideload
Para 'students, hobbyists, and learners': permite distribuir para até 20 dispositivos autorizados explicitamente pelos usuários finais, sem ID governamental e sem taxa. Não serve para produção. Registro de pacote exige provar posse fornecendo APK assinado com a chave privada. Apps não registrados ainda podem ser instalados via adb ou 'advanced flow' para power users.
FONTE: https://developer.android.com/developer-verification

### [confirmada] Brasil: Digital ECA obriga ingestão de faixa etária das lojas; Play Age Signals API (beta) é o mecanismo
Apps direcionados a — ou provavelmente acessados por — crianças e adolescentes devem 'ingest age range data from app stores'. A partir de março/2026 o Google Play, para usuários identificados como menores no Brasil, bloqueia aquisição/compra de conteúdo maduro (apps 18+) e filtra esse conteúdo de busca e navegação, exceto por deep link. Jogos voltados a menores não podem ter loot boxes. Para vender (merchant) no Brasil: nome e endereço da empresa, beneficiários finais com >25%, executivos/representantes, validação de endereço, CPF e CNPJ.
FONTE: https://support.google.com/googleplay/android-developer/answer/6223646

### [confirmada] Anúncio de política de 15/04/2026: Contact Picker obrigatório, geofencing removido de foreground service, location button como escopo mínimo
Prazo geral de conformidade: 30 dias a partir de 15/04/2026 (ou seja, 15/05/2026). Mudanças: apps que acessam contatos devem usar o Android Contact Picker em vez de acesso amplo; geofencing deixa de ser caso de uso aprovado para foreground services (usar a Geofence API oficial); location button passa a ser o escopo mínimo recomendado para localização precisa; transferência de conta de desenvolvedor deve usar o fluxo oficial 'Transfer ownership' do Play Console.
FONTE: https://support.google.com/googleplay/android-developer/answer/16926792

### [confirmada] Anúncio de política de 15/07/2026: registro obrigatório de TODOS os apps no Play Console, sob pena de remoção global
Conformidade em 30 dias (14/08/2026). 'All Play apps must be registered in Play Console', valendo para apps distribuídos pela Play ou fora dela em dispositivos Android certificados; apps não registrados enfrentam remoção global da Google Play. Também: READ_CALL_LOG deixa de ser permitido para verificação de conta por chamada telefônica (alternativas: Digital Credentials API, SMS Retriever API); novas restrições de chat anônimo para menores; esclarecimento de que apps sem classificação (unrated) não são permitidos.
FONTE: https://support.google.com/googleplay/android-developer/answer/17134731

### [confirmada] iOS: exclusão de conta deve ser INICIADA dentro do app desde 30/06/2022 (guideline 5.1.1(v))
'apps submitted to the App Store that support account creation must also let users initiate deletion of their account within the app'. Pode-se finalizar na web, mas é obrigatório 'include a link directly to the page on your website where they can complete the process' (deep link para a página exata, não para a home). Desativação temporária NÃO basta. Deve apagar 'all data associated with the account ... including user-generated content that's shared with others, such as photos, video, text posts, and reviews'. Apps fora de setores altamente regulados 'should not require people to make a phone call, send an email, or go through other support flows'. Vale globalmente, não só GDPR/CCPA.
FONTE: https://developer.apple.com/support/offering-account-deletion-in-your-app/

### [confirmada] iOS: guideline 1.2 exige FILTRO PRÉ-PUBLICAÇÃO de conteúdo censurável, mais rígido que o Google
Apps com UGC devem incluir: 'A method for filtering objectionable material from being posted to the app'; 'A mechanism to report offensive content and timely responses to concerns'; 'The ability to block abusive users from the service'; 'Published contact information so users can easily reach you'. Comportamento 'egregious or repeated' é motivo de remoção imediata do app E do Apple Developer Program. Implicação de arquitetura AGORA: o pipeline de moderação precisa de um estágio automático que bloqueia publicação (não apenas remoção reativa).
FONTE: https://developer.apple.com/app-store/review/guidelines/

### [confirmada] iOS: privacy manifest PrivacyInfo.xcprivacy com 4 chaves; SDKs de terceiros com impacto em privacidade precisam de manifest assinado desde 12/02/2025
Arquivo PrivacyInfo.xcprivacy (plist XML) por target. Chaves: NSPrivacyTracking (bool), NSPrivacyTrackingDomains (array), NSPrivacyCollectedDataTypes, NSPrivacyAccessedAPITypes. Categorias de required-reason API: file timestamp, system boot time, disk space, active keyboard, user defaults. Desde 01/05/2024 é preciso declarar razões aprovadas para essas APIs ao enviar app novo ou update. Desde 12/02/2025, se o app novo (ou um update) incluir um SDK da lista de 'privacy-impacting SDKs', esse SDK deve trazer privacy manifest e assinatura. O manifest do app não precisa cobrir dados coletados por SDKs de terceiros linkados — cada SDK traz o seu.
FONTE: https://developer.apple.com/support/third-party-SDK-requirements/

### [confirmada] iOS: ATT só é exigido se houver tracking; e é proibido condicionar funcionalidade à concessão de permissões
5.1.2(i): 'You must receive explicit permission from users via the App Tracking Transparency APIs to track their activity'; e 'Your app may not require users to enable system functionalities (e.g. push notifications, location services, tracking) in order to access functionality, content, use the app, or receive monetary or other compensation'. 5.1.1(ii) exige consentimento para coleta e um caminho acessível para RETIRAR o consentimento, e 'Ensure your purpose strings clearly and completely describe your use of the data'. Decisão recomendada: não fazer tracking cross-app -> sem prompt ATT, sem IDFA, sem NSPrivacyTracking=true.
FONTE: https://developer.apple.com/app-store/review/guidelines/

## ESPECIFICACOES CONCRETAS
- targetSdkVersion / compileSdkVersion = 36 (Android 16). Prazo: 31/08/2026 para novos apps e updates; extensão possível até 01/11/2026.
- targetSdk 35 (Android 15) = piso para permanecer disponível a novos usuários em devices mais novos.
- Alinhamento ELF exigido para 16 KB: segmentos LOAD com align >= 2**14 (16384 bytes). Verificação: llvm-objdump -p LIB.so | grep LOAD; zipalign -v -c -P 16 4 APP.apk.
- AGP >= 8.5.1 e Android NDK >= r28 para alinhamento 16 KB automático. Para NDK <= r27: -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384.
- Fallback AGP <= 8.5: android { packagingOptions { jniLibs { useLegacyPackaging = true } } }.
- Closed testing conta pessoal: exatamente 12 testadores, opt-in contínuo por 14 dias CONSECUTIVOS; análise de acesso a produção tipicamente até 7 dias. Regra vale para contas pessoais criadas após 13/11/2023.
- Taxa Google Play Console: US$ 25, cobrança única. Cartões aceitos: MasterCard, Visa, Amex, Discover (só EUA), Visa Electron (fora dos EUA).
- Conta de organização: D-U-N-S de 9 dígitos (Dun & Bradstreet) + documento de registro da organização + ID com foto de representante autorizado; nome legal e endereço devem coincidir entre Google Payments profile e perfil D&B.
- Chave de upload: RSA >= 2048 bits, keystore .jks ou .keystore. Chave de assinatura gerada pelo Google: RSA 4096. Chave própria enviada: RSA >= 2048.
- Limites de tamanho (download comprimido): base module 500 MB; feature module 500 MB cada; asset pack 1.5 GB cada; módulos + install-time asset packs 4 GB; on-demand/fast-follow 30 GB; total 34 GB; APK legado 100 MB; máx. 100 feature modules (API 26+) e 100 asset packs.
- Data safety — Location: 'Approximate location' = área >= 3 km2; 'Precise location' = área < 3 km2.
- Data safety — finalidades selecionáveis: App functionality, Analytics, Developer communications, Advertising or marketing, Fraud prevention security and compliance, Personalization, Account management.
- Data safety — categorias relevantes ao melhor_mercado: Location (Approximate/Precise); Personal info (Name, Email address, User IDs); Financial info (Purchase history); Photos and videos (Photos); App activity (Other user-generated content); Device or other IDs; App info and performance (Crash logs, Diagnostics).
- Location button: artefato androidx.core:core-locationbutton:1.0.0-alpha01; classe androidx.core.locationbutton.compose.LocationButton; permissão android.permission.USE_LOCATION_BUTTON obrigatória; flag android:usesPermissionFlags="onlyForLocationButton" em ACCESS_FINE_LOCATION; introduzido no Android 17 (API 37); enforcement previsto 28/10/2026 / 'late October 2026'.
- Android photo picker: dispensa READ_MEDIA_IMAGES e READ_MEDIA_VIDEO. Acesso parcial no Android 14+ usa READ_MEDIA_VISUAL_USER_SELECTED com concessão apenas durante a sessão (revogada quando o app vai a background ou é morto).
- Permissões que exigem Declaration Form no Play Console: ACCESS_BACKGROUND_LOCATION, SMS/Call Log, QUERY_ALL_PACKAGES, MANAGE_EXTERNAL_STORAGE, REQUEST_INSTALL_PACKAGES, AccessibilityService API.
- URL de exclusão de conta: precisa carregar sem erro, ter o caminho de exclusão proeminente na própria página, referenciar o nome do app ou do desenvolvedor exatamente como na ficha da loja, e permitir concluir sem redirecionar de volta ao app. Declarada em App content > Data safety > Data deletion.
- App access: até 5 conjuntos de credenciais/instruções para revisor e crawler.
- Android developer verification: enforcement 30/09/2026 em Brasil, Indonésia, Singapura, Tailândia; 7 lojas (Google Play, HONOR App Market, OPPO App Market, Galaxy Store, Palm Store, V-Appstore, GetApps); expansão global em 2027; conta gratuita 'limited distribution' = até 20 dispositivos, sem ID governamental e sem taxa.
- Anúncio de política 15/07/2026: conformidade até 14/08/2026; registro obrigatório de todos os apps no Play Console sob pena de remoção global.
- Anúncio de política 15/04/2026: conformidade até 15/05/2026; Contact Picker obrigatório; geofencing removido dos casos aprovados de foreground service.
- iOS: PrivacyInfo.xcprivacy (plist), chaves NSPrivacyTracking, NSPrivacyTrackingDomains, NSPrivacyCollectedDataTypes, NSPrivacyAccessedAPITypes. Categorias de required-reason API: file timestamp, system boot time, disk space, active keyboard, user defaults. Declaração exigida desde 01/05/2024; SDKs de terceiros com manifest assinado desde 12/02/2025.
- iOS: exclusão de conta obrigatória desde 30/06/2022 (guideline 5.1.1(v)); iniciação in-app obrigatória; link direto para a página exata de conclusão na web quando aplicável.
- App Links: assetlinks.json em https://<dominio>/.well-known/assetlinks.json com SHA-256 do certificado de assinatura do GOOGLE (Play App Signing), não da upload key; android:autoVerify="true".
- Brasil merchant: CPF e CNPJ, beneficiários finais com participação > 25%, executivos/representantes autorizados, validação de endereço.

## RECOMENDACOES
- Nascer em targetSdk 36 / compileSdk 36 no primeiro AAB. O prazo de 31/08/2026 está a ~40 dias; subir em 35 significa refazer o ciclo de compatibilidade imediatamente. Registrar no CI um gate que falha o build se targetSdk < 36.
- Abrir conta de ORGANIZAÇÃO (CNPJ + D-U-N-S) em vez de conta pessoal. Isso (a) evita o gargalo documentado de 12 testadores por 14 dias corridos que se aplica a contas pessoais criadas após 13/11/2023, e (b) já resolve a verificação de identidade exigida no Brasil. Solicitar o D-U-N-S com semanas de antecedência — nome legal e endereço no perfil de pagamentos do Google precisam bater exatamente com a Dun & Bradstreet.
- Tratar 30/09/2026 (developer verification, Brasil na primeira onda) como marco de release hard. Conferir a Play Console Home e garantir que o package name br.com.<algo>.melhormercado esteja registrado e verificado antes dessa data, sob pena de o app ficar indisponível para nova instalação em aparelhos certificados no Brasil.
- Permissões Android — declarar exatamente: CAMERA (para leitura do QR Code da NFC-e), ACCESS_COARSE_LOCATION, INTERNET, POST_NOTIFICATIONS. Nada mais. Auditar o AndroidManifest MERGEADO (./gradlew :app:processReleaseManifest e inspecionar app/build/intermediates/merged_manifests/) porque plugins Flutter injetam permissões silenciosamente; remover com <uses-permission android:name="..." tools:node="remove" />.
- Zero permissões de mídia: usar o Android photo picker (image_picker no Flutter já delega ao picker em Android 13+) para escolher fotos existentes, e ACTION_IMAGE_CAPTURE/câmera in-app para capturar novas. Isso elimina READ_MEDIA_IMAGES, READ_MEDIA_VIDEO, READ_MEDIA_VISUAL_USER_SELECTED e o access review associado.
- Localização: implementar tier 1 = CEP digitado pelo usuário (zero permissão); tier 2 = ACCESS_COARSE_LOCATION com prominent disclosure. Só considerar precisa se a métrica de produto provar que coarse (>= 3 km2) degrada o ranking de mercados próximos — e, nesse caso, planejar o location button (androidx.core:core-locationbutton) antes de subir para targetSdk 37.
- Construir o pipeline de moderação como requisito de arquitetura de dia 1, não como backlog: (a) aceite versionado dos Termos de Uso antes do primeiro upload de UGC, com registro de user_id + termos_version + timestamp + IP; (b) fila de moderação automática pré-publicação (detecção de PII na imagem, NSFW, duplicata por perceptual hash, outlier de preço estatístico); (c) denúncia in-app de CONTEÚDO e de USUÁRIO; (d) bloqueio de usuário (filtra contribuições daquele contribuidor para quem bloqueou); (e) console admin com ações take-down, shadow-ban e ban.
- NUNCA servir a imagem crua do cupom a outros usuários. Cupom fiscal brasileiro carrega CPF na nota, nome, endereço e às vezes final do cartão. Arquitetura: bucket S3 privado com objetos de imagem original em ciclo de vida curto (ex.: expirar em 30-90 dias após extração bem-sucedida), acesso só por URL pré-assinada e só para o próprio autor e para admins; publicamente expor apenas os campos estruturados (produto, preço, loja, data, GTIN).
- Implementar um serviço único de exclusão de conta que atenda Google, Apple e LGPD de uma vez: endpoint DELETE /v1/me disparando job assíncrono que (1) apaga PII e credenciais, (2) apaga objetos de imagem no S3, (3) anonimiza contributor_id nas linhas de preço para um tombstone, (4) grava log de auditoria imutável. Expor: caminho in-app proeminente em Configurações > Conta > Excluir conta, e página web pública (ex.: https://melhormercado.app/excluir-conta) que carrega sem erro, cita o nome do app como na ficha da loja, e permite concluir o pedido sem voltar ao app.
- Modelar desde já a separação entre dado-do-usuário e fato-de-mercado. Um preço observado em uma loja é um fato de mercado; a foto e o vínculo com quem enviou são dados do usuário. Sem essa separação, a exclusão de conta obriga a destruir o histórico de preços — que é o ativo do produto.
- Preencher App access no Play Console com credenciais de conta de teste (até 5 conjuntos) e instruções passo a passo, incluindo como pular o onboarding de localização. Sem isso o pre-launch report não passa do login e o revisor humano rejeita por 'não conseguimos acessar'.
- Sobre 'Purchase history' no Data safety: decidir explicitamente se os itens do cupom ficam vinculados à conta. Se ficarem, declarar Financial info > Purchase history (categoria sensível, aumenta escrutínio). Alternativa arquitetural: gravar a contribuição com contributor_id surrogate e não manter tabela 'minhas compras' por padrão, oferecendo-a como opt-in explícito.
- Escrever a política de privacidade DEPOIS de preencher o Data safety e derivá-la do mesmo inventário de dados, para garantir consistência campo a campo. Deve conter: identidade legal e CNPJ do controlador, contato do encarregado/DPO, tipos de dados por categoria (espelhando o Data safety), finalidades, bases legais LGPD, subprocessadores (provedor de OCR, cloud, analytics), transferências internacionais, prazos de retenção, mecanismo de exclusão e a URL de exclusão de conta.
- Build de release: R8 full mode + shrinkResources, flutter build appbundle --obfuscate --split-debug-info=build/symbols, upload do mapping.txt no Play Console e dos símbolos Dart no serviço de crash. Manter keep rules para modelos serializados e para SDKs nativos (ML Kit em especial).
- App Links verificados: android:autoVerify="true" no intent-filter e assetlinks.json publicado em https://<dominio>/.well-known/assetlinks.json com o SHA-256 da CHAVE DE ASSINATURA DO GOOGLE (Play App Signing), não da upload key — erro clássico que faz o deep link cair no browser.
- iOS agora, mesmo sem lançar: reservar bundle id, escrever purpose strings honestas (NSCameraUsageDescription, NSLocationWhenInUseUsageDescription), planejar PHPickerViewController para evitar NSPhotoLibraryUsageDescription, e manter uma planilha de SDKs/pods com o status de privacy manifest assinado. Não adotar SDK de terceiro sem verificar se ele publica PrivacyInfo.xcprivacy assinado.
- Executar checklist de acessibilidade antes do primeiro closed test, porque o pre-launch report reporta: alvos de toque >= 48dp, Semantics/label em todo widget interativo do Flutter, contraste >= 4.5:1, suporte a escala de fonte do sistema sem overflow.
- Rodar verificação de 16 KB no CI: unzip do AAB/APK e llvm-objdump -p em cada .so de lib/arm64-v8a checando 'align 2**14' ou superior, mais zipalign -c -P 16 -v 4. Fazer isso a cada adição de plugin Flutter, não só no lançamento.

## NAO FAZER
- NÃO declarar ACCESS_BACKGROUND_LOCATION. Não há caso de uso legítimo para um buscador de preços, exige Console declaration + análise com vídeo demonstrativo, e a política diz explicitamente que apps podem ser rejeitados por pedir background location sem justificativa convincente.
- NÃO declarar READ_MEDIA_IMAGES / READ_MEDIA_VIDEO. Uso pontual (enviar foto de um cupom) é exatamente o cenário que a política manda resolver com o Android photo picker; declarar essas permissões dispara access review e cria risco de rejeição por escopo excessivo.
- NÃO declarar MANAGE_EXTERNAL_STORAGE, QUERY_ALL_PACKAGES, READ_CONTACTS, READ_SMS nem READ_CALL_LOG. Todos exigem Declaration Form, e desde 15/07/2026 verificação de conta por chamada telefônica deixou de ser caso de uso aceito para READ_CALL_LOG.
- NÃO usar conta de desenvolvedor pessoal para este produto. O requisito de 12 testadores por 14 dias corridos adiciona semanas ao cronograma e é frágil (qualquer opt-out reinicia a contagem daquele testador).
- NÃO publicar APK. Novos apps só entram como Android App Bundle desde agosto/2021 — construir pipeline de release em torno de APK é retrabalho garantido.
- NÃO exibir a imagem original do cupom para outros usuários, nem gerar URL pública/permanente para ela. Só expor campos estruturados extraídos.
- NÃO implementar 'desativar conta' no lugar de 'excluir conta'. A Apple explicita que desativação temporária não satisfaz 5.1.1(v), e o Google exige exclusão dos dados declarados no Data safety.
- NÃO colocar a prominent disclosure apenas na política de privacidade, nos termos, na descrição da loja ou atrás de um menu de configurações. A política exige tela in-app, no fluxo normal, imediatamente antes do prompt de runtime, com ação afirmativa.
- NÃO projetar coleta de dados de encartes ou de portais fiscais que dependa de burlar CAPTCHA, autenticação, rate limit, robots.txt ou termos de uso — isso viola as políticas de Device and Network Abuse e Misrepresentation do Google, além de ser ilícito. Se um dado só for obtível por essa via, a decisão correta é NÃO coletá-lo. Alternativas legítimas: (a) processar o conteúdo do QR/DANFE que o próprio usuário possui, no dispositivo; (b) OCR do cupom físico enviado pelo usuário; (c) convênio/API oficial com a SEFAZ estadual ou programas oficiais de nota fiscal; (d) acordo comercial ou parceria direta com as redes varejistas para receber encartes; (e) fontes que publicam dados abertos com licença explícita.
- NÃO adicionar SDK de anúncios ou analytics de terceiros no MVP. Cada um adiciona linhas no Data safety, potencialmente aciona ATT no iOS, e traz Device IDs para a declaração — encarecendo compliance antes de haver receita.
- NÃO deixar o assetlinks.json com o SHA-256 da upload key. Com Play App Signing, o certificado que assina o APK entregue é o do Google; usar o hash errado quebra silenciosamente a verificação de App Links em produção.
- NÃO tratar moderação como funcionalidade pós-lançamento. A Apple exige explicitamente um método de FILTRAGEM que impeça a publicação de conteúdo censurável, o que é uma decisão de arquitetura de pipeline (estado 'pendente' antes de 'publicado'), não um recurso de admin adicionado depois.

## RISCOS
- RISCO ALTO — Vazamento de PII em foto de cupom. Cupom fiscal brasileiro pode conter CPF, nome, endereço e final de cartão. Se a imagem crua for exposta a outros usuários ou indexada, é simultaneamente violação da User Data policy do Google, violação da 1.2 da Apple e incidente LGPD com dever de notificação à ANPD.
- RISCO ALTO — Enquadramento como UGC dispara todo o pacote de moderação. Muitos times subestimam isso e lançam sem denúncia/bloqueio, levando a suspensão. A definição do Google ('conteúdo contribuído por usuários e visível a pelo menos um subconjunto dos usuários') captura o preço contribuído mesmo sem exibir a foto.
- RISCO ALTO — Prazo de 30/09/2026 do developer verification com o Brasil na primeira onda. Se o package name não estiver registrado e a conta verificada, o app fica indisponível para NOVA instalação em dispositivos certificados no Brasil, em 7 lojas. Verificação de organização depende de D-U-N-S de terceiro (Dun & Bradstreet), fora do seu controle de prazo.
- RISCO MÉDIO-ALTO — Gargalo dos 12 testadores por 14 dias corridos se a conta for pessoal. Um único testador que faz opt-out zera a contagem contínua dele. Some-se ~7 dias de análise do pedido de produção: são no mínimo 3 semanas entre 'app pronto' e 'app na produção'.
- RISCO MÉDIO-ALTO — Inconsistência entre Data safety, política de privacidade e comportamento real do app. É uma das causas mais comuns de remoção. Usar OCR de terceiro (Cloud Vision, Textract) sem declarar corretamente 'compartilhado' vs 'coletado' é o ponto mais escorregadio.
- RISCO MÉDIO — 16 KB page size quebrando por causa de um plugin. Um único .so desalinhado de um plugin transitivo faz o upload ser rejeitado. O prazo já passou (01/11/2025), então não há graça: a rejeição é imediata.
- RISCO MÉDIO — Escalada de escopo de localização. Se o produto exigir 'mercados num raio de 1 km', coarse (>= 3 km2) pode ser insuficiente, empurrando para ACCESS_FINE_LOCATION e, com targetSdk 37 a partir de fins de outubro/2026, para o location button — que hoje é uma lib alpha, Compose-only, sem caminho oficial em Flutter.
- RISCO MÉDIO — Declarar 'Purchase history' aumenta escrutínio e cria obrigação de exclusão mais pesada; não declarar quando os itens do cupom ficam vinculados à conta é falsa declaração.
- RISCO MÉDIO — Divergência entre as regras de exclusão de conta: o Google aceita que o caminho in-app seja um link para a web; a Apple exige INICIAÇÃO in-app e só permite finalizar na web com deep link para a página exata. Construir só para o Google gera retrabalho e rejeição na App Store.
- RISCO MÉDIO — Content rating (IARC/ClassInd) respondido sem marcar presença de UGC. O Google clarificou em 15/07/2026 que apps sem classificação não são permitidos, e resposta incorreta sobre UGC é motivo de reclassificação forçada ou remoção.
- RISCO BAIXO-MÉDIO — Digital ECA brasileiro: se o app for 'provavelmente acessado por' adolescentes (e um app de compras de supermercado plausivelmente é), pode incidir a obrigação de ingerir faixa etária das lojas via Play Age Signals API (beta). Precisa de avaliação jurídica.
- RISCO BAIXO — Tamanho do bundle não é preocupação real (limite de 500 MB no base module vs ~15-35 MB de um app Flutter), mas modelos de OCR on-device (ML Kit, TFLite) podem inflar rapidamente; se passar de ~200 MB, aparece aviso de dados móveis ao usuário.

## EM ABERTO
- Contas de ORGANIZAÇÃO estão de fato isentas da regra de 12 testadores/14 dias? A página oficial se chama 'App testing requirements for new personal developer accounts', o que sugere escopo restrito a contas pessoais, mas existem threads da comunidade pedindo clarificação para contas de organização. Não encontrei declaração oficial explícita de isenção. Verificar antes de fechar o cronograma.
- Qual a versão mínima do AGP necessária para compileSdk 36? Confirmei AGP >= 8.5.1 apenas para o alinhamento 16 KB. A versão de AGP compatível com compileSdk 36 não foi verificada nesta pesquisa e provavelmente é bem superior.
- A janela de extensão do requisito de 16 KB terminou em 31/05/2026? Fontes secundárias citam essa data, mas não consegui extrair o conteúdo do thread oficial. Como a data já passaria de qualquer forma (hoje é 22/07/2026), a questão é acadêmica para este projeto.
- Enviar a foto do cupom para um OCR de terceiro (Google Cloud Vision, AWS Textract, Azure Document Intelligence) conta como 'shared' no Data safety, ou como processamento por prestador de serviço (não-compartilhamento)? A definição do Google trata service providers de forma distinta, mas não confirmei o texto exato aplicável a este caso. Impacta diretamente a declaração — resolver antes de preencher o formulário.
- Contribuições de preço SEM imagem visível a terceiros já colocam o app no tier 'publicly accessible UGC' (report + block obrigatórios), ou apenas no tier de report? A leitura conservadora (implementar ambos) é a recomendada, mas vale confirmar com o Policy Support para dimensionar esforço.
- Existe caminho suportado para usar o LocationButton (androidx.core:core-locationbutton, Compose) dentro de um app Flutter? Não há guia oficial. Alternativas seriam PlatformView hospedando ComposeView ou plugin próprio — ambos não validados.
- Versão exata do Flutter a partir da qual libflutter.so/libapp.so são garantidamente 16 KB-aligned. Fontes encontradas foram secundárias (Medium/DEV) e divergem entre 3.22, 3.29 e 3.32. Validar empiricamente com APK Analyzer no Flutter 3.44.7 local.
- Valor atual da taxa do Apple Developer Program e política de isenção. Não verificado nesta pesquisa — não assumir US$ 99/ano sem confirmar.
- O limiar de 200 MB que dispara aviso de download em dados móveis é atual? Veio de resumo de busca, não do texto primário extraído.
- O Digital ECA brasileiro se aplica ao melhor_mercado (app 'provavelmente acessado por' adolescentes)? Exige avaliação jurídica; se aplicável, entra a Play Age Signals API (beta) como dependência técnica.
- A data efetiva de 28/10/2026 e o vínculo com Android 17/API 37 para Contact Picker (READ_CONTACTS) apareceram em um resumo de página que pode ter inferido. Se o app um dia tocar em contatos (convite de amigos), confirmar na fonte antes de projetar.
- Formato exato do flag de manifesto do location button: a doc de desenvolvedor mostra android:usesPermissionFlags="onlyForLocationButton"; um resumo da página de política sugeriu android:onlyForLocationButton="true". Prevalece a doc de desenvolvedor, mas confirmar no momento da implementação.
