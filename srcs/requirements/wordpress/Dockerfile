FROM debian:bookworm

RUN apt update -y && apt upgrade -y
RUN apt-get install -y php8.2 php-fpm php-mysql wget curl unzip mariadb-client sed

RUN mkdir -p /var/www/html
RUN wget https://wordpress.org/latest.tar.gz && tar -xzf latest.tar.gz && \
    mv wordpress/* /var/www/html && rm -rf wordpress latest.tar.gz

RUN sed -i 's|^listen = .*|listen = wordpress:9000|' /etc/php/8.2/fpm/pool.d/www.conf

COPY tools/setup.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/setup.sh

RUN wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
RUN chmod +x wp-cli.phar
RUN mv wp-cli.phar /usr/local/bin/wp

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/setup.sh"]
CMD ["/usr/sbin/php-fpm8.2", "-F"]
