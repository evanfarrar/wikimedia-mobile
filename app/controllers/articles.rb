class Articles < Application
  provides :wml
  provides :html
  provides :json
  override! :content_type

  def home
    # This whole block is cached here in the controller
    # instead of the Article level... as articles are done.
    cache_block do
      
      request.action_name = "home"
      
      # If we have a specific mobile_main_page
      # maintained at the wiki-admin level, then
      # we render home as if its an article.
      # Except, this article, we tell it its name
      if current_wiki['mobile_main_page']
        @name = current_wiki['mobile_main_page']
        # Call down to the show action
        show
        # Rendering is handled by show
      else
        # This is if we have a specific set of selectors for 
        # the general-purpose main page
        if current_wiki['selectors']
          @main_page = Wikipedia.main_page(request.language_code)
        end
        
        # If we don't have selectors or a mobile_main_page
        # then we just display a search box with nothing below.
        # The home template should know what to do with no
        # @main_page object.
        
        format_display_with_data do
          {:title => "::Home", :html => render(:layout => false)}
        end
      end
    end
  end
  
  def random
    redirect("/wiki/" + Article.random(current_server, params[:variant]))
  end
  
  def show
    # This is to cover the case when we have path's like "/wiki//dev/null"
    # Merb strips the second / and so we are re-instituting it here
    if (request.env["PATH_INFO"] || request.env["REQUEST_PATH"]).include?("/wiki//")
      @name = "/" + current_name
    end

    if /action=([^&]*)/.match(request.env["QUERY_STRING"]) then
        wikiaction = $1
        if wikiaction != "" && wikiaction != "view" then
          redirect "http://#{request.language_code}.wikipedia.org/w/index.php?" + request.env["QUERY_STRING"] + "&useskin=chick"
        end
    end

    if current_name == ""
      redirect(home_page_path)
    else
      # Perform a normal search
      @article = Article.new(current_server, current_name, nil, request.device, params[:variant])
      
      # The inner block is for data formats... aka, JSON and YAML and XML
      # The page is rendered with the template if we aren't doing a special
      # format... so basically, this does "render"
      #
      # Here, we also specify :show, because this #show method is used by
      # some language's home page.... they are more articles than specific
      # home pages.
      format_display_with_data(:show) do
        @article.to_hash(request.device)
      end
    end
  end
  
  def file
    @image = Image.new(current_server, params[:file], nil, request.device, params[:variant])
    render :image
  end

 private 
 
  def format_display_with_data(template_name = nil, &block)
    Merb.logger[:content_type] = content_type

    case content_type
    when :json
      json = JSON.dump(block.call)
      if params[:callback]
        json = "#{params[:callback]}(#{json})"
        
        if(request.device.format_name == :native_iphone)
          json = NativeAppHack.js + "\n" + json
        end
      end
      render json, :format => :json
    else
      case content_type
      when :wml
        @headers["Content-Type"] = "text/vnd.wap.wml; charset=utf-8"
      end
      render template_name, :layout => request.device.with_layout
    end
  end
 
  def content_type
    (params[:format] || request.device.view_format).to_sym
  end
  
  def cache_block(&block)
    begin
      time_to "cache block" do
      
        key = cache_key
        html = Cache.get(key)
      
        if html
          Merb.logger[:cache_hit] = true
          return html
        else
          html = block.call
        
          time_to "store in cache" do
            Cache.set(key, html, 60 * 60 * 3)
          end

          Merb.logger[:cache_hit] = false
        end
        html
      end
    # If memcached is unavailable for some reason, then don't barf... just fetch
    rescue Dalli::DalliError
      return block.call
    end
  end

 protected
  # This is URI encoded.
  def current_name
    @name ||= (params[:search] || params[:title] || "")
  end
  
  def cache_key
    "#{request.language_code}/#{request.device.format_name}/#{content_type}##{params[:callback]}".gsub(" ", "-")
  end
end
