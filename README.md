# GitHub Events

A Little Printer publication that displays the contents of your GitHub News Feed from the past 24 hours. See a sample at http://remote.bergcloud.com/publications/149

This is a Ruby + Sinatra app, which might be useful as a demonstration of authenticating a subscriber with their GitHub account via OAuth2. No other configuration by the subscriber is required.

Also see the [GitHub Developer API](http://developer.github.com/) for more things you could do.

## Setup

You'll need to [register two OAuth applications on GitHub](https://github.com/settings/applications/new); one for each of the Received and Organization events publications.

The Main URL will be the top-level (eg `http://my-app-name.herokuapp.com/received/`) although there's nothing useful there in this app.

The Callback URL will, to follow the same example, like `http://my-app-name.herokuapp.com/received/configure/return/`.

Once created, GitHub will supply you with an ID and Secret for each application, which our code expects to be in these environment variables:

    GITHUB_CLIENT_ID_RECEIVED
    GITHUB_CLIENT_SECRET_RECEIVED
    GITHUB_CLIENT_ID_ORGANIZATION
    GITHUB_CLIENT_SECRET_ORGANIZATION

eg, for a Heroku app, you'd do this, with your credentials in place:

    $ heroku config:set GITHUB_CLIENT_ID_RECEIVED=myreceivedclientid GITHUB_CLIENT_SECRET_RECEIVED=myreceivedclientsecret GITHUB_CLIENT_ID_ORGANIZATION=myorganizationclientid GITHUB_CLIENT_SECRET_ORGANIZATION=myorganizationclientsecret


Set `RACK_ENV` to either `production` or `development`.

----

BERG Cloud Developer documentation: http://remote.bergcloud.com/developers/
