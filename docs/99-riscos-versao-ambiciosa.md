# Registro de riscos — melhor_mercado

Atualizado em 2026-07-22. Complementa a seção 8 de [`00-fase-0-visao-arquitetural.md`](00-fase-0-visao-arquitetural.md).

Revisar a cada fim de fase. Um risco sem **indicador antecedente mensurável** e sem **gatilho** não é um risco gerenciado — é uma preocupação.

---

## R1 — Densidade insuficiente na praça piloto
- **Probabilidade / Impacto:** Alta / Existencial
- **Descrição:** O produto só entrega valor quando a cesta do usuário encontra preços recentes em várias lojas próximas. Sem densidade, a busca volta vazia, o usuário não vê retorno pelo cupom que enviou, e o loop não fecha. O concorrente mais próximo (Economiza Club, RS/PR/SP, desde 2015, modelo idêntico de QR + base colaborativa) aparentemente morreu exatamente aqui — o domínio hoje nem mantém HTTPS.
- **Agravante medido:** com meia-vida de 7 dias e piso de confiança em 0,25, uma observação única morre em ~13 dias; uma contribuição manual morre em ~3. A base se auto-esvazia mais rápido do que um piloto de 300 cupons consegue preencher.
- **Indicador:** cobertura média da cesta por requisição de busca/otimização, por praça.
- **Gatilho:** < 70% da cesta-alvo coberta em ≥ 5 lojas.
- **Mitigação:** Fase 1.5 dedicada à semeadura, com ferramenta de digitação em lote como entregável de MVP; meia-vida e piso de confiança **dependentes da fase da praça** (bootstrap usa 21–30 dias e piso 0,10, com rótulo "estimado" visível), apertando conforme a densidade sobe — são parâmetros em tabela versionada, portanto config, não código.
- **Plano B:** reduzir o escopo geográfico a um único bairro e contratar coleta paga por cupom.
- **Dono:** produto.

## R2 — Saturação da fila de curadoria humana
- **Probabilidade / Impacto:** Alta / Alto
- **Descrição:** O auto-link exige marca identificada, e o dicionário de marcas nasce vazio. Com auto-link em 0% no dia 1, 1.000 cupons geram ~25.000 itens em revisão — a 15 s cada, 104 horas de trabalho humano. O gargalo vira uma pessoa, não um servidor.
- **Indicadores:** itens em revisão por 1.000 cupons; taxa de auto-link; `review_backlog_days`.
- **Gatilhos:** > 120 itens/1.000 · auto-link < 60% · backlog > 3 dias.
- **Mitigação:** semear o dicionário de marcas antes da Fase 3 (dump do Open Food Facts filtrado por Brasil + mineração dos primeiros milhares de descrições); permitir auto-link sem marca quando houver GTIN não-RCN com DV válido; fila **em lote com atalhos de teclado** (a diferença entre 15 s e 2 s por decisão é a diferença entre viável e inviável); priorizar a fila por valor (frequência do alias × nº de listas que contêm o produto × dispersão de preço), não por ordem de chegada; teto diário explícito de itens revisados.
- **Plano B:** revisão comunitária — duas confirmações concordantes de usuários distintos substituem a revisão do admin para itens de baixo risco.
- **Dono:** engenharia + operação.

## R3 — Envenenamento de preço por contribuição adversarial
- **Probabilidade / Impacto:** Média / Alto, com responsabilidade civil embutida
- **Descrição:** Qualquer pessoa pode enviar foto ou QR. Um concorrente pode inflar o preço de um rival para desviar clientes. **Não há defesa criptográfica possível:** o `cHashQRCode` só é verificável com o CSC, que é segredo entre a SEFAZ e o emitente. Um QR sintético com DV módulo 11 correto passa em qualquer validação local.
- **Indicadores:** share de observações por `(loja, contribuinte)`; taxa de quarentena por anomalia; primeira semana de uma loja com < 3 contribuintes.
- **Gatilho:** share > 60% com ≥ 3 observações.
- **Mitigação:** quórum de publicação (≥2 contribuintes não correlacionados, ou 1 fonte forte com reputação); gate de anomalia **simétrico** (< 0,60× e > 1,40× da mediana) — um gate que só detecta deflação passa direto pelo ataque comercialmente relevante; baseline regional quando não há histórico local; atestação de dispositivo para emitir conta guest, com *fail-closed*; revisão manual obrigatória para toda loja cuja primeira semana venha de menos de 3 contribuintes.
- **Vetor espelhado:** denúncia como arma — 50 contas denunciando os preços de um rival entopem a fila e a saída de menor esforço do moderador é despublicar. Limitar por `(denunciante, alvo)`, exigir corroboração para ação automática, e espelhar reputação de denunciante.
- **Dono:** engenharia.

## R4 — Custo de IA acima da receita inexistente
- **Probabilidade / Impacto:** Média / Alto
- **Descrição:** É o único custo que cresce linearmente com o sucesso do produto. A diferença entre dois extratores plausíveis é de ~10× (US$80/mês vs US$920/mês a 40 mil documentos). Quotas calibradas "para não incomodar" (30 uploads/hora) permitem que um script com 1.000 identificadores de dispositivo consuma em uma hora mais orçamento do que um mês de uso legítimo.
- **Indicadores:** US$/documento; gasto diário vs teto; custo por MAU.
- **Gatilhos:** > US$0,02/doc · > 80% do teto diário.
- **Mitigação:** um único extrator barato no MVP; contador atômico de custo verificado **antes** da chamada, não depois; quotas na ordem de grandeza do uso real (20 documentos/dia por usuário autenticado, 5/dia por guest); retry por estágio, nunca da task inteira — uma falha no INSERT após a extração não pode repagar OCR e LLM; degradação explícita ao estourar (documentos vão para revisão com mensagem honesta, a fila não para).
- **Dono:** engenharia.

## R5 — Verificação de desenvolvedor na Google Play não concluída
- **Probabilidade / Impacto:** Média / Bloqueia o lançamento
- **Descrição:** O Brasil está na **primeira onda** do Android developer verification. A partir de **30/09/2026**, apps de desenvolvedores não verificados ficam indisponíveis para nova instalação em dispositivos certificados, em 7 lojas. A verificação de organização depende de número D-U-N-S emitido pela Dun & Bradstreet — terceiro fora do controle de prazo do projeto.
- **Prazos correlatos:** registro obrigatório de todos os apps no Play Console até **14/08/2026**; targetSdk 36 obrigatório para apps novos a partir de **31/08/2026** (extensão possível até 01/11/2026).
- **Indicador:** status da conta e do package name no Play Console.
- **Gatilho:** D-60 sem verificação concluída.
- **Mitigação:** iniciar o D-U-N-S e o registro do package name **imediatamente**, em paralelo ao desenvolvimento; nome legal e endereço no perfil de pagamentos do Google precisam coincidir exatamente com o cadastro na Dun & Bradstreet.
- **Dono:** produto.

## R6 — DANFE Simplificado Tipo 2 invalida parte do mapa de OCR
- **Probabilidade / Impacto:** Média / Alto
- **Descrição:** Ajustes SINIEF de abril/2026 introduzem o "DANFE Simplificado – Tipo 2", com início citado em **03/08/2026**. Não foi possível confirmar quais campos ele torna facultativos na impressão. Se a divisão de itens virar opcional, o cupom pode legalmente não trazer os itens — restando só chave e total. Além disso, o DANFE "resumido/ecológico" já é permitido por várias UFs hoje.
- **Indicador:** taxa de reconciliação aritmética por versão de pré-processamento; frequência do warning "sem itens no DANFE".
- **Gatilho:** queda > 10 pontos percentuais.
- **Mitigação:** fluxo de fallback já previsto — mantém a identidade obtida do QR e oferece entrada manual dos itens; acompanhar a publicação do Manual de Especificações Técnicas posterior à v6.0.
- **Dono:** engenharia.

## R7 — Cronograma solo
- **Probabilidade / Impacto:** Alta / Alto
- **Descrição:** O plano de escopo integral pressupõe dois desenvolvedores seniores em paralelo. Solo, o fator de correção é 1,8–2,2×. Além disso, o trabalho **não-dev** (anotação do golden set de matching, golden set de OCR, dicionário de marcas, dicionário de abreviações, curadoria contínua, LIA/ROPA/RIPD com revisão jurídica) não é substituível por código e frequentemente fica fora do orçamento.
- **Indicador:** velocidade real vs planejada nas Fases 0–2.
- **Gatilho:** desvio > 30%.
- **Mitigação:** roadmap publicado em dias-dev, não em semanas; corte explícito de encartes e alertas; linha separada para trabalho não-dev com responsável nomeado.
- **Dono:** produto.

## R8 — Volatilidade regulatória do documento fiscal
- **Probabilidade / Impacto:** Alta / Médio
- **Descrição:** As URLs de consulta por UF mudaram em MG (2022), RJ (2023), GO (2025) e RN (2026). O leiaute do QR mudou em 2018 (v1→v2) e 2025 (v3, em produção desde 01/09/2025). O regime de destinatário CNPJ da NFC-e mudou pelo menos 4 vezes entre abril/2025 e abril/2026. Três leiautes de QR convivem em campo, mais o CF-e-SAT.
- **Indicador:** taxa de erro do parser por versão de QR detectada.
- **Gatilho:** > 2%.
- **Mitigação:** nunca fazer *hardcode* de URL — derivar a UF de `chave[0:2]` e manter a tabela em configuração versionada com data de vigência; persistir sempre o payload bruto do QR para permitir reprocessar o histórico sem pedir novo escaneamento; determinar a versão pelo campo 2 do split, **nunca** pelo domínio.
- **Dono:** engenharia.

## R9 — Vazamento de PII em foto de cupom
- **Probabilidade / Impacto:** Média / Crítico
- **Descrição:** O DANFE pode conter CPF (obrigatório acima de R$ 10.000,00, ou a pedido) e, em entrega em domicílio, **nome e endereço completos obrigatórios**. O modo de falha mais provável não é o pipeline ler o CPF e ignorá-lo — é o OCR **não** ler o CPF (foto tremida, papel desbotado, ângulo) e o pipeline concluir "não há PII" e persistir a imagem intacta. Metadados EXIF com GPS são um segundo vetor silencioso.
- **Exposição:** art. 52, II da LGPD — 2% do faturamento, teto R$ 50 milhões por infração; e declaração falsa no Data safety é motivo de remoção da loja.
- **Indicador:** amostragem semanal de OCR sobre objetos do bucket durável, procurando CPF válido.
- **Gatilho:** qualquer achado.
- **Mitigação:** redação **antes** da persistência durável; falha do detector = redação conservadora da região inteira, nunca *no-op*; re-encode destrutivo que elimina EXIF/XMP de graça; detector por bloco geométrico (tudo abaixo do rótulo "CONSUMIDOR"/"DESTINATÁRIO" até a próxima linha divisória), não só por rótulo; **CPF nunca armazenado em nenhuma forma, inclusive hash** — com ~10⁹ CPFs válidos, enumerar contra qualquer hash é trivial em GPU, e sob o art. 12 continua dado pessoal.
- **Dono:** engenharia.

## R10 — Ação de varejista por uso de marca ou concorrência desleal
- **Probabilidade / Impacto:** Baixa / Alto
- **Descrição:** O art. 132, IV da Lei 9.279/96 condiciona a citação livre da marca a "sem conotação comercial", e um app monetizado tem conotação comercial. O risco real não é perder no mérito — é a liminar: uma ordem para remover uma rede grande da base degrada o produto por meses.
- **Indicador:** notificação extrajudicial.
- **Gatilho:** qualquer.
- **Mitigação:** uso **nominativo em texto puro** — nunca logotipo, trade dress ou cor institucional da rede; nunca rótulos como "Parceiro" ou "Oficial"; rodapé fixo de não-afiliação; canal público de contestação para o comerciante, com SLA de 48h e despublicação reversível (soft delete com motivo), preservando a trilha de auditoria.
- **Âncora de defesa:** o CONFAZ opera desde 2019 o "Menor Preço Brasil" (Convênio de Cooperação Técnica nº 03/19, 21 estados + DF), que publica preço por item nominando o estabelecimento a partir de NFC-e. Somado à Lei 10.962/2004, que obriga o varejo a afixar preços de forma ostensiva, um preço que a lei manda expor publicamente não pode ser reivindicado como segredo de negócio.
- **Dono:** produto + jurídico.

---

## Riscos de segurança rastreados fora desta tabela

Modelagem STRIDE por fronteira de confiança em `docs/compliance/ameacas.md` (a escrever antes da Fase 2). Vetores já identificados e ainda **não** endereçados por controle implementado:

- **Injeção de prompt no extrator** — o extrator recebe imagem e texto de um documento controlado pelo atacante; um cupom impresso com instruções pode induzir saída arbitrária, e o JSON Schema não protege contra valores plausíveis.
- **Cupom sintético com DV válido** — autenticidade é indecidível; compensar com corroboração por documento fiscal **distinto**, nunca pelo reenvio da mesma nota.
- **SSRF no importador de encarte** — a URL de origem é buscada pelo backend; exige allowlist de domínio e bloqueio de faixas privadas e link-local.
- **Exfiltração da própria base** — a densidade de cobertura é o ativo defensável, e uma API de leitura sem cota diária permite varredura sistemática por produto × célula geográfica.
- **Custo como DoS** — teto por dispositivo/dia, além do teto global.
