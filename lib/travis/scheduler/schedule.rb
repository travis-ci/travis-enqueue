require 'multi_json'

require 'core_ext/kernel/run_periodically'
require 'travis/support/amqp'
require 'travis/support/database'
require 'travis/scheduler/helpers/locking'
require 'travis/scheduler/services/enqueue_jobs'
require 'travis/support/exceptions'
require 'travis/scheduler/support/sidekiq'

module Travis
  module Scheduler
    class Schedule
      extend Travis::Exceptions::Handling
      include Helpers::Locking

      def setup
        Travis::Amqp.config = config.amqp.to_h
        Travis::Database.connect(config.database.to_h)
        Travis::Exceptions::Reporter.start
        Travis::Metrics.setup
        Support::Sidekiq.setup(config)
        Support::Features.setup(config)

        declare_exchanges_and_queues
      end

      def run
        enqueue_jobs_periodically
      end

      private

        def enqueue_jobs_periodically
          run_periodically(Travis.config.interval) do
            time { enqueue_jobs }
          end
          sleep
        end

        def enqueue_jobs
          exclusive do
            Services::EnqueueJobs.run
          end
        end
        rescues :enqueue_jobs

        def declare_exchanges_and_queues
          channel = Travis::Amqp.connection.create_channel
          channel.exchange 'reporting', durable: true, auto_delete: false, type: :topic
          channel.queue 'builds.linux', durable: true, exclusive: false
        end

        def time(&block)
          Metriks.timer('schedule.enqueue_jobs').time(&block)
        end

        def exclusive(&block)
          super('schedule.enqueue_jobs', &block)
        end

        def config
          Scheduler.config
        end
    end
  end
end
