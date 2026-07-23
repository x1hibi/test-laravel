FROM composer:2 AS composer-build
WORKDIR /var/www

COPY composer.json composer.lock* ./
RUN composer install --no-interaction --no-plugins --no-scripts --prefer-dist --no-dev --optimize-autoloader

COPY . .
RUN composer dump-autoload --optimize --no-dev

FROM node:20-bookworm AS node-build
WORKDIR /var/www

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

FROM php:8.2-fpm-bookworm
WORKDIR /var/www

ENV DEBIAN_FRONTEND=noninteractive
ENV PORT=10000

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        nginx \
        curl \
        git \
        unzip \
        zip \
        gettext-base \
        libpng-dev \
        libjpeg-dev \
        libfreetype6-dev \
        libonig-dev \
        libxml2-dev \
        libzip-dev \
        libicu-dev \
        libpq-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql pdo_sqlite mbstring exif pcntl bcmath zip intl gd \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer-build /var/www/vendor /var/www/vendor
COPY --from=node-build /var/www/public/build /var/www/public/build
COPY . /var/www

RUN chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache /var/www/public \
    && chmod -R 775 /var/www/storage /var/www/bootstrap/cache \
    && composer install --no-interaction --no-plugins --no-scripts --prefer-dist --no-dev --optimize-autoloader \
    && php artisan storage:link || true

COPY docker/nginx/default.conf.template /etc/nginx/conf.d/default.conf.template
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 10000
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
