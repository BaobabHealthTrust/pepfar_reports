ActionController::Routing::Routes.draw do |map|
  map.root :controller => "administration"
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
