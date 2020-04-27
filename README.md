# rodauth-rails

Provides Rails 5.0+ integration for the [Rodauth] authentication framework.

## Installation

Add the gem to your Gemfile:

```rb
gem "rodauth-rails", "~> 0.1"
```

Then run `bundle install`.

Next, run the install generator:

```
$ rails generate rodauth:install
```

The generator will create the following files:

* migration at `db/migrate/*_create_rodauth.rb`
* initializer at `config/initializers/rodauth.rb` and `config/initializers/sequel.rb`
* app at `lib/rodauth_app.rb`

The migration file creates tables required by Rodauth. You're encouraged to
review the migration, and modify it so that you only create tables for features
you intend to use.

```rb
# db/migrate/*_create_rodauth.rb
class CreateRodauth < ActiveRecord::Migration
  def change
    create_table(:accounts) { ... }
    create_table(:account_password_hashes) { ... }
    create_table(:account_password_reset_keys) { ... }
    create_table(:account_verification_keys) { ... }
    create_table(:account_login_change_keys) { ... }
    create_table(:account_remember_keys) { ... }
    # ...
  end
end
```

Once you're done, you can run the migration:

```
$ rails db:migrate
```

The `rodauth.rb` initializer sets the constant for your Rodauth app, which will
be inserted into your middleware stack.

```rb
# config/initializers/rodauth.rb
Rodauth::Rails.configure do |config|
  config.app = "RodauthApp"
end
```

If you're using ActiveRecord, a `sequel.rb` initializer will be added as well,
which configures Sequel to use ActiveRecord's connection.

```rb
# config/initializers/sequel.rb
require "sequel-activerecord-adapter"

# creates a Sequel "connection" that reuses the existing ActiveRecord connection
DB = Sequel.activerecord
```

Your Rodauth app is created in the `lib/` directory, and it comes with a
default set of authentication features enabled. This is where you configure
your authentication behaviour, see the comments and Rodauth [feature
documentation] for the list of things you can configure.

```rb
# lib/rodauth_app.rb
class RodauthApp < Rodauth::Rails::App
  rodauth do
    # configuration
  end

  route do |r|
    # request handling
  end
end
```

Note that Rails doesn't autoload files in the `lib/` directory by default, so
make sure to add `lib/` to your `config.autoload_paths`:

```rb
# config/application.rb
module YourApp
  class Application < Rails::Application
    # ...
    config.autoload_paths += %W[#{config.root}/lib]
    # ...
  end
end
```

Lastly, the generator will create an `Account` model, which you can use to
access the created user accounts.

```rb
# app/models/account.rb
class Account < ApplicationRecord
end
```

## Getting started

Let's start by adding some basic authentication navigation links to our home
page:

```erb
<ul>
  <% if rodauth.authenticated? %>
    <li><%= link_to "Sign out", rodauth.logout_path, method: :post %></li>
  <% else %>
    <li><%= link_to "Sign in", rodauth.login_path %></li>
    <li><%= link_to "Sign up", rodauth.create_account_path %></li>
  <% end %>
</ul>
```

These links are fully functional, feel free to visit them and interact with the
pages. The templates that ship with Rodauth aim to provide a complete
authentication experience, and the forms use [Boostrap] markup.

Let's also add the `#current_account` method for retrieving the account of the
the currently authenticated user:

```rb
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  private

  def current_account
    @current_account ||= Account.find(rodauth.session_value)
  end
  helper_method :current_account
end
```
```erb
<p>Authenticated as: <%= current_account.email %></p>
```

Next, we'll likely want to require authentication for certain sections/pages of
our app. We can do this in our Rodauth app's routing block, which helps keep
the authentication logic encapsulated:

```rb
# lib/rodauth_app.rb
class RodauthApp < Rodauth::Rails::App
  # ...
  route do |r|
    # ...
    r.rodauth # route rodauth requests

    # require authentication for /dashboard/* and /account/* routes
    if r.path.start_with?("/dashboard") || r.path.start_with?("/account")
      rodauth.require_authentication # redirect to login page if not authenticated
    end
  end
end
```

We can also require authentication at the controller layer:

```rb
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  private

  def authenticate
    rodauth.require_authentication # redirect to login page if not authenticated
  end
end
```
```rb
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  before_action :authenticate
end
```
```rb
# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  before_action :authenticate, except: [:index, :show]
end
```

Or at the Rails router level:

```rb
# config/routes.rb
Rails.application.routes.draw do
  constraints(-> (req) { req.env["rodauth"].require_authentication }) do
    namespace :admin do
      # ...
    end
  end
end
```

### Views

The templates built into Rodauth are useful when getting started, but at some
point we'll probably want more control over the markup. For that we can run the
following command:

```sh
$ rails generate rodauth:views
```

This will copy views for Rodauth features that are enabled by default into your
`app/views/rodauth` directory. Feel free to remove the views related to
features you're not using. You can also specify a list of features which you
want to generate views for (this will not remove any existing views):

```sh
$ rails generate rodauth:views --features login create_account verify_account reset_password
```

To have Rodauth render the imported views, we'll need to change the
`rails_controller` setting in our Rodauth app to point to the new
`RodauthController`.

```rb
# lib/rodauth_app.rb
class RodauthApp < Rodauth::Rails::App
  # ...
  rodauth do
    # ...
    rails_controller { RodauthController }
    # ...
  end
end
```

Note that the "rodauth" naming here is not required; you can just as well have
an `AuthenticationController` render views from `app/views/authentication`
directory, for example.

### Mailer

Rodauth may send emails as part of the authentication flow. Most email settings
can be customized:

```rb
# lib/rodauth_app.rb
class RodauthApp < Rodauth::Rails::App
  # ...
  rodauth do
    # ...
    # general settings
    email_from "no-reply@myapp.com"
    email_subject_prefix "[MyApp] "
    send_email(&:deliver_later)
    # ...
    # feature settings
    verify_account_email_subject "Verify your account"
    verify_account_email_body { "Verify your account by visting this link: #{verify_account_email_link}" }
    # ...
  end
end
```

This is convenient when starting out, but eventually you might want to use your
own mailer. You can start by running the following command:

```sh
$ rails generate rodauth:mailer
```

This will create a `RodauthMailer` with the associated mailer views in
`app/views/rodauth_mailer` directory.

```rb
# app/mailers/rodauth_mailer.rb
class RodauthMailer < ApplicationMailer
  def verify_account(recipient, email_link) ... end
  def reset_password(recipient, email_link) ... end
  def verify_login_change(recipient, old_login, new_login, email_link) ... end
  def password_changed(recipient) ... end
end
```

You can then uncomment the lines in your Rodauth configuration to have it call
your mailer. If you've enabled additional authentication features, make sure to
override their `send_*_email` methods as well.

```rb
# lib/rodauth_app.rb
class RodauthApp < Rodauth::Rails::App
  # ...
  rodauth do
    # ...
    send_reset_password_email do
      RodauthMailer.reset_password(email_to, password_reset_email_link).deliver_now
    end
    send_verify_account_email do
      RodauthMailer.verify_account(email_to, verify_account_email_link).deliver_now
    end
    send_verify_login_change_email do |login|
      RodauthMailer.verify_login_change(login, verify_login_change_old_login, verify_login_change_new_login, verify_login_change_email_link).deliver_now
    end
    send_password_changed_email do
      RodauthMailer.password_changed(email_to).deliver_now
    end
    # send_email_auth_email do
    #   RodauthMailer.email_auth(email_to, email_auth_email_link).deliver_now
    # end
    # send_unlock_account_email do
    #   RodauthMailer.unlock_account(email_to, unlock_account_email_link).deliver_now
    # end
    # ...
  end
end
```

## How it works

### Middleware

rodauth-rails inserts a `Rodauth::Rails::Middleware` into your middleware
stack, which delegates to your Rodauth app. This trick allows your Rodauth app
to remain reloadable in development.

```sh
$ rails middleware
...
use Rodauth::Rails::Middleware
run MyApp::Application.routes
```

The Rodauth app stores the `Rodauth::Auth` instance in the Rack env hash, which
is then available in your Rails app:

```rb
request.env["rodauth"] #=> #<Rodauth::Auth>
# or
request.env["rodauth.secondary"] #=> #<Rodauth::Auth> (if using multiple configurations)
```

In controllers and views the `#rodauth` method can be used for convenience:

```rb
class MyController < ApplicationController
  def my_action
    rodauth #=> #<Rodauth::Auth>
    # or
    rodauth(:secondary) #=> #<Rodauth::Auth> (if using multiple configurations)
  end
end
```
```erb
<% rodauth #=> #<Rodauth::Auth> %>
<!-- or -->
<% rodauth(:secondary) #=> #<Rodauth::Auth> (if using multiple configurations) %>
```

### App

The `Rodauth::Rails::App` class is a [Roda] subclass with added behaviour that
smooths out integration with Rails:

* loads Roda's middleware plugin
* assigns Rodauth instance to Rack env hash
* uses Rails' flash instead of Roda's
* uses Rails' CSRF protection instead of Roda's
* sets [HMAC] secret to Rails' secret key base
* uses ActionController for rendering templates
* uses ActionMailer for sending emails

The `rodauth { ... }` method wraps configuring the Rodauth plugin, forwarding
any additional [options].

```rb
rodauth { ... }             # defining default Rodauth configuration
rodauth(json: true)         # passing options to the Rodauth plugin
rodauth(:secondary) { ... } # defining multiple Rodauth configurations
```

### Sequel

Rodauth uses the [Sequel] library for database queries, due to more advanced
database usage (SQL expressions, database-agnostic date arithmetic, SQL
function calls).

If ActiveRecord is used in the application, the `rodauth:install` generator
will have automatically set up Sequel with the [sequel-activerecord-adapter]
gem. This gem configures Sequel to reuse the existing ActiveRecord connection
for its database interaction.

This means that, from the usage perspective, Sequel can be considered just
as an implementation detail of Rodauth.

## Configuring

For the list of configuration methods provided by Rodauth, see the [feature
documentation].

The `rails` feature rodauth-rails uses is customizable as well, here is the
list of its configuration methods:

| Name                        | Description                                                        |
| :----                       | :----------                                                        |
| `rails_render(**options)`   | Calls `#render` on the controller renderer.                        |
| `rails_renderer`            | Instance of `ActionController::Renderer`.                          |
| `rails_csrf_tag`            | Hidden field added to Rodauth templates containing the CSRF token. |
| `rails_csrf_param`          | Value of the `name` attribute for the CSRF tag.                    |
| `rails_csrf_token`          | Value of the `value` attribute for the CSRF tag.                   |
| `rails_check_csrf!`         | Verifies the authenticity token for the current request.           |
| `rails_controller_instance` | Instance of the controller with the request env context.           |
| `rails_controller`          | Controller class to use for rendering and CSRF protection.         |

The `Rodauth::Rails` module has several config settings available as well:

| Name         | Description                                                                                         |
| :-----       | :----------                                                                                         |
| `app`        | Constant name of your Rodauth app, which is called by the middleware.                               |
| `middleware` | Whether to insert the middleware into the Rails application's middleware stack. Defaults to `true`. |

```rb
# config/initializers/rodauth.rb
Rodauth::Rails.configure do |config|
  config.app = "RodauthApp"
  config.middleware = true
end
```

## Testing

For system tests it's generally better to go through the actual authentication
flow with tools like Capybara, and to not use any stubbing.

In functional and integration tests you can just make requests to Rodauth
routes:

```rb
# test/controllers/posts_controller_test.rb
class PostsControllerTest < ActionDispatch::IntegrationTest
  test "should require authentication" do
    get posts_url
    assert_redirected_to "/login"

    login
    get posts_url
    assert_response :success

    logout
    assert_redirected_to "/login"
  end

  private

  def login(login: "user@example.com", password: "secret")
    post "/create-account", params: {
      "login"            => login,
      "password"         => password,
      "password-confirm" => password,
    }

    post "/login", params: {
      "login"    => login,
      "password" => password,
    }
  end

  def logout
    post "/logout"
  end
end
```

## Rodauth defaults

rodauth-rails changes some of the default Rodauth settings for greater
convenience:

### Database functions

By default on PostgreSQL, MySQL, and Microsoft SQL Server, Rodauth uses
database functions to access password hashes, with the user running the
application unable to get direct access to password hashes. This reduces the
risk of an attacker being able to access password hashes and use them to attack
other sites.

While this is useful additional security, it is also more complex to set up and
to reason about, as it requires having two different database users and making
sure the correct migration is run for the correct user.

To keep with Rails' "convention over configuration" doctrine, rodauth-rails
disables the use of database functions. It can still be turned back on, it's
just disabled by default.

### Account statuses

The recommended [Rodauth migration] stores possible account status values in a
separate table, and creates a foreign key on the accounts table, which ensures
only a valid status value will be persisted.

This doesn't work well when the database is restored from the schema file, in
which case the account statuses table will be empty. This happens in tests by
default, but it's also common in development, since older migrations often stop
working and restoring from the schema file is the only way to get the database
set up.

To avoid these problems, rodauth-rails modifies the setup to store account
status text directly in the accounts table. If you're worried about invalid
status values creeping in, you can use enums. Alternatively, you can still
go back to the setup recommended by Rodauth.

## Rails support

Rails 5.0 or above is supported. This is mainly due to the fact that Rails 5.0
added the API for [rendering views outside of controllers], which this library
relies on.

If you're on an older version of Rails and would like to use this gem, let me
know and we could try adding support together.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the rodauth-rails project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/janko/rodauth-rails/blob/master/CODE_OF_CONDUCT.md).

[Rodauth]: https://github.com/jeremyevans/rodauth
[Sequel]: https://github.com/jeremyevans/sequel
[rendering views outside of controllers]: https://blog.bigbinary.com/2016/01/08/rendering-views-outside-of-controllers-in-rails-5.html
[feature documentation]: http://rodauth.jeremyevans.net/documentation.html
[Rodauth plugin]: https://github.com/jeremyevans/rodauth/#label-Plugin+Options
[Bootstrap]: https://getbootstrap.com/
[Roda]: http://roda.jeremyevans.net/
[HMAC]: http://rodauth.jeremyevans.net/rdoc/files/README_rdoc.html#label-HMAC
[database authentication functions]: http://rodauth.jeremyevans.net/rdoc/files/README_rdoc.html#label-Password+Hash+Access+Via+Database+Functions
[multiple configurations]: http://rodauth.jeremyevans.net/rdoc/files/README_rdoc.html#label-With+Multiple+Configurations
[views]: /app/views/rodauth
[Rodauth migration]: http://rodauth.jeremyevans.net/rdoc/files/README_rdoc.html#label-Creating+tables
[sequel-activerecord-adapter]: https://github.com/janko/sequel-activerecord-adapter
