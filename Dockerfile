# syntax=docker/dockerfile:1.7

FROM public.ecr.aws/docker/library/composer:2 AS vendor
WORKDIR /app

COPY src/composer.json src/composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist --no-scripts

COPY src .
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader

FROM public.ecr.aws/docker/library/php:8.4-cli AS runtime
WORKDIR /var/www/html

RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq-dev unzip git \
    && docker-php-ext-install pdo pdo_pgsql \
    && rm -rf /var/lib/apt/lists/*

COPY --from=vendor /app /var/www/html

RUN mkdir -p /run/php \
    && chown -R www-data:www-data /var/www/html /run/php \
    && rm -f /var/www/html/.env \
    && mkdir -p storage/framework/cache/data storage/framework/views storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache

EXPOSE 80

ENTRYPOINT ["/bin/sh", "-c", "php artisan migrate --force || echo 'Migrations failed (continuing)'; exec php artisan serve --host=0.0.0.0 --port=80"]
