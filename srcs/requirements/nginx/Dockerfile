FROM debian:bookworm

RUN apt update -y && apt upgrade -y
RUN apt-get install -y nginx openssl

RUN mkdir -p /etc/nginx/ssl
RUN openssl req -x509 -nodes \
  -out /etc/nginx/ssl/inception.crt \
  -keyout /etc/nginx/ssl/inception.key \
  -subj "/C=FR/ST=IDF/L=Paris/O=42/OU=42/CN=ibouhlel.42.fr/UID=ibouhlel"

RUN mkdir -p /var/run/nginx
COPY conf/nginx.conf /etc/nginx/nginx.conf

RUN chmod 755 /var/www/html
RUN chown -R www-data:www-data /var/www/html

CMD ["nginx", "-g", "daemon off;"]
