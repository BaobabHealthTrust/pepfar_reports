# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def app_version
      `git describe`.gsub(/\n/, '')
  end
end
