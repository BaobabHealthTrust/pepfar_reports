class CohortToolController < ApplicationController

def monthly_survival
        @year = params[:year]
        @month = params[:month]
        month = month_number(params[:month])
        reg_month_start = "#{@year}-#{month}-01".to_date
        reg_month_end = reg_month_start.end_of_month
        ret_month = month_number(params[:retension_month])
        retained = "#{params[:retension_year]}-#{ret_month}-01".to_date.end_of_month
        @ret_year = params[:retension_year]
        @ret_month = params[:retension_month]
        @def_ids, @def_ages = defaulted_patients(reg_month_start, reg_month_end, retained)
        @art_ids, @art_age, @outcome = art_patients(reg_month_start, reg_month_end, retained, @def_ids.join(","))
        session[:ids] = @def_ids + @art_ids
        session[:defaulters] = @def_ids
        #session[:art_id] = @art_ids
        @age = {}
        @age["less1"] = 0
        @age["less15"] = 0
        @age["more15"] = 0
        @def_ages.each {|age|
           if age.to_i < 1
             @age["less1"] += 1
           elsif age.to_i >= 1 and age.to_i < 15
             @age["less15"] += 1
           else
             @age["more15"] += 1
           end
        }
        @art_age.each {|age|
           if age.to_i < 1
             @age["less1"] += 1
           elsif age.to_i >= 1 and age.to_i < 15
             @age["less15"] += 1
           else
             @age["more15"] += 1
           end
        }


        @total = @def_ids.length + @art_ids.length
        render :template => '/administration/index'
  end

  def list
    #raise params.to_yaml
    if params[:id] == "0_to_1"
      @data = drill_ages(0, 1)
      @category = "Age - 0 to 1"
    elsif params[:id] == "1_to_15"
      @data = drill_ages(1, 15)
      @category = "Age - 1 to 15"
    elsif params[:id] == "15_to_100"
      @data = drill_ages(15, 1000)
      @category = "Age - Above 15"
    elsif params[:id] == "total"
      @data = drill_outcomes(session[:ids])
      @category = "Total Registered"
    elsif params[:id] == "defaulted"
      @data = drill_outcomes(session[:defaulters])
      @category = "Outcome - Defaulters"
    elsif params[:id] == "Died"
      @data = drill_outcomes(session[:died])
      @category = "Outcome - Died"
    elsif params[:id] == "Alive and on treatment"
       @data = drill_outcomes(session[:alive])
       @category = "Outcome - Alive and on treatment"
    elsif params[:id] == "Transferred out"
       @data = drill_outcomes(session[:transferred])
       @category = "Outcome - Transferred out"
    elsif params[:id] == "Unknown"
       @data = drill_outcomes(session[:unknown])
       @category = "Outcome - Unknown"
    end
    
  end
   
  def drill_ages(min, max)
    return [] if session[:ids].blank?
    patients_ids = []
    PatientProgram.find_by_sql("
                    SELECT p.patient_id, p.identifier, pe.gender FROM earliest_start_date e
                    LEFT JOIN patient_identifier p ON e.patient_id = p.patient_id
                    INNER JOIN person pe ON pe.person_id = p.patient_id
                    WHERE e.age_at_initiation >= #{min} AND e.age_at_initiation < #{max}
                    AND p.voided = 0
                    AND p.identifier_type = 4 AND p.patient_id IN (#{session[:ids].join(',')})
                   ").each do | patient |
				patients_ids << [patient.patient_id, patient.identifier, patient.gender]
     end
     return patients_ids
  end

  def drill_outcomes(ids)
    return [] if ids.blank?
    patients_ids = []
    PatientProgram.find_by_sql("
                    SELECT e.patient_id, p.identifier, pe.gender FROM earliest_start_date e
                    LEFT JOIN patient_identifier p ON e.patient_id = p.patient_id
                    INNER JOIN person pe ON pe.person_id = p.patient_id
                    WHERE p.identifier_type = 4 AND p.voided = 0 AND p.patient_id IN (#{ids.join(',')})
                   ").each do | patient |
				patients_ids << [patient.patient_id, patient.identifier, patient.gender]
     end
     return patients_ids
  end

  def pre_art(start_date, end_date)
    patients_ids = []
    PatientProgram.find_by_sql("
                    SELECT p.patient_id, (SELECT MIN(obs_datetime) FROM obs o WHERE o.person_id = p.patient_id) current FROM patient p
                    WHERE p.voided = 0 AND DATE(current) >= '#{start_date}' AND DATE(current) <= '#{end_date}'").each{|patient|
                    patients_ids << [patient.patient_id, patient.current]
                    }

    return patients_ids
  end

  def art_patients(start_date, end_date, retained_date, ids)
    unless ids.blank?
      conditions = " AND e.patient_id NOT IN (#{ids})"
    end
    patients_ids = []
    patients_ages = []
    patient_outcome = {}
    patient_outcome["Alive and on treatment"] = []
    patient_outcome["Died"] = []
    patient_outcome["Unknown"] = []
    patient_outcome["Transferred out"] = []
    PatientProgram.find_by_sql("SELECT p.patient_id, e.age_at_initiation AS age, current_state_for_program(p.patient_id, 1, '#{retained_date}') AS state, c.name as status FROM patient p
                                INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, 1, '#{retained_date}')
                                INNER join earliest_start_date e ON e.patient_id = p.patient_id
                                INNER JOIN concept_name c ON c.concept_id = pw.concept_id
                                WHERE earliest_start_date >= '#{start_date}' AND earliest_start_date  <= '#{end_date}' #{conditions}
                                 AND DATE(e.date_enrolled) = DATE(e.earliest_start_date)").each do | patient |
      next if patients_ids.include?(patient.patient_id)
      patients_ids << patient.patient_id
      patients_ages << patient.age #rescue "N/A"
      status = patient.status
      if status.match(/died/i)
        patient_outcome["Died"] << patient.patient_id
      elsif status.match(/antire/i)
        patient_outcome["Alive and on treatment"] << patient.patient_id
      elsif status.match(/treat/i)
        patient_outcome["Alive and on treatment"] << patient.patient_id
      elsif status.match(/arvs/i)
        patient_outcome["Alive and on treatment"] << patient.patient_id
      elsif status.match(/transfer/i)
        patient_outcome["Transferred out"] << patient.patient_id
      else
        patient_outcome["Unknown"] << patient.patient_id
      end

    end
    session[:transferred] = patient_outcome["Transferred out"]
    session[:unknown] = patient_outcome["Unknown"]
    session[:alive] = patient_outcome["Alive and on treatment"]
    session[:died] = patient_outcome["Died"]

    return patients_ids, patients_ages, patient_outcome
  end

	def defaulted_patients(start_date, end_date, retained_date)
		patients_ids = []
    patients_ages = []
		 PatientProgram.find_by_sql("SELECT e.patient_id, e.age_at_initiation AS age, current_defaulter(patient_id, '#{retained_date}') AS def
											FROM earliest_start_date e LEFT JOIN person p ON p.person_id = e.patient_id
											WHERE e.earliest_start_date >= '#{start_date}' AND e.earliest_start_date <=  '#{end_date}' AND p.dead=0
                      AND DATE(e.date_enrolled) = DATE(e.earliest_start_date)
											HAVING def = 1 AND current_state_for_program(patient_id, 1, '#{retained_date}') NOT IN (6, 2, 3)").each do | patient |
				next if patients_ids.include?(patient.patient_id)
        patients_ids << patient.patient_id
        patients_ages << patient.age
     end
      return patients_ids, patients_ages
  end

	def month_number(m)
    months = {}
    months["January"] = 1
    months["February"] = 2
    months["March"] = 3
    months["April"] = 4
    months["May"] = 5
    months["June"] = 6
    months["July"] = 7
    months["August"] = 8
    months["September"] = 9
    months["October"] = 10
    months["November"] = 11
    months["December"] = 12
    return months[m]
  end

end
