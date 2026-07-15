Rails.application.configure do
  MissionControl::Jobs.http_basic_auth_user = ENV.fetch("JOBS_USER", "admin")
  MissionControl::Jobs.http_basic_auth_password = ENV.fetch("JOBS_PASSWORD", "solid")
end
