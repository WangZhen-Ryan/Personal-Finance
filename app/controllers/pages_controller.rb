class PagesController < ApplicationController
  before_action :authenticate_user!

  def dashboard
    # This is the root path route ("/")
    # to be used as the dashboard
  end
end
