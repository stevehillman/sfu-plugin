class Course
  attr_accessible :course_sections_attributes
  accepts_nested_attributes_for :course_sections

end

class NewCourseFormController < ApplicationController
  unloadable

  def new 
    @user = AccountUser.find(@current_user.id).user
    @course = Course.new
    @terms = Account.find_by_name('Simon Fraser University').enrollment_terms.delete_if {|t| t.name == 'Default Term'}
    10.times { @course.course_sections.build }
  end
end
