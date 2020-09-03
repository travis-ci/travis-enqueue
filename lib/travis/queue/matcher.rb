module Travis
  class Queue
    class Matcher < Struct.new(:job, :config, :logger)
      KEYS = %i(slug owner os language sudo dist group osx_image percentage
        resources services arch virt)

      MSGS = {
        unknown_matchers: 'unknown matchers used for queue %s: %s (repo=%s)"'
      }

      OSS_ONLY_ARCH = %w(arm64 ppc64le s390x)

      def matches?(attrs)
        puts '----------matches start-------------'
        puts 'sb-scheduler-debugging-matches'
        puts "attrs is: #{attrs}"
        puts "keys is: #{attrs.keys}"
        puts "job is: #{job}"
        puts '----------matches end-------------'
        check_unknown_matchers(attrs.keys)
        matches = matches_for(attrs)
        matches.any? && matches.all? { |key, value| value === attrs[key] }
      end

      private

        def matches_for(attrs)
          (KEYS & attrs.keys).map { |key| [key, send(key)] }.to_h
        end

        def slug
          repo.slug
        end

        def owner
          repo.owner_name
        end

        def os
          job.config[:os]
        end

        def language
          Array(job.config[:language]).flatten.compact.first
        end

        def sudo
          job.config[:sudo]
        end

        def dist
          job.config[:dist]
        end

        def group
          job.config[:group]
        end

        def osx_image
          job.config[:osx_image]
        end

        def percentage
          ->(percent) { rand(100) < percent }
        end

        def services
          ->(services) { (Array(job.config[:services]) & services).any? }
        end

        def repo
          job.repository
        end

        def resources
          resources_enabled? && job.config[:resources] || {}
        end

        def arch
          return nil if job.private? && OSS_ONLY_ARCH.include?(job.config[:arch])

          job.config[:arch]
        end

        def virt
          job.config[:virt]
        end

        def resources_enabled?
          Travis::Features.active?(:vm_config, repo)
        end

        def check_unknown_matchers(used)
          unknown = used - KEYS
          logger.warn MSGS[:unknown_matchers] % [used, unknown, repo.slug] if logger && unknown.any?
        end
    end
  end
end
