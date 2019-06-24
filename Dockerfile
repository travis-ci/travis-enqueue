FROM ruby:2.4.2

LABEL maintainer Travis CI GmbH <support+travis-app-docker-images@travis-ci.com>

# required for envsubst tool
RUN ( \
   apt-get update ; \
   apt-get install -y --no-install-recommends  gettext-base ; \
   rm -rf /var/lib/apt/lists/* ; \
   groupadd -r travis && useradd -m -r -g travis travis ; \
   mkdir -p /usr/src/app ; \
   chown -R travis:travis /usr/src/app \
)

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

USER travis
WORKDIR /usr/src/app

COPY Gemfile      /usr/src/app
COPY Gemfile.lock /usr/src/app

ARG bundle_gems__contribsys__com
RUN bundle config https://gems.contribsys.com/ $bundle_gems__contribsys__com \
      && bundle install --deployment \
      && bundle config --delete https://gems.contribsys.com/

COPY . /usr/src/app

CMD bundle exec je bin/sidekiq-pgbouncer ${SIDEKIQ_CONCURRENCY:-5} ${SIDEKIQ_QUEUE:-scheduler}
