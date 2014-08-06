module SurveyorGui
  module Models
    module ResponseMethods

      def self.included(base)
        base.send :has_many, :answers, :primary_key => :answer_id, :foreign_key => :id
        base.send :has_many, :questions
        base.send :belongs_to, :column
        base.send :attr_accessible, :response_set, :question, :answer, :date_value, :time_value,
            :response_set_id, :question_id, :answer_id, :datetime_value, :integer_value, :float_value,
            :unit, :text_value, :string_value, :response_other, :response_group, 
            :survey_section_id, :blob, :column if defined? ActiveModel::MassAssignmentSecurity
        base.send :validates_uniqueness_of, :response_set_id, scope: [:question_id, :answer_id] 
        #belongs_to :user

        # after_destroy :delete_blobs!
        # after_destroy :delete_empty_dir

        #extends response to allow file uploads.
        base.send :mount_uploader, :blob, BlobUploader
      end

      VALUE_TYPE = ['float', 'integer', 'string', 'datetime', 'text']

      def response_value
        if self.question.pick=='none'
          VALUE_TYPE.each do |value_type|
            value_attribute = value_type+'_value'
            if instance_eval(value_attribute)
              return instance_eval(value_attribute)
            end
          end
          nil
        else
          return self.answer.text
        end
      end

    private

      def delete_blobs!
          self.remove_blob!
      end


      def delete_empty_dir
        FileUtils.rm_rf(File.join(Rails.root.to_s,'public',BlobUploader.store_dir))
      end
    end
  end
end
