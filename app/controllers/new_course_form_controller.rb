require "rest_client"
require "json"

class NewCourseFormController < ApplicationController
  unloadable

  def new
    @user = User.find(@current_user.id)
    @sfuid = @user.pseudonym.unique_id
    @sfuid = "wcs"
    #@course_list = get_courses_for_instructor @sfuid
    @course_list = Array.new
    @terms = Account.find_by_name('Simon Fraser University').enrollment_terms.delete_if {|t| t.name == 'Default Term'}
  end

  def courses
    course_array = []

    if params[:term].nil?
      courses = SFU::Course.for_instructor params[:sfuid]
    else
      courses = SFU::Course.for_instructor params[:sfuid], params[:term]
    end

    courses.compact.each do |course|
      course.compact.each do |c|
        course_hash = {}
        unless c["instructor"].nil?
          course_hash["name"] = c["course"].first["name"]
          course_hash["title"] = c["course"].first["title"]
          course_hash["number"] = c["course"].first["number"]
          course_hash["section"] = c["course"].first["section"]
          course_hash["key"] = c["course"].first["key"]
          course_hash["semester"] = c["course"].first["semester"]
          course_hash["instructor"] = c["instructor"].first["username"]
          course_hash["roleCode"] = c["instructor"].first["roleCode"]
          course_array.push course_hash
        end
      end
    end



    respond_to do |format|
      format.json { render :text => course_array.reverse.to_json }
      #format.json { render :text => courses.to_json }
    end

  end

  def terms
    terms = SFU::Course.terms params[:sfuid]
    term_array = []
    terms.each do |term|
      term_array.push term
    end

    respond_to do |format|
      format.json { render :text => term_array.reverse.to_json }
    end
  end

  def create

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
          course_string =  "#{id}:::#{name}#{number} - " + get_term_display(term_code) + " #{section} #{title}"
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

end


module SFU

  class Course
    class << self
      def terms(sfuid)
        terms = SFURest.json SFURest.terms_url, "&username=" + sfuid
        terms["teachingSemester"]
      end

      def for_instructor(sfuid, term_code = nil)
        terms(sfuid).map do |term|
          if term_code.nil?
            courses = SFURest.json SFURest.courses_url, "&username=" + sfuid + "&term=" + term["peopleSoftCode"]
            courses["teachingCourse"]
          else
            if term["peopleSoftCode"] == term_code
              courses = SFURest.json SFURest.courses_url, "&username=" + sfuid + "&term=" + term["peopleSoftCode"]
              courses["teachingCourse"]
            end
          end
        end
      end

    end
  end

  class User
    class << self
      def roles(sfuid)
        account = SFURest.json SFURest.account_url, "&username=" + sfuid
        account["roles"]
      end

      # returns true or false
      def student_only?(sfuid)
        result = roles sfuid
        if result.join("").eql? "undergrad"
          return true
        end
        false
      end

    end
  end

end

module SFURest
  extend self

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


  def json(url, params)
    rest_url =  url + "?art=" + auth_token + params
    begin
      json_out = RestClient.get rest_url
      JSON.parse json_out
    rescue Exception=>e
      "[ teachingSemester => {}, teachingCourse => {} ]"
    end
  end

  def auth_token
    token = File.read File.dirname(__FILE__) + "/auth_token"
    token.strip
  end
end
