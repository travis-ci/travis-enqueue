# frozen_string_literal: true

require 'forwardable'
require 'travis/scheduler/serialize/worker/config'

module Travis
  module Scheduler
    module Serialize
      class Worker
        class Job < Struct.new(:job, :config)
          extend Forwardable

          def_delegators :job, :id, :repository, :source, :commit, :number,
                         :queue, :state, :debug_options, :queued_at, :allow_failure, :stage, :name, :restarted_at, :restarted_by
          def_delegators :source, :request

          def env_vars
            Travis.logger.info "Starting env vars logic"

            # TODO Add timestamp to the logs to check the performance with/out account envs
            vars = repository.settings.env_vars
            vars = vars.public unless secure_env?

            mapped_vars = vars.map { |var| env_var(var) }
            Travis.logger.info "Repo env vars processed"
            return mapped_vars unless pull_request? && repository.fork?

            # TODO Check that the build is not forked or PR
            account_vars = account_env_vars
            Travis.logger.info "Mapped account env vars: #{account_vars}"

            repo_var_hash     = mapped_vars.map { |v| [v[:name], v] }.to_h
            account_var_hash  = account_vars.map { |v| [v[:name], v] }.to_h

            final_vars_hash = repo_var_hash.merge(account_var_hash)

            final_vars = final_vars_hash.values
            Travis.logger.info "Merged env vars: #{final_vars}"

            final_vars
          end

          def account_env_vars
            Travis.logger.info "Fetching account env vars for owner: #{job.owner_id} with owner type: #{job.owner_type}"
            vars = AccountEnvVars.where(owner_id: job.owner_id, owner_type: job.owner_type)
            Travis.logger.info "Results for owner: #{job.owner_id}, variables: #{vars}"
            vars.map { |var| account_env_var(var) }
          end

          def secure_env?
            defined?(@secure_env) ? @secure_env : (@secure_env = (!pull_request? || secure_env_allowed_in_pull_request?))
          end

          def pull_request?
            source.event_type == 'pull_request'
          end

          def secure_env_allowed_in_pull_request?
            repository.settings.share_encrypted_env_with_forks || request.same_repo_pull_request?
          end

          def secure_env_removed?
            !secure_env? && job.repository.settings.has_secure_vars?
          end

          def ssh_key
            job.config[:source_key]
          end

          def decrypted_config
            secure = Travis::SecureConfig.new(repository_key)
            Config.decrypt(job.config, secure, full_addons: true, secure_env: true)
          end

          def secrets
            secrets = Config.secrets(job.config)
            secrets.map { |str| decrypt(str) }.compact
          end

          def decrypt(str)
            repository_key.decrypt(Base64.decode64(str)) if str.is_a?(String)
          rescue OpenSSL::PKey::RSAError => e
          end

          def vm_config
            # we'll want to see out what kinds of vm_config sets we have and
            # then decide how to best map what to where. at this point that
            # decision is yagni though, so i'm just picking :gpu as a key here.
            vm_config? && vm_configs[:gpu] ? vm_configs[:gpu].to_h : {}
          end

          def vm_size
            job.config.dig(:vm, :size)
          end

          def trace?
            Rollout.matches?(:trace, uid: SecureRandom.hex, owner: repository.owner.login, repo: repository.slug, redis: Scheduler.redis)
          end

          def warmer?
            Rollout.matches?(:warmer, uid: SecureRandom.hex, owner: repository.owner.login, repo: repository.slug, redis: Scheduler.redis)
          end

          def restarted_by_login
            User.find(restarted_by).login if restarted_by
          end

          private

          def env_var(var)
            { name: var.name, value: var.value.decrypt, public: var.public, branch: var.branch }
          end

          def account_env_var(var)
            { name: var.name, value: var.value, public: var.public, branch: nil }
          end


          def has_secure_vars?(key)
            job.config.key?(key) &&
              job.config[key].respond_to?(:key?) &&
              job.config[key].key?(:secure)
          end

          def vm_config?
            Features.active?(:resources_gpu, repository) && job.config.dig(:resources, :gpu)
          end

          def vm_configs
            config[:vm_configs] || {}
          end

          def job_repository
            return job.repository if job.source.event_type != 'pull_request' || job.source.request.pull_request.head_repo_slug == job.source.request.pull_request.base_repo_slug

            return repository if repository.settings.share_encrypted_env_with_forks

            owner_name, repo_name = job.source.request.pull_request.head_repo_slug.split('/')
            return if owner_name.nil? || owner_name.empty? || repo_name.nil? || repo_name.empty?

            ::Repository.find_by(owner_name: owner_name, name: repo_name)
          end

          def repository_key
            job_repository&.key || ::SslKey.new(private_key: 'test')
          end
        end
      end
    end
  end
end
