MIGRATE=migrate
MIGRATIONS_DIR=feelog-backend-go/infra/migrations

DB_USER=$(shell terraform output -raw db_user)
DB_PASSWORD=$(shell terraform output -raw db_password)
DB_HOST=$(shell terraform output -raw db_host)
DB_NAME=$(shell terraform output -raw db_name)
DB_URL=postgres://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):5432/$(DB_NAME)?sslmode=require

.PHONY: migrate-up migrate-down migrate-status

migrate-up:
	$(MIGRATE) -path $(MIGRATIONS_DIR) -database "$(DB_URL)" up

migrate-down:
	$(MIGRATE) -path $(MIGRATIONS_DIR) -database "$(DB_URL)" down 1

migrate-status:
	$(MIGRATE) -path $(MIGRATIONS_DIR) -database "$(DB_URL)" version 