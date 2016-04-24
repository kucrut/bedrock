<?php
$base_dir = dirname( dirname( __FILE__ ) );
$root_dir = "${base_dir}/root";

/**
 * Use Dotenv to set required environment variables and load .env file in root
 */
Dotenv::load( $base_dir );
Dotenv::required(
	array(
		'DB_NAME',
		'DB_USER',
		'DB_PASSWORD',
		'TABLE_PREFIX',
		'WP_HOME',
		'WP_SITEURL',
		'LOGGED_IN_KEY',
		'LOGGED_IN_SALT',
		'AUTH_KEY',
		'AUTH_SALT',
		'SECURE_AUTH_KEY',
		'SECURE_AUTH_SALT',
		'NONCE_KEY',
		'NONCE_SALT',
	)
);

/**
 * Set up our global environment constant and load its config first
 * Default: development
 */
define( 'WP_ENV', getenv( 'WP_ENV' ) ? getenv( 'WP_ENV' ) : 'development' );

$env_config = dirname( __FILE__ ) . '/environments/' . WP_ENV . '.php';

define( 'DB_NAME', getenv( 'DB_NAME' ) );
define( 'DB_USER', getenv( 'DB_USER' ) );
define( 'DB_PASSWORD', getenv( 'DB_PASSWORD' ) );
define( 'DB_HOST', getenv( 'DB_HOST' ) ? getenv( 'DB_HOST' ) : 'localhost' );

if ( file_exists( $env_config ) ) {
	require_once $env_config;
}

/**
 * Custom Content Directory
 */
define( 'CONTENT_DIR', '/wp-content' );
define( 'WP_CONTENT_DIR', $root_dir . CONTENT_DIR );
define( 'WP_CONTENT_URL', "//{$_SERVER['HTTP_HOST']}" . CONTENT_DIR );

/**
 * DB settings
 */
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );
$table_prefix = getenv( 'TABLE_PREFIX' );

/**
 * Authentication Unique Keys and Salts
 */
define( 'AUTH_KEY',         getenv( 'AUTH_KEY' ) );
define( 'SECURE_AUTH_KEY',  getenv( 'SECURE_AUTH_KEY' ) );
define( 'LOGGED_IN_KEY',    getenv( 'LOGGED_IN_KEY' ) );
define( 'NONCE_KEY',        getenv( 'NONCE_KEY' ) );
define( 'AUTH_SALT',        getenv( 'AUTH_SALT' ) );
define( 'SECURE_AUTH_SALT', getenv( 'SECURE_AUTH_SALT' ) );
define( 'LOGGED_IN_SALT',   getenv( 'LOGGED_IN_SALT' ) );
define( 'NONCE_SALT',       getenv( 'NONCE_SALT' ) );

/**
 * Custom Settings
 */
define( 'AUTOMATIC_UPDATER_DISABLED', true );
define( 'DISABLE_WP_CRON', true );
define( 'DISALLOW_FILE_EDIT', true );
define( 'DISABLED_PLUGINS', getenv( 'DISABLED_PLUGINS' ) );

/**
 * Multisite
 *
 * The token below will be replaced with the real
 * multisite configs when you run bin/setup-multisite.sh
 */
#MULTISITE_CONFIGS#

/**
 * Bootstrap WordPress
 */
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', $root_dir . '/wp/' );
}
