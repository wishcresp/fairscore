include UserRatingMaths

class RatingsController < ApplicationController
  before_action :set_rating, only: [:update, :destroy]
  before_action -> { require_owner @rating }, only: [:update, :destroy]

  # POST /media/:media_id/rating
  def create
    @rating = Rating.new(user_id: current_user.id, media_id: params[:media_id], status_id: 0)
    success = @rating.save
    flash[success ? :info : :danger] = success ? 'Rating was added.' : 'Something went wrong while saving the rating.'
    redirect_back fallback_location: root_path
  end

  # PUT /media/:media_id/rating
  def update
    # Validate new score
    unless rating_params[:score].to_i.between?(Rating::MIN, Rating::MAX)
      flash[:danger] = 'Score was not valid'
      redirect_back fallback_location: root_path
    end

    new_score = rating_params[:score].presence
    old_score = @rating.score

    # Dont bother updating rating unless there is a change to score or status
    do_update = new_score.to_i != old_score.to_i || rating_params[:status_id] != @rating.status_id
    if do_update
      success = ActiveRecord::Base.transaction do
        # Calculate and update user sum scores
        new_rating_sum, new_rating_sum_of_squares = update_user_sum_scores(@rating, new_score, old_score)

        # Avoid hitting the DB and calculate scored rating change: score added (+1), score removed (-1), no change (0)
        score_count_change = ((new_score.present? && old_score.blank?) ? 1 : (new_score.blank? && old_score.present?) ? -1 : 0)
        count = @rating.user.scored_ratings + score_count_change
        # Calculate the new rating zscore and media zscore sum
        zscore = new_score.present? ? calc_z_score(new_score.to_i, new_rating_sum, new_rating_sum_of_squares, count) : 0
        @rating.update(score: new_score, status_id: rating_params[:status_id], zscore: zscore)
        @rating.save
      end

      update_rating_media_zscores(@rating) if do_update && success
      flash[success ? :info : :danger] = success ? 'Rating was successfully updated.' : 'Rating update failed.'
    end

    redirect_back fallback_location: root_path
  end

  # DELETE /media/:media_id/rating
  def destroy
    # Update user scores and destroy rating
    success = ActiveRecord::Base.transaction do
      # Update media if the rating has a score
      update_user_sum_scores(@rating, 0, @rating.score) if @rating.score.present?
      @rating.destroy
    end

    update_rating_media_zscores(@rating) if success
    flash[success ? :info : :danger] = success ? 'Rating was removed.' : 'Rating could not be removed.'
    redirect_back fallback_location: root_path
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_rating
      @rating = Rating.includes(:user).find_by(user_id: current_user.id, media_id: params[:media_id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def rating_params
      params.require(:rating).permit(:status_id, :score)
    end

    # Update the sums of scores of a rating's user during rating updates/media deletions
    def update_user_sum_scores(rating, new_score, old_score)
      # Calculate the rating sums for the user and the new zscore rating
      new_rating_sum = rating.user.rating_sum + new_score.to_i - old_score.to_i
      new_rating_sum_of_squares = rating.user.rating_sum_of_squares + new_score.to_i**2 - old_score.to_i**2
      rating.user.update(rating_sum: new_rating_sum, rating_sum_of_squares: new_rating_sum_of_squares)
      [new_rating_sum, new_rating_sum_of_squares]
    end

    # Start a new job to update the zscores related to a given rating that was changed.
    # Jobs use FIFO queue to prevent data loss from multiple requests
    def update_rating_media_zscores(changed_rating)
      MediaZscoresUpdateJob.perform_later(changed_rating)
    end

end
