# frozen_string_literal: true

require 'redis'
require 'travis/amqp'
require 'travis/exceptions'
require 'travis/logger'
require 'travis/metrics'
require 'travis/owners'
require 'travis/queue'
require 'travis/scheduler/config'
require 'travis/scheduler/jobs'
require 'travis/scheduler/record'
require 'travis/scheduler/ping'
require 'travis/scheduler/service'
require 'travis/scheduler/support/features'
require 'travis/scheduler/support/sidekiq'
require 'travis/scheduler/worker'
require 'travis/scheduler/billing'
require 'travis/service'
require 'travis/support/database'
require 'marginalia'

require 'pry' unless %w[production staging].include? ENV['ENV']

Travis::Exceptions::Queue = ::Queue # TODO: fix in travis-exceptions

module Travis
  module Scheduler
    Context = Struct.new(:config, :amqp, :features, :logger, :metrics, :redis)

    class << self
      attr_reader :metrics

      def setup
        Amqp.setup(config.amqp.to_h, logger)
        Database.connect(config.database.to_h)
        Exceptions.setup(config, config.env, logger)
        @metrics = Metrics.setup(config.metrics, logger)
        Sidekiq.setup(config, logger)
        Features.setup(config)

        return unless ENV['QUERY_COMMENTS_ENABLED'] == 'true'

        ::Marginalia.install
      end

      def context
        @context ||= Context.new(config, nil, nil, logger, metrics, redis)
      end

      def config
        @config ||= Config.load
      end

      def env
        config.env
      end

      def logger
        @logger ||= Logger.configure(Logger.new(STDOUT), config)
      end

      def logger=(logger)
        @logger = Logger.configure(logger, config)
      end

      def redis
        cfg = config[:redis].to_h
        cfg = cfg.merge(ssl_params: redis_ssl_params(config)) if cfg[:ssl]
        @_redis ||= Redis.new(cfg)
      end

      def redis_ssl_params(config)
        @redis_ssl_params ||= begin
          return nil unless config[:redis][:ssl]

          value = {}
          value[:ca_path] = ENV['REDIS_SSL_CA_PATH'] if ENV['REDIS_SSL_CA_PATH']
          value[:cert] = OpenSSL::X509::Certificate.new(File.read(ENV['REDIS_SSL_CERT_FILE'])) if ENV['REDIS_SSL_CERT_FILE']
          value[:key] = OpenSSL::PKEY::RSA.new(File.read(ENV['REDIS_SSL_KEY_FILE'])) if ENV['REDIS_SSL_KEY_FILE']
          value[:verify_mode] = OpenSSL::SSL::VERIFY_NONE if config[:ssl_verify] == false
          value
        end
      end

      def ping
        Ping.new(context).start unless ENV['SKIP_PING']
      end
    end
  end

  # TODO: used by travis-settings, apparently
  class << self
    def env
      Scheduler.env
    end

    def config
      Scheduler.config
    end

    def logger
      Scheduler.logger
    end
  end
end
