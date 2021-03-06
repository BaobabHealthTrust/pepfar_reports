class UserController < ApplicationController

  def login
    if request.get?
      reset_session
    else
      user = User.find_by_username params[:user]['username']
      logged_in_user = user.try_to_login(params[:user]['password'])
      if not logged_in_user.blank?
        reset_session
        session[:current_user_id] = user.id
        redirect_to("/")
      else
        flash[:error] = "Invalid username or password"
      end      
    end
  end          

  def programs
    if request.post?
      redirect_to(:action => "activities", 
        :id => params[:user_id],:selected_program => params[:program]) 
    else
			program_selection = CoreService.get_global_property_value("select_program") rescue true
			if program_selection == true
        @user_id = (params[:id])
			else
				redirect_to(:action => "activities",
          :id => @user_id,:selected_program => "HIV PROGRAM")
      end
		end 
  end

  # List roles containing the string given in params[:value]
  def role
    valid_roles = CoreService.get_global_property_value("valid_roles") rescue nil
    role_conditions = ["role LIKE (?)", "%#{params[:value]}%"]
    role_conditions = ["role LIKE (?) AND role IN (?)",
      "%#{params[:value]}%",
      valid_roles.split(',')] if valid_roles
    roles = Role.find(:all,:conditions => role_conditions)
    roles = roles.map do |r|
      "<li value='#{r.role}'>#{r.role.gsub('_',' ').capitalize}</li>"
    end
    render :text => roles.join('') and return
  end

  def username
    users = User.find(:all,:conditions => ["username LIKE (?)","%#{params[:username]}%"])

    if params[:all_roles] and params[:all_roles] == '1'
      users = users.map{|u| "<li value='#{u.username}'>#{u.username}</li>" }
    else
      @users_with_provider_role = []
      users.each do |user|
        is_provider = UserRole.find_all_by_user_id(user.user_id).map(&:role).include?("Provider") rescue nil
        @users_with_provider_role << user if is_provider
      end
      users = @users_with_provider_role.map{| u | "<li value='#{u.username}'>#{u.username}</li>" }
    end

    render :text => users.join('') and return
  end
  
  def health_centres
    redirect_to(:controller => "patient", :action => "menu")
    @health_centres = Location.find(:all,  :order => "name").map{|r|[r.name, r.location_id]}
  end
 
  def list_clinicians
    @clinician_role = Role.find_by_role("clinician").id
    @clinicians = UserRole.find_all_by_role_id(@clinician_role)
  end
  
  def logout
    #if time is 4 o'oclock then send report on logout.
    reset_session
    redirect_to(:action => "login")
  end

  def signup
    render :text => "Please sign up"
  end

  def remind_password
  end

  def index
    @user=User.find(current_user.user_id)
    @firstname=@user.first_name
    @secondName=@user.last_name
       
    list
    return render(:action => 'list')
  end
  
  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  #  verify :method => :post, :only => [ :destroy, :create, :update ],
  # :redirect_to => { :action => :list }
        
  def voided_list
    session[:voided_list] = false
    @user_pages, @users = paginate(:users, :per_page => 50,:conditions =>["voided=1"])
    render :view => 'list'
  end
  
  def list
    session[:voided_list] = true
    @user_pages, @users = paginate(:users, :per_page => 50,:conditions =>["voided=0"])
  end

  def show
    unless params[:id].blank?
      @user = User.find(params[:id])
    else
      @user = User.find(:first, :order => 'date_created DESC')
    end  
    render :layout => 'menu'
  end

  def new
    @user = User.new
  end

  def create
    session[:user_edit] = nil
    existing_user = User.find(:first, :conditions => {:username => params[:user][:username]}) rescue nil

    if existing_user
      flash[:notice] = 'Username already in use'
      redirect_to :action => 'new'
      return
    end
    if (params[:user][:plain_password] != params[:user_confirm][:password])
      flash[:notice] = 'Password Mismatch'
      redirect_to :action => 'new'
      return
      #  flash[:notice] = nil
      @user_first_name = params[:person_name][:given_name]
      #      @user_middle_name = params[:user][:middle_name]
      @user_last_name = params[:person_name][:family_name]
      @user_role = params[:user_role][:role_id]
      @user_admin_role = params[:user_role_admin][:role]
      @user_name = params[:user][:username]
    end
	
    params[:user][:password] = params[:user][:plain_password]
    params[:user][:plain_password] = nil
    person = Person.create()
    person.names.create(params[:person_name])
    params[:user][:user_id] = nil
    @user = RawUser.new(params[:user])
    @user.person_id = person.id
    if @user.save
      # if params[:user_role_admin][:role] == "Yes"
      #  @roles = Array.new.push params[:user_role][:role_id] 
      # @roles << "superuser"
      # @roles.each{|role|
      # user_role=UserRole.new
      # user_role.role_id = Role.find_by_role(role).role_id
      # user_role.user_id=@user.user_id
      # user_role.save
      #}
      #else
      @user.update_attributes(params[:user])
      user_role = UserRole.new
      user_role.role = Role.find_by_role(params[:user_role][:role_id])
      user_role.user_id = @user.user_id
      user_role.save
      # end
      flash[:notice] = 'User was successfully created.'
      redirect_to :action => 'show'
    else
      flash[:notice] = 'OOps! User was not created!.'
      render :action => 'new'
    end
  end

  def edit
    @user = User.find(params[:id])
  end

  def update
    #find_by_person_id(params[:id])
    @user = User.find(params[:id])

    username = params[:user]['username'] rescue current_user.username

    if username
      @user.update_attributes(:username => username)
    end

    PersonName.find(:all,:conditions =>["voided = 0 AND person_id = ?",@user.person_id]).each do | person_name |
      person_name.voided = 1
      person_name.voided_by = current_user.person_id
      person_name.date_voided = Time.now()
      person_name.void_reason = 'Edited name'
      person_name.save
    end rescue nil

    person_name = PersonName.new()
    person_name.family_name = params[:person_name]["family_name"]
    person_name.given_name = params[:person_name]["given_name"]
    person_name.person_id = @user.person_id
    person_name
    if person_name.save
      flash[:notice] = 'User was successfully updated.'
      redirect_to :action => 'show', :id => @user.id and return
    end rescue nil

    flash[:notice] = "OOps! User was not updated!."
    render :action => 'show', :id => @user.id
  end

  def destroy
    unless request.get?
      @user = RawUser.find(params[:id])
      if @user.update_attributes(:voided => 1, :void_reason => params[:user][:void_reason],:voided_by => current_user.user_id,:date_voided => Time.now.to_s)
        flash[:notice]='User has successfully been removed.'
        redirect_to :action => 'voided_list'
      else
        flash[:notice]='User was not successfully removed'
        redirect_to :action => 'destroy'
      end
    end
  end

  def add_role
    @user = User.find(params[:id])
    unless request.get?
      user_role=UserRole.new
      user_role.role = Role.find_by_role(params[:user_role][:role_id])
      user_role.user_id=@user.user_id
      user_role.save
      flash[:notice] = "You have successfuly added the role of #{params[:user_role][:role_id]}"
      redirect_to :action => "show"
    else
      user_roles = UserRole.find_all_by_user_id(@user.user_id).collect{|ur|ur.role.role}
      all_roles = Role.find(:all).collect{|r|r.role}
      @roles = (all_roles - user_roles)
      @show_super_user = true if UserRole.find_all_by_user_id(@user.user_id).collect{|ur|ur.role.role != "superuser" }
    end
  end

  def delete_role
    @user = User.find(params[:id])
    unless request.post?
      @roles = UserRole.find_all_by_user_id(@user.user_id).collect{|ur|ur.role.role}
    else
      role = Role.find_by_role(params[:user_role][:role_id]).role
      user_role =  UserRole.find_by_role_and_user_id(role,@user.user_id)  
      user_role.destroy
      flash[:notice] = "You have successfuly removed the role of #{params[:user_role][:role_id]}"
      redirect_to :action =>"show"
    end
  end
  
  def user_menu
    render(:layout => "layouts/menu")
  end
 
  def search_user
    unless request.get?
      @user = User.find_by_username(params[:user][:username])
      redirect_to :action =>"show", :id => @user.id
    end
  end

  def change_password
    @user = RawUser.find(params[:id])

    unless request.get? 
      if (params[:user][:plain_password] != params[:user_confirm][:password])
        flash[:notice] = 'Password Mismatch'
        redirect_to :action => 'new'
        return
      else
        params[:user][:password] = params[:user][:plain_password]
        params[:user][:plain_password] = nil
        if @user.update_attributes(params[:user])
          flash[:notice] = "Password successfully changed"
          redirect_to :action => "show",:id => @user.id
          return
        else
          flash[:notice] = "Password change failed"
        end
      end
    end

  end

  def activities
    # Don't show tasks that have been disabled
    #user_roles = UserRole.find(:all,:conditions =>["user_id = ?", current_user.id]).collect{|r|r.role}
    role_privileges = RolePrivilege.find(:all,:conditions => ["role IN (?)", current_user_roles])
    @privileges = Privilege.find(:all,:conditions => ["privilege IN (?)", role_privileges.collect{|r|r.privilege}])

    #raise @privileges.to_yaml

    @activities = current_user.activities.reject{|activity| 
      CoreService.get_global_property_value("disable_tasks").split(",").include?(activity)
    } rescue current_user.activities
   
    #raise @privileges.to_yaml
    encounter_privilege_hash = generate_encounter_privilege_map   

    if params[:selected_program] == 'HIV PROGRAM' or params[:selected_program] == 'HIV'
      tb_encounters = ['Manage TB Treatment Visits','Manage TB adherence',
        'Manage TB initial visits','Manage Lab Results','Manage HIV Status Visits',
        'Manage Lab Orders','Manage TB Registration Visits',
        'Manage TB Reception Visits','Give Lab Results','Manage Source of Referral',
        'Manage Sputum Submissions','Manage TB Clinic Visits']
      encounter_privilege_hash.delete_if do |key,value|
        tb_encounters.include?(key)
      end
    end

    @privileges = @privileges.collect do |privilege|
      if !encounter_privilege_hash[privilege.privilege.squish].nil?
        encounter_privilege_hash[privilege.privilege.squish].humanize
      else
        privilege.privilege
      end
    end
    
    #.gsub('Hiv','HIV') .gsub('Tb','TB').gsub('Art','ART').gsub('hiv','HIV')
    #.gsub('Hiv','HIV').gsub('Tb','TB').gsub('Art','ART').gsub('hiv','HIV')
    
    @encounter_types = EncounterType.find(:all).map{|enc|enc.name.gsub(/.*\//,"").gsub(/\..*/,"").humanize}
    @available_encounter_types = Dir.glob(RAILS_ROOT+"/app/views/encounters/*.rhtml").map{|file|file.gsub(/.*\//,"").gsub(/\..*/,"").humanize}
    @available_encounter_types -= @available_encounter_types - @encounter_types

    available_privileges_not_from_encounters_folder = []
    
    privileges_not_from_encounters_folder = ['Manage Prescriptions','Manage Appointments', 'Manage Drug Dispensations']
    
    available_privileges_not_from_encounters_folder += privileges_not_from_encounters_folder.select{|pri| @privileges.include?(pri)}

    @privileges =   @privileges - (@privileges - @available_encounter_types) + available_privileges_not_from_encounters_folder
    
    @activities = @activities.collect do |activity| 
      if !encounter_privilege_hash[activity].nil?
        encounter_privilege_hash[activity.squish].gsub('Hiv','HIV').gsub('Tb','TB').gsub('Art','ART').gsub('hiv','HIV')
      else
        activity.gsub('Hiv','HIV').gsub('Tb','TB').gsub('Art','ART').gsub('hiv','HIV')
      end
    end                            

    @privileges = @privileges.collect do |privilege|
      privilege.gsub('Hiv','HIV').gsub('Tb','TB').gsub('Art','ART').gsub('hiv','HIV')
    end
    #@privileges += ['Manage prescriptions','Manage appointments', 'Dispensation']  
    @privileges.sort!
    @patient_id = params[:patient_id]
  end
  
  def change_activities
    privilege_encounter_hash = generate_privilege_encounter_map
    
    params[:user][:activities] = params[:user][:activities].collect do |activity| 
      if !privilege_encounter_hash[activity.squish].nil?
        privilege_encounter_hash[activity.squish]
      else
        activity
      end
    end

    activities = params[:user][:activities]
    current_user.activities = params[:user][:activities]
    if params[:id]
      session_date = session[:datetime].to_date rescue Date.today
      redirect_to next_task(Patient.find(params[:id]))
      return 
    end
    redirect_to '/clinic'
  end
  
  def generate_encounter_privilege_map
    encounter_privilege_map = CoreService.get_global_property_value("encounter_privilege_map").to_s rescue ''
    encounter_privilege_map = encounter_privilege_map.split(",")
    encounter_privilege_hash = {}
    encounter_privilege_map.each do |encounter_privilege|
      encounter_privilege_hash[encounter_privilege.split(":").last.squish] = encounter_privilege.split(":").first.squish
    end
    encounter_privilege_hash
  end
  
  def generate_privilege_encounter_map
    encounter_privilege_map = CoreService.get_global_property_value("encounter_privilege_map").to_s rescue ''
    encounter_privilege_map = encounter_privilege_map.split(",")
    encounter_privilege_hash = {}
    encounter_privilege_map.each do |encounter_privilege|
      encounter_privilege_hash[encounter_privilege.split(":").first.squish.gsub('Hiv','HIV').gsub('Tb','TB').gsub('Art','ART').gsub('hiv','HIV')] = encounter_privilege.split(":").last.squish
    end
    encounter_privilege_hash
  end

  def properties
    if request.post?
      property = UserProperty.find(:first,                                                   
        :conditions =>["property = ? AND user_id = ?",'preferred.keyboard',
          current_user.id])
      if property.blank?
        property = UserProperty.new()
        property.user_id = current_user.id
        property.property = 'preferred.keyboard'
        property.property_value = 'abc' if params[:property_value] == 'No'
        property.property_value = 'qwerty' if params[:property_value] == 'Yes'
        property.save
      else
        property.property_value = 'abc' if params[:property_value] == 'No'
        property.property_value = 'qwerty' if params[:property_value] == 'Yes'
        property.save
      end
      redirect_to '/clinic' and return
    end
  end
  
	def set_user_role
    # Don't show tasks that have been disabled
    @user = User.find(params[:user_id])
    @role=Role.find(:all).map(&:role)
    @user_roles = UserRole.find(:all,:conditions =>["user_id = ?", @user.user_id]).map(&:role)
  end

	def set_role_role
		@roles = Role.find(:all).map(&:role)
	end
	
  def change_role
  	@user_id = params[:id]
  	new_roles = []
  	
  	new_roles = params[:user][:activities] if !params[:user][:activities].blank?
  	current_roles = UserRole.find(:all,:conditions =>["user_id = ?", @user_id]).map(&:role)

  	removed_roles = current_roles - new_roles
  	new_roles -= current_roles
  	
  	new_roles.each do |r|
  		new_role = UserRole.new
  		new_role.user_id = @user_id
  		new_role.role = r
  		new_role.save
  	end
  	
  	removed_roles.each do |r|
  		UserRole.delete_all(["user_id = ? AND role = ?", @user_id, r])
  	end
		redirect_to '/clinic' and return
  end
  
  def roles
  	@role = params[:role_role]
		@selected_role_roles = RoleRole.find(:all, :conditions => ["parent_role = ?", @role]).map(&:child_role)
		@selected_role_roles = [] if @selected_role_roles.blank?
		@roles = Role.find(:all).map(&:role) - [@role]
  end
  
  def set_roles_for_role
  	selected_role = params[:id]
  	new_roles = []
  	
  	new_roles = params[:roles][:select_role] if !params[:roles][:select_role].blank?
  	current_roles = RoleRole.find(:all,:conditions =>["parent_role = ?", selected_role]).map(&:child_role)

  	removed_roles = current_roles - new_roles
  	new_roles -= current_roles

  	new_roles.each do |r|
  		new_role = RoleRole.new
  		new_role.parent_role = selected_role
  		new_role.child_role = r
  		new_role.save
  	end
  	
  	removed_roles.each do |r|
  		RoleRole.delete_all(["parent_role = ? AND child_role = ?", selected_role, r])
  	end
		redirect_to '/clinic' and return
  end
  
  def users
    @users = User.find(:all)
  end
  
  def merge_users
    @user = User.find_by_username(params[:user][:username])
    @users = User.find(:all, :conditions => ["user_id != ? ", @user.user_id])
  	render :layout => "menu" 
  end
  
  def merge
  	primary = params[:primary]
  	secondary = params[:secondary]

  	ActiveRecord::Base.transaction do
      person = Person.find(primary)
      user= User.find(primary)
      reason = "merged with user #{secondary}"
      person.names.each{|row| row.void(reason) }
      person.addresses.each{|row| row.void(reason) }
      person.relationships.each{|row| row.void(reason) }
      person.person_attributes.each{|row| row.void(reason) }
      user.retired = 1
      user.retire_reason = reason
      user.retired_by = current_user.user_id
      user.date_retired = Time.now()
      person.voided = 1
      person.voided_by = current_user.user_id
      person.void_reason = reason
      person.date_voided = Time.now
      user.save
      person.save

  	end
  	
    redirect_to '/clinic' and return
  end
end
