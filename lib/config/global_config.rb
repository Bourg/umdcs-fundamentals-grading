require 'toml-rb'
require 'tty-prompt'
require 'prereq/file_exists'
require 'uri'

require 'entities/grader'
require 'entities/graders'

module SPD
  module Config
    class GlobalConfig
      include SPD::Entities

      private_class_method :new
      attr_reader :course_url, :graders

      $non_grader_subsections = ["email_domain"]
      $email_domain_regexp = /^\w+(?:\.\w+)+$/

      def initialize(path)
        # Attempt to load
        if File.file?(path)
          config = TomlRB.load_file(path)
        else
          config = {}
        end

        @p = TTY::Prompt.new
        @config = config

        validate_course
        validate_graders
        validate_mailing

        File.write(path, TomlRB.dump(@config))

        # TODO reintegrate email addresses
        #email_domain = config["mailing"]["email_domain"]

        @course_url = config["url"]
        @graders = Graders.new(select_actual_graders(config["graders"]).to_a.map do |g|
          grader_id = g[0]
          properties = g[1]

          Grader.new(grader_id, properties["workload"], properties["active"])
        end)
        @sender_email = config["mailing"]["sender"]
      end

      def self.load_from_file(path)
        new(path)
      end

      private

      def validate_course
        descend(@config, "course") do |course|
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

      def validate_graders
        descend(@config, "graders") do |graders|
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

      def validate_mailing
        descend(@config, "mailing") do |mailing|
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

      def descend(hash, key)
        sub = hash.fetch(key, {})
        sub = {} unless sub.is_a? Hash

        yield sub
        hash[key] = sub
      end

      def descend_value(hash, key)
        hash[key] = yield hash[key]
      end

      def select_actual_graders(graders_section)
        graders_section.reject {|grader_id| $non_grader_subsections.include? grader_id}
      end
    end
  end
end