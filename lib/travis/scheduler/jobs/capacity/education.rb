require 'travis/scheduler/helper/memoize'

module Travis
  module Scheduler
    module Jobs
      module Capacity
        class Education < Base
          include Helper::Memoize

          def applicable?
            !on_metered_plan? && com? && educational?
          end

          def accept?(job)
            super if educational?
          end

          def report(status, job)
            super.merge(max: max)
          end

          private

            def max
              @max ||= config[:limit][:education] || 0
            end

            def educational?
              owners.educational?
            end
            memoize :educational?

            def com?
              config.com?
            end
        end
      end
    end
  end
end
