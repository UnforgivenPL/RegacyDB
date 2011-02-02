class RmodelGenerator < Rails::Generators::Base
  source_root File.expand_path('../templates', __FILE__)
  
  argument :model_name, :type=>:string, :required=>true
  
  def create_model
   create_file "app/models/#{model_name.underscore}.rb", <<-RMODEL
class #{model_name.camelcase} < UnforgivenPL::RegacyDB::Base

 # provide statements and attributes for this class

end
   RMODEL
  end
  
end
