### Perform multi-stage build using tool-specific docker images

# TODO: Create dkan-tools image (probably a "Running without docker" based install inside of a container)

FROM getdkan/dkan-docker:php72-cli as dkan2-build
WORKDIR /tools

# Install dktl
RUN git clone https://github.com/GetDKAN/dkan-tools.git && \
    ln -s /tools/dkan-tools/bin/dktl /usr/local/bin/dktl

WORKDIR /build

# Set DKTL_MODE to HOST to skip docker.
ENV DKTL_MODE "HOST"

# Set DRUPAL_VERSION to V8 so that dktl works fine.
ENV DRUPAL_VERSION V8

# Set environment variable to manage drupal version we want.
ENV DOWNLOAD_DRUPAL_VERSION 8.7.8

RUN dktl init && \
    dktl get $DOWNLOAD_DRUPAL_VERSION && \
    dktl make

## Use node 10 docker image to build react frontend
FROM node:10 as frontend-build
WORKDIR docroot
RUN git clone https://github.com/GetDKAN/data-catalog-frontend.git
WORKDIR data-catalog-frontend
RUN npm install

# Use Dkan PHP7-Web docker image to create DKAN2 image - TODO convert to Centos
FROM getdkan/dkan-docker:php7-web
WORKDIR /workspace/source

RUN chown -R www-data /var/log/apache2/ && \
#    chown -R www-data /var/run/apache2/ && \
    chown -R www-data /var/lock/apache2/ && \
    chown -R www-data /etc/ssl/ && \
    sed -i 's/80/8080/' /etc/apache2/ports.conf && \
    sed -i 's/443/8443/' /etc/apache2/ports.conf && \
    sed -i 's/80/8080/' /etc/apache2/sites-available/000-default.conf && \
    sed -i 's/443/8443/' /etc/apache2/sites-available/000-default.conf && \
    sed 's/\tErrorLog ${APACHE_LOG_DIR}\/error.log/\tErrorLog \/dev\/stderr/' /etc/apache2/sites-enabled/000-default.conf && \
#    sed -i 's/dkan/demo2.getdkan.com/' /var/www/docroot/data-catalog-frontend/.env.production && \
    sed 's/\tCustomLog ${APACHE_LOG_DIR}\/access.log combined/\tCustomLog \/dev\/stdout/' /etc/apache2/sites-enabled/000-default.conf

COPY --chown=www-data:www-data  --from=dkan2-build /build/docroot /var/www/
#COPY --chown=www-data:www-data  --from=frontend-build /build /var/www/docroot/data-catalog-frontend/build
#RUN chown root /var/www

ENV PORT 8080
EXPOSE 8080
