require "rest_client"
require "json"

class NewCourseFormController < ApplicationController
  unloadable

  def new 
    @user = AccountUser.find(@current_user.id).user
    @course = Course.new
    @terms = Account.find_by_name('Simon Fraser University').enrollment_terms.delete_if {|t| t.name == 'Default Term'}
    10.times { @course.course_sections.build }
  end

  def get_user_roles_from_amaint (sfuid)
    auth_token = "not saved on github"
    rest_url = "https://rest.its.sfu.ca/cgi-bin/WebObjects/AOBRestServer.woa/rest/datastore2/global/accountInfo.js?art=" + auth_token + "&username=" + sfuid
    json_out = RestClient.get rest_url
    account = JSON.parse json_out
    account['roles']
  end

  def student_only? (sfuid)
    if get_user_roles_from_amaint(sfuid).equal? "undergrad"
      return false
    end
    return true
  end

end
