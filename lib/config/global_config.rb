require 'toml-rb'
require 'tty-prompt'
require 'uri'

require 'config/base_config'

require 'prereq/file_exists'

require 'distribute/grader'
require 'distribute/graders'

module SPD
  module Config
    class GlobalConfig < BaseConfig
      include SPD::Distribute
      attr_reader :course_url, :graders

      $email_domain_regexp = /^\w+(?:\.\w+)+$/

      def initialize(path)
        super(path) do |config|
          validate_course config
          validate_graders config
          validate_mailing config
        end

        # TODO reintegrate email addresses
        #email_domain = config["mailing"]["email_domain"]
        #@sender_email = config["mailing"]["sender"]

        @course_url = config["course"]["url"]
        @graders = Graders.new(config["graders"].to_a.map do |g|
          grader_id = g[0]
          properties = g[1]

          Grader.new(grader_id, properties["workload"], properties["active"])
        end)
      end

      private

      def validate_course(config)
        descend(config, "course") do |course|
          descend_value(course, "url") do |url|
            unless url =~ URI.regexp
              url = @p.ask("What is the course webpage's base URL?", required: true) do |q|
                q.validate URI.regexp
              end
            end

            url
          end
        end
      end

      def validate_graders(config)
        descend(config, "graders") do |graders|
          # Logic: If there are no graders, run the configuration process for N graders
          #        If there is at least one grader, run the validation process on those graders
          if graders.empty?
            while @p.yes?("Would you like to define another grader?")
              # Get a non-used grader ID
              grader_id = @p.ask("What is this grader's ID?", required: true) do |q|
                q.validate {|id| !graders.has_key? id}
              end

              # By performing descent and validation on the grader ID and an empty properties, it will auto-configure
              descend_value(graders, grader_id) do
                validate_grader(grader_id, {})
              end
            end
          else
            graders.each {|id, properties| validate_grader(id, properties)}
          end
        end
      end

      def validate_grader(grader_id, properties)
        descend_value(properties, "workload") do |workload|
          unless workload && workload > 0
            workload = @p.ask("What is #{grader_id}'s workload?",
                              default: '1', convert: :float) do |q|
              q.validate {|v| v.to_f > 0}
            end
          end

          workload
        end

        descend_value(properties, "active") do |active|
          if active.nil?
            active = @p.yes?("Is #{grader_id} active?")
          end

          active
        end

        properties
      end

      def validate_mailing(config)
        descend(config, "mailing") do |mailing|
          descend_value(mailing, "email_domain") do |email_domain|
            unless email_domain =~ $email_domain_regexp
              email_domain = @p.ask("What is the default email domain for graders?", required: true) {|q|
                q.validate $email_domain_regexp
              }
            end

            email_domain
          end

          descend_value(mailing, "sender") do |sender_email|
            unless sender_email
              sender_email = @p.ask("What should the sender's email be?") {|q| q.validate :email}
            end

            sender_email
          end
        end
      end
    end
  end
end