# Usar como base la imagen oficial de Ruby de Forem
FROM ghcr.io/forem/ruby:3.3.0@sha256:9cda49a45931e9253d58f7d561221e43bd0d47676b8e75f55862ce1e9997ab5c as base

FROM base as builder

# This is provided by BuildKit
ARG TARGETARCH

USER root

# Instalar dependencias del sistema (igual que el original)
RUN apt update && \
    apt install -y \
        build-essential \
        libcurl4-openssl-dev \
        libffi-dev \
        libxml2-dev \
        libxslt-dev \
        libpcre3-dev \
        libpq-dev \
        pkg-config \
        libpixman-1-dev \
        libcairo2-dev \
        libpango1.0-dev \
        && \
    apt clean

# Configuración del entorno (igual que el original)
ENV BUNDLER_VERSION=2.4.17 \
    BUNDLE_SILENCE_ROOT_WARNING=true \
    BUNDLE_SILENCE_DEPRECATIONS=true

RUN gem install -N bundler:"${BUNDLER_VERSION}"

ENV APP_USER=forem APP_UID=1000 APP_GID=1000 APP_HOME=/opt/apps/forem \
    LD_PRELOAD=libjemalloc.so.2
RUN mkdir -p ${APP_HOME} && chown "${APP_UID}":"${APP_GID}" "${APP_HOME}" && \
    groupadd -g "${APP_GID}" "${APP_USER}" && \
    adduser --uid "${APP_UID}" --gid "${APP_GID}" --home "${APP_HOME}" "${APP_USER}"

# Instalar dockerize (igual que el original)
ENV DOCKERIZE_VERSION=v0.7.0
RUN curl -fsSLO https://github.com/jwilder/dockerize/releases/download/"${DOCKERIZE_VERSION}"/dockerize-linux-${TARGETARCH}-"${DOCKERIZE_VERSION}".tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-linux-${TARGETARCH}-"${DOCKERIZE_VERSION}".tar.gz \
    && rm dockerize-linux-${TARGETARCH}-"${DOCKERIZE_VERSION}".tar.gz \
    && chown root:root /usr/local/bin/dockerize

USER "${APP_USER}"
WORKDIR "${APP_HOME}"

# Copiar archivos de dependencias (igual que el original)
COPY --chown=${APP_UID}:${APP_GID} ./.ruby-version "${APP_HOME}"/
COPY --chown=${APP_UID}:${APP_GID} ./Gemfile ./Gemfile.lock "${APP_HOME}"/
COPY --chown=${APP_UID}:${APP_GID} ./vendor/cache "${APP_HOME}"/vendor/cache

# Configurar bundle (igual que el original)
ENV BUNDLE_APP_CONFIG="${APP_HOME}/.bundle"
RUN mkdir -p "${BUNDLE_APP_CONFIG}" && \
    touch "${BUNDLE_APP_CONFIG}/config" && \
    chown -R "${APP_UID}:${APP_GID}" "${BUNDLE_APP_CONFIG}" && \
    bundle config --local build.sassc --disable-march-tune-native && \
    bundle config --local without development:test && \
    BUNDLE_FROZEN=true bundle install --deployment --jobs 4 --retry 5 && \
    find "${APP_HOME}"/vendor/bundle -name "*.c" -delete && \
    find "${APP_HOME}"/vendor/bundle -name "*.o" -delete

# Copiar código fuente
COPY --chown=${APP_UID}:${APP_GID} . "${APP_HOME}"

# 🎯 AQUÍ APLICAMOS TU MODIFICACIÓN DE WASABI
# Sobrescribir el archivo de configuración con tu versión modificada
COPY --chown=${APP_UID}:${APP_GID} ./config/initializers/carrierwave.rb "${APP_HOME}"/config/initializers/carrierwave.rb

RUN mkdir -p "${APP_HOME}"/public/{assets,images,packs,podcasts,uploads}

# Configurar timeout para yarn (igual que el original)
RUN echo 'httpTimeout: 300000' >> ~/.yarnrc.yml

# Compilar assets (igual que el original)
RUN NODE_ENV=production yarn install && \
    RAILS_ENV=production NODE_ENV=production bundle exec rake assets:precompile && \
    rm -rf node_modules

# Build metadata
ARG VCS_REF=unspecified
RUN echo $(date -u +'%Y-%m-%dT%H:%M:%SZ') >> "${APP_HOME}"/FOREM_BUILD_DATE && \
    echo "${VCS_REF}" >> "${APP_HOME}"/FOREM_BUILD_SHA

## Production (igual que el original, pero con tu modificación incluida)
FROM base as production

USER root

ENV BUNDLER_VERSION=2.4.17 BUNDLE_SILENCE_ROOT_WARNING=1
RUN gem install -N bundler:"${BUNDLER_VERSION}"

ENV APP_USER=forem APP_UID=1000 APP_GID=1000 APP_HOME=/opt/apps/forem \
    LD_PRELOAD=libjemalloc.so.2
RUN mkdir -p ${APP_HOME} && chown "${APP_UID}":"${APP_GID}" "${APP_HOME}" && \
    groupadd -g "${APP_GID}" "${APP_USER}" && \
    adduser --uid "${APP_UID}" --gid "${APP_GID}" --home "${APP_HOME}" "${APP_USER}"

COPY --from=builder --chown="${APP_USER}":"${APP_USER}" ${APP_HOME} ${APP_HOME}

USER "${APP_USER}"
WORKDIR "${APP_HOME}"

VOLUME "${APP_HOME}"/public/

ENTRYPOINT ["./scripts/entrypoint.sh"]

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]