require 'travis/config'

module Travis
  module Scheduler
    class Config < Travis::Config
      define  amqp:          { username: 'guest', password: 'guest', host: 'localhost', prefetch: 1 },
              database:      { adapter: 'postgresql', database: "travis_#{env}", encoding: 'unicode', min_messages: 'warning' },
              encryption:    { },
              enterprise:    false,
              github:        { },
              interval:      2,
              limit:         { strategy: 'default', default: 5, by_owner: {}, delegate: {} },
              logger:        { time_format: false, process_id: true, thread_id: true, log_level: :info },
              log_level:     :info,
              metrics:       { reporter: 'librato' },
              notifications: [],
              plans:         { },
              pusher:        { app_id: 'app-id', key: 'key', secret: 'secret', secure: false },
              redis:         { url: 'redis://localhost:6379' },
              sentry:        { },
              sidekiq:       { namespace: 'sidekiq', pool_size: 3 },
              lock:          { strategy: :redis, ttl: 150 },
              ssl:           { },
              cache_settings: { },
              queue_redirections: { },
              oauth2:        { },
              prefer_https:  false
    end
  end
end
