include UserRatingMaths

class MediaZscoresUpdateJob < ApplicationJob
  queue_as :fairscore

  # When a user changes the score of a rating, update the stored zscore of the rating
  # and adjust the associated media's zscore sum
  def perform(changed_rating)
    changed_rating.user.ratings.each do |rating|
      # Skip the rating if it was the originally modified rating or the rating has no score
      next if rating.id == changed_rating.id || rating.score.blank?

      new_zscore = calc_z_score(rating.score.to_i, rating.user.rating_sum, rating.user.rating_sum_of_squares, rating.user.reload.scored_ratings)
      rating.zscore = new_zscore
      rating.save
    end
  end

end
