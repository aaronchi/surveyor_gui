module SurveyorGui::ReportHelper

  STAT_FUNCTIONS = {
    sum: ->(arr){arr.sum},
    min: ->(arr){arr.min},
    max: ->(arr){arr.max},
    average: ->(arr){arr.average}
  }

  STAT_FORMATS = {
    number: "%g",
    date: "%m-%d-%y",
    time: "%I:%M:%S %P",
    datetime: "%m-%d-%y %I:%M:%S %P"
  }

  def question_should_display(q)
    display=true
    if q.dependency
      q.dependency.dependency_conditions.each do |dc|
        if Response.where(:question_id => dc.question_id).first && dc.answer_id != Response.where(:question_id => dc.question_id).first.answer_id
          display=false
        end
      end
    end
    return display
  end
  
  def star_average(responses,q)
    (responses.where(:question_id => q.id).where('integer_value > ?',0).collect(&:integer_value).average * 2).round
  end

  def stats(q, stat_function)
    stat = calculate_stats(q, stat_function)
    format_stats(q, stat)
  end

  def calculate_stats(q, stat_function)
    arr =  @responses.where(:question_id => q.id).map{|r| r.response_value.to_f}
    STAT_FUNCTIONS[stat_function].call(arr)
  end
  
  def format_stats(q, stat)
    if q.question_type_id == :number
      STAT_FORMATS[q.question_type_id] % stat 
    else
      stat = Time.zone.at(stat)     
      stat.strftime(STAT_FORMATS[q.question_type_id])
    end
  end

end
