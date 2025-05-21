# Guide pour enfant

Ce guide te montrera tout ce qu'il te faut pour le projet **Inception**, il te montrera pas à pas les étapes en expliquant les configs utiliser, pour info je suis sur un VM Debian 12 Bookworm (64-bit).

---

## 1. 📦 Installation des dépendances

Avant de lancer quoi que ce soit, il te faut installer les outils suivants :


```bash
sudo apt update && sudo apt upgrade -y
sudo apt install make -y
sudo apt install docker-compose -y
sudo apt install vim -y
```

``sudo usermod -aG docker $USER`` : Cette commande est utile pour ne pas avoir a faire sudo à chaque fois que vous utiliser `docker` ou `docker-compose`.

## 📁 Structure des fichiers

Voici la structure utiliser durant ce guide :

```
inception/
├── Makefile
├── srcs/
│   ├── .env
│   ├── docker-compose.yml
│   └── requirements/
│       └── mariadb/
│           ├── Dockerfile
│           ├── conf/
│           └── tools/
│       └── nginx/
│           └── conf/
│       └── wordpress/
│           └── tools/
```

Note : Il est important de faire un .gitignore en donnant la destination de votre .env, il faut surtout pas le push dans un repo.

## 🐬 Mise en place de MariaDB

Il faut noter qu'il est interdit d'utiliser les images déjà pré-fait de Docker Hub alors tous nos Dockerfile commencerons ainsi : ``FROM debian:bookworm``.

### Fichier srcs/requirements/mariadb/Dockerfile :

```docker
#Noter que faire ceci est comme lancer une mini VM
FROM debian:bookworm

#Alors toujours faire les updates
RUN apt update -y && apt upgrade -y

#On installe ce qui nous intéresse : pour ce Dockerfile MariaDB server
RUN apt-get install mariadb-server -y
```

### Fichier srcs/requirements/mariadb/conf/50-server.cnf :

```
[mysqld]
datadir = /var/lib/mysql
socket = /run/mysqld/mysqld.sock
bind_address=*
port = 3306
user = mysql
```

Ici nous donnons à MariaDB les infos concernant la base de donnée. Il est important de comprendre que c'est une mini VM le fichier que tu lui donnes ici n'est pas celui de ton PC mais bien celui du docker. Le sujet nous dit de stocker la data dans ``/home/$USER/data/mariadb/``.

Nous allons link ``/var/lib/mysql`` à ``/home/$USER/data/mariadb/`` dans le fichier ``docker-compose.yml``.

### Fichier srcs/docker-compose.yml :

```yml
version: '3.8'

services:
  mariadb:
    build: ./requirements/mariadb
    container_name: mariadb
    image: mariadb_custom
    restart: always
    env_file:
      - .env
    volumes:
      - mariadb_data:/var/lib/mysql

volumes:
  mariadb_data:
    driver: local
    driver_opts:
      type: none
      device: /home/${USER}/data/mariadb
      o: bind
```

en faisant ainsi, nous attachons bien la data au bon endroit et avec ``o:bind``, ils sont directement lié.

Comme vous voyez nous lions aussi le docker avec ``.env`` qui contient pour l'instant juste ce qu'on a besoin pour la config.

### Fichier srcs/.env :

```
#DB
MYSQL_ROOT_PASSWORD=
MYSQL_DATABASE= wordpress
MYSQL_USER= wpuser
MYSQL_PASSWORD=
```

Ne soyez pas bete et remplissez aussi les champs vides.

Maintenant qu'on a créer notre .env, on peut finaliser le dernier fichier qui nous manque pour MariaDB, le ``script.sh``

### Fichier srcs/requirements/mariadb/tools/script.sh :

```sh
#!/bin/bash

service mariadb start;
sleep 10;

mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;"

mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE USER IF NOT EXISTS \`${MYSQL_USER}\`@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';"

mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO \`${MYSQL_USER}\`@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';"

mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';"

mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"

mysqladmin -u root -p$MYSQL_ROOT_PASSWORD shutdown
exec mysqld_safe
```

Maintenant que le script est fonctionnel, il nous suffit de terminer pour de bon le Dockerfile.

### Fichier srcs/requirements/mariadb/Dockerfile :

```docker
FROM debian:bookworm

RUN apt update -y && apt upgrade -y
RUN apt-get install mariadb-server -y

#Nous remplaçons le fichier config par le notre
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

#Nous mettons notre script dans la racine et on lui donne les droit d'execution
COPY tools/script.sh /usr/local/bin/script.sh
RUN chmod +x /usr/local/bin/script.sh

#Nous créons le dossier que MariaDB a besoin avec les autorisations pour fonctionner
RUN mkdir -p /run/mysqld && chown -R mysql:mysql /run/mysqld

#Pour finir nous lançons le script pour mettre en route la DB
CMD ["/usr/local/bin/script.sh"]

```

Voila pour MariaDB, nous en avons fini pour ce docker.

Lancer le docker en etant a la racine du projet et faites : 

``docker-compose -f srcs/docker-compose.yml --env-file srcs/.env up --build``

Pour tester, vous pouvez rejoindre le docker en faisant la commande ``docker exec -it mariadb bash`` ce qui vas vous faire rentrer dans la mini VM et tester pour voir si le script a bien fonctionner, regarder si la DB a été créer et l'utilisateur aussi.

## 📝 Création de Wordpress

### Fichier srcs/requirements/wordpress/Dockerfile :

```docker
FROM debian:bookworm

RUN apt update -y && apt upgrade -y
RUN apt-get install -y php8.2 php-fpm php-mysql wget curl unzip mariadb-client sed

#Pas besoin d'explication, on telecharge on extrait.
RUN mkdir -p /var/www/html
RUN wget https://wordpress.org/latest.tar.gz && tar -xzf latest.tar.gz && \
    mv wordpress/* /var/www/html && rm -rf wordpress latest.tar.gz

#Très important pour avoir le port 9000 ouvert.
RUN sed -i 's|^listen = .*|listen = wordpress:9000|' /etc/php/8.2/fpm/pool.d/www.conf
```

On a déjà fait plus de la moitié du Dockerfile, mais avant de le terminer il faut faire le ``setup.sh`` qui vas etre utile pour la configuration de la DB sur Wordpress et la création du compte admin et éditeur comme ce qui est demandé dans le sujet.

### Fichier srcs/requirements/wordpress/tools/setup.sh :

```sh
#!/bin/sh
set -e

WP_PATH="/var/www/html"


#Tout d'abord on vérifie si WordPress est bien installé, on installe si ce n'est pas le cas.
if [ ! -f "$WP_PATH/wp-load.php" ]; then
  echo "Downloading WordPress..."
  wp core download --path="$WP_PATH" --allow-root
fi


#On met les infos de la DB dans les configs.
cat <<EOF > "$WP_PATH/wp-config.php"
<?php
define('DB_NAME', '${MYSQL_DATABASE}');
define('DB_USER', '${MYSQL_USER}');
define('DB_PASSWORD', '${MYSQL_PASSWORD}');
define('DB_HOST', '${WP_DB_HOST}');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
\$table_prefix = 'wp_';
define('WP_DEBUG', false);
if ( !defined('ABSPATH') ) define('ABSPATH', __DIR__ . '/');
require_once ABSPATH . 'wp-settings.php';
EOF


#TRES IMPORTANT, on attend le lancement complet de MariaDB pour faire la suite.
until mysql -h "${WP_DB_HOST}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "SELECT 1" > /dev/null 2>&1; do
  echo "Waiting for MariaDB..."
  sleep 2
done


#On configure et on crée les utilisateur en utilisant les variables de .env.
if ! wp core is-installed --path="$WP_PATH" --allow-root; then
  echo "Installing WordPress..."
  wp core install \
    --path="$WP_PATH" \
    --url="https://${DOMAIN_NAME}" \
    --title="${WP_TITLE}" \
    --admin_user="${WP_ADMIN}" \
    --admin_password="${WP_ADMIN_PASSWORD}" \
    --admin_email="${WP_ADMIN_EMAIL}" \
    --allow-root
  wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
    --user_pass="${WP_USER_PASSWORD}" \
    --role=editor \
    --path="$WP_PATH" \
    --allow-root
fi

#Et on fini par executer la commande pour lancer le docker.
exec /usr/sbin/php-fpm8.2 -F

```

Voilà on a déjà fait le plus gros du projet arriver ici. Il nous manque plus qu'à finir le Dockerfile

### Fichier srcs/requirements/wordpress/Dockerfile :

```docker
FROM debian:bookworm

RUN apt update -y && apt upgrade -y
RUN apt-get install -y php8.2 php-fpm php-mysql wget curl unzip mariadb-client sed

RUN mkdir -p /var/www/html
RUN wget https://wordpress.org/latest.tar.gz && tar -xzf latest.tar.gz && \
    mv wordpress/* /var/www/html && rm -rf wordpress latest.tar.gz

RUN sed -i 's|^listen = .*|listen = wordpress:9000|' /etc/php/8.2/fpm/pool.d/www.conf

#On deplace le setup on le donnant les droit executable comme précédement
COPY tools/setup.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/setup.sh


#On télécharge WP-CLI pour pouvoir l'utiliser dans notre script (c'est les commands wp)
RUN wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
RUN chmod +x wp-cli.phar
RUN mv wp-cli.phar /usr/local/bin/wp

#Ceci est pour ouvrir le port 9000
EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/setup.sh"]
CMD ["/usr/sbin/php-fpm8.2", "-F"]
```

Il suffit maintenant juste d'ajouter cela au ``docker-compose.yml``.

### Fichier srcs/docker-compose.yml :

```yml
version: '3.8'

services:

  mariadb:
    build: ./requirements/mariadb
    container_name: mariadb
    image: mariadb_custom
    restart: always
    env_file:
      - .env
    volumes:
      - mariadb_data:/var/lib/mysql
    networks:
      - inception
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 5s
      timeout: 3s
      retries: 5

  wordpress:
    build: ./requirements/wordpress
    container_name: wordpress
    image: wordpress_custom
    restart: always
    env_file:
      - .env
    depends_on:
      mariadb:
        condition: service_healthy
    volumes:
      - wordpress_data:/var/www/html
    networks:
      - inception
    expose:
      - "9000"



volumes:
  mariadb_data:
    driver: local
    driver_opts:
      type: none
      device: /home/${USER}/data/mariadb
      o: bind
  wordpress_data:
    driver: local
    driver_opts:
      type: none
      device: /home/${USER}/data/wordpress
      o: bind



#Nous créons un reseau pour la communication entre les dockers
networks:
  inception:
    driver: bridge
```

L'ajout d'un reseau local entre les dockers pour la communication est primordiale. Et comme vous pouvez le constater l'ajout d'un statut pour vérifier le bon fonctionnement de mariaDB afin de proteger wordpress d'un crash causé par l'initialisation de la DB est important pour le bon fonctionnement des dockers.

Maintenant on peut passer à Nginx.

## 🚪 Installation Nginx

Commençons tout de suite par l'installation et la certification auto-signé pour le https.

### Fichier srcs/requirements/nginx/Dockerfile :
```docker
FROM debian:bookworm

RUN apt update -y && apt upgrade -y
RUN apt-get install -y nginx openssl

RUN mkdir -p /etc/nginx/ssl
RUN openssl req -x509 -nodes \
  -out /etc/nginx/ssl/inception.crt \
  -keyout /etc/nginx/ssl/inception.key \
  -subj "/C=FR/ST=IDF/L=Paris/O=42/OU=42/CN=DOMAIN/UID=USER"
```

Remplacer juste ``DOMAIN`` par le nom de domaine demander par le sujet et ``USER`` par votre identifiant.

Il faut aussi modifier dans le fichier ``/etc/hosts`` pour que le nom de domaine correspond a ce qui est demandé dans l'enoncé ``127.0.0.1    DOMAIN``.

Maintenant passons à la configuration de nginx

### Fichier srcs/requirements/nginx/conf/nginx.conf :

```conf
worker_processes 1;

events {
	worker_connections 1024;
}

#Ceci donne acces au fichier du site et par quel port écouter
http {
	server {
		include  /etc/nginx/mime.types;
		listen 443 ssl;
		ssl_protocols TLSv1.2 TLSv1.3;
		ssl_certificate /etc/nginx/ssl/inception.crt;
		ssl_certificate_key /etc/nginx/ssl/inception.key;

		root /var/www/html;
		server_name ibouhlel.42.fr;
		index index.php index.html index.htm;
		location ~ \.php$ {
			include  /etc/nginx/mime.types;
			include snippets/fastcgi-php.conf;
			fastcgi_pass wordpress:9000;
		}
	}

#Cela est pour bloquer la connexion en passant par localhost
	server {
		listen 80 default_server;
		listen 443 ssl default_server;
		server_name _;
		ssl_certificate /etc/nginx/ssl/inception.crt;
		ssl_certificate_key /etc/nginx/ssl/inception.key;
		return 444;
	}
}
```

### Fichier srcs/requirements/nginx/Dockerfile :
```docker
#Met la config dans le bon dossier pour qu'elle soit prise en compte
RUN mkdir -p /var/run/nginx
COPY conf/nginx.conf /etc/nginx/nginx.conf

#Donne acces au site complet
RUN chmod 755 /var/www/html
RUN chown -R www-data:www-data /var/www/html

CMD ["nginx", "-g", "daemon off;"]
```

ajouter ce bloc à la fin de votre Dockerfile et on passe tout de suite à la fin du ``docker-compose.yml``.

### Fichier srcs/docker-compose.yml :
```yml
  nginx:
    build: ./requirements/nginx
    container_name: nginx
    image: nginx_custom
    restart: always
    ports:
      - "443:443"
    volumes:
      - wordpress_data:/var/www/html
    depends_on:
      - wordpress
    networks:
      - inception
```

Suffit d'ajouter ce bloc dans les services et nous avons fini le projet. Plus qu'à tester, vérfier et comprends les notions importantes.