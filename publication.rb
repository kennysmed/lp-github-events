# coding: utf-8
require 'json'
require 'oauth2'
require 'sinatra'

enable :sessions

raise 'GITHUB_CLIENT_ID is not set' if !ENV['GITHUB_CLIENT_ID']
raise 'GITHUB_CLIENT_SECRET is not set' if !ENV['GITHUB_CLIENT_SECRET']


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
end


helpers do
  # Set the variety setting to `variety` if it's valid. Else, stay with default.
  def set_variety(variety)
    settings.variety = variety if settings.valid_varieties.include?(variety)
  end

  def consumer
    OAuth2::Client.new(ENV['GITHUB_CLIENT_ID'], ENV['GITHUB_CLIENT_SECRET'],
      {
        :site => 'https://api.github.com',
        :authorize_url => 'https://github.com/login/oauth/authorize',
        :token_url => 'https://github.com/login/oauth/access_token'
      }
    )
  end

  # So that we keep the title consistent in all the places.
  def format_title
    title = "GitHub Events"
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
    return user + '/<span class="repo-name">' + repo + '</span>'
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

  # Send them to GitHub to approve us.
  url = consumer.auth_code.authorize_url(
    :redirect_uri => url("/#{settings.variety}/return/"),
    :scope => 'repo:status' # Also use notifications?
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
    access_token = consumer.auth_code.get_token(params[:code],
                          :redirect_uri => url("/#{settings.variety}/return/"))
  rescue OAuth2::Error => e
    # Debugging:
    # return "OAuth2 error: #{$!}"
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
  set_frequency('organization')

  request = OAuth2::AccessToken.new(consumer, session[:access_token]) 

  # We need the user's details:
  @user = JSON.parse(request.get('/user').body)

  @orgs = JSON.parse(request.get("/users/#{@user['login']}/orgs").body)

  erb :select_org
end


# The user has selected one of their organizations in our custom form, so now
# we need to check it's valid then, if so, send them back to Remote with the
# organization ID in the config vars.
post '/organization/select-org/' do
  set_frequency('organization')

  if params[:organization]
    # Check it's a valid org.
    request = OAuth2::AccessToken.new(consumer, session[:access_token]) 

    # We need the user's details:
    @user = JSON.parse(request.get('/user').body)

    @orgs = JSON.parse(request.get("/users/#{@user['login']}/orgs").body)

    if @orgs.find {|org| org['id'] == params[:organization].to_i}
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

  # Testing, always changing etag:
  # etag Digest::MD5.hexdigest(params[:access_token] + Time.now.strftime('%M%H-%d%m%Y'))
  etag Digest::MD5.hexdigest(params[:access_token] + Date.today.strftime('%d%m%Y'))

  request = OAuth2::AccessToken.new(consumer, params[:access_token]) 

  # We need the user's details:
  @user = JSON.parse(request.get('/user').body)

  if settings.variety == 'organization'
    @orgs = JSON.parse(request.get("/users/#{@user['login']}/orgs").body)

    puts @orgs

    if @orgs.find {|org| org['id'] == params[:organization].to_i}
      event_page = JSON.parse(request.get(
        "/users/#{@user['login']}/events/orgs/#{params[:organization]}").body)

    else
      # The organization ID isn't one the user has access to.
      return 204, "User #{@user['login']} doesn't have access to organization #{params[:organization]}"
    end
  else
    # Fetch all events this user has received:
    event_page = JSON.parse(request.get(
                              "/users/#{@user['login']}/received_events").body)
  end

  # We only want events from the past 24 hours.
  @events = Array.new
  time_now = Time.now.utc
  event_page.each do |e|
    if (time_now - Time.parse(e['created_at'])) <= 86400
      @events << e
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

  @user = {'login' => 'jherekc'}
  @events = [
    {
      'actor' => {'login' => 'philgyford'},
      'type' => 'CommitCommentEvent',
      'repo' => {
        'name' => 'bergcloud/how-many-people-in-space',
      },
      'payload' => {
        'id' => 34827,
        'comment' => {
          'body' => "Good to see this in there at last. I'd also like to say a bit more so that we can be sure that long comments are displayed correctly."
        }
      }
    },
    {
      'actor' => {'login' => 'alicebartlett'},
      'type' => 'CreateEvent',
      'repo' => {
        'name' => 'bergcloud/lp-word-of-the-day',
      },
      'payload' => {
        'ref_type' => 'branch',
        'ref' => 'master',
      }
    },
    {
      'actor' => {'login' => 'philgyford'},
      'type' => 'DeleteEvent',
      'repo' => {
        'name' => 'philgyford/samuelpepys-twitter',
      },
      'payload' => {
        'ref_type' => 'branch',
        'ref' => 'tester',
      }
    },
    {
      'actor' => {'login' => 'philgyford'},
      'type' => 'DownloadEvent',
      'repo' => {
        'name' => 'philgyford/django-pepysdiary',
      },
    },
    {
      'actor' => {'login' => 'benterrett'},
      'type' => 'FollowEvent',
      'payload' => {
        'target' => {
          'login' => 'rex3000'
        }
      }
    },
    {
      'actor' => {'login' => 'straup'},
      'type' => 'ForkEvent',
      'repo' => {
        'name' => 'tomtaylor/noticings-iphone',
      },
      'payload' => {
        'forkee' => 'straup/noticings-iphone',
      },
    },
    {
      'actor' => {'login' => 'straup'},
      'type' => 'GistEvent',
      'payload' => {
        'action' => 'create',
        'id' => 3973400
      },
    },
    {
      'actor' => {'login' => 'reinout'},
      'type' => 'IssueCommentEvent',
      'repo' => {
        'name' => 'jezdez/django_compressor',
      },
      'payload' => {
        'id' => 296,
        'comment' => {
          'body' => "This is probably related to #226, I think.\n\nThis means that it probably works fine in production, when you collect all the static files in that CACHE dir and serve it from there? And that it fails in development?"
        }
      },
    },
    {
      'actor' => {'login' => 'manelclos'},
      'type' => 'IssuesEvent',
      'repo' => {
        'name' => 'alex/django-taggit',
      },
      'payload' => {
        'id' => 103,
        'title' => "Related Field has invalid lookup: icontains\" in Admin when adding 'tags' to search_fields",
      },
    },
    {
      'actor' => {'login' => 'undermanager'},
      'type' => 'MemberEvent',
      'repo' => {
        'name' => 'undermanager/georgemichael',
      },
      'payload' => {
        'action' => 'added',
        'member' => {'login' => 'benterrett'}
      },
    },
    {
      'actor' => {'login' => 'bergcloud'},
      'type' => 'PublicEvent',
      'repo' => {
        'name' => 'bergcloud/lp_publication_hello_world',
      },
    },
    {
      'actor' => {'login' => 'alicebartlett'},
      'type' => 'PullRequestEvent',
      'repo' => {
        'name' => 'bergcloud/lp_publication_hello_world',
      },
      'payload' => {
        'action' => 'closed',
        'number' => 2,
        'pull_request' => {
          'title' => "Update Bundler source to use https",
          'merged' => true,
          'commits' => 1,
          'additions' => 2,
          'deletions' => 2
        }
      },
    },
    {
      'actor' => {'login' => 'randomecho'},
      'type' => 'PullRequestReviewCommentEvent',
      'repo' => {
        'name' => 'github/developer.github.com',
      },
      'payload' => {
        'comment' => {
          'body' => "Well now it looks like there should be \"an elephant\" for some sober reason."
        }
      },
    },
    {
      'actor' => {'login' => 'alicebartlett'},
      'type' => 'PushEvent',
      'repo' => {
        'name' => 'bergcloud/lp-how-many-people-in-space',
      },
      'payload' => {
        'ref' => 'ref/heads/master',
        'size' => 13
      },
    },
    {
      'actor' => {'login' => 'mrkruger'},
      'type' => 'TeamAddEvent',
      'payload' => {
        'team' => {'name' => 'krugeris'},
        'user' => {'login' => 'artvanderlay'}
      }
    },
    {
      'actor' => {'login' => 'tomtaylor'},
      'type' => 'WatchEvent',
      'repo' => {
        'name' => 'modeset/teabag'
      }
    }
  ]
  content_type 'text/html; charset=utf-8'
  erb :publication
end


post %r{/(received|organization)/validate_config/} do |variety|
  set_variety(variety)
end

