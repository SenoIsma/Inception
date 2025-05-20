FROM debian:bookworm

RUN apt update -y && apt upgrade -y
RUN apt-get install mariadb-server -y

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/script.sh /usr/local/bin/script.sh
RUN chmod +x /usr/local/bin/script.sh

RUN mkdir -p /run/mysqld && chown -R mysql:mysql /run/mysqld

CMD ["/usr/local/bin/script.sh"]
