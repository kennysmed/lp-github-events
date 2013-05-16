# GitHub Events

A Little Printer publication that displays the contents of your GitHub News Feed from the past 24 hours. See a sample at http://remote.bergcloud.com/publications/149

This is a Ruby + Sinatra app, which might be useful as a demonstration of authenticating a subscriber with their GitHub account via OAuth2. No other configuration by the subscriber is required.

Also see the [GitHub Developer API](http://developer.github.com/) for more things you could do.

## Setup

You'll need to [register an OAuth application on GitHub](https://github.com/settings/applications/new).

The Main URL will be the top-level (eg `http://my-app-name.herokuapp.com/received/`) although there's nothing useful there in this app.

(Note: We use a directory, `/received/`, for this publication so we can use the same code for slight variations in future.)

The Callback URL will, to follow the same example, like `http://my-app-name.herokuapp.com/received/configure/return/`.

Once created, GitHub will supply you with an ID and Secret which our code expects to be in these environment variables:

    GITHUB_CLIENT_ID
    GITHUB_CLIENT_SECRET

eg, for a Heroku app, you'd do this, with your credentials in place:

    $ heroku config:set GITHUB_CLIENT_ID=myclientid GITHUB_CLIENT_SECRET=myclientsecret


----

BERG Cloud Developer documentation: http://remote.bergcloud.com/developers/
