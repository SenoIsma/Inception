#!/bin/sh
set -e

WP_PATH="/var/www/html"

if [ ! -f "$WP_PATH/wp-load.php" ]; then
  echo "Downloading WordPress..."
  wp core download --path="$WP_PATH" --allow-root
fi

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

until mysql -h "${WP_DB_HOST}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "SELECT 1" > /dev/null 2>&1; do
  echo "Waiting for MariaDB..."
  sleep 2
done

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

exec /usr/sbin/php-fpm8.2 -F
