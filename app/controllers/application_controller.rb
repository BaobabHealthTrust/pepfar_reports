class ApplicationController < ActionController::Base
  protect_from_forgery       
                                                                                
  skip_before_filter :verify_authenticity_token, :only => ['login','logout']                         

  def admin?                                                                    
    User.current_user.user_roles.map(&:role).include?('admin')                  
  end

  def check_authorized
    unless admin?
      redirect_to '/'
    end
  end

                                                                                 
  protected                                                                     
                                                                                
  def verify_authenticity_token                                     
    if session[:current_user_id].blank?                                                 
      respond_to do |format|                                                    
        format.html { redirect_to :controller => 'user',:action => 'logout' }   
      end                                                                       
    elsif not session[:current_user_id].blank?                                          
      User.current = User.find(session[:current_user_id])
    end                                                                         
  end 

end
