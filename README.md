# WP Base

WP Base is a modern WordPress stack based on [Bedrock](http://roots.io/wordpress-stack/) that helps you get started with the best development tools and project structure.

## Quick Start

See [Installation/Usage](#installationusage) for more details)

## Features

* Dependency management with [Composer](http://getcomposer.org)
* Automated deployments with [Capistrano](http://www.capistranorb.com/)
* Better folder structure
* Easy WordPress configuration with environment specific files
* Environment variables with [Dotenv](https://github.com/vlucas/phpdotenv)
* Easy development environments with [VVV](https://github.com/10up/varying-vagrant-vagrants/)

WP Base is meant as a base for you to fork and modify to fit your needs. It is delete-key friendly and you can strip out or modify any part of it. You'll also want to customize WP Base with settings specific to your sites/company.

Much of the philosphy behind Bedrock is inspired by the [Twelve-Factor App](http://12factor.net/) methodology including the [WordPress specific version](http://roots.io/twelve-factor-wordpress/).

Note: While this is a project from the guys behind the [Roots starter theme](http://roots.io/starter-theme/), Bedrock isn't tied to Roots in any way and works with any theme.

## Requirements

* Git
* PHP >= 5.3.2 (for Composer)
* Ruby >= 1.9 (for Capistrano)

If you aren't interested in using a part, then you don't need its requirements either. Not deploying with Capistrano? Then don't worry about Ruby for example.

## Installation/Usage

See [Documentation](#documentation) for more details on the steps below.

### Using `create-project`

**TODO**

### Manually

1. Clone/Fork repo inside VVV's `www` directory
2. Run `composer install`
3. Answer the questions to generate the `.env` file
4. Initialize site:
  * You can reload vagrant by running `vagrant reload --provision`
  * Or, if it's already running, you can run **from within the vagrant environment** `./bin/vvv-init.sh -r`
5. Add theme(s)
6. Access WP Admin at `http://<CHOSEN DOMAIN NAME>/wp/wp-admin`
7. Using Capistrano for deploys? Edit stage/environment configs in `config/deploy/` to set the roles/servers and connection options.

## Documentation

### Folder Structure

```
├── bin
│   └── vvv-init.sh
├── config
│   │── deploy
│   │   ├── staging.rb
│   │   └── production.rb
│   │── deploy.rb
│   │── environments
│   │   ├── development.php
│   │   ├── staging.php
│   │   └── production.php
│   └── application.php
├── root
│   ├── app
│   │   ├── mu-plugins
│   │   ├── plugins
│   │   └── themes
│   ├── wp
│   ├── index.php
│   └── wp-config.php
├── scripts
│   └── Bedrock
│       └── Installer.php
├── vendor
├── Capfile
├── Gemfile
├── Gemfile.lock
├── composer.json
└── composer.lock
```

The organization of WP Base is similar to putting WordPress in its own subdirectory but with some improvements.

* `wp-content` (or maybe just `content`) has been named `app` to better reflect its contents. It contains application code and not just "static content". It also matches up with other frameworks such as Symfony and Rails.
* `wp-config.php` remains in the root because it's required by WP, but it only acts as a loader. The actual configuration files have been moved to `config/` for better separation.
* Capistrano configs are also located in `config/` to make it consistent.
* `vendor/` is where the Composer managed dependencies are installed to.
* `wp/` is where the WordPress core lives. It's also managed by Composer but can't be put under `vendor` due to WP limitations.

### Configuration Files

The root `wp-config.php` is required by WordPress and is only used to load the other main configs. Nothing else should be added to it.

`config/application.php` is the main config file that contains what `wp-config.php` usually would. Base options should be set in there.

For environment specific configuration, use the files under `config/environments`. By default there's is `development`, `staging`, and `production` but these can be whatever you require.

The environment configs are required **before** the main `application` config so anything in an environment config takes precedence over `application`.

Note: You can't re-define constants in PHP. So if you have a base setting in `application.php` and want to override it in `production.php` for example, you have a few options:

* Remove the base option and be sure to define it in every environment it's needed
* Only define the constant in `application.php` if it isn't already defined.

### Environment Variables

WP Base tries to separate config from code as much as possible and environment variables are used to achieve this. The benefit is there's a single place (`.env`) to keep settings like database or other 3rd party credentials that isn't committed to your repository.

[PHP dotenv](https://github.com/vlucas/phpdotenv) is used to load the `.env` file. All variables are then available in your app by `getenv`, `$_SERVER`, or `$_ENV`.

Currently, the following env vars are required:

* `DB_USER`
* `DB_NAME`
* `DB_PASSWORD`
* `WP_HOME`
* `WP_SITEURL`

#### Don't want it?

You will lose the separation between config and code and potentially put secure credentials at risk.

* Remove `dotenv` from `composer.json` requires
* Remove `.env.example` file from root
* Remove `require_once('vendor/autoload.php');` from `wp-config.php`
* Replace all `getenv` calls with whatever method you want to set those values

### Composer

[Composer](http://getcomposer.org) is used to manage dependencies. WP Base considers any 3rd party library as a dependency including WordPress itself and any plugins.

See these two blogs for more extensive documentation:

* [Using Composer with WordPress](http://roots.io/using-composer-with-wordpress/)
* [WordPress Plugins with Composer](http://roots.io/wordpress-plugins-with-composer/)

Screencast ($): [Using Composer With WordPress](http://roots.io/screencasts/using-composer-with-wordpress/)

#### Plugins

[WordPress Packagist](http://wpackagist.org/) is already registered in the `composer.json` file so any plugins from the [WordPress Plugin Directory](http://wordpress.org/plugins/) can easily be required.

To add a plugin, add it under the `require` directive or use `composer require <namespace>/<packagename>` from the command line. If it's from WordPress Packagist then the namespace is always `wpackagist`.

Whenever you add a new plugin or update the WP version, run `composer update` to install your new packages.

`plugins`, and `mu-plugins` are Git ignored by default since Composer manages them. If you want to add something to those folders that *isn't* managed by Composer, you need to update `.gitignore` to whitelist them:

`!app/plugins/plugin-name`

#### Updating WP and plugin versions

Updating your WordPress version (or any plugin) is just a matter of changing the version number in the `composer.json` file.

Then running `composer update` will pull down the new version.

### Capistrano

[Capistrano](http://www.capistranorb.com/) is a remote server automation and deployment tool. It will let you deploy or rollback your application in one command:

* Deploy: `cap production deploy`
* Rollback: `cap production deploy:rollback`

Composer support is built-in so when you run a deploy, `composer install` is automatically run. Capistrano has a great [deploy flow](http://www.capistranorb.com/documentation/getting-started/flow/) that you can hook into and extend it.

It's written in Ruby so it's needed *locally* if you want to use it. Capistrano was recently rewritten to be completely language agnostic, so if you previously wrote it off for being too Rails-centric, take another look at it.

Screencast ($): [Deploying WordPress with Capistrano](http://roots.io/screencasts/deploying-wordpress-with-capistrano/)

#### Don't want it?

You will lose the one-command deploys and built-in integration with Composer. Another deploy method will be needed as well.

* Remove `Capfile`, `Gemfile`, and `Gemfile.lock`
* Remove `config/deploy.rb`
* Remove `config/deploy/` directory

### wp-cron

WP Base disables the internal WP Cron via `define('DISABLE_WP_CRON', true);`. If you keep this setting, you'll need to manually set a cron job like the following in your crontab file:

`*/5 * * * * curl http://example.com/wp/wp-cron.php`

## TODO

* Solution for basic database syncing/copying

## Contributing

**TODO**

## Support

**TODO**
