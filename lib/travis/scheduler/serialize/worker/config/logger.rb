# Example: config/initializers/logger.rb

require 'travis/logger'

Travis.logger.formatter = proc do |severity, datetime, progname, msg|
  # Use strftime with '%L' for millisecond precision
  formatted_time = datetime.strftime('%Y-%m-%d %H:%M:%S.%L')

  "[#{formatted_time}] #{severity}: #{msg}\n"
end
