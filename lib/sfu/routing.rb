module SFU #:nodoc: 
  module Routing #:nodoc: 
    module MapperExtensions 

      def sfu
        @set.add_route("/sfu", {:controller => "sfu", :action => "index"}) 
      end 

      def new_course_form
	      @set.add_route("/sfu/course_form", {:controller => "new_course_form", :action => "new"})
        @set.add_route("/sfu/course_form/create", {:controller => "new_course_form", :action => "create"})
        @set.add_route("/sfu/courses/:sfuid", {:controller => "new_course_form", :action => "courses"})
        @set.add_route("/sfu/courses/:sfuid/:term", {:controller => "new_course_form", :action => "courses"})
        @set.add_route("/sfu/terms/:sfuid", {:controller => "new_course_form", :action => "terms"})
      end

    end
  end 
end 

ActionController::Routing::RouteSet::Mapper.send :include, SFU::Routing::MapperExtensions
