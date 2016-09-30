require 'travis/rollout'

module Travis
  module Scheduler
    module Service
      class Event < Struct.new(:context, :event, :data)
        include Registry, Helper::Context, Helper::Locking, Helper::Logging,
          Helper::Metrics, Helper::Runner, Helper::With

        register :service, :event

        MSGS = {
          receive: 'Received event %s %s=%s for %s',
          ignore:  'Ignoring owner based on rollout: %s (type=%s id=%s)',
          test:    'testing exception handling in Scheduler 2.0'
        }

        def run
          if ENV['ENV'] == 'test' || rollout?(obj.owner)
            info MSGS[:receive] % [event, type, obj.id, repo.owner_name]
            meter
            raise MSGS[:test] if obj.owner.login == 'svenfuchs' && ENV['TEST_SENTRY']
            inline :enqueue_owners, attrs, jid: jid
          else
            debug MSGS[:ignore] % [obj.owner.login, obj.owner_type, obj.owner.id]
          end
        end

        private

          def rollout?(owner)
            Rollout.matches?({ uid: owner.id.to_i, owner: owner.login }, redis: Scheduler.redis)
          end

          def meter
            super(event.sub(':', '.'))
          end

          def attrs
            { owner_type: obj.owner_type, owner_id: obj.owner_id }
          end

          def obj
            @obj ||= Kernel.const_get(type.capitalize).find(data[:id])
          end

          def repo
            obj.repository
          end

          def state
            @state ||= State.new(owners, config)
          end

          def owners
            Owners.new(data, config)
          end

          def type
            event.split(':').first
          end

          def action
            event.split(':').last
          end

          def jid
            data[:jid]
          end
      end
    end
  end
end
