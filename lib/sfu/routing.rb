module SFU #:nodoc: 
  module Routing #:nodoc: 
    module MapperExtensions 

      def sfu
        @set.add_route("/sfu", {:controller => "sfu", :action => "index"}) 
      end 

      def new_course_form
	@set.add_route("/api/vi/sfu/new_course_form", {:controller => "new_course_form", :action => "new"})
      end

    end
  end 
end 

ActionController::Routing::RouteSet::Mapper.send :include, SFU::Routing::MapperExtensions
