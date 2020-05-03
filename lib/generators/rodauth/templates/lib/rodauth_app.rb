class RodauthApp < Rodauth::Rails::App
  configure do
    # List of authentication features that are loaded.
    enable :create_account, :verify_account, :verify_account_grace_period,
      :login, :remember, :logout,
      :reset_password, :change_password, :change_password_notify,
      :change_login, :verify_login_change,
      :close_account

    # See the Rodauth documentation for the list of available config options:
    # http://rodauth.jeremyevans.net/documentation.html

    # ==> General
    # Specify the controller used for view rendering and CSRF verification.
    rails_controller { RodauthController }

    # Store account status in a text column.
    account_status_column :status
    account_unverified_status_value "unverified"
    account_open_status_value "verified"
    account_closed_status_value "closed"

    # Store password hash in a column instead of a separate table.
    # account_password_hash_column :password_digest

    # Set password when creating account instead of when verifying.
    verify_account_set_password? false

    # Redirect back to originally requested location after authentication.
    # login_return_to_requested_location? true
    # two_factor_auth_return_to_requested_location? true # if using MFA

    # Autologin the user after they have reset their password.
    # reset_password_autologin? true

    # Delete the account record when the user has closed their account.
    # delete_account_on_close? true

    # Redirect to the app from login and registration pages if already logged in.
    # already_logged_in { redirect login_redirect }

    # ==> Emails
    # Uncomment the lines below once you've imported mailer views.
    # send_reset_password_email do
    #   RodauthMailer.reset_password(email_to, password_reset_email_link).deliver_now
    # end
    # send_verify_account_email do
    #   RodauthMailer.verify_account(email_to, verify_account_email_link).deliver_now
    # end
    # send_verify_login_change_email do |login|
    #   RodauthMailer.verify_login_change(login, verify_login_change_old_login, verify_login_change_new_login, verify_login_change_email_link).deliver_now
    # end
    # send_password_changed_email do
    #   RodauthMailer.password_changed(email_to).deliver_now
    # end
    # # send_email_auth_email do
    # #   RodauthMailer.email_auth(email_to, email_auth_email_link).deliver_now
    # # end
    # # send_unlock_account_email do
    # #   RodauthMailer.unlock_account(email_to, unlock_account_email_link).deliver_now
    # # end

    # In the meantime you can tweak settings for emails created by Rodauth
    # email_subject_prefix "[MyApp] "
    # email_from "noreply@myapp.com"
    # send_email(&:deliver_later)
    # reset_password_email_body { "Click here to reset your password: #{reset_password_email_link}" }

    # ==> Flash
    # Match flash keys with ones already used in the Rails app.
    # flash_notice_key :success # default is :notice
    # flash_error_key :error # default is :alert

    # Override default flash messages.
    # create_account_notice_flash "Your account has been created. Please verify your account by visiting the confirmation link sent to your email address."
    # login_error_flash "Login is required for accessing this page"
    # login_notice_flash nil

    # ==> Validation
    # Override default validation error messages.
    # no_matching_login_message "user with this email address doesn't exist"
    # already_an_account_with_this_login_message "user with this email address already exists"
    # password_too_short_message { "needs to have at least #{password_minimum_length} characters" }
    # login_does_not_meet_requirements_message { "invalid email#{", #{login_requirement_message}" if login_requirement_message}" }

    # Change minimum number of password characters required when creating an account.
    # password_minimum_length 8

    # ==> Remember Feature
    # Remember all logged in users.
    after_login { remember_login }

    # Or only remember users that have ticked a "Remember Me" checkbox on login.
    # after_login { remember_login if param_or_nil("remember") }

    # Extend user's remember period when remembered via a cookie
    extend_remember_deadline? true

    # Consider remembered users to be multifactor-authenticated (if using MFA).
    # after_load_memory { two_factor_update_session("totp") if two_factor_authentication_setup? }

    # ==> Hooks
    # Validate custom fields in the create account form.
    # before_create_account do
    #   throw_error_status(422, "name", "must be present") if param("name").empty?
    # end

    # Perform additional actions after the account is created.
    # after_create_account do
    #   db.after_commit do # wait until account record creation is committed
    #     Profile.create!(account_id: account[:id], name: param("name"))
    #   end
    # end

    # Do additional cleanup after the account is closed.
    # after_close_account do
    #   Profile.find_by!(account_id: account[:id]).destroy
    # end

    # ==> Redirects
    # Redirect to home page after logout.
    logout_redirect "/"

    # Redirect to wherever login redirects to after account verification.
    verify_account_redirect { login_redirect }

    # Redirect to login page after password reset.
    reset_password_redirect { login_path }

    # ==> Deadlines
    # Change default deadlines for some actions.
    # verify_account_grace_period 3.days
    # reset_password_deadline_interval Hash[hours: 6]
    # verify_login_change_deadline_interval Hash[days: 2]
    # remember_deadline_interval Hash[days: 30]

    # ==> Extending
    # Define any additional methods you want for the Rodauth object.
    # auth_class_eval do
    #   def my_send_email(name, *args)
    #     AuthenticationMailer.public_send(name, *args).deliver_later
    #   end
    # end
    #
    # Then use the new custom method in configuration blocks.
    # send_password_reset_email do
    #   my_send_email(:password_reset, email_to, password_reset_email_link)
    # end
  end

  route do |r|
    rodauth.load_memory # autologin remembered users

    r.rodauth # route rodauth requests

    # ==> Authenticating Requests
    # Call `rodauth.require_authentication` for requests that you want to
    # require authentication for. Some examples:
    #
    # next if r.path.start_with?("/docs") # skip authentication for documentation pages
    # next if session[:admin] # skip authentication for admins
    #
    # # authenticate /dashboard/* and /account/* requests
    # if r.path.start_with?("/dashboard") || r.path.start_with?("/account")
    #   rodauth.require_authentication
    # end
  end
end
