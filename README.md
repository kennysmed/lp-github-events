# GitHub Events

Two Little Printer publication that display events from the past 24 hours. 

One shows the contents of your personal GitHub News Feed ("received" events is how the GitHub API describes them). See a sample at http://remote.bergcloud.com/publications/149

The other publication has an extra configuration step that lets the user choose an organization that they're part of on GitHub, and shows events for that.

This is a Ruby + Sinatra app, which might be useful as a demonstration of authenticating a subscriber with their GitHub account via OAuth2. It uses the [`github_api`](https://github.com/peter-murach/github/) gem.

Also see the [GitHub Developer API](http://developer.github.com/) for more things you could do.

## Setup

You'll need to [register two OAuth applications on GitHub](https://github.com/settings/applications/new). One is for the events for an individual user, the other is the for events for an organization that the user chooses.<sup>*</sup>

For each application, set both of its URLs to the top level of this site, shared by both of the publications, eg `http://my-app-name.herokuapp.com/`. 

Once created, GitHub will supply you with an ID and Secret for each application, which our code expects to be in these environment variables:

    GITHUB_CLIENT_ID_USER
    GITHUB_CLIENT_SECRET_USER
    GITHUB_CLIENT_ID_ORGANIZATION
    GITHUB_CLIENT_SECRET_ORGANIZATION

eg, for a Heroku app, you'd do this, with your credentials in place:

    $ heroku config:set GITHUB_CLIENT_ID_USER=myuserclientid GITHUB_CLIENT_SECRET_USER=myuserclientsecret GITHUB_CLIENT_ID_ORGANIZATION=myorgclientid GITHUB_CLIENT_SECRET_ORGANIZATION=myorgclientid

Set the `RACK_ENV` environment variable to either `production` or `development`.

<sup>*</sup> Why do we need two different OAuth applications on GitHub? When authenticating a user with an application, the code must supply a [`scope`](http://developer.github.com/v3/oauth/#scopes), giving permissions to particular things. For simply showing a user's News Feed we only need `repo` access. But for accessing information about an organization we need the wider-ranging `repo:status`. We could ask for the latter in both cases, and stick with a single application, but this seems excessive for users who will only require the personal events. Hence, two applications, which we ask for different scopes.

----

BERG Cloud Developer documentation: http://remote.bergcloud.com/developers/
