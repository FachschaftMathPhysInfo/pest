namespace :misc do
  desc "Generate how tos in all available languagess in tmp/howtos"
  task :howtos do
    saveto = File.join(GNT_ROOT, "tmp", "howtos")
    create_howtos(saveto)
    Rake::Task["clean".to_sym].invoke
  end
end
