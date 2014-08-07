require 'complex'
include Math

class SurveyorGui::ReportsController < ApplicationController
  def preview
    response_qty = 5 
    @title = "Preview Report for "+response_qty.to_s+" randomized responses"
    @survey = Survey.find(params[:survey_id])
    user_id = defined?(current_user) ? current_user.id : 1 
    ResponseSet.where('survey_id = ? and test_data = ? and user_id = ?',report_params[:survey_id],true, user_id).each {|r| r.destroy}
    response_qty.times.each {
      @response_set = ResponseSet.create(:survey => @survey, :user_id => user_id, :test_data => true)
      generate_1_result_per_question(@response_set, @survey)
    }
    @response_sets = ResponseSet.where('survey_id = ? and test_data = ? and user_id = ?',params[:survey_id],true, user_id)
    @responses = Response.joins(:response_set, :answer).where('user_id = ? and survey_id = ? and test_data = ?',user_id,params[:survey_id],true)
    if (!@survey)
      flash[:notice] = "Survey/Questionnnaire not found."
      redirect_to :back
    end
    generate_report(params[:survey_id], true)
    render :show    
  end

  def generate_report(survey_id, test)
    questions = Question.joins(:survey_section).where('survey_sections.survey_id = ?', survey_id)
# multiple_choice_responses = Response.joins(:response_set, :answer).where('survey_id = ? and test_data = ?',survey_id,test).group('responses.question_id','answers.id','answers.text').select('responses.question_id, answers.id, answers.text as text, count(*) as answer_count').order('responses.question_id','answers.id')
 
# multiple_choice_responses = Answer.unscoped.joins(:question=>:survey_section).includes(:responses=>:response_set).where('survey_sections.survey_id=? and (response_sets.test_data=? or response_sets.test_data is null)',survey_id,test).group('answers.question_id','answers.id','answers.text').select('answers.question_id, answers.id, answers.text as text, count(*) as answer_count').order('answers.question_id','answers.id')

# multiple_choice_responses = Answer.unscoped.find(:all,
# :joins => "LEFT JOIN responses ON responses.answer_id = answers.id",
# :select => "answers.question_id, answers.id, answers.text as text, count(answers.*) as answer_count",
# :group => "answers.question_id, answers.id, answers.text",
# :order => "answers.question_id, answers.id")

    multiple_choice_responses = Answer.unscoped.joins("LEFT OUTER JOIN responses ON responses.answer_id = answers.id
LEFT OUTER JOIN response_sets ON response_sets.id = responses.response_set_id").
                                                joins(:question=>:survey_section).
                                                where('survey_sections.survey_id=? and (response_sets.test_data=? or response_sets.test_data is null)',survey_id,test).
                                                select("answers.question_id, answers.id, answers.text as text, count(responses.id) as answer_count").
                                                group("answers.question_id, answers.id, answers.text").
                                                order("answers.question_id, answers.id")

    single_choice_responses = Response.joins(:response_set).where('survey_id = ? and test_data = ?',survey_id,test).select('responses.question_id, responses.answer_id,
responses.float_value,
responses.integer_value,
responses.datetime_value, 
responses.string_value')
    @chart = {}
    colors = ['#4572A7', '#AA4643', '#89A54E', '#80699B', '#3D96AE', '#DB843D', '#92A8CD', '#A47D7C', '#B5CA92']
    questions.each do |q|
      if q.pick == 'one'
          generate_pie_chart(q, multiple_choice_responses)
      elsif q.pick == 'any'
          generate_bar_chart(q, multiple_choice_responses, colors)
      elsif [:number,:date,:datetime,:time].include? q.question_type_id
          generate_histogram_chart(q, single_choice_responses)
      else
      end
    end
  end

  private

  RESPONSE_GENERATOR = {
    pick_one: ->(response, response_set, q, context){ response_set.responses.create(question_id: q.id, answer_id: context.send(:random_pick, q)) },
    pick_any: ->(response, response_set, q, context){ context.send(:random_anys, response, response_set, q) },
    dropdown: ->(response, response_set, q, context){ response_set.responses.create(question_id: q.id, answer_id: context.send(:random_pick, q)) },
    number:   ->(response, response_set, q, context){ response.integer_value = rand(100); response.save },
    string:   ->(response, response_set, q, context){ response.string_value = context.send(:random_string); response.save },
    box:      ->(response, response_set, q, context){ response.text_value = context.send(:random_string); response.save },
    date:     ->(response, response_set, q, context){ response.datetime_value = context.send(:random_date); response.save },
    datetime: ->(response, response_set, q, context){ response.datetime_value = context.send(:random_date); response.save },
    time:     ->(response, response_set, q, context){ response.datetime_value = context.send(:random_date); response.save },
    file:     ->(response, response_set, q, context){ context.send(:make_blob, response, false) },
    stars:    ->(response, response_set, q, context){ response_set.responses.create(:question_id => q.id, :integer_value => rand(5)+1, :answer_id => q.answers.first.id)}
  }
  
  def generate_1_result_per_question(response_set, survey)
    @survey.survey_sections.each do |ss|
      ss.questions.each do |q|
        response = response_set.responses.build(:question_id => q.id, :answer_id => q.answers.first.id)
        RESPONSE_GENERATOR[q.question_type_id].call(response, response_set, q, self)
        p "q type #{q.question_type_id} response #{response.answer_id}"
      end
    end
  end
  
  def random_string
    whichone = rand(5)
    case whichone
    when 0
      'An answer.'
    when 1
      'A different answer.'
    when 2
      'Any answer here.'
    when 3
      'Some response.'
    when 4
      'A random response.'
    when 5
      'A random answer.'
    end
  end
  
  def random_date
    Time.now + (rand(100)-50).days
  end
  
  def random_pick(question, avoid=[])
    answer = nil
    answers = question.answers
    while !answer
      pick = rand(answers.count)
      if !avoid.include?(answers[pick].id)
        answer=answers[pick].id
      end
    end
    return answer
  end
  
  def random_pick_count(question)
    answers = question.answers
    return rand(answers.count)+1
  end

  def make_blob(response, show_blob)
    response.save!
    response.blob.store!(File.new(Rails.public_path+'/images/regulations.jpg')) if show_blob
  end

  def random_anys(response, response_set, q)
    if !q.answers.blank?
      how_many = random_pick_count(q)
      how_many.times {
        already_checked = response_set.responses.where('question_id=?',q.id).collect(&:answer_id)
        response = response_set.responses.build(:question_id => q.id, :answer_id => random_pick(q,already_checked))
        response.save!
      }
    else
      response = nil
    end
  end
  
  def generate_pie_chart(q, responses)
    piearray = []
    responses.where(:question_id => q.id).each_with_index do |a, index|
      piearray[index]= {:y=> a.answer_count.to_i, :name => a.text.to_s}
    end
    @chart[q.id.to_s] = LazyHighCharts::HighChart.new('graph') do |f|
      f.options[:chart][:plotBorderWidth] = nil
      f.options[:chart][:plotBackgroundColor] = nil
      f.options[:title][:text] = q.text
      f.plot_options(:pie=>{
        :allowPointSelect=>true,
        :cursor=>"pointer" ,
        :dataLabels=>{
          :enabled=>true,
          :color=>"#000000",
          :connectorColor=>"#000000"
        },
        :enableMouseTracking => false,
        :shadow => false,
        :animation => false
      })
      f.series( :type => 'pie',
        :name=> q.text,
        :data => piearray
      )
    end
  end
  
  def generate_bar_chart(q, responses, colors)
    bararray = []
    responses.where(:question_id => q.id).each_with_index do |a, index|
      bararray[index]= {:y=> a.answer_count.to_i, :color => colors[index].to_s}
    end
    @chart[q.id.to_s] = LazyHighCharts::HighChart.new('graph') do |f|
      f.options[:chart][:defaultSeriesType] = 'column'
      f.options[:title][:text] = q.text
      f.options[:xAxis][:categories] = q.answers.order('answers.id').map{|a| a.text}
      f.options[:xAxis][:labels] = {:rotation=> -45, :align => 'right'}
      f.options[:yAxis][:min] = 0
      f.options[:yAxis][:title] = {:text => 'Count'}
      f.plot_options(
        :pointPadding=>true,
        :borderWidth => 0,
        :enableMouseTracking => false,
        :shadow => false,
        :animation => false,
        :stickyTracking => false
      )
      f.series( :data => bararray,
        :dataLabels => {
          :enabled=>true
          } )
    end
  end
  
  def generate_histogram_chart(q, responses)
    suffix = q.suffix
    histarray = HistogramArray.new(q, responses.where(:question_id => q.id), suffix).calculate
    @chart[q.id.to_s] = LazyHighCharts::HighChart.new('graph') do |f|
      f.options[:chart][:defaultSeriesType] = 'column'
      f.options[:title][:text] = 'Histogram for "'+q.text+'"'
      f.options[:legend][:enabled] = false
      f.options[:xAxis][:categories] = histarray.map{|h| h[:x]}
      f.options[:xAxis][:labels] = {:rotation=> -45, :align => 'right'}
      f.options[:yAxis][:min] = 0
      f.options[:yAxis][:title] = {:text => 'Occurrences'}
      f.plot_options(
        :pointPadding=>true,
        :borderWidth => 0,
        :enableMouseTracking => false,
        :shadow => false,
        :animation => false
      )
      f.series( :data=> histarray.map{|h| h[:y]},
        :dataLabels => {
          :enabled=>true
          }
              )
    end
  end

  def report_params 
    @report_params ||= params.permit(:survey_id, :id)
  end
      
end

class HistogramArray
  def initialize(question, in_arr, label=nil)
    @out_arr = []
    p "in arr at init #{in_arr.map{|a| a}}"
    @in_arr = in_arr.map{|a| a.response_value}
    return if in_arr.empty?
    @question = question
    set_min
    set_max
    set_count
    set_distribution
    set_step
  end

  def calculate
    if !@in_arr.empty?
      @distribution.times do |index|
        refresh_range
        set_x_label
        @out_arr[index]= {
          :x => @x_label,
          :y => @in_arr.select {|v| v.to_f >= @lower_bound && v.to_f < @upper_bound}.count
        }
      end
    end
    return @out_arr
  end

  private

  def set_min
    @min = @range = @in_arr.min.to_f
  end

  def set_max
    @max = @in_arr.max.to_f
    @max = @max + @max.abs*0.00000000001
  end

  def set_count
    @count = @in_arr.count
  end

  def set_distribution
    @distribution = sqrt(@count).round
  end

  def set_step
    @step = ((@max-@min)/@distribution)
  end
  
  def refresh_range
    @lower_bound = @range
    @upper_bound = @range+@step
    @range = @upper_bound
  end    
    
  def trunc_range(num)
    return (num*10000000000).to_i/10000000000
  end

  def set_x_label
    if @question.question_type_id == :number
      @x_label = trunc_range(@lower_bound).to_s+' to '+trunc_range(@upper_bound).to_s+' '+@label.to_s
    else
      response_formatter = ReportFormatter.new(@question, @in_arr)
      lower_bound = response_formatter.format_stats(@lower_bound)
      upper_bound = response_formatter.format_stats(@upper_bound)
      @x_label = lower_bound+' to '+upper_bound+' '+@label.to_s
    end 
  end
end
