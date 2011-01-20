require 'pathname'

# Copyright (c) 2005 Jamis Buck
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
class ExceptionNotification::Notifier < ActionMailer::Base
  self.mailer_name = 'exception_notifier'
  self.view_paths << "#{File.dirname(__FILE__)}/../../views"
  
  @@sender_address = %("Exception Notifier" <exception.notifier@default.com>)
  cattr_accessor :sender_address
  
  @@exception_recipients = []
  cattr_accessor :exception_recipients
  
  @@email_prefix = "[ERROR] "
  cattr_accessor :email_prefix
  
  @@sections = %w(request session environment backtrace)
  cattr_accessor :sections
  
  def self.reloadable?() false end
  
  def self.safely_deliver_exception_notification(*args)
    begin
      options = args.
      ExceptionNotification::Notifier.deliver_exception_notification(*args)
    rescue
      begin
        Rails.logger.error "[exception_notification] #{$!}\n#{$!.backtrace}"
      rescue
      end
    end
  end
  
  def exception_notification(*args)
    options = args.extract_options!
        
    exception = options[:exception] || $!
    exception = Exception.new(exception) if exception.is_a?(String)
    
    controller = args.first || options[:controller]
    request = controller.respond_to?(:request) ? controller.request : nil
    source = self.class.exception_source(controller)
    
    sections, data = self.sections.dup, (options[:data] || {})
    sections.unshift("data") unless data.empty?
    
    content_type "text/plain"
    
    subject    "#{email_prefix}#{source} (#{exception.class}) #{exception.message.inspect}"
    
    recipients exception_recipients
    from       sender_address
    
    body       ({
                  :controller => controller,
                  :request => request,
                  :exception => exception,
                  :exception_source => source,
                  :host => (request ? (request.env["HTTP_X_FORWARDED_HOST"] || request.env["HTTP_HOST"]) : "unknown"),
                  :backtrace => sanitize_backtrace(exception.backtrace),
                  :rails_root => rails_root,
                  :data => data,
                  :sections => (options[:sections] || (sections - (options[:except_sections]||[]))).uniq
               })
  end
  
  def self.exception_source(controller)
    if controller.respond_to?(:controller_name)
      "in #{controller.controller_name}##{controller.action_name}"
    else
      "outside of a controller"
    end
  end
  
  
  
private
  
  
  
  def sanitize_backtrace(trace)
    return [] if trace.blank?
    # re = Regexp.new(/^#{Regexp.escape(rails_root)}/) # <-- redundant?
    re = /^#{Regexp.escape(rails_root)}/
    trace.map { |line| Pathname.new(line.gsub(re, "[RAILS_ROOT]")).cleanpath.to_s }
  end
  
  def rails_root
    @rails_root ||= Pathname.new(RAILS_ROOT).cleanpath.to_s
  end
  
  
  
end
