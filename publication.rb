# coding: utf-8
require 'oauth2'
require 'sinatra'

enable :sessions

configure do
end


helpers do
  def oauth_client
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


get '/edition/' do
  erb :publication
end


get '/configure/' do
  url = oauth_client.auth_code.authorize_url(
    :redirect_uri => params[:return_url],
    :scope => 'repo:status' # Also use notifications?
  )
  redirect url
end


# Must be a subdirectory of the calling URL.
# This URL is specified in the Github application.
get '/configure/return/' do
  begin
    access_token = oauth_client.auth_code.get_token(
                                  params[:code], :redirect_uri => redirect_uri)
    query = URI.encode_www_form('config[access_token]' => access_token.token)
    redirect params[:return_url] + '?' + query 
  rescue OAuth::Error => e
    puts "OAuth error: #{$!}"
    redirect params[:error_url]
  end
end


get '/sample/' do
  erb :publication
end


post '/validate_config/' do
end

