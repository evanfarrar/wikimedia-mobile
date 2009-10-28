module ControllerExtensions
  module Logging
    def self.included(klass)
      klass.before :start_timer
      klass.after :logger_output
      
      # DEVELOPMENT
      if Merb.env == "development"
        klass.before :clear_cache
      end
    end
    
    def start_timer
      @timer = Time.now
    end

    def logger_output
      action_time = @timer ? (Time.now - @timer) : nil

      logged_data = {:time => Time.now.to_s, 
                     :action_time => action_time,
                     :language_code => request.language_code, 
                     :country_code => request.country_code,
                     :user_agent => request.user_agent,
                     :referer => request.referer,
                     :format_name => request.device.format_name,
                     :was_redirected => params[:wasRedirected],
                     :was_home_page => (params[:action] == "home")
                     }

      if @article
        logged_data[:article_title] = @article.title
      end

      # This is an extension that we added to logger
      logged_data.merge!(Merb.logger.dump_logger_hash)

      # Dump it out!
      yaml = logged_data.to_yaml
      yaml_flat = yaml.gsub("\n", "\\n")
      Merb.logger.warn("~~~~" + yaml_flat)
    end

    def clear_cache
      Cache.clear
    end

    
  end
end