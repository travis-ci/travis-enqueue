# frozen_string_literal: true

require 'sidekiq'
require 'travis/exceptions/sidekiq'
require 'travis/metrics/sidekiq'
require 'travis/honeycomb'
require 'travis/scheduler/support/sidekiq/honeycomb'
require 'travis/scheduler/support/sidekiq/marginalia'

module Travis
  module Scheduler
    module Sidekiq
      class << self
        def setup(config, logger)
          Travis::Honeycomb::Context.add_permanent('app', 'scheduler')
          Travis::Honeycomb::Context.add_permanent('dyno', ENV['DYNO'])
          Travis::Honeycomb::Context.add_permanent('site', ENV['TRAVIS_SITE'])
          Travis::Honeycomb.setup

          ::Sidekiq.configure_server do |c|
            c.redis = {
              url: config.redis.url
            }

            # Raven sets up a middleware unsolicitedly:
            # https://github.com/getsentry/raven-ruby/blob/master/lib/raven/integrations/sidekiq.rb#L28-L34
            c.error_handlers.clear

            c.server_middleware do |chain|
              chain.add Exceptions::Sidekiq, config.env, logger if config.sentry.dsn
              chain.add Metrics::Sidekiq
              chain.add Sidekiq::Honeycomb
              chain.add Sidekiq::Marginalia, app: 'scheduler'
            end

            c.logger.level = ::Logger.const_get(config.sidekiq.log_level.upcase.to_s)

            if pro?
              c.super_fetch!
              c.reliable_scheduler!
            end
          end

          ::Sidekiq.configure_client do |c|
            c.redis = {
              url: config.redis.url
            }
          end

          return unless pro?

          ::Sidekiq::Client.reliable_push!
        end

        def pro?
          ::Sidekiq::NAME == 'Sidekiq Pro'
        end
      end
    end
  end
end
