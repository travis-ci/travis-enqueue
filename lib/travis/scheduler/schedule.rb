require 'multi_json'

require 'travis'
require 'travis/model'
require 'travis/states_cache'
require 'travis/support/amqp'
require 'core_ext/kernel/run_periodically'
require 'travis/support/logging'

module Travis
  module Scheduler
    class Schedule
      include Travis::Logging

      def setup
        Travis::Async.enabled = true
        Travis::Amqp.config = Travis.config.amqp

        Travis.logger.info('[hub] connecting to database')
        Travis::Database.connect

        if Travis.config.logs_database
          Travis.logger.info('[hub] connecting to logs database')
          Log.establish_connection 'logs_database'
          Log::Part.establish_connection 'logs_database'
        end

        Travis.logger.info('[hub] setting up sidekiq')
        Travis::Async::Sidekiq.setup(Travis.config.redis.url, Travis.config.sidekiq)

        Travis.logger.info('[hub] starting exceptions reporter')
        Travis::Exceptions::Reporter.start

        Travis.logger.info('[hub] setting up metrics')
        Travis::Metrics.setup

        Travis.logger.info('[hub] setting up notifications')
        Travis::Notification.setup

        Travis.logger.info('[hub] setting up addons')
        Travis::Addons.register

        declare_exchanges_and_queues
      end

      def run
        Travis.logger.info('[enqueue] starting the onslaught')
        run_periodically(Travis.config.queue.interval) do
          Metriks.timer("enqueue.enqueue_jobs").time { enqueue_jobs! }
        end
      end

      private

        def enqueue_jobs!
          Travis.run_service(:enqueue_jobs)
        rescue => e
          log_exception(e)
        end

        def declare_exchanges_and_queues
          Travis.logger.info('[enqueue] connecting to amqp')
          channel = Travis::Amqp.connection.create_channel
          channel.exchange 'reporting', durable: true, auto_delete: false, type: :topic
          channel.queue 'builds.linux', durable: true, exclusive: false
        end
    end
  end
end