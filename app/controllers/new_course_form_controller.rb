require "rest_client"
require "json"

class NewCourseFormController < ApplicationController
  unloadable

  def new
    @user = User.find(@current_user.id)
    @sfuid = @user.pseudonym.unique_id
    @sfuid = "wcs"
    @course_list = get_courses_for_instructor @sfuid
    @terms = Account.find_by_name('Simon Fraser University').enrollment_terms.delete_if {|t| t.name == 'Default Term'}
  end

  def create

  end


  def rest_server
    "https://rest.its.sfu.ca/cgi-bin/WebObjects/AOBRestServer.woa"
  end

  def account_url
    rest_server + "/rest/datastore2/global/accountInfo.js"
  end

  def terms_url
    rest_server + "/rest/crr/terms.js"
  end

  def courses_url
    rest_server + "/rest/crr/resource2.js"
  end

  def auth_token
    token = File.read File.dirname(__FILE__) + "/auth_token"
    token.strip
  end

  # returns an array
  def get_user_roles_from_amaint (sfuid)
    account = get_json_data account_url, "&username=" + sfuid
    unless account.nil?
      account["roles"]
    end
  end

  def student_only? (sfuid)
    result = get_user_roles_from_amaint(sfuid)
    unless result.nil?
	    if result.join("").eql? "undergrad"
      		return true
	    end
    end
    false
  end

  # returns an array
  def get_terms_for_instructor (sfuid)
    terms = get_json_data terms_url, "&username=" + sfuid
    unless terms.nil?
      terms["teachingSemester"]
    end
  end


  # returns an array
  def get_courses_for_term (sfuid, term)
    courses = get_json_data courses_url, "&username=" + sfuid + "&term=" + term
    unless courses.nil?
      courses["teachingCourse"]
    end
  end

  # returns an array
  def get_courses_for_instructor (sfuid)
    course_list = Array.new
    terms = get_terms_for_instructor sfuid

    unless terms.nil?
      terms.each do |term|
        courses = get_courses_for_term sfuid, term["peopleSoftCode"]

        courses.each do |course|
          term_code = term["peopleSoftCode"]
          name = course["course"].first["name"]
          title = course["course"].first["title"]
          number = course["course"].first["number"]
          section = course["course"].first["section"]
          id = "#{term_code}-#{name.downcase}-#{number}-#{section}"
          course_string = "#{id}:::" + get_term_display(term_code) + " #{name}#{number}-#{section} #{title}"
          instructor = course["instructor"]
          username = instructor.first["username"]
          role_code = instructor.first["roleCode"]


          if sfuid == username && role_code == "PI"
            course_list.push course_string
          end
        end
      end
    end
    course_list.push "sandbox-#{sfuid}:::Sandbox container"
    course_list
  end

  def get_term_display (term)
    year = term[0..2].to_i + 1900
    sem = term[-1,1]
    display = String.new
    if sem == "1"
      display = "Spring" + year.to_s
    elsif sem == "4"
      display = "Summer" + year.to_s
    elsif sem == "7"
      display = "Fall" + year.to_s
    end
    display
  end

  def get_json_data (url, params)
    rest_url =  url + "?art=" + auth_token + params
    json_out = RestClient.get rest_url
    if json_out.length > 2
      JSON.parse json_out
    end

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

