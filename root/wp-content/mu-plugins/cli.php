<?php

/**
 * Plugin Name: WP-CLI commands for the Stack
 * Author: Dzikri Aziz
 * Author URI: http://kucrut.org
 */

if ( ! defined( 'WP_CLI' ) || ! WP_CLI ) {
	return;
}

class Kucrut_Stack_Cli extends WP_CLI_Command {

	/**
	 * Template/stylesheet option names
	 *
	 * @access protected
	 * @var    array
	 */
	protected $template_root_option_names = array(
		'template_root',
		'stylesheet_root',
	);


	/**
	 * Update template/stylesheet root paths.
	 *
	 * ## EXAMPLES
	 *
	 *     wp kc-stack update-template-root
	 *
	 * @subcommand update-template-root
	 */
	public function update_template_root() {
		preg_match( '#(?P<datetime>\d{14})#', ABSPATH, $matches );

		if ( empty( $matches['datetime'] ) ) {
			WP_CLI::warning( 'Release datetime not found.' );
			exit( 0 );
		}

		if ( is_multisite() ) {
			foreach ( wp_get_sites() as $site ) {
				switch_to_blog( $site['blog_id'] );
				$this->_update_template_root( $matches['datetime'] );
				restore_current_blog();
			}
		} else {
			$this->_update_template_root();
		}

		WP_CLI::success( 'Done!' );
	}


	/**
	 * Update template/stylesheet root paths
	 *
	 * @param string $datetime Datetime, eg. 20151030081354.
	 */
	protected function _update_template_root( $datetime ) {
		foreach ( $this->template_root_option_names as $name ) {
			$value = get_option( $name );

			if ( empty( $value ) || '/themes' === $value ) {
				continue;
			}

			$value = preg_replace( '#releases/(\d{14})/#', "releases/{$datetime}/", $value );
			update_option( $name, $value );
		}
	}
}

WP_CLI::add_command( 'kc-stack', 'Kucrut_Stack_Cli' );
