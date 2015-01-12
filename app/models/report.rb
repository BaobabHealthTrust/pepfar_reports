module Report
    def self.generate_cohort_date_range(quarter = "", start_date = nil, end_date = nil)

    quarter_beginning   = start_date.to_date  rescue nil
    quarter_ending      = end_date.to_date    rescue nil
    quarter_end_dates   = []
    quarter_start_dates = []
    date_range          = [nil, nil]

    if(!quarter_beginning.nil? && !quarter_ending.nil?)
      date_range = [quarter_beginning, quarter_ending]
		elsif (!quarter.nil? && quarter == "Cumulative")
      quarter_beginning = PatientService.initial_encounter.encounter_datetime.to_date rescue Date.today
      quarter_ending    = Date.today.to_date

      date_range        = [quarter_beginning, quarter_ending]
		elsif(!quarter.nil? && (/Q[1-4][\_\+\- ]\d\d\d\d/.match(quarter)))
			quarter, quarter_year = quarter.humanize.split(" ")

      quarter_start_dates = ["#{quarter_year}-01-01".to_date, "#{quarter_year}-04-01".to_date, "#{quarter_year}-07-01".to_date, "#{quarter_year}-10-01".to_date]
      quarter_end_dates   = ["#{quarter_year}-03-31".to_date, "#{quarter_year}-06-30".to_date, "#{quarter_year}-09-30".to_date, "#{quarter_year}-12-31".to_date]

      current_quarter   = (quarter.match(/\d+/).to_s.to_i - 1)
      quarter_beginning = quarter_start_dates[current_quarter]
      quarter_ending    = quarter_end_dates[current_quarter]

      date_range = [quarter_beginning, quarter_ending]

    end

    return date_range
  end

  def self.cohort_range(date)
    year = date.year
    if date >= "#{year}-01-01".to_date and date <= "#{year}-03-31".to_date
      quarter = "Q1 #{year}"
    elsif date >= "#{year}-04-01".to_date and date <= "#{year}-06-30".to_date
      quarter = "Q2 #{year}"
    elsif date >= "#{year}-07-01".to_date and date <= "#{year}-09-30".to_date
      quarter = "Q3 #{year}"
    elsif date >= "#{year}-10-01".to_date and date <= "#{year}-12-31".to_date
      quarter = "Q4 #{year}"
    end
    self.generate_cohort_date_range(quarter)
  end

  def self.generate_cohort_quarters(start_date, end_date)
    cohort_quarters   = []
    current_quarter   = ""
    quarter_end_dates = ["#{end_date.year}-03-31".to_date, "#{end_date.year}-06-30".to_date, "#{end_date.year}-09-30".to_date, "#{end_date.year}-12-31".to_date]

    quarter_end_dates.each_with_index do |quarter_end_date, quarter|
      (current_quarter = (quarter + 1) and break) if end_date < quarter_end_date
    end

    quarter_number  =  current_quarter
    cohort_quarters += ["Cumulative"]
    current_date    =  end_date

    begin
      cohort_quarters += ["Q#{quarter_number} #{current_date.year}"]
      (quarter_number > 1) ? quarter_number -= 1: (current_date = current_date - 1.year and quarter_number = 4)
    end while (current_date.year >= start_date.year)

    cohort_quarters
  end


=begin

"SELECT age,gender,count(*) AS total FROM 
            (SELECT age_group(p.birthdate,date(obs.obs_datetime),Date(p.date_created),p.birthdate_estimated) 
            as age,p.gender AS gender
            FROM `encounter` INNER JOIN obs ON obs.encounter_id=encounter.encounter_id
            INNER JOIN patient p ON p.patient_id=encounter.patient_id WHERE
            (encounter_datetime >= '#{start_date}' AND encounter_datetime <= '#{end_date}' 
            AND encounter_type=#{enc_type_id} AND obs.voided=0) GROUP BY encounter.patient_id 
            order by age) AS t group by t.age,t.gender"
=end




  def self.opd_diagnosis(start_date , end_date , groups = ['> 14 to < 20'] )
    age_groups = groups.map{|g|"'#{g}'"}
    concept = ConceptName.find_by_name("DIAGNOSIS").concept_id

=begin
    observations = Observation.find(:all,:joins => "INNER JOIN person p ON p.person_id = obs.person_id
                   INNER JOIN concept_name c ON obs.value_coded = c.concept_id",
                   :select => "value_coded diagnosis , 
                    (SELECT age_group(p.birthdate,LEFT(obs.obs_datetime,10),LEFT(p.date_created,10),p.birthdate_estimated) patient_groups",
                   :conditions => ["concept_id = ? AND obs_datetime >= ? AND obs_datetime <= ?",
                   concept , start_date.strftime('%Y-%m-%d 00:00:00') , end_date.strftime('%Y-%m-%d 23:59:59') ],
                   :group => "diagnosis HAVING patient_groups IN (#{age_groups.join(',')})",
                   :order => "diagnosis ASC")
=end

    observations = Observation.find_by_sql(["SELECT name diagnosis , 
age_group(p.birthdate,DATE(obs_datetime),DATE(p.date_created),p.birthdate_estimated) age_groups 
FROM `obs` 
INNER JOIN person p ON obs.person_id = obs.person_id
INNER JOIN concept_name c ON c.concept_name_id = obs.value_coded_name_id
WHERE (obs.concept_id=#{concept} 
AND obs_datetime >= '#{start_date.strftime('%Y-%m-%d 00:00:00')}'
AND obs_datetime <= '#{end_date.strftime('%Y-%m-%d 23:59:59')}' AND obs.voided = 0) 
GROUP BY diagnosis,age_groups
HAVING age_groups IN (#{age_groups.join(',')})
ORDER BY c.name ASC"])


    return {} if observations.blank?
    results = Hash.new(0)
    observations.map do | obs |
      results[obs.diagnosis] += 1
    end
    results
  end


  def self.opd_diagnosis_by_location(diagnosis , start_date , end_date , groups = ['> 14 to < 20'] )
    age_groups = groups.map{|g|"'#{g}'"}
    concept = ConceptName.find_by_name("DIAGNOSIS").concept_id

=begin
    observations = Observation.find(:all,:joins => "INNER JOIN person p ON p.person_id = obs.person_id
                   INNER JOIN concept_name c ON obs.value_coded = c.concept_id",
                   :select => "value_coded diagnosis , 
                    (SELECT age_group(p.birthdate,LEFT(obs.obs_datetime,10),LEFT(p.date_created,10),p.birthdate_estimated) patient_groups",
                   :conditions => ["concept_id = ? AND obs_datetime >= ? AND obs_datetime <= ?",
                   concept , start_date.strftime('%Y-%m-%d 00:00:00') , end_date.strftime('%Y-%m-%d 23:59:59') ],
                   :group => "diagnosis HAVING patient_groups IN (#{age_groups.join(',')})",
                   :order => "diagnosis ASC")
=end

    observations = Observation.find_by_sql(["SELECT name diagnosis , city_village village , 
age_group(p.birthdate,DATE(obs_datetime),DATE(p.date_created),p.birthdate_estimated) age_groups 
FROM `obs` 
INNER JOIN person p ON obs.person_id = obs.person_id
INNER JOIN concept_name c ON c.concept_name_id = obs.value_coded_name_id
INNER JOIN person_address pd ON obs.person_id = pd.person_id
WHERE (obs.concept_id=#{concept} 
AND obs_datetime >= '#{start_date.strftime('%Y-%m-%d 00:00:00')}'
AND obs_datetime <= '#{end_date.strftime('%Y-%m-%d 23:59:59')}' AND obs.voided = 0) 
GROUP BY diagnosis , village ,age_groups
HAVING age_groups IN (#{age_groups.join(',')}) AND diagnosis = ?
ORDER BY c.name ASC",diagnosis])


    return {} if observations.blank?
    results = Hash.new(0)
    observations.map do | obs |
      results["#{obs.village}::#{obs.diagnosis}"] += 1
    end
    results
  end

  def self.opd_diagnosis_plus_demographics(diagnosis , start_date , end_date , groups = ['> 14 to < 20'] )
    age_groups = groups.map{|g|"'#{g}'"}
    concept = ConceptName.find_by_name("DIAGNOSIS").concept_id
    attribute_type = PersonAttributeType.find_by_name("Cell Phone Number").id

    observations = Observation.find_by_sql(["SELECT 
p.person_id patient_id , pn.given_name first_name, pn.family_name last_name , p.birthdate, 
LEFT(obs.obs_datetime,10) visit_date, p.gender , pa.value phone_number , cn.name diagnosis,
age(p.birthdate, LEFT(obs_datetime,10),LEFT(p.date_created,10), p.birthdate_estimated) visit_age,
age(p.birthdate, current_date, current_date, p.birthdate_estimated) current_age, 
age_group(p.birthdate, LEFT(obs_datetime,10),LEFT(p.date_created,10), p.birthdate_estimated) age_groups, 
pd.city_village address, (SELECT address2 FROM person_address i WHERE i.person_id = p.person_id limit 1) landmark
FROM `obs`
INNER JOIN concept_name cn ON obs.value_coded_name_id = cn.concept_name_id
INNER JOIN person p ON obs.person_id = p.person_id
INNER JOIN person_attribute pa ON p.person_id = pa.person_id
INNER JOIN person_name pn ON p.person_id = pn.person_id
INNER JOIN person_address pd ON p.person_id = pd.person_id
WHERE (obs.concept_id = ? AND obs.obs_datetime >= ? AND obs.obs_datetime <= ? AND pa.person_attribute_type_id = ?) 
GROUP BY first_name,last_name,birthdate,gender,visit_date,value_coded_name_id
HAVING age_groups IN (#{age_groups.join(',')}) AND diagnosis = ?
ORDER BY age_groups DESC",concept , start_date.strftime('%Y-%m-%d 00:00:00'),
end_date.strftime('%Y-%m-%d 23:59:59'),attribute_type,diagnosis])

    return {} if observations.blank?
    results = Hash.new()
    count = 0
    observations.map do | obs |
      results["#{obs.patient_id}:#{obs.visit_date}"][:diagnosis] << obs.diagnosis unless results["#{obs.patient_id}:#{obs.visit_date}"].blank?
      results["#{obs.patient_id}:#{obs.visit_date}"] = {
                            :name => "#{obs.first_name} #{obs.last_name}",
                            :birthdate => obs.birthdate ,
                            :visit_date => obs.visit_date,
                            :visit_age => obs.visit_age,
                            :current_age => obs.current_age,
                            :phone_number => obs.phone_number,
                            :diagnosis => [obs.diagnosis]  ,
                            :age_group => obs.age_groups,
                            :address => obs.address
                          } if results["#{obs.patient_id}:#{obs.visit_date}"].blank?
    end
    results
  end


  def self.opd_disaggregated_diagnosis(start_date , end_date , groups = ['> 14 to < 20'] )
    age_groups = groups.map{|g|"'#{g}'"}
    concept = ConceptName.find_by_name("DIAGNOSIS").concept_id

    observations = Observation.find_by_sql(["SELECT p.person_id patient_id , p.gender gender , name diagnosis ,  
age_group(p.birthdate,DATE(obs_datetime),DATE(p.date_created),p.birthdate_estimated) age_groups
FROM `obs` 
INNER JOIN person p ON obs.person_id = p.person_id
INNER JOIN concept_name c ON c.concept_name_id = obs.value_coded_name_id
WHERE (obs.concept_id=#{concept} 
AND obs_datetime >= '#{start_date.strftime('%Y-%m-%d 00:00:00')}'
AND obs_datetime <= '#{end_date.strftime('%Y-%m-%d 23:59:59')}' AND obs.voided = 0) 
GROUP BY patient_id , age_groups , diagnosis 
HAVING age_groups IN (#{age_groups.join(',')})
ORDER BY diagnosis ASC"])


    return {} if observations.blank?
    results = Hash.new()
    observations.map do | obs |
      results[obs.diagnosis] = {obs.gender => {
                                 :less_than_six_months => 0,
                                 :six_months_to_five_years => 0,
                                 :five_years_to_fourteen_years => 0,
                                 :over_fourteen_years => 0 
                               }} if results[obs.diagnosis].blank?

     if results[obs.diagnosis][obs.gender].blank?
       results[obs.diagnosis] = {obs.gender => {
                                  :less_than_six_months => 0,
                                  :six_months_to_five_years => 0,
                                  :five_years_to_fourteen_years => 0,
                                  :over_fourteen_years => 0 
                                }} 
     end 


     case obs.age_groups
        when "< 6 months" 
          results[obs.diagnosis][obs.gender][:less_than_six_months]+=1
        when "6 months to < 1 yr" , "1 to < 5"
          results[obs.diagnosis][obs.gender][:six_months_to_five_years]+=1
        when "5 to 14"
          results[obs.diagnosis][obs.gender][:five_years_to_fourteen_years]+=1
        else
          results[obs.diagnosis][obs.gender][:over_fourteen_years]+=1
      end
    
    end
    results
  end

  def self.opd_referrals(start_date , end_date)
    concept = ConceptName.find_by_name("REFERRAL CLINIC IF REFERRED").concept_id

    observations = Observation.find_by_sql(["SELECT value_text clinic , count(*) total
FROM `obs` 
INNER JOIN concept_name c ON c.concept_name_id = obs.concept_id
WHERE (obs.concept_id=#{concept} 
AND obs_datetime >= '#{start_date.strftime('%Y-%m-%d 00:00:00')}'
AND obs_datetime <= '#{end_date.strftime('%Y-%m-%d 23:59:59')}' AND obs.voided = 0) 
GROUP BY clinic
ORDER BY clinic ASC"])


    return {} if observations.blank?
    results = Hash.new()
    observations.map do | obs |
      results[obs.clinic] = 1
    end
    results
  end

  def self.set_appointments(date = Date.today,identifier_type = 'Filing number')
    concept_id = ConceptName.find_by_name("Appointment date").concept_id
    records = Observation.find(:all,:joins =>"INNER JOIN person p 
      ON p.person_id = obs.person_id
      INNER JOIN person_name n ON p.person_id=n.person_id                                 
      RIGHT JOIN patient_identifier i ON i.patient_id = obs.person_id 
      AND i.identifier_type = (SELECT patient_identifier_type_id 
      FROM patient_identifier_type pi WHERE pi.name = '#{identifier_type}')",
      :conditions =>["obs.concept_id=? AND value_datetime >= ? AND value_datetime <=?",
      concept_id,date.strftime('%Y-%m-%d 00:00:00'),date.strftime('%Y-%m-%d 23:59:59')],
      :select =>"obs.obs_id obs_id,obs.person_id patient_id,n.given_name first_name,n.family_name last_name, 
      p.gender gender,p.birthdate birthdate, obs.obs_datetime visit_date , i.identifier identifier",
      :order => "obs.obs_datetime DESC")

    demographics = {}
    (records || []).each do |r|
      demographics[r.obs_id] = {:first_name => r.first_name,
                            :last_name => r.last_name,
                            :gender => r.gender,
                            :birthdate => r.birthdate,
                            :visit_date => r.visit_date,
                            :patient_id => r.patient_id,
                            :identifier => r.identifier}
    end
    return demographics
  end

  def self.total_registered(start_date, end_date, age)
    total_registered = {}
=begin
    result = Encounter.find_by_sql("SELECT * FROM earliest_start_date e
      INNER JOIN person p ON p.person_id = e.patient_id AND p.voided = 0 
      WHERE e.earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}'
      AND (LEFT(e.date_enrolled,10) = e.earliest_start_date) 
      AND age_at_initiation BETWEEN #{age.first} AND #{age.last} 
      GROUP BY e.patient_id;")
=end

    result = Encounter.find_by_sql("SELECT * FROM earliest_start_date e
      INNER JOIN person p ON p.person_id = e.patient_id AND p.voided = 0 
      WHERE e.earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}'
      AND age_at_initiation BETWEEN #{age.first} AND #{age.last} 
      GROUP BY e.patient_id;")

    unless result.blank?
      result.each do |r|
        gender =  r.gender.upcase rescue nil
        next if gender.blank?
        if total_registered[r.patient_id].blank? 
          total_registered[r.patient_id] = []

          total_registered[r.patient_id] = {
            :earliest_start_date =>  r.earliest_start_date,
            :age_at_initiation => r.age_at_initiation,
            :gender => gender
          }
        end
      end
    end
    return total_registered
  end

  def self.followup_months(patients_to_follow, start_date)
    end_date = start_date.end_of_month
    patient_ids = patients_to_follow.join(',')

    result = Encounter.find_by_sql("SELECT p.person_id,i.identifier arv_number,
      e.age_at_initiation, current_state_for_program(e.patient_id, 1, '#{end_date}') outcome,
      p.gender gender, p.birthdate, e.earliest_start_date
      FROM earliest_start_date e
      INNER JOIN person p ON p.person_id = e.patient_id 
      RIGHT JOIN patient_identifier i ON i.patient_id = e.patient_id 
      AND i.voided = 0 AND i.identifier_type = 4
      WHERE e.patient_id IN(#{patient_ids}) GROUP BY e.patient_id")
   

    followup_patients = {}
    (result || []).each do |r|
      if followup_patients[r.person_id].blank?
        followup_patients[r.person_id] = []
      end
      
      followup_patients[r.person_id] = {
        :earliest_start_date =>  r.earliest_start_date,
        :age_at_initiation => r.age_at_initiation,
        :gender => r.gender, :outcome => self.get_outcome(r.person_id,r.outcome,end_date),
        :arv_number => r.arv_number,:dob => r.birthdate
      }
    end
    followup_patients
  end

  def self.get_outcome(patient_id,outcome,end_date)
    case outcome 
      when  '7'
        defaulter = Encounter.find_by_sql("SELECT current_defaulter(#{patient_id},'#{end_date}') as outcome;")
        if defaulter.last.outcome == '1'
          return 'Defaulter'
        end
        return 'On ART'
      when '3'
        return 'Died'
      when '2'
        return 'Transfered out'
      when '3'
        return 'Died'
      when '6'
        return 'Treatement stopped'
      else
        return 'Unknown'
    end
  end

  def self.total_registered_pregnant(start_date, end_date, age)
    total_registered = {}
=begin
    result = Encounter.find_by_sql("SELECT p.person_id patient_id,p.birthdate,p.gender,obs.obs_datetime,
      e.earliest_start_date,e.age_at_initiation FROM obs 
      INNER JOIN person p ON p.person_id = obs.person_id AND p.voided = 0 
      AND obs.voided = 0 AND p.gender = 'F'
      INNER JOIN earliest_start_date e ON e.patient_id = p.person_id
      AND e.earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}'
      WHERE obs.concept_id = 7563 AND value_coded = 1755
      AND (LEFT(e.date_enrolled,10) = e.earliest_start_date)
      AND e.age_at_initiation BETWEEN #{age.first} AND #{age.last} 
      GROUP BY e.patient_id")
=end

    result = Encounter.find_by_sql("SELECT p.person_id patient_id,p.birthdate,p.gender,obs.obs_datetime,
      e.earliest_start_date,e.age_at_initiation FROM obs 
      INNER JOIN person p ON p.person_id = obs.person_id AND p.voided = 0 
      AND obs.voided = 0 AND p.gender = 'F'
      INNER JOIN earliest_start_date e ON e.patient_id = p.person_id
      AND e.earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}'
      WHERE obs.concept_id = 7563 AND value_coded = 1755
      AND e.age_at_initiation BETWEEN #{age.first} AND #{age.last} 
      GROUP BY e.patient_id")

    unless result.blank?
      result.each do |r|
        gender =  r.gender.upcase rescue nil
        next if gender.blank?
        if total_registered[r.patient_id].blank? 
          total_registered[r.patient_id] = []

          total_registered[r.patient_id] = {
            :earliest_start_date =>  r.earliest_start_date,
            :age_at_initiation => r.age_at_initiation,
            :gender => gender
          }
        end
      end
    end

    patient_ids = total_registered.keys.join(',') rescue []
    unless patient_ids.blank?
=begin
      result = Encounter.find_by_sql("SELECT p.person_id patient_id,p.gender,
        e.earliest_start_date,e.age_at_initiation FROM earliest_start_date e
        INNER JOIN person p ON p.person_id = e.patient_id AND p.voided = 0 AND p.gender = 'F'
        AND e.earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}'
        INNER JOIN patient_pregnant_obs preg ON preg.person_id = e.patient_id
        WHERE preg.value_coded = 1065 AND preg.person_id NOT IN(#{patient_ids})
        AND (LEFT(e.date_enrolled,10) = e.earliest_start_date)
        AND e.age_at_initiation BETWEEN #{age.first} AND #{age.last} 
        AND DATEDIFF(e.earliest_start_date,preg.obs_datetime) <= 30
        GROUP BY e.patient_id")
=end
      result = Encounter.find_by_sql("SELECT p.person_id patient_id,p.gender,
        e.earliest_start_date,e.age_at_initiation FROM earliest_start_date e
        INNER JOIN person p ON p.person_id = e.patient_id AND p.voided = 0 AND p.gender = 'F'
        AND e.earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}'
        INNER JOIN patient_pregnant_obs preg ON preg.person_id = e.patient_id
        WHERE preg.value_coded = 1065 AND preg.person_id NOT IN(#{patient_ids})
        AND e.age_at_initiation BETWEEN #{age.first} AND #{age.last} 
        AND DATEDIFF(preg.obs_datetime, e.earliest_start_date) BETWEEN 0 AND 30
        GROUP BY e.patient_id")

      unless result.blank?
        result.each do |r|
          gender =  r.gender.upcase rescue nil
          next if gender.blank?
          if total_registered[r.patient_id].blank? 
            total_registered[r.patient_id] = []

            total_registered[r.patient_id] = {
              :earliest_start_date =>  r.earliest_start_date,
              :age_at_initiation => r.age_at_initiation,
              :gender => gender
            }
          end
        end
      end
    end

    return total_registered
  end

  def self.total_new_registered(start_date, end_date, age)
    total_registered = {}

    result = Encounter.find_by_sql("SELECT * FROM earliest_start_date e
      INNER JOIN person p ON p.person_id = e.patient_id AND p.voided = 0 
      WHERE e.earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}'
      AND (LEFT(e.date_enrolled,10) = e.earliest_start_date) 
      AND age_at_initiation BETWEEN #{age.first} AND #{age.last} 
      GROUP BY e.patient_id;")

    unless result.blank?
      result.each do |r|
        gender =  r.gender.upcase rescue nil
        next if gender.blank?
        if total_registered[r.patient_id].blank? 
          total_registered[r.patient_id] = []

          total_registered[r.patient_id] = {
            :earliest_start_date =>  r.earliest_start_date,
            :age_at_initiation => r.age_at_initiation,
            :gender => gender
          }
        end
      end
    end
    return total_registered
  end

  def self.on_art_started_ipt(start_date, end_date, age)
    total_registered = {}
    dispensing_encounter_type_id = EncounterType.find_by_name("DISPENSING").id
    isoniazed_concept_id = Concept.find_by_name('ISONIAZID').id
    amount_dispensed_concept = Concept.find_by_name('Amount dispensed').id
    result = Encounter.find_by_sql("SELECT * FROM earliest_start_date e
      INNER JOIN person p ON p.person_id = e.patient_id
      INNER JOIN encounter enc ON enc.patient_id = p.person_id AND
      enc.encounter_type = #{dispensing_encounter_type_id} INNER JOIN obs ON enc.encounter_id=obs.encounter_id
      INNER JOIN orders o ON obs.order_id = o.order_id INNER JOIN drug_order do ON
      o.order_id = do.order_id INNER JOIN drug d ON do.drug_inventory_id = d.drug_id
      AND d.concept_id = #{isoniazed_concept_id} AND obs.concept_id = #{amount_dispensed_concept}
      AND p.voided = 0 WHERE e.earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}'
      AND (LEFT(e.date_enrolled,10) = e.earliest_start_date)
      AND age_at_initiation BETWEEN #{age.first} AND #{age.last}
      GROUP BY e.patient_id")

    unless result.blank?
      result.each do |r|
        gender =  r.gender.upcase rescue nil
        next if gender.blank?
        if total_registered[r.patient_id].blank?
          total_registered[r.patient_id] = []

          total_registered[r.patient_id] = {
            :earliest_start_date =>  r.earliest_start_date,
            :age_at_initiation => r.age_at_initiation,
            :gender => gender
          }
        end
      end
    end
    return total_registered
  end

  def self.on_art_with_tb_symptoms(start_date, end_date, age)
    hiv_clinic_consultation_enc_id = EncounterType.find_by_name("HIV CLINIC CONSULTATION").id
    tb_concept_id = ConceptName.find_by_name("Routine Tuberculosis Screening").concept_id
    tb_symptoms_ids = ConceptSet.find_all_by_concept_set(tb_concept_id, :order => 'sort_weight').collect{|cs|
      cs.concept.concept_id
    }
    routine_tb_screening_concept_id = Concept.find_by_name("ROUTINE TB SCREENING").id
    total_registered = {}

    result = Encounter.find_by_sql("SELECT * FROM earliest_start_date e
      INNER JOIN person p ON p.person_id = e.patient_id
      INNER JOIN encounter enc ON enc.patient_id = p.person_id AND
      enc.encounter_type = #{hiv_clinic_consultation_enc_id} INNER JOIN obs ON
      enc.encounter_id=obs.encounter_id AND obs.concept_id=#{routine_tb_screening_concept_id}
      AND DATE(obs.obs_datetime) = (SELECT MAX(DATE(encounter_datetime)) FROM encounter WHERE
      patient_id = e.patient_id AND voided=0 LIMIT 1)
      AND p.voided = 0 WHERE e.earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}'
      AND (LEFT(e.date_enrolled,10) = e.earliest_start_date)
      AND age_at_initiation BETWEEN #{age.first} AND #{age.last}
      GROUP BY e.patient_id
      HAVING value_coded IN (#{tb_symptoms_ids.join(', ')})")

    unless result.blank?
      result.each do |r|
        gender =  r.gender.upcase rescue nil
        next if gender.blank?
        if total_registered[r.patient_id].blank?
          total_registered[r.patient_id] = []

          total_registered[r.patient_id] = {
            :earliest_start_date =>  r.earliest_start_date,
            :age_at_initiation => r.age_at_initiation,
            :gender => gender
          }
        end
      end
    end
    return total_registered
  end

  def self.patients_list(patient_ids,date = Date.today.to_s)
    total_registered = {}

    result = Encounter.find_by_sql("SELECT p.person_id patient_id, e.earliest_start_date,
      p.birthdate,p.gender,n.given_name,n.family_name,
      current_state_for_program(p.person_id, 1, DATE('#{date}')) state,
      current_defaulter(p.person_id,DATE('#{date}')) defaulter,
      e.earliest_start_date,e.age_at_initiation,i.identifier arv_number,
      i2.identifier national_id,obs.value_coded reason_for_art_concept_id
      FROM earliest_start_date e
      INNER JOIN person p ON p.person_id = e.patient_id AND p.voided = 0 
      LEFT JOIN patient_identifier i ON p.person_id = i.patient_id 
      AND i.voided = 0 AND i.identifier_type = 4
      LEFT JOIN patient_identifier i2 ON p.person_id = i2.patient_id 
      AND i2.voided = 0 AND i2.identifier_type = 3
      LEFT JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
      LEFT JOIN obs ON obs.person_id = p.person_id AND obs.voided = 0
      AND obs.concept_id = 7563
      WHERE p.person_id IN(#{patient_ids})
      GROUP BY p.person_id;")

    unless result.blank?
      result.each do |r|
        gender =  r.gender.upcase rescue nil
        next if gender.blank?
        if total_registered[r.patient_id].blank? 
          total_registered[r.patient_id] = []
          total_registered[r.patient_id] = {
            :earliest_start_date =>  r.earliest_start_date,
            :age_at_initiation => r.age_at_initiation,
            :birthdate => r.birthdate, :family_name => r.family_name,
            :given_name => r.given_name, :gender => gender,
            :outcome => self.get_outcome(r.patient_id, r.state, date),
            :reason_for_art => self.get_reason_for_art(r.reason_for_art_concept_id),
            :defaulter => r.defaulter,:national_id => r.national_id,:arv_number => r.arv_number
          }
        end
      end
    end
    return total_registered
  end

  def self.get_reason_for_art(concept_id = nil)
    return if concept_id.blank?
    ConceptName.find_by_concept_id(concept_id).name
  end

end
