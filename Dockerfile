### Perform multi-stage build using tool-specific docker images

# Use node 10 docker image to build react frontend
FROM node:10 as frontend-build
WORKDIR /workspace/source/docroot/data-catalog-frontend 

#ENV REACT_APP_INTERRA_API_URL=/api/v1
#ENV REACT_APP_INTERRA_BASE_URL=/

RUN npm install && \
    npm run build && \
    cp -R build /

# TODO: Create dkan-tools image (probably a "Running without docker" based install inside of a container)

FROM getdkan/dkan-tools:latest as dkan2-build
WORKDIR /build

ENV DRUPAL_VERSION=V8

### Directory structure
# /build is build root
# /build/docroot which is where drupal is inflated
# /build/src
# /build/dkan2 ???
# /build/config/sync ???

RUN dktl init 

# Need to check correct paths 
COPY ./ /build/dkan2 

RUN dktl dkan:get $DRUPAL_VERSION && \
    dktl make 



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
COPY --chown=www-data:www-data  --from=frontend-build /build /var/www/docroot/data-catalog-frontend/build
#RUN chown root /var/www

ENV PORT 8080
EXPOSE 8080
