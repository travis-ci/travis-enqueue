require 'travis/config'

module Travis
  module Scheduler
    class Config < Travis::Config
      define amqp:       { username: 'guest', password: 'guest', host: 'localhost', prefetch: 1 },
             database:   { adapter: 'postgresql', database: "travis_#{env}", encoding: 'unicode', min_messages: 'warning' },
             delegate:   { },
             encryption: { key: 'secret' * 10 },
             enterprise: false,
             github:     { api_url: 'https://api.github.com', source_host: 'github.com' },
             interval:   2,
             limit:      { default: 5, by_owner: {}, delegate: {} },
             lock:       { strategy: :redis, ttl: 150 },
             logger:     { time_format: false, process_id: false, thread_id: false },
             log_level:  :info,
             metrics:    { reporter: 'librato' },
             plans:      { },
             queue:      { default: 'builds.gce', redirect: {} },
             redis:      { url: 'redis://localhost:6379' },
             sentry:     { },
             sidekiq:    { namespace: 'sidekiq', pool_size: 3, log_level: :warn },
             ping:       { interval: 5 * 60 },
             site:       ENV['TRAVIS_SITE'] || 'org',
             ssl:        { },
             job_board:  { url: ENV['JOB_BOARD_URL'] || 'https://job-board.travis-ci.org', auth: ENV['JOB_BOARD_AUTH'] || 'user:pass' }

      def metrics
        # TODO fix keychain?
        super.to_h.merge(librato: librato.to_h.merge(source: librato_source), graphite: graphite)
      end
    end
  end
end
