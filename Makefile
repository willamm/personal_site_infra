.PHONY: format apply creds destroy
format:
	terraform fmt -check

creds:
	. ~/.cloudflare

apply: creds
	terraform apply -var-file=secret.tfvars -auto-approve

destroy: creds
	terraform destroy -var-file=secret.tfvars -auto-approve