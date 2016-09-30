require 'forwardable'

module Travis
  module Scheduler
    module Serialize
      class Worker
        class Repo < Struct.new(:repo, :config)
          extend Forwardable

          def_delegators :repo, :id, :github_id, :slug,
            :last_build_id, :last_build_number, :last_build_started_at,
            :last_build_finished_at, :last_build_duration, :last_build_state,
            :description, :key, :settings, :private?

          def vm_type
            Features.active?(:premium_vms, repo) ? :premium : :default
          end

          def timeouts
            { hard_limit: timeout(:hard_limit), log_silence: timeout(:log_silence) }
          end

          def api_url
            "#{config[:github][:api_url]}/repos/#{slug}"
          end

          def source_url
            private? || force_private? ? source_git_url : source_http_url
          end

          private

            def env_var(var)
              { name: var.name, value: var.value.decrypt, public: var.public }
            end

            def timeout(type)
              return unless timeout = repo.settings.send(:"timeout_#{type}")
              timeout = Integer(timeout)
              timeout * 60 # worker handles timeouts in seconds
            end

            def force_private?
              source_host != 'github.com'
            end

            def source_http_url
              "https://#{source_host}/#{slug}.git"
            end

            def source_git_url
              "git@#{source_host}:#{slug}.git"
            end

            def source_host
              config[:github][:source_host] || 'github.com'
            end
        end
      end
    end
  end
end
