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
          course_hash["semester"] = c["course"].first["semester"].to_s
          course_hash["instructor"] = c["instructor"].first["username"]
          course_hash["roleCode"] = c["instructor"].first["roleCode"]
          course_hash["key"] = course_hash["semester"] + ":::" +
                              course_hash["name"].downcase +  ":::" +
                              course_hash["number"] + ":::" +
                              course_hash["section"].downcase + ":::" + course_hash["title"]

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

  # course.csv
  # course_id,short_name,long_name,account_id,term_id,status
  # section.csv
  # section_id,course_id,name,status,start_date,end_date
  # enrollment.csv
  # course_id,user_id,role,section_id,status
  def create
    selected_courses = []
    account_id = Account.find_by_name('Simon Fraser University').id
    username = params[:course_for]
    cross_list = params[:cross_list]
    params.each do |key, value|
      if key.to_s.starts_with? "selected_course"
        selected_courses.push value
      end
    end

    @course_csv = []
    @section_csv = []
    @enrollment_csv = []
    selected_courses.each do |course|
      # 20131:::ensc:::351:::d100:::Real Time and Embedded Systems
      course_info = course.split(":::")
      term = course_info[0]
      name = course_info[1]
      number = course_info[2]
      section = course_info[3]
      title = course_info[4]

      course_id = "#{term}-#{name}-#{number}-#{section}:::course"
      section_id = "#{term}-#{name}-#{number}-#{section}:::section"
      short_name = "#{name.upcase}#{number} #{section.upcase}"
      long_name =  "#{short_name} #{title}"

      @course_csv.push "#{course_id},#{short_name},#{long_name},#{account_id},active"
      @section_csv.push "#{section_id},#{course_id},#{section.upcase},active,,,"
      @enrollment_csv.push "#{course_id},#{username},teacher,#{section_id},active"

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
