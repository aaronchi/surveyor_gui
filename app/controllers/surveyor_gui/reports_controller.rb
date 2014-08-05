require 'complex'
include Math

class SurveyorGui::ReportsController < ApplicationController
  def preview
    response_qty = 5 
    @title = "Preview Report for "+response_qty.to_s+" responses"
    @survey = Survey.find(params[:survey_id])
    user_id = defined?(current_user) ? current_user.id : 1 
    ResponseSet.where('survey_id = ? and test_data = ? and user_id = ?',report_params[:survey_id],true, user_id).each {|r| r.destroy}
    response_qty.times.each {
      @response_set = ResponseSet.create(:survey => @survey, :user_id => user_id, :test_data => true)
      generate_1_result_per_question(@response_set, @survey, false)
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

    single_choice_responses = Response.joins(:response_set).where('survey_id = ? and test_data = ?',survey_id,test).select('responses.question_id,
responses.float_value,
responses.integer_value,
responses.datetime_value')
    @chart = {}
    colors = ['#4572A7', '#AA4643', '#89A54E', '#80699B', '#3D96AE', '#DB843D', '#92A8CD', '#A47D7C', '#B5CA92']
    questions.each do |q|
      if q.pick == 'one'
          generate_pie_chart(q, multiple_choice_responses)
      elsif q.pick == 'any'
          generate_bar_chart(q, multiple_choice_responses, colors)
      elsif q.answers.first && (q.answers.first.response_class == 'integer' || q.answers.first.response_class == 'float' )
          generate_histogram_chart(q, single_choice_responses)
      else
      end
    end
  end

  private
  
  def generate_1_result_per_question(response_set, survey, show_blob)
    @survey.survey_sections.each do |ss|
      ss.questions.each do |q|
        case q.pick
        when 'none'
            if q.answers.first
            response = response_set.responses.build(:question_id => q.id, :answer_id => q.answers.first.id)
            case q.answers.first.response_class
            when 'integer'
              response.integer_value = rand(100)
            when 'float'
              response.float_value = rand(100)
            when 'string'
              response.string_value = random_string
            when 'text'
              response.text_value = random_string
            when 'date'
              response.datetime_value = random_date
            when 'blob'
              response.save!
              response.blob.store!(File.new(Rails.public_path+'/images/regulations.jpg')) if show_blob
            end
            response.save!
          end
        when 'one'
          if q.display_type=='stars'
            response = response_set.responses.build(:question_id => q.id, :integer_value => rand(5)+1, :answer_id => q.answers.first.id)
          else
            response = response_set.responses.build(:question_id => q.id, :answer_id => random_pick(q))
          end
          response.save!
        when 'any'
          if !q.answers.blank?
            how_many = random_pick_count(q)
            how_many.times {
              already_checked = response_set.responses.where('question_id=?',q.id).collect(&:answer_id)
              response = response_set.responses.build(:question_id => q.id, :answer_id => random_pick(q,already_checked))
              response.save!
            }
          end
        end
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
  
  def histogram(in_arr, label=nil)
    #floats round to 4
    out_arr = []
    if !in_arr.blank?
      min = in_arr.collect(&:response_value).min
      max = in_arr.collect(&:response_value).max
      max = max + max.abs*0.00000000001
      count = in_arr.count(:id)
      distribution = sqrt(count).round
      range = min
      step = ((max-min)/distribution)
      distribution.times do |index|
        lower_bound = range
        upper_bound = range+step
        range = upper_bound
        out_arr[index]= {
          :x => trunc_range(lower_bound).to_s+' to '+trunc_range(upper_bound).to_s+' '+label.to_s,
          :y => in_arr.select {|v| v.response_value >= lower_bound && v.response_value < upper_bound}.count
        }
      end
    end
    return out_arr
  end
  
  def trunc_range(num)
    return (num*10000000000).to_i/10000000000
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
  
  
  def generate_financial_chart
    colors = ['#4572A7', '#AA4643', '#89A54E', '#80699B', '#3D96AE', '#DB843D', '#92A8CD', '#A47D7C', '#B5CA92']
    bararray = []
    @evaluation_institution.financial_scenarios.each_with_index do |fs, index|
      total_cost = 0
      fs.fs_products.each do |fsp|
        extended_cost = fsp.unit_cost_in_dollars * fsp.estimated_annual_usage
        total_cost = total_cost + extended_cost
      end
      adjusted_cost = total_cost + fs.other_costs_in_dollars - fs.anticipated_savings_in_dollars
      bararray[index]= {:y=> adjusted_cost, :color => colors[index].to_s}
    end
    @financial_chart = LazyHighCharts::HighChart.new('graph') do |f|
      f.options[:chart][:defaultSeriesType] = 'column'
      f.options[:legend][:enabled]=false
      f.options[:title][:text] = "Scenario Comparison"
      f.options[:xAxis][:categories] = @evaluation_institution.financial_scenarios.each_with_index.map{|fs, index| "Scenario "+(index+1).to_s+": " + (index==0 ? @evaluation_institution.evaluation.name : fs.name)}
      f.options[:xAxis][:labels] = {:rotation=> -45, :align => 'right', :style=>{:fontSize=>"14pt", :fontWeight=>"bold"}}
      f.options[:yAxis][:min] = 0
      f.options[:yAxis][:title] = {:text => 'Total Cost'}
      f.plot_options(
        :pointPadding=>true,
        :borderWidth => 0,
        :enableMouseTracking => false,
        :shadow => false,
        :animation => false,
        :stickyTracking => false
      )
      f.series(
        :data => bararray,
        :dataLabels => {
          :enabled=>true
          } )
    end
  end
  
  def generate_histogram_chart(q, responses)
    suffix = q.answers.first.text.split('|')[1]
    histarray = histogram(responses.where(:question_id => q.id), suffix)
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
