require 'common/logger'

module SPD
  module Distribute
    class Mailer
      include SPD::Common

      def initialize(sender, subject, body)
        @sender = sender.to_s
        @subject = subject.to_s
        @body = body.to_s
      end

      def send(recipient, attachment_paths = nil)
        if attachment_paths.is_a?(String)
          attachment_paths = [attachment_paths]
        end

        attachment_string = if attachment_paths.empty? then "" else "-a #{attachment_paths.join(" ")}" end
        mail_command = "echo '#{@body}' | EMAIL='#{@sender}' mutt -s '#{@subject}' #{recipient} #{attachment_string}"
        system(mail_command)
      end
    end
  end
end