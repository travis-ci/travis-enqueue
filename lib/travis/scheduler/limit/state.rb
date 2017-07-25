module Travis
  module Scheduler
    module Limit
      class State
        BOOST = 'scheduler.owner.limit.%s'

        attr_reader :owners, :config

        def initialize(owners, config = {})
          @owners = owners
          @config = config
          @count  = { repo: {}, queue: {} }
          @boosts = {}
        end

        def running_by_owners
          @count[:owners] ||= running_jobs_by_owners.count
        end

        def running_by_owners_public
          @count[:public] ||= running_jobs_by_owners.where(private: false).count
        end

        def running_by_repo(id)
          @count[:repo][id] ||= Job.by_repo(id).running.count
        end

        def running_by_queue(queue)
          @count[:queue][queue] ||= Job.by_owners(owners.all).by_queue(queue).running.count
        end

        def boost_for(login)
          @boosts[login] ||= Scheduler.redis.get(BOOST % login).to_i
        end

        private

          def running_jobs_by_owners
            @running_jobs_by_owners ||= Job.by_owners(owners.all).running
          end
      end
    end
  end
end
