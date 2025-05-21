# Inception

Inception est un projet 42 visant à créer un environnement de conteneurs Docker.
Le but est de déployer un service web qu'à l'aide de Docker Compose, le tout sans utiliser d'image Docker Hub.

## Services inclus

- **NGINX** – Serveur web avec certificats SSL auto-signés.
- **WordPress** – CMS déployé avec son propre container.
- **MariaDB** – Base de données MySQL utilisée par WordPress.

## Dépendances

- `docker`
- `docker-compose`
- `GNU Make`

## Lancement du projet

   ```bash
   git clone https://github.com/tonpseudo/inception.git
   cd inception
   make
   ```

📚 Un guide pas à pas pour réussir le projet est disponible ici : [GUIDE.md](./GUIDE.md)
