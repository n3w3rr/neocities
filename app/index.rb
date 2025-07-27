get '/?' do
  if current_site
    require_login

    redirect '/dashboard' if current_site.is_education

    @page = params[:page]
    @page = 1 if @page.not_an_integer?

    if params[:activity] == 'mine'
      events_dataset = current_site.latest_events(@page)
    elsif params[:event_id]
      event = Event.select(:id).where(id: params[:event_id]).first
      not_found if event.nil?
      not_found if event.is_deleted
      events_dataset = Event.where(id: params[:event_id]).paginate(1, 1)
    else
      events_dataset = current_site.news_feed(@page)
    end

    @pagination_dataset = events_dataset
    @events = events_dataset.all

    current_site.events_dataset.update notification_seen: true

    halt erb :'home', locals: {site: current_site}
  end

  if SimpleCache.expired?(:sites_count)
    @sites_count = SimpleCache.store :sites_count, Site.count.roundup(100), 4.hours
  else
    @sites_count = SimpleCache.get :sites_count
  end

  if SimpleCache.expired?(:total_hits_count)
    @total_hits_count = SimpleCache.store :total_hits_count, DB['SELECT SUM(hits) AS hits FROM SITES'].first[:hits], 4.hours
  else
    @total_hits_count = SimpleCache.get :total_hits_count
  end

  @total_hits_count ||= 0

  if SimpleCache.expired?(:total_views_count)
    @total_views_count = SimpleCache.store :total_views_count, DB['SELECT SUM(views) AS views FROM SITES'].first[:views], 4.hours
  else
    @total_views_count = SimpleCache.get :total_views_count
  end

  @total_views_count ||= 0

  if SimpleCache.expired?(:changed_count)
    @changed_count = SimpleCache.store :changed_count, DB['SELECT SUM(changed_count) AS changed_count FROM SITES'].first[:changed_count], 4.hours
  else
    @changed_count = SimpleCache.get :changed_count
  end

  @changed_count ||= 0

=begin
  if SimpleCache.expired?(:blog_feed_html)
    @blog_feed_html = ''

    begin
      xml = HTTP.timeout(global: 2).get('https://blog.neocities.org/feed.xml').to_s
      feed = Feedjira::Feed.parse xml
      feed.entries[0..2].each do |entry|
        @blog_feed_html += %{<a href="#{entry.url}">#{entry.title.split('.').first}</a> <span style="float: right">#{entry.published.strftime('%b %-d, %Y')}</span><br>}
      end
    rescue
      @blog_feed_html = 'The latest news on Neocities can be found on our blog.'
    end

    @blog_feed_html = SimpleCache.store :blog_feed_html, @blog_feed_html, 8.hours
  else
    @blog_feed_html = SimpleCache.get :blog_feed_html
  end
=end

@blog_feed_html = 'The latest news on Neocities can be found on our blog.'

  if SimpleCache.expired?(:featured_sites)
    @featured_sites = Site.order(:score.desc).exclude(is_nsfw: true).exclude(is_deleted: true).limit(1000).all.sample(12).collect {|s| {screenshot_url: s.screenshot_url('index.html', '540x405'), uri: s.uri, title: s.title}}
    SimpleCache.store :featured_sites, @featured_sites, 1.hour
  else
    @featured_sites = SimpleCache.get :featured_sites
  end

  @create_disabled = false

  erb :index, layout: :index_layout
end

get '/welcome' do
  require_login
  redirect '/' if current_site.supporter?
  @title = 'Welcome!'
  erb :'welcome', locals: {site: current_site}
end

get '/education' do
  redirect '/' if signed_in?
  erb :education, layout: :index_layout
end

get '/donate' do
  erb :'donate'
end

get '/about' do
  erb :'about'
end

get '/terms' do
  erb :'terms'
end

get '/privacy' do
  erb :'privacy'
end

get '/press' do
  erb :'press'
end

get '/legal/?' do
  @title = 'Legal Guide to Neocities'
  erb :'legal'
end

get '/thankyou' do
  @title = 'Thank you!'
  erb :'thankyou'
end

get '/cli' do
  @title = 'Command Line Interface'
  erb :'cli'
end

get '/forgot_username' do
  @title = 'Forgot Username'
  erb :'forgot_username'
end

post '/forgot_username' do
  if params[:email].blank?
    flash[:error] = 'Cannot use an empty email address!'
    redirect '/forgot_username'
  end

  begin
    sites = Site.get_recovery_sites_with_email params[:email]
  rescue ArgumentError
    redirect '/forgot_username'
  end

  sites.each do |site|
    body = <<-EOT
Hello! This is the Neocities cat, and I have received a username lookup request using this email address.

Your username is #{site.username}

If you didn't request this, you can ignore it. Or hide under a bed. Or take a nap. Your call.

Meow,
the Neocities Cat
    EOT

    body.strip!

    EmailWorker.perform_async({
      from: Site::FROM_EMAIL,
      to: params[:email],
      subject: '[Neocities] Username lookup',
      body: body
    })

  end

  flash[:success] = 'If your email was valid, the Neocities Cat will send an e-mail with your username in it.'
  redirect '/'
end
