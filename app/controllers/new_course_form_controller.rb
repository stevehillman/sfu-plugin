require "rest_client"
require "json"

class NewCourseFormController < ApplicationController
  unloadable

  def new
    @user = User.find(@current_user.id)
    @sfuid = @user.pseudonym.unique_id
    if !student_only? @sfuid
      @course = Course.new
      @terms = Account.find_by_name('Simon Fraser University').enrollment_terms.delete_if {|t| t.name == 'Default Term'}
      10.times { @course.course_sections.build }
    end
  end

  def get_user_roles_from_amaint (sfuid)
    auth_token = "not saved on github"
    rest_url = "https://rest.its.sfu.ca/cgi-bin/WebObjects/AOBRestServer.woa/rest/datastore2/global/accountInfo.js?art=" + auth_token + "&username=" + sfuid
    json_out = RestClient.get rest_url
    account = JSON.parse json_out
    account['roles']
  end

  def student_only? (sfuid)
    if get_user_roles_from_amaint(sfuid).join("").eql? "undergrad"
      return true
    end
    return false
  end

end
