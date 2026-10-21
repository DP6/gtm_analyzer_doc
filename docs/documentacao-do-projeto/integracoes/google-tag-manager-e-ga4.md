---
title: "Google Tag Manager e GA4"
description: "Leitura de containers GTM e propriedades GA4 pelas APIs do Google, reaproveitando o mesmo pipeline de auditoria do upload de JSON."
sidebar_position: 3
---

# Google Tag Manager e GA4

`backend/services/google_platform_service.py` consulta GTM (API v2), GA4 Admin e GA4 Data com o access token do usuário, obtido da conexão descrita em [Google OAuth](./google-oauth.md). As rotas estão em `backend/routers/google_platforms.py` (ver [API plataformas Google](../api/google-platforms.md)); `_token` (`:46`) lê o cookie, valida dono e escopos e renova o access token (401 se a conexão é inválida, 502 se a renovação falha).

## Cliente HTTP

`_request` (`google_platform_service.py:17`) usa `httpx` com timeout de 30 s e converte erros: status 400, 401, 403, 404 e 429 são mantidos; o resto vira 502, com a mensagem de erro do Google quando existe. `_list` (`:34`) pagina com `pageSize=200` e `nextPageToken` até acabar.

## GTM

| Função | Linha | Faz |
|---|---|---|
| `list_gtm_accounts` | 48 | Contas (`path`, `name`) |
| `list_gtm_containers` | 53 | Containers de uma conta (valida `account_id` numérico); devolve `public_id`, `usage_context` |
| `list_gtm_versions` | 69 | `version_headers` ordenados da versão mais nova para a mais antiga |
| `analyze_gtm_container_version` | 88 | Baixa a versão e roda a auditoria |

`analyze_gtm_container_version` valida o caminho com `accounts/<n>/containers/<n>/versions/<n>`, busca a versão e chama `process_single_container({"containerVersion": version}, file_name="<publicId> v<versão> (GTM API)")`. Esse é **o mesmo pipeline do upload de JSON**: `process_single_container` (`backend/services/audit_service.py:5`) chama `analyze_gtm_json` (`backend/analyze_gtm_json.py:6`), que escolhe o auditor e acrescenta `source_json_file` a cada item. Se o resultado traz `error`, a API responde 422.

### Classificação do tipo de container

`analyze_gtm_json` lê `usageContext` do container (`analyze_gtm_json.py:21`):

| Contexto | Tipo interno | Auditor | `gtm_container_type` no payload |
|---|---|---|---|
| contém `SERVER` | server | `backend/audits/audit_server_container.py` | `server` |
| contém `ANDROID_SDK_5` ou `IOS_SDK_5` | mobile | `backend/audits/audit_mobile_container.py` | `unknown` |
| demais (padrão `WEB`) | web | `backend/audits/audit_web_container.py` | `web` |

### Detecção de UPD (container web)

`audit_web_container` (`audit_web_container.py:58`) trata como variável UPD toda variável do tipo `awec` (User-Provided Data); o método vem do parâmetro `mode` (`automatic`, `manual`, `partial`, `not_configured` ou `unknown`). Depois liga tags (`awct`, `flc`, `fls`, `gaawc`, `gaawe`, `awud`, ignorando pausadas) à variável de duas formas: parâmetro `user_data` em `eventSettingsTable`/`configSettingsTable` da própria tag, ou via variáveis de configuração/eventos (`gtes`, `gtcs`). O status de cada tag (`upd_configuration_status`) segue `correct`, `incomplete: missing email`, `incomplete: missing phone_number`, `incomplete: missing email and phone_number`, `incorrect` ou `not_configured`; a checagem de `email` e `phone_number` é feita nas chaves declaradas dentro da variável (`:47`). O mesmo auditor extrai IDs `G-...` e `AW-...` das tags ativas (resolvendo variáveis Constant) e os devolve como `platform_accounts`. Os valores de status são parte do contrato descrito em [Contrato de status UPD](../referencia/contrato-status-upd.md).

Containers server e mobile usam heurísticas mais simples: variáveis de `event_data` (server) ou de SDK (mobile) contam como UPD e a tag fica `correct` se referencia uma delas.

### Persistência

`POST /api/gtm/analyze-live` grava a execução (`source="live"`) e registra conta e container em `google_accounts` do projeto, apenas se `project_id` e `report_id` vieram (`backend/routers/google_platforms.py:89`). O resultado é mesclado no payload com a fonte `gtm_api` (ver [Payload v3](../geracao-do-documento/payload-v3.md)).

## GA4

- `list_ga4_properties` (`google_platform_service.py:102`): `accountSummaries` da Admin API, achatado em propriedades com nome da conta.
- `analyze_ga4_property` (`:118`): valida `properties/<n>`, aplica as mesmas regras de data (fim = ontem, início = 29 dias antes, intervalo máximo de 366 dias inclusivos, 422 se inválido) usando a data local do servidor (UTC no Cloud Run), e consulta propriedade, `dataStreams`, `keyEvents` e um `runReport` Data API com `eventName` x `eventCount`.
- Saída: `platform_accounts` (um por data stream, com `measurement_id` de web streams; um item sem stream se não houver) e `conversion_actions` com um item por key event (`conversion_goal: key_event`, `conversion_origin: ga4_event`, contagem e `has_recent_activity` do período).

## Observações

- O escopo GA4 é somente leitura (`analytics.readonly`) e o de GTM também (`tagmanager.readonly`).
- Diferente do Google Ads, não há cache em memória nestes serviços.
- Os auditores têm testes em `backend/tests/test_audit_service.py` e `backend/tests/test_google_platform_service.py`. Ver [Testes](../desenvolvimento/testes.md).
