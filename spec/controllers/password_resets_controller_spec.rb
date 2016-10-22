require "spec_helper"

RSpec.describe PasswordResetsController do
  describe "GET new" do
    it "requires logout" do
      user = create(:user)
      login_as(user)
      get :new
      expect(response).to redirect_to(edit_user_url(user))
      expect(flash[:error]).to eq("You are already logged in.")
    end

    it "succeeds when logged out" do
      get :new
      expect(response.status).to eq(200)
    end
  end

  describe "POST create" do
    it "requires logout" do
      user = create(:user)
      login_as(user)
      post :create
      expect(response).to redirect_to(edit_user_url(user))
      expect(flash[:error]).to eq("You are already logged in.")
    end

    it "requires username" do
      post :create, email: 'fake_email'
      expect(response).to render_template('new')
      expect(flash[:error]).to eq("Username is required.")
    end

    it "requires email" do
      post :create, username: 'fake_username'
      expect(response).to render_template('new')
      expect(flash[:error]).to eq("Email is required.")
    end

    it "handles user not found" do
      post :create, username: 'fake_username', email: 'fake_email'
      expect(response).to render_template('new')
      expect(flash[:error]).to eq("Account could not be found.")
    end

    it "handles email match but not username" do
      user = create(:user)
      post :create, username: 'fake_username', email: user.email
      expect(response).to render_template('new')
      expect(flash[:error]).to eq("Account could not be found.")
    end

    it "handles username match but not email" do
      user = create(:user)
      post :create, username: user.username, email: 'fake_email'
      expect(response).to render_template('new')
      expect(flash[:error]).to eq("Account could not be found.")
    end

    it "handles failed save" do
      user = create(:user)
      expect_any_instance_of(PasswordReset).to receive(:generate_auth_token).and_return(nil)
      post :create, username: user.username, email: user.email
      expect(response).to render_template('new')
      expect(flash[:error]).to eq("Password reset could not be saved.")
    end

    it "resends link if reset already present" do
      ActionMailer::Base.deliveries.clear
      user = create(:user)
      reset = create(:password_reset, user: user)
      expect(PasswordReset.count).to eq(1)
      post :create, username: user.username, email: user.email
      expect(flash[:success]).to eq("Your password reset link has been re-sent.")
      expect(ActionMailer::Base.deliveries.count).to eq(1)
      expect(PasswordReset.count).to eq(1)
    end

    it "sends password reset" do
      ActionMailer::Base.deliveries.clear
      user = create(:user)
      post :create, username: user.username, email: user.email
      expect(response).to redirect_to(new_password_reset_url)
      expect(flash[:success]).to eq("A password reset link has been emailed to you.")
      expect(ActionMailer::Base.deliveries.count).to eq(1)
      expect(PasswordReset.count).to eq(1)
      expect(PasswordReset.first.user_id).to eq(user.id)
    end
  end

  describe "GET show" do
    it "requires logout" do
      user = create(:user)
      login_as(user)
      get :show, id: -1
      expect(response).to redirect_to(edit_user_url(user))
      expect(flash[:error]).to eq("You are already logged in.")
    end

    it "requires valid token" do
      get :show, id: -1
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("Authentication token not found.")
    end

    it "requires active token" do
      token = create(:expired_password_reset)
      get :show, id: token.auth_token
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("Authentication token expired.")
    end

    it "requires unused token" do
      token = create(:used_password_reset)
      get :show, id: token.auth_token
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("Authentication token has already been used.")
    end

    it "succeeds" do
      token = create(:password_reset)
      get :show, id: token.auth_token
      expect(response.status).to eq(200)
    end
  end

  describe "PUT update" do
    it "requires logout" do
      user = create(:user)
      login_as(user)
      put :update, id: -1
      expect(response).to redirect_to(edit_user_url(user))
      expect(flash[:error]).to eq("You are already logged in.")
    end

    it "requires valid token" do
      put :update, id: -1
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("Authentication token not found.")
    end

    it "requires active token" do
      token = create(:expired_password_reset)
      put :update, id: token.auth_token
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("Authentication token expired.")
    end

    it "requires unused token" do
      token = create(:used_password_reset)
      put :update, id: token.auth_token
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("Authentication token has already been used.")
    end

    it "requires password" do
      token = create(:password_reset)
      put :update, id: token.auth_token, password_confirmation: 'newpass'
      expect(flash[:error][:message]).to eq("Could not update password.")
      expect(response).to render_template('show')
    end

    it "requires long enough password" do
      token = create(:password_reset)
      put :update, id: token.auth_token, password: 'new', password_confirmation: 'new'
      expect(flash[:error][:message]).to eq("Could not update password.")
      expect(response).to render_template('show')
    end

    it "requires short enough password" do
      token = create(:password_reset)
      put :update, id: token.auth_token, password: 'newpass' * 12, password_confirmation: 'newpass' * 12
      expect(flash[:error][:message]).to eq("Could not update password.")
      expect(response).to render_template('show')
    end

    it "requires password confirmation" do
      token = create(:password_reset)
      put :update, id: token.auth_token, password: 'newpass'
      expect(flash[:error][:message]).to eq("Could not update password.")
      expect(response).to render_template('show')
    end

    it "requires password and confirmation to match" do
      token = create(:password_reset)
      put :update, id: token.auth_token, password: 'newpass', password_confirmation: 'notnewpass'
      expect(flash[:error][:message]).to eq("Could not update password.")
      expect(response).to render_template('show')
    end

    it "succeeds" do
      token = create(:password_reset)
      expect(token.user.authenticate('newpass')).to eq(false)
      put :update, id: token.auth_token, password: 'newpass', password_confirmation: 'newpass'
      expect(response).to redirect_to(root_url)
      expect(flash[:success]).to eq("Password successfully changed.")
      expect(token.reload).to be_used
      expect(token.user.authenticate('newpass')).to eq(true)
    end
  end
end
