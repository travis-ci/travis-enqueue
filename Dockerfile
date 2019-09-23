FROM ruby:2.4.2

LABEL maintainer Travis CI GmbH <support+travis-scheduler-docker-images@travis-ci.com>

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

RUN mkdir -p /app
WORKDIR /app

COPY Gemfile      /app
COPY Gemfile.lock /app

ARG bundle_gems__contribsys__com
RUN bundle config https://gems.contribsys.com/ $bundle_gems__contribsys__com \
      && bundle install --deployment \
      && bundle config --delete https://gems.contribsys.com/

COPY . /app

CMD ["bundle", "exec", "je", "bin/sidekiq-pgbouncer", "${SIDEKIQ_CONCURRENCY:-5}", "${SIDEKIQ_QUEUE:-scheduler}"]
