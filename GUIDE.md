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
    networks:
      - inception

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

Pour tester, vous pouvez rejoindre le docker en faisant la commande ``docker exec -it mariadb bash`` ce qui vas vous faire rentrer dans la mini VM et tester pour voir si le script a bien fonctionner, regarder sur la DB a été créer et l'utilisateur aussi.