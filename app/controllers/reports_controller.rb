class ReportsController < ApplicationController
  def on_art
    if not params[:start_date].blank? and not params[:end_date].blank?
      @start_date = params[:start_date].to_date
      @end_date = params[:end_date].to_date
      case params[:age]
        when 'All'
          age = [0,1000]
          @age_group = "All patients"
        when '0,0'
          age = [0,0]
          @age_group = "Patients under one year old when starting"
        when '1 to 14'
          age = [1,14]
          @age_group = "Patients between 1 yr and under 15 yrs old when starting"
        when '>= 15'
          age = [15,1000]
          @age_group = "Patients over 15 years old when starting"
      end

      @total_registered = Report.total_registered(@start_date, @end_date, age)
      @followup_months = {}
      unless @total_registered.blank?
        patients_to_follow = @total_registered.keys
        (1.upto(12)).each do |m|
          next unless m == 12
          followup_start_date = @start_date + m.month
          @followup_months[followup_start_date] = Report.followup_months(patients_to_follow,followup_start_date)
        end
      end
    end

  end

end
