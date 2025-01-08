# frozen_string_literal: true

require 'travis/lock'

module Travis
  module Scheduler
    module Helper
      module Locking
        def exclusive(key, config, opts = {}, &block)
          options = config[:lock].to_h
          options = options.merge(opts)
          options[:ttl] ||= 2
          if options[:strategy] == :redis
            options[:url] ||= config[:redis][:url]
            options[:ssl] ||= config[:redis][:ssl]
            options[:ca_path] ||= ENV['REDIS_SSL_CA_PATH'] if ENV['REDIS_SSL_CA_PATH']
            options[:cert] ||= OpenSSL::X509::Certificate.new(File.read(ENV['REDIS_SSL_CERT_FILE'])) if ENV['REDIS_SSL_CERT_FILE']
            options[:key] ||= OpenSSL::PKEY::RSA.new(File.read(ENV['REDIS_SSL_KEY_FILE'])) if ENV['REDIS_SSL_KEY_FILE']
            options[:verify_mode] ||= OpenSSL::SSL::VERIFY_NONE if config[:ssl_verify] == false
          end
          info "Locking #{key} with: #{options[:strategy]}, ttl: #{options[:ttl]}s"
          options[:ttl] = options[:ttl] * 1000 # RedLock wants milliseconds
          Lock.exclusive(key, options, &block)
        end
      end
    end
  end
end
