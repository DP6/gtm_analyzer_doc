# Deploy no Cloud Run (mesmo projeto/região do gtm_analyzer_app, repositório próprio).
GCP_PROJECT ?= dp6-ins-datastrength
GCP_REGION  ?= southamerica-east1
REPO_NAME   ?= gtm-analyzer-docs-repo
SERVICE     ?= gtm-analyzer-docs
ALLOWED_DOMAIN ?= dp6.com.br
IMAGE       := $(GCP_REGION)-docker.pkg.dev/$(GCP_PROJECT)/$(REPO_NAME)/$(SERVICE):$(shell date +%Y%m%d-%H%M%S)

.PHONY: init deploy logs status

# Rodar uma vez: cria o repositório Docker próprio da documentação.
init:
	gcloud artifacts repositories describe $(REPO_NAME) --location=$(GCP_REGION) --project=$(GCP_PROJECT) >/dev/null 2>&1 || \
	gcloud artifacts repositories create $(REPO_NAME) --repository-format=docker --location=$(GCP_REGION) \
		--description="Imagens da documentação do GTM Analyzer" --project=$(GCP_PROJECT)
	gcloud services enable iap.googleapis.com --project=$(GCP_PROJECT)

deploy:
	npm ci && npm run build
	gcloud builds submit --tag $(IMAGE) --project=$(GCP_PROJECT) .
	gcloud beta run deploy $(SERVICE) --image=$(IMAGE) --region=$(GCP_REGION) --project=$(GCP_PROJECT) \
		--platform=managed --no-allow-unauthenticated --iap --port=8080 \
		--min-instances=0 --max-instances=2 --memory=256Mi
	gcloud beta iap web add-iam-policy-binding --resource-type=cloud-run --service=$(SERVICE) --region=$(GCP_REGION) \
		--project=$(GCP_PROJECT) --member=domain:$(ALLOWED_DOMAIN) --role=roles/iap.httpsResourceAccessor

logs:
	gcloud run services logs tail $(SERVICE) --region=$(GCP_REGION) --project=$(GCP_PROJECT)

status:
	@gcloud run services describe $(SERVICE) --region=$(GCP_REGION) --project=$(GCP_PROJECT) --format="value(status.url)"
