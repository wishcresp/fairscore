require 'open-uri'

class ResultCacheUpdateJob < ApplicationJob
  queue_as :default

  # Read JSON result from URL and update cache
  def perform(url, cache_key)
    result = open(url).read
    Rails.cache.write(cache_key, {value: result, last_update: Time.now})
  end

end
