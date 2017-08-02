module Travis
  module Owners
    module Cli
      class Group < Cl::Cmd

        register 'owners:group'

        purpose 'Group owners into a new owner group'

        arg :owners, type: :array

        MSGS = {
          count:   'You need to pass at least 2 owner logins.',
          unknown: 'Unknown owners: %s.',
          grouped: 'The following owners already are in an owner group: %s. Please use the `owners add` command.',
          confirm: 'This will group the following owners: %s. Confirm? [y/n]',
          done:    'Done. These owners are now grouped.'
        }

        def run
          validate
          confirm
          create
        end

        private

          def validate
            abort MSGS[:count] if args.size < 2

            unknown = args - owners.map(&:login)
            abort MSGS[:unknown] % unknown.join(', ') if unknown.any?

            logins = owners.select(&:owner_group).map(&:login)
            abort MSGS[:grouped] % logins.join(', ') if logins.any?
          end

          def confirm
            puts MSGS[:confirm] % owners.map(&:login).join(', ')
            input = STDIN.gets.chomp.downcase
            abort 'Aborting.' unless input == 'y'
          end

          def create
            owners.each { |owner| OwnerGroup.create!(uuid: uuid, owner: owner) }
            puts MSGS[:done]
          end

          def uuid
            @uuid ||= SecureRandom.uuid
          end

          def owners
            @owners_ ||= User.where(login: logins) + Organization.where(login: logins)
          end

          def logins
            args
          end
      end
    end
  end
end
