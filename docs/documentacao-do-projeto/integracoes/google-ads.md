---
title: "Google Ads"
description: "Análise de contas Google Ads pela API (GAQL), fan-out de contas MCC, cache de contas e o caminho alternativo por CSV."
sidebar_position: 2
---

# Google Ads

Dois caminhos produzem o mesmo formato de ação de conversão e passam pela mesma regra de inclusão (`finalize_report_inclusion`, `backend/services/google_ads_service.py:7`):

| Caminho | Entrada | Código |
|---|---|---|
| Ao vivo | Conexão OAuth do usuário ([Google OAuth](./google-oauth.md)) | `backend/services/google_ads_api_service.py` |
| CSV | Exports do Google Ads enviados por upload | `backend/services/google_ads_service.py:212` (`analyze_google_ads_csvs`) |

Rotas em `backend/routers/google_ads.py`: `GET /accounts`, `POST /analyze-live`, `POST /analyze` (CSV). Ver [API Google Ads](../api/google-ads.md).

## Cliente e consultas

- `_client` (`google_ads_api_service.py:35`) monta o `GoogleAdsClient` com o developer token, o cliente OAuth e o refresh token do cookie. `login_customer_id` é normalizado para 10 dígitos (`normalize_customer_id`, `:28`).
- `_rows` (`:99`) executa GAQL com `search_stream` e traduz `GoogleAdsException`: permissão negada ou conta desabilitada vira 403, cota vira 429, autenticação vira 401, o resto 502. O `request_id` do Google acompanha o erro (`GoogleAdsApiError`, `:21`).
- Falha de renovação do token vira 401 "Conexão Google Ads expirada ou revogada" (`:47`).

## Contas acessíveis e hierarquia de MCC

`list_accessible_accounts` (`:126`):

1. Lista os customers acessíveis ao usuário (`CustomerService.list_accessible_customers`).
2. Para cada raiz, percorre `customer_client` com `level <= 1` em largura, empilhando novos MCCs encontrados (cada MCC visitado uma vez). As consultas de cada nível rodam em paralelo (até 10 threads, `_ACCOUNTS_FETCH_MAX_WORKERS`).
3. Cada conta recebe `login_customer_id` (a raiz pela qual foi alcançada; `None` para a própria raiz), `manager`, `level`, `status`, moeda e fuso. Caminhos duplicados são descartados.
4. Falhas por raiz ou subconta viram `warnings`, sem abortar.

**Cache.** O resultado fica em memória por 300 s (`_ACCOUNTS_CACHE_TTL_SECONDS`, `:54`), com chave SHA-256 do refresh token (`:60`). É por instância: perde-se no reinício e não é compartilhado entre instâncias do Cloud Run (o código já marca isso como `ponytail`).

## `analyze_live_account`

`analyze_live_account` (`:441`) recebe conta, `login_customer_id` opcional e período.

**Regras de data** (`:466` a `:473`):

- O "hoje" é calculado no fuso da própria conta (se o fuso for inválido, usa a data local).
- Sem datas: `end_date` = ontem, `start_date` = `end_date - 29 dias` (30 dias completos).
- Erro 422 (`ValueError`) se início maior que fim, se `end_date` for hoje ou futuro, ou se o intervalo passar de 365 dias de diferença (366 dias inclusivos).

**Consultas em sequência** para conta não MCC: dados da conta (`customer`, incluindo `conversion_tracking_setting`; 404 se vazio), `conversion_action`, métricas por período (`all_conversions` e valor; ausência de linha significa volume zero), `campaign_conversion_goal` (campanhas habilitadas), `customer_conversion_goal`, `conversion_goal_campaign_config` (custom goals) e `offline_conversion_upload_client_summary`. Falha na última só gera o aviso `offline_diagnostics_unavailable`.

**Classificação.** `resolve_optimization` (`:308`) liga cada ação a `campaign_goal`, `account_goal` e/ou `custom_goal`; `_canonical_action` (`:263`) monta o item canônico; `_source_fields` (`:211`) define a origem (ações `GOOGLE_ANALYTICS_4_*` viram `ga4_event` antes da checagem por `origin`, porque a API não tem origem GA4). `finalize_report_inclusion` marca `included_in_report` somente se a ação tem volume, ao menos uma fonte de meta, origem `WEBSITE` e é primária ou secundária com pelo menos 25% do volume primário web. `conversion_actions` é o subconjunto incluído; `all_conversion_actions` guarda todas.

**Findings** (`severity`, `code`, `message`): termos de dados não aceitos, nenhuma ação de otimização, ações sem volume. **Derivados**: `ecl_enabled`, `oci_implemented` (há uploads offline), `oci_integration_method` (cliente com mais eventos), `google_ads_gtag_upd_capability` e `google_ads_ec_eligible_actions_identified` (há ações elegíveis). Estes campos alimentam o [payload](../geracao-do-documento/payload-v3.md).

## MCC (fan-out)

Se a conta é gerente, `_analyze_manager_account` (`:419`) lista os descendentes não gerentes (`_list_descendant_client_ids`, `:337`), analisa cada um com `analyze_live_account` usando o MCC como `login_customer_id` (paralelo, até 10 threads) e agrega em `_merge_live_account_results` (`:374`): `coverage: "aggregated_mcc"`, `child_account_ids`, findings prefixados pelo nome da conta, `account_tracking` nulo. Subcontas que falham viram `warnings`; 404 se o MCC não tem clientes acessíveis e 502 se nenhuma subconta pôde ser consultada.

## Persistência

Com `project_id` e `report_id`, a rota grava a execução (`source="live"`), registra os IDs usados em `google_accounts` do projeto e salva a análise do relatório (`backend/routers/google_ads.py:136`), tudo em modo best-effort.

## Caminho CSV

`analyze_google_ads_csvs` exige o CSV de ações com as colunas `Account`, `ID`, `Resource_Name`, `Name`, `Status`, `Type`, `Category`, `Origin`, `Primary`, `Conversions`. Aceita opcionalmente o CSV de metas personalizadas (`Custom_Goal_Conversion_Actions`, `Custom_Goal_Status`, `Custom_Goal_Name` opcional) e o de metas padrão (`Biddable`, `Category`, `Origin`). Diferenças em relação ao ao vivo: a fonte de meta padrão é `standard_goal` (não há equivalente a `customer_conversion_goal`, então nunca aparece "Account-default goal"), `warnings` e `findings` vêm vazios, não há diagnóstico de uploads offline e o erro HTTP é sempre 400 (`backend/routers/google_ads.py:190`).

## Sobre `Docs/google_ads_backend_flow.md`

Conferido contra o código: período, fontes de meta, regra de inclusão e hierarquia de contas conferem. Divergência: o documento descreve o caminho CSV como tendo "a mesma lógica" de origem GA4; confirmado em `_derive_origin_and_source`, mas a cobertura CSV é menor (sem findings, sem métricas por período). Nada de status "implementado/pendente" nele foi usado como fato.

Relacionados: [Contrato de status UPD](../referencia/contrato-status-upd.md), [Dicionário de dados](../referencia/dicionario-de-dados.md).
