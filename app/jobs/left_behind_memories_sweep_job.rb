# Purges private memories 90 days after their author went. See /docs/developer/leaving.
class LeftBehindMemoriesSweepJob < ApplicationJob
  queue_as :low

  def perform
    Memory.purge_left_behind
  end
end
