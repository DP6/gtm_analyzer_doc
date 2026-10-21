---
title: "Timeout y errores"
description: "Tabla de errores de la generación en Drive (503, 422, 502, 504), causas, acciones y el riesgo de documentos duplicados tras un timeout."
sidebar_position: 4
---

# Timeout y errores

Todos los errores salen de `generate_drive_report` (`backend/services/apps_script_service.py`). Los mensajes son genéricos a propósito: los detalles de Apps Script no llegan al usuario, solo a los logs (`logger.warning`).

## Tabla de errores

| HTTP | Mensaje (resumen) | Causa | Qué hacer |
|---|---|---|---|
| 503 | "Geração no Drive não configurada: informe ..." (Generación en Drive no configurada: informe ...) (`:24`) | Falta `DS30_APPS_SCRIPT_URL`, `DS30_APPS_SCRIPT_SECRET`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` o `GOOGLE_REFRESH_TOKEN` | Configurar la variable citada (el mensaje lista solo los nombres) y reiniciar el backend |
| 503 | "DS30_APPS_SCRIPT_URL deve ser a URL /exec" (debe ser la URL /exec) (`:26`) | URL fuera del patrón (por ejemplo `/dev`) | Usar la URL `/exec` del despliegue |
| 422 | "Coleção inválida: `<chave>`" (Colección inválida) (`:31`) | La colección no es una lista de objetos | Corregir el payload en la pestaña de origen |
| 422 | "Logo inválido. Use PNG, JPEG ou GIF de até 5 MB." (Logo inválido. Use PNG, JPEG o GIF de hasta 5 MB.) (`:45`) | Logo del proyecto fuera de formato, corrupto o demasiado grande | Cambiar el logo en la configuración del proyecto |
| 502 | "Não foi possível renovar o token Google ..." (No fue posible renovar el token de Google ...) (`:58`) | Refresh token de la cuenta publicadora revocado o cliente OAuth divergente | Generar un nuevo token (ver [Apps Script](../integracoes/apps-script.md)); no se hizo ningún POST |
| 502 | "O endpoint do Apps Script retornou HTTP 401/403" (El endpoint de Apps Script devolvió HTTP 401/403) (`:70`) | Cuenta publicadora sin acceso al Web App o despliegue que rechaza el Bearer | Revisar el acceso `DOMAIN` y la cuenta publicadora |
| 502 | "retornou HTTP `<código>`" (devolvió HTTP) (`:71`) | Otro error HTTP de la publicación | Revisar la publicación y los permisos del Web App |
| 502 | "Falha de comunicação com o Apps Script" (Falla de comunicación con Apps Script) (`:74`) | Error de transporte (DNS, conexión) | Verificar la red y la URL; intentar de nuevo |
| 502 | "Resposta inválida do Apps Script" (Respuesta inválida de Apps Script) (`:81`) | El cuerpo no era JSON (por ejemplo, la página de login de Google) | Revisar la publicación y el acceso; el log trae la cadena de redirecciones |
| 502 | "O Apps Script não conseguiu gerar o documento" (Apps Script no logró generar el documento) (`:84`) | JSON con `ok` distinto de `true`: secreto divergente, `CONFIG` incompleto, plantilla inaccesible, error de render | Ver las ejecuciones de `doPost` en Apps Script |
| 502 | "identificador de documento inválido" (identificador de documento inválido) (`:88`) | `documentId` ausente o fuera de `[A-Za-z0-9_-]+` | Ver la ejecución en Apps Script |
| 504 | "O Apps Script não respondeu a tempo ..." (Apps Script no respondió a tiempo ...) (`:66`) | Timeout de 360 s (`httpx.Timeout(360, connect=10)`, `:60`) | **Revisar la carpeta del cliente en Drive antes de generar de nuevo** |

Orden de evaluación y líneas: ver [Flujo de generación](./fluxo-de-geracao.md).

## 504 y documentos duplicados

No hay reintento automático. Un 504 significa que el backend dejó de esperar, no que el script se detuvo: Apps Script puede terminar y crear el documento después. Cada generación concluida crea una nueva copia, y el nombre (`[DS30] Diagnóstico Técnico - <cliente> (<fecha>)`) no tiene sufijo de unicidad, por lo que un nuevo intento genera un segundo archivo con el mismo nombre. Revise la subcarpeta del cliente y elimine el duplicado si es necesario. Cuando el error ocurre durante el armado, el script mueve la copia incompleta a la papelera (`Docs/ds30_appscript/Main.js:64`).

## NO VERIFICADO: timeout de Cloud Run

El cliente HTTP espera hasta 360 s, pero el timeout predeterminado de solicitud de Cloud Run es 300 s. El `gcloud run deploy` del `Makefile` (líneas 139 a 151) no define `--timeout`, y el `Dockerfile` y `backend/config.py` no tienen referencia a timeout. Si el servicio está con el valor predeterminado, Cloud Run puede cerrar la solicitud del usuario antes de que el backend llegue a los 360 s, y el frontend recibiría un error que no es el 504 documentado. Un humano debe confirmar el valor real con `gcloud run services describe <servicio> --region=<región>` (campo `timeoutSeconds`). Esta página no afirma cuál es el valor en producción.

## Pruebas

`backend/tests/test_report_contract_v2.py` cubre: reenvío del payload y del correo de la sesión (`:42`), `client_name` proveniente del proyecto sin sobrescribir el existente (`:75`), errores remotos sin filtrar detalles, incluidos 401/403/500, no-JSON, `ok: false`, `documentId` malicioso y timeout 504 (`:117`), configuración y entradas inválidas que fallan antes de la red (`:157`), refresh que falla antes del POST (`:181`), redirección sin Bearer y renovación en cada generación (`:201`) y el log de la cadena de redirecciones (`:224`). Ver [Pruebas](../desenvolvimento/testes.md).
