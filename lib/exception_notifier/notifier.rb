require 'action_mailer'
require 'pp'

class ExceptionNotifier
  class Notifier < ActionMailer::Base
    self.mailer_name = 'exception_notifier'
    self.append_view_path "#{File.dirname(__FILE__)}/views"
    
    @default_sender_address = %("Exception Notifier" <exception.notifier@default.com>)
    @default_exception_recipients = []
    @default_email_prefix = "[ERROR] "
    @default_sections = %w(request session environment backtrace)
    
    class << self
      attr_accessor :default_sender_address,
                    :default_exception_recipients,
                    :default_email_prefix,
                    :default_sections
      
      def default_options
        { :sender_address => default_sender_address,
          :exception_recipients => default_exception_recipients,
          :email_prefix => default_email_prefix,
          :sections => default_sections }
      end
      
      def safely_deliver_exception_notification(*args)
        begin
          ExceptionNotifier::Notifier.exception_notification(*args).deliver
        rescue
          begin
            Rails.logger.error "[exception_notification] #{$!}\n#{$!.backtrace.join("\n")}"
          rescue
          end
        end
      end
    end

    class MissingController
      def method_missing(*args, &block)
      end
    end

    def exception_notification(*args)
      options     = args.extract_options!
      @env        = options[:env]
      @exception  = args.first || $!
      @exception  = Exception.new(@exception) if @exception.is_a?(String)
      @options    = ((@env ? @env['exception_notifier.options'] : nil) || {}).merge(options).reverse_merge(self.class.default_options)
      @kontroller = (@env ? @env['action_controller.instance'] : nil) || MissingController.new
      @request    = @env ? ActionDispatch::Request.new(@env) : nil
      @backtrace  = clean_backtrace(@exception)
      data        = options[:data] || (@env ? @env['exception_notifier.exception_data'] : nil) || {}
      @sections   = @options[:sections]
      @sections << "data" unless data.blank?

      data.each do |name, value|
        instance_variable_set("@#{name}", value)
      end

      prefix   = "#{@options[:email_prefix]}#{@kontroller.controller_name}##{@kontroller.action_name}"
      subject  = "#{prefix} (#{@exception.class}) #{@exception.message.inspect}"

      mail(:to => @options[:exception_recipients], :from => @options[:sender_address], :subject => subject) do |format|
        format.text { render "#{mailer_name}/exception_notification" }
      end
    end

    private
      
      def clean_backtrace(exception)
        Rails.respond_to?(:backtrace_cleaner) ?
          Rails.backtrace_cleaner.send(:filter, (exception.backtrace || "")) :
          exception.backtrace || ""
      end
      
      helper_method :inspect_object
      
      def inspect_object(object)
        case object
        when Hash, Array
          object.inspect
        when ActionController::Base
          "#{object.controller_name}##{object.action_name}"
        else
          object.to_s
        end
      end
      
  end
end
