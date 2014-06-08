class ReportsController < ApplicationController
  def on_art
    if not params[:start_date].blank? and not params[:end_date].blank?
      @start_date = params[:start_date].to_date
      @end_date = params[:end_date].to_date

      @total_registered = Report.total_registered(@start_date, @end_date)
      @followup_months = {}
      unless @total_registered.blank?
        patients_to_follow = @total_registered.keys
        (1.upto(12)).each do |m|
          followup_start_date = @start_date + m.month
          @followup_months[followup_start_date] = Report.followup_months(patients_to_follow,followup_start_date)
        end
      end
    end

  end

end
