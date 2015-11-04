set :application, 'my_app_name'
set :repo_url, 'git@example.com:me/my_repo.git'

# Branch options
# Prompts for the branch name (defaults to current branch)
#ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }

# Sets branch to current one
#set :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }

# Hardcodes branch to always be master
# This could be overridden in a stage config file
set :branch, :master

set :deploy_to, "/srv/www/#{fetch(:application)}"

set :log_level, :info

set :linked_files, %w{.env}
set :linked_dirs, %w{root/app/uploads root/app/cache}

namespace :deploy do

  desc 'Create linked files'
  namespace :check do
    task :linked_files => '.env'
  end

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # This task is required by Capistrano but can be a no-op
      # Your restart mechanism here, for example:
      #execute :sudo, :systemctl, :restart, :mysqld
      #execute :sudo, :service, :mysql, :restart
    end
  end

end

remote_file '.env' => "/tmp/#{fetch(:application)}.env", roles: :app

file "/tmp/#{fetch(:application)}.env" do |t|
  if !FileTest.exist? "#{shared_path}/.env"
    puts t.name
    puts "\n\033[32mLet's create the \033[33m.env\033[32m file for \033[33m#{fetch(:stage)}\033[0m\n\n"
    sh "export ENV_FILE=/tmp/#{fetch(:application)}.env && composer run-script post-install-cmd"
    puts "\n"
  end
end

namespace :deploy do
  desc 'Update WordPress template root paths to point to the new release'
  task :update_option_paths do
    on roles(:app) do
      within fetch(:release_path) do
        if test :wp, :core, 'is-installed'
          execute :wp, :'kc-stack', :'update-template-root'
        end
      end
    end
  end
end

# The above update_option_paths task is not run by default
# Note that you need to have WP-CLI installed on your server
# Uncomment the following line to run it on deploys if needed
after 'deploy:publishing', 'deploy:update_option_paths'
