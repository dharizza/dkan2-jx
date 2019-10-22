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
    dktl make --frontend

# Use Dkan PHP7-Web docker image to create DKAN2 image
FROM getdkan/dkan-docker:php7-web as dkan2-final
WORKDIR /build

RUN chown -R www-data /var/log/apache2/ && \
#    chown -R www-data /var/run/apache2/ && \
    chown -R www-data /var/lock/apache2/ && \
    chown -R www-data /etc/ssl/ && \
    sed -i 's/80/8080/' /etc/apache2/ports.conf && \
    sed -i 's/443/8443/' /etc/apache2/ports.conf && \
    sed -i 's/80/8080/' /etc/apache2/sites-available/000-default.conf && \
    sed -i 's/443/8443/' /etc/apache2/sites-available/000-default.conf && \
    sed 's/\tErrorLog ${APACHE_LOG_DIR}\/error.log/\tErrorLog \/dev\/stderr/' /etc/apache2/sites-enabled/000-default.conf && \
    sed 's/\tCustomLog ${APACHE_LOG_DIR}\/access.log combined/\tCustomLog \/dev\/stdout/' /etc/apache2/sites-enabled/000-default.conf

COPY --chown=www-data:www-data  --from=dkan2-build /build /var/www/

ENV PORT 8080
EXPOSE 8080
