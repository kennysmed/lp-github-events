# coding: utf-8
require 'github_api'
require 'json'
require 'sinatra'

enable :sessions

raise 'GITHUB_CLIENT_ID_USER is not set' if !ENV['GITHUB_CLIENT_ID_USER']
raise 'GITHUB_CLIENT_SECRET_USER is not set' if !ENV['GITHUB_CLIENT_SECRET_USER']
raise 'GITHUB_CLIENT_ID_ORGANIZATION is not set' if !ENV['GITHUB_CLIENT_ID_ORGANIZATION']
raise 'GITHUB_CLIENT_SECRET_ORGANIZATION is not set' if !ENV['GITHUB_CLIENT_SECRET_ORGANIZATION']

configure do
  if settings.development?
    # So we can see what's going wrong on Heroku.
    set :show_exceptions, true
  end

  # The different varieties of data we can display.
  # Each publication has a different variety.
  # The variety is the top-level directory.
  #   * received - The user's public and private 'received events'.
  #   * organization - The events for an organization.
  set :valid_varieties, ['received', 'organization']

  # The default variety, which can be changed with different URLs.
  set :variety, 'received'

  # If we're fetching data for an organization in /edition/, this will get set.
  # eg, 'bergcloud'.
  set :organization_login, nil
end


helpers do
  # Set the variety setting to `variety` if it's valid. Else, stay with default.
  def set_variety(variety)
    settings.variety = variety if settings.valid_varieties.include?(variety)
  end

  def github_client_id
    if settings.variety == 'organization'
      return ENV['GITHUB_CLIENT_ID_ORGANIZATION']
    else
      return ENV['GITHUB_CLIENT_ID_USER']
    end
  end

  def github_client_secret
    if settings.variety == 'organization'
      return ENV['GITHUB_CLIENT_SECRET_ORGANIZATION']
    else
      return ENV['GITHUB_CLIENT_SECRET_USER']
    end
  end

  ########################################################################
  # Wrappers for using the github api.

  # Make a github client instance when the user is going through the OAuth process.
  def consumer
    Github.new(
      :client_id => github_client_id(),
      :client_secret => github_client_secret()
    )
  end

  # Make a github client instance using the stored access_token.
  def github_from_access_token(access_token)
    begin
      return Github.new(
        :client_id => github_client_id(),
        :client_secret => github_client_secret(),
        :oauth_token => access_token
      )
    rescue Github::Error::GithubError => error
      halt 500, "Something went wrong when authenticating with the access_token: #{error}"
    end
  end

  # Get data about a GitHub user.
  # github is a Github client instance.
  def get_user_data(github)
    begin
      return github.users.get
    rescue Github::Error::GithubError => error
      halt 500, "Something went wrong fetching user data: #{error}"
    end
  end

  # Get data about a GitHub organization.
  # github is a Github client instance.
  # orgnization_login is like 'bergcloud' or 'rig'.
  def get_organization_data(github, organization_login)
    begin
      return github.orgs.get(organization_login)
    rescue Github::Error::GithubError => error
      halt 500, "Something went wrong fetching organization data: #{error}"
    end
  end

  # Get the list of a GitHub user's organizations.
  # github is a Github client instance.
  def get_users_organizations(github)
    begin
      return github.orgs.list
    rescue Github::Error::GithubError => error
      halt 500, "Something went wrong fetching organizations for the user: #{error}"
    end
  end

  # Get one page of events for a GitHub user, or a particular organization,
  # from the user's point of view.
  # If organization_login isn't supplied, it's the former.
  # github is a Github client instance.
  def get_users_events(github, user_login, organization_login=nil)
    error_msg = "Something went wrong fetching events for user '#{user_login}'"
    if organization_login
      error_msg += " and organization '#{organization_login}'"
    end

    begin
      if organization_login
        return github.activity.events.user_org(:user => user_login,
                                              :org_name => organization_login)
      else
        return github.activity.events.received(user_login)
      end
    rescue Github::Error::GithubError => error
      error_msg += ": #{error}"
      halt 500, error_msg
    end
  end

  ########################################################################
  # Helpers used in templates.

  # So that we keep the title consistent in all the places.
  def format_title
    "GitHub Events"
  end

  def format_full_title
    title = format_title
    if settings.variety == 'organization'
      title += " for Organizations"
    end
    return title
  end

  # Used in the template for pluralizing words.
  def pluralize(num, word, ext='s')
    if num.to_i == 1
      return num.to_s + ' ' + word
    else
      return num.to_s + ' ' + word + ext
    end
  end

  # Used in the template for truncating strings at word boundaries.
  def truncate(text, len, end_string='…')
    words = text.split()
    return words[0...len].join(' ') + (words.length > len ? end_string : '')
  end

  # Used in the template for formatting repo names.
  def format_repo(name)
    user, repo = name.split('/')
    repo_html = '<span class="repo-name">' + repo + '</span>'
    if settings.variety == 'organization' and user == settings.organization_login
      return repo_html
    else
      return user + '/' + repo_html
    end
  end
end


get '/favicon.ico' do
  status 410
end


get %r{^/(received|organization)/meta.json$} do |variety|
  set_variety(variety)
  content_type :json
  erb :meta
end


get %r{^/(received|organization)/$} do |variety|
  set_variety(variety)
  output = "Little Printer GitHub Events Publication"
  if variety == 'organization'
    output += " for an Organization"
  end
  output
end


# The user has just come here from BERG Cloud to authenticate with GitHub.
get %r{^/(received|organization)/configure/$} do |variety|
  set_variety(variety)

  # Save these for use when the user returns.
  session[:bergcloud_return_url] = params['return_url']
  session[:bergcloud_error_url] = params['error_url']

  # For individual public/private events, we just need 'repo:status' scope.
  # For access to organizations we need the full 'repo' scope.
  scope = settings.variety == 'organization' ? 'repo' : 'repo:status'

  # Send them to GitHub to approve us.
  url = consumer.authorize_url(
    :redirect_uri => url("/#{settings.variety}/return/"),
    :scope => scope
  )
  redirect url
end


# The user has returned here from approving us (or not) at GitHub.
get %r{^/(received|organization)/return/$} do |variety|
  set_variety(variety)

  # If there's no code returned, something went wrong, or the user declined
  # to authenticate us. This is the least nasty thing we can do right now:
  redirect session[:bergcloud_error_url] if !params[:code]

  begin
    access_token = consumer.get_token(params[:code],
                          :redirect_uri => url("/#{settings.variety}/return/"))
  rescue Github::Error::GithubError => error
    # Debugging:
    # return "Github error: #{error}"
    redirect session[:bergcloud_error_url]
  end

  if settings.variety == 'organization'
    # We need to ask the user to choose an organization.
    # Save the access_token for after that's done.
    session[:access_token] = access_token.token
    redirect url("/organization/select-org/")

  else
    # Standard version for a user's events. No local config required.
    # Send them straight back to the Remote.
    query = URI.encode_www_form('config[access_token]' => access_token.token)
    redirect session[:bergcloud_return_url] + '?' + query 
  end
end


# User has come here after authenticating with GitHub, and they're using the
# Organization variety of publication.
# Now they need to choose one of their organizations.
get '/organization/select-org/' do
  set_variety('organization')

  github = github_from_access_token(session[:access_token])

  @user = get_user_data(github)

  @orgs = get_users_organizations(github)

  if session[:form_error]
    @form_error = session[:form_error]
    session[:form_error] = nil
  end

  erb :select_org
end


# The user has selected one of their organizations in our custom form, so now
# we need to check it's valid then, if so, send them back to Remote with the
# organization ID in the config vars.
post '/organization/select-org/' do
  set_variety('organization')

  if params[:organization]
    # Check it's a valid org.
    github = github_from_access_token(session[:access_token])

    @user = get_user_data(github)

    @orgs = get_users_organizations(github)

    if @orgs.find {|org| org['login'] == params[:organization]}
      # Valid organization ID.
      query = URI.encode_www_form(
                              'config[access_token]' => session[:access_token],
                              'config[organization]' => params[:organization])
      redirect session[:bergcloud_return_url] + '?' + query 

    else
      session[:form_error] = "Please select an organization"
      redirect url("/organization/select-org/")
    end
  else
    session[:form_error] = "Please select an organization"
    redirect url("/organization/select-org/")
  end
end


# BERG CLoud is requesting an edition for a user.
# We'll get an access_token that lets us authenticate as this user.
get %r{^/(received|organization)/edition/$} do |variety|
  set_variety(variety)

  etag Digest::MD5.hexdigest(params[:access_token] + Date.today.strftime('%d%m%Y'))
  # Testing, always changing etag:
  # etag Digest::MD5.hexdigest(params[:access_token] + Time.now.strftime('%M%H-%d%m%Y'))

  github = github_from_access_token(params[:access_token])

  @user = get_user_data(github)
  @organization = nil

  if settings.variety == 'organization'
    settings.organization_login = params[:organization]

    @orgs = get_users_organizations(github)

    # Make sure that the org we're getting events for is one that the user
    # has access for. And put it into @organization so we can access it in the
    # template.
    matched_org = @orgs.find {|org| org['login'] == settings.organization_login}
    if matched_org.nil?
      # The organization ID isn't one the user has access to.
      return 204, "User '#{@user['login']}' doesn't have access to organization '#{settings.organization_login}'"
    else
      # org only contains some of the Organization's data. We need more
      # (like the name), so...
      @organization = get_organization_data(github, matched_org.login)
      # Gets events for the organization.
      event_page = get_users_events(github, @user['login'], settings.organization_login)
    end

  else
    # No organizations - fetch all events this user has received.
    event_page = get_users_events(github, @user['login'])
  end

  # We only want events from the past 24 hours.
  @events = Array.new
  time_now = Time.now.utc
  event_page.each do |ev|
    if (time_now - Time.parse(ev['created_at'])) <= 86400
      @events << ev
    else
      break
    end 
  end

  if @events.length == 0
    return 204, "User #{@user['login']} has no events to show today"
  end

  content_type 'text/html; charset=utf-8'
  erb :publication
end


get %r{^/(received|organization)/sample/$} do |variety|
  set_variety(variety)

  @user = {
    'avatar_url' => url('img/avatar_user.jpg'),
    'login' => 'philgyford',
    'name' => 'Phil Gyford',
  }

  if settings.variety == 'organization'
    @organization = {
      'avatar_url' => url('img/avatar_organization.png'),
      'login' => 'bergcloud',
      'name' => 'BERG Cloud',
    }
    events_filename = 'events_organization.json'
  else
    @organization = nil
    events_filename = 'events_user.json'
  end

  @events = JSON.parse( IO.read(Dir.pwd + '/public/json/'+events_filename) )

  content_type 'text/html; charset=utf-8'
  erb :publication
end


post %r{/(received|organization)/validate_config/} do |variety|
  set_variety(variety)
end

