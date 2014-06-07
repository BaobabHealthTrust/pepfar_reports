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

  def art_patients(start_date, end_date, retained_date, ids)
    patients_ids = []
    patients_ages = []
    patient_outcome = {}
    PatientProgram.find_by_sql("SELECT p.patient_id, e.age_at_initiation AS age, current_state_for_program(p.patient_id, 1, '#{retained_date}') AS state, c.name as status FROM patient p
                                INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, 1, '#{retained_date}')
                                INNER join earliest_start_date e ON e.patient_id = p.patient_id
                                INNER JOIN concept_name c ON c.concept_id = pw.concept_id
                                WHERE earliest_start_date >= '#{start_date}' AND earliest_start_date  <= '#{end_date}'
                                AND e.patient_id NOT IN (#{ids})").each do | patient |
      patients_ids << patient.patient_id
      patients_ages << patient.age #rescue "N/A"
      status = patient.status
      status = "Died" if status.match(/died/i)
      status = "Alive and On treatment" if status.match(/antire/i)
      status = "Alive and On treatment" if status.match(/treat/i)
      status = "Alive and On treatment" if status.match(/arvs/i)
      patient_outcome[status] = [] if patient_outcome[status].blank?
      patient_outcome[status] << patient.patient_id
    end

    return patients_ids, patients_ages, patient_outcome
  end

	def defaulted_patients(start_date, end_date, retained_date)
		patients_ids = []
    patients_ages = []
		 PatientProgram.find_by_sql("SELECT e.patient_id, e.age_at_initiation AS age, current_defaulter(patient_id, '#{retained_date}') AS def
											FROM earliest_start_date e LEFT JOIN person p ON p.person_id = e.patient_id
											WHERE e.earliest_start_date >= '#{start_date}' AND e.earliest_start_date <=  '#{end_date}' AND p.dead=0
											HAVING def = 1 AND current_state_for_program(patient_id, 1, '#{retained_date}') NOT IN (6, 2, 3)").each do | patient |
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
