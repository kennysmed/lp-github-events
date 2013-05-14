# coding: utf-8
require 'json'
require 'oauth2'
require 'sinatra'

enable :sessions

configure do
end


helpers do
  def consumer
    OAuth2::Client.new(ENV['GITHUB_CLIENT_ID'], ENV['GITHUB_CLIENT_SECRET'],
      {
        :site => 'https://api.github.com',
        :authorize_url => 'https://github.com/login/oauth/authorize',
        :token_url => 'https://github.com/login/oauth/access_token'
      }
    )
  end
end


get '/' do
  "Little Printer Github Events Publication"
end


# The user has just come here from BERG Cloud to authenticate with Github.
get '/configure/' do
  # Save these for use when the user returns.
  session[:bergcloud_return_url] = params['return_url']
  session[:bergcloud_error_url] = params['error_url']

  # Send them to Github to approve us.
  url = consumer.auth_code.authorize_url(
    :redirect_uri => url('/configure/return/'),
    :scope => 'repo:status' # Also use notifications?
  )
  redirect url
end


# The user has returned here from approving us (or not) at Github.
# URL be a subdirectory of the calling URL.
# This URL is also specified in the Github application.
get '/configure/return/' do
  # If there's no code returned, something went wrong, or the user declined
  # to authenticate us. This is the least nasty thing we can do right now:
  redirect session[:bergcloud_error_url] if !params[:code]

  begin
    access_token = consumer.auth_code.get_token(
                                  params[:code], :redirect_uri => url('/configure/return'))
    query = URI.encode_www_form('config[access_token]' => access_token.token)
    redirect session[:bergcloud_return_url] + '?' + query 
  rescue OAuth::Error => e
    puts "OAuth error: #{$!}"
    redirect session[:bergcloud_error_url]
  end
end


# BERG CLoud is requesting an edition for a user.
# We'll get an access_token that lets us authenticate as this user.
get '/edition/' do
  request = OAuth2::AccessToken.new(consumer, params[:access_token]) 

  # We need the user's details:
  user = JSON.parse(request.get('/user').body)

  # Fetch events this user has received:
  @events = JSON.parse(request.get("/users/#{user['login']}/received_events").body)

  if @events.length == 0
    etag Digest::MD5.hexdigest(params[:access_token] + Date.today.strftime('%d%m%Y'))
    return 204, "User #{user['login']} has no events to show"
  end

  if (Time.now.utc - Time.parse(@events.first['created_at'])) > 86400
    etag Digest::MD5.hexdigest(params[:access_token] + Date.today.strftime('%d%m%Y'))
    return 204, "No events for #{user['login']} in past 24 hours"
  end

  # etag Digest::MD5.hexdigest(params[:access_token] + Date.today.strftime('%d%m%Y'))
  # Testing, always changing etag:
  etag Digest::MD5.hexdigest(params[:access_token] + Time.now.strftime('%M%H-%d%m%Y'))
  erb :publication
end


get '/sample/' do
  erb :publication
end


post '/validate_config/' do
end

