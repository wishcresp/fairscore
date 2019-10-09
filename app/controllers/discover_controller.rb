include TMDbApi

class DiscoverController < ApplicationController
  before_action :set_user_ratings

  # GET /discover/new
  def new
    @results = get_new_movies['results']
  end

  # GET /discover/top
  def top
    @results = get_top_movies['results']
  end

  # POST /discover/search
  def search
    @results = search_movies(params[:query])['results']
  end

  private

    def set_user_ratings
      @ratings = current_user.ratings
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def media_params
      params.require(:media).permit(:id, :title, :year, :info)
    end

end
