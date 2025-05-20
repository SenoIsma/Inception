NAME=inception
COMPOSE=docker-compose -f srcs/docker-compose.yml --env-file srcs/.env
DATA_DIR=/home/$(USER)/data

up:
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down --volumes

fclean: clean
	docker system prune -af
	docker volume prune -f
	docker network prune -f

re: fclean up

destroy:
	sudo rm -rf $(DATA_DIR)/mariadb/* $(DATA_DIR)/wordpress/*

.PHONY: up down clean fclean re destroy
