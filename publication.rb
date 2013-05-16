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


get '/' do
  "Little Printer GitHub Events Publication"
end


# The user has just come here from BERG Cloud to authenticate with GitHub.
get '/configure/' do
  # Save these for use when the user returns.
  session[:bergcloud_return_url] = params['return_url']
  session[:bergcloud_error_url] = params['error_url']

  # Send them to GitHub to approve us.
  url = consumer.auth_code.authorize_url(
    :redirect_uri => url('/configure/return/'),
    :scope => 'repo:status' # Also use notifications?
  )
  redirect url
end


# The user has returned here from approving us (or not) at GitHub.
# URL be a subdirectory of the calling URL.
# This URL is also specified in the GitHub application.
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
  @user = JSON.parse(request.get('/user').body)

  # Fetch events this user has received:
  event_page = JSON.parse(request.get("/users/#{@user['login']}/received_events").body)

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
    etag Digest::MD5.hexdigest(params[:access_token] + Date.today.strftime('%d%m%Y'))
    return 204, "User #{@user['login']} has no events to show"
  end

  etag Digest::MD5.hexdigest(params[:access_token] + Date.today.strftime('%d%m%Y'))
  # Testing, always changing etag:
  # etag Digest::MD5.hexdigest(params[:access_token] + Time.now.strftime('%M%H-%d%m%Y'))
  erb :publication
end


get '/sample/' do
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
  erb :publication
end


post '/validate_config/' do
end

